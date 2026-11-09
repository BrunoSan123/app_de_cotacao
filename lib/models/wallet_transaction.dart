enum WalletTransactionType { deposit, withdrawal }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final WalletTransactionType type;
  final double amount;
  final DateTime createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      type: WalletTransactionType.values.byName(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'createdAt': createdAt.toIso8601String(),
  };
}
