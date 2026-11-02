import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database.dart';

/// Result data object returned by candidate backup file validation.
class RestoreValidation {
  final bool ok;
  final String? candidatePath;
  final String? failureReason;
  final int? sourceUserVersion;
  final int? adminCount;

  const RestoreValidation({
    required this.ok,
    this.candidatePath,
    this.failureReason,
    this.sourceUserVersion,
    this.adminCount,
  });
}

/// Service managing SQLite hot backups, candidate validation, and atomic restore.
class BackupService {
  final Future<Directory> Function() _backupsDirResolver;
  final Future<String> Function() _liveDbPathResolver;
  final Future<Database> Function() _openLiveDb;
  final Future<void> Function() _closeLiveDb;
  final DateTime Function() _now;

  BackupService({
    Future<Directory> Function()? backupsDirResolver,
    Future<String> Function()? liveDbPathResolver,
    Future<Database> Function()? openLiveDb,
    Future<void> Function()? closeLiveDb,
    DateTime Function()? now,
  }) : _backupsDirResolver = backupsDirResolver ?? _defaultBackupsDir,
       _liveDbPathResolver = liveDbPathResolver ?? _defaultLiveDbPath,
       _openLiveDb = openLiveDb ?? (() => DatabaseService.instance.database),
       _closeLiveDb = closeLiveDb ?? (() => DatabaseService.instance.close()),
       _now = now ?? DateTime.now;

  static final BackupService instance = BackupService();

  static Future<String> _defaultLiveDbPath() =>
      DatabaseService.instance.getDatabasePath();

