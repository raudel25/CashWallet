import '../data/cash_entry_repository.dart';
import '../data/crypto_entry_repository.dart';
import '../data/crypto_wallet_repository.dart';
import '../models/cash_entry.dart';
import 'currency_service.dart';
import 'exchange_rate_service.dart';

/// A place that holds money: cash in one currency or a crypto wallet.
class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.balance,
    required this.isCrypto,
    this.balanceUsd,
  });

  final String id;
  final String name;

  /// Cash currency (e.g. "MXN") or token (e.g. "USDT").
  final String currencyCode;

  /// In [currencyCode].
  final double balance;

  /// Null when there is no exchange rate for [currencyCode].
  final double? balanceUsd;
  final bool isCrypto;
}

/// A dated income or expense, already converted to USD.
class FinanceMovement {
  const FinanceMovement({
    required this.date,
    required this.amountUsd,
    required this.isIncome,
    this.isTransferCost = false,
  });

  final DateTime date;
  final double amountUsd;
  final bool isIncome;

  /// Value lost (or gained) moving money between accounts: fees, spreads
  /// and exchange differences.
  final bool isTransferCost;
}

/// One side of a transfer, converted to USD.
class TransferLegUsd {
  const TransferLegUsd(this.date, this.amountUsd, this.outgoing);

  final DateTime date;
  final double? amountUsd;
  final bool outgoing;
}

class MonthTotals {
  const MonthTotals({required this.month, this.incomes = 0, this.expenses = 0});

  /// First day of the month.
  final DateTime month;
  final double incomes;
  final double expenses;

  double get net => incomes - expenses;
}

class MonthProjection {
  const MonthProjection({
    required this.month,
    required this.incomes,
    required this.expenses,
    required this.balance,
  });

  final DateTime month;
  final double incomes;
  final double expenses;

  /// Estimated net worth at the end of [month].
  final double balance;
}

class FinanceSummary {
  const FinanceSummary({
    required this.accounts,
    required this.netWorthUsd,
    required this.cashUsd,
    required this.cryptoUsd,
    required this.missingRates,
    required this.currentMonth,
    required this.previousMonth,
    required this.history,
    required this.projections,
    required this.projectionBasisMonths,
    this.expensePaceUsd,
    this.currentMonthTransferCostsUsd = 0,
  });

  final List<FinanceAccount> accounts;
  final double netWorthUsd;
  final double cashUsd;
  final double cryptoUsd;

  /// Currencies with balance or movements but no exchange rate. They are
  /// left out of every USD total.
  final Set<String> missingRates;

  final MonthTotals currentMonth;
  final MonthTotals previousMonth;

  /// Last months, oldest first, including the current one.
  final List<MonthTotals> history;

  /// Next months. Empty until there is at least one complete month of data.
  final List<MonthProjection> projections;

  /// How many complete months the projection averages.
  final int projectionBasisMonths;

  /// Expenses expected by the end of the current month at the current pace.
  /// Null in the first days of the month, when the pace isn't meaningful.
  final double? expensePaceUsd;

  /// Part of this month's expenses that are transfer costs.
  final double currentMonthTransferCostsUsd;
}

/// Loads every account (cash in all currencies + crypto wallets) and builds
/// the unified summary in USD.
class FinanceSummaryService {
  FinanceSummaryService({
    required this.incomeRepository,
    required this.expenseRepository,
    required this.currencyService,
    required this.walletRepository,
    required this.cryptoEntryRepository,
    required this.exchangeRateService,
  });

  final CashEntryRepository incomeRepository;
  final CashEntryRepository expenseRepository;
  final CurrencyService currencyService;
  final CryptoWalletRepository walletRepository;
  final CryptoEntryRepository cryptoEntryRepository;
  final ExchangeRateService exchangeRateService;

  static const historyMonths = 6;
  static const projectionMonths = 3;

  /// Stablecoins are counted 1:1 with USD.
  static const _usdTokens = {'USDT', 'USDC'};

