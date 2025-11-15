import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../l10n/app_localizations.dart';
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
    // Request a fresh summary when the page is initialized so the UI updates
    // even if the controller previously loaded data before the widget was built.
    widget.controller.refresh();
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
    final comparisonText = diff >= 0
        ? context.t('dashboard_prefix_up')
        : context.t('dashboard_prefix_down');
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
              context.t(
                'dashboard_total_balance_title',
                params: {'currency': currency.code},
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              context.t(
                'dashboard_currency_name',
                params: {'name': currency.name},
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Text(
                '$symbol ${totalBalance.toStringAsFixed(2)}',
                key: ValueKey<String>(
                  'balance-${totalBalance.toStringAsFixed(2)}',
                ),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<DashboardRange>(
              segments: [
                ButtonSegment(
                  value: DashboardRange.day,
                  label: Text(context.loc.rangeLabel(DashboardRangeLabel.day)),
                  icon: const Icon(Icons.calendar_view_day),
                ),
                ButtonSegment(
                  value: DashboardRange.week,
                  label: Text(context.loc.rangeLabel(DashboardRangeLabel.week)),
                  icon: const Icon(Icons.calendar_view_week),
                ),
                ButtonSegment(
                  value: DashboardRange.month,
                  label: Text(
                    context.loc.rangeLabel(DashboardRangeLabel.month),
                  ),
                  icon: const Icon(Icons.calendar_view_month),
                ),
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
                      context.t(
                        'dashboard_summary',
                        params: {'range': _rangeLabel},
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: context.t('dashboard_incomes'),
                      amount: summary?.totalIncomes ?? 0,
                      color: Colors.green,
                      symbol: symbol,
                    ),
                    _SummaryRow(
                      label: context.t('dashboard_expenses'),
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
                            Text(context.t('dashboard_net_current')),
                            Text(
                              '$symbol ${net.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                textAlign: TextAlign.end,
                                diff == 0
                                    ? context.t('dashboard_no_change')
                                    : context.t(
                                        'dashboard_comparison',
                                        params: {
                                          'prefix': _comparisonPrefix,
                                          'amount':
                                              '$symbol ${diff.abs().toStringAsFixed(2)}',
                                        },
                                      ),
                                style: TextStyle(color: trendColor),
                              ),
                              if (diff != 0)
                                Text(
                                  comparisonText,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _DenominationBalanceCard(
                key: ValueKey<int>(balances.length),
                balances: balances,
                symbol: symbol,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _rangeLabel {
    switch (_selectedRange) {
      case DashboardRange.day:
        return context.loc.rangeLabel(DashboardRangeLabel.day);
      case DashboardRange.week:
        return context.loc.rangeLabel(DashboardRangeLabel.week);
      case DashboardRange.month:
        return context.loc.rangeLabel(DashboardRangeLabel.month);
    }
  }

  String get _comparisonPrefix {
    final diff = (_summary?.net ?? 0) - (_summary?.netPrevious ?? 0);
    return diff >= 0
        ? context.t('dashboard_prefix_up')
        : context.t('dashboard_prefix_down');
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
    Key? key,
    required this.balances,
    required this.symbol,
  }) : super(key: key);

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
              context.t('dashboard_denominations_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (balances.isEmpty)
              Text(
                context.t('dashboard_denominations_empty'),
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
                      Text(context.t('dashboard_total_label')),
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
