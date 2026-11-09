import 'trade_order.dart';
import 'wallet_transaction.dart';

class Wallet {
  const Wallet({
    this.availableBalance = 50000,
    this.orders = const [],
    this.transactions = const [],
  });

  final double availableBalance;
  final List<TradeOrder> orders;
  final List<WalletTransaction> transactions;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      availableBalance: (json['availableBalance'] as num).toDouble(),
      orders: (json['orders'] as List<dynamic>)
          .map((item) => TradeOrder.fromJson(item as Map<String, dynamic>))
          .toList(),
      transactions: (json['transactions'] as List<dynamic>)
          .map(
            (item) => WalletTransaction.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'availableBalance': availableBalance,
    'orders': orders.map((order) => order.toJson()).toList(),
    'transactions': transactions
        .map((transaction) => transaction.toJson())
        .toList(),
  };
}
