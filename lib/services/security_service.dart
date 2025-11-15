import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  SecurityService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _keyPin = 'security_pin';
  static const _keyPassword = 'security_password';
  static const _keyBiometric = 'security_biometric_enabled';

  Future<bool> isBiometricAvailable() async {
    try {
      // Prefer checking available biometrics; some platforms return canCheckBiometrics
      // but no enrolled biometrics. Use both checks for robustness.
      final available = await _localAuth.getAvailableBiometrics();
      if (available.isNotEmpty) return true;
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _keyPin, value: pin);
  }

  Future<void> removePin() async {
    await _storage.delete(key: _keyPin);
  }

  Future<bool> hasPin() async {
    final v = await _storage.read(key: _keyPin);
    return v != null && v.isNotEmpty;
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _keyPin);
    return stored == pin;
  }

  Future<void> setPassword(String password) async {
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<void> removePassword() async {
    await _storage.delete(key: _keyPassword);
  }

  Future<bool> hasPassword() async {
    final v = await _storage.read(key: _keyPassword);
    return v != null && v.isNotEmpty;
  }

  Future<bool> verifyPassword(String password) async {
    final stored = await _storage.read(key: _keyPassword);
    return stored == password;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometric, value: enabled ? '1' : '0');
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _storage.read(key: _keyBiometric);
    return v == '1';
  }

  Future<bool> anySecurityEnabled() async {
    final hasPinV = await hasPin();
    final hasPwd = await hasPassword();
    final bio = await isBiometricEnabled();
    return hasPinV || hasPwd || bio;
  }

  Future<bool> authenticateBiometrics({String reason = 'Authenticate'}) async {
    try {
      // Allow device credential fallback (biometric or device PIN/passcode)
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }
}
