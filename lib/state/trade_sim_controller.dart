import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/asset_price_point.dart';
import '../models/asset_quote.dart';
import '../models/trade_order.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../services/brapi_service.dart';
import '../services/local_json_store.dart';

class TradeSimController extends ChangeNotifier {
  static int _idSequence = 0;

  TradeSimController({LocalJsonStore? store, BrapiService? brapiService})
    : _store = store ?? LocalJsonStore(),
      _brapiService = brapiService ?? BrapiService();

  final LocalJsonStore _store;
  final BrapiService _brapiService;

  User? user;
  List<AssetQuote> quotes = const [];
  String? quoteError;
  bool isLoading = true;
  bool isRefreshingQuotes = false;
  bool isLoadingMoreQuotes = false;
  bool hasMoreQuotes = false;
  String? errorMessage;
  int selectedTab = 0;
  String searchQuery = '';
  String? selectedTradeSymbol;
  int _currentQuotePage = 0;
  int _quoteRequestId = 0;
  Timer? _searchDebounce;
  final Map<String, AssetQuote> _quoteCache = {};

  double get cashBalance => user?.wallet.availableBalance ?? 0;

  List<TradeOrder> get orders => user?.wallet.orders ?? const [];

  List<TradeOrder> get openDayTrades => orders
      .where(
        (order) =>
            order.type == TradeType.day && order.status == OrderStatus.open,
      )
      .toList();

  List<TradeOrder> get swingOrders => orders
      .where(
        (order) =>
            order.type == TradeType.swing &&
            order.status == OrderStatus.executed,
      )
      .toList();

  List<AssetQuote> get filteredQuotes {
    final query = searchQuery.trim().toUpperCase();
    if (query.isEmpty) return quotes;
    return quotes
        .where(
          (quote) =>
              quote.symbol.contains(query) ||
              (quote.name?.toUpperCase().contains(query) ?? false),
        )
        .toList();
  }

  Future<List<AssetPricePoint>> fetchPriceHistory(
    String symbol, {
    String range = '1mo',
  }) {
    return _brapiService.fetchPriceHistory(
      symbol,
      range: range,
      interval: '1d',
    );
  }

  void openTradingFor(String symbol) {
    selectedTradeSymbol = symbol;
    selectedTab = 3;
    notifyListeners();
  }

  double get investedValue {
    var total = 0.0;
    for (final entry in holdings.entries) {
      final quote = quoteFor(entry.key);
      if (quote != null) total += entry.value * quote.price;
    }
    return total;
  }

  double get totalEquity {
    final openDayValue = openDayTrades.fold<double>(
      0,
      (total, order) =>
          total +
          order.quantity * (quoteFor(order.symbol)?.price ?? order.price),
    );
    return cashBalance + investedValue + openDayValue;
  }

  Map<String, int> get holdings {
    final result = <String, int>{};
    for (final order in swingOrders) {
      final multiplier = order.side == OrderSide.buy ? 1 : -1;
      result.update(
        order.symbol,
        (quantity) => quantity + multiplier * order.quantity,
        ifAbsent: () => multiplier * order.quantity,
      );
    }
    result.removeWhere((_, quantity) => quantity <= 0);
    return result;
  }

  Future<void> initialize() async {
    try {
      user = await _store.getCurrentUser();
    } finally {
      isLoading = false;
      notifyListeners();
    }
    await refreshQuotes();
  }

  Future<void> refreshQuotes() {
    _searchDebounce?.cancel();
    return _loadQuotePage(reset: true);
  }

  Future<void> loadMoreQuotes() async {
    if (!hasMoreQuotes || isRefreshingQuotes || isLoadingMoreQuotes) return;
    await _loadQuotePage(reset: false);
  }

