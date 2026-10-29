// LIVE DATABASE DESTRUCTIVE TEST
// Run explicitly via:
//   flutter test tool/live/restore_rehearsal_test.dart \
//     --dart-define=RUN_LIVE_DB_REHEARSAL=true
// Lives OUTSIDE test/ so `flutter test` (no args) never discovers it.
// The path IS the gate; no tag system involved.
// EXERCISES THE REAL ~/Documents/Ailyans/school_database.db.
//
// Preconditions:
//   - App is closed (no flutter run, no sqflite handle on the live DB)
//   - Manual backup exists at ~/Documents/Ailyans_manual_backups/
//   - Baseline: Stu_Reg=670, VoucharMas=2024, Teachers=24, session_yr='2026-27'

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:school_automation/core/db/backup_service.dart';
import 'package:school_automation/core/db/database.dart';

// ignore_for_file: avoid_print

const Map<String, Object> _baseline = {
  'Stu_Reg': 670,
  'VoucharMas': 2024,
  'Teachers': 24,
  'session_yr': '2026-27',
};

void main() {
  test(
    'live restore rehearsal',
    () async {
      // Double opt-in guard: tag alone is not enough.
      // Must also pass --dart-define=RUN_LIVE_DB_REHEARSAL=true.
      const optIn = bool.fromEnvironment('RUN_LIVE_DB_REHEARSAL');
      if (!optIn) {
        markTestSkipped(
          'Set -DRUN_LIVE_DB_REHEARSAL=true and run with --tags live-db',
        );
        return;
      }

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final log = StringBuffer();

      void emit(String s) {
        debugPrint(s);
        log.writeln(s);
      }

      void ok(String s) => emit('  OK  $s');

      void failStep(int code, String msg) {
        emit('  FAIL [$code] $msg');
        _writeLog(log, stamp: _stampSecond());
        fail('[$code] $msg');
      }

      final stamp = _stampSecond();
      emit('=================================================');
      emit(' Live Restore Rehearsal -- ${DateTime.now()}');
      emit('=================================================');

      // -----------------------------------------------------------------------
      // Step 0: Open live DB
      // -----------------------------------------------------------------------
      emit('\n--- Step 0: Init sqfliteFfi + open live DB ---');
      Database liveDb;
      try {
        liveDb = await DatabaseService.instance.database;
        ok('Live DB opened');
      } catch (e) {
        failStep(1, 'Could not open live DB: $e');
        return;
      }
      final livePath = await DatabaseService.instance.getDatabasePath();
      ok('Path: $livePath');

      // -----------------------------------------------------------------------
      // Step 0.5: Independent pre-rehearsal safety backup (raw VACUUM INTO,
      // NOT via BackupService, so we have a fallback even if BackupService fails)
      // -----------------------------------------------------------------------
      emit('\n--- Step 0.5: Independent pre-rehearsal safety backup ---');
      final backupsDir = Directory(p.join(p.dirname(livePath), 'backups'));
      await backupsDir.create(recursive: true);
      final preBackupPath = p.join(backupsDir.path, 'pre_rehearsal_$stamp.db');
      if (File(preBackupPath).existsSync()) File(preBackupPath).deleteSync();
      final escapedPre = preBackupPath.replaceAll("'", "''");
      await liveDb.execute("VACUUM INTO '$escapedPre'");
      final preBackupFile = File(preBackupPath);
      if (!preBackupFile.existsSync() || preBackupFile.lengthSync() < 1024) {
        failStep(1, 'Pre-rehearsal backup failed or empty: $preBackupPath');
        return;
      }
      ok(
        'Pre-rehearsal backup: $preBackupPath (${preBackupFile.lengthSync()} bytes)',
      );

      // -----------------------------------------------------------------------
      // Step 1: Baseline counts
      // -----------------------------------------------------------------------
      emit('\n--- Step 1: Baseline row counts ---');
      final stuReg =
          (await liveDb.rawQuery('SELECT COUNT(*) FROM Stu_Reg'))
              .first
              .values
              .first as int;
      final voucharMas =
          (await liveDb.rawQuery('SELECT COUNT(*) FROM VoucharMas'))
              .first
              .values
              .first as int;
      final teachers =
          (await liveDb.rawQuery('SELECT COUNT(*) FROM Teachers'))
              .first
              .values
              .first as int;
      final sessionRows = await liveDb.rawQuery(
        "SELECT config_value FROM app_config WHERE config_key = 'default_session_yr' LIMIT 1",
      );
      final sessionYr =
          sessionRows.isEmpty
              ? null
              : sessionRows.first['config_value'] as String?;

      emit(
        '  Stu_Reg=$stuReg  VoucharMas=$voucharMas  Teachers=$teachers  session=$sessionYr',
      );

      if (stuReg != _baseline['Stu_Reg']) {
        failStep(2, 'Stu_Reg baseline: got $stuReg expected ${_baseline['Stu_Reg']}');
        return;
      }
      if (voucharMas != _baseline['VoucharMas']) {
        failStep(2, 'VoucharMas baseline: got $voucharMas expected ${_baseline['VoucharMas']}');
        return;
      }
      if (teachers != _baseline['Teachers']) {
        failStep(2, 'Teachers baseline: got $teachers expected ${_baseline['Teachers']}');
        return;
      }
      if (sessionYr != _baseline['session_yr']) {
        failStep(2, 'session_yr baseline: got $sessionYr expected ${_baseline['session_yr']}');
        return;
      }
      ok('All baseline counts match');

      // -----------------------------------------------------------------------
      // Step 2: Export snapshot via BackupService.exportSnapshot
      // -----------------------------------------------------------------------
      emit('\n--- Step 2: Export snapshot via BackupService.exportSnapshot ---');
      File snapshot;
      try {
        snapshot = await BackupService.instance.exportSnapshot(
          suggestedName: 'rehearsal_export_$stamp.db',
        );
      } catch (e) {
        failStep(3, 'exportSnapshot threw: $e');
        return;
      }
      if (!snapshot.existsSync()) {
        failStep(3, 'Snapshot file does not exist after export');
        return;
      }
      ok('Snapshot: ${snapshot.path} (${snapshot.lengthSync()} bytes)');

      // -----------------------------------------------------------------------
      // Step 3: Validate candidate
      // -----------------------------------------------------------------------
      emit('\n--- Step 3: validateCandidate ---');
      RestoreValidation validation;
      try {
        validation =
            await BackupService.instance.validateCandidate(snapshot.path);
      } catch (e) {
        failStep(4, 'validateCandidate threw: $e');
        return;
      }
      if (!validation.ok) {
        failStep(4, 'Validation failed: ${validation.failureReason}');
        return;
      }
      ok(
        'Validation passed: schema=v${validation.sourceUserVersion} admins=${validation.adminCount}',
      );

      // -----------------------------------------------------------------------
      // Step 4: DESTRUCTIVE restore
      // -----------------------------------------------------------------------
      emit('\n--- Step 4: DESTRUCTIVE restoreFrom ---');
      emit('  *** Overwriting $livePath ***');
      File safetyBackup;
      try {
        safetyBackup =
            await BackupService.instance.restoreFrom(snapshot.path);
      } catch (e) {
        failStep(5, 'restoreFrom threw: $e');
        return;
      }
      ok('restoreFrom returned safety backup: ${safetyBackup.path}');

      // -----------------------------------------------------------------------
      // Step 5: Reopen and post-restore counts
      // -----------------------------------------------------------------------
      emit('\n--- Step 5: Post-restore counts ---');
      Database restoredDb;
      try {
        restoredDb = await DatabaseService.instance.database;
      } catch (e) {
        failStep(5, 'Could not reopen DB after restore: $e');
        return;
      }

      final stuReg2 =
          (await restoredDb.rawQuery('SELECT COUNT(*) FROM Stu_Reg'))
              .first
              .values
              .first as int;
      final voucharMas2 =
          (await restoredDb.rawQuery('SELECT COUNT(*) FROM VoucharMas'))
              .first
              .values
              .first as int;
      final teachers2 =
          (await restoredDb.rawQuery('SELECT COUNT(*) FROM Teachers'))
              .first
              .values
              .first as int;

      emit(
        '  Stu_Reg=$stuReg2  VoucharMas=$voucharMas2  Teachers=$teachers2',
      );

      if (stuReg2 != stuReg) {
        failStep(6, 'Post-restore Stu_Reg: $stuReg2 != $stuReg');
        return;
      }
      if (voucharMas2 != voucharMas) {
        failStep(6, 'Post-restore VoucharMas: $voucharMas2 != $voucharMas');
        return;
      }
      if (teachers2 != teachers) {
        failStep(6, 'Post-restore Teachers: $teachers2 != $teachers');
        return;
      }
      ok('All post-restore counts match');

      // -----------------------------------------------------------------------
      // Step 6: PRAGMA quick_check
      // -----------------------------------------------------------------------
      emit('\n--- Step 6: PRAGMA quick_check ---');
      final chk = await restoredDb.rawQuery('PRAGMA quick_check');
      final chkResult =
          chk.isNotEmpty ? (chk.first.values.first as String?) : null;
      emit('  quick_check result: $chkResult');
      if (chkResult != 'ok') {
        failStep(7, 'quick_check: $chkResult');
        return;
      }
      ok('quick_check = ok');

      // -----------------------------------------------------------------------
      // Step 7: Admin user check
      // -----------------------------------------------------------------------
      emit('\n--- Step 7: Admin user check ---');
      final adminCount =
          (await restoredDb.rawQuery(
                'SELECT COUNT(*) FROM Users WHERE UserLvl = 1',
              ))
              .first
              .values
              .first as int;
      emit('  Admin users: $adminCount');
      if (adminCount < 1) {
        failStep(8, 'No admin users in restored DB');
        return;
      }
      ok('Admin users: $adminCount');

      // -----------------------------------------------------------------------
      // Step 8: WAL/SHM hygiene
      // -----------------------------------------------------------------------
      emit('\n--- Step 8: WAL/SHM hygiene ---');
      for (final suffix in ['-wal', '-shm']) {
        final f = File('$livePath$suffix');
        if (f.existsSync()) {
          failStep(9, 'Stale $suffix file present: ${f.path}');
          return;
        }
        ok('Not present: ${p.basename('$livePath$suffix')}');
      }

      // -----------------------------------------------------------------------
      // Step 9: Safety backups still on disk
      // -----------------------------------------------------------------------
      emit('\n--- Step 9: Safety backup existence ---');
      if (!preBackupFile.existsSync()) {
        failStep(10, 'pre_rehearsal backup missing: $preBackupPath');
        return;
      }
      if (!safetyBackup.existsSync()) {
        failStep(10, 'restoreFrom safety backup missing: ${safetyBackup.path}');
        return;
      }
      ok('pre_rehearsal: ${preBackupFile.path}');
      ok('safety: ${safetyBackup.path}');

      // -----------------------------------------------------------------------
      // Step 10: Write log
      // -----------------------------------------------------------------------
      emit('\n--- Step 10: Write log ---');
      _writeLog(log, stamp: stamp);
      ok('Log written');

      emit('\n=================================================');
      emit(' ALL STEPS PASSED');
      emit(' Live DB: $livePath');
      emit(' Pre-rehearsal backup: $preBackupPath');
      emit(' restoreFrom safety backup: ${safetyBackup.path}');
      emit(' Snapshot: ${snapshot.path}');
      emit('=================================================');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

// ---------------------------------------------------------------------------
// Helpers (top-level, outside main)
// ---------------------------------------------------------------------------

void _writeLog(StringBuffer log, {required String stamp}) {
  try {
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory(p.join(home, 'Documents', 'Ailyans', 'backups'));
    dir.createSync(recursive: true);
    final f = File(p.join(dir.path, 'rehearsal_log_$stamp.txt'));
    log.writeln('\n=== END ===');
    f.writeAsStringSync(log.toString());
    debugPrint('Log written to: ${f.path}');
  } catch (e) {
    debugPrint('Could not write log: $e');
  }
}

String _stampSecond() {
  final now = DateTime.now();
  String pad2(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${pad2(now.month)}-${pad2(now.day)}_${pad2(now.hour)}${pad2(now.minute)}${pad2(now.second)}';
}
