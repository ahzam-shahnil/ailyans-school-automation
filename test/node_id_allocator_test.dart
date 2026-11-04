import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/sync/node_id_allocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  NodeIdAllocator allocatorFor(Database database) {
    return NodeIdAllocator(openDb: () async => database);
  }

  test(
    'Migration 009 idempotent column guard adds next_allocated_id and fixes '
    'block on fresh and existing v9 DBs',
    () async {
      // PHASE 1 — fresh install proves the seed INSERT.
      {
        final freshDb = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
        );
        try {
          await SchemaMigrations.migrate(freshDb);

          final version = (await freshDb.rawQuery(
            'PRAGMA user_version',
          )).first.values.first;
          expect(version, 10);

          final node = await freshDb.query(
            '_sync_state',
            where: "table_name = '__node__'",
          );
          expect(node.first['node_block_start'], 100000);
          expect(node.first['node_block_end'], 199999);
          expect(node.first['next_allocated_id'], 100000);
        } finally {
          await freshDb.close();
        }
      }

      // PHASE 2 — existing v9 DB with F-1 shape (no next_allocated_id,
      // blocks 10000..19999) proves the idempotent column guard converges.
      {
        final legacyDb = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
        );
        try {
          await legacyDb.execute('''
            CREATE TABLE _sync_state (
              table_name TEXT PRIMARY KEY,
              last_pulled_at TEXT,
              last_pushed_at TEXT,
              is_applying_remote INTEGER NOT NULL DEFAULT 0,
              node_block_start INTEGER,
              node_block_end INTEGER
            )
          ''');
          // Migration 010 alters StuAdv, so the simulated v9 DB must contain it.
          await legacyDb.execute('''
            CREATE TABLE StuAdv (
              StuAdvID INTEGER PRIMARY KEY
            )
          ''');
          await legacyDb.rawInsert(
            "INSERT INTO _sync_state (table_name, is_applying_remote, "
            "node_block_start, node_block_end) VALUES "
            "('__global__', 0, NULL, NULL)",
          );
          await legacyDb.rawInsert(
            "INSERT INTO _sync_state (table_name, is_applying_remote, "
            "node_block_start, node_block_end) VALUES "
            "('__node__', 0, 10000, 19999)",
          );
          await legacyDb.execute('PRAGMA user_version = 9');

          await SchemaMigrations.migrate(legacyDb);

          final version = (await legacyDb.rawQuery(
            'PRAGMA user_version',
          )).first.values.first;
          expect(version, 10);

          final node = await legacyDb.query(
            '_sync_state',
            where: "table_name = '__node__'",
          );
          expect(node.first['node_block_start'], 100000);
          expect(node.first['node_block_end'], 199999);
          expect(node.first['next_allocated_id'], 100000);
        } finally {
          await legacyDb.close();
        }
      }
    },
  );

  test(
    'Sequential allocation returns consecutive integers starting from blockStart',
    () async {
      final allocator = allocatorFor(db);
      await allocator.configureNodeBlock('windows');

      expect(await allocator.nextId(), 100000);
      expect(await allocator.nextId(), 100001);
      expect(await allocator.nextId(), 100002);
    },
  );

  test(
    'Block exhaustion throws BlockExhaustedException with populated fields',
    () async {
      final allocator = allocatorFor(db);
      await db.update(
        '_sync_state',
        <String, Object?>{
          'node_block_start': 100000,
          'node_block_end': 100002,
          'next_allocated_id': 100000,
        },
        where: "table_name = '__node__'",
      );

      expect(await allocator.nextId(), 100000);
      expect(await allocator.nextId(), 100001);
      expect(await allocator.nextId(), 100002);

      try {
        await allocator.nextId();
        fail('Expected BlockExhaustedException');
      } on BlockExhaustedException catch (error) {
        expect(error.nodeId, 'windows');
        expect(error.blockStart, 100000);
        expect(error.blockEnd, 100002);
        expect(error.currentAllocation, 100003);
        expect(error.toString(), contains('node "windows"'));
        expect(error.toString(), contains('block 100000..100002'));
      }
    },
  );

  test(
    'Concurrent allocation via Future.wait returns distinct IDs',
    () async {
      final allocator = allocatorFor(db);
      await allocator.configureNodeBlock('windows');

      final ids = await Future.wait(
        List<Future<int>>.generate(100, (_) => allocator.nextId()),
      );

      expect(ids.length, 100);
      expect(ids.toSet().length, 100);
      for (final id in ids) {
        expect(id, inInclusiveRange(100000, 199999));
      }
    },
  );

  test(
    'Per-device isolation: windows and android_a never collide',
    () async {
      final dbA = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      final dbB = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      try {
        await SchemaMigrations.migrate(dbA);
        await SchemaMigrations.migrate(dbB);

        final allocatorA = allocatorFor(dbA);
        final allocatorB = allocatorFor(dbB);
        await allocatorA.configureNodeBlock('windows');
        await allocatorB.configureNodeBlock('android_a');

        final idsA = <int>[];
        for (var i = 0; i < 50; i++) {
          idsA.add(await allocatorA.nextId());
        }

        final idsB = <int>[];
        for (var i = 0; i < 50; i++) {
          idsB.add(await allocatorB.nextId());
        }

        expect(idsA, List<int>.generate(50, (i) => 100000 + i));
        expect(idsB, List<int>.generate(50, (i) => 200000 + i));
        expect(idsA.toSet().intersection(idsB.toSet()), isEmpty);
      } finally {
        await dbA.close();
        await dbB.close();
      }
    },
  );

  test(
    'next_allocated_id survives DB close-reopen (temp file)',
    () async {
      final dir = await Directory.systemTemp.createTemp('f3a_alloc_');
      final path = p.join(dir.path, 'school_database.db');
      Database? fileDb;
      try {
        final firstDb = await databaseFactoryFfi.openDatabase(path);
        fileDb = firstDb;
        await SchemaMigrations.migrate(firstDb);

        final allocator = allocatorFor(firstDb);
        await allocator.configureNodeBlock('windows');
        for (var i = 0; i < 5; i++) {
          await allocator.nextId();
        }

        final before = await allocator.state();
        expect(before.nextAllocated, 100005);

        await firstDb.close();
        fileDb = null;

        final secondDb = await databaseFactoryFfi.openDatabase(path);
        fileDb = secondDb;
        final reopened = allocatorFor(secondDb);

        final after = await reopened.state();
        expect(after.nextAllocated, 100005);
        expect(await reopened.nextId(), 100005);
      } finally {
        final current = fileDb;
        if (current != null && current.isOpen) {
          await current.close();
        }
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'state() reports current allocation without consuming an ID',
    () async {
      await db.update(
        '_sync_state',
        <String, Object?>{'next_allocated_id': 100050},
        where: "table_name = '__node__'",
      );

      final allocator = allocatorFor(db);
      final first = await allocator.state();
      final second = await allocator.state();

      expect(first.nextAllocated, 100050);
      expect(second.nextAllocated, 100050);
      expect(await allocator.nextId(), 100050);
    },
  );

  test(
    'LedgerReconciler: cash + advance both contribute; NULL VoucherMasID '
    'deduction is invisible',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await SchemaMigrations.migrate(db);

      // Fixture: a voucher with SubTotal 1920, no discount.
      await db.insert('VoucharMas', <String, Object?>{
        'VoucherMasID': 'TEST-F3C',
        'SubTotal': 1920,
        'Discount': 0,
        'IsPaid': 'N',
        'PaidAmt': 0,
      });

      // Part 1 — cash only (1420, no advance yet).
      await db.insert('FeeTransaction', <String, Object?>{
        'FeeTransID': 999001,
        'VoucharNo': 'TEST-F3C',
        'PaidAmount': 1420,
        'TotalAmount': 1920,
      });
      var result = await LedgerReconciler.reconcileVoucher(db, 'TEST-F3C');
      expect(result.totalPaid, 1420);
      expect(result.isPaid, 'N');

      // Part 2 — advance deduction linked by VoucherMasID (-500 -> +500).
      await db.insert('StuAdv', <String, Object?>{
        'StuAdvID': 999002,
        'StuRegID': 1,
        'AdvAmount': -500,
        'MOP': 'Advance Deduction',
        'VoucherMasID': 'TEST-F3C',
      });
      result = await LedgerReconciler.reconcileVoucher(db, 'TEST-F3C');
      expect(result.totalPaid, 1920);
      expect(result.isPaid, 'Y');

      // Part 3 — a deduction with NULL VoucherMasID must NOT be counted.
      await db.rawUpdate(
        'UPDATE StuAdv SET VoucherMasID = NULL WHERE StuAdvID = 999002',
      );
      result = await LedgerReconciler.reconcileVoucher(db, 'TEST-F3C');
      expect(result.totalPaid, 1420);
      expect(result.isPaid, 'N');

      await db.close();
    },
  );

  test(
    'LedgerReconciler: over-discount clamps to 0, preserves O for rolled-over',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await SchemaMigrations.migrate(db);

      // Over-discount: Discount > SubTotal -> clampedNet=0 -> 'Y' on 0 paid.
      await db.insert('VoucharMas', <String, Object?>{
        'VoucherMasID': 'TEST-OVER',
        'SubTotal': 1000,
        'Discount': 1500,
        'IsPaid': 'N',
        'PaidAmt': 0,
      });
      var r = await LedgerReconciler.reconcileVoucher(db, 'TEST-OVER');
      expect(r.totalPaid, 0);
      expect(r.isPaid, 'Y');

      // Rolled-over-unpaid: IsPaid='O', no payments -> stays 'O'.
      await db.insert('VoucharMas', <String, Object?>{
        'VoucherMasID': 'TEST-ROLLED',
        'SubTotal': 1000,
        'Discount': 0,
        'IsPaid': 'O',
        'PaidAmt': 0,
      });
      r = await LedgerReconciler.reconcileVoucher(db, 'TEST-ROLLED');
      expect(r.totalPaid, 0);
      expect(r.isPaid, 'O');

      await db.close();
    },
  );
}
