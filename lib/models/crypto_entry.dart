import 'dart:convert';

import 'cash_entry.dart';

class CryptoEntry {
  const CryptoEntry({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.txHash,
    this.counterparty,
    this.isOpening = false,
    this.transferId,
  });

  final String id;
  final String walletId;
  final CashEntryType type;
  final double amount;
  final String description;
  final DateTime createdAt;

  /// On-chain transaction hash, set when imported from the blockchain.
  /// Used to avoid importing the same transaction twice.
  final String? txHash;

  /// Other side of an imported transfer (sender for incomes, recipient for
  /// expenses).
  final String? counterparty;

  /// Initial balance of the wallet: what it held before the first movement
  /// tracked by the app. Recomputed on the first blockchain sync.
  final bool isOpening;

  /// Set when this entry is one side of a transfer between accounts.
  final String? transferId;

  bool get isTransfer => transferId != null;

  bool get isImported => txHash != null;

  double get signedAmount => type == CashEntryType.income ? amount : -amount;

  factory CryptoEntry.create({
    required String walletId,
    required CashEntryType type,
    required double amount,
    required String description,
    required DateTime createdAt,
    String? txHash,
    String? counterparty,
    bool isOpening = false,
    String? transferId,
  }) {
    return CryptoEntry(
      // Imported entries are created in batches, so the hash keeps ids unique.
      id: txHash ?? DateTime.now().microsecondsSinceEpoch.toString(),
      walletId: walletId,
      type: type,
      amount: amount,
      description: description.trim(),
      createdAt: createdAt,
      txHash: txHash,
      counterparty: counterparty,
      isOpening: isOpening,
      transferId: transferId,
    );
  }

  factory CryptoEntry.fromJson(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return CryptoEntry(
      id: data['id'] as String,
      walletId: data['walletId'] as String,
      type: CashEntryType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => CashEntryType.income,
      ),
      amount: (data['amount'] as num).toDouble(),
      description: data['description'] as String? ?? '',
      createdAt: DateTime.parse(data['createdAt'] as String),
      txHash: data['txHash'] as String?,
      counterparty: data['counterparty'] as String?,
      isOpening: data['isOpening'] as bool? ?? false,
      transferId: data['transferId'] as String?,
    );
  }

  String toJson() => jsonEncode({
    'id': id,
    'walletId': walletId,
    'type': type.name,
    'amount': amount,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'txHash': txHash,
    'counterparty': counterparty,
    'isOpening': isOpening,
    'transferId': transferId,
  });

  CryptoEntry copyWith({
    CashEntryType? type,
    double? amount,
    String? description,
    DateTime? createdAt,
    bool? isOpening,
    String? transferId,
  }) {
    return CryptoEntry(
      id: id,
      walletId: walletId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description?.trim() ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      txHash: txHash,
      counterparty: counterparty,
      isOpening: isOpening ?? this.isOpening,
      transferId: transferId ?? this.transferId,
    );
  }
}

/// Formats token amounts with 2 decimals, keeping up to 6 when significant
/// (e.g. 12.50, 12.3456).
String formatTokenAmount(double value) {
  return value.toStringAsFixed(6).replaceFirst(RegExp(r'0{1,4}$'), '');
}

/// Whether two token amounts are equal at cent precision.
bool tokenAmountsMatch(double a, double b) => (a - b).abs() < 0.005;

/// Shortens an address for display, e.g. "0x55d3…7955".
String shortenAddress(String address) {
  if (address.length < 12) return address;
  return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
}
