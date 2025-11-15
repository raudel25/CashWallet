import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'services/language_service.dart';
import 'services/theme_service.dart';
import 'ui/home_page.dart';

class CashWalletApp extends StatefulWidget {
  const CashWalletApp({super.key});

  @override
  State<CashWalletApp> createState() => _CashWalletAppState();
}

class _CashWalletAppState extends State<CashWalletApp> {
  final LanguageService _languageService = LanguageService();
  final ThemeService _themeService = ThemeService();
  Locale? _locale;
  ThemeMode? _themeMode;

  @override
  void initState() {
    super.initState();
    _loadLocale();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _themeService.loadThemeMode();
    if (!mounted) return;
    setState(() => _themeMode = mode);
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

  Future<void> _handleThemeChanged(ThemeMode mode) async {
    await _themeService.saveThemeMode(mode);
    if (!mounted) return;
    setState(() {
      _themeMode = mode;
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
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      // Use saved theme mode (or system initially)
      themeMode: _themeMode ?? ThemeMode.system,
      home: HomePage(
        onLanguageChanged: _handleLanguageChanged,
        onThemeChanged: _handleThemeChanged,
        currentThemeMode: _themeMode ?? ThemeMode.system,
      ),
    );
  }
}
