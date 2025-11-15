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
    this.breakdown = const [],
  });

  final String id;
  final CashEntryType type;
  final double amount;
  final String description;
  final DateTime createdAt;
  final List<DenominationCount> breakdown;

  factory CashEntry.createIncome({
    required List<DenominationCount> breakdown,
    required String description,
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
    );
  }

  factory CashEntry.createExpense({
    required List<DenominationCount> breakdown,
    required String description,
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
      breakdown: breakdownJson
          .map(DenominationCount.fromJson)
          .toList(growable: false),
    );
  }

  String toJson() => jsonEncode({
    'id': id,
    'type': type.name,
    'amount': amount,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'breakdown': breakdown.map((item) => item.toJson()).toList(),
  });

  static CashEntryType _typeFromString(String raw) {
    return CashEntryType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => CashEntryType.income,
    );
  }
}
