import 'package:shared_preferences/shared_preferences.dart';

/// Stores where each wallet's blockchain sync left off. Keys use the
/// `cash_wallet_` prefix so backups include them automatically.
class CryptoSyncStateRepository {
  const CryptoSyncStateRepository();

  String _keyFor(String walletId) => 'cash_wallet_crypto_sync_$walletId';

  /// Null when the wallet was never synced.
  Future<int?> loadCursor(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFor(walletId));
  }

  Future<void> saveCursor(String walletId, int cursor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFor(walletId), cursor);
  }

  Future<void> clear(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(walletId));
  }
}
