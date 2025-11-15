import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/currency.dart';

class CurrencyService {
  static const _storageKey = 'cash_wallet_currency';

  static final List<Currency> _currencies = [
    const Currency(
      code: 'USD',
      name: 'Dólar estadounidense',
      symbol: '\$',
      countryCodes: ['US', 'PR', 'EC', 'SV', 'PA'],
    ),
    const Currency(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      countryCodes: [
        'ES',
        'FR',
        'DE',
        'IT',
        'PT',
        'IE',
        'NL',
        'BE',
        'FI',
        'AT',
      ],
    ),
    const Currency(
      code: 'MXN',
      name: 'Peso mexicano',
      symbol: '\$',
      countryCodes: ['MX'],
    ),
    const Currency(
      code: 'COP',
      name: 'Peso colombiano',
      symbol: '\$',
      countryCodes: ['CO'],
    ),
    const Currency(
      code: 'ARS',
      name: 'Peso argentino',
      symbol: '\$',
      countryCodes: ['AR'],
    ),
    const Currency(
      code: 'CLP',
      name: 'Peso chileno',
      symbol: '\$',
      countryCodes: ['CL'],
    ),
    const Currency(
      code: 'PEN',
      name: 'Sol peruano',
      symbol: 'S/',
      countryCodes: ['PE'],
    ),
    const Currency(
      code: 'VES',
      name: 'Bolívar venezolano',
      symbol: 'Bs.',
      countryCodes: ['VE'],
    ),
    const Currency(
      code: 'CUP',
      name: 'Peso cubano',
      symbol: '\$',
      countryCodes: ['CU'],
    ),
    const Currency(
      code: 'DOP',
      name: 'Peso dominicano',
      symbol: 'RD\$',
      countryCodes: ['DO'],
    ),
  ];

  Currency get defaultCurrency => _currencies.first;

  List<Currency> get availableCurrencies => List.unmodifiable(_currencies);

  Future<Currency> loadSelectedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null) {
      final currency = _currencies.firstWhere(
        (currency) => currency.code == stored,
        orElse: () => defaultCurrency,
      );
      return currency;
    }

    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return _detectFromLocale(locale);
  }

  Future<void> saveSelectedCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, code);
  }

  Currency _detectFromLocale(Locale locale) {
    final countryCode = locale.countryCode?.toUpperCase();
    if (countryCode != null) {
      for (final currency in _currencies) {
        if (currency.countryCodes.contains(countryCode)) {
          return currency;
        }
      }
    }
    return defaultCurrency;
  }
}
