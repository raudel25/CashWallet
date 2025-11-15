import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../models/currency.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.currency,
  });

  final DashboardController controller;
  final Currency currency;

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  DashboardSummary? _summary;
  DashboardRange _selectedRange = DashboardRange.month;

  @override
  void initState() {
    super.initState();
    widget.controller.range = _selectedRange;
  }

  void updateSummary(DashboardSummary summary) {
    setState(() {
      _summary = summary;
    });
  }

  Future<void> _onRangeChanged(DashboardRange range) async {
    setState(() {
      _selectedRange = range;
    });
    await widget.controller.changeRange(range);
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currency;
    final symbol = currency.symbol;
    final summary = _summary;
    final net = summary?.net ?? 0;
    final previousNet = summary?.netPrevious ?? 0;
    final diff = net - previousNet;
    final trendColor = diff >= 0 ? Colors.green : Colors.red;
    final comparisonText = diff >= 0 ? 'más que' : 'menos que';
    final totalBalance = summary?.totalBalance ?? 0;
    final balances =
        summary?.denominationBalances ?? const <DenominationBalance>[];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo total (${currency.code})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(currency.name, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              '$symbol ${totalBalance.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<DashboardRange>(
              segments: const [
                ButtonSegment(value: DashboardRange.day, label: Text('Día')),
                ButtonSegment(
                  value: DashboardRange.week,
                  label: Text('Semana'),
                ),
                ButtonSegment(value: DashboardRange.month, label: Text('Mes')),
              ],
              selected: {_selectedRange},
              onSelectionChanged: (value) {
                _onRangeChanged(value.first);
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen por $_rangeLabel',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Ingresos',
                      amount: summary?.totalIncomes ?? 0,
                      color: Colors.green,
                      symbol: symbol,
                    ),
                    _SummaryRow(
                      label: 'Gastos',
                      amount: summary?.totalExpenses ?? 0,
                      color: Colors.red,
                      symbol: symbol,
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Neto actual'),
                            Text(
                              '$symbol ${net.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              diff == 0
                                  ? 'Sin cambios vs. periodo previo'
                                  : '$_comparisonPrefix $symbol ${diff.abs().toStringAsFixed(2)}',
                              style: TextStyle(color: trendColor),
                            ),
                            Text(
                              diff == 0
                                  ? ''
                                  : '$comparisonText el periodo anterior',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _DenominationBalanceCard(balances: balances, symbol: symbol),
          ],
        ),
      ),
    );
  }

  String get _rangeLabel {
    switch (_selectedRange) {
      case DashboardRange.day:
        return 'día';
      case DashboardRange.week:
        return 'semana';
      case DashboardRange.month:
        return 'mes';
    }
  }

  String get _comparisonPrefix {
    final diff = (_summary?.net ?? 0) - (_summary?.netPrevious ?? 0);
    return diff >= 0 ? 'Arriba' : 'Abajo';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.symbol,
  });

  final String label;
  final double amount;
  final Color color;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$symbol ${amount.toStringAsFixed(2)}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _DenominationBalanceCard extends StatelessWidget {
  const _DenominationBalanceCard({
    required this.balances,
    required this.symbol,
  });

  final List<DenominationBalance> balances;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Billetes por denominación',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (balances.isEmpty)
              Text(
                'Aún no tienes denominaciones registradas con saldo.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  ...balances.map(
                    (balance) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$symbol ${balance.value.toStringAsFixed(2)}'),
                          Text(
                            '${balance.quantity} unidades',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '$symbol ${balance.amount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total'),
                      Text(
                        '${balances.fold<int>(0, (sum, item) => sum + item.quantity)} unidades',
                      ),
                      Text(
                        '$symbol ${balances.fold<double>(0, (sum, item) => sum + item.amount).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
