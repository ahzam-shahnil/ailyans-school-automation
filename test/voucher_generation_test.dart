import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/voucher_generation_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/voucher_preview_row.dart';
import 'package:school_automation/screens/fees/voucher_generation_screen.dart';
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

    // Clean up any pre-seeded October vouchers so cohort generation tests are isolated
    await db.delete('VoucharDet', where: "VoucharMasID LIKE '1710-%'");
    await db.delete('VoucharMas', where: "ForMonth = 'October 2017'");

    // Mark previous September vouchers as paid by default so baseline arrears are 0
    await db.rawUpdate("UPDATE VoucharMas SET IsPaid = 'Y'");

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('Phase D Step 8 — VoucherGenerationScreen & Batch Engine Tests', () {
    // 4a: Preview for Class 10 (10 students) returns 10 rows,
    // subtotal=1920 (1500+300+120), netPayable=1920.
    test('4a. Preview for Class 10 returns 10 rows, subtotal=1920, netPayable=1920', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default filter selects Class 10 (id 13) for October 2017
      container.read(voucherGenFiltersProvider.notifier).setClassId(13);

      final previewRows = await container.read(
        voucherGenPreviewProvider.future,
      );

      expect(previewRows.length, 10);
      for (final row in previewRows) {
        expect(row.subtotal, 1920); // 1500 + 300 + 120
        expect(row.arrears, 0);
        expect(row.discount, 0);
        expect(row.netPayable, 1920);
        expect(row.status, VoucherPreviewStatus.ready);
        expect(row.voucherId.startsWith('1710-'), isTrue);
        expect(row.voucherId.startsWith('#'), isFalse);
      }
    });

    // 4b: Full-discount student (temporarily set FullDiscount=1 in test setup)
    // -> status=fullWaiver, discount=1500, netPayable=420.
    test('4b. Full-discount student -> status=fullWaiver, discount=1500, netPayable=420', () async {
      // Pick student 4415 (Usman Tariq) and set FullDiscount = 1
      await db.rawUpdate(
        'UPDATE Stu_Reg SET FullDiscount = 1 WHERE Stu_RegID = 4415',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(voucherGenFiltersProvider.notifier).setClassId(13);

      final previewRows = await container.read(
        voucherGenPreviewProvider.future,
      );
      final usman = previewRows.firstWhere((r) => r.stuRegId == 4415);

      expect(usman.subtotal, 1920);
      expect(usman.discount, 1500); // 100% Tuition Fee waiver (Head #2)
      expect(
        usman.netPayable,
        420,
      ); // 1920 - 1500 = 420 (Exam + Annual Charges)
      expect(usman.status, VoucherPreviewStatus.fullWaiver);
    });

    // 4c: Duplicate prevention: pre-insert a VoucharMas row for 1710-4411,
    // verify preview shows status=alreadyGenerated for 4411.
    test(
      '4c. Duplicate prevention: pre-inserted 1710-4411 shows alreadyGenerated',
      () async {
        await db.insert('VoucharMas', {
          'VoucherMasID': '1710-4411',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4411,
          'ClassID': 13,
          'SubTotal': 1920,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(voucherGenFiltersProvider.notifier).setClassId(13);

        final previewRows = await container.read(
          voucherGenPreviewProvider.future,
        );
        final student4411 = previewRows.firstWhere((r) => r.stuRegId == 4411);

        expect(student4411.status, VoucherPreviewStatus.alreadyGenerated);
        expect(student4411.skipReason, 'Already generated');

        // Other 9 students should still be ready
        final otherStudents = previewRows
            .where((r) => r.stuRegId != 4411)
            .toList();
        expect(otherStudents.length, 9);
        for (final row in otherStudents) {
          expect(row.status, VoucherPreviewStatus.ready);
        }
      },
    );

    // 4d: Execute for Class 10 cohort: transaction commits 10 VoucharMas rows
    // and 30 VoucharDet rows (3 heads × 10). SessionYr='2017-2018'.
    test('4d. Execute for Class 10 cohort commits 10 VoucharMas and 30 VoucharDet rows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(voucherGenFiltersProvider.notifier).setClassId(13);

      // Pre-warm preview
      await container.read(voucherGenPreviewProvider.future);

      // Execute batch generation
      final summary = await container
          .read(voucherGenExecutionProvider.notifier)
          .generateVouchers();

      expect(summary, isNotNull);
      expect(summary!.generatedCount, 10);
      expect(summary.skippedCount, 0);
      expect(summary.totalBilled, 19200); // 10 × 1920

      // Verify VoucharMas committed rows
      final masRows = await db.rawQuery(
        "SELECT * FROM VoucharMas WHERE ForMonth = 'October 2017'",
      );
      expect(masRows.length, 10);
      for (final row in masRows) {
        expect(row['SessionYr'], '2017-2018');
        expect(row['IsPaid'], 'N');
        expect(row['ClassID'], 13);
        expect((row['VoucherMasID'] as String).startsWith('1710-'), isTrue);
        expect((row['VoucherMasID'] as String).startsWith('#'), isFalse);
      }

      // Verify VoucharDet committed rows
      final detRows = await db.rawQuery(
        "SELECT * FROM VoucharDet WHERE VoucharMasID LIKE '1710-%'",
      );
      expect(detRows.length, 30); // 3 tariff heads × 10 students

      // Detail checks for 1710-4411
      final det4411 = await db.rawQuery(
        "SELECT * FROM VoucharDet WHERE VoucharMasID = '1710-4411' ORDER BY feeParameterID ASC",
      );
      expect(det4411.length, 3);
      expect(det4411[0]['feeParameterID'], 2); // Tuition Fee
      expect(det4411[0]['Amount'], 1500.0);
      expect(det4411[1]['feeParameterID'], 3); // Exam Fee
      expect(det4411[1]['Amount'], 300.0);
      expect(det4411[2]['feeParameterID'], 7); // Annual Charges
      expect(det4411[2]['Amount'], 120.0);
    });

    // 4e: Arrears rollover: mark one student's existing Sep-2017 voucher IsPaid='O',
    // run generation, verify new Oct voucher has a FeeParamID=4 line item.
    test('4e. Arrears rollover marks prior as O and injects FeeParamID=4 detail row', () async {
      // Setup: mark student 4411's existing Sep-2017 voucher as IsPaid = 'O' with SubTotal=1800
      await db.rawUpdate(
        "UPDATE VoucharMas SET IsPaid = 'O', SubTotal = 1800, Discount = 0 "
        "WHERE VoucherMasID = '1709-4411'",
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(voucherGenFiltersProvider.notifier).setClassId(13);

      // Verify preview recognizes arrears rollover
      final previewRows = await container.read(
        voucherGenPreviewProvider.future,
      );
      final student4411 = previewRows.firstWhere((r) => r.stuRegId == 4411);

      expect(student4411.status, VoucherPreviewStatus.arrearsRollover);
      expect(student4411.subtotal, 1920);
      expect(student4411.arrears, 1800);
      expect(student4411.netPayable, 3720); // 1920 + 1800

      // Run generation
      await container
          .read(voucherGenExecutionProvider.notifier)
          .generateVouchers();

      // Verify new Oct voucher 1710-4411 has FeeParamID = 4
      final arrearsDetail = await db.rawQuery(
        "SELECT * FROM VoucharDet WHERE VoucharMasID = '1710-4411' AND feeParameterID = 4",
      );
      expect(arrearsDetail.length, 1);
      expect(arrearsDetail.first['Amount'], 1800.0);

      // Verify total detail rows for 1710-4411 is now 4 (3 tariffs + 1 arrears)
      final allDet4411 = await db.rawQuery(
        "SELECT * FROM VoucharDet WHERE VoucharMasID = '1710-4411'",
      );
      expect(allDet4411.length, 4);

      // Verify prior Sep voucher is marked 'O'
      final sepVoucher = await db.rawQuery(
        "SELECT IsPaid FROM VoucharMas WHERE VoucherMasID = '1709-4411'",
      );
      expect(sepVoucher.first['IsPaid'], 'O');
    });

    // Widget UI Test: Verify rendering of VoucherGenerationScreen
    testWidgets(
      'UI renders VoucherGenerationScreen with 40/60 split, table, and KPI strip',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              classesProvider.overrideWith(
                (ref) async => [
                  const SchoolClass(classId: 13, cName: 'Class 10'),
                ],
              ),
              sectionsProvider.overrideWith(
                (ref) async => [
                  const ClassSec(classSecId: 1, classId: 13, secName: 'A'),
                ],
              ),
              voucherBankListProvider.overrideWith(
                (ref) async => [
                  const BankOption(
                    bankInfoId: 1,
                    bankName: 'Askari Bank',
                    branch: 'Ballo Khel Road',
                    acctNo: '4528',
                    isDefault: true,
                  ),
                ],
              ),
              voucherClassTariffsProvider(13).overrideWith(
                (ref) async => [
                  const FeeHeadSummary(
                    feeParamId: 2,
                    description: 'Tuition Fee ',
                    fee: 1500.0,
                  ),
                  const FeeHeadSummary(
                    feeParamId: 3,
                    description: 'Exam Fee',
                    fee: 300.0,
                  ),
                  const FeeHeadSummary(
                    feeParamId: 7,
                    description: 'Annual Cgarges',
                    fee: 120.0,
                  ),
                ],
              ),
              voucherGenPreviewProvider.overrideWith(
                (ref) async => [
                  const VoucherPreviewRow(
                    stuRegId: 4411,
                    studentName: 'Muhammad Ali Khan',
                    subtotal: 1920,
                    arrears: 0,
                    discount: 0,
                    netPayable: 1920,
                    status: VoucherPreviewStatus.ready,
                    voucherId: '1710-4411',
                  ),
                ],
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: VoucherGenerationScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Header verification
        expect(find.text('Monthly Voucher Generation Engine'), findsOneWidget);
        expect(find.text('Batch Generation Parameters'), findsOneWidget);
        expect(
          find.text('Cohort Billing Audit & Ledger Preview'),
          findsOneWidget,
        );

        // KPI card titles
        expect(find.text('Eligible Students'), findsOneWidget);
        expect(find.text('Full Tuition Waiver'), findsOneWidget);
        expect(find.text('Estimated Net Billed'), findsOneWidget);

        // Table headers
        expect(find.text('Voucher ID'), findsOneWidget);
        expect(find.text('Student Name'), findsOneWidget);
        expect(find.text('SubTotal (Rs)'), findsOneWidget);
        expect(find.text('Arrears'), findsOneWidget);
        expect(find.text('Discount'), findsOneWidget);
        expect(find.text('Net Pay (Rs)'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);

        // Verify at least one voucher ID rendered without leading '#'
        expect(find.text('1710-4411'), findsOneWidget);
        expect(find.text('#1710-4411'), findsNothing);

        // Verify Generate button is present
        expect(find.textContaining('Generate'), findsWidgets);
      },
    );

    // Fix 4: Layout regression — screen must fit 1440×900 without overflow
    testWidgets('VoucherGenerationScreen fits 1440x900 without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classesProvider.overrideWith(
              (ref) async => [
                const SchoolClass(classId: 13, cName: 'Class 10'),
              ],
            ),
            sectionsProvider.overrideWith(
              (ref) async => [
                const ClassSec(classSecId: 1, classId: 13, secName: 'A'),
              ],
            ),
            voucherBankListProvider.overrideWith(
              (ref) async => [
                const BankOption(
                  bankInfoId: 1,
                  bankName: 'Askari Bank',
                  branch: 'Ballo Khel Road',
                  acctNo: '4528',
                  isDefault: true,
                ),
              ],
            ),
            voucherClassTariffsProvider(13).overrideWith(
              (ref) async => [
                const FeeHeadSummary(
                  feeParamId: 2,
                  description: 'Tuition Fee ',
                  fee: 1500.0,
                ),
                const FeeHeadSummary(
                  feeParamId: 3,
                  description: 'Exam Fee',
                  fee: 300.0,
                ),
                const FeeHeadSummary(
                  feeParamId: 7,
                  description: 'Annual Cgarges',
                  fee: 120.0,
                ),
              ],
            ),
            voucherGenPreviewProvider.overrideWith(
              (ref) async => List.generate(
                10,
                (i) => VoucherPreviewRow(
                  stuRegId: 4411 + i,
                  studentName: 'Student ${4411 + i}',
                  subtotal: 1920,
                  arrears: 0,
                  discount: 0,
                  netPayable: 1920,
                  status: VoucherPreviewStatus.ready,
                  voucherId: '1710-${4411 + i}',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VoucherGenerationScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No overflow exception should have been thrown
      expect(tester.takeException(), isNull);

      // Generate button must be visible without scrolling
      expect(find.textContaining('Generate'), findsWidgets);

      // Table headers visible
      expect(find.text('Voucher ID'), findsOneWidget);
      expect(find.text('Student Name'), findsOneWidget);
    });

    testWidgets(
      'Numeric columns render full Rs amounts without truncation at 1440×900',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final readyKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              classesProvider.overrideWith(
                (ref) async => [
                  const SchoolClass(classId: 13, cName: 'Class 10'),
                ],
              ),
              sectionsProvider.overrideWith(
                (ref) async => [
                  const ClassSec(classSecId: 1, classId: 13, secName: 'A'),
                ],
              ),
              voucherBankListProvider.overrideWith(
                (ref) async => [
                  const BankOption(
                    bankInfoId: 1,
                    bankName: 'Askari Bank',
                    branch: 'Ballo Khel Road',
                    acctNo: '4528',
                    isDefault: true,
                  ),
                ],
              ),
              voucherClassTariffsProvider(13).overrideWith(
                (ref) async => [
                  const FeeHeadSummary(
                    feeParamId: 2,
                    description: 'Tuition Fee ',
                    fee: 1500.0,
                  ),
                  const FeeHeadSummary(
                    feeParamId: 3,
                    description: 'Exam Fee',
                    fee: 300.0,
                  ),
                  const FeeHeadSummary(
                    feeParamId: 7,
                    description: 'Annual Cgarges',
                    fee: 120.0,
                  ),
                ],
              ),
              voucherGenPreviewProvider.overrideWith(
                (ref) async => List.generate(
                  10,
                  (i) => VoucherPreviewRow(
                    stuRegId: 4411 + i,
                    studentName: 'Student ${4411 + i}',
                    subtotal: 1920,
                    arrears: 0,
                    discount: 0,
                    netPayable: 1920,
                    status: VoucherPreviewStatus.ready,
                    voucherId: '1710-${4411 + i}',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: RepaintBoundary(
                key: readyKey,
                child: const Scaffold(body: VoucherGenerationScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Capture Screenshot 1: vouchers-ready-equalized.png
        await tester.runAsync(() async {
          final boundary =
              readyKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.0);
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final buffer = byteData!.buffer.asUint8List();
          const outDir =
              '/Users/ahzam/flutter_projects/REA/rebuild/design/phase-d-runtime';
          await Directory(outDir).create(recursive: true);
          await File('$outDir/vouchers-ready-equalized.png')
              .writeAsBytes(buffer);
        });

        // No truncation ellipsis on numeric cells
        expect(find.textContaining('Rs. 1,9...'), findsNothing);
        expect(
          find.textContaining('...'),
          findsNothing,
          reason: 'Numeric cells must not truncate; use flex + compact format',
        );
        // KPI must show either Rs. 0 (pre-generation) or Rs. 19,200 (post)
        expect(
          find.textContaining('Rs.'),
          findsWidgets,
          reason: 'KPI label renders with Rs. prefix',
        );
      },
    );

    testWidgets('Capture vouchers-generated-compact.png at 1440x900', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final generatedKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classesProvider.overrideWith(
              (ref) async => [
                const SchoolClass(classId: 13, cName: 'Class 10'),
              ],
            ),
            sectionsProvider.overrideWith(
              (ref) async => [
                const ClassSec(classSecId: 1, classId: 13, secName: 'A'),
              ],
            ),
            voucherBankListProvider.overrideWith(
              (ref) async => [
                const BankOption(
                  bankInfoId: 1,
                  bankName: 'Askari Bank',
                  branch: 'Ballo Khel Road',
                  acctNo: '4528',
                  isDefault: true,
                ),
              ],
            ),
            voucherClassTariffsProvider(13).overrideWith(
              (ref) async => [
                const FeeHeadSummary(
                  feeParamId: 2,
                  description: 'Tuition Fee ',
                  fee: 1500.0,
                ),
                const FeeHeadSummary(
                  feeParamId: 3,
                  description: 'Exam Fee',
                  fee: 300.0,
                ),
                const FeeHeadSummary(
                  feeParamId: 7,
                  description: 'Annual Cgarges',
                  fee: 120.0,
                ),
              ],
            ),
            voucherGenPreviewProvider.overrideWith(
              (ref) async => List.generate(
                10,
                (i) => VoucherPreviewRow(
                  stuRegId: 4411 + i,
                  studentName: 'Student ${4411 + i}',
                  subtotal: 1920,
                  arrears: 0,
                  discount: 0,
                  netPayable: 1920,
                  status: VoucherPreviewStatus.alreadyGenerated,
                  voucherId: '1710-${4411 + i}',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: generatedKey,
              child: const Scaffold(body: VoucherGenerationScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Capture Screenshot 2: vouchers-generated-compact.png
      await tester.runAsync(() async {
        final boundary =
            generatedKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final buffer = byteData!.buffer.asUint8List();
        const outDir =
            '/Users/ahzam/flutter_projects/REA/rebuild/design/phase-d-runtime';
        await Directory(outDir).create(recursive: true);
        await File('$outDir/vouchers-generated-compact.png')
            .writeAsBytes(buffer);
      });

      // Verify post-generation KPI text is rendered
      expect(find.text('Cohort Total Billed'), findsOneWidget);
      expect(find.text('Print 10 Vouchers (Ctrl+P)'), findsOneWidget);
    });
  });
}
