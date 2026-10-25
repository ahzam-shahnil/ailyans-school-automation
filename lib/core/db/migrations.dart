import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Database schema migration runner.
/// Loads base DDL on first launch and executes incremental version upgrades.
class SchemaMigrations {
  /// Runs pending migrations up to the latest target schema version.
  static Future<void> migrate(Database db) async {
    final versionResult = await db.rawQuery('PRAGMA user_version');
    int currentVersion = 0;
    if (versionResult.isNotEmpty && versionResult.first.values.isNotEmpty) {
      currentVersion = (versionResult.first.values.first as int?) ?? 0;
    }

    // Initial schema load (user_version 0 -> 1)
    if (currentVersion == 0) {
      await loadInitialSchema(db);
      await db.execute('PRAGMA user_version = 1');
      currentVersion = 1;
    }

    // Migration 002 (M1: Add Users.IsActive column for Phase 2 user management)
    if (currentVersion < 2) {
      await applyMigration002(db);
      await db.execute('PRAGMA user_version = 2');
      currentVersion = 2;
    }

    // Migration 003: Purge corrupted October 2017 vouchers produced by the
    // arrears double-counting bug (SubTotals ~47,800–48,700 instead of ~1,920).
    // Also reverts any prior-month 'O' status set by the buggy run to 'N'.
    if (currentVersion < 3) {
      await db.rawDelete('''
        DELETE FROM VoucharDet WHERE VoucharMasID IN (
          SELECT VoucherMasID FROM VoucharMas
          WHERE ForMonth = 'October 2017' AND SubTotal > 5000
        )
      ''');
      await db.rawDelete('''
        DELETE FROM VoucharMas
        WHERE ForMonth = 'October 2017' AND SubTotal > 5000
      ''');
      // Restore any prior-month rows incorrectly marked 'O' by the buggy run.
      await db.rawUpdate('''
        UPDATE VoucharMas SET IsPaid='N'
        WHERE IsPaid='O' AND ForMonth != 'October 2017'
      ''');
      await db.execute('PRAGMA user_version = 3');
      currentVersion = 3;
    }

    // Migration 004: Ensure VoucharMas has PaidAmt, PaidDate, BankID columns
    // for payment settlement tracking.
    if (currentVersion < 4) {
      await applyMigration004(db);
      await db.execute('PRAGMA user_version = 4');
      currentVersion = 4;
    }

    // Migration 005: Dev-only cleanup: purge test vouchers and reset to clean state.
    if (currentVersion < 5) {
      await applyMigration005(db);
      await db.execute('PRAGMA user_version = 5');
      currentVersion = 5;
    }

    // Migration 006: Seed exam baseline data (ExamTerm, ExamInfo, Subject, Subj_Class, ExGrade)
    if (currentVersion < 6) {
      await applyMigration006(db);
      await db.execute('PRAGMA user_version = 6');
      currentVersion = 6;
    }

    // Ensure app_config table exists for device-local preferences
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_config (
        config_key TEXT PRIMARY KEY,
        config_value TEXT
      );
    ''');
  }

  /// Loads and executes the initial schema from assets/reference/schema.sql.
  static Future<void> loadInitialSchema(Database db) async {
    final sqlScript = await rootBundle.loadString(
      'assets/reference/schema.sql',
    );
    await executeSqlScript(db, sqlScript);
  }

  /// Migration M1: Adds `Users.IsActive` column and index.
  /// Legacy VB6 had no active/inactive flag; Phase 2 introduces IsActive.
  static Future<void> applyMigration002(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(Users)');
    final hasIsActive = tableInfo.any((col) => col['name'] == 'IsActive');
    if (!hasIsActive) {
      await db.execute(
        'ALTER TABLE Users ADD COLUMN IsActive INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_active ON Users(IsActive) WHERE IsActive = 1',
      );
    }
  }

  /// Migration M4: Adds `PaidAmt`, `PaidDate`, and `BankID` to `VoucharMas`.
  static Future<void> applyMigration004(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(VoucharMas)');
    final cols = tableInfo.map((col) => col['name'] as String).toSet();
    if (!cols.contains('PaidAmt')) {
      await db.execute(
        'ALTER TABLE VoucharMas ADD COLUMN PaidAmt INTEGER DEFAULT 0',
      );
    }
    if (!cols.contains('PaidDate')) {
      await db.execute('ALTER TABLE VoucharMas ADD COLUMN PaidDate TEXT');
    }
    if (!cols.contains('BankID')) {
      await db.execute('ALTER TABLE VoucharMas ADD COLUMN BankID INTEGER');
    }
  }

  /// Migration 005: Purges all test voucher data (VoucharDet, VoucharMas, FeeTransaction).
  /// Leaves students, classes, tariffs, attendance, banks, and users intact.
  static Future<void> applyMigration005(Database db) async {
    await db.delete('VoucharDet');
    await db.delete('VoucharMas');
    await db.delete('FeeTransaction');
  }

  /// Migration 006: Seed exam baseline (ExamTerm, ExamInfo, Subject, Subj_Class, ExGrade).
  /// Fully idempotent via WHERE NOT EXISTS guards.
  static Future<void> applyMigration006(Database db) async {
    // 3 ExamTerms
    for (final row in [
      [1, '1st Term', '-'],
      [2, '2nd Term', '-'],
      [3, 'Final Term', '-'],
    ]) {
      await db.rawInsert(
        'INSERT INTO ExamTerm (ExTermID, TermName, TermRemarks) '
        'SELECT ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM ExamTerm WHERE ExTermID = ?)',
        [row[0], row[1], row[2], row[0]],
      );
    }

    // 1 ExamInfo
    await db.rawInsert(
      'INSERT INTO ExamInfo (ExamInfoID, ExTermID, SessionYR, StartDate, EndDate, ResultDate, ExamSupervisorID, Location, Detail) '
      "SELECT 1, 1, '2017-2018', '2017-09-01', '2017-09-15', '2017-09-30', 1, 'Main Hall', '1st Term Examination 2017' "
      'WHERE NOT EXISTS (SELECT 1 FROM ExamInfo WHERE ExamInfoID = 1 AND ExTermID = 1)',
    );

    // 5 Subjects
    final subjects = [
      [1, 'Islamiat', 'Compulsory religious studies'],
      [2, 'Maths', 'Mathematics syllabus'],
      [3, 'Urdu', 'National language'],
      [4, 'English', 'Compulsory English'],
      [5, 'Computer Science', 'Theory + Practical lab'],
    ];
    for (final row in subjects) {
      await db.rawInsert(
        'INSERT INTO Subject (SubjID, SubjName, SubjDetail) '
        'SELECT ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM Subject WHERE SubjID = ?)',
        [row[0], row[1], row[2], row[0]],
      );
    }

    // 5 Subj_Class mappings (all to Class 13)
    final subjClasses = [
      [1, 1, 13, 1, 100, 0],
      [2, 2, 13, 1, 100, 0],
      [3, 3, 13, 1, 100, 0],
      [4, 4, 13, 1, 100, 0],
      [5, 5, 13, 1, 75, 25], // Computer Science: 75 theory + 25 practical
    ];
    for (final row in subjClasses) {
      await db.rawInsert(
        'INSERT INTO Subj_Class (Subj_ClsID, SubjID, ClassID, TeacherID, TotalMarks, TotalPracticalMarks) '
        'SELECT ?, ?, ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM Subj_Class WHERE SubjID = ? AND ClassID = ?)',
        [row[0], row[1], row[2], row[3], row[4], row[5], row[1], row[2]],
      );
    }

    // 5 ExGrade rows for Class 13 (verified thresholds, 5 grades)
    final grades = [
      [1, 13, 'A', 90, 100, 'Outstanding'],
      [2, 13, 'B', 80, 89, 'Vgood'],
      [3, 13, 'C', 70, 79, 'good'],
      [4, 13, 'D', 60, 69, 'Fair'],
      [5, 13, 'F', 0, 59, 'Fail'],
    ];
    for (final row in grades) {
      await db.rawInsert(
        'INSERT INTO ExGrade (ExGradID, CalssID, Grad, GradMinMarks, GradMaxMarks, Remarks) '
        'SELECT ?, ?, ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM ExGrade WHERE ExGradID = ?)',
        [row[0], row[1], row[2], row[3], row[4], row[5], row[0]],
      );
    }
  }

  /// Executes a multi-statement SQL script using a transactional batch.
  static Future<void> executeSqlScript(Database db, String script) async {
    final batch = db.batch();
    final lines = script.split('\n');
    final statementBuffer = StringBuffer();

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('--') || line.isEmpty) {
        continue;
      }
      statementBuffer.writeln(rawLine);
      if (line.endsWith(';')) {
        final statement = statementBuffer.toString().trim();
        if (statement.isNotEmpty) {
          batch.execute(statement);
        }
        statementBuffer.clear();
      }
    }

    final remaining = statementBuffer.toString().trim();
    if (remaining.isNotEmpty) {
      batch.execute(remaining);
    }

    await batch.commit(noResult: true);
  }
}
