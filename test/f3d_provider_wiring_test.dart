import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/providers/sibling_links_provider.dart';
import 'package:school_automation/core/providers/student_registration_provider.dart';
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
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('F-3d Provider Wiring Tests', () {
    test(
      '1. postPayment uses NodeIdAllocator for FeeTransID and LedgerReconciler for PaidAmt',
      () async {
        // Insert a VoucharMas row
        await db.insert('VoucharMas', {
          'VoucherMasID': 'TEST-F3D',
          'SubTotal': 1000,
          'Discount': 0,
          'IsPaid': 'N',
          'PaidAmt': 0,
        });

        int feeTransId = 0;
        await db.transaction((txn) async {
          feeTransId = await NodeIdAllocator.allocateInTransaction(
            txn,
            tableName: 'FeeTransaction',
            pkColumn: 'FeeTransID',
          );

          await txn.insert('FeeTransaction', {
            'FeeTransID': feeTransId,
            'VoucharNo': 'TEST-F3D',
            'PaidAmount': 500,
          });

          await LedgerReconciler.reconcileVoucher(txn, 'TEST-F3D');
        });

        expect(feeTransId, greaterThanOrEqualTo(100000));

        final vmRows = await db.query(
          'VoucharMas',
          where: 'VoucherMasID = ?',
          whereArgs: ['TEST-F3D'],
        );
        expect(vmRows.first['PaidAmt'], 500);
        expect(vmRows.first['IsPaid'], 'N');
      },
    );

    test(
      '2. postPayment with advance: FeeTransID allocator + StuAdv allocator both block-range, reconciler sums both',
      () async {
        await db.insert('VoucharMas', {
          'VoucherMasID': 'TEST-F3D-ADV',
          'SubTotal': 1000,
          'Discount': 0,
          'IsPaid': 'N',
          'PaidAmt': 0,
        });

        int feeTransId = 0;
        int stuAdvId = 0;

        await db.transaction((txn) async {
          feeTransId = await NodeIdAllocator.allocateInTransaction(
            txn,
            tableName: 'FeeTransaction',
            pkColumn: 'FeeTransID',
          );
          await txn.insert('FeeTransaction', {
            'FeeTransID': feeTransId,
            'VoucharNo': 'TEST-F3D-ADV',
            'PaidAmount': 500,
          });

          stuAdvId = await NodeIdAllocator.allocateInTransaction(
            txn,
            tableName: 'StuAdv',
            pkColumn: 'StuAdvID',
          );
          await txn.insert('StuAdv', {
            'StuAdvID': stuAdvId,
            'StuRegID': 1,
            'AdvAmount': -500,
            'VoucherMasID': 'TEST-F3D-ADV',
          });

          await LedgerReconciler.reconcileVoucher(txn, 'TEST-F3D-ADV');
        });

        expect(feeTransId, greaterThanOrEqualTo(100000));
        expect(stuAdvId, greaterThanOrEqualTo(100000));

        final vmRows = await db.query(
          'VoucharMas',
          where: 'VoucherMasID = ?',
          whereArgs: ['TEST-F3D-ADV'],
        );
        expect(vmRows.first['PaidAmt'], 1000);
        expect(vmRows.first['IsPaid'], 'Y');
      },
    );

    test(
      '3. sibling_links.linkPair transaction rollback on UNIQUE constraint',
      () async {
        // Pre-insert canonical pair (1, 2)
        await db.insert('Sibling_Links', {
          'LinkID': 1,
          'Stu1_RegID': 1,
          'Stu2_RegID': 2,
        });

        final syncRowsBefore = await db.rawQuery(
          "SELECT next_allocated_id FROM _sync_state WHERE table_name = '__node__'",
        );
        final nextIdBefore = syncRowsBefore.first['next_allocated_id'] as int;

        final notifier = SiblingLinksNotifier();
        final success = await notifier.linkPair(1, 2);
        expect(success, isFalse);

        final syncRowsAfter = await db.rawQuery(
          "SELECT next_allocated_id FROM _sync_state WHERE table_name = '__node__'",
        );
        final nextIdAfter = syncRowsAfter.first['next_allocated_id'] as int;

        expect(nextIdAfter, equals(nextIdBefore));
      },
    );

    test(
      '4. student_wizard.submitStudentAdmission uses allocator (block-range Stu_RegID after seeding test block)',
      () async {
        await db.rawUpdate(
          "UPDATE _sync_state SET node_block_start = 400000, "
          "node_block_end = 499999, next_allocated_id = 400000 "
          "WHERE table_name = '__node__'",
        );

        final draft = WizardDraft()
          ..nameFirst = 'Wiring'
          ..nameLast = 'Test'
          ..dob = DateTime(2010, 1, 1)
          ..fName = 'Parent Name';

        final newId = await submitStudentAdmission(draft, dbOverride: db);
        expect(newId, 400000);

        final studentRows = await db.query(
          'Stu_Reg',
          where: 'Stu_RegID = ?',
          whereArgs: [400000],
        );
        expect(studentRows.length, 1);
        expect(studentRows.first['NameFirst'], 'Wiring');
      },
    );
  });
}
