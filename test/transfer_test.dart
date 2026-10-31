import 'package:cash_wallet/app.dart';
import 'package:cash_wallet/data/cash_entry_repository.dart';
import 'package:cash_wallet/data/crypto_entry_repository.dart';
import 'package:cash_wallet/data/crypto_wallet_repository.dart';
import 'package:cash_wallet/data/denomination_repository.dart';
import 'package:cash_wallet/models/cash_entry.dart';
import 'package:cash_wallet/models/crypto_entry.dart';
import 'package:cash_wallet/models/crypto_wallet.dart';
import 'package:cash_wallet/models/denomination.dart';
import 'package:cash_wallet/models/denomination_count.dart';
import 'package:cash_wallet/services/currency_service.dart';
import 'package:cash_wallet/services/finance_summary_service.dart';
import 'package:cash_wallet/services/transfer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final incomes = CashEntryRepository('cash_wallet_incomes');
  final expenses = CashEntryRepository('cash_wallet_expenses');
  const cryptoEntries = CryptoEntryRepository();
  const wallets = CryptoWalletRepository();

  TransferService service() => TransferService(
    incomeRepository: incomes,
    expenseRepository: expenses,
    denominationRepository: const DenominationRepository(),
    currencyService: CurrencyService(),
    walletRepository: wallets,
    cryptoEntryRepository: cryptoEntries,
  );

  Future<CryptoWallet> addWallet({String? address}) async {
    final wallet = CryptoWallet.create(
      name: 'Trust',
      networkId: 'bep20',
      tokenSymbol: 'USDT',
      address: address,
    );
    await wallets.add(wallet);
    return wallet;
  }

  test('accounts: cash with denominations and every wallet', () async {
    await const DenominationRepository().save('USD', const [
      Denomination(20),
      Denomination(100),
    ]);
    await addWallet();
    final accounts = await service().loadAccounts();
    expect(accounts.map((a) => a.id).first, 'cash:USD');
    expect(accounts.whereType<CryptoTransferAccount>(), hasLength(1));
    // Currencies without denominations can't receive bills.
    expect(accounts.any((a) => a.id == 'cash:MXN'), isFalse);
  });

  test('manual wallet → cash creates both legs with a shared id', () async {
    final wallet = await addWallet();
    await cryptoEntries.add(
      CryptoEntry.create(
        walletId: wallet.id,
        type: CashEntryType.income,
        amount: 200,
        description: '',
        createdAt: DateTime(2026, 10, 1),
      ),
    );
    final cash = CashTransferAccount(
      CurrencyService().availableCurrencies.first,
      const [Denomination(20)],
    );
    await service().create(
      from: CryptoTransferAccount(wallet),
      fromLeg: const NewCryptoLeg(100),
      to: cash,
      toLeg: const CashLeg([DenominationCount(denomination: 20, quantity: 4)]),
      date: DateTime(2026, 10, 10),
      fromDescription: 'to cash',
      toDescription: 'from Trust',
    );

    final cryptoLeg = (await cryptoEntries.load(
      wallet.id,
    )).firstWhere((e) => e.isTransfer);
    final cashLeg = (await incomes.load('USD')).single;
    expect(cryptoLeg.type, CashEntryType.expense);
    expect(cryptoLeg.amount, 100);
    expect(cashLeg.amount, 80);
    expect(cashLeg.breakdown.single.quantity, 4);
    expect(cashLeg.transferId, cryptoLeg.transferId);
    expect(await cryptoEntries.balance(wallet.id), 100);
    expect(await service().loadCashStock('USD'), {20.0: 4});
  });

  test(
    'synced wallet links the imported movement instead of adding one',
    () async {
      final wallet = await addWallet(
        address: '0x1111111111111111111111111111111111111111',
      );
      final imported = CryptoEntry.create(
        walletId: wallet.id,
        type: CashEntryType.expense,
        amount: 50,
        description: '',
        createdAt: DateTime(2026, 10, 5),
        txHash: '0xabc:1',
        counterparty: '0x2222222222222222222222222222222222222222',
      );
      await cryptoEntries.add(imported);

      final linkable = await service().loadLinkableEntries(
        wallet.id,
        outgoing: true,
      );
      expect(linkable.single.id, imported.id);
      expect(
        await service().loadLinkableEntries(wallet.id, outgoing: false),
        isEmpty,
      );

      await service().create(
        from: CryptoTransferAccount(wallet),
        fromLeg: LinkedCryptoLeg(imported),
        to: CashTransferAccount(
          CurrencyService().availableCurrencies.first,
          const [Denomination(50)],
        ),
        toLeg: const CashLeg([
          DenominationCount(denomination: 50, quantity: 1),
        ]),
        date: imported.createdAt,
        fromDescription: 'Transfer to Cash USD',
        toDescription: 'Transfer from Trust',
      );

      final entries = await cryptoEntries.load(wallet.id);
      expect(entries, hasLength(1));
      expect(entries.single.isTransfer, isTrue);
      expect(entries.single.txHash, '0xabc:1');
      expect(entries.single.description, 'Transfer to Cash USD');
      // Already linked: not offered again.
      expect(
        await service().loadLinkableEntries(wallet.id, outgoing: true),
        isEmpty,
      );
    },
  );

  group('summary', () {
    final day = DateTime(2026, 10, 10);
    test('a complete transfer only counts its cost', () {
      final movements = FinanceSummaryService.transferMovements([
        [TransferLegUsd(day, 100, true), TransferLegUsd(day, 98, false)],
        [TransferLegUsd(day, 50, true), TransferLegUsd(day, 50, false)],
      ]);
      expect(movements, hasLength(1));
      expect(movements.single.amountUsd, closeTo(2, 1e-9));
      expect(movements.single.isIncome, isFalse);
      expect(movements.single.isTransferCost, isTrue);
    });

    test('a transfer missing one side counts as a normal movement', () {
      final movements = FinanceSummaryService.transferMovements([
        [TransferLegUsd(day, 70, true)],
      ]);
      expect(movements.single.amountUsd, 70);
      expect(movements.single.isTransferCost, isFalse);
    });

    test('a side without exchange rate leaves the cost out', () {
      final movements = FinanceSummaryService.transferMovements([
        [TransferLegUsd(day, 100, true), TransferLegUsd(day, null, false)],
      ]);
      expect(movements, isEmpty);
    });

    test('monthly expenses include fees but not transferred amounts', () {
      final now = DateTime(2026, 10, 20);
      final summary = FinanceSummaryService.compute(
        accounts: const [],
        movements: [
          FinanceMovement(date: day, amountUsd: 30, isIncome: false),
          ...FinanceSummaryService.transferMovements([
            [TransferLegUsd(day, 100, true), TransferLegUsd(day, 97, false)],
          ]),
        ],
        missingRates: const {},
        now: now,
      );
      expect(summary.currentMonth.expenses, closeTo(33, 1e-9));
      expect(summary.currentMonth.incomes, 0);
      expect(summary.currentMonthTransferCostsUsd, closeTo(3, 1e-9));
    });
  });

  testWidgets('summary tab offers the transfer form', (tester) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    final button = find.text('Transferir').evaluate().isNotEmpty
        ? find.text('Transferir')
        : find.text('Transfer');
    await tester.tap(button.first);
    await tester.pumpAndSettle();

    expect(
      find.text('Desde').evaluate().isNotEmpty ||
          find.text('From').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
  });
}
