import 'dart:convert';

import 'package:cotation_app/models/trade_order.dart';
import 'package:cotation_app/models/user.dart';
import 'package:cotation_app/models/wallet.dart';
import 'package:cotation_app/models/wallet_transaction.dart';
import 'package:cotation_app/services/brapi_service.dart';
import 'package:cotation_app/services/local_json_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Wallet models round-trip through JSON', () {
    final openedAt = DateTime.utc(2026, 11, 9);
    final wallet = Wallet(
      availableBalance: 42000,
      orders: [
        TradeOrder(
          id: 'order-1',
          symbol: 'PETR4',
          type: TradeType.day,
          side: OrderSide.buy,
          status: OrderStatus.open,
          quantity: 10,
          price: 35.5,
          openedAt: openedAt,
        ),
      ],
      transactions: [
        WalletTransaction(
          id: 'transaction-1',
          type: WalletTransactionType.deposit,
          amount: 2000,
          createdAt: openedAt,
        ),
      ],
    );

    expect(Wallet.fromJson(wallet.toJson()).toJson(), wallet.toJson());
    expect(const Wallet().availableBalance, 50000);
  });

  test('LocalJsonStore persists users and the active session', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalJsonStore();
    final user = User(
      id: 'user-1',
      email: 'trader@example.com',
      fullName: 'Test Trader',
      passwordHash: 'one-way-hash',
      createdAt: DateTime.utc(2026, 11, 9),
      wallet: const Wallet(),
    );

    await store.saveUser(user);
    await store.setCurrentUser(user.id);

    final foundUser = await store.findUserByEmail(' TRADER@example.com ');
    expect(foundUser?.id, user.id);
    expect(foundUser?.wallet.availableBalance, 50000);

    final currentUser = await store.getCurrentUser();
    expect(currentUser?.email, user.email);

    await store.clearSession();
    expect(await store.getCurrentUser(), isNull);
  });

  test('BrapiService maps quote fields and includes the token', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/quote/PETR4,VALE3');
      expect(request.url.queryParameters['token'], 'test-token');
      return http.Response(
        jsonEncode({
          'results': [
            {
              'symbol': 'PETR4',
              'regularMarketPrice': 35.5,
              'regularMarketChangePercent': 1.25,
              'regularMarketDayHigh': 36.0,
              'regularMarketDayLow': 34.8,
              'regularMarketVolume': 123456,
            },
          ],
        }),
        200,
      );
    });
    final service = BrapiService(client: client, token: 'test-token');

    final quotes = await service.fetchQuotes(['petr4', 'VALE3']);

    expect(quotes, hasLength(1));
    expect(quotes.single.symbol, 'PETR4');
    expect(quotes.single.price, 35.5);
    expect(quotes.single.changePercent, 1.25);
    expect(quotes.single.dayHigh, 36.0);
    expect(quotes.single.dayLow, 34.8);
    expect(quotes.single.volume, 123456);
    client.close();
  });

  test('BrapiService explains when Brapi rejects a missing token', () async {
    final service = BrapiService(
      client: MockClient((_) async => http.Response('{}', 401)),
    );

    await expectLater(
      service.fetchQuotes(['PETR4']),
      throwsA(
        isA<BrapiApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', contains('token')),
      ),
    );
  });

  test('BrapiService loads real stock listings from the Brapi list endpoint', () async {
    final service = BrapiService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/quote/list');
        expect(request.url.queryParameters['type'], 'stock');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['limit'], '30');
        expect(request.url.queryParameters['search'], 'PETR');
        return http.Response(
          jsonEncode({
            'stocks': [
              {
                'stock': 'PETR4',
                'name': 'PETROLEO BRASILEIRO S.A.',
                'close': 45.3,
                'change': -1.41,
                'volume': 47084100,
              },
            ],
            'currentPage': 2,
            'totalPages': 5,
            'hasNextPage': true,
          }),
          200,
        );
      }),
    );

    final page = await service.fetchStockList(
      search: 'PETR',
      page: 2,
      limit: 30,
    );

    expect(page.stocks, hasLength(1));
    expect(page.stocks.single.symbol, 'PETR4');
    expect(page.stocks.single.name, 'PETROLEO BRASILEIRO S.A.');
    expect(page.stocks.single.price, 45.3);
    expect(page.stocks.single.changePercent, -1.41);
    expect(page.stocks.single.volume, 47084100);
    expect(page.stocks.single.dayHigh, isNull);
    expect(page.hasNextPage, isTrue);
  });

  test('BrapiService loads and sorts historical prices for a stock', () async {
    final service = BrapiService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/quote/PETR4');
        expect(request.url.queryParameters['range'], '1mo');
        expect(request.url.queryParameters['interval'], '1d');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'symbol': 'PETR4',
                'historicalDataPrice': [
                  {
                    'date': 1791946800,
                    'close': 58.11,
                    'adjustedClose': 58.10,
                    'open': 56.88,
                    'high': 58.11,
                    'low': 56.74,
                    'volume': 42367600,
                  },
                  {
                    'date': 1791860400,
                    'close': 56.85,
                    'adjustedClose': 56.84,
                    'open': 55.65,
                    'high': 56.88,
                    'low': 55.58,
                    'volume': 38257100,
                  },
                ],
              },
            ],
          }),
          200,
        );
      }),
    );

    final history = await service.fetchPriceHistory('petr4');

    expect(history, hasLength(2));
    expect(history.first.date.isBefore(history.last.date), isTrue);
    expect(history.first.price, 56.84);
    expect(history.last.price, 58.10);
    expect(history.first.high, 56.88);
    expect(history.last.volume, 42367600);
  });
}
