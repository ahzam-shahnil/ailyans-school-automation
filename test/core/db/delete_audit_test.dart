// Phase K-6-c item 4 — `_delete_audit` (Migration 011) tests.
//
// T1. A v10-shaped fixture migrates to 11 and `_delete_audit` exists with
//     the EXACT locked columns (incl. NOT NULL flags).
// T2. A fresh chain (v0 → 11) creates `_delete_audit`; the runner is
//     idempotent on a second run (no duplicate table, version stays 11).
// T3. `_delete_audit` carries ZERO sync triggers (and none reference it);
//     kSyncedTables stays 28; audit insert+update produce ZERO outbox rows.
// T4. Audit state machine: 'confirmed' persists alone; the real handler's
//     success path deletes the student rows and marks 'success'; an
//     injected failure (dropped table) marks 'failed' with a non-empty
//     error and the record survives the transaction ROLLBACK.
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/delete_audit.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/student_profile_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const List<String> kExpectedAuditColumns = [
  'id',
  'stu_reg_id',
  'attempted_by',
  'status',
  'error',
  'created_at',
  'updated_at',
];

Future<Database> _openInMemory() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
  return db;
}

Future<int> _userVersion(Database db) async {
  final rows = await db.rawQuery('PRAGMA user_version');
  return rows.first.values.first as int;
}

