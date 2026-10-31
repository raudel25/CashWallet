import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/crypto_entry.dart';
import '../../models/denomination_count.dart';
import '../../services/transfer_service.dart';
import 'crypto_movement_form_sheet.dart';

/// Moves money between two accounts (cash ↔ crypto, cash ↔ cash in another
/// currency, crypto ↔ crypto). Returns true when a transfer was saved.
class TransferSheet extends StatefulWidget {
  const TransferSheet({
    super.key,
    required this.transferService,
    this.initialFromId,
    this.initialToId,
    this.linkedEntry,
  });

  final TransferService transferService;
  final String? initialFromId;
  final String? initialToId;

  /// Imported movement to preselect on the matching side.
  final CryptoEntry? linkedEntry;

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  List<TransferAccount>? _accounts;
  TransferAccount? _from;
  TransferAccount? _to;
  final _fromSide = _SideState();
  final _toSide = _SideState();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  static const _usdUnits = {'USD', 'USDT', 'USDC'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fromSide.dispose();
    _toSide.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accounts = await widget.transferService.loadAccounts();
    TransferAccount? find(String? id) {
      for (final account in accounts) {
        if (account.id == id) return account;
      }
      return null;
    }

    if (!mounted) return;
    setState(() => _accounts = accounts);
    await _select(true, find(widget.initialFromId));
    await _select(false, find(widget.initialToId));
  }

  String _accountName(TransferAccount account) => switch (account) {
    CashTransferAccount(:final currency) =>
      '${context.t('summary_cash')} ${currency.code}',
    CryptoTransferAccount(:final wallet) => '${wallet.name} · ${wallet.label}',
  };

