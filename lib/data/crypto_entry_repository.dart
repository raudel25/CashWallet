import 'package:shared_preferences/shared_preferences.dart';

import '../models/crypto_entry.dart';

/// Movements are stored per wallet. Keys use the `cash_wallet_` prefix so
/// backups include them automatically.
class CryptoEntryRepository {
  const CryptoEntryRepository();

  String _keyFor(String walletId) => 'cash_wallet_crypto_entries_$walletId';

  Future<List<CryptoEntry>> load(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyFor(walletId)) ?? [];
    return raw.map(CryptoEntry.fromJson).map(_migrateLegacyAdjustment).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Older versions recorded "Adjust" as a plain income or expense, which
  /// inflated the summary. Adjustments only reconcile the balance, so they
  /// are treated as part of the opening balance.
  static const _legacyAdjustmentDescriptions = {
    'Ajuste de sincronización',
    'Sync adjustment',
  };

  CryptoEntry _migrateLegacyAdjustment(CryptoEntry entry) {
    if (entry.isOpening || entry.isImported || entry.isTransfer) return entry;
    if (!_legacyAdjustmentDescriptions.contains(entry.description)) {
      return entry;
    }
    return entry.copyWith(isOpening: true);
  }

  Future<void> save(String walletId, List<CryptoEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyFor(walletId),
      entries.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<void> add(CryptoEntry entry) async {
    final entries = await load(entry.walletId);
    await save(entry.walletId, [entry, ...entries]);
  }

  Future<void> update(CryptoEntry entry) async {
    final entries = await load(entry.walletId);
    await save(
      entry.walletId,
      entries.map((item) => item.id == entry.id ? entry : item).toList(),
    );
  }

  Future<void> delete(String walletId, String entryId) async {
    final entries = await load(walletId);
    await save(walletId, entries.where((item) => item.id != entryId).toList());
  }

  Future<void> deleteAll(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(walletId));
  }

  Future<double> balance(String walletId) async {
    final entries = await load(walletId);
    return entries.fold<double>(0, (sum, entry) => sum + entry.signedAmount);
  }
}
