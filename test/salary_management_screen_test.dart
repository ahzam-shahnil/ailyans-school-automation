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

  Widget buildTestScreen({
    SalaryManagementNotifier? notifier,
    int userLvl = 1,
  }) {
    final router = GoRouter(
      initialLocation: '/staff/salary',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/staff/salary',
              builder: (context, state) => const SalaryManagementScreen(),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          salaryManagementProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser.copyWith(userLevel: userLvl), const [
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

  group('SalaryManagement Provider & Business Logic Tests', () {
    test('a) loads 6 active teachers on mount', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(salaryManagementProvider);
      expect(state.roster.length, 6);
      expect(state.totalEligibleStaff, 6);
      expect(state.roster[0].teacherName, 'Ahzam Shahnil');
      expect(state.roster[0].isPending, isTrue);
    });

    test('b) selecting TeacherID=1 auto-derives 3 allowance items from TSalLvlAmount (Basic 5000, House Rent 5000, TA/DA 1000)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectEmployee(1);

      final state = container.read(salaryManagementProvider);
      expect(state.selectedTeacherId, 1);
      expect(state.draftAllowances.length, 3);
      expect(state.draftAllowances[0].detail, 'Basic Salary');
      expect(state.draftAllowances[0].amount, 5000);
      expect(state.draftAllowances[1].detail, 'House Rent');
      expect(state.draftAllowances[1].amount, 5000);
      expect(state.draftAllowances[2].detail, 'TA/DA');
      expect(state.draftAllowances[2].amount, 1000);
    });

    test('c) totals compute: gross=11000, net = 11000 - deductions', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectEmployee(1);

      var state = container.read(salaryManagementProvider);
      expect(state.grossEarnings, 11000);
      expect(state.netPayable, 11000);

      notifier.updateDeductions(1500);
      state = container.read(salaryManagementProvider);
      expect(state.draftDeductions, 1500.0);
      expect(state.netPayable, 9500);
    });

    test('d) selecting TeacherID=2 (Teacher Level 3) derives Basic=10000, Rent=5000, TA/DA=1000', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectEmployee(2);

      final state = container.read(salaryManagementProvider);
      expect(state.selectedTeacherId, 2);
      expect(state.draftAllowances.length, 3);
      expect(state.draftAllowances[0].amount, 10000);
      expect(state.draftAllowances[1].amount, 5000);
      expect(state.draftAllowances[2].amount, 1000);
      expect(state.grossEarnings, 16000);
    });

    test('e) editing deductions updates net display live', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectEmployee(1);

      notifier.updateDeductions(500);
      final state = container.read(salaryManagementProvider);
      expect(state.netPayable, 10500);
    });

    test('f) adding an allowance head appends a new row', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectEmployee(1);

      notifier.addAllowanceHead(3, 500);
      final state = container.read(salaryManagementProvider);
      expect(state.draftAllowances.length, 4);
      expect(state.draftAllowances.last.ser, 4);
      expect(state.draftAllowances.last.detail, 'TA/DA');
      expect(state.draftAllowances.last.amount, 500);
      expect(state.grossEarnings, 11500);
    });

    test('g) removing an allowance head deletes + renumbers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectEmployee(1);

      notifier.removeAllowanceHead(2); // Remove House Rent
      final state = container.read(salaryManagementProvider);
      expect(state.draftAllowances.length, 2);
      expect(state.draftAllowances[0].ser, 1);
      expect(state.draftAllowances[0].detail, 'Basic Salary');
      expect(state.draftAllowances[1].ser, 2);
      expect(state.draftAllowances[1].detail, 'TA/DA');
    });

    test(
      'h) commit creates new TSalMas with id yyMM-1 and TSalDet rows',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(salaryManagementProvider.notifier);
        await notifier.loadInitialData();
        await notifier.selectEmployee(1);
        notifier.updateDeductions(500);

        final ok = await notifier.commitSlip(userLvl: 1);
        expect(ok, isTrue);

        final state = container.read(salaryManagementProvider);
        expect(state.toast, 'Salary Slip Committed & Disbursed Successfully');

        final yyMM = SalaryManagementNotifier.deriveYyMM(state.selectedMonth);
        final expectedId = '$yyMM-1';

        final masRows = await db.rawQuery(
          'SELECT * FROM TSalMas WHERE TeacherID = 1 AND SalMonth = ?',
          [state.selectedMonth],
        );
        expect(masRows.length, 1);
        expect(masRows.first['TSalMasID'], expectedId);
        expect(masRows.first['PaidAmt'], 10500);
        expect(masRows.first['TDeductions'], 500);
        expect(masRows.first['IsPaid'], 'Y');

        final detRows = await db.rawQuery(
          'SELECT * FROM TSalDet WHERE TSalMasID = ? ORDER BY TSalDetSer ASC',
          [expectedId],
        );
        expect(detRows.length, 3);
        expect(detRows[0]['Amount'], 5000);
      },
    );

    test('i) commit with deductions > gross fires Deductions cannot exceed total gross earnings', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectEmployee(1);
      notifier.updateDeductions(15000); // Exceeds 11000

      final ok = await notifier.commitSlip(userLvl: 1);
      expect(ok, isFalse);
      final state = container.read(salaryManagementProvider);
      expect(
        state.errorMessage,
        'Deductions cannot exceed total gross earnings',
      );
    });

    test('j) commit with userLvl=3 fires You don\'t have enough rights for purpose', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectEmployee(1);

      final ok = await notifier.commitSlip(userLvl: 3);
      expect(ok, isFalse);
      final state = container.read(salaryManagementProvider);
      expect(state.errorMessage, "You don't have enough rights for purpose");
    });

    test('k) batch disburse processes all pending rows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(salaryManagementProvider.notifier);
      await notifier.loadInitialData();

      expect(container.read(salaryManagementProvider).roster.length, 6);
      expect(
        container
            .read(salaryManagementProvider)
            .roster
            .every((r) => r.isPending),
        isTrue,
      );

      final ok = await notifier.batchDisbursePending(userLvl: 1);
      expect(ok, isTrue);

      final state = container.read(salaryManagementProvider);
      expect(state.roster.every((r) => r.isPaid == 'Y'), isTrue);
      expect(state.grossPayroll, greaterThan(0));
      expect(state.netDisbursed, greaterThan(0));
    });
  });

  group('SalaryManagementScreen UI & Widget Tests', () {
    testWidgets('l) fits 1440x900 AND 1440x780 without overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late SalaryManagementNotifier notifier;
      await tester.runAsync(() async {
        notifier = SalaryManagementNotifier();
        await notifier.loadInitialData();
      });

      // 1. Test 1440x900
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('Staff Payroll & Salary Disbursement'), findsOneWidget);
      expect(find.text('Total Eligible Staff'), findsOneWidget);
      expect(find.text('Ahzam Shahnil'), findsOneWidget);

      // Select Ahzam Shahnil
      await tester.runAsync(() async {
        await notifier.selectEmployee(1);
      });
      await tester.pumpAndSettle();

      expect(find.text('Basic Salary'), findsOneWidget);
      expect(find.text('House Rent'), findsOneWidget);
      expect(find.text('TA/DA'), findsOneWidget);

      // 2. Test 1440x780
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('Staff Payroll & Salary Disbursement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
