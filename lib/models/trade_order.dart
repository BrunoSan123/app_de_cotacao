enum TradeType { swing, day }

enum OrderSide { buy, sell }

enum OrderStatus { open, closed, executed, cancelled }

class TradeOrder {
  const TradeOrder({
    required this.id,
    required this.symbol,
    required this.type,
    required this.side,
    required this.status,
    required this.quantity,
    required this.price,
    required this.openedAt,
    this.closedAt,
    this.realizedPnl,
  });

  final String id;
  final String symbol;
  final TradeType type;
  final OrderSide side;
  final OrderStatus status;
  final int quantity;
  final double price;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double? realizedPnl;

  factory TradeOrder.fromJson(Map<String, dynamic> json) {
    return TradeOrder(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      type: TradeType.values.byName(json['type'] as String),
      side: OrderSide.values.byName(json['side'] as String),
      status: OrderStatus.values.byName(json['status'] as String),
      quantity: (json['quantity'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      openedAt: DateTime.parse(json['openedAt'] as String),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      realizedPnl: (json['realizedPnl'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'type': type.name,
    'side': side.name,
    'status': status.name,
    'quantity': quantity,
    'price': price,
    'openedAt': openedAt.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'realizedPnl': realizedPnl,
  };
}
