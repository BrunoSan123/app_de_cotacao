class AssetQuote {
  const AssetQuote({
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.volume,
    this.name,
    this.dayHigh,
    this.dayLow,
  });

  final String symbol;
  final String? name;
  final double price;
  final double changePercent;
  final double? dayHigh;
  final double? dayLow;
  final int volume;

  factory AssetQuote.fromJson(Map<String, dynamic> json) {
    return AssetQuote(
      symbol: json['symbol'] as String,
      name: json['name'] as String?,
      price: (json['price'] as num).toDouble(),
      changePercent: (json['changePercent'] as num).toDouble(),
      dayHigh: (json['dayHigh'] as num?)?.toDouble(),
      dayLow: (json['dayLow'] as num?)?.toDouble(),
      volume: (json['volume'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'price': price,
    'changePercent': changePercent,
    'dayHigh': dayHigh,
    'dayLow': dayLow,
    'volume': volume,
  };
}
