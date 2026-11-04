import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Inserts a minimal valid Stu_Reg row (NameFirst and FullDiscount are NOT NULL).
Future<void> insertStudent(Database db, int id, String name) async {
  await db.insert('Stu_Reg', <String, Object?>{
    'Stu_RegID': id,
    'NameFirst': name,
    'FullDiscount': 0,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    await SchemaMigrations.migrate(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'Migrations 009+010 set PRAGMA user_version = 10 and seed _sync_state '
    '(__global__ and __node__)',
    () async {
      final versionRows = await db.rawQuery('PRAGMA user_version');
      expect(versionRows.first.values.first, 10);

      final stateRows = await db.query('_sync_state');
      expect(stateRows.length, 2);

      final global = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['__global__'],
      );
      expect(global.length, 1);
      expect(global.single['is_applying_remote'], 0);

      final node = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['__node__'],
      );
      expect(node.length, 1);
      expect(node.single['is_applying_remote'], 0);
      expect(node.single['node_block_start'], 100000);
      expect(node.single['node_block_end'], 199999);
    },
  );

  test(
    'INSERT into Stu_Reg enqueues exactly 1 UPSERT row with '
    'record_pk = Stu_RegID',
    () async {
      await insertStudent(db, 9001, 'Trigger Insert');

      final rows = await db.query('_sync_outbox');
      expect(rows.length, 1);
      expect(rows.single['table_name'], 'Stu_Reg');
      expect(rows.single['operation'], 'UPSERT');
      expect(rows.single['record_pk'], '9001');
      expect(rows.single['payload_json'], isNull);
    },
  );

  test('UPDATE on Stu_Reg enqueues a second UPSERT row', () async {
    await insertStudent(db, 9001, 'Trigger Insert');
    await db.update(
      'Stu_Reg',
      <String, Object?>{'NameFirst': 'Trigger Updated'},
      where: 'Stu_RegID = ?',
      whereArgs: [9001],
    );

    final rows = await db.query('_sync_outbox', orderBy: 'id');
    expect(rows.length, 2);
    expect(rows.map((row) => row['operation']), everyElement('UPSERT'));
    expect(rows.last['record_pk'], '9001');
  });

  test('DELETE on Stu_Reg enqueues a DELETE row', () async {
    await insertStudent(db, 9001, 'Trigger Insert');
    await db.update(
      'Stu_Reg',
      <String, Object?>{'NameFirst': 'Trigger Updated'},
      where: 'Stu_RegID = ?',
      whereArgs: [9001],
    );
    await db.delete('Stu_Reg', where: 'Stu_RegID = ?', whereArgs: [9001]);

    final rows = await db.query('_sync_outbox', orderBy: 'id');
    expect(rows.length, 3);
    expect(rows.last['operation'], 'DELETE');
    expect(rows.last['record_pk'], '9001');
  });

  test(
    'Composite-key table (AttMas) INSERT/DELETE captures unambiguous record_pk',
    () async {
      await db.insert('AttMas', <String, Object?>{
        'AttMasID': 7001,
        'ClassID': 13,
        'ClassSecID': 1,
        'AttDate': '2026-11-03',
        'StudySessionYr': '2017-2018',
      });

      final afterInsert = await db.query('_sync_outbox', orderBy: 'id');
      expect(afterInsert.length, 1);
      final insertedPk =
          jsonDecode(afterInsert.single['record_pk'] as String)
              as Map<String, dynamic>;
      expect(insertedPk, <String, dynamic>{
        'ClassID': 13,
        'ClassSecID': 1,
        'AttDate': '2026-11-03',
      });

      await db.delete(
        'AttMas',
        where: 'ClassID = ? AND ClassSecID = ? AND AttDate = ?',
        whereArgs: [13, 1, '2026-11-03'],
      );

      final afterDelete = await db.query('_sync_outbox', orderBy: 'id');
      expect(afterDelete.length, 2);
      expect(afterDelete.last['operation'], 'DELETE');
      final deletedPk =
          jsonDecode(afterDelete.last['record_pk'] as String)
              as Map<String, dynamic>;
      expect(deletedPk, insertedPk);
    },
  );

  test(
    'Re-entrancy guard: is_applying_remote = 1 suppresses trigger enqueue; '
    'resetting to 0 resumes capture',
    () async {
      await db.update(
        '_sync_state',
        <String, Object?>{'is_applying_remote': 1},
        where: 'table_name = ?',
        whereArgs: ['__global__'],
      );

      await insertStudent(db, 9101, 'Guarded Insert');
      expect((await db.query('_sync_outbox')).length, 0);

      await db.update(
        '_sync_state',
        <String, Object?>{'is_applying_remote': 0},
        where: 'table_name = ?',
        whereArgs: ['__global__'],
      );

      await insertStudent(db, 9102, 'Resumed Insert');
      final rows = await db.query('_sync_outbox');
      expect(rows.length, 1);
      expect(rows.single['record_pk'], '9102');
      expect(rows.single['operation'], 'UPSERT');
    },
  );

  test('Trigger inventory matches kSyncedTables.length * 3', () async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM sqlite_master "
      "WHERE type = 'trigger' AND name LIKE 'trg_sync_%'",
    );
    final triggerCount = result.first['cnt'] as int;
    expect(triggerCount, kSyncedTables.length * 3);
  });
}
