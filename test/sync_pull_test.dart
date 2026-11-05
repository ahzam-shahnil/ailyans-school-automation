import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/sync/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a UTC ISO-8601 string offset from a base timestamp by [seconds].
String ts(int seconds) {
  final base = DateTime.utc(2026, 1, 1);
  return base.add(Duration(seconds: seconds)).toIso8601String();
}

/// Builds a fakeFetchDelta closure backed by [data]: map of table -> rows.
/// Respects [sinceIso] filtering and [offset] slicing; ignores [limit]
/// (all test datasets are well below 500).
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

/// Seeds `_sync_state` with a last_pulled_at watermark for [tableName].
Future<void> seedWatermark(
  Database db,
  String tableName,
  String lastPulledAt,
) async {
  await db.rawInsert(
    'INSERT INTO _sync_state (table_name, last_pulled_at, is_applying_remote) '
    'VALUES (?, ?, 0) '
    'ON CONFLICT(table_name) DO UPDATE SET last_pulled_at = excluded.last_pulled_at',
    [tableName, lastPulledAt],
  );
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Test 1 — bootstrap: null watermark returns all remote rows
  // -------------------------------------------------------------------------
  test(
    'fetchDelta with null watermark pulls all rows and inserts them locally',
    () async {
      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'app_config': [
            {'config_key': 'alpha', 'config_value': 'a', 'updated_at': ts(1)},
            {'config_key': 'beta', 'config_value': 'b', 'updated_at': ts(2)},
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pullDelta();

      expect(result.pulledCount, 2);
      expect(result.failedCount, 0);
      final rows = await db.query('app_config', orderBy: 'config_key');
      // Triggers may have added rows from migrate; filter to our test keys.
      final keys = rows.map((r) => r['config_key']).toSet();
      expect(keys, containsAll(['alpha', 'beta']));
    },
  );

  // -------------------------------------------------------------------------
  // Test 2 — watermark filter: only rows newer than last_pulled_at are pulled
  // -------------------------------------------------------------------------
  test(
    'fetchDelta with sinceIso watermark only returns rows with updated_at > watermark',
    () async {
      // Pre-seed watermark: ts(5). Only the ts(10) row should come through.
      await seedWatermark(db, 'app_config', ts(5));

      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'app_config': [
            {
              'config_key': 'old_key',
              'config_value': 'old',
              'updated_at': ts(3), // before watermark — filtered out
            },
            {
              'config_key': 'new_key',
              'config_value': 'new',
              'updated_at': ts(10), // after watermark — passes through
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pullDelta();

      expect(result.pulledCount, 1);
      final rows = await db.query(
        'app_config',
        where: 'config_key = ?',
        whereArgs: ['new_key'],
      );
      expect(rows.length, 1);
      expect(rows.first['config_value'], 'new');

      // old_key must NOT be in the DB.
      final oldRows = await db.query(
        'app_config',
        where: 'config_key = ?',
        whereArgs: ['old_key'],
      );
      expect(oldRows, isEmpty);
    },
  );

  // -------------------------------------------------------------------------
  // Test 3 — Rule 1: updated_at stripped before local insert (no crash)
  // -------------------------------------------------------------------------
  test(
    'updated_at is stripped from remote row before local SQLite insert',
    () async {
      // app_config has no updated_at column in SQLite — inserting with it
      // would throw a "table has no column named updated_at" error.
      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'app_config': [
            {
              'config_key': 'strip_test',
              'config_value': 'x',
              'updated_at': ts(1),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      // Must NOT throw.
      final result = await svc.pullDelta();

      expect(result.failedCount, 0);
      expect(result.pulledCount, 1);

      final rows = await db.query(
        'app_config',
        where: 'config_key = ?',
        whereArgs: ['strip_test'],
      );
      expect(rows.length, 1);
      expect(rows.first['config_value'], 'x');
      // Confirm updated_at column does not exist in local row.
      expect(rows.first.containsKey('updated_at'), isFalse);
    },
  );

  // -------------------------------------------------------------------------
  // Test 4 — Rule 2: is_applying_remote suppresses outbox enqueue during pull
  // -------------------------------------------------------------------------
  test(
    'is_applying_remote guard prevents outbox enqueue for rows inserted '
    'during the pull transaction',
    () async {
      // Clear any outbox entries from migrate's seed.
      await db.delete('_sync_outbox');

      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'app_config': [
            {
              'config_key': 'guard_test',
              'config_value': 'v',
              'updated_at': ts(1),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      await svc.pullDelta();

      // The app_config insert happened inside the transaction with
      // is_applying_remote = 1, so the trigger must NOT have fired.
      final outbox = await db.query(
        '_sync_outbox',
        where: 'table_name = ?',
        whereArgs: ['app_config'],
      );
      expect(outbox, isEmpty);

      // Guard must be cleared after the transaction.
      final state = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['__global__'],
      );
      expect(state.first['is_applying_remote'], 0);
    },
  );

  // -------------------------------------------------------------------------
  // Test 5 — Rule 2: failed transaction rolls back is_applying_remote to 0
  // -------------------------------------------------------------------------
  test(
    'Failed pull transaction rolls back is_applying_remote to 0 '
    'and is_applying_remote is 0 after pullDelta returns',
    () async {
      // Provide a Stu_Reg row missing NameFirst (NOT NULL) to cause a
      // transaction-level constraint error on insert.
      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'Stu_Reg': [
            {
              'Stu_RegID': 99001,
              // NameFirst intentionally omitted — NOT NULL violation
              'FullDiscount': 0,
              'updated_at': ts(1),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pullDelta();

      // The transaction failed, so we get a failedCount.
      expect(result.failedCount, greaterThan(0));

      // is_applying_remote must be 0 (transaction rolled back SET=1 as well).
      final state = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['__global__'],
      );
      expect(state.first['is_applying_remote'], 0);
    },
  );

  // -------------------------------------------------------------------------
  // Test 6 — Rule 3: dirty-outbox skip (local edit wins, remote skipped)
  // -------------------------------------------------------------------------
  test(
    'Row with pending outbox entry is skipped during pull (dirty-outbox guard)',
    () async {
      // Seed a local Stu_Reg row — trigger auto-enqueues it as dirty.
      await db.insert('Stu_Reg', {
        'Stu_RegID': 8001,
        'NameFirst': 'LocalOnly',
        'FullDiscount': 0,
      });
      // Confirm the row is dirty in the outbox.
      final dirty = await db.query(
        '_sync_outbox',
        where: "table_name = 'Stu_Reg' AND record_pk = '8001'",
      );
      expect(dirty.length, 1);

      // Remote offers a conflicting NameFirst for the same Stu_RegID.
      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'Stu_Reg': [
            {
              'Stu_RegID': 8001,
              'NameFirst': 'RemoteOverwrite', // must be ignored
              'FullDiscount': 1,
              'updated_at': ts(100),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      await svc.pullDelta();

      final rows = await db.query(
        'Stu_Reg',
        where: 'Stu_RegID = ?',
        whereArgs: [8001],
      );
      expect(rows.length, 1);
      expect(rows.first['NameFirst'], 'LocalOnly'); // local value preserved
    },
  );

  // -------------------------------------------------------------------------
  // Test 7 — Rule 3 append-only: FeeTransaction is NOT skipped despite dirty
  // -------------------------------------------------------------------------
  test(
    'FeeTransaction bypasses dirty-outbox skip: remote row is applied even '
    'when the same FeeTransID has a pending outbox entry',
    () async {
      // Seed a VoucharMas header (FeeTransaction.VoucharNo references it).
      await db.insert('VoucharMas', {
        'VoucherMasID': 'VM-AOT',
        'SubTotal': 2000,
        'Discount': 0,
        'IsPaid': 'N',
        'PaidAmt': 0,
      });

      // Insert a local FeeTransaction — trigger enqueues it as dirty.
      await db.insert('FeeTransaction', {
        'FeeTransID': 7001,
        'VoucharNo': 'VM-AOT',
        'PaidAmount': 500,
      });
      final dirty = await db.query(
        '_sync_outbox',
        where: "table_name = 'FeeTransaction' AND record_pk = '7001'",
      );
      expect(dirty.length, 1);

      // Remote sends a conflicting PaidAmount for the same FeeTransID.
      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'FeeTransaction': [
            {
              'FeeTransID': 7001,
              'VoucharNo': 'VM-AOT',
              'PaidAmount': 999, // append-only: both records valid
              'updated_at': ts(50),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      await svc.pullDelta();

      // FeeTransaction row was upserted (ConflictAlgorithm.replace).
      final rows = await db.query(
        'FeeTransaction',
        where: 'FeeTransID = ?',
        whereArgs: [7001],
      );
      expect(rows.length, 1);
      expect(rows.first['PaidAmount'], 999); // remote value applied
    },
  );

  // -------------------------------------------------------------------------
  // Test 8 — Rule 4: LedgerReconciler fires on pulled FeeTransaction
  // -------------------------------------------------------------------------
  test(
    'Pulling a FeeTransaction row triggers LedgerReconciler and updates '
    'VoucharMas.PaidAmt and IsPaid',
    () async {
      // Seed a voucher header.
      await db.insert('VoucharMas', {
        'VoucherMasID': 'VM-REC1',
        'SubTotal': 1000,
        'Discount': 0,
        'IsPaid': 'N',
        'PaidAmt': 0,
      });

      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'FeeTransaction': [
            {
              'FeeTransID': 8101,
              'VoucharNo': 'VM-REC1',
              'PaidAmount': 1000,
              'updated_at': ts(1),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      await svc.pullDelta();

      final vm = await db.query(
        'VoucharMas',
        where: 'VoucherMasID = ?',
        whereArgs: ['VM-REC1'],
      );
      expect(vm.length, 1);
      expect(vm.first['PaidAmt'], 1000);
      expect(vm.first['IsPaid'], 'Y');
    },
  );

  // -------------------------------------------------------------------------
  // Test 9 — Rule 5: watermark = MAX(remote.updated_at), not local clock
  // -------------------------------------------------------------------------
  test(
    'last_pulled_at watermark is set to MAX(remote.updated_at), not local clock',
    () async {
      final t1 = ts(10);
      final t2 = ts(20); // MAX
      final t3 = ts(5);

      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'app_config': [
            {'config_key': 'k1', 'config_value': 'a', 'updated_at': t1},
            {'config_key': 'k2', 'config_value': 'b', 'updated_at': t2},
            {'config_key': 'k3', 'config_value': 'c', 'updated_at': t3},
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final before = DateTime.now().toUtc();
      await svc.pullDelta();

      final state = await db.query(
        '_sync_state',
        where: 'table_name = ?',
        whereArgs: ['app_config'],
      );
      expect(state.length, 1);
      final watermark = state.first['last_pulled_at'] as String;
      // Must equal the MAX remote timestamp, not anything derived from local clock.
      expect(watermark, t2);
      // Sanity: watermark must be BEFORE local test execution ended (not future).
      expect(DateTime.parse(watermark).isBefore(before), isTrue);
    },
  );

  // -------------------------------------------------------------------------
  // Test 10 — multi-table bootstrap: 3 tables pulled, all watermarks set
  // -------------------------------------------------------------------------
  test(
    'Multi-table pull: 3 tables (app_config, Stu_Reg, VoucharMas) each with '
    '10 rows are all applied and watermarks advanced',
    () async {
      final configRows = List.generate(
        10,
        (i) => {
          'config_key': 'cfg_$i',
          'config_value': 'val_$i',
          'updated_at': ts(i + 1),
        },
      );
      final stuRegRows = List.generate(
        10,
        (i) => {
          'Stu_RegID': 9100 + i,
          'NameFirst': 'Student${9100 + i}',
          'FullDiscount': 0,
          'updated_at': ts(100 + i),
        },
      );
      final voucharRows = List.generate(
        10,
        (i) => {
          'VoucherMasID': 'VM-MT-$i',
          'SubTotal': (i + 1) * 100,
          'IsPaid': 'N',
          'PaidAmt': 0,
          'updated_at': ts(200 + i),
        },
      );

      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'app_config': configRows,
          'Stu_Reg': stuRegRows,
          'VoucharMas': voucharRows,
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      final result = await svc.pullDelta();

      // 10 + 10 + 10 = 30 rows pulled.
      expect(result.pulledCount, 30);
      expect(result.failedCount, 0);

      // Spot-check one row per table.
      final cfg = await db.query(
        'app_config',
        where: 'config_key = ?',
        whereArgs: ['cfg_5'],
      );
      expect(cfg.first['config_value'], 'val_5');

      final stu = await db.query(
        'Stu_Reg',
        where: 'Stu_RegID = ?',
        whereArgs: [9105],
      );
      expect(stu.first['NameFirst'], 'Student9105');

      final vm = await db.query(
        'VoucharMas',
        where: 'VoucherMasID = ?',
        whereArgs: ['VM-MT-7'],
      );
      expect(vm.first['SubTotal'], 800);

      // Watermarks must be set for all 3 tables.
      for (final tbl in ['app_config', 'Stu_Reg', 'VoucharMas']) {
        final s = await db.query(
          '_sync_state',
          where: 'table_name = ?',
          whereArgs: [tbl],
        );
        expect(s.first['last_pulled_at'], isNotNull,
            reason: '$tbl watermark not set');
      }

      // __global__ watermark must be set.
      final global = await db.query(
        '_sync_state',
        where: "table_name = '__global__'",
      );
      expect(global.first['last_pulled_at'], isNotNull);
    },
  );

  // -------------------------------------------------------------------------
  // Test 11 — Rule 4 correction: reconciler fires on StuAdv.VoucherMasID
  // -------------------------------------------------------------------------
  test(
    'Pulling a StuAdv deduction row (VoucherMasID set) triggers '
    'LedgerReconciler and updates VoucharMas.PaidAmt / IsPaid (Rule 4 fix)',
    () async {
      // Seed a voucher header with a Rs. 1000 fee.
      await db.insert('VoucharMas', {
        'VoucherMasID': 'VM-ADV1',
        'SubTotal': 1000,
        'Discount': 0,
        'IsPaid': 'N',
        'PaidAmt': 0,
      });

      // Remote sends a StuAdv deduction row: AdvAmount = -1000 means
      // the student's advance covers the full fee.
      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = fakeFor({
          'StuAdv': [
            {
              'StuAdvID': 11001,
              'StuRegID': 1,
              'AdvAmount': -1000,
              'VoucherMasID': 'VM-ADV1',
              'updated_at': ts(1),
            },
          ],
        });
      final svc = SyncService(adapter: adapter, openDb: () async => db);

      await svc.pullDelta();

      final vm = await db.query(
        'VoucharMas',
        where: 'VoucherMasID = ?',
        whereArgs: ['VM-ADV1'],
      );
      expect(vm.length, 1);
      // LedgerReconciler: SUM(-AdvAmount WHERE AdvAmount < 0) = 1000.
      expect(vm.first['PaidAmt'], 1000);
      expect(vm.first['IsPaid'], 'Y');
    },
  );
}
