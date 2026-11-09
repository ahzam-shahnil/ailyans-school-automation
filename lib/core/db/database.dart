import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:school_automation/core/sync/node_id_allocator.dart';
import 'package:sqflite/sqflite.dart' as mobile; // native Android/iOS
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
    if (Platform.isAndroid || Platform.isIOS) {
      // Native sqflite (Java/Kotlin plugin). No sqfliteFfiInit needed.
      databaseFactory = mobile.databaseFactorySqflitePlugin;
    } else {
      // Desktop: FFI factory backed by sqlite3_flutter_libs.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _getDatabasePath();

    // Phase G-9.7a: fresh installs bootstrap from the bundled sanitized
    // production snapshot (assets/db/seed_school_database.db) instead of the
    // synthetic 10-student seeder. Only file-based databases that do not
    // exist yet are bootstrapped; existing installs and :memory: test
    // databases are untouched.
    await _bootstrapFromBundledSeed(dbPath);

    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        onConfigure: (db) async {
          // Enable foreign keys
          await db.rawQuery('PRAGMA foreign_keys = ON');
          // Use WAL journaling where the engine supports it.
          try {
            await db.rawQuery('PRAGMA journal_mode = WAL');
          } catch (_) {}
        },
      ),
    );

    // Run initial schema load (if PRAGMA user_version == 0) and any pending migrations
    await SchemaMigrations.migrate(db);

    // Phase F-3a: ensure per-device block allocator state.
    // node_id comes from app_config; default 'windows'. Idempotent.
    final cfg = await db.query(
      'app_config',
      columns: ['config_value'],
      where: "config_key = 'node_id'",
    );
    final nodeId = cfg.isEmpty
        ? 'windows'
        : (cfg.first['config_value'] as String);
    await NodeIdAllocator(openDb: () async => db).configureNodeBlock(nodeId);

    // Seed initial development data if Users table is empty
    await DatabaseSeeder.seedIfEmpty(db);
    await DatabaseSeeder.seedFeeTariffsIfEmpty(db);

    // Startup log message
    debugPrint('Database opened at: $dbPath');

    return db;
  }

  /// Copies the bundled sanitized production snapshot to [dbPath] when the
  /// on-disk database file does not exist yet (or is 0 bytes), so first launch
  /// boots with the full production dataset (673 students, schema v10) instead
  /// of the synthetic seeder fixture.
  ///
  /// Never runs for in-memory databases, and never overwrites an existing
  /// database file. Wrapped in try/catch: if the asset bundle is unavailable
  /// (e.g. some test environments), we gracefully fall back to the normal
  /// SchemaMigrations.migrate + DatabaseSeeder.seedIfEmpty path.
  Future<void> _bootstrapFromBundledSeed(String dbPath) async {
    try {
      if (dbPath == inMemoryDatabasePath) return;
      final file = File(dbPath);
      if (file.existsSync() && file.lengthSync() > 0) return;

      final ByteData asset = await rootBundle.load(
        'assets/db/seed_school_database.db',
      );

      // Remove stale WAL/SHM siblings so the clean snapshot is not
      // contaminated by leftover journal files from a previous install.
      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('$dbPath$suffix');
        if (sidecar.existsSync()) sidecar.deleteSync();
      }

      await file.writeAsBytes(asset.buffer.asUint8List(), flush: true);
      debugPrint('Bootstrapped database from bundled seed asset: $dbPath');
    } catch (e) {
      debugPrint('Bundled seed bootstrap skipped: $e');
    }
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
