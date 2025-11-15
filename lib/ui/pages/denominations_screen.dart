import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/currency.dart';
import 'denominations_page.dart';

class DenominationsScreen extends StatefulWidget {
  const DenominationsScreen({
    super.key,
    required this.loadStock,
    required this.currency,
  });

  final Future<Map<double, int>> Function() loadStock;
  final Currency currency;

  @override
  State<DenominationsScreen> createState() => _DenominationsScreenState();
}

class _DenominationsScreenState extends State<DenominationsScreen> {
  final GlobalKey<DenominationsPageState> _pageKey =
      GlobalKey<DenominationsPageState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t(
            'denominations_title',
            params: {'currency': widget.currency.code},
          ),
        ),
      ),
      body: DenominationsPage(
        key: _pageKey,
        loadStock: widget.loadStock,
        currency: widget.currency,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pageKey.currentState?.openAddDialog(),
        icon: const Icon(Icons.add),
        label: Text(context.t('denominations_add')),
      ),
    );
  }
}
