import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/database.dart';
import '../models/access_object.dart';
import '../models/user.dart';

/// Abstract contract for user management and permission matrix operations.
abstract class UserRepository {
  /// Retrieves all users ordered by ID.
  Future<List<User>> getAllUsers();

  /// Retrieves a specific user by their ID.
  Future<User?> getUserById(int id);

  /// Inserts a new user record into the database. Returns the generated ID.
  Future<int> insertUser(User user);

  /// Updates an existing user's information.
  Future<bool> updateUser(User user);

  /// Deactivates a user (sets IsActive = 0) without destroying audit history.
  Future<bool> deactivateUser(int id);

  /// Retrieves all active securable modules (excluding deprecated ObjID 25).
  Future<List<AccessObject>> getAllAccessObjects();

  /// Retrieves assigned module IDs for a user.
  Future<List<int>> getUserAssignedObjectIds(int userId);

  /// Atomically replaces user module rights via a transaction.
  Future<void> assignUserRights(int userId, List<int> objIds);
}

/// Production implementation of [UserRepository] backed by [DatabaseService].
class UserRepositoryImpl implements UserRepository {
  final DatabaseService _dbService;

  UserRepositoryImpl({DatabaseService? dbService})
    : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<User>> getAllUsers() async {
    final db = await _dbService.database;
    final results = await db.rawQuery('SELECT * FROM Users ORDER BY ID');
    return results.map((row) => User.fromMap(row)).toList();
  }

  @override
  Future<User?> getUserById(int id) async {
    final db = await _dbService.database;
    final results = await db.rawQuery(
      'SELECT * FROM Users WHERE ID = ? LIMIT 1',
      [id],
    );
    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  @override
  Future<int> insertUser(User user) async {
    final db = await _dbService.database;
    int targetId = user.id;

    if (targetId <= 0) {
      final idResult = await db.rawQuery(
        'SELECT COALESCE(MAX(ID), 0) + 1 AS nextId FROM Users',
      );
      targetId = (idResult.first['nextId'] as int?) ?? 1;
    }

    final toInsert = user.copyWith(id: targetId);
    await db.insert('Users', toInsert.toMap());
    return targetId;
  }

  @override
  Future<bool> updateUser(User user) async {
    final db = await _dbService.database;
    final count = await db.update(
      'Users',
      user.toMap(),
      where: 'ID = ?',
      whereArgs: [user.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deactivateUser(int id) async {
    final db = await _dbService.database;
    final count = await db.rawUpdate(
      'UPDATE Users SET IsActive = 0 WHERE ID = ?',
      [id],
    );
    return count > 0;
  }

  @override
  Future<List<AccessObject>> getAllAccessObjects() async {
    final db = await _dbService.database;
    final results = await db.rawQuery(
      'SELECT * FROM AccObj WHERE ObjID != 25 ORDER BY ObjID',
    );
    return results.map((row) => AccessObject.fromMap(row)).toList();
  }

  @override
  Future<List<int>> getUserAssignedObjectIds(int userId) async {
    final db = await _dbService.database;
    final results = await db.rawQuery(
      'SELECT ObjID FROM AccRhts WHERE UID = ?',
      [userId],
    );
    return results.map((row) => row['ObjID'] as int).toList();
  }

  @override
  Future<void> assignUserRights(int userId, List<int> objIds) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM AccRhts WHERE UID = ?', [userId]);
      final batch = txn.batch();
      for (final objId in objIds) {
        batch.insert('AccRhts', {'UID': userId, 'ObjID': objId});
      }
      await batch.commit(noResult: true);
    });
  }
}

/// Riverpod provider for [UserRepository].
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl();
});
