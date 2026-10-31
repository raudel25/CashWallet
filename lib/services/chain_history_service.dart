import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/crypto_network.dart';
import '../models/crypto_wallet.dart';
import 'chain_balance_service.dart';

/// A token transfer that touches the wallet's address.
class ChainTransfer {
  const ChainTransfer({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.timestamp,
    required this.incoming,
  });

  /// Unique per transfer: `txHash:logIndex` on EVM, transaction id on Tron.
  final String id;
  final String from;
  final String to;
  final double amount;
  final DateTime timestamp;
  final bool incoming;

  String get counterparty => incoming ? from : to;
}

class ChainHistoryResult {
  const ChainHistoryResult({
    required this.transfers,
    required this.cursor,
    required this.windowStart,
    this.truncated = false,
  });

  /// Oldest first.
  final List<ChainTransfer> transfers;

  /// Where the next sync continues: last scanned block (EVM) or last seen
  /// timestamp in milliseconds (Tron).
  final int cursor;

  /// Earliest moment covered by this read. Null when the whole history was
  /// read (Tron first sync).
  final DateTime? windowStart;

  /// The gap since the last sync was too large and older blocks were skipped.
  final bool truncated;
}

/// Reads incoming and outgoing token transfers from free public nodes.
class ChainHistoryService {
  ChainHistoryService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 30);
  static const _transferTopic =
      '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
  static const _tronPageSize = 200;
  static const _tronMaxPages = 25;

  /// Reads transfers after [cursor]. With no cursor (first sync) EVM reads
  /// the network's initial lookback and Tron the whole history.
  Future<ChainHistoryResult> fetchTransfers(
    CryptoWallet wallet, {
    int? cursor,
  }) async {
    final address = wallet.address;
    final network = wallet.network;
    final token = network?.token(wallet.tokenSymbol);
    if (address == null || network == null || token == null) {
      throw ChainBalanceException('Wallet has no address or unknown token');
    }
    try {
      switch (network.family) {
        case ChainFamily.evm:
          final logs = network.evmLogs;
          if (logs == null) {
            throw ChainBalanceException('History not supported');
          }
          return await _fetchEvm(logs, token, address, cursor);
        case ChainFamily.tron:
          return await _fetchTron(network, token, address, cursor);
      }
    } on ChainBalanceException {
      rethrow;
    } catch (e) {
      throw ChainBalanceException('Request failed: $e');
    }
  }

  Future<dynamic> _rpc(String url, String method, List<dynamic> params) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw ChainBalanceException('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (!body.containsKey('result')) {
      throw ChainBalanceException('RPC error: ${body['error']}');
    }
    return body['result'];
  }

  String _hex(int value) => '0x${value.toRadixString(16)}';

  Future<ChainHistoryResult> _fetchEvm(
    EvmLogsConfig logs,
    TokenContract token,
    String address,
    int? cursor,
  ) async {
    final head = int.parse(
      (await _rpc(logs.rpcUrl, 'eth_blockNumber', [])) as String,
    );
    var start = cursor == null ? head - logs.initialLookbackBlocks : cursor + 1;
    var truncated = false;
    final maxSpan = logs.blockRange * logs.maxChunks;
    if (head - start + 1 > maxSpan) {
      start = head - maxSpan + 1;
      truncated = cursor != null;
    }

    final me = address.toLowerCase();
    final paddedMe = '0x${me.substring(2).padLeft(64, '0')}';
    final divisor = BigInt.from(10).pow(token.decimals);
    final transfers = <ChainTransfer>[];
    DateTime? windowStart;

    for (var from = start; from <= head; from += logs.blockRange) {
      final to = (from + logs.blockRange - 1).clamp(from, head);
      Future<List<dynamic>> query(List<String?> topics) async =>
          (await _rpc(logs.rpcUrl, 'eth_getLogs', [
                {
                  'fromBlock': _hex(from),
                  'toBlock': _hex(to),
                  'address': token.address,
                  'topics': topics,
                },
              ]))
              as List<dynamic>;

      final results = await Future.wait([
        query([_transferTopic, null, paddedMe]),
        query([_transferTopic, paddedMe]),
      ]);
      for (final raw in [...results[0], ...results[1]]) {
        final log = raw as Map<String, dynamic>;
        final topics = (log['topics'] as List<dynamic>).cast<String>();
        if (topics.length < 3) continue;
        final sender = '0x${topics[1].substring(26)}';
        final recipient = '0x${topics[2].substring(26)}';
        // Self-transfers don't change the balance.
        if (sender == recipient) continue;
        final value = BigInt.parse(
          (log['data'] as String).substring(2),
          radix: 16,
        );
        final timestamp = log['blockTimestamp'] as String?;
        transfers.add(
          ChainTransfer(
            id: '${log['transactionHash']}:${int.parse(log['logIndex'] as String)}',
            from: sender,
            to: recipient,
            amount: value / divisor,
            timestamp: timestamp == null
                ? DateTime.now()
                : DateTime.fromMillisecondsSinceEpoch(
                    int.parse(timestamp) * 1000,
                  ),
            incoming: recipient == me,
          ),
        );
      }
    }

    // Approximate the window start from the oldest scanned block's time.
    final first = await _rpc(logs.rpcUrl, 'eth_getBlockByNumber', [
      _hex(start),
      false,
    ]);
    if (first is Map<String, dynamic>) {
      windowStart = DateTime.fromMillisecondsSinceEpoch(
        int.parse(first['timestamp'] as String) * 1000,
      );
    }

    transfers.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return ChainHistoryResult(
      transfers: transfers,
      cursor: head,
      windowStart: windowStart,
      truncated: truncated,
    );
  }

  Future<ChainHistoryResult> _fetchTron(
    CryptoNetwork network,
    TokenContract token,
    String address,
    int? cursor,
  ) async {
    final transfers = <ChainTransfer>[];
    final divisor = BigInt.from(10).pow(token.decimals);
    var newCursor = cursor ?? 0;
    String? fingerprint;
    var pages = 0;
    var truncated = false;

    do {
      final query = {
        'contract_address': token.address,
        'only_confirmed': 'true',
        'limit': '$_tronPageSize',
        'order_by': 'block_timestamp,asc',
        if (cursor != null) 'min_timestamp': '${cursor + 1}',
        if (fingerprint != null) 'fingerprint': fingerprint,
      };
      final uri = Uri.parse(
        '${network.rpcUrl}/v1/accounts/$address/transactions/trc20',
      ).replace(queryParameters: query);
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw ChainBalanceException('HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      for (final raw in body['data'] as List<dynamic>? ?? []) {
        final item = raw as Map<String, dynamic>;
        final from = item['from'] as String;
        final to = item['to'] as String;
        if (from == to) continue;
        final timestamp = item['block_timestamp'] as int;
        if (timestamp > newCursor) newCursor = timestamp;
        transfers.add(
          ChainTransfer(
            id: item['transaction_id'] as String,
            from: from,
            to: to,
            amount: BigInt.parse(item['value'] as String) / divisor,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
            incoming: to == address,
          ),
        );
      }
      fingerprint =
          (body['meta'] as Map<String, dynamic>?)?['fingerprint'] as String?;
      pages++;
      if (fingerprint != null && pages >= _tronMaxPages) {
        truncated = true;
        break;
      }
    } while (fingerprint != null);

    transfers.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return ChainHistoryResult(
      transfers: transfers,
      cursor: newCursor,
      windowStart: null,
      truncated: truncated,
    );
  }
}
