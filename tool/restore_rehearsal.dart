// ignore_for_file: avoid_print
// ignore_for_file: avoid_relative_lib_imports
//
// DEPRECATED - kept as reference only.
// Cannot execute under `dart run` or `flutter pub run` because the script
// transitively imports package:flutter/foundation.dart via backup_service.dart,
// which requires the Flutter engine's dart:ui bindings.
//
// The executable version of this rehearsal lives at:
//   tool/live/restore_rehearsal_test.dart
// Run with:
//   flutter test tool/live/restore_rehearsal_test.dart \
//     --dart-define=RUN_LIVE_DB_REHEARSAL=true
//
// Restore Rehearsal Script
//
// Exercises the production BackupService and DatabaseService against the real
// ~/Documents/Ailyans/school_database.db.
//
// Steps:
//   0. sqfliteFfiInit + open live DB
//   1. Baseline row counts (Stu_Reg, VoucharMas, Teachers, app_config)
//   2. Export snapshot via VACUUM INTO
//   3. Validate candidate (validateCandidate)
//   4. DESTRUCTIVE restore (restoreFrom) -- overwrites live DB
//   5. Post-restore row counts (must match baseline)
//   6. PRAGMA quick_check on restored DB
//   7. Admin user check (Users WHERE UserLvl=1)
//   8. WAL/SHM hygiene (wal and shm files must be absent)
//   9. Safety backup existence (pre_restore_*.db must exist)
//  10. Write rehearsal log to rehearsal_log_<stamp>.txt
//
// Usage: dart run tool/restore_rehearsal.dart
//
// EXIT CODES:
//   0 -- all steps passed
//   1 -- setup / IO failure
//   2 -- baseline count mismatch (pre-condition failed)
//   3 -- export failed
//   4 -- validation failed
//   5 -- restore threw exception
//   6 -- post-restore count mismatch
//   7 -- quick_check failed
//   8 -- no admin user found
//   9 -- wal/shm hygiene failure
//  10 -- safety backup missing

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/core/db/backup_service.dart';
import '../lib/core/db/database.dart';

