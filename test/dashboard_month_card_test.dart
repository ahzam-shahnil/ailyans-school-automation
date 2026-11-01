import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/providers/clock_provider.dart';
import 'package:school_automation/core/providers/dashboard_metrics_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/screens/dashboard/dashboard_screen.dart';
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
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('Dashboard Latest Billing Month Card Tests', () {
    test('a. Latest Billing Month card shows current month when vouchers exist in active session', () async {
      // Set active session in app_config
      await db.execute(
        "INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES ('default_session_yr', '2026-27')",
      );

      // Clock set to 2026-10-15 (yyMM = 2610)
      DateTime fixedClock() => DateTime(2026, 10, 15);

      // Insert current month voucher (2610)
      await db.execute('''
          INSERT INTO VoucharMas (VoucherMasID, SessionYr, ForMonth, SubTotal, PaidAmt, IsPaid, ClassID, Student_Class_StuRegID)
          VALUES ('2610-1001', '2026-27', 'Oct-2026', 5000, 3000, 'N', 1, 1001)
        ''');

      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(fixedClock)],
      );
      addTearDown(container.dispose);

      final metrics = await container.read(dashboardMetricsProvider.future);

      expect(metrics.latestBilledMonthLabel, 'Oct-2026');
      expect(metrics.monthlyExpected, 5000);
      expect(metrics.monthlyCollected, 3000);
      expect(metrics.latestBilledGross, 5000);
      expect(metrics.latestBilledCollected, 3000);
    });

    test('b. Latest Billing Month card shows previous month when current month empty', () async {
      // Set active session in app_config
      await db.execute(
        "INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES ('default_session_yr', '2026-27')",
      );

      // Clock set to 2026-11-01 (yyMM = 2611, with 0 November vouchers)
      DateTime fixedClock() => DateTime(2026, 11, 1);

      // Insert prior month voucher (2610 = Oct-2026)
      await db.execute('''
          INSERT INTO VoucharMas (VoucherMasID, SessionYr, ForMonth, SubTotal, PaidAmt, IsPaid, ClassID, Student_Class_StuRegID)
          VALUES ('2610-1001', '2026-27', 'Oct-2026', 135500, 121170, 'N', 1, 1001)
        ''');

      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(fixedClock)],
      );
      addTearDown(container.dispose);

      final metrics = await container.read(dashboardMetricsProvider.future);

      // Honest query: shows October 2026 data
      expect(metrics.latestBilledMonthLabel, 'Oct-2026');
      expect(metrics.monthlyExpected, 135500);
      expect(metrics.monthlyCollected, 121170);
    });

    testWidgets(
      'c. Card subtitle renders "Oct-2026 • Exp: Rs. X" on Dashboard UI',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const testMetrics = DashboardMetrics(
          attendancePercent: 85.0,
          presentCount: 17,
          absentCount: 3,
          leaveCount: 0,
          totalStudents: 20,
          monthlyCollected: 121170,
          monthlyExpected: 135500,
          collectionPace: 89,
          activeEnrollment: 72,
          classCount: 10,
          sectionCount: 15,
          pendingVouchers: 8,
          outstandingAmount: 14330,
          latestBilledMonthLabel: 'Oct-2026',
          latestBilledGross: 135500,
          latestBilledCollected: 121170,
          recentPayments: [],
          classStrength: [],
        );

        const testShellMeta = ShellMetadata(
          branchName: "Ailyans's Higher Secondary School Mianwali",
          branchAddress: 'Muslim Bazar Mianwali',
          branchPhone: null,
          branchPrincipal: null,
          sessionYear: '2026-27',
          studentCount: 72,
          classCount: 10,
          staffCount: 5,
          pendingVouchers: 8,
        );

        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/fees/ledger',
              builder: (context, state) => const Scaffold(body: Text('Ledger')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardMetricsProvider.overrideWith(
                (ref) => Future.value(testMetrics),
              ),
              shellMetadataProvider.overrideWith(
                (ref) => Future.value(testShellMeta),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Title kept verbatim for compatibility
        expect(find.text('MONTHLY FEE COLLECTION'), findsOneWidget);
        // Value rendered
        expect(find.text('Rs. 121,170'), findsOneWidget);
        expect(find.text('89% Pace'), findsOneWidget);
        // Subtitle shows honest month label
        expect(find.text('Oct-2026 • Exp: Rs. 135,500'), findsOneWidget);
      },
    );

    test(
      'd. Zero current-month vouchers does NOT trigger fallback (honest query)',
      () async {
        // Set active session in app_config
        await db.execute(
          "INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES ('default_session_yr', '2026-27')",
        );

        // Clock set to 2026-11-01
        DateTime fixedClock() => DateTime(2026, 11, 1);

        // When NO vouchers exist at all in 2026-27 session
        final container = ProviderContainer(
          overrides: [clockProvider.overrideWithValue(fixedClock)],
        );
        addTearDown(container.dispose);

        final metrics = await container.read(dashboardMetricsProvider.future);

        // No vouchers in 2026-27 session, so latestBilledMonthLabel is empty
        expect(metrics.latestBilledGross, 0);
        expect(metrics.latestBilledCollected, 0);
      },
    );
  });
}
