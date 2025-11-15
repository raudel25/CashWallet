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
    required this.onSelectTheme,
    required this.currentThemeMode,
  });

  final Currency currency;
  final VoidCallback onSelectCurrency;
  final VoidCallback onSelectLanguage;
  final String currentLanguageLabel;
  final VoidCallback onOpenDenominations;
  final Future<void> Function(ThemeMode) onSelectTheme;
  final ThemeMode currentThemeMode;

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
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(context.t('settings_theme')),
            subtitle: Text(_themeLabel(context, currentThemeMode)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final selected = await showModalBottomSheet<ThemeMode>(
                context: context,
                builder: (context) {
                  ThemeMode temp = currentThemeMode;
                  return StatefulBuilder(
                    builder: (context, setState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          groupValue: temp,
                          title: Text(context.t('theme_system')),
                          onChanged: (v) => setState(() => temp = v!),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          groupValue: temp,
                          title: Text(context.t('theme_light')),
                          onChanged: (v) => setState(() => temp = v!),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          groupValue: temp,
                          title: Text(context.t('theme_dark')),
                          onChanged: (v) => setState(() => temp = v!),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(context.t('common_cancel')),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(temp),
                                  child: Text(context.t('common_save')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
              if (selected != null) await onSelectTheme(selected);
            },
          ),
        ),
      ],
    );
  }

  String _themeLabel(BuildContext context, ThemeMode mode) {
    if (mode == ThemeMode.light) return context.t('theme_light');
    if (mode == ThemeMode.dark) return context.t('theme_dark');
    return context.t('theme_system');
  }
}
