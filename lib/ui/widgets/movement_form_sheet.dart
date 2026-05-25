import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/cash_entry.dart';
import '../../models/denomination.dart';
import '../../models/denomination_count.dart';

class MovementFormResult {
  const MovementFormResult({
    required this.description,
    required this.breakdown,
    required this.createdAt,
  });

  final String description;
  final List<DenominationCount> breakdown;
  final DateTime createdAt;
}

class MovementFormSheet extends StatefulWidget {
  const MovementFormSheet({
    super.key,
    required this.type,
    required this.denominations,
    required this.currencySymbol,
    this.availableStock,
    this.initialEntry,
  });

  final CashEntryType type;
  final List<Denomination> denominations;
  final String currencySymbol;

  /// For expenses: available stock per denomination. Null for incomes.
  final Map<double, int>? availableStock;

  /// If provided, the sheet works in edit mode.
  final CashEntry? initialEntry;

  bool get isExpense => type == CashEntryType.expense;
  bool get isEditing => initialEntry != null;

  @override
  State<MovementFormSheet> createState() => _MovementFormSheetState();
}

class _MovementFormSheetState extends State<MovementFormSheet> {
  late final Map<double, TextEditingController> _quantityControllers;
  late final Map<double, FocusNode> _quantityFocusNodes;
  late final TextEditingController _descriptionController;
  late final FocusNode _descriptionFocus;
  late DateTime _selectedDate;
  double _total = 0;
  Map<double, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEntry;
    final initialQuantities = <double, int>{
      for (final item in initial?.breakdown ?? const <DenominationCount>[])
        item.denomination: item.quantity,
    };
    _quantityControllers = {
      for (final denomination in widget.denominations)
        denomination.value: TextEditingController(
          text: (initialQuantities[denomination.value] ?? 0).toString(),
        ),
    };
    _quantityFocusNodes = {
      for (final denomination in widget.denominations)
        denomination.value: FocusNode(),
    };
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _descriptionFocus = FocusNode();
    _selectedDate = initial?.createdAt ?? DateTime.now();
    _total = _calculateTotal();
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final node in _quantityFocusNodes.values) {
      node.dispose();
    }
    _descriptionFocus.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double _calculateTotal() {
    return widget.denominations.fold<double>(0, (sum, denomination) {
      final controller = _quantityControllers[denomination.value]!;
      final quantity = int.tryParse(controller.text) ?? 0;
      return sum + denomination.value * quantity;
    });
  }

  void _updateTotal() {
    setState(() => _total = _calculateTotal());
  }

  List<DenominationCount> _buildBreakdown() {
    return widget.denominations
        .map(
          (denomination) => DenominationCount(
            denomination: denomination.value,
            quantity:
                int.tryParse(_quantityControllers[denomination.value]!.text) ??
                0,
          ),
        )
        .where((item) => item.quantity > 0)
        .toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? _selectedDate.hour,
        time?.minute ?? _selectedDate.minute,
      );
    });
  }

  void _submit() {
    if (_total <= 0) {
      final messageKey = widget.isExpense
          ? 'home_need_expense_units'
          : 'home_need_income_units';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(messageKey))));
      return;
    }

    final breakdown = _buildBreakdown();

    if (widget.isExpense) {
      final stock = widget.availableStock ?? const <double, int>{};
      final initialBreakdown = <double, int>{
        for (final item in widget.initialEntry?.breakdown ?? const [])
          item.denomination: item.quantity,
      };
      final Map<double, String> newErrors = {};
      for (final item in breakdown) {
        final available =
            (stock[item.denomination] ?? 0) +
            (initialBreakdown[item.denomination] ?? 0);
        if (item.quantity > available) {
          newErrors[item.denomination] = context.t(
            'home_only_have_units',
            params: {
              'count': '$available',
              'value':
                  '${widget.currencySymbol} ${item.denomination.toStringAsFixed(2)}',
            },
          );
        }
      }
      if (newErrors.isNotEmpty) {
        setState(() => _errors = newErrors);
        return;
      }
      if (_errors.isNotEmpty) {
        setState(() => _errors = {});
      }
    }

    Navigator.of(context).pop(
      MovementFormResult(
        description: _descriptionController.text.trim(),
        breakdown: breakdown,
        createdAt: _selectedDate,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = widget.isExpense;
    final accentColor = isExpense ? Colors.red : Colors.green;
    final titleKey = widget.isEditing
        ? (isExpense ? 'home_edit_expense' : 'home_edit_income')
        : (isExpense ? 'home_new_expense' : 'home_new_income');
    final instructionKey = isExpense
        ? 'home_expense_instruction'
        : 'home_income_instruction';
    final hintKey = isExpense
        ? 'home_description_expense_hint'
        : 'home_description_income_hint';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExpense ? Icons.trending_down : Icons.trending_up,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t(titleKey),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.t(instructionKey),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final denomination = widget.denominations[index];
                  final controller =
                      _quantityControllers[denomination.value]!;
                  final focusNode = _quantityFocusNodes[denomination.value]!;
                  final isLast = index == widget.denominations.length - 1;
                  final error = _errors[denomination.value];
                  final hint = isExpense && widget.availableStock != null
                      ? context.t(
                          'form_available_hint',
                          params: {
                            'count':
                                '${(widget.availableStock?[denomination.value] ?? 0) + ((widget.initialEntry?.breakdown.firstWhere((item) => item.denomination == denomination.value, orElse: () => DenominationCount(denomination: denomination.value, quantity: 0)).quantity) ?? 0)}',
                          },
                        )
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText:
                              '${widget.currencySymbol} ${denomination.value.toStringAsFixed(2)}',
                          helperText: hint,
                          suffixText: context.t('common_units'),
                          errorText: error,
                        ),
                        onChanged: (_) {
                          _updateTotal();
                          if (_errors.containsKey(denomination.value)) {
                            setState(
                              () => _errors.remove(denomination.value),
                            );
                          }
                        },
                        onFieldSubmitted: (_) {
                          if (!isLast) {
                            final nextDenom =
                                widget.denominations[index + 1].value;
                            _quantityFocusNodes[nextDenom]?.requestFocus();
                          } else {
                            _descriptionFocus.requestFocus();
                          }
                        },
                      ),
                    ],
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: widget.denominations.length,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              focusNode: _descriptionFocus,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: context.t('home_description_label'),
                hintText: context.t(hintKey),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('form_date_label'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _formatDate(_selectedDate),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit_calendar,
                      color: Theme.of(context).hintColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.t('home_total_calculated')),
                Text(
                  '${widget.currencySymbol} ${_total.toStringAsFixed(2)}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: accentColor),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: Text(context.t('common_save')),
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
