// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:cash_wallet/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Muestra el resumen por defecto y el efectivo en su pestaña', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    final hasSummary =
        find.textContaining('Patrimonio total').evaluate().isNotEmpty ||
        find.textContaining('Net worth').evaluate().isNotEmpty;
    expect(hasSummary, isTrue);

    await tester.tap(find.byIcon(Icons.payments_outlined).last);
    await tester.pumpAndSettle();
    final hasBalance =
        find.textContaining('Saldo total').evaluate().isNotEmpty ||
        find.textContaining('Total balance').evaluate().isNotEmpty;
    expect(hasBalance, isTrue);
    final hasFab =
        find.text('Registrar movimiento').evaluate().isNotEmpty ||
        find.text('Register movement').evaluate().isNotEmpty;
    expect(hasFab, isTrue);
  });

  testWidgets('Permite navegar al historial y la configuración', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Historial').evaluate().isNotEmpty ||
          find.textContaining('History').evaluate().isNotEmpty,
      isTrue,
    );
    // History page should show the income/expense filter labels.
    expect(
      find.textContaining('Ingresos').evaluate().isNotEmpty ||
          find.textContaining('Incomes').evaluate().isNotEmpty,
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Configuración').evaluate().isNotEmpty ||
          find.textContaining('Settings').evaluate().isNotEmpty,
      isTrue,
    );
    expect(
      find.textContaining('personalizar').evaluate().isNotEmpty ||
          find.textContaining('customize').evaluate().isNotEmpty,
      isTrue,
    );
    expect(
      find.textContaining('Denominaciones').evaluate().isNotEmpty ||
          find.textContaining('Denominations').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('El botón flotante abre las opciones de registro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.payments_outlined).last);
    await tester.pumpAndSettle();

    final fabEs = find.textContaining('Registrar movimiento');
    final fabEn = find.textContaining('Register movement');
    final fab = fabEs.evaluate().isNotEmpty ? fabEs : fabEn;
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(
      find.text('Nuevo ingreso').evaluate().isNotEmpty ||
          find.text('New income').evaluate().isNotEmpty,
      isTrue,
    );
    expect(
      find.text('Nuevo gasto').evaluate().isNotEmpty ||
          find.text('New expense').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('En configuración se puede abrir el diálogo de denominaciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final denominationsTile =
        find.textContaining('Denominaciones').evaluate().isNotEmpty
        ? find.textContaining('Denominaciones')
        : find.textContaining('Denominations');
    expect(denominationsTile.evaluate().isNotEmpty, isTrue);

    await tester.tap(denominationsTile);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Denominaciones').evaluate().isNotEmpty ||
          find.textContaining('Denominations').evaluate().isNotEmpty,
      isTrue,
    );

    final addButton = find.text('Añadir').evaluate().isNotEmpty
        ? find.text('Añadir')
        : find.text('Add');
    expect(addButton.evaluate().isNotEmpty, isTrue);

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Nueva denominación').evaluate().isNotEmpty ||
          find.text('New denomination').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
