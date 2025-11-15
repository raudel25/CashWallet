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
    expect(find.textContaining('Saldo total'), findsOneWidget);
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
      find.text('Selecciona un apartado para personalizar tu experiencia.'),
      findsOneWidget,
    );
    expect(find.text('Denominaciones'), findsOneWidget);
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

    final denominationsTile = find.text('Denominaciones');
    expect(denominationsTile, findsOneWidget);

    await tester.tap(denominationsTile);
    await tester.pumpAndSettle();

    expect(find.textContaining('Denominaciones'), findsWidgets);

    final addButton = find.text('Añadir');
    expect(addButton, findsOneWidget);

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Nueva denominación'), findsOneWidget);
  });
}
