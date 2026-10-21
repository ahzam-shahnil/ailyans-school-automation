import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/db/database.dart';
import '../models/user.dart';

/// Abstract contract for authentication operations.
abstract class AuthRepository {
  /// Retrieves all usernames for the login selection dropdown.
  Future<List<String>> getAllUsernames();

  /// Authenticates user against BCrypt hashed credentials in the SQLite database.
  Future<User?> authenticate(String username, String password);

  /// Retrieves authorized access object IDs (AccRhts) for the user.
  Future<List<int>> getUserAllowedObjectIds(int userId);

  /// Updates user password after validating minimum length of 8 characters.
  Future<bool> changePassword(int userId, String newPassword);

  /// Retrieves the persisted username if "Remember me" was previously checked.
  Future<String?> getRememberedUsername();

  /// Persists or clears the remembered username in the app_config table.
  Future<void> setRememberedUsername(String? username);
}

/// Production implementation of [AuthRepository] backed by [DatabaseService].
class AuthRepositoryImpl implements AuthRepository {
  final DatabaseService _dbService;

  AuthRepositoryImpl({DatabaseService? dbService})
    : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<String>> getAllUsernames() async {
    final db = await _dbService.database;
    final results = await db.rawQuery('SELECT Name FROM Users ORDER BY Name');
    return results.map((row) => row['Name'] as String).toList();
  }

  @override
  Future<User?> authenticate(String username, String password) async {
    final db = await _dbService.database;
    final results = await db.rawQuery(
      'SELECT * FROM Users WHERE Name = ? AND IsActive = 1 LIMIT 1',
      [username],
    );

    if (results.isEmpty) return null;

    final user = User.fromMap(results.first);
    if (BCrypt.checkpw(password, user.password)) {
      return user;
    }
    return null;
  }

  @override
  Future<List<int>> getUserAllowedObjectIds(int userId) async {
    final db = await _dbService.database;
    final results = await db.rawQuery(
      'SELECT ObjID FROM AccRhts WHERE UID = ?',
      [userId],
    );
    return results.map((row) => row['ObjID'] as int).toList();
  }

  @override
  Future<bool> changePassword(int userId, String newPassword) async {
    if (newPassword.length < 8) {
      return false;
    }

    final db = await _dbService.database;
    final hashedPassword = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    final count = await db.rawUpdate('UPDATE Users SET Pwd = ? WHERE ID = ?', [
      hashedPassword,
      userId,
    ]);
    return count > 0;
  }

  @override
  Future<String?> getRememberedUsername() async {
    final db = await _dbService.database;
    final results = await db.query(
      'app_config',
      columns: ['config_value'],
      where: 'config_key = ?',
      whereArgs: ['last_username'],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['config_value'] as String?;
  }

  @override
  Future<void> setRememberedUsername(String? username) async {
    final db = await _dbService.database;
    if (username == null || username.trim().isEmpty) {
      await db.delete(
        'app_config',
        where: 'config_key = ?',
        whereArgs: ['last_username'],
      );
    } else {
      await db.insert('app_config', {
        'config_key': 'last_username',
        'config_value': username.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

/// Riverpod provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});
