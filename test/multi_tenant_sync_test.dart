import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/sync/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// G-10 Shot 6b — multi-tenant school_id isolation tests
//
// Remote tables carry `school_id TEXT NOT NULL` + composite PKs
// (school_id, <pk>); local SQLite tables have NO school_id column. These
// tests verify:
//   a) push payloads are tagged with the resolved active school_id,
//   b) pulled rows have school_id stripped before the local SQLite write,
//   c) device-local app_config keys never cross the sync boundary.
// ---------------------------------------------------------------------------

/// Returns a UTC ISO-8601 string offset from a base timestamp by [seconds].
String ts(int seconds) {
  final base = DateTime.utc(2026, 1, 1);
  return base.add(Duration(seconds: seconds)).toIso8601String();
}

/// Builds a fakeFetchDelta closure backed by [data]: map of table -> rows.
List<Map<String, dynamic>> Function(String, String?, int, int) fakeFor(
  Map<String, List<Map<String, dynamic>>> data,
) {
  return (table, sinceIso, offset, limit) {
    final rows = data[table] ?? const [];
    final filtered = sinceIso == null
        ? rows
        : rows
            .where((r) =>
                (r['updated_at'] as String).compareTo(sinceIso) > 0)
            .toList();
    return filtered.skip(offset).toList();
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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

  // -------------------------------------------------------------------------
  // (a) Push: school_id injection
  // -------------------------------------------------------------------------

  test(
    'Push payload includes school_id "ailyans" when app_config has no '
    'school_id and no tenant is configured (default fallback)',
    () async {
      await db.insert('app_config', {
        'config_key': 'last_username',
        'config_value': 'admin',
      });

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pushOutbox();

      expect(result.pushedCount, 1);
      expect(adapter.upserts.first.payload['school_id'], 'ailyans');
    },
  );

  test(
    'Push payload includes school_id "school_xyz" when app_config '
    'configures it',
    () async {
      await db.insert('app_config', {
        'config_key': 'school_id',
        'config_value': 'school_xyz',
      });
      await db.insert('app_config', {
        'config_key': 'last_username',
        'config_value': 'admin',
      });

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pushOutbox();

      expect(result.pushedCount, 1);
      expect(adapter.upserts.first.payload['school_id'], 'school_xyz');
    },
  );

  test(
    'Push falls back to the SharedPreferences bytewave_tenant id when '
    'app_config has no school_id',
    () async {
      SharedPreferences.setMockInitialValues({
        'bytewave_tenant': jsonEncode({'id': 'tenant_abc'}),
      });
      await db.insert('app_config', {
        'config_key': 'last_username',
        'config_value': 'admin',
      });

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      await svc.pushOutbox();

      expect(adapter.upserts.first.payload['school_id'], 'tenant_abc');
    },
  );

  test(
    'Push tags data-table payloads too (Stu_Reg row carries the resolved '
    'school_id)',
    () async {
      await db.insert('app_config', {
        'config_key': 'school_id',
        'config_value': 'school_xyz',
      });
      await db.insert('Stu_Reg', {
        'Stu_RegID': 9601,
        'NameFirst': 'Tenant Tagged',
        'FullDiscount': 0,
      });

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      await svc.pushOutbox();

      final stuUpsert = adapter.upserts.firstWhere(
        (u) => u.table == 'Stu_Reg',
      );
      expect(stuUpsert.payload['Stu_RegID'], 9601);
      expect(stuUpsert.payload['school_id'], 'school_xyz');
    },
  );

  // -------------------------------------------------------------------------
  // (b) Pull: .eq filter wiring + school_id strip before local write
  // -------------------------------------------------------------------------

  test(
    'pullDelta forwards the resolved school_id to fetchDelta for the '
    ".eq('school_id', …) remote filter",
    () async {
      await db.insert('app_config', {
        'config_key': 'school_id',
        'config_value': 'school_xyz',
      });

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      await svc.pullDelta();

      expect(adapter.lastFetchSchoolId, 'school_xyz');
    },
  );

  test(
    "Pulled rows with remote school_id 'school_xyz' have school_id stripped "
    'before the local SQLite upsert (no "no column named school_id" error)',
    () async {
      await db.insert('app_config', {
        'config_key': 'school_id',
        'config_value': 'school_xyz',
      });
      await db.delete('_sync_outbox');

      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'Stu_Reg': [
            {
              'Stu_RegID': 8801,
              'NameFirst': 'Tenant Row',
              'FullDiscount': 0,
              'school_id': 'school_xyz',
              'updated_at': ts(1),
            },
          ],
          'app_config': [
            {
              'config_key': 'alpha',
              'config_value': 'a',
              'school_id': 'school_xyz',
              'updated_at': ts(2),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      // Must NOT throw — school_id is stripped before txn.insert.
      final result = await svc.pullDelta();

      expect(result.failedCount, 0);
      expect(result.pulledCount, 2);

      final stu = await db.query(
        'Stu_Reg',
        where: 'Stu_RegID = ?',
        whereArgs: [8801],
      );
      expect(stu.length, 1);
      expect(stu.first['NameFirst'], 'Tenant Row');
      expect(stu.first.containsKey('school_id'), isFalse);

      final alpha = await db.query(
        'app_config',
        where: 'config_key = ?',
        whereArgs: ['alpha'],
      );
      expect(alpha.first['config_value'], 'a');
    },
  );

  // -------------------------------------------------------------------------
  // (c) Protected device-local app_config keys
  // -------------------------------------------------------------------------

  test(
    'Local-only app_config keys (school_id, node_id, supabase_sync_password) '
    'are never pushed: their outbox rows are dropped without adapter calls',
    () async {
      // Migrate seeds node_id-related state; clear and seed explicitly.
      await db.delete('_sync_outbox');
      await db.insert('app_config', {
        'config_key': 'school_id',
        'config_value': 'school_xyz',
      });
      await db.insert('app_config', {
        'config_key': 'node_id',
        'config_value': 'node-1',
      });
      await db.insert('app_config', {
        'config_key': 'supabase_sync_password',
        'config_value': 'secret',
      });
      // Sanity: triggers enqueued all three.
      final outbox = await db.query('_sync_outbox');
      expect(outbox.length, 3);

      final adapter = FakeSyncRemoteAdapter();
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pushOutbox();

      expect(result.pushedCount, 0);
      expect(adapter.upserts, isEmpty);
      expect(adapter.deletes, isEmpty);
      // Outbox rows were dropped locally.
      expect(await db.query('_sync_outbox'), isEmpty);
    },
  );

  test(
    'Local-only app_config keys are never overwritten by pull: remote values '
    'for school_id / node_id / supabase_sync_password are skipped',
    () async {
      await db.insert('app_config', {
        'config_key': 'school_id',
        'config_value': 'school_xyz',
      });
      await db.insert('app_config', {
        'config_key': 'node_id',
        'config_value': 'node-1',
      });
      await db.insert('app_config', {
        'config_key': 'supabase_sync_password',
        'config_value': 'secret',
      });

      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'app_config': [
            {
              'config_key': 'school_id',
              'config_value': 'hijacked-school',
              'school_id': 'other_school',
              'updated_at': ts(1),
            },
            {
              'config_key': 'node_id',
              'config_value': 'hijacked-node',
              'school_id': 'other_school',
              'updated_at': ts(2),
            },
            {
              'config_key': 'supabase_sync_password',
              'config_value': 'hijacked-secret',
              'school_id': 'other_school',
              'updated_at': ts(3),
            },
            {
              'config_key': 'alpha',
              'config_value': 'a',
              'school_id': 'school_xyz',
              'updated_at': ts(4),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pullDelta();

      // Only the non-protected 'alpha' row is applied.
      expect(result.failedCount, 0);

      final local = await db.query('app_config');
      final byKey = {
        for (final r in local) r['config_key'] as String: r['config_value'],
      };
      expect(byKey['school_id'], 'school_xyz');
      expect(byKey['node_id'], 'node-1');
      expect(byKey['supabase_sync_password'], 'secret');
      expect(byKey['alpha'], 'a');
    },
  );
}
