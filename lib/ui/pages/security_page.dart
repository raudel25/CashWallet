import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/security_service.dart';
import '../widgets/confirm_dialog.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key, required this.securityService});

  final SecurityService securityService;

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _hasPin = false;
  bool _hasPassword = false;
  int _autoLockMinutes = SecurityService.defaultAutoLockMinutes;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final bioAvail = await widget.securityService.isBiometricAvailable();
    final bioEnabled = await widget.securityService.isBiometricEnabled();
    final hasPin = await widget.securityService.hasPin();
    final hasPwd = await widget.securityService.hasPassword();
    final autoLock = await widget.securityService.getAutoLockMinutes();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = bioAvail;
      _biometricEnabled = bioEnabled;
      _hasPin = hasPin;
      _hasPassword = hasPwd;
      _autoLockMinutes = autoLock;
    });
  }

  Future<void> _setPin() async {
    final hasPwd = await widget.securityService.hasPassword();
    if (!mounted) return;
    if (hasPwd) {
      final confirmed = await showConfirmDialog(
        context,
        title: context.t('security_confirm_remove_password_title'),
        content: context.t('security_confirm_remove_password_msg'),
        confirmLabel: context.t('common_save'),
        cancelLabel: context.t('common_cancel'),
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
    final value = await _showCredentialDialog(
      title: context.t('security_set_pin'),
      label: context.t('security_pin'),
      isPin: true,
      minLength: 6,
      validatorKey: 'security_pin_min',
    );
    if (value == null) return;
    await widget.securityService.setPin(value);
    if (hasPwd) {
      await widget.securityService.removePassword();
    }
    await _loadState();
  }

  Future<void> _removePin() async {
    await widget.securityService.removePin();
    await _loadState();
  }

  Future<void> _setPassword() async {
    final hasPin = await widget.securityService.hasPin();
    if (!mounted) return;
    if (hasPin) {
      final confirmed = await showConfirmDialog(
        context,
        title: context.t('security_confirm_remove_pin_title'),
        content: context.t('security_confirm_remove_pin_msg'),
        confirmLabel: context.t('common_continue'),
        cancelLabel: context.t('common_cancel'),
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
    final value = await _showCredentialDialog(
      title: context.t('security_set_password'),
      label: context.t('security_password'),
      isPin: false,
      minLength: 6,
      validatorKey: 'security_password_min',
    );
    if (value == null) return;
    await widget.securityService.setPassword(value);
    if (hasPin) {
      await widget.securityService.removePin();
    }
    await _loadState();
  }

  Future<void> _removePassword() async {
    await widget.securityService.removePassword();
    await _loadState();
  }

  Future<String?> _showCredentialDialog({
    required String title,
    required String label,
    required bool isPin,
    required int minLength,
    required String validatorKey,
  }) async {
    final formKey = GlobalKey<FormState>();
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    final node1 = FocusNode();
    final node2 = FocusNode();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: ctrl1,
                  keyboardType:
                      isPin ? TextInputType.number : TextInputType.text,
                  obscureText: true,
                  focusNode: node1,
                  decoration: InputDecoration(labelText: label),
                  validator: (v) {
                    if (v == null || v.trim().length < minLength) {
                      return context.t(validatorKey);
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(node2),
                ),
                TextFormField(
                  controller: ctrl2,
                  keyboardType:
                      isPin ? TextInputType.number : TextInputType.text,
                  obscureText: true,
                  focusNode: node2,
                  decoration: InputDecoration(
                    labelText: context.t('security_confirm'),
                  ),
                  validator: (v) {
                    if (v != ctrl1.text) {
                      return context.t('security_confirm_match');
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      result = ctrl1.text.trim();
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t('common_cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  result = ctrl1.text.trim();
                  Navigator.of(context).pop();
                }
              },
              child: Text(context.t('common_save')),
            ),
          ],
        );
      },
    );
    node1.dispose();
    node2.dispose();
    ctrl1.dispose();
    ctrl2.dispose();
    return result;
  }

  Future<void> _toggleBiometric(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (value) {
        final hasPin = await widget.securityService.hasPin();
        final hasPwd = await widget.securityService.hasPassword();
        if (!hasPin && !hasPwd) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                context.t('security_biometric_requires_credential'),
              ),
            ),
          );
          return;
        }
        final available = await widget.securityService.isBiometricAvailable();
        if (!available) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(context.t('security_biometric_unavailable')),
            ),
          );
          return;
        }
        if (!mounted) return;
        final ok = await widget.securityService.authenticateBiometrics(
          reason: context.t('security_biometric_verify'),
        );
        if (!ok) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text(context.t('security_biometric_failed'))),
          );
          return;
        }
        await widget.securityService.setBiometricEnabled(true);
        if (mounted) setState(() => _biometricEnabled = true);
      } else {
        await widget.securityService.setBiometricEnabled(false);
        if (mounted) setState(() => _biometricEnabled = false);
      }
    } catch (e, st) {
      debugPrint('SecurityPage: error toggling biometric: $e');
      debugPrint(st.toString());
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.t('security_biometric_error'))),
        );
      }
    } finally {
      await _loadState();
    }
  }

  String _autoLockLabel(BuildContext context, int minutes) {
    if (minutes <= 0) return context.t('security_auto_lock_immediately');
    if (minutes >= 9999) return context.t('security_auto_lock_never');
    return context.t(
      'security_auto_lock_minutes',
      params: {'minutes': '$minutes'},
    );
  }

  Future<void> _openAutoLockSelector() async {
    final options = <int>[0, 1, 5, 15, 30, 60, 9999];
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.t('security_auto_lock'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...options.map(
                (m) => RadioListTile<int>(
                  value: m,
                  groupValue: _autoLockMinutes,
                  title: Text(_autoLockLabel(context, m)),
                  onChanged: (_) => Navigator.of(context).pop(m),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    await widget.securityService.setAutoLockMinutes(selected);
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.pin),
            title: Text(context.t('security_pin')),
            subtitle: Text(
              _hasPin
                  ? context.t('security_pin_set')
                  : context.t('security_pin_not_set'),
            ),
            trailing: _hasPin
                ? TextButton(
                    onPressed: _removePin,
                    child: Text(context.t('security_remove')),
                  )
                : TextButton(
                    onPressed: _setPin,
                    child: Text(context.t('security_set')),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock),
            title: Text(context.t('security_password')),
            subtitle: Text(
              _hasPassword
                  ? context.t('security_password_set')
                  : context.t('security_password_not_set'),
            ),
            trailing: _hasPassword
                ? TextButton(
                    onPressed: _removePassword,
                    child: Text(context.t('security_remove')),
                  )
                : TextButton(
                    onPressed: _setPassword,
                    child: Text(context.t('security_set')),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (_biometricAvailable)
          Card(
            child: SwitchListTile(
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
              title: Text(context.t('security_biometric')),
              subtitle: Text(context.t('security_biometric_desc')),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(context.t('security_auto_lock')),
            subtitle: Text(context.t('security_auto_lock_desc')),
            trailing: Text(_autoLockLabel(context, _autoLockMinutes)),
            onTap: _openAutoLockSelector,
          ),
        ),
      ],
    );
  }
}
