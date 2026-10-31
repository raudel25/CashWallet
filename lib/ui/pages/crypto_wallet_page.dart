import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/crypto_entry_repository.dart';
import '../../data/crypto_wallet_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/cash_entry.dart';
import '../../models/crypto_entry.dart';
import '../../models/crypto_wallet.dart';
import '../../services/crypto_sync_service.dart';
import '../../services/transfer_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/crypto_movement_form_sheet.dart';
import '../widgets/crypto_wallet_form_sheet.dart';
import '../widgets/transfer_sheet.dart';

class CryptoWalletPage extends StatefulWidget {
  const CryptoWalletPage({
    super.key,
    required this.wallet,
    required this.walletRepository,
    required this.entryRepository,
    required this.syncService,
    required this.transferService,
    required this.onTransferSaved,
  });

  final CryptoWallet wallet;
  final CryptoWalletRepository walletRepository;
  final CryptoEntryRepository entryRepository;
  final CryptoSyncService syncService;
  final TransferService transferService;
  final Future<void> Function() onTransferSaved;

  @override
  State<CryptoWalletPage> createState() => _CryptoWalletPageState();
}

class _CryptoWalletPageState extends State<CryptoWalletPage> {
  late CryptoWallet _wallet;
  List<CryptoEntry> _entries = [];
  bool _isLoading = true;

  double? _onChainBalance;
  bool _isSyncing = false;
  bool _syncFailed = false;
  bool _historyFailed = false;

  /// Balance from recorded movements.
  double get _balance =>
      _entries.fold<double>(0, (sum, entry) => sum + entry.signedAmount);

  @override
  void initState() {
    super.initState();
    _wallet = widget.wallet;
    _refresh();
  }

  /// Reloads local movements and syncs with the blockchain.
  Future<void> _refresh() async {
    await _reloadEntries();
    await _syncOnChain();
  }

