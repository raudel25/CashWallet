import 'dart:async';

import '../data/cash_entry_repository.dart';
import '../models/cash_entry.dart';

enum DashboardRange { day, week, month }

class DashboardSummary {
  const DashboardSummary({
    required this.totalIncomes,
    required this.totalExpenses,
    required this.previousIncomes,
    required this.previousExpenses,
    required this.totalBalance,
    required this.denominationBalances,
  });

  final double totalIncomes;
  final double totalExpenses;
  final double previousIncomes;
  final double previousExpenses;
  final double totalBalance;
  final List<DenominationBalance> denominationBalances;

  double get net => totalIncomes - totalExpenses;
  double get netPrevious => previousIncomes - previousExpenses;
}

class DenominationBalance {
  const DenominationBalance({required this.value, required this.quantity});

  final double value;
  final int quantity;

  double get amount => value * quantity;
}

class DashboardController {
  DashboardController({
    required CashEntryRepository incomeRepository,
    required CashEntryRepository expenseRepository,
    required String currencyCode,
    required this.onSummaryUpdated,
  }) : _incomeRepository = incomeRepository,
       _expenseRepository = expenseRepository,
       _currencyCode = currencyCode {
    // Subscribe to repository change events and refresh when relevant currency changes.
    _incomeChangesSub = _incomeRepository.changes.listen((code) {
      if (code == _currencyCode) {
        _loadSummary();
      }
    });
    _expenseChangesSub = _expenseRepository.changes.listen((code) {
      if (code == _currencyCode) {
        _loadSummary();
      }
    });
  }

  final CashEntryRepository _incomeRepository;
  final CashEntryRepository _expenseRepository;
  final void Function(DashboardSummary) onSummaryUpdated;
  String _currencyCode;

  DashboardRange range = DashboardRange.month;
  // Removed periodic refresh timer: dashboard updates are triggered from UI lifecycle.
  late final StreamSubscription<String> _incomeChangesSub;
  late final StreamSubscription<String> _expenseChangesSub;

  Future<void> init() async {
    await _loadSummary();
  }

  void dispose() {
    // Nothing to dispose for now.
    _incomeChangesSub.cancel();
    _expenseChangesSub.cancel();
  }

  Future<void> changeRange(DashboardRange newRange) async {
    if (newRange == range) return;
    range = newRange;
    await _loadSummary();
  }

  Future<void> setCurrency(String currencyCode) async {
    if (currencyCode == _currencyCode) return;
    _currencyCode = currencyCode;
    await _loadSummary();
  }

  Future<void> refresh() => _loadSummary();

  Future<void> _loadSummary() async {
    final incomesFuture = _incomeRepository.load(_currencyCode);
    final expensesFuture = _expenseRepository.load(_currencyCode);
    final incomes = await incomesFuture;
    final expenses = await expensesFuture;
    final now = DateTime.now();

    final totalBalance =
        _sumEntries(incomes, DateTime.fromMillisecondsSinceEpoch(0), now) -
        _sumEntries(expenses, DateTime.fromMillisecondsSinceEpoch(0), now);
    final denominations = _calculateDenominationBalances(incomes, expenses);
    final periods = _buildPeriods(now);
    final currentIncomes = _sumEntries(incomes, periods.currentStart, now);
    final previousIncomes = _sumEntries(
      incomes,
      periods.previousStart,
      periods.currentStart,
    );
    final currentExpenses = _sumEntries(expenses, periods.currentStart, now);
    final previousExpenses = _sumEntries(
      expenses,
      periods.previousStart,
      periods.currentStart,
    );

    final summary = DashboardSummary(
      totalIncomes: currentIncomes,
      totalExpenses: currentExpenses,
      previousIncomes: previousIncomes,
      previousExpenses: previousExpenses,
      totalBalance: totalBalance,
      denominationBalances: denominations,
    );
    onSummaryUpdated(summary);
  }

  _Period _buildPeriods(DateTime now) {
    switch (range) {
      case DashboardRange.day:
        final currentStart = DateTime(now.year, now.month, now.day);
        final previousStart = currentStart.subtract(const Duration(days: 1));
        return _Period(
          previousStart: previousStart,
          currentStart: currentStart,
        );
      case DashboardRange.week:
        final weekday = now.weekday;
        final currentStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: weekday - 1));
        final previousStart = currentStart.subtract(const Duration(days: 7));
        return _Period(
          previousStart: previousStart,
          currentStart: currentStart,
        );
      case DashboardRange.month:
        final currentStart = DateTime(now.year, now.month);
        final previousMonth = DateTime(now.year, now.month - 1);
        return _Period(
          previousStart: previousMonth,
          currentStart: currentStart,
        );
    }
  }

  double _sumEntries(List<CashEntry> entries, DateTime from, DateTime to) {
    return entries
        .where(
          (entry) =>
              !entry.createdAt.isBefore(from) && entry.createdAt.isBefore(to),
        )
        .fold<double>(0, (sum, entry) => sum + entry.amount);
  }

  List<DenominationBalance> _calculateDenominationBalances(
    List<CashEntry> incomes,
    List<CashEntry> expenses,
  ) {
    final Map<double, int> counts = {};

    void accumulate(List<CashEntry> entries, int multiplier) {
      for (final entry in entries) {
        for (final breakdown in entry.breakdown) {
          final total =
              (counts[breakdown.denomination] ?? 0) +
              breakdown.quantity * multiplier;
          if (total <= 0) {
            counts.remove(breakdown.denomination);
          } else {
            counts[breakdown.denomination] = total;
          }
        }
      }
    }

    accumulate(incomes, 1);
    accumulate(expenses, -1);

    final balances =
        counts.entries
            .map(
              (entry) =>
                  DenominationBalance(value: entry.key, quantity: entry.value),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return balances;
  }
}

class _Period {
  const _Period({required this.previousStart, required this.currentStart});

  final DateTime previousStart;
  final DateTime currentStart;
}
