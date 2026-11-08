// Phase G / G-5-3 — mobile FeeLedgerScreen zero-overflow at 360/390/414.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/fees/fee_ledger_screen.dart';
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

  Widget buildMobileWidget() {
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

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildMobileWidget());
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
      reason: 'fee_ledger zero-overflow at $size',
    );

    // Loaded state markers.
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

    // Mobile branch must replace the DataTable with cards.
    expect(
      find.byType(DataTable).evaluate().length,
      0,
      reason: 'no desktop DataTable at $size',
    );
  }

  testWidgets('FeeLedgerScreen zero overflow at 360x800', (tester) async {
    await pumpAt(tester, const Size(360, 800));
  });

  testWidgets('FeeLedgerScreen zero overflow at 390x844', (tester) async {
    await pumpAt(tester, const Size(390, 844));
  });

  testWidgets('FeeLedgerScreen zero overflow at 414x896', (tester) async {
    await pumpAt(tester, const Size(414, 896));
  });
}
