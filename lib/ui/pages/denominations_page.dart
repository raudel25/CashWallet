import 'package:flutter/material.dart';

import '../../data/denomination_repository.dart';
import '../../models/denomination.dart';

class DenominationsPage extends StatefulWidget {
  const DenominationsPage({super.key});

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
    final stored = await _repository.load();
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
        const SnackBar(content: Text('Esta denominación ya está registrada.')),
      );
      return;
    }

    final updated = [..._denominations, Denomination(value)]
      ..sort((a, b) => a.value.compareTo(b.value));
    await _repository.save(updated);

    if (!mounted) return;
    setState(() => _denominations = updated);
  }

  Future<void> _removeDenomination(Denomination denomination) async {
    final updated = _denominations.where((d) => d != denomination).toList();
    await _repository.save(updated);

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
          title: const Text('Nueva denominación'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un monto válido';
                }
                final normalized = value.replaceAll(',', '.');
                final parsed = double.tryParse(normalized);
                if (parsed == null || parsed <= 0) {
                  return 'El monto debe ser mayor que cero';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleAddValue(controller, formKey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => _handleAddValue(controller, formKey),
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
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
            'Agrega cada una de las denominaciones de efectivo que tienes guardadas.',
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
  const _DenominationTile({required this.denomination, required this.onDelete});

  final Denomination denomination;
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
        title: Text('\$ ${_formatAmount(denomination.value)}'),
        subtitle: const Text('Denominación guardada'),
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
            'Todavía no has añadido denominaciones.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Utiliza el botón “Añadir” para empezar.',
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
