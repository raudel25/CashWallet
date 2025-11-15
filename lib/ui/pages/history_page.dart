import 'package:flutter/material.dart';

import '../../data/cash_entry_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/cash_entry.dart';
import '../../models/currency.dart';
import '../../models/denomination_count.dart';
import '../widgets/confirm_dialog.dart';

enum HistoryFilter { incomes, expenses }

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.incomeRepository,
    required this.expenseRepository,
    required this.currency,
  });

  final CashEntryRepository incomeRepository;
  final CashEntryRepository expenseRepository;
  final Currency currency;

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  HistoryFilter _filter = HistoryFilter.incomes;
  List<CashEntry> _incomes = [];
  List<CashEntry> _expenses = [];
  bool _isLoading = true;
  late String _currencyCode;

  @override
  void initState() {
    super.initState();
    _currencyCode = widget.currency.code;
    refresh(_currencyCode);
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currency.code != widget.currency.code) {
      _currencyCode = widget.currency.code;
      refresh(_currencyCode);
    }
  }

  Future<void> refresh([String? currencyCode]) async {
    final code = currencyCode ?? _currencyCode;
    final incomes = await widget.incomeRepository.load(code);
    final expenses = await widget.expenseRepository.load(code);
    if (!mounted) return;
    setState(() {
      _incomes = incomes;
      _expenses = expenses;
      _isLoading = false;
    });
  }

  Future<void> _removeEntry(CashEntry entry) async {
    // Confirm deletion with the user
    final confirmed = await showConfirmDialog(
      context,
      title: context.t('history_confirm_delete_title'),
      content: context.t('history_confirm_delete_msg'),
    );
    if (!confirmed) return;

    final repository = entry.type == CashEntryType.income
        ? widget.incomeRepository
        : widget.expenseRepository;
    final entries = await repository.load(_currencyCode);
    final updated = entries.where((item) => item.id != entry.id).toList();
    await repository.save(_currencyCode, updated);
    await refresh(_currencyCode);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filter == HistoryFilter.incomes ? _incomes : _expenses;
    final highlightColor = _filter == HistoryFilter.incomes
        ? Colors.green
        : Colors.red;
    final prefix = _filter == HistoryFilter.incomes ? '+' : '-';
    final emptyTitle = _filter == HistoryFilter.incomes
        ? context.t('history_empty_incomes_title')
        : context.t('history_empty_expenses_title');
    final emptyMessage = _filter == HistoryFilter.incomes
        ? context.t('history_empty_incomes_desc')
        : context.t('history_empty_expenses_desc');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('history_title'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          SegmentedButton<HistoryFilter>(
            segments: [
              ButtonSegment(
                value: HistoryFilter.incomes,
                label: Text(context.t('history_filter_incomes')),
                icon: const Icon(Icons.trending_up),
              ),
              ButtonSegment(
                value: HistoryFilter.expenses,
                label: Text(context.t('history_filter_expenses')),
                icon: const Icon(Icons.trending_down),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (value) {
              setState(() => _filter = value.first);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? _HistoryEmptyState(
                    title: emptyTitle,
                    description: emptyMessage,
                  )
                : ListView.separated(
                    itemBuilder: (context, index) {
                      final entry = list[index];
                      return _HistoryTile(
                        entry: entry,
                        highlightColor: highlightColor,
                        amountPrefix: prefix,
                        onDelete: () => _removeEntry(entry),
                        currencySymbol: widget.currency.symbol,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: list.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.highlightColor,
    required this.amountPrefix,
    required this.onDelete,
    required this.currencySymbol,
  });

  final CashEntry entry;
  final Color highlightColor;
  final String amountPrefix;
  final VoidCallback onDelete;
  final String currencySymbol;

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year • $hour:$minute';
  }

  String _formatBreakdown(List<DenominationCount> breakdown) {
    if (breakdown.isEmpty) return 'Sin desglose';
    return breakdown
        .map(
          (item) =>
              '${item.quantity} x $currencySymbol ${item.denomination.toStringAsFixed(item.denomination == item.denomination.roundToDouble() ? 0 : 2)}',
        )
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final description = entry.description.isEmpty
        ? context.t('history_no_description')
        : entry.description;

    return Card(
      child: ListTile(
        title: Text(
          '$amountPrefix $currencySymbol ${_formatAmount(entry.amount)}',
          style: TextStyle(color: highlightColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 4),
            Text(
              _formatDate(entry.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (entry.breakdown.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.t(
                  'history_breakdown',
                  params: {'breakdown': _formatBreakdown(entry.breakdown)},
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list_alt_outlined, size: 64, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