Future<int> _outboxCount(Database db) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM _sync_outbox');
  return (rows.first['n'] as num).toInt();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Migration 011 — _delete_audit', () {
    test('T1. v10-shaped fixture → runner → user_version = 11 with the '
        'exact locked columns', () async {
      final db = await _openInMemory();
      addTearDown(db.close);

      // Simulated v10 install: F-1 shape (_sync_state with the
      // next_allocated_id column) + StuAdv (altered by migration 010).
      await db.execute('''
        CREATE TABLE _sync_state (
          table_name TEXT PRIMARY KEY,
          last_pulled_at TEXT,
          last_pushed_at TEXT,
          is_applying_remote INTEGER NOT NULL DEFAULT 0,
          node_block_start INTEGER,
          node_block_end INTEGER,
          next_allocated_id INTEGER
        )
      ''');
      await db.execute('CREATE TABLE StuAdv (StuAdvID INTEGER PRIMARY KEY)');
      await db.rawInsert(
        "INSERT INTO _sync_state (table_name, is_applying_remote) "
        "VALUES ('__global__', 0)",
      );
      await db.execute('PRAGMA user_version = 10');

      await SchemaMigrations.migrate(db);

      expect(await _userVersion(db), 11);

      final cols = await db.rawQuery("PRAGMA table_info('_delete_audit')");
      expect(
        cols.map((c) => c['name'] as String).toList(),
        kExpectedAuditColumns,
        reason: 'The audit table carries the exact locked column set',
      );
      // NOT NULL flags: stu_reg_id, status, created_at are NOT NULL;
      // attempted_by, error, updated_at (and the rowid alias id) nullable.
      final notNull = {
        for (final c in cols) c['name'] as String: c['notnull'] as int,
      };
      expect(notNull['stu_reg_id'], 1);
      expect(notNull['status'], 1);
      expect(notNull['created_at'], 1);
      expect(notNull['attempted_by'], 0);
      expect(notNull['error'], 0);
      expect(notNull['updated_at'], 0);
    });

    test('T2. fresh chain v0 → 11 creates _delete_audit; runner idempotent '
        'on second run', () async {
      final db = await _openInMemory();
      addTearDown(db.close);

      await SchemaMigrations.migrate(db);
      expect(await _userVersion(db), 11);

      final cols = await db.rawQuery("PRAGMA table_info('_delete_audit')");
      expect(
        cols.map((c) => c['name'] as String).toList(),
        kExpectedAuditColumns,
      );

      // Idempotent second run: version unchanged, no duplicate table.
      await SchemaMigrations.migrate(db);
      expect(await _userVersion(db), 11);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = '_delete_audit'",
      );
      expect(tables, hasLength(1));
    });

    test('T3. zero triggers on _delete_audit; kSyncedTables still 28; '
        'audit writes enqueue zero outbox rows', () async {
      expect(
        kSyncedTables.length,
        28,
        reason: 'The synced-table freeze must hold',
      );
      expect(kSyncedTables.contains('_delete_audit'), isFalse);

      final db = await _openInMemory();
      addTearDown(db.close);
      await SchemaMigrations.migrate(db);
      await DatabaseSeeder.seedIfEmpty(db);

      // No trigger exists whose target table is _delete_audit (either as
      // trg name fragment or as tbl_name).
      final trgByName = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' "
        "AND name LIKE '%delete_audit%'",
      );
      expect(trgByName, isEmpty);
      final trgByTarget = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' "
        "AND tbl_name = '_delete_audit'",
      );
      expect(trgByTarget, isEmpty);

      final before = await _outboxCount(db);
      final id = await recordDeleteConfirmed(db, stuRegId: 9999);
      await markDeleteSuccess(db, id);
      expect(await _outboxCount(db), before,
          reason: 'Audit writes are local-only — zero outbox rows');

      // Positive control: the audit row itself persisted.
      final audit = await db.query(
        '_delete_audit',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(audit.single['status'], 'success');
    });

    test('T4a. recordDeleteConfirmed alone persists a confirmed row', () async {
      final db = await _openInMemory();
      addTearDown(db.close);
      await SchemaMigrations.migrate(db);

      final id = await recordDeleteConfirmed(
        db,
        stuRegId: 4782,
        attemptedBy: 1,
      );
      final row = (await db.query(
        '_delete_audit',
        where: 'id = ?',
        whereArgs: [id],
      )).single;

      expect(row['stu_reg_id'], 4782);
      expect(row['attempted_by'], 1);
      expect(row['status'], 'confirmed');
      expect(row['error'], isNull);
      expect(row['updated_at'], isNull);
      // created_at mirrors the _sync_outbox trigger format
      // (YYYY-MM-DDTHH:MM:SS.mmmZ).
      expect(
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$')
            .hasMatch(row['created_at'] as String),
        isTrue,
        reason: "created_at must match strftime('%Y-%m-%dT%H:%M:%fZ','now')",
      );
    });

    test('T4b. full success path: handler deletes student rows and marks '
        'success', () async {
      final db = await _openInMemory();
      addTearDown(db.close);
      await SchemaMigrations.migrate(db);
      await DatabaseSeeder.seedIfEmpty(db);
      DatabaseService.instance.setDatabase(db);
      addTearDown(() => DatabaseService.instance.setDatabase(null));

      // Seed a disposable student in the seeded session (4411 shape,
      // ClassID 13, SessionYr '2017-2018').
      await db.insert('Stu_Reg', {
        'Stu_RegID': 9001,
        'NameFirst': 'Throwaway',
        'NameLast': 'Student',
        'DOB': '2002-04-12',
        'F_Name': 'Test Father',
        'CNIC_No': '38302-9999999-9',
        'Sex': 'Male',
        'Mobile1': '03009999999',
        'AdmClass': 13,
        'DOAdmission': '2024-08-15',
        'FullDiscount': 0,
      });
      await db.insert('Student_Class', {
        'Stu_RegID': 9001,
        'ClassID': 13,
        'ClassSecID': 25,
        'ClassRollNo': 99,
        'SessionYr': '2017-2018',
        'Present': 1,
        'VGen': 'Y',
      });

      final attemptId = await recordDeleteConfirmed(
        db,
        stuRegId: 9001,
        attemptedBy: 1,
      );
      await permanentlyDeleteStudent(9001, auditAttemptId: attemptId);

      expect(
        (await db.query(
          'Stu_Reg',
          where: 'Stu_RegID = ?',
          whereArgs: [9001],
        )),
        isEmpty,
      );
      expect(
        (await db.query(
          'Student_Class',
          where: 'Stu_RegID = ?',
          whereArgs: [9001],
        )),
        isEmpty,
      );

      final row = (await db.query(
        '_delete_audit',
        where: 'id = ?',
        whereArgs: [attemptId],
      )).single;
      expect(row['status'], 'success');
      expect(row['error'], isNull);
      expect(row['updated_at'], isNotNull);
    });

    test('T4c. failure path: injected fault marks failed with non-empty '
        'error and the record survives the ROLLBACK', () async {
      final db = await _openInMemory();
      addTearDown(db.close);
      await SchemaMigrations.migrate(db);
      await DatabaseSeeder.seedIfEmpty(db);
      DatabaseService.instance.setDatabase(db);
      addTearDown(() => DatabaseService.instance.setDatabase(null));

      await db.insert('Stu_Reg', {
        'Stu_RegID': 9002,
        'NameFirst': 'Faulty',
        'NameLast': 'Student',
        'DOB': '2002-04-12',
        'F_Name': 'Test Father',
        'CNIC_No': '38302-9999999-8',
        'Sex': 'Male',
        'Mobile1': '03009999998',
        'AdmClass': 13,
        'DOAdmission': '2024-08-15',
        'FullDiscount': 0,
      });

      // Reachable fault point: remove a table the handler's DELETE
      // sequence touches — no handler refactor needed for injection.
      await db.execute('DROP TABLE AttDet');

      final attemptId = await recordDeleteConfirmed(db, stuRegId: 9002);
      await expectLater(
        permanentlyDeleteStudent(9002, auditAttemptId: attemptId),
        throwsException,
        reason: 'The handler must preserve its error propagation',
      );

      final row = (await db.query(
        '_delete_audit',
        where: 'id = ?',
        whereArgs: [attemptId],
      )).single;
      expect(row['status'], 'failed');
      expect((row['error'] as String).isNotEmpty, isTrue);
      expect(row['updated_at'], isNotNull);

      // The delete transaction rolled back: Stu_Reg row survives.
      expect(
        (await db.query(
          'Stu_Reg',
          where: 'Stu_RegID = ?',
          whereArgs: [9002],
        )),
        hasLength(1),
      );

      // Restore the dropped table so tearDown (db.close) is unaffected
      // and outbox trigger installation is not re-run against a broken
      // schema by anything else in this test process.
      await db.execute('''
        CREATE TABLE AttDet (
          AttDetID INTEGER PRIMARY KEY,
          AttMasID INTEGER,
          Stu_RegID INTEGER,
          Status TEXT
        )
      ''');
    });

    test('T4d. direct handler invocation (null auditAttemptId) self-records '
        'a confirmed row and completes as success', () async {
      final db = await _openInMemory();
      addTearDown(db.close);
      await SchemaMigrations.migrate(db);
      await DatabaseSeeder.seedIfEmpty(db);
      DatabaseService.instance.setDatabase(db);
      addTearDown(() => DatabaseService.instance.setDatabase(null));

      await db.insert('Stu_Reg', {
        'Stu_RegID': 9003,
        'NameFirst': 'Direct',
        'NameLast': 'Caller',
        'DOB': '2002-04-12',
        'F_Name': 'Test Father',
        'CNIC_No': '38302-9999999-7',
        'Sex': 'Male',
        'Mobile1': '03009999997',
        'AdmClass': 13,
        'DOAdmission': '2024-08-15',
        'FullDiscount': 0,
      });

      await permanentlyDeleteStudent(9003);

      expect(
        (await db.query(
          'Stu_Reg',
          where: 'Stu_RegID = ?',
          whereArgs: [9003],
        )),
        isEmpty,
      );
      final rows = await db.query(
        '_delete_audit',
        where: 'stu_reg_id = ?',
        whereArgs: [9003],
      );
      expect(rows, hasLength(1));
      expect(rows.single['status'], 'success');
      expect(rows.single['attempted_by'], isNull);
    });
  });
}
