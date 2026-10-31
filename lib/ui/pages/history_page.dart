import 'package:flutter/material.dart';

import '../../data/cash_entry_repository.dart';
import '../../data/denomination_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/cash_entry.dart';
import '../../models/currency.dart';
import '../../models/denomination_count.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/movement_form_sheet.dart';

enum HistoryFilter { incomes, expenses }

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.incomeRepository,
    required this.expenseRepository,
    required this.denominationRepository,
    required this.currency,
    required this.loadStock,
    this.onChanged,
  });

  final CashEntryRepository incomeRepository;
  final CashEntryRepository expenseRepository;
  final DenominationRepository denominationRepository;
  final Currency currency;
  final Future<Map<double, int>> Function() loadStock;
  final VoidCallback? onChanged;

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  HistoryFilter _filter = HistoryFilter.incomes;
  List<CashEntry> _incomes = [];
  List<CashEntry> _expenses = [];
  bool _isLoading = true;
  late String _currencyCode;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<CashEntry> _applyFilters(List<CashEntry> entries) {
    return entries.where((entry) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesDescription = entry.description.toLowerCase().contains(q);
        final matchesAmount = entry.amount.toStringAsFixed(2).contains(q);
        if (!matchesDescription && !matchesAmount) return false;
      }
      final range = _dateRange;
      if (range != null) {
        final dayStart = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final dayEnd = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        if (entry.createdAt.isBefore(dayStart) ||
            entry.createdAt.isAfter(dayEnd)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _removeEntry(CashEntry entry) async {
    final repository = entry.type == CashEntryType.income
        ? widget.incomeRepository
        : widget.expenseRepository;
    await repository.delete(_currencyCode, entry.id);
    await refresh(_currencyCode);
    widget.onChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('history_entry_deleted')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    return showConfirmDialog(
      context,
      title: context.t('history_confirm_delete_title'),
      content: context.t('history_confirm_delete_msg'),
    );
  }

  Future<void> _editEntry(CashEntry entry) async {
    final denominations = await widget.denominationRepository.load(
      _currencyCode,
    );
    if (denominations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('home_configure_denominations'))),
      );
      return;
    }

    Map<double, int>? stock;
    if (entry.type == CashEntryType.expense) {
      stock = await widget.loadStock();
    }

    if (!mounted) return;
    final result = await showModalBottomSheet<MovementFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MovementFormSheet(
        type: entry.type,
        denominations: denominations,
        currencySymbol: widget.currency.symbol,
        availableStock: stock,
        initialEntry: entry,
      ),
    );
    if (result == null) return;

    final updated = entry.copyWith(
      description: result.description,
      breakdown: result.breakdown,
      createdAt: result.createdAt,
    );

    final repository = entry.type == CashEntryType.income
        ? widget.incomeRepository
        : widget.expenseRepository;
    await repository.update(_currencyCode, updated);
    await refresh(_currencyCode);
    widget.onChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('history_entry_updated')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleOpening(CashEntry entry) async {
    await widget.incomeRepository.update(
      _currencyCode,
      entry.copyWith(isOpening: !entry.isOpening),
    );
    await refresh(_currencyCode);
    widget.onChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(entry.isOpening ? 'opening_unmarked' : 'opening_marked'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial =
        _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: initial,
    );
    if (picked == null) return;
    setState(() => _dateRange = picked);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final raw = _filter == HistoryFilter.incomes ? _incomes : _expenses;
    final list = _applyFilters(raw);
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
    final hasFilters = _searchQuery.isNotEmpty || _dateRange != null;
    final filteredEmpty = list.isEmpty && raw.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.t('history_search_hint'),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _dateRange == null
                        ? context.t('history_filter_date')
                        : _formatRange(_dateRange!),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: context.t('history_clear_filters'),
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const _HistorySkeleton()
                : raw.isEmpty
                ? _HistoryEmptyState(
                    title: emptyTitle,
                    description: emptyMessage,
                  )
                : filteredEmpty
                ? _HistoryEmptyState(
                    title: context.t('history_no_results_title'),
                    description: context.t('history_no_results_desc'),
                  )
                : RefreshIndicator(
                    onRefresh: () => refresh(_currencyCode),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemBuilder: (context, index) {
                        final entry = list[index];
                        return Dismissible(
                          key: ValueKey(entry.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) => _confirmDelete(),
                          onDismissed: (_) => _removeEntry(entry),
                          child: _HistoryTile(
                            entry: entry,
                            highlightColor: highlightColor,
                            amountPrefix: prefix,
                            onEdit: () => _editEntry(entry),
                            // Only incomes can be cash the user already had.
                            onToggleOpening:
                                entry.type == CashEntryType.income &&
                                    entry.transferId == null
                                ? () => _toggleOpening(entry)
                                : null,
                            onDelete: () async {
                              if (await _confirmDelete()) {
                                await _removeEntry(entry);
                              }
                            },
                            currencySymbol: widget.currency.symbol,
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: list.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatRange(DateTimeRange range) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${fmt(range.start)} - ${fmt(range.end)}';
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.highlightColor,
    required this.amountPrefix,
    required this.onEdit,
    required this.onDelete,
    required this.currencySymbol,
    this.onToggleOpening,
  });

  final CashEntry entry;
  final Color highlightColor;
  final String amountPrefix;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String currencySymbol;
  final VoidCallback? onToggleOpening;

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

  String _formatBreakdown(BuildContext context, List<DenominationCount> bd) {
    if (bd.isEmpty) return context.t('history_no_breakdown');
    return bd
        .map(
          (item) =>
              '${item.quantity} × $currencySymbol ${item.denomination.toStringAsFixed(item.denomination == item.denomination.roundToDouble() ? 0 : 2)}',
        )
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final description = entry.description.isEmpty
        ? context.t('history_no_description')
        : entry.description;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: highlightColor.withValues(alpha: 0.12),
                child: Icon(
                  entry.type == CashEntryType.income
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: highlightColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            description,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$amountPrefix $currencySymbol ${_formatAmount(entry.amount)}',
                          style: TextStyle(
                            color: highlightColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(entry.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (entry.isOpening) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 14,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.t('crypto_initial_balance'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                    if (entry.breakdown.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.t(
                          'history_breakdown',
                          params: {
                            'breakdown': _formatBreakdown(
                              context,
                              entry.breakdown,
                            ),
                          },
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'opening') onToggleOpening?.call();
                },
                itemBuilder: (context) => [
                  if (onToggleOpening != null)
                    PopupMenuItem(
                      value: 'opening',
                      child: Row(
                        children: [
                          Icon(
                            entry.isOpening
                                ? Icons.trending_up
                                : Icons.flag_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.t(
                              entry.isOpening
                                  ? 'opening_unmark'
                                  : 'opening_mark',
                            ),
                          ),
                        ],
                      ),
                    ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: color, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: 160, color: color),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 120, color: color),
                    ],
                  ),
                ),
                Container(height: 14, width: 64, color: color),
              ],
            ),
          ),
        );
      },
    );
  }
}

