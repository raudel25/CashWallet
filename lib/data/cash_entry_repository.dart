import 'package:shared_preferences/shared_preferences.dart';

import '../models/cash_entry.dart';

class CashEntryRepository {
  const CashEntryRepository(this.storageKey);

  final String storageKey;

  String _keyFor(String currencyCode) => '${storageKey}_$currencyCode';

  Future<List<CashEntry>> load(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    final rawEntries = prefs.getStringList(_keyFor(currencyCode)) ?? [];
    final entries = rawEntries.map(CashEntry.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> save(String currencyCode, List<CashEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = entries.map((entry) => entry.toJson()).toList();
    await prefs.setStringList(_keyFor(currencyCode), payload);
  }
}
