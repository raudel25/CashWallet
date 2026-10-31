import 'package:flutter/material.dart';

import '../../data/crypto_entry_repository.dart';
import '../../data/crypto_wallet_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/cash_entry.dart';
import '../../models/crypto_entry.dart';
import '../../models/crypto_wallet.dart';
import '../../services/crypto_sync_service.dart';
import '../../services/transfer_service.dart';
import '../widgets/crypto_wallet_form_sheet.dart';
import 'crypto_wallet_page.dart';

class CryptoPage extends StatefulWidget {
  const CryptoPage({
    super.key,
    required this.walletRepository,
    required this.entryRepository,
    required this.syncService,
    required this.transferService,
    required this.onTransferSaved,
  });

  final CryptoWalletRepository walletRepository;
  final CryptoEntryRepository entryRepository;
  final CryptoSyncService syncService;
  final TransferService transferService;

  /// Transfers also change cash: lets the home page refresh other tabs.
  final Future<void> Function() onTransferSaved;

  @override
  CryptoPageState createState() => CryptoPageState();
}

class CryptoPageState extends State<CryptoPage> {
  List<CryptoWallet> _wallets = [];
  Map<String, double> _balances = {};

  /// On-chain balances for wallets with an address. Missing when the read
  /// failed or is still in progress.
  Map<String, double> _onChain = {};
  bool _isLoading = true;

  /// What the user actually holds: on-chain when known, recorded otherwise.
  double _displayBalance(CryptoWallet wallet) =>
      _onChain[wallet.id] ?? _balances[wallet.id] ?? 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final wallets = await widget.walletRepository.load();
    final balances = <String, double>{
      for (final wallet in wallets)
        wallet.id: await widget.entryRepository.balance(wallet.id),
    };
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _balances = balances;
      _isLoading = false;
    });
    await _syncOnChain(wallets);
  }

  Future<void> _syncOnChain(List<CryptoWallet> wallets) async {
    final withAddress = wallets.where((wallet) => wallet.address != null);
    final results = await Future.wait(
      withAddress.map((wallet) async {
        final result = await widget.syncService.sync(wallet);
        final balance = result.onChainBalance;
        return balance == null ? null : MapEntry(wallet.id, balance);
      }),
    );
    // Syncing may have imported movements: reload recorded balances.
    final balances = <String, double>{
      for (final wallet in wallets)
        wallet.id: await widget.entryRepository.balance(wallet.id),
    };
    if (!mounted) return;
    setState(() {
      _onChain = Map.fromEntries(results.nonNulls);
      _balances = balances;
    });
  }

  Future<void> addWallet() async {
    final result = await showModalBottomSheet<CryptoWalletFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CryptoWalletFormSheet(),
    );
    if (result == null) return;

    await widget.walletRepository.add(result.wallet);
    // With an address, the first sync recomputes this from the blockchain.
    if (result.initialBalance > 0) {
      await widget.entryRepository.add(
        CryptoEntry.create(
          walletId: result.wallet.id,
          type: CashEntryType.income,
          amount: result.initialBalance,
          description: '',
          createdAt: result.wallet.createdAt,
          isOpening: true,
        ),
      );
    }
    await refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('crypto_wallet_saved'))));
  }

  Future<void> _openWallet(CryptoWallet wallet) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CryptoWalletPage(
          wallet: wallet,
          walletRepository: widget.walletRepository,
          entryRepository: widget.entryRepository,
          syncService: widget.syncService,
          transferService: widget.transferService,
          onTransferSaved: widget.onTransferSaved,
        ),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_wallets.isEmpty) {
      return _CryptoEmptyState(onAdd: addWallet);
    }

    // All supported tokens are USD stablecoins, so they add up as ≈ USD.
    final total = _wallets.fold<double>(
      0,
      (sum, wallet) => sum + _displayBalance(wallet),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('crypto_total_title'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$ ${formatTokenAmount(total)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      'crypto_wallets_count',
                      params: {'count': '${_wallets.length}'},
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final wallet in _wallets) ...[
            _WalletTile(
              wallet: wallet,
              balance: _displayBalance(wallet),
              outOfSync:
                  _onChain.containsKey(wallet.id) &&
                  !tokenAmountsMatch(
                    _onChain[wallet.id]!,
                    _balances[wallet.id] ?? 0,
                  ),
              onTap: () => _openWallet(wallet),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.wallet,
    required this.balance,
    required this.outOfSync,
    required this.onTap,
  });

  final CryptoWallet wallet;
  final double balance;

  /// Recorded movements don't match the on-chain balance.
  final bool outOfSync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shortAddress = wallet.shortAddress;

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: Text(
            wallet.tokenSymbol.substring(0, 1),
            style: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(wallet.name),
        subtitle: Text(
          shortAddress == null
              ? wallet.label
              : '${wallet.label}\n$shortAddress',
        ),
        isThreeLine: shortAddress != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (outOfSync) ...[
              Icon(Icons.sync_problem, size: 18, color: colorScheme.error),
              const SizedBox(width: 4),
            ],
            Text(
              '${formatTokenAmount(balance)} ${wallet.tokenSymbol}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _CryptoEmptyState extends StatelessWidget {
  const _CryptoEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            Text(
              context.t('crypto_empty_title'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.t('crypto_empty_desc'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(context.t('crypto_add_wallet')),
            ),
          ],
        ),
      ),
    );
  }
}
