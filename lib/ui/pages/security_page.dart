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
    if (!mounted) return;
    setState(() {
      _biometricAvailable = bioAvail;
      _biometricEnabled = bioEnabled;
      _hasPin = hasPin;
      _hasPassword = hasPwd;
    });
  }

  Future<void> _setPin() async {
    // If a password is set, warn that it will be removed
    final hasPwd = await widget.securityService.hasPassword();
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
    final formKey = GlobalKey<FormState>();
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    final node1 = FocusNode();
    final node2 = FocusNode();
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t('security_set_pin')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: ctrl1,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  focusNode: node1,
                  decoration: InputDecoration(
                    labelText: context.t('security_pin'),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 6)
                      return context.t('security_pin_min');
                    return null;
                  },
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(node2),
                ),
                TextFormField(
                  controller: ctrl2,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  focusNode: node2,
                  decoration: InputDecoration(
                    labelText: context.t('security_confirm'),
                  ),
                  validator: (v) {
                    if (v != ctrl1.text)
                      return context.t('security_confirm_match');
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.t('common_cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false)
                  Navigator.of(context).pop(true);
              },
              child: Text(context.t('common_save')),
            ),
          ],
        );
      },
    );
    if (res == true) {
      await widget.securityService.setPin(ctrl1.text.trim());
      if (hasPwd) {
        await widget.securityService.removePassword();
      }
      await _loadState();
    }
    node1.dispose();
    node2.dispose();
  }

  Future<void> _removePin() async {
    await widget.securityService.removePin();
    await _loadState();
  }

  Future<void> _setPassword() async {
    // If a PIN is set, warn that it will be removed
    final hasPin = await widget.securityService.hasPin();
    if (hasPin) {
      final confirmed = await showConfirmDialog(
        context,
        title: context.t('security_confirm_remove_pin_title'),
        content: context.t('security_confirm_remove_pin_msg'),
        confirmLabel: context.t('common_save'),
        cancelLabel: context.t('common_cancel'),
      );
      if (!confirmed) return;
    }
    final formKey = GlobalKey<FormState>();
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    final node1 = FocusNode();
    final node2 = FocusNode();
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t('security_set_password')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: ctrl1,
                  obscureText: true,
                  focusNode: node1,
                  decoration: InputDecoration(
                    labelText: context.t('security_password'),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 6)
                      return context.t('security_password_min');
                    return null;
                  },
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(node2),
                ),
                TextFormField(
                  controller: ctrl2,
                  obscureText: true,
                  focusNode: node2,
                  decoration: InputDecoration(
                    labelText: context.t('security_confirm'),
                  ),
                  validator: (v) {
                    if (v != ctrl1.text)
                      return context.t('security_confirm_match');
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.t('common_cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false)
                  Navigator.of(context).pop(true);
              },
              child: Text(context.t('common_continue')),
            ),
          ],
        );
      },
    );
    if (res == true) {
      await widget.securityService.setPassword(ctrl1.text.trim());
      if (hasPin) {
        await widget.securityService.removePin();
      }
      await _loadState();
    }
  }

  Future<void> _removePassword() async {
    await widget.securityService.removePassword();
    await _loadState();
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final hasPin = await widget.securityService.hasPin();
      final hasPwd = await widget.securityService.hasPassword();
      if (!hasPin && !hasPwd) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('security_biometric_requires_credential')),
          ),
        );
        return;
      }
      final available = await widget.securityService.isBiometricAvailable();
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('security_biometric_unavailable'))),
        );
        return;
      }
      final ok = await widget.securityService.authenticateBiometrics(
        reason: context.t('security_biometric_verify'),
      );
      if (!ok) return;
      await widget.securityService.setBiometricEnabled(true);
    } else {
      await widget.securityService.setBiometricEnabled(false);
    }
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
      ],
    );
  }
}
