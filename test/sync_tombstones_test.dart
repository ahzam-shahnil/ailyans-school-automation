// Phase F: Cross-device delete propagation via _sync_tombstones
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
  late FakeSyncRemoteAdapter fakeAdapter;
  late SyncService syncService;

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

    fakeAdapter = FakeSyncRemoteAdapter();
    syncService = SyncService(adapter: fakeAdapter);
  });

  tearDown(() async {
    DatabaseService.instance.setDatabase(null);
    await db.close();
  });

  group('Tombstone sync propagation', () {
    test(
      'T1: applies Student_Class tombstone, deletes local row without outbox echo, advances watermark',
      () async {
        // 1. Seed prerequisite tables (Class and Stu_Reg) so foreign keys pass
        await db.insert('Class', {'ClassID': 4, 'CName': 'Class 4'});
        await db.insert('Stu_Reg', {
          'Stu_RegID': 4631,
          'NameFirst': 'Test',
          'NameLast': 'Student',
          'DOAdmission': '2026-08-01',
          'FullDiscount': 0,
        });

        // Seed target Student_Class row (4631, 4, '2026-27')
        await db.insert('Student_Class', {
          'Stu_RegID': 4631,
          'ClassID': 4,
          'SessionYr': '2026-27',
          'ClassRollNo': 12,
          'Present': 1,
          'VGen': 'Y',
        });

        // Drain any outbox triggers caused by seeding
        await db.delete('_sync_outbox');

        // Confirm row is present locally
        final beforeRows = await db.query(
          'Student_Class',
          where: 'Stu_RegID = ? AND ClassID = ? AND SessionYr = ?',
          whereArgs: [4631, 4, '2026-27'],
        );
        expect(beforeRows, hasLength(1));

        // 2. Configure fakeFetchTombstones with a deletion tombstone for (4631, 4, '2026-27')
        const tombstoneTimestamp = '2026-11-19T22:00:00.000Z';
        fakeAdapter.fakeFetchTombstones = (sinceIso, schoolId, offset, limit) {
          return [
            {
              'id': 1,
              'table_name': 'Student_Class',
              'pk_json': {
                'Stu_RegID': 4631,
                'ClassID': 4,
                'SessionYr': '2026-27',
              },
              'deleted_at': tombstoneTimestamp,
            },
          ];
        };

        // 3. Run pullDelta
        final pullResult = await syncService.pullDelta();

        // Pulled count must include the applied tombstone
        expect(pullResult.pulledCount, equals(1));
        expect(pullResult.failedCount, equals(0));

        // 4. Verify local row was deleted
        final afterRows = await db.query(
          'Student_Class',
          where: 'Stu_RegID = ? AND ClassID = ? AND SessionYr = ?',
          whereArgs: [4631, 4, '2026-27'],
        );
        expect(afterRows, isEmpty);

        // 5. Verify NO echo in _sync_outbox (is_applying_remote guard prevented trigger)
        final outboxRows = await db.query(
          '_sync_outbox',
          where: "table_name = 'Student_Class' AND operation = 'DELETE'",
        );
        expect(
          outboxRows,
          isEmpty,
          reason: 'Remote tombstone application must NOT echo into _sync_outbox',
        );

        // 6. Verify watermark in _sync_state for '_sync_tombstones'
        final stateRows = await db.query(
          '_sync_state',
          where: "table_name = '_sync_tombstones'",
        );
        expect(stateRows, hasLength(1));
        expect(stateRows.first['last_pulled_at'], equals(tombstoneTimestamp));
      },
    );

    test('T1b: pk_json serialized as JSON string parses and applies identically', () async {
      await db.insert('Class', {'ClassID': 5, 'CName': 'Class 5'});
      await db.insert('Stu_Reg', {
        'Stu_RegID': 4632,
        'NameFirst': 'Test',
        'NameLast': 'Student 2',
        'DOAdmission': '2026-08-01',
        'FullDiscount': 0,
      });
      await db.insert('Student_Class', {
        'Stu_RegID': 4632,
        'ClassID': 5,
        'SessionYr': '2026-27',
        'ClassRollNo': 15,
        'Present': 1,
        'VGen': 'Y',
      });
      await db.delete('_sync_outbox');

      fakeAdapter.fakeFetchTombstones = (sinceIso, schoolId, offset, limit) {
        return [
          {
            'id': 2,
            'table_name': 'Student_Class',
            'pk_json': jsonEncode({
              'Stu_RegID': 4632,
              'ClassID': 5,
              'SessionYr': '2026-27',
            }),
            'deleted_at': '2026-11-19T22:30:00.000Z',
          },
        ];
      };

      final result = await syncService.pullDelta();
      expect(result.pulledCount, equals(1));

      final rows = await db.query('Student_Class', where: 'Stu_RegID = 4632');
      expect(rows, isEmpty);

      final outbox = await db.query('_sync_outbox');
      expect(outbox, isEmpty);
    });

    test('T2: unknown table and missing PK column tombstones are safely ignored without throw', () async {
      fakeAdapter.fakeFetchTombstones = (sinceIso, schoolId, offset, limit) {
        return [
          // Unknown table not in kPkColumns
          {
            'id': 101,
            'table_name': 'NonExistentTable',
            'pk_json': {'id': 999},
            'deleted_at': '2026-11-19T22:00:00.000Z',
          },
          // Synced table but missing one of the composite PK columns (missing SessionYr)
          {
            'id': 102,
            'table_name': 'Student_Class',
            'pk_json': {'Stu_RegID': 4631, 'ClassID': 4},
            'deleted_at': '2026-11-19T22:01:00.000Z',
          },
          // Malformed pk_json
          {
            'id': 103,
            'table_name': 'Student_Class',
            'pk_json': 'not-a-valid-json-string',
            'deleted_at': '2026-11-19T22:02:00.000Z',
          },
        ];
      };

      // Must complete without error
      final pullResult = await syncService.pullDelta();
      expect(pullResult.pulledCount, equals(0));
      expect(pullResult.failedCount, equals(0));
      expect(pullResult.errors, isEmpty);
    });

    test('T2b: fetchTombstones error (offline/table missing) is non-fatal for pullDelta', () async {
      fakeAdapter.failTables.add('_sync_tombstones');

      // pullDelta must not crash even when fetchTombstones fails
      final result = await syncService.pullDelta();
      expect(result.failedCount, equals(0));
    });
  });
}
