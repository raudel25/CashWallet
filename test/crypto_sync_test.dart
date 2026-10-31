import 'dart:convert';

import 'package:cash_wallet/data/crypto_entry_repository.dart';
import 'package:cash_wallet/data/crypto_sync_state_repository.dart';
import 'package:cash_wallet/models/cash_entry.dart';
import 'package:cash_wallet/models/crypto_entry.dart';
import 'package:cash_wallet/models/crypto_wallet.dart';
import 'package:cash_wallet/services/chain_balance_service.dart';
import 'package:cash_wallet/services/chain_history_service.dart';
import 'package:cash_wallet/services/crypto_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _me = '0x1111111111111111111111111111111111111111';
const _other = '0x2222222222222222222222222222222222222222';
const _topic =
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

String _pad(String address) => '0x${address.substring(2).padLeft(64, '0')}';
String _hexAmount(double amount, {int decimals = 18}) =>
    '0x${(BigInt.from(amount * 1000) * BigInt.from(10).pow(decimals - 3)).toRadixString(16)}';

Map<String, dynamic> _log({
  required String from,
  required String to,
  required double amount,
  required String tx,
  int block = 999000,
  int timestamp = 1790000000,
}) => {
  'topics': [_topic, _pad(from), _pad(to)],
  'data': _hexAmount(amount),
  'blockNumber': block,
  'transactionHash': tx,
  'logIndex': '0x1',
  'blockTimestamp': '0x${timestamp.toRadixString(16)}',
};

/// Fake EVM node at block [head] with [balance] on-chain and [logs].
MockClient _fakeBsc({
  required double balance,
  required List<Map<String, dynamic>> logs,
  int decimals = 18,
  int head = 1000000,
  void Function(Map<String, dynamic> request)? onRequest,
}) {
  return MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    onRequest?.call(body);
    final params = body['params'] as List<dynamic>;
    Object? result;
    switch (body['method']) {
      case 'eth_call':
        result = _hexAmount(balance, decimals: decimals);
      case 'eth_blockNumber':
        result = '0x${head.toRadixString(16)}';
      case 'eth_getBlockByNumber':
        result = {'timestamp': '0x${1789900000.toRadixString(16)}'};
      case 'eth_getLogs':
        final filter = params.first as Map<String, dynamic>;
        final topics = filter['topics'] as List<dynamic>;
        final incoming = topics.length > 2;
        final from = int.parse(filter['fromBlock'] as String);
        final to = int.parse(filter['toBlock'] as String);
        result = logs.where((log) {
          final t = log['topics'] as List<dynamic>;
          final block = log['blockNumber'] as int;
          return block >= from &&
              block <= to &&
              (incoming ? t[2] == _pad(_me) : t[1] == _pad(_me));
        }).toList();
    }
    return http.Response(jsonEncode({'result': result}), 200);
  });
}

