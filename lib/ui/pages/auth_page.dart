import 'package:flutter/material.dart';
import '../../services/security_service.dart';
import '../../l10n/app_localizations.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.securityService,
    required this.onAuthenticated,
  });

  final SecurityService securityService;
  final VoidCallback onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  String _error = '';
  final _pinController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = true;
  bool _biometricEnabled = false;
  bool _hasPin = false;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final bio = await widget.securityService.isBiometricEnabled();
    final hasPin = await widget.securityService.hasPin();
    final hasPwd = await widget.securityService.hasPassword();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = bio;
      _hasPin = hasPin;
      _hasPassword = hasPwd;
      _loading = false;
    });
    if (_biometricEnabled) {
      final ok = await widget.securityService.authenticateBiometrics(
        reason: context.t('security_biometric_verify'),
      );
      if (ok) {
        widget.onAuthenticated();
      }
    }
  }

  Future<void> _tryPin() async {
    final pin = _pinController.text.trim();
    final ok = await widget.securityService.verifyPin(pin);
    if (ok) return widget.onAuthenticated();
    setState(() => _error = context.t('security_invalid_pin'));
  }

  Future<void> _tryPassword() async {
    final pwd = _passwordController.text.trim();
    final ok = await widget.securityService.verifyPassword(pwd);
    if (ok) return widget.onAuthenticated();
    setState(() => _error = context.t('security_invalid_password'));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 28.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(Icons.lock, size: 36, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.t('security_unlock_title'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('security_biometric_prompt'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      if (_biometricEnabled)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final ok = await widget.securityService
                                    .authenticateBiometrics(
                                      reason: context.t(
                                        'security_biometric_verify',
                                      ),
                                    );
                                if (ok) widget.onAuthenticated();
                              },
                              icon: const Icon(Icons.fingerprint),
                              label: Text(context.t('security_biometric')),
                            ),
                          ),
                        ),
                      if (_hasPin) ...[
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: context.t('security_pin'),
                            errorText: _error.isEmpty ? null : _error,
                            counterText: '',
                          ),
                          onSubmitted: (_) => _tryPin(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _tryPin,
                            child: Text(context.t('security_unlock')),
                          ),
                        ),
                      ],
                      if (!_hasPin && _hasPassword) ...[
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: context.t('security_password'),
                            errorText: _error.isEmpty ? null : _error,
                          ),
                          onSubmitted: (_) => _tryPassword(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _tryPassword,
                            child: Text(context.t('security_unlock')),
                          ),
                        ),
                      ],
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