  Future<void> _select(bool isFrom, TransferAccount? account) async {
    final side = isFrom ? _fromSide : _toSide;
    setState(() {
      if (isFrom) {
        _from = account;
      } else {
        _to = account;
      }
      side.reset(account);
      _error = null;
    });
    if (account == null) return;

    switch (account) {
      case CashTransferAccount(:final currency):
        if (isFrom) {
          final stock = await widget.transferService.loadCashStock(
            currency.code,
          );
          if (!mounted) return;
          setState(() => side.stock = stock);
        }
      case CryptoTransferAccount(:final wallet, :final isSynced):
        if (isSynced) {
          final linkable = await widget.transferService.loadLinkableEntries(
            wallet.id,
            outgoing: isFrom,
          );
          if (!mounted) return;
          final preset = widget.linkedEntry;
          setState(() {
            side.linkable = linkable;
            if (preset != null && preset.walletId == wallet.id) {
              side.linked = linkable
                  .where((e) => e.id == preset.id)
                  .firstOrNull;
              if (side.linked != null) _date = side.linked!.createdAt;
            }
          });
        } else if (isFrom) {
          final balance = await widget.transferService.loadCryptoBalance(
            wallet.id,
          );
          if (!mounted) return;
          setState(() => side.balance = balance);
        }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
    });
  }

  /// Builds the leg for one side, or returns an error message key.
  (TransferLeg?, String?) _buildLeg(
    TransferAccount account,
    _SideState side, {
    required bool isFrom,
  }) {
    switch (account) {
      case CashTransferAccount(:final denominations):
        final breakdown = [
          for (final denomination in denominations)
            DenominationCount(
              denomination: denomination.value,
              quantity:
                  int.tryParse(side.controllerFor(denomination.value).text) ??
                  0,
            ),
        ].where((item) => item.quantity > 0).toList();
        if (breakdown.isEmpty) return (null, 'transfer_error_amount');
        if (isFrom) {
          for (final item in breakdown) {
            if (item.quantity > (side.stock[item.denomination] ?? 0)) {
              return (null, 'transfer_error_stock');
            }
          }
        }
        return (CashLeg(breakdown), null);
      case CryptoTransferAccount(:final isSynced):
        if (isSynced) {
          final linked = side.linked;
          if (linked == null) return (null, 'transfer_error_pick_movement');
          return (LinkedCryptoLeg(linked), null);
        }
        final amount = parseTokenAmount(side.amountController.text);
        if (amount == null || amount <= 0) {
          return (null, 'transfer_error_amount');
        }
        if (isFrom && amount > (side.balance ?? 0) + 1e-9) {
          return (null, 'transfer_error_balance');
        }
        return (NewCryptoLeg(amount), null);
    }
  }

  double _sideAmount(TransferAccount? account, _SideState side) {
    if (account == null) return 0;
    return switch (account) {
      CashTransferAccount(:final denominations) => denominations.fold<double>(
        0,
        (sum, d) =>
            sum +
            d.value * (int.tryParse(side.controllerFor(d.value).text) ?? 0),
      ),
      CryptoTransferAccount(:final isSynced) =>
        isSynced
            ? side.linked?.amount ?? 0
            : parseTokenAmount(side.amountController.text) ?? 0,
    };
  }

  Future<void> _save() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) {
      setState(() => _error = context.t('transfer_error_accounts'));
      return;
    }
    if (from.id == to.id) {
      setState(() => _error = context.t('transfer_error_same'));
      return;
    }
    final (fromLeg, fromError) = _buildLeg(from, _fromSide, isFrom: true);
    final (toLeg, toError) = _buildLeg(to, _toSide, isFrom: false);
    final error = fromError ?? toError;
    if (error != null || fromLeg == null || toLeg == null) {
      setState(() => _error = context.t(error ?? 'transfer_error_amount'));
      return;
    }

    setState(() => _saving = true);
    final note = _descriptionController.text.trim();
    String describe(String key, TransferAccount other) {
      final base = context.t(key, params: {'account': _accountName(other)});
      return note.isEmpty ? base : '$base · $note';
    }

    await widget.transferService.create(
      from: from,
      fromLeg: fromLeg,
      to: to,
      toLeg: toLeg,
      date: _date,
      fromDescription: describe('transfer_to_desc', to),
      toDescription: describe('transfer_from_desc', from),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String? _rateInfo() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return null;
    final sent = _sideAmount(from, _fromSide);
    final received = _sideAmount(to, _toSide);
    if (sent <= 0 || received <= 0) return null;
    if (_usdUnits.contains(from.unit) && _usdUnits.contains(to.unit)) {
      final cost = sent - received;
      if (cost.abs() < 0.005) return context.t('transfer_no_cost');
      return context.t(
        cost > 0 ? 'transfer_cost' : 'transfer_gain',
        params: {'amount': formatTokenAmount(cost.abs())},
      );
    }
    // Show the rate per USD when one side is dollars (e.g. 1 USD = 410 CUP).
    if (_usdUnits.contains(from.unit)) {
      return context.t(
        'transfer_rate',
        params: {
          'rate': '1 ${from.unit} = ${_formatRate(received / sent)} ${to.unit}',
        },
      );
    }
    if (_usdUnits.contains(to.unit)) {
      return context.t(
        'transfer_rate',
        params: {
          'rate': '1 ${to.unit} = ${_formatRate(sent / received)} ${from.unit}',
        },
      );
    }
    return context.t(
      'transfer_rate',
      params: {
        'rate': '1 ${from.unit} = ${_formatRate(received / sent)} ${to.unit}',
      },
    );
  }

  /// 405.000004 → "405.00"; small rates keep more decimals (0.0024).
  String _formatRate(double rate) =>
      rate >= 1 ? rate.toStringAsFixed(2) : rate.toStringAsFixed(4);

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    final rateInfo = _rateInfo();
    final linkedDate = _fromSide.linked?.createdAt ?? _toSide.linked?.createdAt;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: accounts == null
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.t('transfer_title'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t('transfer_intro'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    _SideEditor(
                      label: context.t('transfer_from'),
                      accounts: accounts,
                      selected: _from,
                      side: _fromSide,
                      isFrom: true,
                      accountName: _accountName,
                      onSelect: (account) => _select(true, account),
                      onChanged: () => setState(() => _error = null),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Icon(Icons.arrow_downward),
                    ),
                    _SideEditor(
                      label: context.t('transfer_to'),
                      accounts: accounts,
                      selected: _to,
                      side: _toSide,
                      isFrom: false,
                      accountName: _accountName,
                      onSelect: (account) => _select(false, account),
                      onChanged: () => setState(() => _error = null),
                    ),
                    if (rateInfo != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        rateInfo,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: context.t('transfer_note'),
                        hintText: context.t('transfer_note_hint'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      // A linked blockchain movement already has its date.
                      onTap: linkedDate == null ? _pickDate : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(_formatDate(linkedDate ?? _date)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(context.t('common_cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.swap_horiz),
                            label: Text(context.t('transfer_save')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Inputs for one side of the transfer.
class _SideState {
  final Map<double, TextEditingController> _cashControllers = {};
  final TextEditingController amountController = TextEditingController();
  Map<double, int> stock = {};
  double? balance;
  List<CryptoEntry> linkable = [];
  CryptoEntry? linked;

  TextEditingController controllerFor(double denomination) =>
      _cashControllers.putIfAbsent(denomination, TextEditingController.new);

  void reset(TransferAccount? account) {
    for (final controller in _cashControllers.values) {
      controller.clear();
    }
    amountController.clear();
    stock = {};
    balance = null;
    linkable = [];
    linked = null;
  }

  void dispose() {
    for (final controller in _cashControllers.values) {
      controller.dispose();
    }
    amountController.dispose();
  }
}

class _SideEditor extends StatelessWidget {
  const _SideEditor({
    required this.label,
    required this.accounts,
    required this.selected,
    required this.side,
    required this.isFrom,
    required this.accountName,
    required this.onSelect,
    required this.onChanged,
  });

  final String label;
  final List<TransferAccount> accounts;
  final TransferAccount? selected;
  final _SideState side;
  final bool isFrom;
  final String Function(TransferAccount) accountName;
  final ValueChanged<TransferAccount?> onSelect;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final account = selected;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              // Rebuild when the selection is set programmatically.
              key: ValueKey(account?.id),
              initialValue: account?.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                for (final item in accounts)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      accountName(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) =>
                  onSelect(accounts.where((item) => item.id == id).firstOrNull),
            ),
            if (account != null) ...[
              const SizedBox(height: 8),
              switch (account) {
                CashTransferAccount() => _cashInputs(context, account),
                CryptoTransferAccount() => _cryptoInputs(context, account),
              },
            ],
          ],
        ),
      ),
    );
  }

  Widget _cashInputs(BuildContext context, CashTransferAccount account) {
    final symbol = account.currency.symbol;
    return Column(
      children: [
        for (final denomination in account.denominations)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextField(
              controller: side.controllerFor(denomination.value),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                labelText: '$symbol ${formatTokenAmount(denomination.value)}',
                suffixText: context.t('common_units'),
                helperText: isFrom
                    ? context.t(
                        'form_available_hint',
                        params: {
                          'count': '${side.stock[denomination.value] ?? 0}',
                        },
                      )
                    : null,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
      ],
    );
  }

  Widget _cryptoInputs(BuildContext context, CryptoTransferAccount account) {
    if (!account.isSynced) {
      return TextField(
        controller: side.amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: context.t('crypto_amount'),
          suffixText: account.unit,
          helperText: isFrom && side.balance != null
              ? context.t(
                  'crypto_available',
                  params: {
                    'amount':
                        '${formatTokenAmount(side.balance!)} ${account.unit}',
                  },
                )
              : null,
        ),
        onChanged: (_) => onChanged(),
      );
    }
    if (side.linkable.isEmpty) {
      return Text(
        context.t(isFrom ? 'transfer_no_outgoing' : 'transfer_no_incoming'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('transfer_pick_movement'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        DropdownButton<String>(
          value: side.linked?.id,
          isExpanded: true,
          hint: Text(context.t('transfer_pick_hint')),
          items: [
            for (final entry in side.linkable)
              DropdownMenuItem(
                value: entry.id,
                child: Text(
                  '${isFrom ? '-' : '+'}${formatTokenAmount(entry.amount)} ${account.unit} · '
                  '${entry.createdAt.day.toString().padLeft(2, '0')}/'
                  '${entry.createdAt.month.toString().padLeft(2, '0')}'
                  '${entry.counterparty == null ? '' : ' · ${shortenAddress(entry.counterparty!)}'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            side.linked = side.linkable.where((e) => e.id == id).firstOrNull;
            onChanged();
          },
        ),
      ],
    );
  }
}