  Future<void> _reloadEntries() async {
    final entries = await widget.entryRepository.load(_wallet.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _syncOnChain() async {
    if (_wallet.address == null) {
      setState(() {
        _onChainBalance = null;
        _syncFailed = false;
        _historyFailed = false;
      });
      return;
    }
    setState(() => _isSyncing = true);
    final result = await widget.syncService.sync(_wallet);
    if (!mounted) return;
    setState(() {
      _onChainBalance = result.onChainBalance;
      _syncFailed = result.onChainBalance == null;
      _historyFailed = result.historyFailed;
      _isSyncing = false;
    });
    if (result.imported > 0) {
      await _reloadEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'crypto_imported',
              params: {'count': '${result.imported}'},
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Moves the difference with the blockchain into the opening balance.
  /// It reconciles untracked history, so it isn't income or expense.
  Future<void> _adjustToOnChain() async {
    final onChain = _onChainBalance;
    if (onChain == null) return;
    final diff = onChain - _balance;
    final amountLabel =
        '${diff > 0 ? '+' : '-'} ${formatTokenAmount(diff.abs())} ${_wallet.tokenSymbol}';
    final confirmed = await showConfirmDialog(
      context,
      title: context.t('crypto_adjust_title'),
      content: context.t('crypto_adjust_msg', params: {'amount': amountLabel}),
      confirmLabel: context.t('crypto_adjust'),
    );
    if (!confirmed || !mounted) return;
    final entries = await widget.entryRepository.load(_wallet.id);
    await widget.entryRepository.save(
      _wallet.id,
      CryptoSyncService.rebalanceOpening(
        wallet: _wallet,
        entries: entries,
        onChainBalance: onChain,
      ),
    );
    await _reloadEntries();
    if (!mounted) return;
    _showSnack('crypto_movement_saved');
  }

  Future<void> _toggleOpening(CryptoEntry entry) async {
    await widget.entryRepository.update(
      entry.copyWith(isOpening: !entry.isOpening),
    );
    await _reloadEntries();
    if (!mounted) return;
    _showSnack(entry.isOpening ? 'opening_unmarked' : 'opening_marked');
  }

  void _showSnack(String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t(key)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openQuickAddSheet() async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.green),
                title: Text(context.t('home_new_income')),
                onTap: () => Navigator.of(context).pop(CashEntryType.income),
              ),
              ListTile(
                leading: const Icon(Icons.trending_down, color: Colors.red),
                title: Text(context.t('home_new_expense')),
                onTap: () => Navigator.of(context).pop(CashEntryType.expense),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(context.t('transfer_title')),
                onTap: () => Navigator.of(context).pop(_transferChoice),
              ),
            ],
          ),
        );
      },
    );
    if (choice == _transferChoice) {
      await _openTransfer();
      return;
    }
    if (choice is! CashEntryType) return;
    final type = choice;
    if (type == CashEntryType.expense && _balance <= 0) {
      if (!mounted) return;
      _showSnack('crypto_no_balance_for_expense');
      return;
    }
    await _addEntry(type);
  }

  Future<void> _addEntry(CashEntryType type) async {
    if (!mounted) return;
    final result = await showModalBottomSheet<CryptoMovementFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CryptoMovementFormSheet(
        type: type,
        tokenSymbol: _wallet.tokenSymbol,
        availableBalance: _balance,
      ),
    );
    if (result == null) return;

    await widget.entryRepository.add(
      CryptoEntry.create(
        walletId: _wallet.id,
        type: type,
        amount: result.amount,
        description: result.description,
        createdAt: result.createdAt,
      ),
    );
    await _reloadEntries();
    if (!mounted) return;
    _showSnack('crypto_movement_saved');
  }

  static const _transferChoice = 'transfer';

  /// Opens the transfer form with this wallet preselected. With [linked],
  /// that imported movement becomes the wallet's side of the transfer.
  Future<void> _openTransfer({CryptoEntry? linked}) async {
    final accountId = 'crypto:${_wallet.id}';
    final incoming = linked?.type == CashEntryType.income;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TransferSheet(
        transferService: widget.transferService,
        initialFromId: incoming ? null : accountId,
        initialToId: incoming ? accountId : null,
        linkedEntry: linked,
      ),
    );
    if (saved != true) return;
    await _reloadEntries();
    await widget.onTransferSaved();
    if (!mounted) return;
    _showSnack('transfer_saved');
  }

  /// Shows what can be done with a movement: edit, link it to a transfer
  /// (imported ones) or mark it as opening balance (incomes).
  Future<void> _onEntryTap(CryptoEntry entry) async {
    final canLink = entry.isImported && !entry.isTransfer;
    final canToggleOpening =
        entry.type == CashEntryType.income && !entry.isTransfer;
    if (!canLink && !canToggleOpening) {
      await _editEntry(entry);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canToggleOpening)
              ListTile(
                leading: Icon(
                  entry.isOpening ? Icons.trending_up : Icons.flag_outlined,
                ),
                title: Text(
                  context.t(
                    entry.isOpening ? 'opening_unmark' : 'opening_mark',
                  ),
                ),
                subtitle: Text(
                  context.t(
                    entry.isOpening
                        ? 'opening_unmark_desc'
                        : 'opening_mark_desc',
                  ),
                ),
                onTap: () => Navigator.of(context).pop('opening'),
              ),
            if (canLink)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(context.t('transfer_mark')),
                subtitle: Text(context.t('transfer_mark_desc')),
                onTap: () => Navigator.of(context).pop('transfer'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.t('history_edit')),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
          ],
        ),
      ),
    );
    if (action == 'opening') await _toggleOpening(entry);
    if (action == 'transfer') await _openTransfer(linked: entry);
    if (action == 'edit') await _editEntry(entry);
  }

  Future<void> _editEntry(CryptoEntry entry) async {
    final result = await showModalBottomSheet<CryptoMovementFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CryptoMovementFormSheet(
        type: entry.type,
        tokenSymbol: _wallet.tokenSymbol,
        availableBalance: _balance,
        initialEntry: entry,
      ),
    );
    if (result == null) return;

    await widget.entryRepository.update(
      entry.copyWith(
        amount: result.amount,
        description: result.description,
        createdAt: result.createdAt,
      ),
    );
    await _reloadEntries();
    if (!mounted) return;
    _showSnack('history_entry_updated');
  }

  Future<bool> _confirmDeleteEntry() {
    return showConfirmDialog(
      context,
      title: context.t('history_confirm_delete_title'),
      content: context.t('history_confirm_delete_msg'),
    );
  }

  Future<void> _removeEntry(CryptoEntry entry) async {
    await widget.entryRepository.delete(_wallet.id, entry.id);
    await _reloadEntries();
    if (!mounted) return;
    _showSnack('history_entry_deleted');
  }

  Future<void> _editWallet() async {
    final result = await showModalBottomSheet<CryptoWalletFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CryptoWalletFormSheet(initialWallet: _wallet),
    );
    if (result == null) return;
    await widget.walletRepository.update(result.wallet);
    // A new address is a different account: start its sync from scratch.
    if (result.wallet.address != _wallet.address) {
      await widget.syncService.syncStateRepository.clear(_wallet.id);
    }
    if (!mounted) return;
    setState(() => _wallet = result.wallet);
    _showSnack('crypto_wallet_saved');
    await _syncOnChain();
  }

  Future<void> _deleteWallet() async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.t('crypto_delete_wallet_title'),
      content: context.t('crypto_delete_wallet_msg'),
    );
    if (!confirmed) return;
    await widget.entryRepository.deleteAll(_wallet.id);
    await widget.syncService.syncStateRepository.clear(_wallet.id);
    await widget.walletRepository.delete(_wallet.id);
    if (!mounted) return;
    _showSnack('crypto_wallet_deleted');
    Navigator.of(context).pop();
  }

  Future<void> _copyAddress() async {
    final address = _wallet.address;
    if (address == null) return;
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    _showSnack('crypto_address_copied');
  }

  Widget _buildSyncStatus(ColorScheme colorScheme) {
    final status = _buildBalanceStatus(colorScheme);
    if (!_historyFailed) return status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        status,
        const SizedBox(height: 4),
        Text(
          context.t('crypto_history_failed'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceStatus(ColorScheme colorScheme) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colorScheme.onPrimaryContainer);
    final onChain = _onChainBalance;

    if (_isSyncing && onChain == null) {
      return Row(
        children: [
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Text(context.t('crypto_syncing'), style: textStyle),
        ],
      );
    }
    if (_syncFailed || onChain == null) {
      return Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.t('crypto_sync_failed'), style: textStyle),
          ),
          TextButton(
            onPressed: _syncOnChain,
            child: Text(context.t('crypto_retry')),
          ),
        ],
      );
    }
    if (tokenAmountsMatch(onChain, _balance)) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(context.t('crypto_in_sync'), style: textStyle),
        ],
      );
    }
    final diff = onChain - _balance;
    return Row(
      children: [
        Icon(Icons.sync_problem, size: 16, color: colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${context.t('crypto_recorded_balance', params: {'amount': '${formatTokenAmount(_balance)} ${_wallet.tokenSymbol}'})}\n'
            '${context.t('crypto_difference', params: {'amount': '${diff > 0 ? '+' : '-'}${formatTokenAmount(diff.abs())}'})}',
            style: textStyle,
          ),
        ),
        FilledButton.tonal(
          onPressed: _adjustToOnChain,
          child: Text(context.t('crypto_adjust')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_wallet.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editWallet();
              if (value == 'delete') _deleteWallet();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(context.t('history_edit')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(context.t('common_delete')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuickAddSheet,
        icon: const Icon(Icons.add),
        label: Text(context.t('home_register_movement')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
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
                            '${context.t(_onChainBalance == null ? 'crypto_balance' : 'crypto_onchain_balance')} · ${_wallet.label}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${formatTokenAmount(_onChainBalance ?? _balance)} ${_wallet.tokenSymbol}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (_wallet.address != null) ...[
                            const SizedBox(height: 8),
                            _buildSyncStatus(colorScheme),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _copyAddress,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _wallet.address!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontFamily: 'monospace',
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.t('crypto_movements'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.list_alt_outlined,
                            size: 48,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t('crypto_no_movements_title'),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t('crypto_no_movements_desc'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final entry in _entries) ...[
                      Dismissible(
                        key: ValueKey(entry.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmDeleteEntry(),
                        onDismissed: (_) => _removeEntry(entry),
                        child: _EntryTile(
                          entry: entry,
                          tokenSymbol: _wallet.tokenSymbol,
                          onTap: () => _onEntryTap(entry),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.tokenSymbol,
    required this.onTap,
  });

  final CryptoEntry entry;
  final String tokenSymbol;
  final VoidCallback onTap;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == CashEntryType.income;
    final color = isIncome ? Colors.green : Colors.red;
    final counterparty = entry.counterparty;
    final description = entry.description.isNotEmpty
        ? entry.description
        : entry.isOpening
        ? context.t('crypto_initial_balance')
        : counterparty != null
        ? context.t(
            isIncome ? 'crypto_received_from' : 'crypto_sent_to',
            params: {'address': shortenAddress(counterparty)},
          )
        : context.t('history_no_description');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            entry.isTransfer
                ? Icons.swap_horiz
                : isIncome
                ? Icons.trending_up
                : Icons.trending_down,
            color: color,
          ),
        ),
        title: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            if (entry.isOpening) ...[
              Icon(
                Icons.flag_outlined,
                size: 14,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 4),
            ],
            if (entry.isImported) ...[
              Icon(Icons.link, size: 14, color: Theme.of(context).hintColor),
              const SizedBox(width: 4),
            ],
            Text(_formatDate(entry.createdAt)),
          ],
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'} ${formatTokenAmount(entry.amount)} $tokenSymbol',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
