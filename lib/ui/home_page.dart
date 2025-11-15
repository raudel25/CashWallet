import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/dashboard_controller.dart';
import '../data/cash_entry_repository.dart';
import '../data/denomination_repository.dart';
import '../models/cash_entry.dart';
import '../models/currency.dart';
import '../models/denomination.dart';
import '../models/denomination_count.dart';
import '../services/currency_service.dart';
import 'pages/dashboard_page.dart';
import 'pages/denominations_screen.dart';
import 'pages/history_page.dart';
import 'pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _dashboardKey = GlobalKey<DashboardPageState>();
  final _historyKey = GlobalKey<HistoryPageState>();
  late final DashboardController _dashboardController;

  final _incomeRepository = const CashEntryRepository('cash_wallet_incomes');
  final _expenseRepository = const CashEntryRepository('cash_wallet_expenses');
  final _denominationRepository = const DenominationRepository();
  final CurrencyService _currencyService = CurrencyService();

  Currency? _currentCurrency;
  bool _isInitializing = true;

  late final List<_Destination> _destinations;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _destinations = const [
      _Destination(
        label: 'Inicio',
        title: 'Inicio',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _Destination(
        label: 'Historial',
        title: 'Historial',
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
      ),
      _Destination(
        label: 'Configuración',
        title: 'Configuración',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];

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
        label: const Text('Registrar movimiento'),
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
        currency: currency,
      ),
      SettingsPage(
        currency: currency,
        onSelectCurrency: _openCurrencySelector,
        onOpenDenominations: _openDenominationsScreen,
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
                title: const Text('Nuevo ingreso'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openIncomeForm();
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_down, color: Colors.red),
                title: const Text('Nuevo gasto'),
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
                  'Selecciona la moneda a usar',
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
        const SnackBar(
          content: Text('Primero configura tus denominaciones en ajustes.'),
        ),
      );
      return;
    }

    final result = await _showIncomeFormSheet(denominations, currency.symbol);
    if (result == null) return;

    final entry = CashEntry.createIncome(
      breakdown: result.breakdown,
      description: result.description,
      currencyCode: currency.code,
    );
    if (entry.amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El ingreso debe ser mayor que cero.')),
      );
      return;
    }

    final currentEntries = await _incomeRepository.load(currency.code);
    await _incomeRepository.save(currency.code, [entry, ...currentEntries]);
    await _historyKey.currentState?.refresh(currency.code);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ingreso registrado correctamente.')),
    );
  }

  Future<void> _openExpenseForm() async {
    final currency = _currentCurrency;
    if (currency == null) return;
    final denominations = await _denominationRepository.load(currency.code);
    if (denominations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero configura tus denominaciones en ajustes.'),
        ),
      );
      return;
    }

    final stock = await _loadDenominationStock();
    final totalPieces = stock.values.fold<int>(0, (sum, qty) => sum + qty);
    if (totalPieces <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No tienes efectivo disponible para registrar un gasto.',
          ),
        ),
      );
      return;
    }
    final result = await _showExpenseFormSheet(
      denominations,
      stock,
      currency.symbol,
    );
    if (result == null) return;

    final entry = CashEntry.createExpense(
      breakdown: result.breakdown,
      description: result.description,
      currencyCode: currency.code,
    );
    if (entry.amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El gasto debe ser mayor que cero.')),
      );
      return;
    }

    final currentEntries = await _expenseRepository.load(currency.code);
    await _expenseRepository.save(currency.code, [entry, ...currentEntries]);
    await _historyKey.currentState?.refresh(currency.code);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gasto registrado correctamente.')),
    );
  }

  Future<_IncomeFormResult?> _showIncomeFormSheet(
    List<Denomination> denominations,
    String currencySymbol,
  ) {
    return showModalBottomSheet<_IncomeFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _IncomeFormSheet(
        denominations: denominations,
        currencySymbol: currencySymbol,
      ),
    );
  }

  Future<_ExpenseFormResult?> _showExpenseFormSheet(
    List<Denomination> denominations,
    Map<double, int> availableStock,
    String currencySymbol,
  ) {
    return showModalBottomSheet<_ExpenseFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExpenseFormSheet(
        denominations: denominations,
        availableStock: availableStock,
        currencySymbol: currencySymbol,
      ),
    );
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

class _IncomeFormResult {
  const _IncomeFormResult({required this.description, required this.breakdown});

  final String description;
  final List<DenominationCount> breakdown;
}

class _ExpenseFormResult {
  const _ExpenseFormResult({
    required this.description,
    required this.breakdown,
  });

  final String description;
  final List<DenominationCount> breakdown;
}

class _IncomeFormSheet extends StatefulWidget {
  const _IncomeFormSheet({
    required this.denominations,
    required this.currencySymbol,
  });

