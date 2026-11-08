// Phase G / G-5 — unified 3-screen × 3-size loaded-state zero-overflow
// suite. Per-screen ProviderScope overrides are copied verbatim from the
// 3 per-screen G-5 test files. This suite exists to catch cross-screen
// regressions and to provide a single command for CI:
//
//   flutter test test/mobile_g5_test.dart
//
// The 3 per-screen files remain for focused debugging.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/clock_provider.dart';
import 'package:school_automation/core/providers/fee_collection_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/voucher_generation_provider.dart';
import 'package:school_automation/models/fee_receipt_view.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/models/voucher_preview_row.dart';
import 'package:school_automation/screens/fees/fee_collection_screen.dart';
import 'package:school_automation/screens/fees/fee_ledger_screen.dart';
import 'package:school_automation/screens/fees/voucher_generation_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  const testUser = User(
    id: 1,
    name: 'Administrator',
    designation: 'Principal',
    password: 'securepassword123',
    userLevel: 1,
    isActive: true,
  );

  const testMetadata = ShellMetadata(
    branchName: "Ailyan's Higher Secondary School Mianwali",
    branchAddress: 'Muslim Bazar Mianwali',
    branchPhone: '0459-234567',
    branchPrincipal: 'Prof. Muhammad Tariq',
    sessionYear: '2017-2018',
    studentCount: 10,
    classCount: 1,
    staffCount: 5,
    pendingVouchers: 2,
  );

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

  // Copied verbatim from test/mobile_g5_fee_collection_test.dart
  Widget wrapFeeCollection(Widget child) {
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
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  // Copied verbatim from test/mobile_g5_voucher_generation_test.dart
  Widget wrapVoucherGeneration(Widget child) {
    return ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2017, 10, 1)),
        availableSessionsProvider.overrideWith(
          (ref) async => ['2017-2018', '2026-27'],
        ),
        shellMetadataProvider.overrideWith(
          (ref) async => const ShellMetadata(
            branchName: "Ailyans's Higher Secondary School Mianwali",
            branchAddress: 'Muslim Bazar Mianwali',
            sessionYear: '2017-2018',
            studentCount: 0,
            classCount: 0,
            staffCount: 0,
            pendingVouchers: 0,
          ),
        ),
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
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  // Copied verbatim from test/mobile_g5_fee_ledger_test.dart
  Widget wrapFeeLedger(Widget child) {
    final router = GoRouter(
      initialLocation: '/fees/ledger',
      routes: [
        GoRoute(
          path: '/fees/ledger',
          builder: (context, state) => Scaffold(body: child),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) {
          final notifier = SessionNotifier();
          notifier.setSession(testUser, const [18]);
          return notifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  // Shared size parametrization
  const sizes = <Size>[Size(360, 800), Size(390, 844), Size(414, 896)];

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('G-5 unified mobile fees zero-overflow', () {
    for (final size in sizes) {
      testWidgets('FeeCollectionScreen loaded at $size', (tester) async {
        setSize(tester, size);
        await tester.pumpWidget(
          wrapFeeCollection(const FeeCollectionScreen()),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        expect(
          tester.takeException(),
          isNull,
          reason: 'fee_collection overflow at $size',
        );
        // At least one loaded-state marker:
        final markers =
            find.textContaining('Net Due:').evaluate().length +
            find.textContaining('Load Voucher').evaluate().length;
        expect(
          markers,
          greaterThan(0),
          reason: 'fee_collection rendered nothing at $size',
        );
      });

      testWidgets('VoucherGenerationScreen loaded at $size', (tester) async {
        setSize(tester, size);
        await tester.pumpWidget(
          wrapVoucherGeneration(const VoucherGenerationScreen()),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        expect(
          tester.takeException(),
          isNull,
          reason: 'voucher_generation overflow at $size',
        );
        final markers =
            find.textContaining('Batch Generation Parameters').evaluate().length +
            find.textContaining('Preview').evaluate().length;
        expect(
          markers,
          greaterThan(0),
          reason: 'voucher_generation rendered nothing at $size',
        );
      });

      testWidgets('FeeLedgerScreen loaded at $size', (tester) async {
        setSize(tester, size);
        await tester.pumpWidget(wrapFeeLedger(const FeeLedgerScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.takeException(),
          isNull,
          reason: 'fee_ledger overflow at $size',
        );
        expect(
          find.textContaining('GROSS RECEIVABLE').evaluate().length,
          greaterThan(0),
          reason: 'KPI visible at $size',
        );
        expect(
          find.textContaining('OUTSTANDING DUES').evaluate().length,
          greaterThan(0),
          reason: 'KPI visible at $size',
        );
        expect(
          find.textContaining('Showing').evaluate().length,
          greaterThan(0),
          reason: 'pagination footer visible at $size',
        );
        expect(
          find.byType(DataTable).evaluate().length,
          0,
          reason: 'no desktop DataTable at $size',
        );
      });
    }
  });
}
