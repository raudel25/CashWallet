import 'dart:convert';

import 'package:cash_wallet/data/cash_entry_repository.dart';
import 'package:cash_wallet/data/crypto_entry_repository.dart';
import 'package:cash_wallet/data/crypto_wallet_repository.dart';
import 'package:cash_wallet/models/cash_entry.dart';
import 'package:cash_wallet/models/crypto_entry.dart';
import 'package:cash_wallet/models/crypto_wallet.dart';
import 'package:cash_wallet/models/denomination_count.dart';
import 'package:cash_wallet/services/currency_service.dart';
import 'package:cash_wallet/services/exchange_rate_service.dart';
import 'package:cash_wallet/services/finance_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

FinanceMovement _m(DateTime date, double usd, {bool income = false}) =>
    FinanceMovement(date: date, amountUsd: usd, isIncome: income);

CashEntry _cash(
  CashEntryType type,
  double amount,
  DateTime date,
  String code,
) => CashEntry(
  id: '${date.microsecondsSinceEpoch}$amount',
  type: type,
  amount: amount,
  description: '',
  createdAt: date,
  currencyCode: code,
  breakdown: [DenominationCount(denomination: amount, quantity: 1)],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('compute', () {
    final now = DateTime(2026, 10, 20);

    test('monthly totals, history and pace', () {
      final summary = FinanceSummaryService.compute(
        accounts: const [],
        movements: [
          _m(DateTime(2026, 10, 2), 1000, income: true),
          _m(DateTime(2026, 10, 5), 200),
          _m(DateTime(2026, 9, 10), 150),
          _m(DateTime(2025, 1, 1), 999), // outside the 6-month window
        ],
        missingRates: const {},
        now: now,
      );
      expect(summary.currentMonth.incomes, 1000);
      expect(summary.currentMonth.expenses, 200);
      expect(summary.previousMonth.expenses, 150);
      expect(summary.history, hasLength(6));
      expect(summary.history.first.month, DateTime(2026, 5));
      expect(summary.history.last.month, DateTime(2026, 10));
      // 200 in 20 days → 310 over October's 31 days.
      expect(summary.expensePaceUsd, closeTo(310, 1e-9));
    });

    test('no pace in the first days of the month', () {
      final summary = FinanceSummaryService.compute(
        accounts: const [],
        movements: [_m(DateTime(2026, 10, 1), 50)],
        missingRates: const {},
        now: DateTime(2026, 10, 3),
      );
      expect(summary.expensePaceUsd, isNull);
    });

    test('projection needs a complete month and weights recent ones', () {
      final onlyCurrent = FinanceSummaryService.compute(
        accounts: const [],
        movements: [_m(DateTime(2026, 10, 2), 100)],
        missingRates: const {},
        now: now,
      );
      expect(onlyCurrent.projections, isEmpty);

      const account = FinanceAccount(
        id: 'cash:USD',
        name: 'USD',
        currencyCode: 'USD',
        balance: 1000,
        balanceUsd: 1000,
        isCrypto: false,
      );
      final summary = FinanceSummaryService.compute(
        accounts: [account],
        movements: [
          // Sep: +600 / -300, Aug: +300 / -600 (first month with data).
          _m(DateTime(2026, 9, 1), 600, income: true),
          _m(DateTime(2026, 9, 2), 300),
          _m(DateTime(2026, 8, 1), 300, income: true),
          _m(DateTime(2026, 8, 2), 600),
        ],
        missingRates: const {},
        now: now,
      );
      // July has no data and is before the first movement: 2 months basis.
      expect(summary.projectionBasisMonths, 2);
      // Weighted (3·Sep + 2·Aug) / 5.
      final incomes = (3 * 600 + 2 * 300) / 5;
      final expenses = (3 * 300 + 2 * 600) / 5;
      expect(summary.projections, hasLength(3));
      expect(summary.projections.first.month, DateTime(2026, 11));
      expect(summary.projections.first.incomes, closeTo(incomes, 1e-9));
      expect(summary.projections.first.expenses, closeTo(expenses, 1e-9));
      expect(
        summary.projections.last.balance,
        closeTo(1000 + 3 * (incomes - expenses), 1e-9),
      );
    });

    test('accounts without rate are excluded from totals', () {
      final summary = FinanceSummaryService.compute(
        accounts: const [
          FinanceAccount(
            id: 'cash:USD',
            name: 'USD',
            currencyCode: 'USD',
            balance: 100,
            balanceUsd: 100,
            isCrypto: false,
          ),
          FinanceAccount(
            id: 'cash:CUP',
            name: 'CUP',
            currencyCode: 'CUP',
            balance: 5000,
            isCrypto: false,
          ),
          FinanceAccount(
            id: 'crypto:1',
            name: 'Trust',
            currencyCode: 'USDT',
            balance: 50,
            balanceUsd: 50,
            isCrypto: true,
          ),
        ],
        movements: const [],
        missingRates: const {'CUP'},
        now: now,
      );
      expect(summary.cashUsd, 100);
      expect(summary.cryptoUsd, 50);
      expect(summary.netWorthUsd, 150);
    });
  });

  test('load converts currencies and skips crypto opening balances', () async {
    final now = DateTime.now();
    final incomes = CashEntryRepository('cash_wallet_incomes');
    final expenses = CashEntryRepository('cash_wallet_expenses');
    await incomes.add('USD', _cash(CashEntryType.income, 100, now, 'USD'));
    await incomes.add('MXN', _cash(CashEntryType.income, 2000, now, 'MXN'));
    await expenses.add('MXN', _cash(CashEntryType.expense, 500, now, 'MXN'));

    final wallet = CryptoWallet.create(
      name: 'Trust',
      networkId: 'bep20',
      tokenSymbol: 'USDT',
    );
    await const CryptoWalletRepository().add(wallet);
    const cryptoEntries = CryptoEntryRepository();
    await cryptoEntries.add(
      CryptoEntry.create(
        walletId: wallet.id,
        type: CashEntryType.income,
        amount: 300,
        description: '',
        createdAt: now,
        isOpening: true,
      ),
    );
    await cryptoEntries.add(
      CryptoEntry.create(
        walletId: wallet.id,
        type: CashEntryType.expense,
        amount: 20,
        description: '',
        createdAt: now,
        txHash: '0xabc:1',
      ),
    );

    final rates = ExchangeRateService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'result': 'success',
            'rates': {'USD': 1, 'MXN': 20, 'CUP': 24},
          }),
          200,
        ),
      ),
    );
    // The user trades CUP at the street rate.
    await rates.setManualRate('CUP', 400);

    final summary = await FinanceSummaryService(
      incomeRepository: incomes,
      expenseRepository: expenses,
      currencyService: CurrencyService(),
      walletRepository: const CryptoWalletRepository(),
      cryptoEntryRepository: cryptoEntries,
      exchangeRateService: rates,
    ).load(now: now);

    // Cash: 100 USD + 1500 MXN / 20 = 175. Crypto: 300 - 20 = 280.
    expect(summary.cashUsd, closeTo(175, 1e-9));
    expect(summary.cryptoUsd, closeTo(280, 1e-9));
    expect(summary.netWorthUsd, closeTo(455, 1e-9));
    // Incomes: 100 + 2000/20 (opening excluded). Expenses: 500/20 + 20.
    expect(summary.currentMonth.incomes, closeTo(200, 1e-9));
    expect(summary.currentMonth.expenses, closeTo(45, 1e-9));

    final loaded = await rates.load(refresh: false);
    expect(loaded['CUP']!.rate, 400);
    expect(loaded['CUP']!.manual, isTrue);
    expect(loaded['MXN']!.manual, isFalse);
  });

  test('rates fall back to cache when the API fails', () async {
    final failing = ExchangeRateService(
      client: MockClient((_) async => http.Response('down', 500)),
    );
    final rates = await failing.load();
    expect(rates.keys, ['USD']);
  });
}
