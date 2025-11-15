import 'package:shared_preferences/shared_preferences.dart';

import '../models/denomination.dart';

class DenominationRepository {
  const DenominationRepository();

  static const _storageKey = 'cash_wallet_denominations';

  Future<List<Denomination>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValues = prefs.getStringList(_storageKey) ?? [];
    final denominations =
        rawValues
            .map(Denomination.fromJson)
            .where((denomination) => denomination.value > 0)
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return denominations;
  }

  Future<void> save(List<Denomination> values) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = values.map((value) => value.toJson()).toList();
    await prefs.setStringList(_storageKey, payload);
  }
}
