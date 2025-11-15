import 'package:shared_preferences/shared_preferences.dart';

import '../models/denomination.dart';

class DenominationRepository {
  const DenominationRepository();

  static const _storageKey = 'cash_wallet_denominations';

  String _keyFor(String currencyCode) => '${_storageKey}_$currencyCode';

  Future<List<Denomination>> load(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValues = prefs.getStringList(_keyFor(currencyCode)) ?? [];
    final denominations =
        rawValues
            .map(Denomination.fromJson)
            .where((denomination) => denomination.value > 0)
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return denominations;
  }

  Future<void> save(String currencyCode, List<Denomination> values) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = values.map((value) => value.toJson()).toList();
    await prefs.setStringList(_keyFor(currencyCode), payload);
  }
}
