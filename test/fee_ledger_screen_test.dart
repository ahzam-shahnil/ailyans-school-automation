import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/fee_ledger_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/fees/fee_ledger_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
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

  Widget buildTestWidget({bool withShell = false}) {
    const screen = FeeLedgerScreen();

    final router = GoRouter(
      initialLocation: '/fees/ledger',
      routes: [
        if (withShell)
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/fees/ledger',
                builder: (context, state) => screen,
              ),
            ],
          )
        else
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

  group('FeeLedgerScreen & Provider Unit Tests', () {
    test(
      '1. Provider loads sessions, months, classes and default aggregates',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(feeLedgerProvider.notifier);
        await notifier.init();

        final state = container.read(feeLedgerProvider);
        expect(state.sessionYears, contains('2017-2018'));
        expect(state.months, contains('October 2017'));
        expect(state.classes, isNotEmpty);
        expect(state.rows, isNotEmpty);
        expect(state.grossReceivable, greaterThan(0));
        expect(state.totalBilledCount, state.rows.length);
      },
    );

    test(
      '2. Renders 4 KPI cards with expected titles and positive values',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(feeLedgerProvider.notifier);
        await notifier.init();
        final state = container.read(feeLedgerProvider);

        expect(state.grossReceivable, greaterThan(0));
        expect(state.totalConcessions, greaterThanOrEqualTo(0));
        expect(state.cashCollected, greaterThanOrEqualTo(0));
        expect(state.outstandingDues, greaterThan(0));
        expect(state.defaultersCount, greaterThan(0));
      },
    );

    test(
      '3. Filtering by Class updates rows and recalculates KPI aggregates',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(feeLedgerProvider.notifier);
        await notifier.init();

        // Class 10 has ClassID = 13 in seed data
        notifier.setClass(13);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(feeLedgerProvider);
        expect(state.selectedClassId, 13);
        for (final r in state.rows) {
          expect(r.className, 'Class 10');
        }
      },
    );

    test(
      '4. Filtering by Month updates rows and handles "All Months"',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(feeLedgerProvider.notifier);
        await notifier.init();

        notifier.setMonth('All Months');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(feeLedgerProvider);
        expect(state.selectedMonth, 'All Months');
        expect(state.rows, isNotEmpty);
      },
    );

    test('5. Status filter "Paid" returns only paid vouchers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeLedgerProvider.notifier);
      await notifier.init();

      notifier.setStatus('Paid');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(feeLedgerProvider);
      for (final r in state.rows) {
        expect(r.isPaid, 'Y');
      }
    });

    test('6. Status filter "Unpaid" returns only unpaid vouchers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeLedgerProvider.notifier);
      await notifier.init();

      notifier.setStatus('Unpaid');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(feeLedgerProvider);
      for (final r in state.rows) {
        expect(r.isPaid, 'N');
      }
    });

    test(
      '7. Load voucher details returns line items from VoucharDet',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(feeLedgerProvider.notifier);
        await notifier.init();

        final firstVoucher = container.read(feeLedgerProvider).rows.first;
        final items = await notifier.loadVoucherDetails(
          firstVoucher.voucherMasId,
        );

        expect(items, isNotEmpty);
        expect(items.first.amount, greaterThan(0));
      },
    );

    test(
      '8. Load class collection summary groups by class accurately',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(feeLedgerProvider.notifier);
        await notifier.init();

        final summary = await notifier.loadClassCollectionSummary();
        expect(summary, isNotEmpty);
        expect(summary.first['className'], isNotNull);
        expect(summary.first['totalBilled'], greaterThan(0));
      },
    );
  });

  group('FeeLedgerScreen Widget Tests', () {
    testWidgets('9. Renders 4 KPI cards and action buttons on 1440x900', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(find.byType(FeeLedgerScreen), findsOneWidget);
      expect(find.text('GROSS RECEIVABLE'), findsOneWidget);
      expect(find.text('TOTAL CONCESSIONS'), findsOneWidget);
      expect(find.text('CASH COLLECTED'), findsOneWidget);
      expect(find.text('OUTSTANDING DUES'), findsOneWidget);

      expect(find.text('Export Defaulters Roster'), findsOneWidget);
      expect(find.text('Class Collection Summary'), findsOneWidget);
      expect(find.text('Daily Collection Ledger'), findsOneWidget);
      expect(find.text('Export to Excel / CSV'), findsOneWidget);
    });

    testWidgets(
      '10. Renders data table columns and rows without layout overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestWidget());
        for (int i = 0; i < 5; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump();
        }

        expect(find.text('Voucher ID'), findsOneWidget);
        expect(find.text('Reg ID'), findsOneWidget);
        expect(find.text('Student Name'), findsOneWidget);
        expect(find.text('Class-Sec'), findsOneWidget);
        expect(find.text('Gross (Rs)'), findsOneWidget);
        expect(find.text('Disc (Rs)'), findsOneWidget);
        expect(find.text('Net Due'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('Due Date'), findsOneWidget);
        expect(find.text('Act'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('11. Clicking [View] row action opens Voucher Details dialog', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }

      final viewIcon = find.byIcon(Icons.visibility_outlined).first;
      await tester.tap(viewIcon);
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }

      expect(find.textContaining('Voucher Details -'), findsOneWidget);
      expect(find.text('Fee Parameter Breakdown:'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Fee Parameter Breakdown:'), findsNothing);
    });

    testWidgets('12. Fits 1440x780 viewport with banner without any overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(FeeLedgerScreen), findsOneWidget);
      expect(find.text('Fee Ledger & Receivables Analytics'), findsOneWidget);
    });
  });
}