  static Future<Directory> _defaultBackupsDir() async {
    final livePath = await _defaultLiveDbPath();
    final dir = Directory(p.join(p.dirname(livePath), 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Directory where automated and manual backups reside.
  Future<Directory> backupsDirectory() async {
    final dir = await _backupsDirResolver();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Resolves the absolute path to the live production database.
  Future<String> liveDbPath() => _liveDbPathResolver();

  /// Lists all *.db files in the backups directory, sorted newest-first.
  Future<List<File>> listBackups() async {
    final dir = await backupsDirectory();
    final entities = await dir.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Exports an instantaneous live snapshot of SQLite via VACUUM INTO.
  Future<File> exportSnapshot({
    String? suggestedName,
    String? explicitTargetPath,
  }) async {
    final dir = await backupsDirectory();
    final targetPath =
        explicitTargetPath ??
        p.join(
          dir.path,
          suggestedName ?? 'school_database_${_stampMinute()}.db',
        );

    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }

    final parentDir = targetFile.parent;
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    final db = await _openLiveDb();
    final escaped = targetPath.replaceAll("'", "''");
    await db.execute("VACUUM INTO '$escaped'");

    return File(targetPath);
  }

  /// Performs read-only integrity inspection on a candidate restore file.
  Future<RestoreValidation> validateCandidate(String filePath) async {
    final candidateFile = File(filePath);
    try {
      if (!candidateFile.existsSync()) {
        return RestoreValidation(
          ok: false,
          candidatePath: filePath,
          failureReason: 'File does not exist',
        );
      }
      if (candidateFile.lengthSync() < 100) {
        return RestoreValidation(
          ok: false,
          candidatePath: filePath,
          failureReason: 'File is smaller than 100 bytes',
        );
      }

      // Check SQLite header (16 bytes: "SQLite format 3\000")
      final raf = candidateFile.openSync(mode: FileMode.read);
      try {
        final header = raf.readSync(16);
        const expected = [
          0x53,
          0x51,
          0x4C,
          0x69,
          0x74,
          0x65,
          0x20,
          0x66,
          0x6F,
          0x72,
          0x6D,
          0x61,
          0x74,
          0x20,
          0x33,
          0x00,
        ];
        if (header.length < 16) {
          return RestoreValidation(
            ok: false,
            candidatePath: filePath,
            failureReason: 'File is not a SQLite database',
          );
        }
        for (var i = 0; i < 16; i++) {
          if (header[i] != expected[i]) {
            return RestoreValidation(
              ok: false,
              candidatePath: filePath,
              failureReason: 'File is not a SQLite database',
            );
          }
        }
      } finally {
        raf.closeSync();
      }

      // Open candidate read-only with singleInstance: false
      sqfliteFfiInit();
      final candDb = await databaseFactoryFfi.openDatabase(
        filePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        // e. PRAGMA quick_check
        final checkRows = await candDb.rawQuery('PRAGMA quick_check');
        final isOk =
            checkRows.isNotEmpty && checkRows.first.values.first == 'ok';
        if (!isOk) {
          return RestoreValidation(
            ok: false,
            candidatePath: filePath,
            failureReason: 'Database integrity check failed',
          );
        }

        // f. Required tables
        final tableRows = await candDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        final tableNames = tableRows
            .map((r) => r['name'] as String?)
            .whereType<String>()
            .toSet();
        const requiredTables = [
          'InstBranch',
          'Users',
          'Stu_Reg',
          'Student_Class',
          'VoucharMas',
          'app_config',
        ];
        for (final req in requiredTables) {
          if (!tableNames.contains(req)) {
            return RestoreValidation(
              ok: false,
              candidatePath: filePath,
              failureReason: 'Missing required table: $req',
            );
          }
        }

        // g. adminCount
        final adminResult = await candDb.rawQuery(
          'SELECT COUNT(*) as cnt FROM Users WHERE UserLvl = 1',
        );
        final adminCount = (adminResult.first['cnt'] as int?) ?? 0;
        if (adminCount < 1) {
          return RestoreValidation(
            ok: false,
            candidatePath: filePath,
            failureReason: 'No SuperAdmin user (UserLvl=1) in backup',
          );
        }

        // h. version
        final versionResult = await candDb.rawQuery('PRAGMA user_version');
        final version = (versionResult.first.values.first as int?) ?? 0;
        if (version > 9) {
          return RestoreValidation(
            ok: false,
            candidatePath: filePath,
            failureReason:
                'Backup is from a newer app version (schema $version > 9)',
          );
        }

        return RestoreValidation(
          ok: true,
          candidatePath: filePath,
          sourceUserVersion: version,
          adminCount: adminCount,
        );
      } finally {
        await candDb.close();
      }
    } catch (_) {
      return RestoreValidation(
        ok: false,
        candidatePath: filePath,
        failureReason: 'Database integrity check failed',
      );
    }
  }

  /// Restores live database from a validated candidate backup.
  Future<File> restoreFrom(String candidatePath) async {
    final v = await validateCandidate(candidatePath);
    if (!v.ok) {
      throw StateError(v.failureReason ?? 'Invalid backup file');
    }

    final safetyFile = await exportSnapshot(
      suggestedName: 'pre_restore_${_stampSecond()}.db',
    );

    await _closeLiveDb();

    final livePath = await liveDbPath();
    for (final p0 in [livePath, '$livePath-wal', '$livePath-shm']) {
      final f = File(p0);
      if (f.existsSync()) {
        f.deleteSync();
      }
    }

    File(candidatePath).copySync(livePath);

    final db = await _openLiveDb();
    final chk = await db.rawQuery('PRAGMA quick_check');
    final ok = chk.isNotEmpty && (chk.first.values.first == 'ok');
    if (!ok) {
      throw StateError(
        'Restore produced corrupt DB - safety backup at ${safetyFile.path}',
      );
    }

    return safetyFile;
  }

  /// Triggers automated daily backup if not already present for today.
  Future<File?> maybeAutoBackup() async {
    final dir = await backupsDirectory();
    final stamp = _stampDay();
    final target = p.join(dir.path, 'auto_$stamp.db');
    if (File(target).existsSync()) return null;

    final created = await exportSnapshot(suggestedName: 'auto_$stamp.db');
    try {
      final autos =
          (await listBackups())
              .where((f) => p.basename(f.path).startsWith('auto_'))
              .toList()
            ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
      for (var i = 10; i < autos.length; i++) {
        try {
          autos[i].deleteSync();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('auto-backup prune skipped: $e');
    }
    return created;
  }

  /// Opens the local backups folder using the host platform's file manager.
  Future<void> openBackupsFolder() async {
    final dir = await backupsDirectory();
    if (Platform.isMacOS) {
      await Process.run('open', [dir.path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [dir.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir.path]);
    } else {
      debugPrint('openBackupsFolder: unsupported platform');
    }
  }

  // --- Stamps (pure ASCII, manual zero-pad, NO intl) ---
  String _pad2(int n) => n.toString().padLeft(2, '0');

  String _stampMinute() {
    final dt = _now();
    final y = dt.year.toString().padLeft(4, '0');
    final mm = _pad2(dt.month);
    final dd = _pad2(dt.day);
    final hh = _pad2(dt.hour);
    final min = _pad2(dt.minute);
    return '$y-$mm-${dd}_$hh$min';
  }

  String _stampSecond() {
    final dt = _now();
    final y = dt.year.toString().padLeft(4, '0');
    final mm = _pad2(dt.month);
    final dd = _pad2(dt.day);
    final hh = _pad2(dt.hour);
    final min = _pad2(dt.minute);
    final ss = _pad2(dt.second);
    return '$y-$mm-${dd}_$hh$min$ss';
  }

  String _stampDay() {
    final dt = _now();
    final y = dt.year.toString().padLeft(4, '0');
    final mm = _pad2(dt.month);
    final dd = _pad2(dt.day);
    return '$y-$mm-$dd';
  }
}
