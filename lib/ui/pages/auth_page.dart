import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/security_service.dart';

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

  int _lockSeconds = 0;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _pinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final bio = await widget.securityService.isBiometricEnabled();
    final hasPin = await widget.securityService.hasPin();
    final hasPwd = await widget.securityService.hasPassword();
    final lockRemaining = await widget.securityService.lockoutRemainingSeconds();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = bio;
      _hasPin = hasPin;
      _hasPassword = hasPwd;
      _lockSeconds = lockRemaining;
      _loading = false;
    });
    if (_lockSeconds > 0) {
      _startLockTimer();
    } else if (_biometricEnabled) {
      _tryBiometric();
    }
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _lockSeconds--);
      if (_lockSeconds <= 0) {
        timer.cancel();
        _lockSeconds = 0;
      }
    });
  }

  Future<void> _tryBiometric() async {
    if (_lockSeconds > 0) return;
    final ok = await widget.securityService.authenticateBiometrics(
      reason: context.t('security_biometric_verify'),
    );
    if (ok && mounted) widget.onAuthenticated();
  }

  Future<void> _verify(Future<bool> Function() check, String invalidKey) async {
    if (_lockSeconds > 0) return;
    final ok = await check();
    if (!mounted) return;
    if (ok) {
      widget.onAuthenticated();
      return;
    }
    final attempts = await widget.securityService.registerFailedAttempt();
    final lockRemaining = await widget.securityService.lockoutRemainingSeconds();
    if (!mounted) return;
    setState(() {
      _error = context.t(invalidKey);
      _lockSeconds = lockRemaining;
    });
    if (lockRemaining > 0) {
      _startLockTimer();
    } else {
      final remainingAttempts = SecurityService.maxAttempts - attempts;
      if (remainingAttempts > 0) {
        setState(() {
          _error =
              '${context.t(invalidKey)} · ${context.t('security_attempts_remaining', params: {'count': '$remainingAttempts'})}';
        });
      }
    }
  }

  Future<void> _tryPin() => _verify(
        () => widget.securityService.verifyPin(_pinController.text.trim()),
        'security_invalid_pin',
      );

  Future<void> _tryPassword() => _verify(
        () => widget.securityService.verifyPassword(
          _passwordController.text.trim(),
        ),
        'security_invalid_password',
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isLocked = _lockSeconds > 0;
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
                        child: const Icon(
                          Icons.lock,
                          size: 36,
                          color: Colors.white,
                        ),
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
                      if (isLocked)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Icon(
                                Icons.lock_clock,
                                color: Theme.of(context).colorScheme.error,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.t('security_locked_title'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.t(
                                  'security_locked_msg',
                                  params: {'seconds': '$_lockSeconds'},
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        if (_biometricEnabled)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _tryBiometric,
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
                            maxLength: 12,
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
