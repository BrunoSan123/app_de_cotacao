import 'dart:convert';

import 'package:cotation_app/main.dart';
import 'package:cotation_app/models/trade_order.dart';
import 'package:cotation_app/screens/home_screen.dart';
import 'package:cotation_app/services/brapi_service.dart';
import 'package:cotation_app/services/local_json_store.dart';
import 'package:cotation_app/state/trade_sim_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('amount parser accepts Brazilian and decimal-point formats', () {
    expect(parseAmount('37.42'), 37.42);
    expect(parseAmount('37,42'), 37.42);
    expect(parseAmount('1.234,56'), 1234.56);
  });

  testWidgets('new user can register and open the market screen', (
    tester,
  ) async {
    final controller = _controller();
    await controller.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const TradeSimApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    await tester.tap(find.text('Ainda não tenho conta — cadastrar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('fullNameField')),
      'Ana Teste',
    );
    await tester.enterText(
      find.byKey(const ValueKey('emailField')),
      'ana@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('passwordField')),
      'senha123',
    );
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Olá, Ana'), findsOneWidget);
    expect(find.text('R\$ 50.000,00'), findsWidgets);

    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsWidgets);
    expect(find.text('PETR4'), findsOneWidget);

    await tester.tap(find.text('PETR4'));
    await tester.pumpAndSettle();
    expect(find.text('Histórico de preços'), findsOneWidget);
    expect(find.text('Variações por pregão'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Operar PETR4'), findsOneWidget);
    await tester.ensureVisible(find.text('Operar PETR4'));
    await tester.tap(find.text('Operar PETR4'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar compra simulada'));
    await tester.tap(find.text('Confirmar compra simulada'));
    await tester.pumpAndSettle();
    expect(controller.holdings['PETR4'], 10);

    await tester.tap(find.text('Carteira').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular depósito'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '100,00');
    await tester.tap(find.text('Depositar'));
    await tester.pumpAndSettle();
    expect(controller.cashBalance, closeTo(49725.8, 0.001));
  });

  test(
    'swing and day trades update balance, custody, and realized P&L',
    () async {
      final controller = _controller();
      await controller.initialize();
      await controller.register(
        fullName: 'Ana Teste',
        email: 'ana@example.com',
        password: 'senha123',
      );

      await controller.placeSwingOrder(
        symbol: 'PETR4',
        side: OrderSide.buy,
        quantity: 10,
        price: 37.42,
      );
      expect(controller.cashBalance, closeTo(49625.8, 0.001));
      expect(controller.holdings['PETR4'], 10);

      await controller.openDayTrade(symbol: 'PETR4', quantity: 5, price: 37.42);
      final openOrder = controller.openDayTrades.single;
      await controller.closeDayTrade(openOrder, 38.42);

      expect(controller.openDayTrades, isEmpty);
      expect(controller.orders.first.realizedPnl, closeTo(5, 0.001));
      expect(controller.cashBalance, closeTo(49630.8, 0.001));
      expect(controller.holdings['PETR4'], 10);
    },
  );

  test('market uses no local quote data when Brapi returns an error', () async {
    final controller = TradeSimController(
      store: LocalJsonStore(),
      brapiService: BrapiService(
        client: MockClient((_) async => http.Response('{}', 401)),
      ),
    );
    await controller.initialize();

    expect(controller.quotes, isEmpty);
    expect(controller.quoteFor('PETR4'), isNull);
    expect(controller.quoteError, contains('Brapi'));

    await controller.register(
      fullName: 'Ana Teste',
      email: 'ana@example.com',
      password: 'senha123',
    );
    await expectLater(
      controller.placeSwingOrder(
        symbol: 'PETR4',
        side: OrderSide.buy,
        quantity: 1,
        price: 37.42,
      ),
      throwsA(isA<TradeSimException>()),
    );

    expect(controller.holdings, isEmpty);
  });
}

TradeSimController _controller() {
  final client = MockClient((request) async {
    if (request.url.path == '/api/quote/PETR4') {
      return http.Response(
        jsonEncode({
          'results': [
            {
              'symbol': 'PETR4',
              'historicalDataPrice': [
                {
                  'date': 1791860400,
                  'close': 37.00,
                  'adjustedClose': 37.00,
                  'open': 36.50,
                  'high': 37.50,
                  'low': 36.20,
                  'volume': 123456,
                },
                {
                  'date': 1791946800,
                  'close': 37.42,
                  'adjustedClose': 37.42,
                  'open': 37.00,
                  'high': 37.90,
                  'low': 36.88,
                  'volume': 234567,
                },
              ],
            },
          ],
        }),
        200,
      );
    }
    return http.Response(
      jsonEncode({
        'stocks': [
          {
            'stock': 'PETR4',
            'name': 'PETROLEO BRASILEIRO S.A.',
            'close': 37.42,
            'change': 1.28,
            'volume': 28430000,
          },
        ],
        'currentPage': 1,
        'totalPages': 1,
        'hasNextPage': false,
      }),
      200,
    );
  });
  return TradeSimController(
    store: LocalJsonStore(),
    brapiService: BrapiService(client: client),
  );
}