// ---------------------------------------------------------------------------
// Baseline constants -- update when production data changes materially.
// ---------------------------------------------------------------------------
const Map<String, Object> _baseline = {
  'Stu_Reg': 670,
  'VoucharMas': 2024,
  'Teachers': 24,
  'app_config_default_session_yr': '2026-27',
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a timestamp string suitable for filenames: yyyyMMdd_HHmmss.
String _stampSecond() {
  final now = DateTime.now();
  final parts = [
    now.year.toString().padLeft(4, '0'),
    now.month.toString().padLeft(2, '0'),
    now.day.toString().padLeft(2, '0'),
    '_',
    now.hour.toString().padLeft(2, '0'),
    now.minute.toString().padLeft(2, '0'),
    now.second.toString().padLeft(2, '0'),
  ];
  return parts.join();
}

final StringBuffer _log = StringBuffer();

void _emit(String line) {
  print(line);
  _log.writeln(line);
}

void _step(int n, String label) => _emit('\n--- Step $n: $label ---');

void _ok(String msg) => _emit('  OK  $msg');

Never _fail(String msg, int code) {
  _emit('  FAIL $msg');
  _emit('\nExit code: $code');
  exit(code);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main() async {
  _emit('=================================================');
  _emit(' Restore Rehearsal -- ${DateTime.now()}');
  _emit('=================================================');

  // -------------------------------------------------------------------------
  // Step 0: sqfliteFfiInit + open live DB
  // -------------------------------------------------------------------------
  _step(0, 'Init sqfliteFfi + open live DB');
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Database liveDb;
  try {
    liveDb = await DatabaseService.instance.database;
    _ok('Live DB opened');
  } catch (e) {
    _fail('Could not open live DB: $e', 1);
  }

  final livePath = await DatabaseService.instance.getDatabasePath();
  _ok('Path: $livePath');

  // -------------------------------------------------------------------------
  // Step 1: Baseline counts
  // -------------------------------------------------------------------------
  _step(1, 'Baseline row counts');

  Future<int> count(String sql) async {
    final rows = await liveDb.rawQuery(sql);
    return rows.first.values.first as int;
  }

  Future<String?> configVal(String key) async {
    final rows = await liveDb.rawQuery(
      "SELECT config_value FROM app_config WHERE config_key = ? LIMIT 1",
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['config_value'] as String?;
  }

  final stuReg = await count('SELECT COUNT(*) FROM Stu_Reg');
  final voucharMas = await count('SELECT COUNT(*) FROM VoucharMas');
  final teachers = await count('SELECT COUNT(*) FROM Teachers');
  final sessionYr = await configVal('default_session_yr');

  _emit('  Stu_Reg       : $stuReg  (expected ${_baseline['Stu_Reg']})');
  _emit('  VoucharMas    : $voucharMas  (expected ${_baseline['VoucharMas']})');
  _emit('  Teachers      : $teachers  (expected ${_baseline['Teachers']})');
  _emit(
    '  session_yr    : $sessionYr  (expected ${_baseline['app_config_default_session_yr']})',
  );

  if (stuReg != _baseline['Stu_Reg']) {
    _fail(
      'Stu_Reg baseline mismatch: got $stuReg expected ${_baseline['Stu_Reg']}',
      2,
    );
  }
  if (voucharMas != _baseline['VoucharMas']) {
    _fail(
      'VoucharMas baseline mismatch: got $voucharMas expected ${_baseline['VoucharMas']}',
      2,
    );
  }
  if (teachers != _baseline['Teachers']) {
    _fail(
      'Teachers baseline mismatch: got $teachers expected ${_baseline['Teachers']}',
      2,
    );
  }
  if (sessionYr != _baseline['app_config_default_session_yr']) {
    _fail(
      'session_yr baseline mismatch: got $sessionYr expected ${_baseline['app_config_default_session_yr']}',
      2,
    );
  }
  _ok('All baseline counts match');

  // -------------------------------------------------------------------------
  // Step 2: Export snapshot via VACUUM INTO
  // -------------------------------------------------------------------------
  _step(2, 'Export snapshot (VACUUM INTO)');

  final stamp = _stampSecond();
  final snapshotName = 'rehearsal_export_$stamp.db';
  File snapshotFile;
  try {
    snapshotFile = await BackupService.instance.exportSnapshot(
      suggestedName: snapshotName,
    );
    _ok('Snapshot created: ${snapshotFile.path}');
    _ok('Size: ${snapshotFile.lengthSync()} bytes');
  } catch (e) {
    _fail('exportSnapshot threw: $e', 3);
  }

  if (!snapshotFile.existsSync()) {
    _fail('Snapshot file does not exist after export', 3);
  }

  // -------------------------------------------------------------------------
  // Step 3: Validate candidate
  // -------------------------------------------------------------------------
  _step(3, 'Validate candidate backup');

  RestoreValidation validation;
  try {
    validation = await BackupService.instance.validateCandidate(
      snapshotFile.path,
    );
  } catch (e) {
    _fail('validateCandidate threw: $e', 4);
  }

  if (!validation.ok) {
    _fail('validateCandidate returned NOT OK: ${validation.failureReason}', 4);
  }
  _ok(
    'Validation passed  schema_version=${validation.sourceUserVersion}  admin_count=${validation.adminCount}',
  );

  // -------------------------------------------------------------------------
  // Step 4: DESTRUCTIVE restore
  // -------------------------------------------------------------------------
  _step(4, 'DESTRUCTIVE restore -- overwriting live DB');
  _emit('  *** This step closes and replaces $livePath ***');

  File safetyBackup;
  try {
    safetyBackup = await BackupService.instance.restoreFrom(snapshotFile.path);
    _ok('restoreFrom completed.  Safety backup: ${safetyBackup.path}');
  } catch (e) {
    _fail('restoreFrom threw: $e', 5);
  }

  // After restore, DatabaseService reopens lazily on next .database access.
  Database restoredDb;
  try {
    restoredDb = await DatabaseService.instance.database;
    _ok('DatabaseService reopened after restore');
  } catch (e) {
    _fail('Could not reopen DB after restore: $e', 5);
  }

  // -------------------------------------------------------------------------
  // Step 5: Post-restore counts -- must match baseline
  // -------------------------------------------------------------------------
  _step(5, 'Post-restore row counts');

  Future<int> count2(String sql) async {
    final rows = await restoredDb.rawQuery(sql);
    return rows.first.values.first as int;
  }

  Future<String?> configVal2(String key) async {
    final rows = await restoredDb.rawQuery(
      "SELECT config_value FROM app_config WHERE config_key = ? LIMIT 1",
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['config_value'] as String?;
  }

  final stuReg2 = await count2('SELECT COUNT(*) FROM Stu_Reg');
  final voucharMas2 = await count2('SELECT COUNT(*) FROM VoucharMas');
  final teachers2 = await count2('SELECT COUNT(*) FROM Teachers');
  final sessionYr2 = await configVal2('default_session_yr');

  _emit('  Stu_Reg       : $stuReg2  (expected $stuReg)');
  _emit('  VoucharMas    : $voucharMas2  (expected $voucharMas)');
  _emit('  Teachers      : $teachers2  (expected $teachers)');
  _emit('  session_yr    : $sessionYr2  (expected $sessionYr)');

  if (stuReg2 != stuReg) {
    _fail('Post-restore Stu_Reg mismatch: $stuReg2 != $stuReg', 6);
  }
  if (voucharMas2 != voucharMas) {
    _fail('Post-restore VoucharMas mismatch: $voucharMas2 != $voucharMas', 6);
  }
  if (teachers2 != teachers) {
    _fail('Post-restore Teachers mismatch: $teachers2 != $teachers', 6);
  }
  if (sessionYr2 != sessionYr) {
    _fail('Post-restore session_yr mismatch: $sessionYr2 != $sessionYr', 6);
  }
  _ok('All post-restore counts match baseline');

  // -------------------------------------------------------------------------
  // Step 6: PRAGMA quick_check
  // -------------------------------------------------------------------------
  _step(6, 'PRAGMA quick_check on restored DB');

  final chk = await restoredDb.rawQuery('PRAGMA quick_check');
  final chkResult =
      chk.isNotEmpty ? (chk.first.values.first as String?) : null;
  _emit('  quick_check result: $chkResult');
  if (chkResult != 'ok') {
    _fail('quick_check returned: $chkResult', 7);
  }
  _ok('quick_check = ok');

  // -------------------------------------------------------------------------
  // Step 7: Admin user check
  // -------------------------------------------------------------------------
  _step(7, 'Admin user check (UserLvl = 1)');

  final adminRows = await restoredDb.rawQuery(
    'SELECT COUNT(*) FROM Users WHERE UserLvl = 1',
  );
  final adminCount = adminRows.first.values.first as int;
  _emit('  Admin users found: $adminCount');
  if (adminCount < 1) {
    _fail('No admin users in restored DB', 8);
  }
  _ok('Admin user present');

  // -------------------------------------------------------------------------
  // Step 8: WAL/SHM hygiene
  // -------------------------------------------------------------------------
  _step(8, 'WAL/SHM hygiene');

  for (final suffix in ['-wal', '-shm']) {
    final f = File('$livePath$suffix');
    if (f.existsSync()) {
      _fail(
        'File ${f.path} exists after restore -- WAL/SHM not cleaned up',
        9,
      );
    }
    _ok('Not present: ${p.basename('$livePath$suffix')}');
  }

  // -------------------------------------------------------------------------
  // Step 9: Safety backup existence
  // -------------------------------------------------------------------------
  _step(9, 'Safety backup existence check');

  if (!safetyBackup.existsSync()) {
    _fail('Safety backup not found: ${safetyBackup.path}', 10);
  }
  _ok('Safety backup exists: ${safetyBackup.path}');
  _ok('Size: ${safetyBackup.lengthSync()} bytes');

  // -------------------------------------------------------------------------
  // Step 10: Write rehearsal log
  // -------------------------------------------------------------------------
  _step(10, 'Write rehearsal log');

  final logName = 'rehearsal_log_$stamp.txt';
  final logDir = Directory(p.join(p.dirname(livePath), 'backups'));
  await logDir.create(recursive: true);
  final logFile = File(p.join(logDir.path, logName));

  _emit('  Writing log to: ${logFile.path}');
  _log.writeln('\n=== END OF REHEARSAL LOG ===');
  logFile.writeAsStringSync(_log.toString());
  _ok('Log written: ${logFile.path}');

  _emit('\n=================================================');
  _emit(' ALL STEPS PASSED -- Exit code 0');
  _emit('=================================================');
  exit(0);
}
