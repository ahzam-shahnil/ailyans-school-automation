// Phase G-9 Shot 4 — Mobile UX tests for Student Batch Workflows:
// BulkEnrollmentScreen, BatchPromotionScreen, and SchoolLeavingScreen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/batch_promotion_provider.dart';
import 'package:school_automation/core/providers/bulk_enrollment_provider.dart';
import 'package:school_automation/core/providers/school_leaving_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/students/batch_promotion_screen.dart';
import 'package:school_automation/screens/students/bulk_enrollment_screen.dart';
import 'package:school_automation/screens/students/school_leaving_screen.dart';
import 'package:school_automation/widgets/mobile/mobile_dropdown_field.dart';
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
    studentCount: 12,
    classCount: 2,
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

    // Seed 2 students into Class 5 (ClassID 8, ClassSecID 15) for Session 2017-2018
    await db.rawInsert('''
      INSERT INTO Stu_Reg (Stu_RegID, NameFirst, NameLast, F_Name, DOAdmission, FullDiscount)
      VALUES (4421, 'Rashid', 'Minhas', 'Minhas Khan', '2017-08-01', 0)
    ''');
    await db.rawInsert('''
      INSERT INTO Student_Class (Stu_RegID, ClassID, ClassSecID, ClassRollNo, SessionYr, Present, VGen)
      VALUES (4421, 8, 15, 1, '2017-2018', 1, 'Y')
    ''');

    await db.rawInsert('''
      INSERT INTO Stu_Reg (Stu_RegID, NameFirst, NameLast, F_Name, DOAdmission, FullDiscount)
      VALUES (4422, 'Tariq', 'Aziz', 'Aziz Khan', '2017-08-01', 0)
    ''');
    await db.rawInsert('''
      INSERT INTO Student_Class (Stu_RegID, ClassID, ClassSecID, ClassRollNo, SessionYr, Present, VGen)
      VALUES (4422, 8, 15, 2, '2017-2018', 1, 'Y')
    ''');

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

  Widget wrapBulkEnrollment({BulkEnrollmentNotifier? notifier}) {
    final router = GoRouter(
      initialLocation: '/students/enrollment/bulk',
      routes: [
        GoRoute(
          path: '/students/enrollment/bulk',
          builder: (context, state) => const Scaffold(body: BulkEnrollmentScreen()),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null) bulkEnrollmentProvider.overrideWith((ref) => notifier),
        classesProvider.overrideWith(
          (ref) => Future.value(const [
            SchoolClass(classId: 13, cName: 'Class 10'),
            SchoolClass(classId: 8, cName: 'Class 5'),
          ]),
        ),
        sectionsProvider.overrideWith(
          (ref) => Future.value(const [
            ClassSec(classSecId: 25, classId: 13, secName: 'A'),
            ClassSec(classSecId: 15, classId: 8, secName: 'A'),
          ]),
        ),
        availableSessionsProvider.overrideWith((ref) async => ['2018-2019', '2017-2018']),
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [12, 13, 20, 26]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapBatchPromotion({BatchPromotionNotifier? notifier}) {
    final router = GoRouter(
      initialLocation: '/students/promote',
      routes: [
        GoRoute(
          path: '/students/promote',
          builder: (context, state) => const Scaffold(body: BatchPromotionScreen()),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null) batchPromotionProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [8, 12, 13, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
        availableSessionsProvider.overrideWith((ref) async => ['2018-2019', '2017-2018']),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapSchoolLeaving({SchoolLeavingNotifier? notifier}) {
    final router = GoRouter(
      initialLocation: '/students/leaving',
      routes: [
        GoRoute(
          path: '/students/leaving',
          builder: (context, state) => const Scaffold(body: SchoolLeavingScreen()),
        ),
        GoRoute(
          path: '/fees/receipts',
          builder: (context, state) => const Scaffold(body: Text('Fee Receipts')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null) schoolLeavingProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [8, 12, 13, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
    'BulkEnrollmentScreen at 360x800 renders mobile filter card, KPI cards, and student roster cards with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late BulkEnrollmentNotifier notifier;
      await tester.runAsync(() async {
        notifier = BulkEnrollmentNotifier();
        notifier.setClassId(13); // Class 10
        notifier.setSecId(25); // Sec A
        notifier.setSessionYr('2017-2018');
        await notifier.loadRoster();
      });

      await tester.pumpWidget(wrapBulkEnrollment(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify mobile header and KPI cards
      expect(find.text('Bulk Class Enrollment'), findsOneWidget);
      expect(find.byType(MobileKpiCard), findsNWidgets(2));
      expect(find.text('ENROLLED STUDENTS'), findsOneWidget);
      expect(find.text('ACTIVE STATUS'), findsOneWidget);

      // Verify mobile filter card and dropdowns
      expect(find.text('COHORT SELECTION'), findsOneWidget);
      expect(find.byType(MobileDropdownField<String>), findsOneWidget);
      expect(find.byType(MobileDropdownField<int>), findsNWidgets(2));

      // Verify Quick Enroll card and sticky actions
      expect(find.text('QUICK ENROLL STUDENT'), findsOneWidget);
      expect(find.text('Re-roll'), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);

      // Verify roster cards render with MobileStatusPill
      expect(find.byType(MobileStatusPill), findsWidgets);
      expect(find.text('#4411'), findsOneWidget);
    },
  );

  testWidgets(
    'BatchPromotionScreen at 360x800 renders source/target filter card, candidate checklist cards, and sticky promote bar with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late BatchPromotionNotifier notifier;
      await tester.runAsync(() async {
        notifier = BatchPromotionNotifier();
        await notifier.loadInitialData();
        await notifier.setSourceClassId(8); // Class 5
        notifier.setSourceClassSecId(15); // Sec A
        notifier.setSourceSessionYr('2017-2018');
        await notifier.setTargetClassId(9); // Class 6
        notifier.setTargetClassSecId(17);
        notifier.setTargetSessionYr('2018-2019');
        await notifier.loadCandidates();
      });

      await tester.pumpWidget(wrapBatchPromotion(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify header and KPI cards
      expect(find.text('Batch Promotion'), findsOneWidget);
      expect(find.byType(MobileKpiCard), findsNWidgets(2));
      expect(find.text('CANDIDATES'), findsOneWidget);
      expect(find.text('SELECTED FOR ACTION'), findsOneWidget);

      // Verify source & target cohort sections
      expect(find.text('SOURCE COHORT (FROM)'), findsOneWidget);
      expect(find.text('DESTINATION COHORT (TO)'), findsOneWidget);

      // Verify candidate cards with roll number pills and student names
      expect(find.text('Rashid Minhas'), findsOneWidget);
      expect(find.text('Tariq Aziz'), findsOneWidget);
      expect(find.text('#4421'), findsOneWidget);
      expect(find.text('#4422'), findsOneWidget);

      // Verify sticky promote bar
      expect(find.text('Promote 2 Students'), findsOneWidget);
    },
  );

  testWidgets(
    'SchoolLeavingScreen at 360x800 renders student lookup, dues banner/form, and SLC register cards with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late SchoolLeavingNotifier notifier;
      await tester.runAsync(() async {
        notifier = SchoolLeavingNotifier();
        await notifier.loadInitialData();
        await notifier.selectStudent(4413); // student with no dues
      });

      await tester.pumpWidget(wrapSchoolLeaving(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify mobile header & KPI cards
      expect(find.text('School Leaving'), findsOneWidget);
      expect(find.byType(MobileKpiCard), findsNWidgets(2));
      expect(find.text('ISSUED CERTIFICATES'), findsOneWidget);
      expect(find.text('CLEARANCE STATUS'), findsOneWidget);

      // Verify clearance dossier, status banner, and withdrawal details
      expect(find.text('STUDENT CLEARANCE DOSSIER'), findsOneWidget);
      expect(find.text('WITHDRAWAL DETAILS'), findsOneWidget);
      expect(find.text('Effective Leaving Date'), findsOneWidget);
      expect(find.text('Reason for Leaving'), findsOneWidget);
      expect(find.text('Character & Conduct'), findsOneWidget);

      // Verify sticky buttons
      expect(find.text('SLC Register'), findsOneWidget);
      expect(find.text('Print SLC'), findsOneWidget);
      expect(find.text('Commit School Leaving'), findsOneWidget);
    },
  );

  testWidgets(
    'All 3 screens at 390x844 interactive state changes render with zero overflow',
    (tester) async {
      setViewport(tester, const Size(390, 844));

      // 1. BulkEnrollmentScreen initial empty state then roster loaded
      {
        await tester.pumpWidget(wrapBulkEnrollment());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('Select Class, Section, and Session, then click Load Roster'),
          findsOneWidget,
        );
      }

      // Unmount previous ProviderScope to avoid Riverpod overrides count assertion
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // 2. BatchPromotionScreen graduation mode
      {
        late BatchPromotionNotifier notifier;
        await tester.runAsync(() async {
          notifier = BatchPromotionNotifier();
          await notifier.loadInitialData();
          await notifier.setSourceClassId(13); // Class 10 -> graduation mode
          notifier.setSourceClassSecId(25);
          notifier.setSourceSessionYr('2017-2018');
          await notifier.loadCandidates();
        });

        await tester.pumpWidget(wrapBatchPromotion(notifier: notifier));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Graduation'), findsWidgets);
        expect(
          find.textContaining('Graduation Mode: Students will graduate'),
          findsOneWidget,
        );
        expect(find.textContaining('Graduate 10 Students'), findsOneWidget);
      }

      // Unmount previous ProviderScope to avoid Riverpod overrides count assertion
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // 3. SchoolLeavingScreen with outstanding dues (BLOCKED gate)
      {
        late SchoolLeavingNotifier notifier;
        await tester.runAsync(() async {
          notifier = SchoolLeavingNotifier();
          await notifier.loadInitialData();
          await notifier.selectStudent(4411); // student with dues
        });

        await tester.pumpWidget(wrapSchoolLeaving(notifier: notifier));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('OUTSTANDING DUES BALANCE'), findsOneWidget);
        expect(find.text('BLOCKED'), findsWidgets);
        expect(find.text('Pay Arrears Now'), findsOneWidget);
        expect(find.text('Refresh Status'), findsOneWidget);
      }
    },
  );
}
