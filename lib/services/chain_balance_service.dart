import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/crypto_network.dart';
import '../models/crypto_wallet.dart';

class ChainBalanceException implements Exception {
  ChainBalanceException(this.message);
  final String message;

  @override
  String toString() => 'ChainBalanceException: $message';
}

/// Reads token balances directly from public blockchain nodes. Only the
/// public address is sent; nothing else leaves the device.
class ChainBalanceService {
  ChainBalanceService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  /// Returns the on-chain balance, or throws [ChainBalanceException].
  Future<double> fetchBalance(CryptoWallet wallet) async {
    final address = wallet.address;
    final network = wallet.network;
    final token = network?.token(wallet.tokenSymbol);
    if (address == null || network == null || token == null) {
      throw ChainBalanceException('Wallet has no address or unknown token');
    }

    final BigInt raw;
    try {
      switch (network.family) {
        case ChainFamily.evm:
          raw = await _fetchEvm(network, token, address);
        case ChainFamily.tron:
          raw = await _fetchTron(network, token, address);
      }
    } on ChainBalanceException {
      rethrow;
    } catch (e) {
      throw ChainBalanceException('Request failed: $e');
    }
    return raw / BigInt.from(10).pow(token.decimals);
  }

  /// `eth_call` to the token's `balanceOf(address)`.
  Future<BigInt> _fetchEvm(
    CryptoNetwork network,
    TokenContract token,
    String address,
  ) async {
    final data =
        '0x70a08231'
        '${address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0')}';
    final response = await _client
        .post(
          Uri.parse(network.rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'eth_call',
            'params': [
              {'to': token.address, 'data': data},
              'latest',
            ],
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw ChainBalanceException('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final result = body['result'];
    if (result is! String) {
      throw ChainBalanceException('RPC error: ${body['error']}');
    }
    final hex = result.replaceFirst('0x', '');
    return hex.isEmpty ? BigInt.zero : BigInt.parse(hex, radix: 16);
  }

  /// TronGrid account endpoint, which lists TRC20 balances by contract.
  Future<BigInt> _fetchTron(
    CryptoNetwork network,
    TokenContract token,
    String address,
  ) async {
    final response = await _client
        .get(Uri.parse('${network.rpcUrl}/v1/accounts/$address'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw ChainBalanceException('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accounts = body['data'] as List<dynamic>? ?? [];
    // Accounts that never received funds are not returned.
    if (accounts.isEmpty) return BigInt.zero;
    final trc20 =
        (accounts.first as Map<String, dynamic>)['trc20'] as List<dynamic>? ??
        [];
    for (final item in trc20) {
      final value = (item as Map<String, dynamic>)[token.address];
      if (value != null) return BigInt.parse(value.toString());
    }
    return BigInt.zero;
  }
}
