import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/asset_price_point.dart';
import '../models/asset_quote.dart';

class BrapiService {
  BrapiService({
    http.Client? client,
    this.token = const String.fromEnvironment('BRAPI_TOKEN'),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final String token;

  Future<List<AssetPricePoint>> fetchPriceHistory(
    String symbol, {
    String range = '1mo',
    String interval = '1d',
  }) async {
    final normalizedSymbol = symbol.trim().toUpperCase();
    if (normalizedSymbol.isEmpty) {
      throw ArgumentError.value(symbol, 'symbol', 'A stock symbol is required.');
    }
    final response = await _client
        .get(
          Uri.https(
            'brapi.dev',
            '/api/quote/$normalizedSymbol',
            {
              'range': range,
              'interval': interval,
              if (token.isNotEmpty) 'token': token,
            },
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = switch (response.statusCode) {
        401 => 'A Brapi exige um token válido para consultar este histórico.',
        403 => 'Seu plano da Brapi não permite consultar este histórico.',
        429 => 'A Brapi limitou temporariamente o número de consultas.',
        _ => 'A Brapi respondeu com erro HTTP ${response.statusCode}.',
      };
      throw BrapiApiException(message, statusCode: response.statusCode);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw BrapiApiException(
        'A Brapi retornou JSON inválido: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['results'] is! List ||
        (decoded['results'] as List).isEmpty) {
      throw const BrapiApiException(
        'A Brapi não retornou o histórico deste ativo.',
      );
    }
    final firstResult = (decoded['results'] as List).first;
    if (firstResult is! Map<String, dynamic> ||
        firstResult['historicalDataPrice'] is! List) {
      throw const BrapiApiException(
        'A resposta da Brapi não contém dados históricos.',
      );
    }

    final points = (firstResult['historicalDataPrice'] as List<dynamic>)
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const BrapiApiException(
              'A Brapi retornou um ponto histórico inválido.',
            );
          }
          try {
            return AssetPricePoint.fromJson(item);
          } on FormatException catch (error) {
            throw BrapiApiException(error.message);
          }
        })
        .toList()
      ..sort((first, second) => first.date.compareTo(second.date));
    return points;
  }

  Future<BrapiStockPage> fetchStockList({
    String? search,
    int page = 1,
    int limit = 30,
  }) async {
    if (page < 1 || limit < 1) {
      throw ArgumentError('Page and limit must be greater than zero.');
    }

    final queryParameters = <String, String>{
      'type': 'stock',
      'page': '$page',
      'limit': '$limit',
    };
    final normalizedSearch = search?.trim();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      queryParameters['search'] = normalizedSearch;
    }

    final response = await _client
        .get(Uri.https('brapi.dev', '/api/quote/list', queryParameters))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = switch (response.statusCode) {
        401 || 403 => 'A Brapi recusou o acesso à lista de ativos.',
        429 => 'A Brapi limitou temporariamente o número de consultas.',
        _ => 'A Brapi respondeu com erro HTTP ${response.statusCode}.',
      };
      throw BrapiApiException(message, statusCode: response.statusCode);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw BrapiApiException(
        'A Brapi retornou JSON inválido: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['stocks'] is! List) {
      throw const BrapiApiException(
        'A resposta da Brapi não contém a lista de ações.',
      );
    }

    final stocks = <AssetQuote>[];
    for (final item in decoded['stocks'] as List<dynamic>) {
      if (item is! Map<String, dynamic>) {
        throw const BrapiApiException(
          'A Brapi retornou um ativo em formato inválido.',
        );
      }
      final symbol = item['stock'];
      final price = item['close'];
      final changePercent = item['change'];
      final volume = item['volume'];
      if (symbol is! String ||
          price is! num ||
          changePercent is! num ||
          volume is! num) {
        throw const BrapiApiException(
          'A Brapi retornou dados incompletos para um ativo.',
        );
      }
      stocks.add(
        AssetQuote(
          symbol: symbol,
          name: item['name'] as String?,
          price: price.toDouble(),
          changePercent: changePercent.toDouble(),
          volume: volume.toInt(),
        ),
      );
    }

    final currentPage = _intValue(decoded['currentPage']) ?? page;
    final totalPages = _intValue(decoded['totalPages']) ?? currentPage;
    return BrapiStockPage(
      stocks: stocks,
      currentPage: currentPage,
      hasNextPage: decoded['hasNextPage'] as bool? ?? currentPage < totalPages,
    );
  }

  Future<List<AssetQuote>> fetchQuotes(Iterable<String> symbols) async {
    final normalizedSymbols = symbols
        .map((symbol) => symbol.trim().toUpperCase())
        .where((symbol) => symbol.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedSymbols.isEmpty) {
      throw ArgumentError.value(
        symbols,
        'symbols',
        'At least one symbol is required.',
      );
    }

    final queryParameters = <String, String>{};
    if (token.isNotEmpty) queryParameters['token'] = token;
    final uri = Uri.https(
      'brapi.dev',
      '/api/quote/${normalizedSymbols.join(',')}',
      queryParameters,
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = switch (response.statusCode) {
        401 || 403 =>
          'A Brapi recusou o acesso. Verifique se o token informado é válido.',
        429 => 'A Brapi limitou temporariamente o número de consultas.',
        _ => 'A Brapi respondeu com erro HTTP ${response.statusCode}.',
      };
      throw BrapiApiException(
        message,
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw BrapiApiException('Brapi returned invalid JSON: ${error.message}');
    }

    if (decoded is! Map<String, dynamic> || decoded['results'] is! List) {
      throw const BrapiApiException(
        'Brapi response did not contain quote results.',
      );
    }

    return (decoded['results'] as List<dynamic>).map((result) {
      if (result is! Map<String, dynamic>) {
        throw const BrapiApiException('Brapi returned an invalid quote entry.');
      }
      return AssetQuote(
        symbol: result['symbol'] as String,
        name: result['shortName'] as String?,
        price: _number(result, 'regularMarketPrice'),
        changePercent: _number(result, 'regularMarketChangePercent'),
        dayHigh: _number(result, 'regularMarketDayHigh'),
        dayLow: _number(result, 'regularMarketDayLow'),
        volume: _number(result, 'regularMarketVolume').toInt(),
      );
    }).toList();
  }

  double _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    throw BrapiApiException('Brapi quote is missing numeric field "$key".');
  }

  int? _intValue(dynamic value) => value is num ? value.toInt() : null;

  void close() {
    if (_ownsClient) _client.close();
  }
}

class BrapiStockPage {
  const BrapiStockPage({
    required this.stocks,
    required this.currentPage,
    required this.hasNextPage,
  });

  final List<AssetQuote> stocks;
  final int currentPage;
  final bool hasNextPage;
}

class BrapiApiException implements Exception {
  const BrapiApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BrapiApiException: $message';
}
