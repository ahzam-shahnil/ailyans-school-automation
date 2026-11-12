// Phase G / G-6b-2 — mobile SalaryManagementScreen loaded-state zero-overflow
// at 360x800, 390x844, 414x896. The in-memory SQLite harness and ProviderScope
// overrides are copied from test/salary_management_screen_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/salary_management_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/staff/salary_management_screen.dart';
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
    staffCount: 6,
    pendingVouchers: 4,
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

    // Seed 6th teacher as active
    await db.insert('Teachers', {
      'TeacherID': 6,
      'TName': 'Test Staff Member',
      'TFName': 'Test Father',
      'TCNIC': '38302-6666666-6',
      'TContactNo1': '03336666666',
      'TSubject': 'General',
      'DOJoing': '2018-01-01',
      'TIsPresent': 'Y',
      'TCat': 'Staff',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed TSalParam
    await db.insert('TSalParam', {
      'SalParamID': 1,
      'SalParam': 'Basic Salary',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalParam', {
      'SalParamID': 2,
      'SalParam': 'House Rent',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalParam', {
      'SalParamID': 3,
      'SalParam': 'TA/DA',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed TSalLvl
    await db.insert('TSalLvl', {
      'SalLvl': 1,
      'LvlDetail': 'Teacher Level 1',
      'AllowedLeaves': 12,
      'PerLeaveDeduct': 500,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvl', {
      'SalLvl': 2,
      'LvlDetail': 'Teacher Level 2',
      'AllowedLeaves': 18,
      'PerLeaveDeduct': 750,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvl', {
      'SalLvl': 3,
      'LvlDetail': 'Teacher Level 3',
      'AllowedLeaves': 24,
      'PerLeaveDeduct': 1000,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed TSalLvlAmount for 2017-2018
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 1,
      'SalLvl': 1,
      'SalParamID': 1,
      'Amount': 5000,
      'SalYear': '2017-2018',
      'Remarks': 'Basic',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 2,
      'SalLvl': 1,
      'SalParamID': 2,
      'Amount': 5000,
      'SalYear': '2017-2018',
      'Remarks': 'Rent',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 3,
      'SalLvl': 1,
      'SalParamID': 3,
      'Amount': 1000,
      'SalYear': '2017-2018',
      'Remarks': 'Transport',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('TSalLvlAmount', {
      'T_SalTD': 4,
      'SalLvl': 2,
      'SalParamID': 1,
      'Amount': 7000,
      'SalYear': '2017-2018',
      'Remarks': 'Basic',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 5,
      'SalLvl': 2,
      'SalParamID': 2,
      'Amount': 5000,
      'SalYear': '2017-2018',
      'Remarks': 'Rent',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 6,
      'SalLvl': 2,
      'SalParamID': 3,
      'Amount': 1000,
      'SalYear': '2017-2018',
      'Remarks': 'Transport',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('TSalLvlAmount', {
      'T_SalTD': 7,
      'SalLvl': 3,
      'SalParamID': 1,
      'Amount': 10000,
      'SalYear': '2017-2018',
      'Remarks': 'Basic',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 8,
      'SalLvl': 3,
      'SalParamID': 2,
      'Amount': 5000,
      'SalYear': '2017-2018',
      'Remarks': 'Rent',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 9,
      'SalLvl': 3,
      'SalParamID': 3,
      'Amount': 1000,
      'SalYear': '2017-2018',
      'Remarks': 'Transport',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed TEmp_Lvl
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 1,
      'TeacherID': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 3,
      'TeacherID': 2,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 3,
      'TeacherID': 3,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 3,
      'TeacherID': 4,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 2,
      'TeacherID': 5,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 2,
      'TeacherID': 6,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Widget wrap(SalaryManagementNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/staff/salary',
      routes: [
        GoRoute(
          path: '/staff/salary',
          builder: (context, state) => const SalaryManagementScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        salaryManagementProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser, const [
            8,
            9,
            10,
            12,
            13,
            14,
            20,
            22,
          ]);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  const sizes = <Size>[Size(360, 800), Size(390, 844), Size(414, 896)];

  group('G-6b-2 mobile SalaryManagementScreen zero-overflow', () {
    for (final size in sizes) {
      testWidgets('loaded payroll register + slip at $size', (tester) async {
        setSize(tester, size);

        late SalaryManagementNotifier notifier;
        await tester.runAsync(() async {
          notifier = SalaryManagementNotifier();
          await notifier.loadInitialData();
          await notifier.selectEmployee(1);
        });

        await tester.pumpWidget(wrap(notifier));
        await tester.pump();

        // Let the screen's own post-frame load complete under real async.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'salary_management zero-overflow at $size',
        );

        // Loaded roster cards + allowance cards must render.
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'mobile salary cards rendered at $size',
        );

        // Seeded payroll data must be visible (not clipped).
        expect(
          find.textContaining('Ahzam Shahnil').evaluate().length,
          greaterThan(0),
          reason: 'seeded employee visible at $size',
        );
        expect(
          find.textContaining('Staff Payroll & Salary Disbursement')
              .evaluate()
              .length,
          greaterThan(0),
          reason: 'header visible at $size',
        );
      });
    }
  });
}
