import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/sync/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    await SchemaMigrations.migrate(db);
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    DatabaseService.instance.setDatabase(null);
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Test 1 — empty outbox
  // ---------------------------------------------------------------------------
  test(
    'Empty outbox returns pushedCount=0 and makes no adapter calls',
    () async {
      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(
        adapter: adapter,
        openDb: () async => db,
      );

      final result = await svc.pushOutbox();

      expect(result.pushedCount, 0);
      expect(result.failedCount, 0);
      expect(adapter.upserts, isEmpty);
      expect(adapter.deletes, isEmpty);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 2 — single UPSERT, watermarks set
  // ---------------------------------------------------------------------------
  test(
    'Single UPSERT on app_config.last_username drains outbox, calls adapter '
    'once, and sets last_pushed_at on app_config and __global__',
    () async {
      await db.insert('app_config', {
        'config_key': 'last_username',
        'config_value': 'admin',
      });

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pushOutbox();

      expect(result.pushedCount, 1);
      expect(result.failedCount, 0);

      // Adapter received exactly one upsert for app_config.
      expect(adapter.upserts.length, 1);
      expect(adapter.upserts.first.table, 'app_config');
      expect(adapter.upserts.first.payload['config_key'], 'last_username');

      // Outbox is empty.
      final remaining = await db.query('_sync_outbox');
      expect(remaining, isEmpty);

      // Watermarks set for app_config.
      final acState = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['app_config'],
      );
      expect(acState.length, 1);
      expect(acState.first['last_pushed_at'], isNotNull);

      // Watermark set for __global__.
      final globalState = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['__global__'],
      );
      expect(globalState.first['last_pushed_at'], isNotNull);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 3 — coalescing: 5 UPSERT rows → 1 adapter call
  // ---------------------------------------------------------------------------
  test(
    'Coalescing 5 UPSERT updates for app_config.last_username results in '
    '1 adapter.upsertRow call with latest value and deletes all 5 outbox rows',
    () async {
      // 1 INSERT + 4 UPDATEs = 5 trigger firings.
      await db.insert('app_config', {
        'config_key': 'last_username',
        'config_value': 'v1',
      });
      for (int i = 2; i <= 5; i++) {
        await db.update(
          'app_config',
          {'config_value': 'v$i'},
          where: 'config_key = ?',
          whereArgs: ['last_username'],
        );
      }

      final outboxBefore = await db.query('_sync_outbox');
      expect(outboxBefore.length, 5);

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pushOutbox();

      expect(result.pushedCount, 1);
      expect(adapter.upserts.length, 1);
      expect(adapter.upserts.first.payload['config_value'], 'v5');

      // All 5 outbox rows deleted.
      final remaining = await db.query('_sync_outbox');
      expect(remaining, isEmpty);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 4 — DELETE row, integer PK coercion
  // ---------------------------------------------------------------------------
  test(
    "DELETE row on Sibling_Links with record_pk '1' calls "
    "adapter.deleteRow('Sibling_Links', {'LinkID': 1}) with int 1",
    () async {
      // Clear any auto-enqueued rows from migrate.
      await db.delete('_sync_outbox');

      // Manually enqueue a synthetic DELETE row.
      await db.rawInsert(
        "INSERT INTO _sync_outbox "
        "(table_name, record_pk, operation, created_at) "
        "VALUES ('Sibling_Links', '1', 'DELETE', strftime('%Y-%m-%dT%H:%M:%fZ','now'))",
      );

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pushOutbox();

      expect(result.pushedCount, 1);
      expect(result.failedCount, 0);
      expect(adapter.deletes.length, 1);
      expect(adapter.deletes.first.table, 'Sibling_Links');

      final pkMap = adapter.deletes.first.pk;
      expect(pkMap, {'LinkID': 1});
      expect(pkMap['LinkID'], isA<int>());
    },
  );

  // ---------------------------------------------------------------------------
  // Test 5 — vanished row (non-existent Stu_Reg 99999)
  // ---------------------------------------------------------------------------
  test(
    'Vanished row: synthetic UPSERT in _sync_outbox for non-existent '
    'Stu_Reg 99999 deletes outbox row without calling adapter',
    () async {
      await db.delete('_sync_outbox');

      await db.rawInsert(
        "INSERT INTO _sync_outbox "
        "(table_name, record_pk, operation, created_at) "
        "VALUES ('Stu_Reg', '99999', 'UPSERT', strftime('%Y-%m-%dT%H:%M:%fZ','now'))",
      );

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pushOutbox();

      // Vanished rows are cleaned up but not counted as pushed.
      expect(result.pushedCount, 0);
      expect(result.failedCount, 0);
      expect(adapter.upserts, isEmpty);
      expect(adapter.deletes, isEmpty);

      // Outbox cleaned up.
      final remaining = await db.query('_sync_outbox');
      expect(remaining, isEmpty);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 6 — retry on failure, then success
  // ---------------------------------------------------------------------------
  test(
    'Retry on push failure: failTables.add(app_config) increments '
    'retry_count to 1, sets last_error, keeps outbox row, and does not '
    'advance __global__ last_pushed_at; subsequent retry succeeds',
    () async {
      await db.insert('app_config', {
        'config_key': 'last_username',
        'config_value': 'admin',
      });

      final adapter = FakeSyncRemoteAdapter()..failTables.add('app_config');
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      // --- First push (fails) ---
      final failResult = await svc.pushOutbox();

      expect(failResult.failedCount, 1);
      expect(failResult.pushedCount, 0);

      // Outbox row still present with retry_count incremented to 1.
      final outboxRows = await db.query('_sync_outbox');
      expect(outboxRows.length, 1);
      expect(outboxRows.first['retry_count'], 1);
      expect(outboxRows.first['last_error'], isNotNull);

      // __global__ last_pushed_at must still be NULL (nothing succeeded).
      final globalState = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['__global__'],
      );
      expect(globalState.first['last_pushed_at'], isNull);

      // --- Second push (success) ---
      adapter.failTables.remove('app_config');
      final successResult = await svc.pushOutbox();

      expect(successResult.pushedCount, 1);
      expect(successResult.failedCount, 0);

      final remaining = await db.query('_sync_outbox');
      expect(remaining, isEmpty);

      final globalStateAfter = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['__global__'],
      );
      expect(globalStateAfter.first['last_pushed_at'], isNotNull);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 7 — composite PK from Student_Class trigger
  // ---------------------------------------------------------------------------
  test(
    'Composite PK: inserting into Student_Class enqueues JSON record_pk '
    'and pushOutbox passes full reconstructed row to adapter.upsertRow',
    () async {
      // Stu_Reg must exist (FK constraint with foreign_keys = ON).
      await db.insert('Stu_Reg', {
        'Stu_RegID': 9501,
        'NameFirst': 'Composite Test',
        'FullDiscount': 0,
      });

      await db.insert('Student_Class', {
        'Stu_RegID': 9501,
        'ClassID': 13,
        'ClassSecID': 25,
        'ClassRollNo': 1,
        'SessionYr': '2025-2026',
        'Present': 1,
        'VGen': 'Y',
      });

      // Verify trigger produced a JSON record_pk.
      final outboxRows = await db.query(
        '_sync_outbox',
        where: 'table_name = ?',
        whereArgs: ['Student_Class'],
      );
      expect(outboxRows.length, 1);
      final pk = jsonDecode(outboxRows.first['record_pk'] as String)
          as Map<String, dynamic>;
      expect(pk['Stu_RegID'], 9501);
      expect(pk['ClassID'], 13);
      expect(pk['SessionYr'], '2025-2026');

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      // Clear Stu_Reg's outbox rows — only test Student_Class push.
      await db.delete(
        '_sync_outbox',
        where: 'table_name = ?',
        whereArgs: ['Stu_Reg'],
      );

      final result = await svc.pushOutbox();

      expect(result.pushedCount, 1);
      expect(result.failedCount, 0);
      expect(adapter.upserts.length, 1);
      expect(adapter.upserts.first.table, 'Student_Class');

      final payload = adapter.upserts.first.payload;
      expect(payload['Stu_RegID'], 9501);
      expect(payload['ClassID'], 13);
      expect(payload['SessionYr'], '2025-2026');
    },
  );

  // ---------------------------------------------------------------------------
  // Test 8 — pure unit test: parseRecordPk integer coercion
  // ---------------------------------------------------------------------------
  test(
    "SchLeaving integer PK coercion: parseRecordPk('SchLeaving', '4810') "
    "returns {'StuRegID': 4810} as int",
    () {
      final svc = SyncService(
        adapter: FakeSyncRemoteAdapter(),
        openDb: () async => db,
      );

      final result = svc.parseRecordPk('SchLeaving', '4810');

      expect(result, {'StuRegID': 4810});
      expect(result['StuRegID'], isA<int>());
    },
  );
}
