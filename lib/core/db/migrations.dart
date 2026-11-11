import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Operational tables whose row changes are captured into `_sync_outbox`.
///
/// Single source of truth for Phase F-1 trigger creation and the trigger
/// inventory test.
const List<String> kSyncedTables = <String>[
  // G-10 Shot 12a: master/reference tables — pushed first so transactional
  // children land after their parents.
  'Users',
  'Class',
  'ClassSec',
  'Subject',
  'Subj_Class',
  'FeeParameters',
  'Cls_Param_Fee',
  'BankInfo',
  'ExamTerm',
  'Stu_Reg',
  'Student_Class',
  'Sibling_Links',
  'VoucharMas',
  'VoucharDet',
  'FeeTransaction',
  'StuAdv',
  'AttMas',
  'AttDet',
  'TAtt',
  'Teachers',
  'TSalMas',
  'TSalDet',
  'ExamInfo',
  'ExamMas',
  'ExamDet',
  'SchLeaving',
  'Books',
  'app_config',
];

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

    // Ensure app_config table exists for device-local preferences
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_config (
        config_key TEXT PRIMARY KEY,
        config_value TEXT
      );
    ''');

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

    // Migration 007: Seed baseline library catalog (5 books across Subjects 1..5)
    if (currentVersion < 7) {
      await applyMigration007(db);
      await db.execute('PRAGMA user_version = 7');
      currentVersion = 7;
    }

    // Migration 008: Sibling Links table (canonical pair, CHECK constraint)
    if (currentVersion < 8) {
      await applyMigration008(db);
      await db.execute('PRAGMA user_version = 8');
      currentVersion = 8;
    }

    // Migration 009: Cloud sync outbox, state, and re-entrancy guarded triggers
    if (currentVersion < 9) {
      await applyMigration009(db);
      await db.execute('PRAGMA user_version = 9');
      currentVersion = 9;
    }

    // Migration 010 (Phase F-3c-1): StuAdv.VoucherMasID for advance-deduction
    // reconciliation. Deduction rows (AdvAmount < 0) link to the voucher they
    // paid. Fixes LedgerReconciler under-reporting PaidAmt by advanceApplied.
    if (currentVersion < 10) {
      await applyMigration010(db);
      await db.execute('PRAGMA user_version = 10');
      currentVersion = 10;
    }

    // Phase F-3a: converge _sync_state on every boot, including existing v9
    // databases that predate next_allocated_id. user_version stays at its
    // current value; F-3c-1 bumps it to 10 above.
    await ensureSyncStateColumns(db);

    // G-10 Shot 12a: install sync capture triggers on every boot (not only
    // inside the version-gated migration 009), so existing v10 databases
    // gain the triggers for newly registered sync tables (master tables).
    // Idempotent via CREATE TRIGGER IF NOT EXISTS.
    await ensureSyncTriggers(db);
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

  /// Migration 007: Seeds baseline library catalog (5 books across Subjects 1..5).
  static Future<void> applyMigration007(Database db) async {
    final books = [
      // BookID, BookCatSubj, BookName, BAuthor, Pages, PulishedBy, PublishedYr, BookPrice, Detail
      [
        1,
        1,
        'Islamiat Lazmi Grade 9',
        'Maulana Muhammad Yousuf',
        220,
        'Punjab Textbook Board',
        2017,
        250,
        'Compulsory religious studies - Grade 9 edition',
      ],
      [
        2,
        2,
        'Mathematics for Class 9',
        'Prof. Muhammad Ashraf',
        380,
        'Punjab Textbook Board',
        2017,
        320,
        'Algebra and Geometry - Grade 9',
      ],
      [
        3,
        3,
        'Urdu Lazmi Grade 9',
        'Dr. Waheed-uz-Zaman Tariq',
        300,
        'Punjab Textbook Board',
        2017,
        280,
        'National language - Grade 9',
      ],
      [
        4,
        4,
        'English Grammar & Composition',
        'Wren & Martin',
        480,
        'S. Chand & Company',
        2015,
        550,
        'Reference grammar for secondary classes',
      ],
      [
        5,
        5,
        'Computer Science Grade 9',
        'M. Sohail Afzal',
        260,
        'Punjab Textbook Board',
        2017,
        350,
        'Theory + Practical - Grade 9',
      ],
    ];
    for (final b in books) {
      await db.rawInsert(
        'INSERT INTO Books (BookID, BookCatSubj, BookName, BAuthor, Pages, PulishedBy, PublishedYr, BookPrice, Detail) '
        'SELECT ?, ?, ?, ?, ?, ?, ?, ?, ? '
        'WHERE NOT EXISTS (SELECT 1 FROM Books WHERE BookID = ?)',
        [b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[0]],
      );
    }
  }

  /// Migration 008: Creates Sibling_Links table for peer/sibling mapping.
  /// Schema-only (no initial seed data).
  static Future<void> applyMigration008(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Sibling_Links (
        LinkID      INTEGER PRIMARY KEY,
        Stu1_RegID  INTEGER NOT NULL,
        Stu2_RegID  INTEGER NOT NULL,
        Relation    TEXT,
        LinkedBy    TEXT,
        LinkedOn    TEXT,
        UNIQUE(Stu1_RegID, Stu2_RegID),
        CHECK(Stu1_RegID < Stu2_RegID)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sibling_stu1 ON Sibling_Links(Stu1_RegID)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sibling_stu2 ON Sibling_Links(Stu2_RegID)',
    );
  }

  /// Exact primary-key column(s) used to build `record_pk` for each synced
  /// table. Composite keys are serialized with JSON, never hyphen-delimited.
  static const Map<String, List<String>> _syncPkColumns =
      <String, List<String>>{
        // G-10 Shot 12a: master/reference tables.
        'Users': <String>['ID'],
        'Class': <String>['ClassID'],
        'ClassSec': <String>['ClassSecID'],
        'Subject': <String>['SubjID'],
        'Subj_Class': <String>['SubjID', 'ClassID'],
        'FeeParameters': <String>['FeeParamID'],
        'Cls_Param_Fee': <String>['ClassID', 'FeeParamID', 'FeeYr'],
        'BankInfo': <String>['BankInfoID'],
        'ExamTerm': <String>['ExTermID'],
        'Stu_Reg': <String>['Stu_RegID'],
        'Student_Class': <String>['Stu_RegID', 'ClassID', 'SessionYr'],
        'Sibling_Links': <String>['LinkID'],
        'VoucharMas': <String>['VoucherMasID'],
        'VoucharDet': <String>['VoucharDetID', 'VoucharMasID', 'feeParameterID'],
        'FeeTransaction': <String>['FeeTransID'],
        'StuAdv': <String>['StuAdvID'],
        'AttMas': <String>['ClassID', 'ClassSecID', 'AttDate'],
        'AttDet': <String>['AttMasID', 'Stu_RegID'],
        'TAtt': <String>['TeacherID', 'AttDate'],
        'Teachers': <String>['TeacherID'],
        'TSalMas': <String>['TeacherID', 'SalMonth'],
        'TSalDet': <String>['TSalMasID', 'Detail'],
        'ExamInfo': <String>['ExTermID', 'SessionYR'],
        'ExamMas': <String>['ExamInfoID', 'Stu_RegID'],
        'ExamDet': <String>['ExamMasID', 'SubjID'],
        'SchLeaving': <String>['StuRegID'],
        'Books': <String>['BookID'],
        'app_config': <String>['config_key'],
      };

  /// Public record_pk expression builder — the exact same function the
  /// capture-trigger DDL uses (via [_syncPkExpression]), exposed so
  /// `SyncService.enqueueInitialMasterTablesIfNeeded` can SELECT record_pk
  /// values from existing rows without re-deriving the serialization
  /// (G-10 Shot 12a).
  static String buildRecordPkExpr(String table, String rowAlias) =>
      _syncPkExpression(table, rowAlias);

  /// Builds the `record_pk` SQL expression for [table] using [rowAlias].
  static String _syncPkExpression(String table, String rowAlias) {
    final columns = _syncPkColumns[table];
    if (columns == null || columns.isEmpty) {
      throw StateError('No sync primary key registered for table $table');
    }
    if (columns.length == 1) {
      return 'CAST($rowAlias.${columns.single} AS TEXT)';
    }
    final args = columns
        .map((column) => "'$column', $rowAlias.$column")
        .join(', ');
    return 'json_object($args)';
  }

  /// Builds one `trg_sync_<table>_<suffix>` capture trigger statement.
  static String _syncTriggerSql({
    required String table,
    required String suffix,
    required String event,
    required String pkExpression,
    required String operation,
  }) {
    return '''
      CREATE TRIGGER IF NOT EXISTS trg_sync_${table}_$suffix
      AFTER $event ON $table
      WHEN COALESCE((SELECT is_applying_remote FROM _sync_state WHERE table_name = '__global__' LIMIT 1), 0) = 0
      BEGIN
        INSERT INTO _sync_outbox (table_name, record_pk, operation, payload_json, created_at)
        VALUES ('$table', $pkExpression, '$operation', NULL, strftime('%Y-%m-%dT%H:%M:%fZ','now'));
      END
    ''';
  }

  /// Migration 009: Creates the cloud-sync outbox/state tables and installs
  /// AFTER INSERT/UPDATE/DELETE capture triggers for every [kSyncedTables]
  /// table. All DDL is idempotent so a partially applied migration can retry.
  static Future<void> applyMigration009(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS _sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_pk TEXT NOT NULL,
        operation TEXT NOT NULL CHECK (operation IN ('UPSERT', 'DELETE')),
        payload_json TEXT,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_created ON _sync_outbox(created_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS _sync_state (
        table_name TEXT PRIMARY KEY,
        last_pulled_at TEXT,
        last_pushed_at TEXT,
        is_applying_remote INTEGER NOT NULL DEFAULT 0,
        node_block_start INTEGER,
        node_block_end INTEGER
      )
    ''');
    // Phase F-3a: add next_allocated_id before the seed INSERT references it.
    await ensureSyncStateColumns(db);
    await db.rawInsert(
      "INSERT OR IGNORE INTO _sync_state (table_name, is_applying_remote) "
      "VALUES ('__global__', 0)",
    );
    await db.rawInsert(
      'INSERT OR IGNORE INTO _sync_state '
      '(table_name, is_applying_remote, node_block_start, node_block_end, '
      'next_allocated_id) '
      "VALUES ('__node__', 0, 100000, 199999, 100000)",
    );

    await ensureSyncTriggers(db);
  }

  /// G-10 Shot 12a: idempotently installs the `trg_sync_<table>_<ai/au/ad>`
  /// capture triggers for every [kSyncedTables] table. Extracted from
  /// [applyMigration009] and additionally invoked from [migrate] on EVERY
  /// boot, so existing v10 databases (which skip the version-gated migration)
  /// gain the capture triggers for newly registered tables (e.g. the 9
  /// master tables). `CREATE TRIGGER IF NOT EXISTS` makes re-runs a no-op.
  ///
  /// Deliberately triggers-only: per-table `_sync_state` rows are managed by
  /// the push/pull watermarks (`pushOutbox` upserts last_pushed_at), NOT
  /// seeded here — the migration tests assert `_sync_state` holds exactly
  /// `__global__` and `__node__` after migration.
  static Future<void> ensureSyncTriggers(Database db) async {
    // G-10 Shot 12a: skip tables that do not exist in this database (partial
    // migration-test fixtures can legitimately contain only _sync_state and
    // one or two tables). CREATE TRIGGER on a missing table would abort
    // migrate() with "no such table". Real installs always carry all 28
    // tables, so every trigger is installed there.
    final existing = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final existingNames = existing.map((r) => r['name'] as String).toSet();

    for (final table in kSyncedTables) {
      if (!existingNames.contains(table)) continue;
      await db.execute(
        _syncTriggerSql(
          table: table,
          suffix: 'ai',
          event: 'INSERT',
          pkExpression: _syncPkExpression(table, 'NEW'),
          operation: 'UPSERT',
        ),
      );
      await db.execute(
        _syncTriggerSql(
          table: table,
          suffix: 'au',
          event: 'UPDATE',
          pkExpression: _syncPkExpression(table, 'NEW'),
          operation: 'UPSERT',
        ),
      );
      await db.execute(
        _syncTriggerSql(
          table: table,
          suffix: 'ad',
          event: 'DELETE',
          pkExpression: _syncPkExpression(table, 'OLD'),
          operation: 'DELETE',
        ),
      );
    }
  }

  /// Phase F-3a: idempotently ensures `_sync_state.next_allocated_id` exists
  /// and converges the legacy `__node__` block (10000..19999) to
  /// 100000..199999. Called from applyMigration009 before its seed INSERTs and
  /// from migrate() on every boot, so existing v9 databases converge without a
  /// version bump.
  static Future<void> ensureSyncStateColumns(Database db) async {
    // Step 1: add next_allocated_id column if absent (idempotent).
    final cols = await db.rawQuery("PRAGMA table_info('_sync_state')");
    if (!cols.any((c) => c['name'] == 'next_allocated_id')) {
      await db.execute(
        'ALTER TABLE _sync_state ADD COLUMN next_allocated_id INTEGER',
      );
    }

    // Step 2: converge the __node__ row for existing F-1 DBs whose block is
    // still 10000..19999. WHERE node_block_start < 100000 makes this a no-op
    // on any DB already at 100000..199999.
    await db.rawUpdate(
      "UPDATE _sync_state SET "
      "  node_block_start = 100000, "
      "  node_block_end = 199999, "
      "  next_allocated_id = COALESCE(next_allocated_id, 100000) "
      "WHERE table_name = '__node__' "
      "  AND (node_block_start IS NULL OR node_block_start < 100000)",
    );

    // Step 3: seed next_allocated_id for a fresh DB where the __node__ row
    // exists but next_allocated_id is still NULL (happens when
    // applyMigration009's seed INSERT ran before this helper on first install).
    await db.rawUpdate(
      "UPDATE _sync_state SET next_allocated_id = COALESCE(node_block_start, 100000) "
      "WHERE table_name = '__node__' AND next_allocated_id IS NULL",
    );
  }

  /// Migration 010 (Phase F-3c-1): Adds `StuAdv.VoucherMasID` so negative
  /// advance-deduction rows can be linked back to the voucher they paid.
  /// Nullable TEXT; positive advance deposits remain NULL until consumed.
  static Future<void> applyMigration010(Database db) async {
    // Idempotent column guard (live DB and fresh install both converge).
    final cols = await db.rawQuery("PRAGMA table_info('StuAdv')");
    if (!cols.any((c) => c['name'] == 'VoucherMasID')) {
      await db.execute('ALTER TABLE StuAdv ADD COLUMN VoucherMasID TEXT');
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stuadv_voucher ON StuAdv(VoucherMasID)',
    );
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