CryptoSyncService _service(http.Client client) => CryptoSyncService(
  balanceService: ChainBalanceService(client: client),
  historyService: ChainHistoryService(client: client),
  entryRepository: const CryptoEntryRepository(),
  syncStateRepository: const CryptoSyncStateRepository(),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final wallet = CryptoWallet.create(
    name: 'Trust',
    networkId: 'bep20',
    tokenSymbol: 'USDT',
    address: _me,
  );
  const repo = CryptoEntryRepository();

  test('first sync imports transfers and sets the opening balance', () async {
    // Balance before the window was 70: +50 in, -20 out → 100 now.
    final service = _service(
      _fakeBsc(
        balance: 100,
        logs: [
          _log(from: _other, to: _me, amount: 50, tx: '0xa'),
          _log(from: _me, to: _other, amount: 20, tx: '0xb'),
        ],
      ),
    );

    final result = await service.sync(wallet);
    expect(result.onChainBalance, 100);
    expect(result.imported, 2);

    final entries = await repo.load(wallet.id);
    final opening = entries.singleWhere((e) => e.isOpening);
    expect(opening.amount, closeTo(70, 1e-9));
    expect(
      entries.where((e) => e.isImported).map((e) => e.counterparty).toSet(),
      {_other},
    );
    expect(await repo.balance(wallet.id), closeTo(100, 1e-9));
    // Opening is dated before the scanned window.
    expect(
      opening.createdAt.isBefore(
        DateTime.fromMillisecondsSinceEpoch(1789900000 * 1000),
      ),
      isTrue,
    );
  });

  test('later syncs only add new transfers and never duplicate', () async {
    final logs = [_log(from: _other, to: _me, amount: 50, tx: '0xa')];
    await _service(_fakeBsc(balance: 50, logs: logs)).sync(wallet);

    // Same transfer reported again plus a new one.
    final cursors = <String>[];
    final second = await _service(
      _fakeBsc(
        balance: 60,
        head: 1000010,
        logs: [
          ...logs,
          _log(from: _other, to: _me, amount: 10, tx: '0xc', block: 1000005),
        ],
        onRequest: (body) {
          if (body['method'] == 'eth_getLogs') {
            cursors.add(
              ((body['params'] as List).first as Map)['fromBlock'] as String,
            );
          }
        },
      ),
    ).sync(wallet);

    expect(second.imported, 1);
    // Continues right after the saved cursor (head = 1000000).
    expect(cursors.first, '0x${1000001.toRadixString(16)}');
    expect(await repo.balance(wallet.id), closeTo(60, 1e-9));
    expect((await repo.load(wallet.id)).where((e) => e.isOpening), isEmpty);
  });

  test('legacy initial balance entry is reused as opening', () async {
    await repo.add(
      CryptoEntry(
        id: 'legacy',
        walletId: wallet.id,
        type: CashEntryType.income,
        amount: 999,
        description: 'Saldo inicial',
        createdAt: wallet.createdAt,
      ),
    );
    await _service(_fakeBsc(balance: 30, logs: [])).sync(wallet);

    final entries = await repo.load(wallet.id);
    expect(entries, hasLength(1));
    expect(entries.single.id, 'legacy');
    expect(entries.single.isOpening, isTrue);
    expect(entries.single.amount, closeTo(30, 1e-9));
  });

  test('concurrent syncs of the same wallet run once', () async {
    var logCalls = 0;
    final service = _service(
      _fakeBsc(
        balance: 50,
        logs: [_log(from: _other, to: _me, amount: 50, tx: '0xa')],
        onRequest: (body) {
          if (body['method'] == 'eth_getLogs') logCalls++;
        },
      ),
    );
    await Future.wait([service.sync(wallet), service.sync(wallet)]);
    expect(
      (await repo.load(wallet.id)).where((e) => e.isImported),
      hasLength(1),
    );
    // 400k lookback / 49,999 per request = 9 chunks × (incoming + outgoing).
    expect(logCalls, 18);
  });

  test('Tron: full history on first sync, opening becomes zero', () async {
    const tronMe = 'TV6MuMXfmLbBqPZvBHdwFsDnQeVfnmiuSi';
    const tronOther = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
    final tronWallet = CryptoWallet.create(
      name: 'Tron',
      networkId: 'trc20',
      tokenSymbol: 'USDT',
      address: tronMe,
    );
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/transactions/trc20')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'transaction_id': 't1',
                'from': tronOther,
                'to': tronMe,
                'value': '25000000',
                'block_timestamp': 1790000000000,
              },
            ],
            'meta': {},
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': [
            {
              'trc20': [
                {'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t': '25000000'},
              ],
            },
          ],
        }),
        200,
      );
    });

    final result = await _service(client).sync(tronWallet);
    expect(result.imported, 1);
    final entries = await repo.load(tronWallet.id);
    expect(entries.single.amount, 25);
    expect(entries.where((e) => e.isOpening), isEmpty);
    expect(
      await const CryptoSyncStateRepository().loadCursor(tronWallet.id),
      1790000000000,
    );
  });

  test('network without history only sets the opening once', () async {
    final arb = CryptoWallet.create(
      name: 'Arb',
      networkId: 'arbitrum',
      tokenSymbol: 'USDT',
      address: _me,
    );
    await _service(_fakeBsc(balance: 40, logs: [], decimals: 6)).sync(arb);
    expect(await repo.balance(arb.id), closeTo(40, 1e-9));

    final second = await _service(
      _fakeBsc(balance: 55, logs: [], decimals: 6),
    ).sync(arb);
    expect(second.onChainBalance, 55);
    // Not auto-adjusted: the difference is shown to the user.
    expect(await repo.balance(arb.id), closeTo(40, 1e-9));
  });
}
