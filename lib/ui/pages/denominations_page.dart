import 'package:flutter/material.dart';

import '../../data/denomination_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/currency.dart';
import '../../models/denomination.dart';

class DenominationsPage extends StatefulWidget {
  const DenominationsPage({
    super.key,
    required this.loadStock,
    required this.currency,
  });

  final Future<Map<double, int>> Function() loadStock;
  final Currency currency;

  @override
  DenominationsPageState createState() => DenominationsPageState();
}

class DenominationsPageState extends State<DenominationsPage> {
  final DenominationRepository _repository = const DenominationRepository();
  List<Denomination> _denominations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDenominations();
  }

  Future<void> openAddDialog() => _openAddDenominationDialog();

  Future<void> _loadDenominations() async {
    final stored = await _repository.load(widget.currency.code);
    setState(() {
      _denominations = stored;
      _isLoading = false;
    });
  }

  Future<void> _addDenomination(double value) async {
    final exists = _denominations.any(
      (denomination) => (denomination.value - value).abs() < 0.001,
    );
    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('denominations_exists'))),
      );
      return;
    }

    final updated = [..._denominations, Denomination(value)]
      ..sort((a, b) => a.value.compareTo(b.value));
    await _repository.save(widget.currency.code, updated);

    if (!mounted) return;
    setState(() => _denominations = updated);
  }

  Future<void> _removeDenomination(Denomination denomination) async {
    final stock = await widget.loadStock();
    final available = stock[denomination.value] ?? 0;
    if (available > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'denominations_remove_error',
              params: {
                'value':
                    '${widget.currency.symbol}${denomination.value.toStringAsFixed(2)}',
                'count': '$available',
              },
            ),
          ),
        ),
      );
      return;
    }

    final updated = _denominations.where((d) => d != denomination).toList();
    await _repository.save(widget.currency.code, updated);

    if (!mounted) return;
    setState(() => _denominations = updated);
  }

  Future<void> _openAddDenominationDialog() async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t('denominations_dialog_title')),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.t('denominations_amount_label'),
                prefixText: '${widget.currency.symbol} ',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.t('denominations_amount_invalid');
                }
                final normalized = value.replaceAll(',', '.');
                final parsed = double.tryParse(normalized);
                if (parsed == null || parsed <= 0) {
                  return context.t('denominations_amount_gt_zero');
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleAddValue(controller, formKey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t('common_cancel')),
            ),
            FilledButton.icon(
              onPressed: () => _handleAddValue(controller, formKey),
              icon: const Icon(Icons.save),
              label: Text(context.t('common_save')),
            ),
          ],
        );
      },
    );
  }

  void _handleAddValue(
    TextEditingController controller,
    GlobalKey<FormState> formKey,
  ) {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final normalized = controller.text.replaceAll(',', '.');
    final value = double.parse(normalized);
    _addDenomination(value).then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'denominations_intro',
              params: {'currency': widget.currency.code},
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _denominations.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemBuilder: (context, index) {
                      final denomination = _denominations[index];
                      return _DenominationTile(
                        denomination: denomination,
                        symbol: widget.currency.symbol,
                        onDelete: () => _removeDenomination(denomination),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: _denominations.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DenominationTile extends StatelessWidget {
  const _DenominationTile({
    required this.denomination,
    required this.symbol,
    required this.onDelete,
  });

  final Denomination denomination;
  final String symbol;
  final VoidCallback onDelete;

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('$symbol ${_formatAmount(denomination.value)}'),
        subtitle: Text(context.t('denominations_saved_label')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.savings_outlined, size: 64, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            context.t('denominations_empty_title'),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.t('denominations_empty_subtitle'),
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
