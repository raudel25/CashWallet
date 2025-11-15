import 'package:flutter/material.dart';

import '../../data/cash_entry_repository.dart';
import '../../models/cash_entry.dart';
import '../../models/denomination_count.dart';

enum HistoryFilter { incomes, expenses }

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.incomeRepository,
    required this.expenseRepository,
  });

  final CashEntryRepository incomeRepository;
  final CashEntryRepository expenseRepository;

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  HistoryFilter _filter = HistoryFilter.incomes;
  List<CashEntry> _incomes = [];
  List<CashEntry> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final incomes = await widget.incomeRepository.load();
    final expenses = await widget.expenseRepository.load();
    if (!mounted) return;
    setState(() {
      _incomes = incomes;
      _expenses = expenses;
      _isLoading = false;
    });
  }

  Future<void> _removeEntry(CashEntry entry) async {
    final repository = entry.type == CashEntryType.income
        ? widget.incomeRepository
        : widget.expenseRepository;
    final entries = await repository.load();
    final updated = entries.where((item) => item.id != entry.id).toList();
    await repository.save(updated);
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filter == HistoryFilter.incomes ? _incomes : _expenses;
    final highlightColor = _filter == HistoryFilter.incomes
        ? Colors.green
        : Colors.red;
    final prefix = _filter == HistoryFilter.incomes ? '+' : '-';
    final emptyTitle = _filter == HistoryFilter.incomes
        ? 'No tienes ingresos registrados'
        : 'No tienes gastos registrados';
    final emptyMessage = _filter == HistoryFilter.incomes
        ? 'Registra tus ingresos desde la pantalla de inicio.'
        : 'Registra tus gastos desde la pantalla de inicio.';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consulta cada movimiento registrado.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          SegmentedButton<HistoryFilter>(
            segments: const [
              ButtonSegment(
                value: HistoryFilter.incomes,
                label: Text('Ingresos'),
                icon: Icon(Icons.trending_up),
              ),
              ButtonSegment(
                value: HistoryFilter.expenses,
                label: Text('Gastos'),
                icon: Icon(Icons.trending_down),
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
  });

  final CashEntry entry;
  final Color highlightColor;
  final String amountPrefix;
  final VoidCallback onDelete;

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
              '${item.quantity} x ${item.denomination.toStringAsFixed(item.denomination == item.denomination.roundToDouble() ? 0 : 2)}',
        )
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final description = entry.description.isEmpty
        ? 'Sin descripción'
        : entry.description;

    return Card(
      child: ListTile(
        title: Text(
          '$amountPrefix \$ ${_formatAmount(entry.amount)}',
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
                'Desglose: ${_formatBreakdown(entry.breakdown)}',
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
