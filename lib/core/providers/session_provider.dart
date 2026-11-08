import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/user.dart';
import '../db/database.dart';

/// Represents an authenticated user session with their authorized module object IDs.
class UserSession {
  final User user;
  final List<int> allowedObjIds;
  final bool hasWeakPasswordWarning;

  const UserSession({
    required this.user,
    required this.allowedObjIds,
    this.hasWeakPasswordWarning = false,
  });

  /// Checks if the current user has access to a specific securable module (ObjID).
  bool hasAccess(int objId) => allowedObjIds.contains(objId);

  /// Creates a copy of [UserSession] with updated fields.
  UserSession copyWith({
    User? user,
    List<int>? allowedObjIds,
    bool? hasWeakPasswordWarning,
  }) {
    return UserSession(
      user: user ?? this.user,
      allowedObjIds: allowedObjIds ?? this.allowedObjIds,
      hasWeakPasswordWarning:
          hasWeakPasswordWarning ?? this.hasWeakPasswordWarning,
    );
  }
}

/// StateNotifier managing current authentication session state.
class SessionNotifier extends StateNotifier<UserSession?> {
  final DatabaseService _dbService;

  SessionNotifier({DatabaseService? dbService, bool? autoRestore})
    : _dbService = dbService ?? DatabaseService.instance,
      super(null) {
    final shouldRestore = autoRestore ?? !_isTestEnvironment;
    if (shouldRestore) {
      restoreSession();
    }
  }

  static bool get _isTestEnvironment {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST') ||
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Returns true if a user is currently logged in.
  bool get isAuthenticated => state != null;

  /// Sets the active user session and persists it across restarts.
  void setSession(
    User user,
    List<int> allowedObjIds, {
    bool hasWeakPasswordWarning = false,
  }) {
    final session = UserSession(
      user: user,
      allowedObjIds: allowedObjIds,
      hasWeakPasswordWarning: hasWeakPasswordWarning,
    );
    state = session;
    _persistSession(session);
  }

  /// Alias for [setSession] representing user login.
  void login(
    User user,
    List<int> allowedObjIds, {
    bool hasWeakPasswordWarning = false,
  }) {
    setSession(
      user,
      allowedObjIds,
      hasWeakPasswordWarning: hasWeakPasswordWarning,
    );
  }

  /// Restores persisted user session from `app_config` if available.
  Future<UserSession?> restoreSession() async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        'app_config',
        columns: ['config_value'],
        where: 'config_key = ?',
        whereArgs: ['logged_in_session'],
        limit: 1,
      );
      if (results.isEmpty) return null;
      final jsonStr = results.first['config_value'] as String?;
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final userMap = data['user'] as Map<String, dynamic>;
      final user = User.fromMap(userMap);
      final allowedObjIds =
          (data['allowedObjIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          <int>[];
      final hasWeakWarning = data['hasWeakPasswordWarning'] as bool? ?? false;

      // Verify user is still active in database
      try {
        final userRows = await db.query(
          'Users',
          where: 'ID = ? AND IsActive = 1',
          whereArgs: [user.id],
          limit: 1,
        );
        if (userRows.isEmpty) {
          await _clearPersistedSession(db);
          return null;
        }
        final freshUser = User.fromMap(userRows.first);
        final rightsRows = await db.query(
          'AccRhts',
          columns: ['ObjID'],
          where: 'UID = ?',
          whereArgs: [user.id],
        );
        final freshObjIds = rightsRows.map((r) => r['ObjID'] as int).toList();
        final session = UserSession(
          user: freshUser,
          allowedObjIds: freshObjIds.isNotEmpty ? freshObjIds : allowedObjIds,
          hasWeakPasswordWarning: hasWeakWarning,
        );
        state = session;
        return session;
      } catch (_) {
        final session = UserSession(
          user: user,
          allowedObjIds: allowedObjIds,
          hasWeakPasswordWarning: hasWeakWarning,
        );
        state = session;
        return session;
      }
    } catch (_) {
      return null;
    }
  }

  /// Sets or updates the weak password warning state.
  void setWeakPasswordWarning(bool warning) {
    if (state != null) {
      final updated = state!.copyWith(hasWeakPasswordWarning: warning);
      state = updated;
      _persistSession(updated);
    }
  }

  /// Dismisses the weak password warning banner.
  void dismissWeakPasswordWarning() {
    if (state != null) {
      final updated = state!.copyWith(hasWeakPasswordWarning: false);
      state = updated;
      _persistSession(updated);
    }
  }

  /// Updates the user in the active session (e.g. after password change).
  void updateUser(User user) {
    if (state != null) {
      final updated = state!.copyWith(user: user);
      state = updated;
      _persistSession(updated);
    }
  }

  /// Clears the active session (logout) and deletes persisted session.
  void clear() {
    state = null;
    _clearPersistedSession();
  }

  /// Alias for [clear] representing user logout.
  void logout() => clear();

  Future<void> _persistSession(UserSession session) async {
    if (_isTestEnvironment) return;
    try {
      final db = await _dbService.database;
      final jsonStr = jsonEncode({
        'user': session.user.toMap(),
        'allowedObjIds': session.allowedObjIds,
        'hasWeakPasswordWarning': session.hasWeakPasswordWarning,
      });
      await db.insert('app_config', {
        'config_key': 'logged_in_session',
        'config_value': jsonStr,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_config', {
        'config_key': 'logged_in_user_id',
        'config_value': session.user.id.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> _clearPersistedSession([Database? activeDb]) async {
    if (_isTestEnvironment) return;
    try {
      final db = activeDb ?? await _dbService.database;
      await db.delete(
        'app_config',
        where: "config_key IN ('logged_in_session', 'logged_in_user_id')",
      );
    } catch (_) {}
  }
}

/// Global provider for the active user session.
final sessionProvider = StateNotifierProvider<SessionNotifier, UserSession?>((
  ref,
) {
  return SessionNotifier();
});
