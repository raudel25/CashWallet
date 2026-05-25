import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'services/language_service.dart';
import 'services/security_service.dart';
import 'services/theme_service.dart';
import 'ui/home_page.dart';
import 'ui/pages/auth_page.dart';

class CashWalletApp extends StatefulWidget {
  const CashWalletApp({super.key});

  @override
  State<CashWalletApp> createState() => _CashWalletAppState();
}

class _CashWalletAppState extends State<CashWalletApp>
    with WidgetsBindingObserver {
  final LanguageService _languageService = LanguageService();
  final ThemeService _themeService = ThemeService();
  final SecurityService _securityService = SecurityService();
  Locale? _locale;
  ThemeMode? _themeMode;
  bool _requireAuth = false;
  bool _authenticated = false;
  DateTime? _lastPausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocale();
    _loadTheme();
    _loadSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_requireAuth) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _lastPausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _maybeLockOnResume();
    }
  }

  Future<void> _maybeLockOnResume() async {
    if (!_authenticated) return;
    final pausedAt = _lastPausedAt;
    if (pausedAt == null) return;
    final autoLockMinutes = await _securityService.getAutoLockMinutes();
    if (autoLockMinutes >= 9999) return; // never
    final elapsed = DateTime.now().difference(pausedAt);
    if (elapsed >= Duration(minutes: autoLockMinutes)) {
      if (!mounted) return;
      setState(() => _authenticated = false);
    }
  }

  Future<void> _loadSecurity() async {
    final required = await _securityService.anySecurityEnabled();
    if (!mounted) return;
    setState(() => _requireAuth = required);
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
    final lightScheme = ColorScheme.fromSeed(seedColor: Colors.green);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.dark,
    );
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
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: lightScheme.surface,
        cardTheme: CardThemeData(
          elevation: 0,
          color: lightScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          surfaceTintColor: lightScheme.surface,
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          color: darkScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          surfaceTintColor: darkScheme.surface,
          centerTitle: false,
        ),
      ),
      themeMode: _themeMode ?? ThemeMode.system,
      home: (_requireAuth && !_authenticated)
          ? AuthPage(
              securityService: _securityService,
              onAuthenticated: () {
                setState(() {
                  _authenticated = true;
                  _lastPausedAt = null;
                });
              },
            )
          : HomePage(
              onLanguageChanged: _handleLanguageChanged,
              onThemeChanged: _handleThemeChanged,
              currentThemeMode: _themeMode ?? ThemeMode.system,
            ),
    );
  }
}