  Future<void> _loadQuotePage({required bool reset}) async {
    final requestId = ++_quoteRequestId;
    final page = reset ? 1 : _currentQuotePage + 1;
    if (reset) {
      isRefreshingQuotes = true;
      quotes = const [];
      _currentQuotePage = 0;
      hasMoreQuotes = false;
      quoteError = null;
    } else {
      isLoadingMoreQuotes = true;
    }
    notifyListeners();

    try {
      final result = await _brapiService.fetchStockList(
        search: searchQuery,
        page: page,
      );
      if (requestId != _quoteRequestId) return;
      for (final stock in result.stocks) {
        _quoteCache[stock.symbol] = stock;
      }
      quotes = reset
          ? result.stocks
          : [
              ...quotes,
              ...result.stocks.where(
                (stock) => !quotes.any((quote) => quote.symbol == stock.symbol),
              ),
            ];
      _currentQuotePage = result.currentPage;
      hasMoreQuotes = result.hasNextPage;
      quoteError = null;
    } on BrapiApiException catch (error) {
      if (requestId == _quoteRequestId) {
        quoteError = error.message;
      }
    } on Exception {
      if (requestId == _quoteRequestId) {
        quoteError = 'Não foi possível conectar à Brapi. Verifique sua conexão e tente novamente.';
      }
    } finally {
      if (requestId == _quoteRequestId) {
        isRefreshingQuotes = false;
        isLoadingMoreQuotes = false;
        notifyListeners();
      }
    }
  }

  AssetQuote? quoteFor(String symbol) {
    final cachedQuote = _quoteCache[symbol];
    if (cachedQuote != null) return cachedQuote;
    for (final quote in quotes) {
      if (quote.symbol == symbol) return quote;
    }
    return null;
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    errorMessage = null;
    final normalizedEmail = email.trim().toLowerCase();
    if (fullName.trim().isEmpty ||
        normalizedEmail.isEmpty ||
        password.length < 6) {
      errorMessage =
          'Preencha seu nome, e-mail e uma senha com ao menos 6 caracteres.';
      notifyListeners();
      return false;
    }
    if (await _store.findUserByEmail(normalizedEmail) != null) {
      errorMessage = 'Já existe uma conta cadastrada com este e-mail.';
      notifyListeners();
      return false;
    }

    final id = _newId();
    final newUser = User(
      id: id,
      email: normalizedEmail,
      fullName: fullName.trim(),
      passwordHash: _passwordHash(id, password),
      createdAt: DateTime.now(),
      wallet: const Wallet(),
    );
    await _store.saveUser(newUser);
    await _store.setCurrentUser(newUser.id);
    user = newUser;
    selectedTab = 0;
    notifyListeners();
    return true;
  }

  Future<bool> signIn({required String email, required String password}) async {
    errorMessage = null;
    final savedUser = await _store.findUserByEmail(email);
    if (savedUser == null ||
        savedUser.passwordHash != _passwordHash(savedUser.id, password)) {
      errorMessage = 'E-mail ou senha incorretos.';
      notifyListeners();
      return false;
    }
    await _store.setCurrentUser(savedUser.id);
    user = savedUser;
    selectedTab = 0;
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    await _store.clearSession();
    user = null;
    selectedTab = 0;
    notifyListeners();
  }

  Future<void> transfer({
    required WalletTransactionType type,
    required double amount,
  }) async {
    if (amount <= 0) throw ArgumentError('Informe um valor maior que zero.');
    final current = _requireUser();
    if (type == WalletTransactionType.withdrawal &&
        amount > current.wallet.availableBalance) {
      throw TradeSimException('Saldo insuficiente para realizar o saque.');
    }
    final balance = type == WalletTransactionType.deposit
        ? current.wallet.availableBalance + amount
        : current.wallet.availableBalance - amount;
    final transaction = WalletTransaction(
      id: _newId(),
      type: type,
      amount: amount,
      createdAt: DateTime.now(),
    );
    await _saveWallet(
      current,
      Wallet(
        availableBalance: balance,
        orders: current.wallet.orders,
        transactions: [transaction, ...current.wallet.transactions],
      ),
    );
  }

  Future<void> placeSwingOrder({
    required String symbol,
    required OrderSide side,
    required int quantity,
    required double price,
  }) async {
    if (quantity < 1 || price <= 0) {
      throw ArgumentError('Quantidade e preço precisam ser maiores que zero.');
    }
    _requireMarketQuote(symbol);
    final current = _requireUser();
    final value = quantity * price;
    if (side == OrderSide.buy && value > current.wallet.availableBalance) {
      throw TradeSimException('Saldo insuficiente para comprar este ativo.');
    }
    if (side == OrderSide.sell && (holdings[symbol] ?? 0) < quantity) {
      throw TradeSimException(
        'Você não possui essa quantidade de $symbol em custódia.',
      );
    }

    final order = TradeOrder(
      id: _newId(),
      symbol: symbol,
      type: TradeType.swing,
      side: side,
      status: OrderStatus.executed,
      quantity: quantity,
      price: price,
      openedAt: DateTime.now(),
    );
    await _saveWallet(
      current,
      Wallet(
        availableBalance:
            current.wallet.availableBalance +
            (side == OrderSide.buy ? -value : value),
        orders: [order, ...current.wallet.orders],
        transactions: current.wallet.transactions,
      ),
    );
  }

