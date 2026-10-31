import 'package:cash_wallet/data/cash_entry_repository.dart';
import 'package:cash_wallet/data/crypto_entry_repository.dart';
import 'package:cash_wallet/data/crypto_wallet_repository.dart';
import 'package:cash_wallet/models/cash_entry.dart';
import 'package:cash_wallet/models/crypto_entry.dart';
import 'package:cash_wallet/models/crypto_wallet.dart';
import 'package:cash_wallet/services/crypto_sync_service.dart';
import 'package:cash_wallet/services/currency_service.dart';
import 'package:cash_wallet/services/exchange_rate_service.dart';
import 'package:cash_wallet/services/finance_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const cryptoEntries = CryptoEntryRepository();
  final incomes = CashEntryRepository('cash_wallet_incomes');
  final expenses = CashEntryRepository('cash_wallet_expenses');

  Future<FinanceSummary> loadSummary() => FinanceSummaryService(
    incomeRepository: incomes,
    expenseRepository: expenses,
    currencyService: CurrencyService(),
    walletRepository: const CryptoWalletRepository(),
    cryptoEntryRepository: cryptoEntries,
    exchangeRateService: ExchangeRateService(
      client: MockClient((_) async => http.Response('', 500)),
    ),
  ).load();

  test('cash opening keeps the balance but is not income', () async {
    final now = DateTime.now();
    final entry = CashEntry(
      id: 'start',
      type: CashEntryType.income,
      amount: 5000,
      description: 'Lo que tenía',
      createdAt: now,
      currencyCode: 'USD',
    );
    await incomes.add('USD', entry.copyWith(isOpening: true));
    await incomes.add(
      'USD',
      CashEntry(
        id: 'salary',
        type: CashEntryType.income,
        amount: 800,
        description: '',
        createdAt: now,
        currencyCode: 'USD',
      ),
    );

    final restored = (await incomes.load(
      'USD',
    )).firstWhere((e) => e.id == 'start');
    expect(restored.isOpening, isTrue);
    // Editing keeps the flag.
    expect(restored.copyWith(description: 'x').isOpening, isTrue);

    final summary = await loadSummary();
    expect(summary.cashUsd, 5800);
    expect(summary.currentMonth.incomes, 800);
  });

  test('legacy "Adjust" entries are treated as opening balance', () async {
    final wallet = CryptoWallet.create(
      name: 'Trust',
      networkId: 'bep20',
      tokenSymbol: 'USDT',
    );
    await const CryptoWalletRepository().add(wallet);
    await cryptoEntries.add(
      CryptoEntry.create(
        walletId: wallet.id,
        type: CashEntryType.income,
        amount: 1500,
        description: 'Ajuste de sincronización',
        createdAt: DateTime.now(),
      ),
    );

    final loaded = await cryptoEntries.load(wallet.id);
    expect(loaded.single.isOpening, isTrue);

    final summary = await loadSummary();
    expect(summary.cryptoUsd, 1500);
    expect(summary.currentMonth.incomes, 0);
  });

  test('adjusting changes the opening, never imported amounts', () {
    final wallet = CryptoWallet.create(
      name: 'Trust',
      networkId: 'bep20',
      tokenSymbol: 'USDT',
    );
    final importedOpening = CryptoEntry.create(
      walletId: wallet.id,
      type: CashEntryType.income,
      amount: 100,
      description: '',
      createdAt: DateTime(2026, 10, 1),
      txHash: '0xa:1',
      isOpening: true,
    );
    final rebalanced = CryptoSyncService.rebalanceOpening(
      wallet: wallet,
      entries: [importedOpening],
      onChainBalance: 130,
    );
    expect(
      rebalanced.firstWhere((e) => e.isImported).amount,
      100,
      reason: 'imported amounts mirror the blockchain',
    );
    final opening = rebalanced.firstWhere((e) => !e.isImported);
    expect(opening.isOpening, isTrue);
    expect(opening.amount, closeTo(30, 1e-9));
  });
}