  Future<FinanceSummary> load({DateTime? now}) async {
    final rates = await exchangeRateService.load();
    final accounts = <FinanceAccount>[];
    final movements = <FinanceMovement>[];
    final transfers = <String, List<TransferLegUsd>>{};
    final missing = <String>{};

    double? toUsd(double amount, String code) {
      if (_usdTokens.contains(code)) return amount;
      final rate = rates[code]?.rate;
      if (rate == null || rate <= 0) return null;
      return amount / rate;
    }

    for (final currency in currencyService.availableCurrencies) {
      final incomes = await incomeRepository.load(currency.code);
      final expenses = await expenseRepository.load(currency.code);
      if (incomes.isEmpty && expenses.isEmpty) continue;

      double sum(List<CashEntry> entries) =>
          entries.fold<double>(0, (total, entry) => total + entry.amount);
      final balance = sum(incomes) - sum(expenses);
      final balanceUsd = toUsd(balance, currency.code);
      if (balanceUsd == null) missing.add(currency.code);
      accounts.add(
        FinanceAccount(
          id: 'cash:${currency.code}',
          name: currency.name,
          currencyCode: currency.code,
          balance: balance,
          balanceUsd: balanceUsd,
          isCrypto: false,
        ),
      );
      for (final entry in [...incomes, ...expenses]) {
        // Cash already held before using the app is not income.
        if (entry.isOpening) continue;
        final usd = toUsd(entry.amount, currency.code);
        final transferId = entry.transferId;
        if (transferId != null) {
          transfers
              .putIfAbsent(transferId, () => [])
              .add(
                TransferLegUsd(
                  entry.createdAt,
                  usd,
                  entry.type == CashEntryType.expense,
                ),
              );
          continue;
        }
        if (usd == null) continue;
        movements.add(
          FinanceMovement(
            date: entry.createdAt,
            amountUsd: usd,
            isIncome: entry.type == CashEntryType.income,
          ),
        );
      }
    }

    for (final wallet in await walletRepository.load()) {
      final entries = await cryptoEntryRepository.load(wallet.id);
      final balance = entries.fold<double>(
        0,
        (total, entry) => total + entry.signedAmount,
      );
      final balanceUsd = toUsd(balance, wallet.tokenSymbol);
      if (balanceUsd == null) missing.add(wallet.tokenSymbol);
      accounts.add(
        FinanceAccount(
          id: 'crypto:${wallet.id}',
          name: '${wallet.name} · ${wallet.label}',
          currencyCode: wallet.tokenSymbol,
          balance: balance,
          balanceUsd: balanceUsd,
          isCrypto: true,
        ),
      );
      for (final entry in entries) {
        // The opening balance is money the wallet already had, not income.
        if (entry.isOpening) continue;
        final usd = toUsd(entry.amount, wallet.tokenSymbol);
        final transferId = entry.transferId;
        if (transferId != null) {
          transfers
              .putIfAbsent(transferId, () => [])
              .add(
                TransferLegUsd(
                  entry.createdAt,
                  usd,
                  entry.type == CashEntryType.expense,
                ),
              );
          continue;
        }
        if (usd == null) continue;
        movements.add(
          FinanceMovement(
            date: entry.createdAt,
            amountUsd: usd,
            isIncome: entry.type == CashEntryType.income,
          ),
        );
      }
    }

    movements.addAll(transferMovements(transfers.values));

    return compute(
      accounts: accounts,
      movements: movements,
      missingRates: missing,
      now: now ?? DateTime.now(),
    );
  }

  /// A complete transfer only counts its cost (what left minus what
  /// arrived). A transfer missing one side (e.g. a deleted leg) counts as a
  /// normal income or expense.
  static List<FinanceMovement> transferMovements(
    Iterable<List<TransferLegUsd>> transfers,
  ) {
    final result = <FinanceMovement>[];
    for (final legs in transfers) {
      final out = legs.where((leg) => leg.outgoing).toList();
      final incoming = legs.where((leg) => !leg.outgoing).toList();
      if (out.isEmpty || incoming.isEmpty) {
        for (final leg in legs) {
          final usd = leg.amountUsd;
          if (usd == null) continue;
          result.add(
            FinanceMovement(
              date: leg.date,
              amountUsd: usd,
              isIncome: !leg.outgoing,
            ),
          );
        }
        continue;
      }
      // Without a rate for one side the cost is unknown: leave it out.
      if (legs.any((leg) => leg.amountUsd == null)) continue;
      double sum(List<TransferLegUsd> items) =>
          items.fold<double>(0, (total, leg) => total + leg.amountUsd!);
      final cost = sum(out) - sum(incoming);
      if (cost.abs() < 0.005) continue;
      result.add(
        FinanceMovement(
          date: out.first.date,
          amountUsd: cost.abs(),
          isIncome: cost < 0,
          isTransferCost: true,
        ),
      );
    }
    return result;
  }

