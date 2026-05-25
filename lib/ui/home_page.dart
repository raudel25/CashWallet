import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../data/cash_entry_repository.dart';
import '../data/denomination_repository.dart';
import '../services/security_service.dart';
import '../l10n/app_localizations.dart';
import '../models/cash_entry.dart';
import '../models/currency.dart';
import '../services/language_service.dart';
import '../services/currency_service.dart';
import 'pages/dashboard_page.dart';
import 'pages/denominations_screen.dart';
import 'pages/history_page.dart';
import 'pages/settings_page.dart';
import 'pages/security_screen.dart';
import 'widgets/movement_form_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  final Future<void> Function(Locale) onLanguageChanged;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _dashboardKey = GlobalKey<DashboardPageState>();
  final _historyKey = GlobalKey<HistoryPageState>();
  late final DashboardController _dashboardController;

  final _incomeRepository = CashEntryRepository('cash_wallet_incomes');
  final _expenseRepository = CashEntryRepository('cash_wallet_expenses');
  final _denominationRepository = const DenominationRepository();
  final CurrencyService _currencyService = CurrencyService();
  final LanguageService _languageService = LanguageService();
  final SecurityService _securityService = SecurityService();

  Currency? _currentCurrency;
  bool _isInitializing = true;

  late List<_Destination> _destinations;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final currency = await _currencyService.loadSelectedCurrency();
    _dashboardController = DashboardController(
      incomeRepository: _incomeRepository,
      expenseRepository: _expenseRepository,
      currencyCode: currency.code,
      onSummaryUpdated: (summary) {
        _dashboardKey.currentState?.updateSummary(summary);
      },
    );

    await _dashboardController.init();
    if (!mounted) return;
    setState(() {
      _currentCurrency = currency;
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _currentCurrency == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = _buildPages();
    _destinations = _buildDestinations(context);
    final destination = _destinations[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text(destination.title)),
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget? _buildFab() {
    if (_currentIndex == 0) {
      return FloatingActionButton.extended(
        onPressed: _openQuickAddSheet,
        icon: const Icon(Icons.add),
        label: Text(context.t('home_register_movement')),
      );
    }

    return null;
  }

  List<Widget> _buildPages() {
    final currency = _currentCurrency!;
    return [
      DashboardPage(
        key: _dashboardKey,
        controller: _dashboardController,
        currency: currency,
      ),
      HistoryPage(
        key: _historyKey,
        incomeRepository: _incomeRepository,
        expenseRepository: _expenseRepository,
        denominationRepository: _denominationRepository,
        currency: currency,
        loadStock: _loadDenominationStock,
        onChanged: () => _dashboardController.refresh(),
      ),
      SettingsPage(
        currency: currency,
        onSelectCurrency: _openCurrencySelector,
        onSelectLanguage: _openLanguageSelector,
        onOpenDenominations: _openDenominationsScreen,
        onOpenSecurity: _openSecurityScreen,
        currentLanguageLabel: context.loc.languageName(
          Localizations.localeOf(context).languageCode,
        ),
        onSelectTheme: widget.onThemeChanged,
        currentThemeMode: widget.currentThemeMode,
        onDataChanged: _refreshAllAfterImport,
      ),
    ];
  }

  Future<void> _refreshAllAfterImport() async {
    final currency = await _currencyService.loadSelectedCurrency();
    await _dashboardController.setCurrency(currency.code);
    await _dashboardController.refresh();
    if (!mounted) return;
    setState(() => _currentCurrency = currency);
    await _historyKey.currentState?.refresh(currency.code);
  }

  List<_Destination> _buildDestinations(BuildContext context) {
    final loc = context.loc;
    return [
      _Destination(
        label: loc.translate('tab_home'),
        title: loc.translate('tab_home'),
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _Destination(
        label: loc.translate('tab_history'),
        title: loc.translate('tab_history'),
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
      ),
      _Destination(
        label: loc.translate('tab_settings'),
        title: loc.translate('tab_settings'),
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];
  }

  Future<void> _openQuickAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.green),
                title: Text(context.t('home_new_income')),
                onTap: () {
                  Navigator.of(context).pop();
                  _openIncomeForm();
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_down, color: Colors.red),
                title: Text(context.t('home_new_expense')),
                onTap: () {
                  Navigator.of(context).pop();
                  _openExpenseForm();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLanguageSelector() async {
    final currentLocale = Localizations.localeOf(context);
    final supported = _languageService.supportedLocales;
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.t('home_select_language'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...supported.map(
                (locale) => RadioListTile<String>(
                  value: locale.languageCode,
                  groupValue: currentLocale.languageCode,
                  title: Text(context.loc.languageName(locale.languageCode)),
                  onChanged: (_) => Navigator.of(context).pop(locale),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null ||
        selected.languageCode == currentLocale.languageCode) {
      return;
    }
    await widget.onLanguageChanged(selected);
  }

  Future<void> _openCurrencySelector() async {
    final currency = _currentCurrency;
    if (currency == null) return;
    final currencies = _currencyService.availableCurrencies;
    final selected = await showModalBottomSheet<Currency>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.t('home_select_currency'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...currencies.map(
                (item) => RadioListTile<String>(
                  value: item.code,
                  groupValue: currency.code,
                  title: Text(item.name),
                  subtitle: Text('${item.symbol} • ${item.code}'),
                  onChanged: (_) => Navigator.of(context).pop(item),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected.code == currency.code) return;
    await _currencyService.saveSelectedCurrency(selected.code);
    await _dashboardController.setCurrency(selected.code);
    setState(() {
      _currentCurrency = selected;
    });
    await _historyKey.currentState?.refresh(selected.code);
  }

  Future<void> _openIncomeForm() async {
    final currency = _currentCurrency;
    if (currency == null) return;
    final denominations = await _denominationRepository.load(currency.code);
    if (denominations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('home_configure_denominations'))),
      );
      return;
    }

    final result = await showModalBottomSheet<MovementFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MovementFormSheet(
        type: CashEntryType.income,
        denominations: denominations,
        currencySymbol: currency.symbol,
      ),
    );
    if (result == null) return;

    final entry = CashEntry.createIncome(
      breakdown: result.breakdown,
      description: result.description,
      currencyCode: currency.code,
    ).copyWith(createdAt: result.createdAt);

    if (entry.amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('home_income_positive'))),
      );
      return;
    }

    await _incomeRepository.add(currency.code, entry);
    await _historyKey.currentState?.refresh(currency.code);
    await _dashboardController.refresh();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('home_income_saved'))));
  }

  Future<void> _openExpenseForm() async {
    final currency = _currentCurrency;
    if (currency == null) return;
    final denominations = await _denominationRepository.load(currency.code);
    if (denominations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('home_configure_denominations'))),
      );
      return;
    }

    final stock = await _loadDenominationStock();
    final totalPieces = stock.values.fold<int>(0, (sum, qty) => sum + qty);
    if (totalPieces <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('home_no_cash_for_expense'))),
      );
      return;
    }
    final result = await showModalBottomSheet<MovementFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MovementFormSheet(
        type: CashEntryType.expense,
        denominations: denominations,
        currencySymbol: currency.symbol,
        availableStock: stock,
      ),
    );
    if (result == null) return;

    final entry = CashEntry.createExpense(
      breakdown: result.breakdown,
      description: result.description,
      currencyCode: currency.code,
    ).copyWith(createdAt: result.createdAt);

    if (entry.amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('home_expense_positive'))),
      );
      return;
    }

    await _expenseRepository.add(currency.code, entry);
    await _historyKey.currentState?.refresh(currency.code);
    await _dashboardController.refresh();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('home_expense_saved'))));
  }

  Future<void> _openDenominationsScreen() async {
    final currency = _currentCurrency;
    if (currency == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DenominationsScreen(
          loadStock: _loadDenominationStock,
          currency: currency,
        ),
      ),
    );
  }

  Future<void> _openSecurityScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SecurityScreen(securityService: _securityService),
      ),
    );
  }

  Future<Map<double, int>> _loadDenominationStock() async {
    final currency = _currentCurrency;
    if (currency == null) return {};
    final incomes = await _incomeRepository.load(currency.code);
    final expenses = await _expenseRepository.load(currency.code);
    final Map<double, int> stock = {};

    void accumulate(List<CashEntry> entries, int multiplier) {
      for (final entry in entries) {
        for (final breakdown in entry.breakdown) {
          stock[breakdown.denomination] =
              (stock[breakdown.denomination] ?? 0) +
              breakdown.quantity * multiplier;
          if ((stock[breakdown.denomination] ?? 0) <= 0) {
            stock.remove(breakdown.denomination);
          }
        }
      }
    }

    accumulate(incomes, 1);
    accumulate(expenses, -1);
    return stock;
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.title,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
}
