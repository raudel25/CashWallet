import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'export_service.dart';

class ImportException implements Exception {
  ImportException(this.message);
  final String message;

  @override
  String toString() => 'ImportException: $message';
}

class ImportService {
  /// Parse and restore a backup file. Replaces all wallet-scoped preferences.
  Future<void> importFromFile(File file) async {
    final raw = await file.readAsString();
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw ImportException('Invalid JSON');
    }
    final app = decoded['app'];
    if (app != 'cash_wallet') {
      throw ImportException('Unknown backup origin');
    }
    final version = decoded['version'];
    if (version is! int || version > kBackupFormatVersion) {
      throw ImportException('Unsupported backup version');
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw ImportException('Malformed backup data');
    }

    final prefs = await SharedPreferences.getInstance();

    // Remove all current wallet-scoped keys first.
    final currentKeys = prefs.getKeys().where(
      (k) => k.startsWith(kWalletKeyPrefix),
    );
    for (final key in currentKeys) {
      await prefs.remove(key);
    }

    // Restore from payload.
    for (final entry in data.entries) {
      final key = entry.key;
      if (!key.startsWith(kWalletKeyPrefix)) continue;
      final value = entry.value;
      if (value is! Map) continue;
      final type = value['type'];
      final raw = value['value'];
      try {
        switch (type) {
          case 'string_list':
            await prefs.setStringList(
              key,
              (raw as List).map((e) => e.toString()).toList(),
            );
            break;
          case 'string':
            await prefs.setString(key, raw as String);
            break;
          case 'int':
            await prefs.setInt(key, (raw as num).toInt());
            break;
          case 'double':
            await prefs.setDouble(key, (raw as num).toDouble());
            break;
          case 'bool':
            await prefs.setBool(key, raw as bool);
            break;
          default:
            // Unknown type, skip.
            break;
        }
      } catch (e) {
        debugPrint('ImportService: failed to restore $key: $e');
      }
    }
  }
}
