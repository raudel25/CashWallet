import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'services/language_service.dart';
import 'ui/home_page.dart';

class CashWalletApp extends StatefulWidget {
  const CashWalletApp({super.key});

  @override
  State<CashWalletApp> createState() => _CashWalletAppState();
}

class _CashWalletAppState extends State<CashWalletApp> {
  final LanguageService _languageService = LanguageService();
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final locale = await _languageService.loadLocale();
    if (!mounted) return;
    setState(() {
      _locale = locale;
    });
  }

  Future<void> _handleLanguageChanged(Locale locale) async {
    await _languageService.saveLocale(locale);
    if (!mounted) return;
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Cash Wallet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: HomePage(onLanguageChanged: _handleLanguageChanged),
    );
  }
}
