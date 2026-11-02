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

  /// Sets an explicit database instance for testing.
  @visibleForTesting
  void setDatabase(Database? db) {
    _database = db;
  }

  Future<Database> _initDatabase() async {
    // FFI is required for desktop. Android/iOS use the same factory backed by
    // the native sqlite3 library bundled via sqlite3_flutter_libs.
    if (Platform.isWindows) {
      sqfliteFfiInit();
    }
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
    await DatabaseSeeder.seedFeeTariffsIfEmpty(db);

    // Startup log message
    debugPrint('Database opened at: $dbPath');

    return db;
  }

  /// Locates the portable Documents/Ailyans/ directory across platforms.
  /// - Android & iOS: <app documents>/Ailyans/school_database.db
  /// - macOS & Linux: ~/Documents/Ailyans/school_database.db
  /// - Windows: %USERPROFILE%\Documents\Ailyans\school_database.db
  Future<String> _getDatabasePath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docsDir.path, 'Ailyans'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return p.join(dir.path, 'school_database.db');
    }

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

  /// Public accessor for the resolved on-disk DB path.
  /// Kept in sync with _getDatabasePath so BackupService can target the same file.
  Future<String> getDatabasePath() => _getDatabasePath();

  /// Closes the database connection if open.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
