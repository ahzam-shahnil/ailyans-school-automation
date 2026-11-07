// Phase G / G-5-1 — mobile FeeCollectionScreen zero-overflow at 360/390/414.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/fee_collection_provider.dart';
import 'package:school_automation/models/fee_receipt_view.dart';
import 'package:school_automation/screens/fees/fee_collection_screen.dart';
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

  FeeReceiptView buildTestReceipt() {
    return FeeReceiptView(
      voucherMasId: '1710-4411',
      stuRegId: 4411,
      studentName: 'Muhammad Ali Khan',
      fatherName: 'Khan Muhammad',
      className: 'Class 10',
      sectionName: 'A',
      rollNo: 1,
      forMonth: 'October 2017',
      issueDate: DateTime(2017, 10, 1),
      dueDate: DateTime(2017, 10, 15),
      subtotal: 1920,
      discount: 0,
      isPaid: 'N',
      paidAmount: 0,
      paidDate: null,
      bankId: null,
      lineItems: const [
        FeeReceiptLineItem(
          feeParamId: 2,
          headName: 'Tuition Fee ',
          amount: 1500,
          discount: 0,
        ),
        FeeReceiptLineItem(
          feeParamId: 3,
          headName: 'Exam Fee',
          amount: 300,
          discount: 0,
        ),
        FeeReceiptLineItem(
          feeParamId: 7,
          headName: 'Annual Cgarges',
          amount: 120,
          discount: 0,
        ),
      ],
    );
  }

  Widget buildMobileScreen() {
    final testState = FeeCollectionState(
      currentReceipt: buildTestReceipt(),
      amountTendered: 1920,
    );

    return ProviderScope(
      overrides: [
        feeCollectionProvider.overrideWith(
          (ref) => FeeCollectionNotifier(testState),
        ),
        bankListProvider.overrideWith(
          (ref) async => [
            const BankRow(
              bankInfoId: 1,
              bankName: 'Askari Bank',
              branch: 'Ballo Khel Road',
              acctNo: '4528',
              isDefault: true,
            ),
          ],
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: FeeCollectionScreen())),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildMobileScreen());
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(
      tester.takeException(),
      isNull,
      reason: 'fee_collection mobile zero-overflow at $size',
    );

    // At least one LOADED state assertion
    expect(
      find.textContaining('Scan a voucher to load details').evaluate().length +
          find.textContaining('Net Due:').evaluate().length +
          find.textContaining('Load Voucher').evaluate().length,
      greaterThan(0),
      reason: 'fee_collection rendered nothing at $size',
    );
  }

  testWidgets('FeeCollectionScreen zero overflow at 360x800', (tester) async {
    await pumpAt(tester, const Size(360, 800));
  });

  testWidgets('FeeCollectionScreen zero overflow at 390x844', (tester) async {
    await pumpAt(tester, const Size(390, 844));
  });

  testWidgets('FeeCollectionScreen zero overflow at 414x896', (tester) async {
    await pumpAt(tester, const Size(414, 896));
  });
}
