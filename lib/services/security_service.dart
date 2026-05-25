import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _keyPin = 'security_pin';
  static const _keyPinSalt = 'security_pin_salt';
  static const _keyPassword = 'security_password';
  static const _keyPasswordSalt = 'security_password_salt';
  static const _keyBiometric = 'security_biometric_enabled';
  static const _keyFailedAttempts = 'security_failed_attempts';
  static const _keyLockedUntil = 'security_locked_until';
  static const _keyAutoLockMinutes = 'security_auto_lock_minutes';

  static const int maxAttempts = 5;
  static const int lockSeconds = 30;
  static const int defaultAutoLockMinutes = 5;

  // ---------- Hashing helpers ----------
  String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String value, String salt) {
    final bytes = utf8.encode('$salt$value');
    return sha256.convert(bytes).toString();
  }

  // ---------- Biometric ----------
  Future<bool> isBiometricAvailable() async {
    try {
      final available = await _localAuth.getAvailableBiometrics();
      if (available.isNotEmpty) return true;
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  // ---------- PIN ----------
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _keyPinSalt, value: salt);
    await _storage.write(key: _keyPin, value: hash);
    await _resetAttempts();
  }

  Future<void> removePin() async {
    await _storage.delete(key: _keyPin);
    await _storage.delete(key: _keyPinSalt);
  }

  Future<bool> hasPin() async {
    final v = await _storage.read(key: _keyPin);
    return v != null && v.isNotEmpty;
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _keyPin);
    if (stored == null || stored.isEmpty) return false;
    final salt = await _storage.read(key: _keyPinSalt);
    final ok = salt == null
        ? stored == pin // legacy plaintext
        : _hash(pin, salt) == stored;
    if (ok && salt == null) {
      // Migrate legacy plaintext to hashed.
      await setPin(pin);
    }
    if (ok) {
      await _resetAttempts();
    }
    return ok;
  }

  // ---------- Password ----------
  Future<void> setPassword(String password) async {
    final salt = _generateSalt();
    final hash = _hash(password, salt);
    await _storage.write(key: _keyPasswordSalt, value: salt);
    await _storage.write(key: _keyPassword, value: hash);
    await _resetAttempts();
  }

  Future<void> removePassword() async {
    await _storage.delete(key: _keyPassword);
    await _storage.delete(key: _keyPasswordSalt);
  }

  Future<bool> hasPassword() async {
    final v = await _storage.read(key: _keyPassword);
    return v != null && v.isNotEmpty;
  }

  Future<bool> verifyPassword(String password) async {
    final stored = await _storage.read(key: _keyPassword);
    if (stored == null || stored.isEmpty) return false;
    final salt = await _storage.read(key: _keyPasswordSalt);
    final ok = salt == null
        ? stored == password
        : _hash(password, salt) == stored;
    if (ok && salt == null) {
      await setPassword(password);
    }
    if (ok) {
      await _resetAttempts();
    }
    return ok;
  }

  // ---------- Biometric flag ----------
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

  // ---------- Attempt limiting ----------
  Future<int> getFailedAttempts() async {
    final raw = await _storage.read(key: _keyFailedAttempts);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> _resetAttempts() async {
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockedUntil);
  }

  /// Record a failed attempt. Returns the number of failed attempts so far,
  /// and locks the credentials when reaching [maxAttempts].
  Future<int> registerFailedAttempt() async {
    final current = await getFailedAttempts();
    final next = current + 1;
    await _storage.write(key: _keyFailedAttempts, value: '$next');
    if (next >= maxAttempts) {
      final until = DateTime.now().add(Duration(seconds: lockSeconds));
      await _storage.write(
        key: _keyLockedUntil,
        value: until.toIso8601String(),
      );
    }
    return next;
  }

  /// Seconds remaining in the lockout, or 0 if not locked.
  Future<int> lockoutRemainingSeconds() async {
    final raw = await _storage.read(key: _keyLockedUntil);
    if (raw == null) return 0;
    final until = DateTime.tryParse(raw);
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      // Lockout expired: clear counters so the user can try again.
      await _resetAttempts();
      return 0;
    }
    return remaining;
  }

  // ---------- Auto-lock ----------
  Future<int> getAutoLockMinutes() async {
    final raw = await _storage.read(key: _keyAutoLockMinutes);
    return int.tryParse(raw ?? '') ?? defaultAutoLockMinutes;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    await _storage.write(key: _keyAutoLockMinutes, value: '$minutes');
  }

  // ---------- Biometric prompt ----------
  Future<bool> authenticateBiometrics({String reason = 'Authenticate'}) async {
    try {
      final available = await _localAuth.getAvailableBiometrics();
      debugPrint('SecurityService: available biometrics => $available');

      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      debugPrint(
        'SecurityService: canCheckBiometrics=$canCheck, isDeviceSupported=$isDeviceSupported',
      );

      if (available.isEmpty && !canCheck && !isDeviceSupported) {
        return false;
      }

      try {
        return await _localAuth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: false,
          ),
        );
      } on PlatformException catch (e) {
        debugPrint('SecurityService: primary authenticate error: $e');
        try {
          return await _localAuth.authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: false,
            ),
          );
        } on Exception catch (e2) {
          debugPrint('SecurityService: fallback authenticate failed: $e2');
          return false;
        }
      }
    } catch (e, st) {
      debugPrint('SecurityService: unexpected error: $e');
      debugPrint(st.toString());
      return false;
    }
  }
}
