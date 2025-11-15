import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class LanguageService {
  static const _storageKey = 'cash_wallet_language';

  Future<Locale> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null) {
      return Locale(stored);
    }
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final code = deviceLocale.languageCode;
    if (AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == code,
    )) {
      return Locale(code);
    }
    return const Locale('en');
  }

  Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, locale.languageCode);
  }

  List<Locale> get supportedLocales => AppLocalizations.supportedLocales;
}
