// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:cash_wallet/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Muestra la pantalla de inicio por defecto', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Bienvenido a tu Cash Wallet'), findsOneWidget);
    expect(find.text('Registrar movimiento'), findsOneWidget);
  });

  testWidgets('Permite navegar al historial y la configuración', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Historial'), findsWidgets);
    expect(find.text('Consulta cada movimiento registrado.'), findsOneWidget);

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    expect(find.text('Configuración'), findsWidgets);
    expect(
      find.text(
        'Agrega cada una de las denominaciones de efectivo que tienes guardadas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('El botón flotante abre las opciones de registro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar movimiento'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo ingreso'), findsOneWidget);
    expect(find.text('Nuevo gasto'), findsOneWidget);
  });

  testWidgets('En configuración se puede abrir el diálogo de denominaciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();

    final addButton = find.text('Añadir denominación');
    expect(addButton, findsOneWidget);

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Nueva denominación'), findsOneWidget);
  });
}
