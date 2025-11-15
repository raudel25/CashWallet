import 'package:flutter/material.dart';

import '../../models/currency.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.currency,
    required this.onSelectCurrency,
    required this.onOpenDenominations,
  });

  final Currency currency;
  final VoidCallback onSelectCurrency;
  final VoidCallback onOpenDenominations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Configuración', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'Selecciona un apartado para personalizar tu experiencia.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Moneda'),
            subtitle: Text('${currency.name} (${currency.code})'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onSelectCurrency,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Denominaciones'),
            subtitle: Text('Administra tus billetes en ${currency.code}.'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onOpenDenominations,
          ),
        ),
      ],
    );
  }
}
