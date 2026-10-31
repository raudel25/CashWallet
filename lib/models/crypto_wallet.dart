import 'dart:convert';

import 'crypto_entry.dart';
import 'crypto_network.dart';

class CryptoWallet {
  const CryptoWallet({
    required this.id,
    required this.name,
    required this.networkId,
    required this.tokenSymbol,
    required this.createdAt,
    this.address,
  });

  final String id;
  final String name;
  final String networkId;
  final String tokenSymbol;
  final DateTime createdAt;

  /// Public address, used later to read the balance on-chain. Optional.
  final String? address;

  CryptoNetwork? get network => CryptoNetworks.byId(networkId);

  /// e.g. "USDT · BEP20"
  String get label => '$tokenSymbol · ${network?.standard ?? networkId}';

  String? get shortAddress {
    final value = address;
    return value == null ? null : shortenAddress(value);
  }

  factory CryptoWallet.create({
    required String name,
    required String networkId,
    required String tokenSymbol,
    String? address,
  }) {
    final now = DateTime.now();
    return CryptoWallet(
      id: now.microsecondsSinceEpoch.toString(),
      name: name.trim(),
      networkId: networkId,
      tokenSymbol: tokenSymbol,
      createdAt: now,
      address: _normalizeAddress(address),
    );
  }

  factory CryptoWallet.fromJson(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return CryptoWallet(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      networkId: data['networkId'] as String,
      tokenSymbol: data['tokenSymbol'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      address: data['address'] as String?,
    );
  }

  String toJson() => jsonEncode({
    'id': id,
    'name': name,
    'networkId': networkId,
    'tokenSymbol': tokenSymbol,
    'createdAt': createdAt.toIso8601String(),
    'address': address,
  });

  CryptoWallet copyWith({
    String? name,
    String? networkId,
    String? tokenSymbol,
    String? address,
  }) {
    return CryptoWallet(
      id: id,
      name: name?.trim() ?? this.name,
      networkId: networkId ?? this.networkId,
      tokenSymbol: tokenSymbol ?? this.tokenSymbol,
      createdAt: createdAt,
      address: address == null ? this.address : _normalizeAddress(address),
    );
  }

  static String? _normalizeAddress(String? address) {
    final trimmed = address?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
