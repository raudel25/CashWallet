import '../data/cash_entry_repository.dart';
import '../data/crypto_entry_repository.dart';
import '../data/crypto_wallet_repository.dart';
import '../data/denomination_repository.dart';
import '../models/cash_entry.dart';
import '../models/crypto_entry.dart';
import '../models/crypto_wallet.dart';
import '../models/currency.dart';
import '../models/denomination.dart';
import '../models/denomination_count.dart';
import 'currency_service.dart';

/// Somewhere money can be moved from or to.
sealed class TransferAccount {
  const TransferAccount();

  String get id;
  String get unit;
}

class CashTransferAccount extends TransferAccount {
  const CashTransferAccount(this.currency, this.denominations);

  final Currency currency;
  final List<Denomination> denominations;

  @override
  String get id => 'cash:${currency.code}';

  @override
  String get unit => currency.code;
}

class CryptoTransferAccount extends TransferAccount {
  const CryptoTransferAccount(this.wallet);

  final CryptoWallet wallet;

  /// Wallets with an address import their movements from the blockchain, so
  /// a transfer links an imported movement instead of creating one.
  bool get isSynced => wallet.address != null;

  @override
  String get id => 'crypto:${wallet.id}';

  @override
  String get unit => wallet.tokenSymbol;
}

/// One side of a transfer, as entered by the user.
sealed class TransferLeg {
  const TransferLeg();

  double get amount;
}

class CashLeg extends TransferLeg {
  const CashLeg(this.breakdown);

  final List<DenominationCount> breakdown;

  @override
  double get amount =>
      breakdown.fold<double>(0, (sum, item) => sum + item.totalValue);
}

class NewCryptoLeg extends TransferLeg {
  const NewCryptoLeg(this.amount);

  @override
  final double amount;
}

/// An already imported blockchain movement that becomes part of the transfer.
class LinkedCryptoLeg extends TransferLeg {
  const LinkedCryptoLeg(this.entry);

  final CryptoEntry entry;

  @override
  double get amount => entry.amount;
}

class TransferService {
  TransferService({
    required this.incomeRepository,
    required this.expenseRepository,
    required this.denominationRepository,
    required this.currencyService,
    required this.walletRepository,
    required this.cryptoEntryRepository,
  });

  final CashEntryRepository incomeRepository;
  final CashEntryRepository expenseRepository;
  final DenominationRepository denominationRepository;
  final CurrencyService currencyService;
  final CryptoWalletRepository walletRepository;
  final CryptoEntryRepository cryptoEntryRepository;

  /// Cash currencies with denominations configured, then crypto wallets.
  Future<List<TransferAccount>> loadAccounts() async {
    final accounts = <TransferAccount>[];
    for (final currency in currencyService.availableCurrencies) {
      final denominations = await denominationRepository.load(currency.code);
      if (denominations.isEmpty) continue;
      accounts.add(CashTransferAccount(currency, denominations));
    }
    for (final wallet in await walletRepository.load()) {
      accounts.add(CryptoTransferAccount(wallet));
    }
    return accounts;
  }

  /// Bills available per denomination in [currencyCode].
  Future<Map<double, int>> loadCashStock(String currencyCode) async {
    final stock = <double, int>{};
    void accumulate(List<CashEntry> entries, int sign) {
      for (final entry in entries) {
        for (final item in entry.breakdown) {
          stock[item.denomination] =
              (stock[item.denomination] ?? 0) + item.quantity * sign;
        }
      }
    }

    accumulate(await incomeRepository.load(currencyCode), 1);
    accumulate(await expenseRepository.load(currencyCode), -1);
    stock.removeWhere((_, quantity) => quantity <= 0);
    return stock;
  }

  Future<double> loadCryptoBalance(String walletId) =>
      cryptoEntryRepository.balance(walletId);

  /// Imported movements not yet part of a transfer: outgoing for the source
  /// side, incoming for the destination side.
  Future<List<CryptoEntry>> loadLinkableEntries(
    String walletId, {
    required bool outgoing,
  }) async {
    final type = outgoing ? CashEntryType.expense : CashEntryType.income;
    final entries = await cryptoEntryRepository.load(walletId);
    return entries
        .where((entry) => entry.isImported && !entry.isTransfer)
        .where((entry) => entry.type == type)
        .take(30)
        .toList();
  }

  /// Writes both sides of the transfer with a shared id.
  Future<void> create({
    required TransferAccount from,
    required TransferLeg fromLeg,
    required TransferAccount to,
    required TransferLeg toLeg,
    required DateTime date,
    required String fromDescription,
    required String toDescription,
  }) async {
    if (from.id == to.id) {
      throw ArgumentError('Source and destination must differ');
    }
    final transferId = 'tr_${DateTime.now().microsecondsSinceEpoch}';
    await _writeLeg(
      account: from,
      leg: fromLeg,
      outgoing: true,
      transferId: transferId,
      date: date,
      description: fromDescription,
    );
    await _writeLeg(
      account: to,
      leg: toLeg,
      outgoing: false,
      transferId: transferId,
      date: date,
      description: toDescription,
    );
  }

  Future<void> _writeLeg({
    required TransferAccount account,
    required TransferLeg leg,
    required bool outgoing,
    required String transferId,
    required DateTime date,
    required String description,
  }) async {
    final type = outgoing ? CashEntryType.expense : CashEntryType.income;
    switch ((account, leg)) {
      case (CashTransferAccount(:final currency), CashLeg(:final breakdown)):
        final repository = outgoing ? expenseRepository : incomeRepository;
        final sanitized = breakdown.where((item) => item.quantity > 0).toList();
        await repository.add(
          currency.code,
          CashEntry(
            // Suffix keeps ids unique when both legs are cash.
            id: '$transferId${outgoing ? '_out' : '_in'}',
            type: type,
            amount: leg.amount,
            description: description,
            createdAt: date,
            currencyCode: currency.code,
            breakdown: sanitized,
            transferId: transferId,
          ),
        );
      case (CryptoTransferAccount(:final wallet), NewCryptoLeg(:final amount)):
        await cryptoEntryRepository.add(
          CryptoEntry(
            id: '$transferId${outgoing ? '_out' : '_in'}',
            walletId: wallet.id,
            type: type,
            amount: amount,
            description: description,
            createdAt: date,
            transferId: transferId,
          ),
        );
      case (CryptoTransferAccount(), LinkedCryptoLeg(:final entry)):
        await cryptoEntryRepository.update(
          entry.copyWith(
            transferId: transferId,
            description: entry.description.isEmpty
                ? description
                : entry.description,
          ),
        );
      default:
        throw ArgumentError('Leg does not match account type');
    }
  }
}
