import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/currency.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.currency,
    required this.onSelectCurrency,
    required this.onSelectLanguage,
    required this.currentLanguageLabel,
    required this.onOpenDenominations,
  });

  final Currency currency;
  final VoidCallback onSelectCurrency;
  final VoidCallback onSelectLanguage;
  final String currentLanguageLabel;
  final VoidCallback onOpenDenominations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.t('settings_title'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          context.t('settings_description'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: Text(context.t('settings_currency')),
            subtitle: Text(
              context.t(
                'settings_currency_subtitle',
                params: {'name': currency.name, 'code': currency.code},
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onSelectCurrency,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.t('settings_language')),
            subtitle: Text(currentLanguageLabel),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onSelectLanguage,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: Text(context.t('settings_denominations')),
            subtitle: Text(
              context.t(
                'settings_denominations_subtitle',
                params: {'currency': currency.code},
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onOpenDenominations,
          ),
        ),
      ],
    );
  }
}
