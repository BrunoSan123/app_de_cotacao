import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class LocalJsonStore {
  LocalJsonStore();

  static const _databaseKey = 'tradesim_database_v1';
  late final Future<SharedPreferences> _store = SharedPreferences.getInstance();

  Future<List<User>> getUsers() async {
    final database = await _readDatabase();
    return (database['users'] as List<dynamic>)
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<User?> findUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    for (final user in await getUsers()) {
      if (user.email.toLowerCase() == normalizedEmail) return user;
    }
    return null;
  }

  Future<void> saveUser(User user) async {
    final database = await _readDatabase();
    final users = (database['users'] as List<dynamic>)
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList();
    final userIndex = users.indexWhere((savedUser) => savedUser.id == user.id);

    if (userIndex == -1) {
      users.add(user);
    } else {
      users[userIndex] = user;
    }

    await _writeDatabase({
      'users': users.map((savedUser) => savedUser.toJson()).toList(),
      'currentUserId': database['currentUserId'],
    });
  }

  Future<void> setCurrentUser(String? userId) async {
    final database = await _readDatabase();
    await _writeDatabase({
      'users': database['users'],
      'currentUserId': userId,
    });
  }

  Future<User?> getCurrentUser() async {
    final database = await _readDatabase();
    final currentUserId = database['currentUserId'] as String?;
    if (currentUserId == null) return null;

    for (final user in await getUsers()) {
      if (user.id == currentUserId) return user;
    }
    return null;
  }

  Future<void> clearSession() => setCurrentUser(null);

  Future<Map<String, dynamic>> _readDatabase() async {
    final rawDatabase = (await _store).getString(_databaseKey);
    if (rawDatabase == null) {
      return {'users': <dynamic>[], 'currentUserId': null};
    }

    final decoded = jsonDecode(rawDatabase);
    if (decoded is! Map<String, dynamic> || decoded['users'] is! List) {
      throw const FormatException('Invalid TradeSim local database format.');
    }
    decoded.putIfAbsent('currentUserId', () => null);
    return decoded;
  }

  Future<void> _writeDatabase(Map<String, dynamic> database) async {
    final saved = await (await _store).setString(
      _databaseKey,
      jsonEncode(database),
    );
    if (!saved) {
      throw const LocalStoreException(
        'Não foi possível salvar os dados locais do TradeSim.',
      );
    }
  }
}

class LocalStoreException implements Exception {
  const LocalStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
