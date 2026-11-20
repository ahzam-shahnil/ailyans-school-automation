import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/fee_collection_provider.dart';
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

    // Apply schema migrations, seeds, and fee tariffs
    await SchemaMigrations.migrate(db);
    await DatabaseSeeder.seedIfEmpty(db);
    await DatabaseSeeder.seedFeeTariffsIfEmpty(db);

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('Run F — Fee Collection Over-Payment & Double-Collect Guard Tests', () {
    test(
      'T1 (over-payment blocked): remaining = 4000, attempt 5000 -> rejected',
      () async {
        // Setup a clean voucher 2611-9001 with subtotal 4000, discount 0, paid 0, unpaid
        await db.insert('VoucharMas', {
          'VoucherMasID': '2611-9001',
          'VDate': '2026-11-01',
          'Student_Class_StuRegID': 4411,
          'ClassID': 13,
          'ForMonth': 'Nov-2026',
          'DueDate': '2026-11-10',
          'SessionYr': '2026-2027',
          'SubTotal': 4000,
          'Discount': 0,
          'IsPaid': 'N',
          'PaidAmt': 0,
          'PaidDate': null,
          'BankID': null,
        });
        await db.insert('VoucharDet', {
          'VoucharDetID': 90011,
          'VoucharMasID': '2611-9001',
          'feeParameterID': 2,
          'Amount': 4000,
          'Discount': 0,
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(feeCollectionProvider.notifier)
            .lookupVoucher('2611-9001');

        var state = container.read(feeCollectionProvider);
        expect(state.currentReceipt, isNotNull);
        expect(state.currentReceipt!.remainingBalance, 4000);
        expect(state.selectedBankId, isNotNull);

        // Attempt over-payment of 5000
        container.read(feeCollectionProvider.notifier).setAmountTendered(5000);
        final success = await container
            .read(feeCollectionProvider.notifier)
            .postPayment();

        expect(success, isFalse);

        state = container.read(feeCollectionProvider);
        expect(
          state.postError,
          contains('exceeds remaining balance of Rs. 4000'),
        );
        expect(state.postError, isNot(contains('Bad state:')));

        // Verify DB state is pristine
        final vRows = await db.query(
          'VoucharMas',
          where: "VoucherMasID = '2611-9001'",
        );
        expect(vRows.first['PaidAmt'], 0);
        expect(vRows.first['IsPaid'], 'N');

        final txRows = await db.query(
          'FeeTransaction',
          where: "VoucharNo = '2611-9001'",
        );
        expect(txRows, isEmpty);
      },
    );

    test(
      'T2 (already-paid blocked): IsPaid = "Y", attempt 100 -> rejected',
      () async {
        await db.insert('VoucharMas', {
          'VoucherMasID': '2611-9002',
          'VDate': '2026-11-01',
          'Student_Class_StuRegID': 4411,
          'ClassID': 13,
          'ForMonth': 'Nov-2026',
          'DueDate': '2026-11-10',
          'SessionYr': '2026-2027',
          'SubTotal': 3000,
          'Discount': 0,
          'IsPaid': 'Y',
          'PaidAmt': 3000,
          'PaidDate': '2026-11-20',
          'BankID': 1,
        });
        await db.insert('VoucharDet', {
          'VoucharDetID': 90021,
          'VoucharMasID': '2611-9002',
          'feeParameterID': 2,
          'Amount': 3000,
          'Discount': 0,
        });
        await db.insert('FeeTransaction', {
          'FeeTransID': 900201,
          'BankID': 1,
          'SubmissionDate': '2026-11-20',
          'VoucharNo': '2611-9002',
          'TotalAmount': 3000,
          'PaidAmount': 3000,
          'Detail': 'Initial full payment',
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(feeCollectionProvider.notifier)
            .lookupVoucher('2611-9002');

        final stateBefore = container.read(feeCollectionProvider);
        expect(stateBefore.currentReceipt, isNotNull);
        expect(stateBefore.currentReceipt!.isPaid, 'Y');

        container.read(feeCollectionProvider.notifier).setAmountTendered(100);
        final success = await container
            .read(feeCollectionProvider.notifier)
            .postPayment();

        expect(success, isFalse);

        final stateAfter = container.read(feeCollectionProvider);
        expect(stateAfter.postError, contains('already fully paid'));
        expect(stateAfter.postError, isNot(contains('Bad state:')));

        // Verify FeeTransaction count remains exactly 1
        final txRows = await db.query(
          'FeeTransaction',
          where: "VoucharNo = '2611-9002'",
        );
        expect(txRows.length, 1);
        expect(txRows.first['PaidAmount'], 3000);

        final vRows = await db.query(
          'VoucharMas',
          where: "VoucherMasID = '2611-9002'",
        );
        expect(vRows.first['PaidAmt'], 3000);
        expect(vRows.first['IsPaid'], 'Y');
      },
    );

    test('T3 (partial + exact final succeeds, 3rd attempt rejected)', () async {
      await db.insert('VoucharMas', {
        'VoucherMasID': '2611-9003',
        'VDate': '2026-11-01',
        'Student_Class_StuRegID': 4411,
        'ClassID': 13,
        'ForMonth': 'Nov-2026',
        'DueDate': '2026-11-10',
        'SessionYr': '2026-2027',
        'SubTotal': 4000,
        'Discount': 0,
        'IsPaid': 'N',
        'PaidAmt': 0,
        'PaidDate': null,
        'BankID': null,
      });
      await db.insert('VoucharDet', {
        'VoucharDetID': 90031,
        'VoucharMasID': '2611-9003',
        'feeParameterID': 2,
        'Amount': 4000,
        'Discount': 0,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Partial payment 1500
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('2611-9003');
      container.read(feeCollectionProvider.notifier).setAmountTendered(1500);
      final firstSuccess = await container
          .read(feeCollectionProvider.notifier)
          .postPayment();
      expect(firstSuccess, isTrue);

      var vRows = await db.query(
        'VoucharMas',
        where: "VoucherMasID = '2611-9003'",
      );
      expect(vRows.first['PaidAmt'], 1500);
      expect(vRows.first['IsPaid'], 'N');

      // 2. Exact final payment 2500
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('2611-9003');
      var state = container.read(feeCollectionProvider);
      expect(state.currentReceipt!.remainingBalance, 2500);
      expect(state.amountTendered, 2500);

      final secondSuccess = await container
          .read(feeCollectionProvider.notifier)
          .postPayment();
      expect(secondSuccess, isTrue);

      vRows = await db.query('VoucharMas', where: "VoucherMasID = '2611-9003'");
      expect(vRows.first['PaidAmt'], 4000);
      expect(vRows.first['IsPaid'], 'Y');

      final txRows = await db.query(
        'FeeTransaction',
        where: "VoucharNo = '2611-9003'",
        orderBy: 'FeeTransID ASC',
      );
      expect(txRows.length, 2);
      expect(txRows[0]['PaidAmount'], 1500);
      expect(txRows[1]['PaidAmount'], 2500);

      // 3. 3rd attempt of 100 on now fully paid voucher -> rejected
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('2611-9003');
      container.read(feeCollectionProvider.notifier).setAmountTendered(100);
      final thirdSuccess = await container
          .read(feeCollectionProvider.notifier)
          .postPayment();
      expect(thirdSuccess, isFalse);

      state = container.read(feeCollectionProvider);
      expect(state.postError, contains('already fully paid'));
      expect(state.postError, isNot(contains('Bad state:')));

      // Transaction count still 2
      final txRowsFinal = await db.query(
        'FeeTransaction',
        where: "VoucharNo = '2611-9003'",
      );
      expect(txRowsFinal.length, 2);
    });

    test('T4 (zero / negative blocked)', () async {
      await db.insert('VoucharMas', {
        'VoucherMasID': '2611-9004',
        'VDate': '2026-11-01',
        'Student_Class_StuRegID': 4411,
        'ClassID': 13,
        'ForMonth': 'Nov-2026',
        'DueDate': '2026-11-10',
        'SessionYr': '2026-2027',
        'SubTotal': 2000,
        'Discount': 0,
        'IsPaid': 'N',
        'PaidAmt': 0,
        'PaidDate': null,
        'BankID': null,
      });
      await db.insert('VoucharDet', {
        'VoucharDetID': 90041,
        'VoucharMasID': '2611-9004',
        'feeParameterID': 2,
        'Amount': 2000,
        'Discount': 0,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Zero amount
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('2611-9004');
      container.read(feeCollectionProvider.notifier).setAmountTendered(0);
      final zeroSuccess = await container
          .read(feeCollectionProvider.notifier)
          .postPayment();
      expect(zeroSuccess, isFalse);

      var state = container.read(feeCollectionProvider);
      expect(state.postError, contains('must be greater than zero'));

      // Negative amount
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('2611-9004');
      container.read(feeCollectionProvider.notifier).setAmountTendered(-500);
      final negSuccess = await container
          .read(feeCollectionProvider.notifier)
          .postPayment();
      expect(negSuccess, isFalse);

      state = container.read(feeCollectionProvider);
      expect(state.postError, contains('must be greater than zero'));

      // Verify 0 transactions in DB
      final txRows = await db.query(
        'FeeTransaction',
        where: "VoucharNo = '2611-9004'",
      );
      expect(txRows, isEmpty);
    });

    test(
      'T5 (transaction-level DB guard catches stale-memory overpayment)',
      () async {
        await db.insert('VoucharMas', {
          'VoucherMasID': '2611-9005',
          'VDate': '2026-11-01',
          'Student_Class_StuRegID': 4411,
          'ClassID': 13,
          'ForMonth': 'Nov-2026',
          'DueDate': '2026-11-10',
          'SessionYr': '2026-2027',
          'SubTotal': 4000,
          'Discount': 0,
          'IsPaid': 'N',
          'PaidAmt': 0,
          'PaidDate': null,
          'BankID': null,
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // 1. Look up voucher when remaining = 4000
        await container
            .read(feeCollectionProvider.notifier)
            .lookupVoucher('2611-9005');
        final state = container.read(feeCollectionProvider);
        expect(state.currentReceipt!.remainingBalance, 4000);

        // 2. Simulate concurrent out-of-band payment in DB (e.g. sync or another teller paying 3500)
        await db.update('VoucharMas', {
          'PaidAmt': 3500,
        }, where: "VoucherMasID = '2611-9005'");

        // 3. User attempts to tender 4000 based on stale in-memory receipt
        container.read(feeCollectionProvider.notifier).setAmountTendered(4000);
        final success = await container
            .read(feeCollectionProvider.notifier)
            .postPayment();

        expect(success, isFalse);

        final stateAfter = container.read(feeCollectionProvider);
        expect(
          stateAfter.postError,
          contains('exceeds remaining balance of Rs. 500'),
        );
        expect(stateAfter.postError, isNot(contains('Bad state:')));

        // PaidAmt in DB remains 3500 (not corrupted or overwritten)
        final vRows = await db.query(
          'VoucharMas',
          where: "VoucherMasID = '2611-9005'",
        );
        expect(vRows.first['PaidAmt'], 3500);
        expect(vRows.first['IsPaid'], 'N');
      },
    );
  });
}