  Future<void> openDayTrade({
    required String symbol,
    required int quantity,
    required double price,
  }) async {
    if (quantity < 1 || price <= 0) {
      throw ArgumentError('Quantidade e preço precisam ser maiores que zero.');
    }
    _requireMarketQuote(symbol);
    final current = _requireUser();
    final value = quantity * price;
    if (value > current.wallet.availableBalance) {
      throw TradeSimException(
        'Saldo insuficiente para abrir esta posição simulada.',
      );
    }
    final order = TradeOrder(
      id: _newId(),
      symbol: symbol,
      type: TradeType.day,
      side: OrderSide.buy,
      status: OrderStatus.open,
      quantity: quantity,
      price: price,
      openedAt: DateTime.now(),
    );
    await _saveWallet(
      current,
      Wallet(
        availableBalance: current.wallet.availableBalance - value,
        orders: [order, ...current.wallet.orders],
        transactions: current.wallet.transactions,
      ),
    );
  }

  Future<void> closeDayTrade(TradeOrder order, double exitPrice) async {
    if (exitPrice <= 0) throw ArgumentError('O preço deve ser maior que zero.');
    final current = _requireUser();
    final currentOrder = current.wallet.orders.firstWhere(
      (savedOrder) => savedOrder.id == order.id,
    );
    if (currentOrder.type != TradeType.day ||
        currentOrder.status != OrderStatus.open) {
      throw TradeSimException('Esta posição já foi encerrada.');
    }
    final closedOrder = TradeOrder(
      id: currentOrder.id,
      symbol: currentOrder.symbol,
      type: currentOrder.type,
      side: currentOrder.side,
      status: OrderStatus.closed,
      quantity: currentOrder.quantity,
      price: currentOrder.price,
      openedAt: currentOrder.openedAt,
      closedAt: DateTime.now(),
      realizedPnl: (exitPrice - currentOrder.price) * currentOrder.quantity,
    );
    final updatedOrders = current.wallet.orders
        .map(
          (savedOrder) =>
              savedOrder.id == currentOrder.id ? closedOrder : savedOrder,
        )
        .toList();
    await _saveWallet(
      current,
      Wallet(
        availableBalance:
            current.wallet.availableBalance + currentOrder.quantity * exitPrice,
        orders: updatedOrders,
        transactions: current.wallet.transactions,
      ),
    );
  }

  void selectTab(int index) {
    selectedTab = index;
    notifyListeners();
  }

  void updateSearch(String value) {
    _quoteRequestId++;
    searchQuery = value;
    _searchDebounce?.cancel();
    quotes = const [];
    hasMoreQuotes = false;
    quoteError = null;
    isRefreshingQuotes = true;
    notifyListeners();
    _searchDebounce = Timer(const Duration(milliseconds: 350), refreshQuotes);
  }

  void _requireMarketQuote(String symbol) {
    if (quoteFor(symbol) == null) {
      throw TradeSimException(
        'O ativo $symbol não está na lista carregada pela Brapi. '
        'Atualize o mercado e selecione um ativo disponível.',
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _brapiService.close();
    super.dispose();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  User _requireUser() {
    final current = user;
    if (current == null) {
      throw TradeSimException('Entre na sua conta para continuar.');
    }
    return current;
  }

  Future<void> _saveWallet(User current, Wallet wallet) async {
    final updatedUser = User(
      id: current.id,
      email: current.email,
      fullName: current.fullName,
      passwordHash: current.passwordHash,
      createdAt: current.createdAt,
      wallet: wallet,
    );
    await _store.saveUser(updatedUser);
    user = updatedUser;
    notifyListeners();
  }

  String _passwordHash(String userId, String password) {
    return sha256.convert(utf8.encode('$userId:$password')).toString();
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';
}

class TradeSimException implements Exception {
  const TradeSimException(this.message);

  final String message;

  @override
  String toString() => message;
}
