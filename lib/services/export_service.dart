import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backup format version. Bump when the structure changes incompatibly.
const int kBackupFormatVersion = 1;

/// Prefix of SharedPreferences keys that belong to the wallet. Used to scope
/// exports/imports and avoid touching unrelated preferences.
const String kWalletKeyPrefix = 'cash_wallet_';

class ExportService {
  /// Build the JSON payload to export.
  Future<Map<String, dynamic>> buildPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(kWalletKeyPrefix)) continue;
      final value = prefs.get(key);
      if (value is List<String>) {
        data[key] = {'type': 'string_list', 'value': value};
      } else if (value is String) {
        data[key] = {'type': 'string', 'value': value};
      } else if (value is int) {
        data[key] = {'type': 'int', 'value': value};
      } else if (value is double) {
        data[key] = {'type': 'double', 'value': value};
      } else if (value is bool) {
        data[key] = {'type': 'bool', 'value': value};
      }
    }
    return {
      'app': 'cash_wallet',
      'version': kBackupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
  }

  /// Write the export to a JSON file in the documents directory.
  Future<File> writeBackupFile() async {
    final payload = await buildPayload();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filename = 'cash_wallet_backup_$timestamp.json';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonStr, flush: true);
    return file;
  }

  /// Export and open the share sheet. Returns true on success.
  Future<bool> exportAndShare() async {
    try {
      final file = await writeBackupFile();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Cash Wallet backup',
      );
      return true;
    } catch (e, st) {
      debugPrint('ExportService: export error: $e');
      debugPrint(st.toString());
      return false;
    }
  }
}