  static FinanceSummary compute({
    required List<FinanceAccount> accounts,
    required List<FinanceMovement> movements,
    required Set<String> missingRates,
    required DateTime now,
  }) {
    double sumUsd(Iterable<FinanceAccount> items) =>
        items.fold<double>(0, (total, item) => total + (item.balanceUsd ?? 0));
    final cashUsd = sumUsd(accounts.where((account) => !account.isCrypto));
    final cryptoUsd = sumUsd(accounts.where((account) => account.isCrypto));
    final netWorth = cashUsd + cryptoUsd;

    MonthTotals totalsFor(DateTime month) {
      final next = DateTime(month.year, month.month + 1);
      var incomes = 0.0;
      var expenses = 0.0;
      for (final movement in movements) {
        if (movement.date.isBefore(month) || !movement.date.isBefore(next)) {
          continue;
        }
        if (movement.isIncome) {
          incomes += movement.amountUsd;
        } else {
          expenses += movement.amountUsd;
        }
      }
      return MonthTotals(month: month, incomes: incomes, expenses: expenses);
    }

    final history = [
      for (var i = historyMonths - 1; i >= 0; i--)
        totalsFor(DateTime(now.year, now.month - i)),
    ];

    // Projection: weighted average of the last complete months with data
    // (most recent weighs more), starting from the first month with data.
    final firstMovement = movements.isEmpty
        ? null
        : movements
              .map((movement) => movement.date)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final basis = <MonthTotals>[];
    if (firstMovement != null) {
      final firstMonth = DateTime(firstMovement.year, firstMovement.month);
      for (var i = 1; i <= 3; i++) {
        final month = DateTime(now.year, now.month - i);
        if (month.isBefore(firstMonth)) break;
        basis.add(totalsFor(month));
      }
    }
    final projections = <MonthProjection>[];
    if (basis.isNotEmpty) {
      const weights = [3.0, 2.0, 1.0];
      var weightSum = 0.0;
      var incomes = 0.0;
      var expenses = 0.0;
      for (var i = 0; i < basis.length; i++) {
        weightSum += weights[i];
        incomes += basis[i].incomes * weights[i];
        expenses += basis[i].expenses * weights[i];
      }
      incomes /= weightSum;
      expenses /= weightSum;
      var balance = netWorth;
      for (var i = 1; i <= projectionMonths; i++) {
        balance += incomes - expenses;
        projections.add(
          MonthProjection(
            month: DateTime(now.year, now.month + i),
            incomes: incomes,
            expenses: expenses,
            balance: balance,
          ),
        );
      }
    }

    final current = history.last;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final nextMonth = DateTime(now.year, now.month + 1);
    final transferCosts = movements
        .where(
          (movement) =>
              movement.isTransferCost &&
              !movement.isIncome &&
              !movement.date.isBefore(current.month) &&
              movement.date.isBefore(nextMonth),
        )
        .fold<double>(0, (total, movement) => total + movement.amountUsd);
    final expensePace = now.day >= 5
        ? current.expenses / now.day * daysInMonth
        : null;

    return FinanceSummary(
      accounts: accounts,
      netWorthUsd: netWorth,
      cashUsd: cashUsd,
      cryptoUsd: cryptoUsd,
      missingRates: missingRates,
      currentMonth: current,
      previousMonth: totalsFor(DateTime(now.year, now.month - 1)),
      history: history,
      projections: projections,
      projectionBasisMonths: basis.length,
      expensePaceUsd: expensePace,
      currentMonthTransferCostsUsd: transferCosts,
    );
  }
}
