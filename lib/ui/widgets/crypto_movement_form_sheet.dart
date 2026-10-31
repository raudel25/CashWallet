import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/cash_entry.dart';
import '../../models/crypto_entry.dart';

/// Parses user input accepting both "12.5" and "12,5". Returns null if invalid.
double? parseTokenAmount(String raw) {
  return double.tryParse(raw.trim().replaceAll(',', '.'));
}

class CryptoMovementFormResult {
  const CryptoMovementFormResult({
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  final double amount;
  final String description;
  final DateTime createdAt;
}

class CryptoMovementFormSheet extends StatefulWidget {
  const CryptoMovementFormSheet({
    super.key,
    required this.type,
    required this.tokenSymbol,
    required this.availableBalance,
    this.initialEntry,
  });

  final CashEntryType type;
  final String tokenSymbol;

  /// Current wallet balance, used to validate expenses.
  final double availableBalance;

  /// If provided, the sheet works in edit mode.
  final CryptoEntry? initialEntry;

  bool get isExpense => type == CashEntryType.expense;
  bool get isEditing => initialEntry != null;

  /// Imported movements mirror the blockchain: only the description changes.
  bool get isLocked => initialEntry?.isImported ?? false;

  @override
  State<CryptoMovementFormSheet> createState() =>
      _CryptoMovementFormSheetState();
}

class _CryptoMovementFormSheetState extends State<CryptoMovementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEntry;
    _amountController = TextEditingController(
      text: initial == null ? '' : formatTokenAmount(initial.amount),
    );
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _selectedDate = initial?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// When editing an expense, its own amount is available again.
  double get _maxExpense {
    final initial = widget.initialEntry;
    return widget.availableBalance +
        (initial != null && initial.type == CashEntryType.expense
            ? initial.amount
            : 0);
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

  String? _validateAmount(String? value) {
    if (widget.isLocked) return null;
    final amount = parseTokenAmount(value ?? '');
    if (amount == null || amount <= 0) {
      return context.t('crypto_amount_invalid');
    }
    // Small tolerance to avoid floating point false positives.
    if (widget.isExpense && amount > _maxExpense + 1e-9) {
      return context.t(
        'crypto_amount_exceeds',
        params: {
          'amount': '${formatTokenAmount(_maxExpense)} ${widget.tokenSymbol}',
        },
      );
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CryptoMovementFormResult(
        amount: parseTokenAmount(_amountController.text)!,
        description: _descriptionController.text.trim(),
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
        child: Form(
          key: _formKey,
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                autofocus: !widget.isEditing,
                readOnly: widget.isLocked,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: context.t('crypto_amount'),
                  suffixText: widget.tokenSymbol,
                  helperText: widget.isLocked
                      ? context.t('crypto_imported_locked')
                      : isExpense
                      ? context.t(
                          'crypto_available',
                          params: {
                            'amount':
                                '${formatTokenAmount(_maxExpense)} ${widget.tokenSymbol}',
                          },
                        )
                      : null,
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
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
                onTap: widget.isLocked ? null : _pickDate,
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
      ),
    );
  }
}
