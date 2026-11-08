// Phase G-9 Shot 1a — Mobile UX tests for FeeCollectionScreen and FeeLedgerScreen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/fee_collection_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/fee_receipt_view.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/fees/fee_collection_screen.dart';
import 'package:school_automation/screens/fees/fee_ledger_screen.dart';
import 'package:school_automation/widgets/mobile/mobile_kpi_card.dart';
import 'package:school_automation/widgets/mobile/mobile_status_pill.dart';
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
          headName: 'Tuition Fee',
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
          headName: 'Annual Charges',
          amount: 120,
          discount: 0,
        ),
      ],
    );
  }

  Widget buildFeeCollectionWidget({
    FeeReceiptView? receipt,
    List<FeeReceiptSummaryRow>? directoryRows,
  }) {
    final testState = FeeCollectionState(
      currentReceipt: receipt,
      amountTendered: receipt != null ? receipt.netPayable : 0,
      directoryRows: directoryRows ?? const [],
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
      child: const MaterialApp(home: FeeCollectionScreen()),
    );
  }

  Widget buildFeeLedgerWidget() {
    const screen = FeeLedgerScreen();
    final router = GoRouter(
      initialLocation: '/fees/ledger',
      routes: [
        GoRoute(
          path: '/fees/ledger',
          builder: (context, state) => const Scaffold(body: screen),
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

  testWidgets(
    'FeeCollectionScreen at 360x800 renders directory cards with MobileStatusPill and zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildFeeCollectionWidget(
          directoryRows: const [
            FeeReceiptSummaryRow(
              voucherMasId: '1710-4411',
              stuRegId: 4411,
              studentName: 'Muhammad Ali Khan',
              className: 'Class 10',
              sectionName: 'A',
              forMonth: 'October 2017',
              netPayable: 1920,
              isPaid: 'N',
            ),
            FeeReceiptSummaryRow(
              voucherMasId: '1710-4412',
              stuRegId: 4412,
              studentName: 'Zainab Bibi',
              className: 'Class 10',
              sectionName: 'A',
              forMonth: 'October 2017',
              netPayable: 1500,
              isPaid: 'Y',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MobileStatusPill), findsWidgets);
      expect(find.text('1710-4411'), findsOneWidget);
      expect(find.text('1710-4412'), findsOneWidget);
    },
  );

  testWidgets(
    'FeeCollectionScreen at 390x844 with loaded voucher renders Net Due summary and 48px settlement button with zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildFeeCollectionWidget(
          receipt: buildTestReceipt(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Net Due:'), findsWidgets);
      expect(find.textContaining('1,920'), findsWidgets);

      final buttonFinder = find.widgetWithText(
        ElevatedButton,
        'Post Payment (Ctrl+Enter)',
      );
      expect(buttonFinder, findsOneWidget);

      final RenderBox renderBox = tester.renderObject(buttonFinder);
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
    },
  );

  testWidgets(
    'FeeLedgerScreen at 360x800 renders 2x2 KPI grid and stacked mobile filter card with zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildFeeLedgerWidget());
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(MobileKpiCard), findsNWidgets(4));
      expect(find.text('GROSS RECEIVABLE'), findsOneWidget);
      expect(find.text('TOTAL CONCESSIONS'), findsOneWidget);
      expect(find.text('CASH COLLECTED'), findsOneWidget);
      expect(find.text('OUTSTANDING DUES'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    },
  );

  testWidgets(
    'FeeLedgerScreen at 390x844 renders ledger voucher cards with MobileStatusPill and zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildFeeLedgerWidget());
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(MobileStatusPill), findsWidgets);
      expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      expect(find.byIcon(Icons.print_outlined), findsWidgets);
      expect(find.byIcon(Icons.sms_outlined), findsWidgets);
    },
  );
}