  final List<Denomination> denominations;
  final String currencySymbol;

  @override
  State<_IncomeFormSheet> createState() => _IncomeFormSheetState();
}

class _IncomeFormSheetState extends State<_IncomeFormSheet> {
  late final Map<double, TextEditingController> _quantityControllers;
  late final TextEditingController _descriptionController;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _quantityControllers = {
      for (final denomination in widget.denominations)
        denomination.value: TextEditingController(text: '0'),
    };
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    final total = widget.denominations.fold<double>(0, (sum, denomination) {
      final controller = _quantityControllers[denomination.value]!;
      final quantity = int.tryParse(controller.text) ?? 0;
      return sum + denomination.value * quantity;
    });
    setState(() => _total = total);
  }

  List<DenominationCount> _buildBreakdown() {
    return widget.denominations
        .map(
          (denomination) => DenominationCount(
            denomination: denomination.value,
            quantity:
                int.tryParse(_quantityControllers[denomination.value]!.text) ??
                0,
          ),
        )
        .where((item) => item.quantity > 0)
        .toList();
  }

  void _submit() {
    if (_total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos una unidad para guardar el ingreso.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _IncomeFormResult(
        description: _descriptionController.text.trim(),
        breakdown: _buildBreakdown(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nuevo ingreso', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Indica cuántas unidades de cada denominación vas a guardar.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: ListView.separated(
              itemBuilder: (context, index) {
                final denomination = widget.denominations[index];
                final controller = _quantityControllers[denomination.value]!;
                return TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText:
                        '${widget.currencySymbol} ${denomination.value.toStringAsFixed(2)}',
                    suffixText: 'unidades',
                  ),
                  onChanged: (_) => _updateTotal(),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: widget.denominations.length,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Ej. Ahorros, venta, etc.',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total calculado:'),
              Text(
                '${widget.currencySymbol} ${_total.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save),
              label: const Text('Guardar ingreso'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({
    required this.denominations,
    required this.availableStock,
    required this.currencySymbol,
  });

  final List<Denomination> denominations;
  final Map<double, int> availableStock;
  final String currencySymbol;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  late final Map<double, TextEditingController> _quantityControllers;
  late final TextEditingController _descriptionController;
  double _total = 0;
  Map<double, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _quantityControllers = {
      for (final denomination in widget.denominations)
        denomination.value: TextEditingController(text: '0'),
    };
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    final total = widget.denominations.fold<double>(0, (sum, denomination) {
      final controller = _quantityControllers[denomination.value]!;
      final quantity = int.tryParse(controller.text) ?? 0;
      return sum + denomination.value * quantity;
    });
    setState(() => _total = total);
  }

  List<DenominationCount> _buildBreakdown() {
    return widget.denominations
        .map(
          (denomination) => DenominationCount(
            denomination: denomination.value,
            quantity:
                int.tryParse(_quantityControllers[denomination.value]!.text) ??
                0,
          ),
        )
        .where((item) => item.quantity > 0)
        .toList();
  }

  void _submit() {
    if (_total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica qué denominaciones estás gastando.'),
        ),
      );
      return;
    }

    final breakdown = _buildBreakdown();
    final Map<double, String> newErrors = {};
    for (final item in breakdown) {
      final available = widget.availableStock[item.denomination] ?? 0;
      if (item.quantity > available) {
        newErrors[item.denomination] =
            'Solo tienes $available unidades de ${widget.currencySymbol} ${item.denomination.toStringAsFixed(2)}.';
      }
    }
    if (newErrors.isNotEmpty) {
      setState(() => _errors = newErrors);
      return;
    }
    if (_errors.isNotEmpty) {
      setState(() => _errors = {});
    }

    Navigator.of(context).pop(
      _ExpenseFormResult(
        description: _descriptionController.text.trim(),
        breakdown: breakdown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nuevo gasto', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Indica cuántas unidades de cada denominación vas a usar.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: ListView.separated(
              itemBuilder: (context, index) {
                final denomination = widget.denominations[index];
                final controller = _quantityControllers[denomination.value]!;
                final error = _errors[denomination.value];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText:
                            '${widget.currencySymbol} ${denomination.value.toStringAsFixed(2)}',
                        suffixText: 'unidades',
                      ),
                      onChanged: (_) {
                        _updateTotal();
                        if (_errors.containsKey(denomination.value)) {
                          setState(() {
                            _errors.remove(denomination.value);
                          });
                        }
                      },
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          error,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                  ],
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: widget.denominations.length,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Ej. Compra, pago de servicio, etc.',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total calculado:'),
              Text(
                '${widget.currencySymbol} ${_total.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save),
              label: const Text('Guardar gasto'),
            ),
          ),
        ],
      ),
    );
  }
}
