import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/currency.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';
import '../widgets/confirm_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.currency,
    required this.onSelectCurrency,
    required this.onSelectLanguage,
    required this.currentLanguageLabel,
    required this.onOpenDenominations,
    required this.onOpenSecurity,
    required this.onSelectTheme,
    required this.currentThemeMode,
    required this.onDataChanged,
  });

  final Currency currency;
  final VoidCallback onSelectCurrency;
  final VoidCallback onSelectLanguage;
  final String currentLanguageLabel;
  final VoidCallback onOpenDenominations;
  final VoidCallback onOpenSecurity;
  final Future<void> Function(ThemeMode) onSelectTheme;
  final ThemeMode currentThemeMode;
  final Future<void> Function() onDataChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.t('settings_description'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          icon: Icons.currency_exchange,
          title: context.t('settings_currency'),
          subtitle: context.t(
            'settings_currency_subtitle',
            params: {'name': currency.name, 'code': currency.code},
          ),
          onTap: onSelectCurrency,
        ),
        _SettingsCard(
          icon: Icons.language,
          title: context.t('settings_language'),
          subtitle: currentLanguageLabel,
          onTap: onSelectLanguage,
        ),
        _SettingsCard(
          icon: Icons.savings_outlined,
          title: context.t('settings_denominations'),
          subtitle: context.t(
            'settings_denominations_subtitle',
            params: {'currency': currency.code},
          ),
          onTap: onOpenDenominations,
        ),
        _SettingsCard(
          icon: Icons.security,
          title: context.t('security_title'),
          subtitle: context.t('security_subtitle'),
          onTap: onOpenSecurity,
        ),
        _SettingsCard(
          icon: Icons.brightness_6,
          title: context.t('settings_theme'),
          subtitle: _themeLabel(context, currentThemeMode),
          onTap: () => _openThemeSelector(context),
        ),
        _BackupCard(
          onExport: () => _handleExport(context),
          onImport: () => _handleImport(context),
        ),
      ],
    );
  }

  Future<void> _openThemeSelector(BuildContext context) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.t('settings_theme'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: currentThemeMode,
                title: Text(context.t('theme_system')),
                onChanged: (_) => Navigator.of(context).pop(ThemeMode.system),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: currentThemeMode,
                title: Text(context.t('theme_light')),
                onChanged: (_) => Navigator.of(context).pop(ThemeMode.light),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: currentThemeMode,
                title: Text(context.t('theme_dark')),
                onChanged: (_) => Navigator.of(context).pop(ThemeMode.dark),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) await onSelectTheme(selected);
  }

  Future<void> _handleExport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedMsg = context.t('settings_export_failed');
    final ok = await ExportService().exportAndShare();
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(failedMsg)));
    }
  }

  Future<void> _handleImport(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.t('settings_import_confirm_title'),
      content: context.t('settings_import_confirm_msg'),
      confirmLabel: context.t('settings_import'),
    );
    if (!confirmed) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final successMsg = context.t('settings_import_success');
    final failedMsg = context.t('settings_import_failed');

    try {
      final file = File(result.files.single.path!);
      await ImportService().importFromFile(file);
      await onDataChanged();
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$failedMsg ($e)')));
    }
  }

  String _themeLabel(BuildContext context, ThemeMode mode) {
    if (mode == ThemeMode.light) return context.t('theme_light');
    if (mode == ThemeMode.dark) return context.t('theme_dark');
    return context.t('theme_system');
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.onExport, required this.onImport});

  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_sync_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('settings_backup'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        context.t('settings_backup_subtitle'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onExport,
                    icon: const Icon(Icons.upload_outlined),
                    label: Text(context.t('settings_export')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(context.t('settings_import')),
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
