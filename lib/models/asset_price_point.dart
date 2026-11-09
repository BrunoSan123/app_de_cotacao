class AssetPricePoint {
  const AssetPricePoint({
    required this.date,
    required this.price,
    this.open,
    this.high,
    this.low,
    this.volume,
  });

  final DateTime date;
  final double price;
  final double? open;
  final double? high;
  final double? low;
  final int? volume;

  factory AssetPricePoint.fromJson(Map<String, dynamic> json) {
    final timestamp = json['date'];
    if (timestamp is! num) {
      throw const FormatException('Invalid Brapi history date.');
    }

    final close = json['adjustedClose'] ?? json['close'];
    if (close is! num) {
      throw const FormatException('Invalid Brapi history price.');
    }

    return AssetPricePoint(
      date: DateTime.fromMillisecondsSinceEpoch(
        timestamp.toInt() * 1000,
        isUtc: true,
      ),
      price: close.toDouble(),
      open: (json['open'] as num?)?.toDouble(),
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toInt(),
    );
  }
}
