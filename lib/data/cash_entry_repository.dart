import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cash_entry.dart';

class CashEntryRepository {
  CashEntryRepository(this.storageKey);

  final String storageKey;

  // Broadcast stream to notify listeners when a save occurs for a currency.
  final StreamController<String> _changes = StreamController.broadcast();

  Stream<String> get changes => _changes.stream;

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
    // Notify listeners that entries for this currency were updated.
    try {
      _changes.add(currencyCode);
    } catch (_) {
      // ignore if controller is closed or add fails
    }
  }

  Future<void> add(String currencyCode, CashEntry entry) async {
    final entries = await load(currencyCode);
    await save(currencyCode, [entry, ...entries]);
  }

  Future<void> update(String currencyCode, CashEntry entry) async {
    final entries = await load(currencyCode);
    final updated = entries
        .map((item) => item.id == entry.id ? entry : item)
        .toList();
    await save(currencyCode, updated);
  }

  Future<void> delete(String currencyCode, String entryId) async {
    final entries = await load(currencyCode);
    final updated = entries.where((item) => item.id != entryId).toList();
    await save(currencyCode, updated);
  }

  // Close controller when repository is disposed (not used currently).
  void dispose() {
    _changes.close();
  }
}
