import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migrations.dart';
import 'seed_data.dart';

/// Singleton DatabaseService providing access to the application's SQLite database.
class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance = DatabaseService._internal();

  factory DatabaseService() => instance;

  Database? _database;

  /// Exposes the open and fully migrated SQLite Database instance.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = await _getDatabasePath();

    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        onConfigure: (db) async {
          // Enable foreign keys
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );

    // Run initial schema load (if PRAGMA user_version == 0) and any pending migrations
    await SchemaMigrations.migrate(db);

    // Seed initial development data if Users table is empty
    await DatabaseSeeder.seedIfEmpty(db);

    // Startup log message
    debugPrint('Database opened at: $dbPath');

    return db;
  }

  /// Locates the portable Documents/Ailyans/ directory across platforms.
  /// - macOS & Linux: ~/Documents/Ailyans/school_database.db
  /// - Windows: %USERPROFILE%\Documents\Ailyans\school_database.db
  Future<String> _getDatabasePath() async {
    String documentsPath;

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        documentsPath = p.join(userProfile, 'Documents');
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        documentsPath = docsDir.path;
      }
    } else {
      // macOS, Linux, and POSIX
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        documentsPath = p.join(home, 'Documents');
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        documentsPath = docsDir.path;
      }
    }

    final ailyansDir = Directory(p.join(documentsPath, 'Ailyans'));
    if (!await ailyansDir.exists()) {
      await ailyansDir.create(recursive: true);
    }
    return p.join(ailyansDir.path, 'school_database.db');
  }

  /// Closes the database connection if open.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
