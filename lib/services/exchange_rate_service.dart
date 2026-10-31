import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Units of a currency per 1 USD, e.g. MXN → 18.8.
class RateInfo {
  const RateInfo({required this.rate, required this.manual, this.updatedAt});

  final double rate;

  /// Set by the user. Needed where the official rate differs from the street
  /// rate (e.g. CUP).
  final bool manual;
  final DateTime? updatedAt;
}

/// Exchange rates against USD. Automatic rates come from a free public API
/// (only the base currency is sent) and are cached; manual rates win.
class ExchangeRateService {
  ExchangeRateService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _autoKey = 'cash_wallet_fx_auto';
  static const _manualKey = 'cash_wallet_fx_manual';
  static const _maxAge = Duration(hours: 12);
  static const _url = 'https://open.er-api.com/v6/latest/USD';

  /// Effective rates by currency code. USD is always 1.
  /// With [refresh], fetches new automatic rates when the cache is stale.
  Future<Map<String, RateInfo>> load({bool refresh = true}) async {
    final prefs = await SharedPreferences.getInstance();
    var auto = _decodeAuto(prefs.getString(_autoKey));
    final fetchedAt = auto?.fetchedAt;
    if (refresh &&
        (fetchedAt == null || DateTime.now().difference(fetchedAt) > _maxAge)) {
      auto = await _fetchAuto(prefs) ?? auto;
    }

    final rates = <String, RateInfo>{
      for (final entry in auto?.rates.entries ?? <MapEntry<String, double>>[])
        entry.key: RateInfo(
          rate: entry.value,
          manual: false,
          updatedAt: auto?.fetchedAt,
        ),
    };
    final manual = _decodeManual(prefs.getString(_manualKey));
    for (final entry in manual.entries) {
      rates[entry.key] = RateInfo(rate: entry.value, manual: true);
    }
    rates['USD'] = const RateInfo(rate: 1, manual: false);
    return rates;
  }

  /// Sets a manual rate, or removes it (back to automatic) when null.
  Future<void> setManualRate(String code, double? rate) async {
    final prefs = await SharedPreferences.getInstance();
    final manual = _decodeManual(prefs.getString(_manualKey));
    if (rate == null) {
      manual.remove(code);
    } else {
      manual[code] = rate;
    }
    await prefs.setString(_manualKey, jsonEncode(manual));
  }

  Future<_AutoRates?> _fetchAuto(SharedPreferences prefs) async {
    try {
      final response = await _client
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['result'] != 'success') return null;
      final rates = (body['rates'] as Map<String, dynamic>).map(
        (code, value) => MapEntry(code, (value as num).toDouble()),
      );
      final auto = _AutoRates(DateTime.now(), rates);
      await prefs.setString(
        _autoKey,
        jsonEncode({
          'fetchedAt': auto.fetchedAt.toIso8601String(),
          'rates': rates,
        }),
      );
      return auto;
    } catch (e) {
      debugPrint('ExchangeRateService: fetch failed: $e');
      return null;
    }
  }

  _AutoRates? _decodeAuto(String? raw) {
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return _AutoRates(
      DateTime.parse(data['fetchedAt'] as String),
      (data['rates'] as Map<String, dynamic>).map(
        (code, value) => MapEntry(code, (value as num).toDouble()),
      ),
    );
  }

  Map<String, double> _decodeManual(String? raw) {
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (code, value) => MapEntry(code, (value as num).toDouble()),
    );
  }
}

class _AutoRates {
  const _AutoRates(this.fetchedAt, this.rates);

  final DateTime fetchedAt;
  final Map<String, double> rates;
}
