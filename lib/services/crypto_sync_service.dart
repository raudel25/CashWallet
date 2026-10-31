import '../data/crypto_entry_repository.dart';
import '../data/crypto_sync_state_repository.dart';
import '../models/cash_entry.dart';
import '../models/crypto_entry.dart';
import '../models/crypto_wallet.dart';
import 'chain_balance_service.dart';
import 'chain_history_service.dart';

class WalletSyncResult {
  const WalletSyncResult({
    this.onChainBalance,
    this.imported = 0,
    this.truncated = false,
    this.historyFailed = false,
  });

  /// Null when the wallet has no address or the balance couldn't be read.
  final double? onChainBalance;

  /// New movements imported from the blockchain.
  final int imported;

  /// Some transfers may be missing because the gap since the last sync was
  /// too large; the difference shows up as out of sync.
  final bool truncated;

  /// The balance was read but importing transfers failed.
  final bool historyFailed;
}

/// Reads the on-chain balance and imports new transfers as movements.
///
/// The first sync of a wallet also recomputes its opening balance so that
/// opening + imported movements = on-chain balance. Later syncs only add
/// new transfers.
class CryptoSyncService {
  CryptoSyncService({
    required this.balanceService,
    required this.historyService,
    required this.entryRepository,
    required this.syncStateRepository,
  });

  final ChainBalanceService balanceService;
  final ChainHistoryService historyService;
  final CryptoEntryRepository entryRepository;
  final CryptoSyncStateRepository syncStateRepository;

  // Several screens may sync the same wallet at once; share one run so
  // transfers aren't imported twice.
  final Map<String, Future<WalletSyncResult>> _inFlight = {};

  Future<WalletSyncResult> sync(CryptoWallet wallet) {
    return _inFlight[wallet.id] ??= _sync(wallet).whenComplete(() {
      // Block body on purpose: returning the removed future would make
      // whenComplete wait on itself forever.
      _inFlight.remove(wallet.id);
    });
  }

  Future<WalletSyncResult> _sync(CryptoWallet wallet) async {
    final network = wallet.network;
    if (wallet.address == null || network == null) {
      return const WalletSyncResult();
    }

    final double balance;
    try {
      balance = await balanceService.fetchBalance(wallet);
    } on ChainBalanceException {
      return const WalletSyncResult();
    }

    final cursor = await syncStateRepository.loadCursor(wallet.id);
    ChainHistoryResult? history;
    if (network.supportsHistory) {
      try {
        history = await historyService.fetchTransfers(wallet, cursor: cursor);
      } on ChainBalanceException {
        return WalletSyncResult(onChainBalance: balance, historyFailed: true);
      }
    } else if (cursor != null) {
      // No history and already set up: nothing to import.
      return WalletSyncResult(onChainBalance: balance);
    }

    final entries = await entryRepository.load(wallet.id);
    final known = entries.map((entry) => entry.txHash).nonNulls.toSet();
    final imported = [
      for (final transfer in history?.transfers ?? const <ChainTransfer>[])
        // `add` also drops duplicates within the same batch.
        if (known.add(transfer.id))
          CryptoEntry.create(
            walletId: wallet.id,
            type: transfer.incoming
                ? CashEntryType.income
                : CashEntryType.expense,
            amount: transfer.amount,
            description: '',
            createdAt: transfer.timestamp,
            txHash: transfer.id,
            counterparty: transfer.counterparty,
          ),
    ];

    var all = [...imported, ...entries];
    if (cursor == null) {
      all = rebalanceOpening(
        wallet: wallet,
        entries: all,
        onChainBalance: balance,
        windowStart: history?.windowStart,
      );
    }
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await entryRepository.save(wallet.id, all);
    await syncStateRepository.saveCursor(wallet.id, history?.cursor ?? 0);

    return WalletSyncResult(
      onChainBalance: balance,
      imported: imported.length,
      truncated: history?.truncated ?? false,
    );
  }

  /// Sets the opening entry so the recorded balance equals [onChainBalance],
  /// dated just before the oldest tracked movement.
  static List<CryptoEntry> rebalanceOpening({
    required CryptoWallet wallet,
    required List<CryptoEntry> entries,
    required double onChainBalance,
    DateTime? windowStart,
  }) {
    CryptoEntry? opening;
    for (final entry in entries) {
      // Entries created before the isOpening flag existed were dated exactly
      // at the wallet's creation.
      final legacyOpening =
          !entry.isImported &&
          entry.type == CashEntryType.income &&
          entry.createdAt == wallet.createdAt;
      // Imported movements marked as opening keep their on-chain amount.
      if ((entry.isOpening && !entry.isImported) || legacyOpening) {
        opening = entry;
        break;
      }
    }
    final others = entries.where((entry) => entry != opening).toList();
    final amount =
        onChainBalance -
        others.fold<double>(0, (sum, entry) => sum + entry.signedAmount);

    final dates = [
      windowStart,
      opening?.createdAt,
      for (final entry in others)
        if (entry.isImported) entry.createdAt,
    ].nonNulls;
    final date = dates.isEmpty
        ? wallet.createdAt
        : dates
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .subtract(const Duration(seconds: 1));

    if (tokenAmountsMatch(amount, 0)) return others;
    final type = amount > 0 ? CashEntryType.income : CashEntryType.expense;
    final updated =
        opening?.copyWith(
          type: type,
          amount: amount.abs(),
          description: '',
          createdAt: date,
          isOpening: true,
        ) ??
        CryptoEntry.create(
          walletId: wallet.id,
          type: type,
          amount: amount.abs(),
          description: '',
          createdAt: date,
          isOpening: true,
        );
    return [updated, ...others];
  }
}
