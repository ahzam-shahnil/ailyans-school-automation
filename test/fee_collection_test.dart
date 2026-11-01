import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/fee_collection_provider.dart';
import 'package:school_automation/core/utils/receipt_pdf_generator.dart' as rcp;
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

    // Ensure 1710-4411 has exactly 3 line items (Tuition 1500, Exam 300, Annual 120 -> subtotal 1920)
    await db.delete('FeeTransaction', where: "VoucharNo = '1710-4411'");
    await db.delete('VoucharDet', where: "VoucharMasID = '1710-4411'");
    await db.update('VoucharMas', {
      'SubTotal': 1920,
      'Discount': 0,
      'IsPaid': 'N',
      'PaidAmt': 0,
      'PaidDate': null,
      'BankID': null,
    }, where: "VoucherMasID = '1710-4411'");
    await db.insert('VoucharDet', {
      'VoucharDetID': 101,
      'VoucharMasID': '1710-4411',
      'feeParameterID': 2,
      'Amount': 1500,
      'Discount': 0,
    });
    await db.insert('VoucharDet', {
      'VoucharDetID': 102,
      'VoucharMasID': '1710-4411',
      'feeParameterID': 3,
      'Amount': 300,
      'Discount': 0,
    });
    await db.insert('VoucharDet', {
      'VoucharDetID': 103,
      'VoucharMasID': '1710-4411',
      'feeParameterID': 7,
      'Amount': 120,
      'Discount': 0,
    });

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('Phase D Step 9 — FeeCollectionScreen & Settlement Engine Tests', () {
    test('1. lookupVoucher(1710-4411) loads receipt with 3 line items & subtotal 1920', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('1710-4411');
      final state = container.read(feeCollectionProvider);

      expect(state.lookupError, isNull);
      expect(state.currentReceipt, isNotNull);
      final receipt = state.currentReceipt!;

      expect(receipt.voucherMasId, '1710-4411');
      expect(receipt.stuRegId, 4411);
      expect(receipt.subtotal, 1920);
      expect(receipt.discount, 0);
      expect(receipt.netPayable, 1920);
      expect(receipt.lineItems.length, 3);
      expect(receipt.lineItems[0].feeParamId, 2);
      expect(receipt.lineItems[0].amount, 1500);
      expect(receipt.lineItems[1].feeParamId, 3);
      expect(receipt.lineItems[1].amount, 300);
      expect(receipt.lineItems[2].feeParamId, 7);
      expect(receipt.lineItems[2].amount, 120);
      expect(receipt.isFullyPaid, isFalse);
    });

    test('2. lookupVoucher(4411) falls back to most recent unpaid for that student', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('4411');
      final state = container.read(feeCollectionProvider);

      expect(state.lookupError, isNull);
      expect(state.currentReceipt, isNotNull);
      expect(state.currentReceipt!.stuRegId, 4411);
      expect(state.currentReceipt!.voucherMasId, '1710-4411');
      expect(state.currentReceipt!.isFullyPaid, isFalse);
    });

    test(
      '3. lookupVoucher(9999-9999) sets lookupError = Voucher not found',
      () async {
        final container = ProviderContainer(
          overrides: [
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
        );
        addTearDown(container.dispose);

        await container
            .read(feeCollectionProvider.notifier)
            .lookupVoucher('9999-9999');
        final state = container.read(feeCollectionProvider);

        expect(state.lookupError, 'Voucher not found');
        expect(state.currentReceipt, isNull);
      },
    );

    test('4. postPayment() on unpaid voucher commits VoucharMas and FeeTransaction', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('1710-4411');
      final success = await container
          .read(feeCollectionProvider.notifier)
          .postPayment();

      expect(success, isTrue);

      // Verify VoucharMas update in DB
      final vRows = await db.query(
        'VoucharMas',
        where: "VoucherMasID = '1710-4411'",
      );
      expect(vRows.length, 1);
      final row = vRows.first;
      expect(row['IsPaid'], 'Y');
      expect(row['PaidAmt'], 1920);
      expect(row['PaidDate'], isNotNull);
      expect(row['BankID'], isNotNull);

      // Verify FeeTransaction insertion
      final txRows = await db.query(
        'FeeTransaction',
        where: "VoucharNo = '1710-4411'",
      );
      expect(txRows.length, 1);
      expect(txRows.first['PaidAmount'], 1920);
      expect(txRows.first['TotalAmount'], 1920);
    });

    test('5. postPayment() with advance credit applied sets PaidAmt = cash + advance (full settlement)', () async {
      // Insert advance deposit row in StuAdv
      await db.insert('StuAdv', {
        'StuAdvID': 1,
        'StuRegID': 4411,
        'AdvAmount': 500,
        'MOP': 'Cash',
        'Date': '2017-09-15',
        'DepositedBy': 'Father',
        'Detail': 'Advance tuition deposit',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('1710-4411');
      final state = container.read(feeCollectionProvider);

      expect(state.currentReceipt!.advanceBalance, 500);
      expect(state.useAdvanceCredit, isTrue);
      expect(state.amountTendered, 1420); // 1920 - 500

      final success = await container
          .read(feeCollectionProvider.notifier)
          .postPayment();
      expect(success, isTrue);

      // Verify VoucharMas PaidAmt is cash tendered
      final vRows = await db.query(
        'VoucharMas',
        where: "VoucherMasID = '1710-4411'",
      );
      expect(vRows.first['IsPaid'], 'Y');
      expect(
        vRows.first['PaidAmt'],
        1920,
      ); // Post-fix: cash 1420 + advance 500 = full settlement

      // Verify FeeTransaction PaidAmount
      final txRows = await db.query(
        'FeeTransaction',
        where: "VoucharNo = '1710-4411'",
      );
      expect(txRows.first['PaidAmount'], 1420);
    });

    test('6. revokePayment(wrongpass) returns wrongPassword and leaves DB unchanged', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Settle payment first
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('1710-4411');
      await container.read(feeCollectionProvider.notifier).postPayment();

      // Reload paid voucher
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('1710-4411');
      expect(
        container.read(feeCollectionProvider).currentReceipt!.isFullyPaid,
        isTrue,
      );

      // Attempt revoke with wrong password
      final result = await container
          .read(feeCollectionProvider.notifier)
          .revokePayment('wrongpass');

      expect(result, RevokeResult.wrongPassword);

      // Verify DB remains paid
      final vRows = await db.query(
        'VoucharMas',
        where: "VoucherMasID = '1710-4411'",
      );
      expect(vRows.first['IsPaid'], 'Y');
      expect(vRows.first['PaidAmt'], 1920);

      final txRows = await db.query(
        'FeeTransaction',
        where: "VoucharNo = '1710-4411'",
      );
      expect(txRows.length, 1);
    });

    test('7. revokePayment(zaidi110) succeeds: marks UNPAID and deletes FeeTransaction', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Settle payment first
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('1710-4411');
      await container.read(feeCollectionProvider.notifier).postPayment();

      // Reload paid voucher
      await container
          .read(feeCollectionProvider.notifier)
          .lookupVoucher('1710-4411');
      expect(
        container.read(feeCollectionProvider).currentReceipt!.isFullyPaid,
        isTrue,
      );

      // Revoke with correct supervisor password
      final result = await container
          .read(feeCollectionProvider.notifier)
          .revokePayment('zaidi110');

      expect(result, RevokeResult.success);

      // Verify VoucharMas rolled back
      final vRows = await db.query(
        'VoucharMas',
        where: "VoucherMasID = '1710-4411'",
      );
      expect(vRows.first['IsPaid'], 'N');
      expect(vRows.first['PaidAmt'], 0);
      expect(vRows.first['PaidDate'], isNull);

      // Verify FeeTransaction row deleted
      final txRows = await db.query(
        'FeeTransaction',
        where: "VoucharNo = '1710-4411'",
      );
      expect(txRows, isEmpty);
    });

    testWidgets(
      '8. Layout test: FeeCollectionScreen fits 1440x900 AND 1440x780 without overflow',
      (tester) async {
        // Test at 1440 x 900 (standard viewport)
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final testReceipt = FeeReceiptView(
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

        final testState = FeeCollectionState(
          currentReceipt: testReceipt,
          amountTendered: 1920,
        );

        await tester.pumpWidget(
          ProviderScope(
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
            child: const MaterialApp(
              home: Scaffold(body: FeeCollectionScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Zero overflow at 1440x900',
        );
        expect(find.text('Payment Settlement'), findsOneWidget);
        expect(find.text('Net Payable'), findsOneWidget);
        expect(find.text('Rs. 1,920'), findsWidgets);

        // Test at 1440 x 780 (password warning banner visible case)
        tester.view.physicalSize = const Size(1440, 780);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Zero overflow at 1440x780',
        );
      },
    );

    test(
      '9. Partial payment math (1300 / 1495) and empty line-items fallback',
      () async {
        // Insert historical voucher with SubTotal=1495, 0 VoucharDet items
        await db.insert('VoucharMas', {
          'VoucherMasID': '1803-4454',
          'VDate': '2018-03-01',
          'Student_Class_StuRegID': 4411,
          'ClassID': 13,
          'SubTotal': 1495,
          'Discount': 0,
          'PaidAmt': 0,
          'IsPaid': 'N',
          'ForMonth': 'Mar-2018',
          'DueDate': '2018-03-10',
          'SessionYr': '2017-2018',
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // 1. Lookup voucher with 0 VoucharDet rows -> synthesizes fallback line item
        await container
            .read(feeCollectionProvider.notifier)
            .lookupVoucher('1803-4454');
        var state = container.read(feeCollectionProvider);

        expect(state.lookupError, isNull);
        expect(state.currentReceipt, isNotNull);
        final receipt = state.currentReceipt!;
        expect(receipt.lineItems.length, 1);
        expect(
          receipt.lineItems.first.headName,
          'Consolidated Voucher Fee (Mar-2018)',
        );
        expect(receipt.lineItems.first.amount, 1495);
        expect(receipt.remainingBalance, 1495);

        // 2. Partial payment: operator enters 1300
        container.read(feeCollectionProvider.notifier).setAmountTendered(1300);
        final firstSuccess = await container
            .read(feeCollectionProvider.notifier)
            .postPayment();
        expect(firstSuccess, isTrue);

        // Verify DB after first payment: IsPaid = 'N', PaidAmt = 1300
        final v1 = await db.query(
          'VoucharMas',
          where: "VoucherMasID = '1803-4454'",
        );
        expect(v1.first['IsPaid'], 'N');
        expect(v1.first['PaidAmt'], 1300);

        final trans1 = await db.query(
          'FeeTransaction',
          where: "VoucharNo = '1803-4454'",
        );
        expect(trans1.length, 1);
        expect(trans1.first['PaidAmount'], 1300);

        // 3. Second lookup: pre-fills remaining balance of 195
        await container
            .read(feeCollectionProvider.notifier)
            .lookupVoucher('1803-4454');
        state = container.read(feeCollectionProvider);
        final partialReceipt = state.currentReceipt!;
        expect(partialReceipt.isPartiallyPaid, isTrue);
        expect(partialReceipt.isFullyPaid, isFalse);
        expect(partialReceipt.paidAmount, 1300);
        expect(partialReceipt.remainingBalance, 195);
        expect(state.amountTendered, 195);

        // 4. Pay remaining 195 -> settles voucher fully (IsPaid = 'Y', PaidAmt = 1495)
        final secondSuccess = await container
            .read(feeCollectionProvider.notifier)
            .postPayment();
        expect(secondSuccess, isTrue);

        final v2 = await db.query(
          'VoucharMas',
          where: "VoucherMasID = '1803-4454'",
        );
        expect(v2.first['IsPaid'], 'Y');
        expect(v2.first['PaidAmt'], 1495);

        final trans2 = await db.query(
          'FeeTransaction',
          where: "VoucharNo = '1803-4454'",
          orderBy: 'FeeTransID ASC',
        );
        expect(trans2.length, 2);
        expect(trans2[1]['PaidAmount'], 195);

        // Verify print data and PDF generation for settled installment voucher
        final printData = await container
            .read(feeCollectionProvider.notifier)
            .loadReceiptPrintData('1803-4454');
        expect(printData, isNotNull);
        expect(printData!.totalPaidToDate, 1495);
        expect(printData.remainingBalance, 0);
        expect(printData.previousPaidAmount, 1300);
        expect(printData.paidAmount, 195);
        expect(printData.paymentHistory.length, 1);

        final pdfBytes =
            await rcp.ReceiptPdfGenerator.generateThreeCopyReceipts(
              receipts: [printData],
              branchName: "Ailyans's Higher Secondary School",
              branchAddress: 'Muslim Bazar Mianwali',
            );
        expect(pdfBytes.length, greaterThan(1000));
      },
    );

    testWidgets(
      '10. Amount Tendered TextField is pre-filled with 195 when loading partially paid voucher',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        const partialReceipt = FeeReceiptView(
          voucherMasId: '1803-4454',
          stuRegId: 4411,
          studentName: 'Muhammad Ali Khan',
          fatherName: 'Khan Muhammad',
          className: 'Class 10',
          sectionName: 'A',
          forMonth: 'Mar-2018',
          subtotal: 1495,
          discount: 0,
          paidAmount: 1300,
          isPaid: 'N',
          lineItems: [
            FeeReceiptLineItem(
              feeParamId: 1,
              headName: 'Consolidated Voucher Fee (Mar-2018)',
              amount: 1495,
            ),
          ],
          paymentHistory: [
            VoucherPaymentInstallment(
              feeTransId: 101,
              submissionDate: '2026-10-31',
              paidAmount: 1300,
              bankName: 'Askari Bank',
            ),
          ],
        );

        const testState = FeeCollectionState(
          currentReceipt: partialReceipt,
          amountTendered: 195,
        );

        await tester.pumpWidget(
          ProviderScope(
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
            child: const MaterialApp(
              home: Scaffold(body: FeeCollectionScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Confirm TextField with Amount Tendered has '195'
        final amountFinder = find.widgetWithText(TextField, '195');
        expect(amountFinder, findsOneWidget);

        // 2. Verify partially paid banner and balance preview pill
        expect(find.textContaining('PARTIALLY PAID'), findsWidgets);
        expect(
          find.textContaining('Balance After This Payment: Rs. 0'),
          findsOneWidget,
        );

        // 3. Verify payment installment history rendered in left totals
        expect(
          find.textContaining('PAYMENT INSTALLMENT HISTORY (1)'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Receipt #101 (31-Oct-2026) - Askari Bank'),
          findsOneWidget,
        );

        // 4. Verify PDF generation for partial paid receipt
        final partialPrintData = rcp.FeeReceiptPrintData(
          feeTransId: 101,
          voucherMasId: '1803-4454',
          stuRegId: 4411,
          studentName: 'Muhammad Ali Khan',
          forMonth: 'Mar-2018',
          submissionDate: DateTime.now(),
          subtotal: 1495,
          discount: 0,
          totalAmount: 1495,
          paidAmount: 1300,
          totalPaidToDate: 1300,
          previousPaidAmount: 0,
          remainingBalance: 195,
          paymentMode: 'Cash',
          bankName: 'Askari Bank',
          lineItems: const [
            rcp.FeeReceiptLineItem(
              feeParamId: 1,
              headName: 'Consolidated Voucher Fee (Mar-2018)',
              amount: 1495,
            ),
          ],
        );
        final pdfBytes =
            await rcp.ReceiptPdfGenerator.generateThreeCopyReceipts(
              receipts: [partialPrintData],
              branchName: "Ailyans's Higher Secondary School",
              branchAddress: 'Muslim Bazar Mianwali',
            );
        expect(pdfBytes.length, greaterThan(1000));
      },
    );
  });
}
