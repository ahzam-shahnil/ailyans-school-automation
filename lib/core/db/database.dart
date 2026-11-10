import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:school_automation/core/sync/node_id_allocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as mobile; // native Android/iOS
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migrations.dart';
import 'seed_data.dart';

/// Singleton DatabaseService providing access to the application's SQLite database.
class DatabaseService {
  /// SharedPreferences key holding the active tenant JSON blob. Shared with
  /// `TenantNotifier` (core/providers/tenant_provider.dart) — G-10 Shot 2.
  static const String tenantKey = 'bytewave_tenant';

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

  /// Locates the portable Documents/ directory across platforms.
  /// - Android & iOS: <app documents>
  /// - macOS & Linux: ~/Documents
  /// - Windows: %USERPROFILE%\Documents
  Future<String> _getDocumentsPath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return p.join(userProfile, 'Documents');
      }
    } else {
      // macOS, Linux, and POSIX
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, 'Documents');
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    return docsDir.path;
  }

  /// Resolves the active tenant id used for the tenant-aware database file.
  ///
  /// G-10 Shot 2: reads the tenant persisted by `TenantNotifier` (key
  /// [tenantKey]). Legacy single-tenant installs (Documents/Ailyans/
  /// school_database.db with no tenant configured) are migrated once to
  /// ByteWave/school_default.db and the tenant is pinned to 'default', so
  /// existing installs keep their data without ever seeing the setup wizard.
  Future<String> _resolveTenantId() async {
    const fallback = 'default';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(tenantKey);
      if (raw != null) {
        final json = jsonDecode(raw);
        final id = json is Map<String, dynamic> ? json['id'] : null;
        if (id is String && id.isNotEmpty) return id;
      }

      // No tenant configured: check for a legacy Ailyans install to migrate.
      final documentsPath = await _getDocumentsPath();
      final legacyDb = File(
        p.join(documentsPath, 'Ailyans', 'school_database.db'),
      );
      if (!await legacyDb.exists()) return fallback;

      // Legacy install: copy the database (and WAL sidecars, if any) into
      // the tenant-aware ByteWave directory as school_default.db, then pin
      // the tenant so the first-launch gate skips the setup wizard.
      final byteWaveDir = Directory(p.join(documentsPath, 'ByteWave'));
      if (!await byteWaveDir.exists()) {
        await byteWaveDir.create(recursive: true);
      }
      final migratedDb = File(p.join(byteWaveDir.path, 'school_default.db'));
      if (!await migratedDb.exists()) {
        await legacyDb.copy(migratedDb.path);
        for (final suffix in ['-wal', '-shm']) {
          final sidecar = File('${legacyDb.path}$suffix');
          if (await sidecar.exists()) {
            await sidecar.copy('${migratedDb.path}$suffix');
          }
        }
        debugPrint('Migrated legacy Ailyans database to ${migratedDb.path}');
      }
      await prefs.setString(
        tenantKey,
        jsonEncode({
          'id': 'default',
          'schoolName': '',
          'adminName': '',
          'adminContact': '',
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );
      return 'default';
    } catch (_) {
      // SharedPreferences unavailable (tests) or migration failure: fall
      // back to the single-tenant default database.
      return fallback;
    }
  }

  /// G-10 Shot 2: tenant-aware database path resolution.
  /// - Tenant configured: <Documents>/ByteWave/school_<tenantId>.db
  /// - Legacy install: migrated to <Documents>/ByteWave/school_default.db
  /// - Fresh install: <Documents>/ByteWave/school_default.db
  Future<String> _getDatabasePath() async {
    final documentsPath = await _getDocumentsPath();
    final dir = Directory(p.join(documentsPath, 'ByteWave'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final tenantId = await _resolveTenantId();
    return p.join(dir.path, 'school_$tenantId.db');
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
