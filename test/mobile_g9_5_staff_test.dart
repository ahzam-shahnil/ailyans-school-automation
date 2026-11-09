import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/salary_management_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/teacher_list_provider.dart';
import 'package:school_automation/core/providers/teacher_profile_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/staff/salary_management_screen.dart';
import 'package:school_automation/screens/staff/teacher_list_screen.dart';
import 'package:school_automation/screens/staff/teacher_profile_screen.dart';
import 'package:school_automation/widgets/mobile/mobile_kpi_card.dart';
import 'package:school_automation/widgets/mobile/mobile_status_pill.dart';

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

    // Update Subj_Class row 4 to TeacherID = 2 so Teacher 1 has exactly 4 assigned classes
    await db.rawUpdate(
      'UPDATE Subj_Class SET TeacherID = 2 WHERE Subj_ClsID = 4',
    );

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

    // Seed TSalMas history for TeacherID=1
    await db.insert('TSalMas', {
      'TSalMasID': '1710-1',
      'TeacherID': 1,
      'DisbursDate': '2017-10-25',
      'SalMonth': 'October 2017',
      'PaidAmt': 45000,
      'TDeductions': 2000,
      'Detail': 'Principal salary - Oct 2017',
      'IsPaid': 'Y',
      'PaidDate': '2017-10-25',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('TSalMas', {
      'TSalMasID': '1709-1',
      'TeacherID': 1,
      'DisbursDate': '2017-09-25',
      'SalMonth': 'September 2017',
      'PaidAmt': 45000,
      'TDeductions': 2000,
      'Detail': 'Principal salary - Sep 2017',
      'IsPaid': 'Y',
      'PaidDate': '2017-09-25',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('TSalMas', {
      'TSalMasID': '1708-1',
      'TeacherID': 1,
      'DisbursDate': '2017-08-25',
      'SalMonth': 'August 2017',
      'PaidAmt': 45000,
      'TDeductions': 2000,
      'Detail': 'Principal salary - Aug 2017',
      'IsPaid': 'Y',
      'PaidDate': '2017-08-25',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget wrapTeacherList({TeacherListNotifier? notifier}) {
    final router = GoRouter(
      initialLocation: '/staff/teachers',
      routes: [
        GoRoute(
          path: '/staff/teachers',
          builder: (context, state) => const TeacherListScreen(),
        ),
        GoRoute(
          path: '/staff/teachers/new',
          builder: (context, state) =>
              const Scaffold(body: Text('New Teacher Stub')),
        ),
        GoRoute(
          path: '/staff/teachers/:id',
          builder: (context, state) => Scaffold(
            body: Text('Teacher Profile Stub: ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null) teacherListProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [8, 9, 10, 12, 13, 14, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapTeacherProfile({
    int? teacherId = 1,
    TeacherProfileNotifier? notifier,
  }) {
    final router = GoRouter(
      initialLocation: '/staff/teachers/$teacherId',
      routes: [
        GoRoute(
          path: '/staff/teachers',
          builder: (context, state) =>
              const Scaffold(body: Text('Teacher Directory Stub')),
        ),
        GoRoute(
          path: '/staff/teachers/:id',
          builder: (context, state) {
            final idStr = state.pathParameters['id'];
            final id = idStr != null ? int.tryParse(idStr) : null;
            return TeacherProfileScreen(teacherId: id);
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          teacherProfileProvider(teacherId).overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [8, 9, 10, 12, 13, 14, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapSalaryManagement({SalaryManagementNotifier? notifier}) {
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
        if (notifier != null)
          salaryManagementProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [8, 9, 10, 12, 13, 14, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
    'TeacherListScreen at 360x800 renders MobileKpiCard strip and teacher cards with MobileStatusPill and zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late TeacherListNotifier notifier;
      await tester.runAsync(() async {
        notifier = TeacherListNotifier();
        await notifier.loadInitialData();
      });

      await tester.pumpWidget(wrapTeacherList(notifier: notifier));
      await tester.pump();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      // Verify header and 2-up MobileKpiCard strip
      expect(find.text('Faculty & Staff Directory'), findsOneWidget);
      expect(find.byType(MobileKpiCard), findsNWidgets(2));
      expect(find.text('TOTAL STAFF'), findsOneWidget);
      expect(find.text('ACTIVE STAFF'), findsOneWidget);

      // Verify teacher cards with MobileStatusPill
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(MobileStatusPill), findsWidgets);
      expect(find.text('Nasir Ali'), findsWidgets);
      expect(find.text('Rehana Shaheen'), findsWidgets);

      // Verify sticky bottom bar
      expect(find.text('+ Add Teacher'), findsWidgets);
    },
  );

  testWidgets(
    'TeacherProfileScreen at 360x800 renders hero card, horizontal tab bar, and tab content with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late TeacherProfileNotifier notifier;
      await tester.runAsync(() async {
        notifier = TeacherProfileNotifier();
        await notifier.loadTeacher(1);
      });

      await tester.pumpWidget(
        wrapTeacherProfile(teacherId: 1, notifier: notifier),
      );
      await tester.pump();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      // Verify hero card and MobileStatusPill
      expect(find.text('Nasir Ali'), findsWidgets);
      expect(find.byType(MobileStatusPill), findsWidgets);
      expect(find.text('Active'), findsWidgets);

      // Verify horizontal tab bar with exact desktop labels
      expect(find.text('1. Personal & Biodata'), findsOneWidget);
      expect(find.text('2. Class Subjects (4)'), findsOneWidget);
      expect(find.text('3. Payroll History (3)'), findsOneWidget);
      expect(find.text('4. Qualifications'), findsOneWidget);

      // Verify tab 1 content
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Father / Spouse Name'), findsOneWidget);
      expect(find.text('Muhammad Ali'), findsOneWidget);

      // Verify sticky bottom bar actions
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Directory'), findsOneWidget);
    },
  );

  testWidgets(
    'TeacherProfileScreen at 390x844 switching tabs renders without zero overflow',
    (tester) async {
      setViewport(tester, const Size(390, 844));

      late TeacherProfileNotifier notifier;
      await tester.runAsync(() async {
        notifier = TeacherProfileNotifier();
        await notifier.loadTeacher(1);
      });

      await tester.pumpWidget(
        wrapTeacherProfile(teacherId: 1, notifier: notifier),
      );
      await tester.pump();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      // 1. Switch to Tab 2 (Class Subjects)
      await tester.ensureVisible(find.text('2. Class Subjects (4)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Class Subjects (4)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Islamiat'), findsWidgets);

      // 2. Switch to Tab 3 (Payroll History)
      await tester.ensureVisible(find.text('3. Payroll History (3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3. Payroll History (3)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('October 2017'), findsWidgets);

      // 3. Switch to Tab 4 (Qualifications)
      await tester.ensureVisible(find.text('4. Qualifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4. Qualifications'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Academic Degrees'), findsOneWidget);

      // 4. Switch back to Tab 1
      await tester.ensureVisible(find.text('1. Personal & Biodata'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1. Personal & Biodata'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Full Name *'), findsOneWidget);
    },
  );

  testWidgets(
    'SalaryManagementScreen at 360x800 renders 2-up KPI cards and payroll cards with MobileStatusPill and zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late SalaryManagementNotifier notifier;
      await tester.runAsync(() async {
        notifier = SalaryManagementNotifier();
        await notifier.loadInitialData();
        await notifier.selectEmployee(1);
      });

      await tester.pumpWidget(wrapSalaryManagement(notifier: notifier));
      await tester.pump();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      // Verify header and 4 MobileKpiCard items in 2-up grid
      expect(find.text('Staff Payroll & Salary Disbursement'), findsOneWidget);
      expect(find.byType(MobileKpiCard), findsNWidgets(4));
      expect(find.text('GROSS PAYROLL'), findsOneWidget);
      expect(find.text('NET DISBURSED'), findsOneWidget);
      expect(find.text('ELIGIBLE STAFF'), findsOneWidget);
      expect(find.text('TOTAL DEDUCTIONS'), findsOneWidget);

      // Verify payroll cards and status pills
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(MobileStatusPill), findsWidgets);
      expect(find.text('Nasir Ali'), findsWidgets);

      // Verify sticky bottom action
      expect(find.text('Save Salary Disbursement'), findsOneWidget);
    },
  );

  testWidgets(
    'TeacherProfileScreen at 414x896 entering Edit Mode updates sticky actions to Cancel / Save Teacher without overflow',
    (tester) async {
      setViewport(tester, const Size(414, 896));

      late TeacherProfileNotifier notifier;
      await tester.runAsync(() async {
        notifier = TeacherProfileNotifier();
        await notifier.loadTeacher(1);
      });

      await tester.pumpWidget(
        wrapTeacherProfile(teacherId: 1, notifier: notifier),
      );
      await tester.pump();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Tap Edit Profile
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // In edit mode, sticky bottom actions are Cancel and Save Teacher
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Teacher'), findsOneWidget);

      // Tap Cancel to return to view mode
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Profile'), findsOneWidget);
    },
  );
}
