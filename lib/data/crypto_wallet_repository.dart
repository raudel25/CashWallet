import 'package:shared_preferences/shared_preferences.dart';

import '../models/crypto_wallet.dart';

/// Keys use the `cash_wallet_` prefix so backups include them automatically.
class CryptoWalletRepository {
  const CryptoWalletRepository();

  static const _storageKey = 'cash_wallet_crypto_wallets';

  Future<List<CryptoWallet>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    return raw.map(CryptoWallet.fromJson).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> save(List<CryptoWallet> wallets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      wallets.map((wallet) => wallet.toJson()).toList(),
    );
  }

  Future<void> add(CryptoWallet wallet) async {
    final wallets = await load();
    await save([...wallets, wallet]);
  }

  Future<void> update(CryptoWallet wallet) async {
    final wallets = await load();
    await save(
      wallets.map((item) => item.id == wallet.id ? wallet : item).toList(),
    );
  }

  Future<void> delete(String walletId) async {
    final wallets = await load();
    await save(wallets.where((item) => item.id != walletId).toList());
  }
}
