import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/currency.dart';
import '../widgets/trend_chart.dart';

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

    return RefreshIndicator(
      onRefresh: () => widget.controller.refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _BalanceHeader(
            currency: currency,
            summary: summary,
          ),
          const SizedBox(height: 20),
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
                label: Text(context.loc.rangeLabel(DashboardRangeLabel.month)),
                icon: const Icon(Icons.calendar_view_month),
              ),
            ],
            selected: {_selectedRange},
            onSelectionChanged: (value) => _onRangeChanged(value.first),
          ),
          const SizedBox(height: 16),
          if (summary == null) ...[
            const _SummarySkeleton(),
            const SizedBox(height: 16),
            const _ChartSkeleton(),
            const SizedBox(height: 16),
            const _DenominationsSkeleton(),
          ] else ...[
            _SummaryCard(
              summary: summary,
              symbol: symbol,
              rangeLabel: _rangeLabel,
            ),
            const SizedBox(height: 16),
            _TrendCard(
              buckets: summary.trend,
              symbol: symbol,
              rangeLabel: _rangeLabel,
            ),
            const SizedBox(height: 16),
            _DenominationBalanceCard(
              balances: summary.denominationBalances,
              symbol: symbol,
            ),
          ],
        ],
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
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.currency, required this.summary});

  final Currency currency;
  final DashboardSummary? summary;

  @override
  Widget build(BuildContext context) {
    final symbol = currency.symbol;
    final totalBalance = summary?.totalBalance ?? 0;
    final color = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.primary, color.primary.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: color.onPrimary),
              const SizedBox(width: 8),
              Text(
                context.t(
                  'dashboard_total_balance_title',
                  params: {'currency': currency.code},
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            currency.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
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
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: color.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.symbol,
    required this.rangeLabel,
  });

  final DashboardSummary summary;
  final String symbol;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final net = summary.net;
    final diff = summary.net - summary.netPrevious;
    final trendColor = diff >= 0 ? Colors.green : Colors.red;
    final comparisonText = diff >= 0
        ? context.t('dashboard_prefix_up')
        : context.t('dashboard_prefix_down');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('dashboard_summary', params: {'range': rangeLabel}),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              label: context.t('dashboard_incomes'),
              amount: summary.totalIncomes,
              color: Colors.green,
              icon: Icons.trending_up,
              symbol: symbol,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: context.t('dashboard_expenses'),
              amount: summary.totalExpenses,
              color: Colors.red,
              icon: Icons.trending_down,
              symbol: symbol,
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('dashboard_net_current')),
                      Text(
                        '$symbol ${net.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              diff >= 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 14,
                              color: trendColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              diff == 0
                                  ? context.t('dashboard_no_change')
                                  : '$symbol ${diff.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                color: trendColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (diff != 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$comparisonText · ${context.t('dashboard_comparison_short')}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.buckets,
    required this.symbol,
    required this.rangeLabel,
  });

  final List<TrendBucket> buckets;
  final String symbol;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final hasData = buckets.any(
      (b) => b.incomes > 0 || b.expenses > 0,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('dashboard_trend_title', params: {'range': rangeLabel}),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    context.t('dashboard_trend_empty'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              TrendChart(buckets: buckets, symbol: symbol),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendDot(color: Colors.green.shade400),
                const SizedBox(width: 4),
                Text(
                  context.t('dashboard_incomes'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                _LegendDot(color: Colors.red.shade400),
                const SizedBox(width: 4),
                Text(
                  context.t('dashboard_expenses'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.symbol,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(
          '$symbol ${amount.toStringAsFixed(2)}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _DenominationBalanceCard extends StatelessWidget {
  const _DenominationBalanceCard({required this.balances, required this.symbol});

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
            const SizedBox(height: 12),
            if (balances.isEmpty)
              Text(
                context.t('dashboard_denominations_empty'),
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              ..._buildBars(context),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.t('dashboard_total_label'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    context.t(
                      'dashboard_units_count',
                      params: {
                        'count':
                            '${balances.fold<int>(0, (sum, item) => sum + item.quantity)}',
                      },
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '$symbol ${balances.fold<double>(0, (sum, item) => sum + item.amount).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBars(BuildContext context) {
    final total = balances.fold<double>(0, (sum, item) => sum + item.amount);
    final color = Theme.of(context).colorScheme.primary;
    return balances.map((b) {
      final percent = total <= 0 ? 0.0 : b.amount / total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$symbol ${b.value.toStringAsFixed(2)}'),
                ),
                Text(
                  context.t(
                    'dashboard_units_count',
                    params: {'count': '${b.quantity}'},
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                Text(
                  '$symbol ${b.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 14, width: 140, color: color),
            const SizedBox(height: 16),
            Container(height: 12, width: double.infinity, color: color),
            const SizedBox(height: 8),
            Container(height: 12, width: double.infinity, color: color),
            const SizedBox(height: 16),
            Container(height: 24, width: 160, color: color),
          ],
        ),
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 14, width: 120, color: color),
            const SizedBox(height: 16),
            Container(height: 140, width: double.infinity, color: color),
          ],
        ),
      ),
    );
  }
}

class _DenominationsSkeleton extends StatelessWidget {
  const _DenominationsSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(height: 14, width: 180, color: color),
            const SizedBox(height: 16),
            for (var i = 0; i < 3; i++) ...[
              Container(height: 10, width: double.infinity, color: color),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
