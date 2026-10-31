import 'dart:convert';

import 'denomination_count.dart';

enum CashEntryType { income, expense }

class CashEntry {
  const CashEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.currencyCode,
    this.breakdown = const [],
    this.transferId,
    this.isOpening = false,
  });

  final String id;
  final CashEntryType type;
  final double amount;
  final String description;
  final DateTime createdAt;
  final String currencyCode;
  final List<DenominationCount> breakdown;

  /// Set when this entry is one side of a transfer between accounts; both
  /// sides share the id and don't count as income or expense.
  final String? transferId;

  /// Cash the user already had when starting to use the app. Counts in the
  /// balance but not as income in the summary or projections.
  final bool isOpening;

  factory CashEntry.createIncome({
    required List<DenominationCount> breakdown,
    required String description,
    required String currencyCode,
  }) {
    final now = DateTime.now();
    final sanitized = breakdown.where((item) => item.quantity > 0).toList();
    final total = sanitized.fold<double>(
      0,
      (sum, item) => sum + item.totalValue,
    );
    return CashEntry(
      id: now.microsecondsSinceEpoch.toString(),
      type: CashEntryType.income,
      amount: total,
      description: description.trim(),
      breakdown: sanitized,
      createdAt: now,
      currencyCode: currencyCode,
    );
  }

  factory CashEntry.createExpense({
    required List<DenominationCount> breakdown,
    required String description,
    required String currencyCode,
  }) {
    final now = DateTime.now();
    final sanitized = breakdown.where((item) => item.quantity > 0).toList();
    final total = sanitized.fold<double>(
      0,
      (sum, item) => sum + item.totalValue,
    );
    return CashEntry(
      id: now.microsecondsSinceEpoch.toString(),
      type: CashEntryType.expense,
      amount: total,
      description: description.trim(),
      breakdown: sanitized,
      createdAt: now,
      currencyCode: currencyCode,
    );
  }

  factory CashEntry.fromJson(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final breakdownJson =
        (data['breakdown'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
    return CashEntry(
      id: data['id'] as String,
      type: _typeFromString(data['type'] as String? ?? 'income'),
      amount: (data['amount'] as num).toDouble(),
      description: data['description'] as String? ?? '',
      createdAt: DateTime.parse(data['createdAt'] as String),
      currencyCode: data['currencyCode'] as String? ?? 'USD',
      breakdown: breakdownJson
          .map(DenominationCount.fromJson)
          .toList(growable: false),
      transferId: data['transferId'] as String?,
      isOpening: data['isOpening'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode({
    'id': id,
    'type': type.name,
    'amount': amount,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'currencyCode': currencyCode,
    'breakdown': breakdown.map((item) => item.toJson()).toList(),
    if (transferId != null) 'transferId': transferId,
    if (isOpening) 'isOpening': true,
  });

  CashEntry copyWith({
    String? description,
    DateTime? createdAt,
    List<DenominationCount>? breakdown,
    bool? isOpening,
  }) {
    final newBreakdown = breakdown ?? this.breakdown;
    final newAmount = breakdown == null
        ? amount
        : newBreakdown.fold<double>(0, (sum, item) => sum + item.totalValue);
    return CashEntry(
      id: id,
      type: type,
      amount: newAmount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      currencyCode: currencyCode,
      breakdown: newBreakdown,
      transferId: transferId,
      isOpening: isOpening ?? this.isOpening,
    );
  }

  static CashEntryType _typeFromString(String raw) {
    return CashEntryType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => CashEntryType.income,
    );
  }
}
