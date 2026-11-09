import 'wallet.dart';

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.passwordHash,
    required this.createdAt,
    required this.wallet,
  });

  final String id;
  final String email;
  final String fullName;

  /// The caller must provide a one-way password hash, never a plaintext password.
  final String passwordHash;

  final DateTime createdAt;
  final Wallet wallet;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      passwordHash: json['passwordHash'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      wallet: Wallet.fromJson(json['wallet'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'passwordHash': passwordHash,
    'createdAt': createdAt.toIso8601String(),
    'wallet': wallet.toJson(),
  };
}
