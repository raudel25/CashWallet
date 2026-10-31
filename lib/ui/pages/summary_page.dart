import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/crypto_entry.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/finance_summary_service.dart';
import '../widgets/crypto_movement_form_sheet.dart';
import '../widgets/trend_chart.dart';

/// Unified dashboard: all cash currencies and crypto wallets in USD.
class SummaryPage extends StatefulWidget {
  const SummaryPage({
    super.key,
    required this.summaryService,
    required this.exchangeRateService,
  });

  final FinanceSummaryService summaryService;
  final ExchangeRateService exchangeRateService;

  @override
  SummaryPageState createState() => SummaryPageState();
}

class SummaryPageState extends State<SummaryPage> {
  FinanceSummary? _summary;
  Map<String, RateInfo> _rates = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final summary = await widget.summaryService.load();
    final rates = await widget.exchangeRateService.load(refresh: false);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _rates = rates;
    });
  }

  String _usd(double value) => '\$ ${value.toStringAsFixed(2)}';

  String _monthLabel(DateTime month, {bool withYear = false}) {
    final names = context.t('months_short').split(',');
    final name = names[month.month - 1];
    return withYear ? '$name ${month.year}' : name;
  }

  Future<void> _editRate(String code) async {
    final current = _rates[code];
    final controller = TextEditingController(
      text: current == null ? '' : current.rate.toString(),
    );
    // null → cancel, NaN → back to automatic.
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.t('summary_rate_dialog_title', params: {'code': code}),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '1 USD = ',
            suffixText: code,
            helperText: context.t('summary_rate_dialog_helper'),
            helperMaxLines: 3,
          ),
        ),
        actions: [
          if (current?.manual ?? false)
            TextButton(
              onPressed: () => Navigator.of(context).pop(double.nan),
              child: Text(context.t('summary_rate_use_auto')),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t('common_cancel')),
          ),
          FilledButton(
            onPressed: () {
              final rate = parseTokenAmount(controller.text);
              if (rate == null || rate <= 0) return;
              Navigator.of(context).pop(rate);
            },
            child: Text(context.t('common_save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await widget.exchangeRateService.setManualRate(
      code,
      result.isNaN ? null : result,
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final rateCodes = {
      for (final account in summary.accounts)
        if (!account.isCrypto && account.currencyCode != 'USD')
          account.currencyCode,
      ...summary.missingRates.where((code) => code != 'USD'),
    }.toList()..sort();

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _NetWorthHeader(summary: summary, format: _usd),
          if (summary.missingRates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(
                  context.t(
                    'summary_missing_rates',
                    params: {'codes': summary.missingRates.join(', ')},
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _MonthCard(
            summary: summary,
            format: _usd,
            monthLabel: _monthLabel(summary.currentMonth.month),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: context.t('summary_history_title'),
            child: Column(
              children: [
                TrendChart(
                  symbol: '\$',
                  buckets: [
                    for (final month in summary.history)
                      TrendBucket(
                        label: _monthLabel(month.month),
                        start: month.month,
                        incomes: month.incomes,
                        expenses: month.expenses,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const _Legend(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: context.t('summary_projection_title'),
            child: summary.projections.isEmpty
                ? Text(
                    context.t('summary_projection_empty'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          'summary_projection_basis',
                          params: {'count': '${summary.projectionBasisMonths}'},
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      for (final projection in summary.projections)
                        _ProjectionRow(
                          label: _monthLabel(projection.month, withYear: true),
                          projection: projection,
                          format: _usd,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: context.t('summary_accounts_title'),
            child: summary.accounts.isEmpty
                ? Text(context.t('summary_accounts_empty'))
                : Column(
                    children: [
                      for (final account in summary.accounts)
                        _AccountRow(account: account, format: _usd),
                    ],
                  ),
          ),
          if (rateCodes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: context.t('summary_rates_title'),
              child: Column(
                children: [
                  for (final code in rateCodes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _editRate(code),
                      title: Text(
                        _rates[code] == null
                            ? context.t(
                                'summary_rate_missing',
                                params: {'code': code},
                              )
                            : '1 USD = ${formatTokenAmount(_rates[code]!.rate)} $code',
                      ),
                      subtitle: Text(
                        context.t(
                          _rates[code]?.manual ?? false
                              ? 'summary_rate_manual'
                              : 'summary_rate_auto',
                        ),
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NetWorthHeader extends StatelessWidget {
  const _NetWorthHeader({required this.summary, required this.format});

  final FinanceSummary summary;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final onPrimary = color.onPrimary;
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
              Icon(Icons.savings_outlined, color: onPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('summary_net_worth'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: onPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              format(summary.netWorthUsd),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(
                icon: Icons.payments_outlined,
                label:
                    '${context.t('summary_cash')} ${format(summary.cashUsd)}',
              ),
              _HeaderChip(
                icon: Icons.account_balance_wallet_outlined,
                label:
                    '${context.t('tab_crypto')} ${format(summary.cryptoUsd)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: onPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.summary,
    required this.format,
    required this.monthLabel,
  });

  final FinanceSummary summary;
  final String Function(double) format;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final current = summary.currentMonth;
    final previous = summary.previousMonth;
    final pace = summary.expensePaceUsd;
    final expenseDiff = current.expenses - previous.expenses;

    return _SectionCard(
      title: context.t('summary_month_title', params: {'month': monthLabel}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: context.t('dashboard_incomes'),
                  value: format(current.incomes),
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: context.t('dashboard_expenses'),
                  value: format(current.expenses),
                  color: Colors.red,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: context.t('summary_net'),
                  value: format(current.net),
                  color: current.net >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t(
              'summary_vs_previous',
              params: {
                'amount':
                    '${expenseDiff >= 0 ? '+' : '-'}${format(expenseDiff.abs())}',
              },
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (summary.currentMonthTransferCostsUsd > 0) ...[
            const SizedBox(height: 4),
            Text(
              context.t(
                'summary_transfer_costs',
                params: {
                  'amount': format(summary.currentMonthTransferCostsUsd),
                },
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (pace != null) ...[
            const SizedBox(height: 4),
            Text(
              context.t('summary_pace', params: {'amount': format(pace)}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectionRow extends StatelessWidget {
  const _ProjectionRow({
    required this.label,
    required this.projection,
    required this.format,
  });

  final String label;
  final MonthProjection projection;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: textTheme.bodyMedium)),
          Expanded(
            child: Text(
              '+${format(projection.incomes)}  -${format(projection.expenses)}',
              style: textTheme.bodySmall,
            ),
          ),
          Text(
            format(projection.balance),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.format});

  final FinanceAccount account;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final usd = account.balanceUsd;
    final native =
        '${formatTokenAmount(account.balance)} ${account.currencyCode}';
    final showNative = account.currencyCode != 'USD';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        account.isCrypto
            ? Icons.account_balance_wallet_outlined
            : Icons.payments_outlined,
      ),
      title: Text(
        account.isCrypto
            ? account.name
            : '${context.t('summary_cash')} ${account.currencyCode}',
      ),
      subtitle: showNative ? Text(native) : null,
      trailing: Text(
        usd == null ? '—' : format(usd),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(Colors.green.shade400, context.t('dashboard_incomes')),
        const SizedBox(width: 16),
        item(Colors.red.shade400, context.t('dashboard_expenses')),
      ],
    );
  }
}
