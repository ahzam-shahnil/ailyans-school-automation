import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/school_leaving_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/sibling_links_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/student_profile_provider.dart';
import 'package:school_automation/core/providers/student_registration_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/student.dart';
import 'package:school_automation/models/student_list_row.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/students/school_leaving_screen.dart';
import 'package:school_automation/screens/students/student_list_screen.dart';
import 'package:school_automation/screens/students/student_profile_screen.dart';
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

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('Phase D.0.1 — Sibling Links & Student Deletion Tests', () {
    // ─────────────────────────────────────────────────────────────────────────
    // a) Migration 008 creates Sibling_Links table with correct schema
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'a) Migration 008 creates Sibling_Links table with correct schema',
      () async {
        final tableInfo = await db.rawQuery('PRAGMA table_info(Sibling_Links)');
        final columnNames = tableInfo
            .map((col) => col['name'] as String)
            .toSet();

        expect(columnNames, contains('LinkID'));
        expect(columnNames, contains('Stu1_RegID'));
        expect(columnNames, contains('Stu2_RegID'));
        expect(columnNames, contains('Relation'));
        expect(columnNames, contains('LinkedBy'));
        expect(columnNames, contains('LinkedOn'));
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // b) Migration 010 sets user_version = 10
    // ─────────────────────────────────────────────────────────────────────────
    test('b) Migration 010 sets user_version = 10', () async {
      final res = await db.rawQuery('PRAGMA user_version');
      final version = res.first.values.first as int;
      expect(version, 10);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // c) linkPair(5, 4411) inserts one row with Stu1=5, Stu2=4411
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'c) linkPair(5, 4411) inserts one row with Stu1=5, Stu2=4411',
      () async {
        final notifier = SiblingLinksNotifier();
        final inserted = await notifier.linkPair(5, 4411, relation: 'sibling');
        expect(inserted, isTrue);

        final rows = await db.rawQuery(
          'SELECT * FROM Sibling_Links WHERE Stu1_RegID = 5 AND Stu2_RegID = 4411',
        );
        expect(rows.length, 1);
        expect(rows.first['Stu1_RegID'], 5);
        expect(rows.first['Stu2_RegID'], 4411);
        expect(rows.first['Relation'], 'sibling');
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // d) linkPair(4411, 5) inserts one row with Stu1=5, Stu2=4411 (canonical)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'd) linkPair(4411, 5) inserts one row with Stu1=5, Stu2=4411 (canonical)',
      () async {
        final notifier = SiblingLinksNotifier();
        final inserted = await notifier.linkPair(4411, 5, relation: 'sibling');
        expect(inserted, isTrue);

        final rows = await db.rawQuery(
          'SELECT * FROM Sibling_Links WHERE Stu1_RegID = 5 AND Stu2_RegID = 4411',
        );
        expect(rows.length, 1);
        expect(rows.first['Stu1_RegID'], 5);
        expect(rows.first['Stu2_RegID'], 4411);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // e) linkPair called twice with same pair returns false (UNIQUE)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'e) linkPair called twice with same pair returns false (UNIQUE)',
      () async {
        final notifier = SiblingLinksNotifier();
        final first = await notifier.linkPair(5, 4411);
        expect(first, isTrue);

        final second = await notifier.linkPair(4411, 5);
        expect(second, isFalse);

        final rows = await db.rawQuery('SELECT * FROM Sibling_Links');
        expect(rows.length, 1);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // f) linkPair(5, 5) returns false (self-link rejected)
    // ─────────────────────────────────────────────────────────────────────────
    test('f) linkPair(5, 5) returns false (self-link rejected)', () async {
      final notifier = SiblingLinksNotifier();
      final inserted = await notifier.linkPair(5, 5);
      expect(inserted, isFalse);

      final rows = await db.rawQuery('SELECT * FROM Sibling_Links');
      expect(rows, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // g) loadForStudent(5) returns the link from either side
    // ─────────────────────────────────────────────────────────────────────────
    test('g) loadForStudent(5) returns the link from either side', () async {
      final notifier = SiblingLinksNotifier();
      await notifier.linkPair(5, 4411);

      final linksFor5 = await notifier.loadForStudent(5);
      expect(linksFor5.length, 1);
      expect(linksFor5.first.stu1RegId, 5);
      expect(linksFor5.first.stu2RegId, 4411);

      final linksFor4411 = await notifier.loadForStudent(4411);
      expect(linksFor4411.length, 1);
      expect(linksFor4411.first.stu1RegId, 5);
      expect(linksFor4411.first.stu2RegId, 4411);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // h) loadForStudent(999) returns empty
    // ─────────────────────────────────────────────────────────────────────────
    test('h) loadForStudent(999) returns empty', () async {
      final notifier = SiblingLinksNotifier();
      await notifier.linkPair(5, 4411);

      final links = await notifier.loadForStudent(999);
      expect(links, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // i) unlink removes the row
    // ─────────────────────────────────────────────────────────────────────────
    test('i) unlink removes the row', () async {
      final notifier = SiblingLinksNotifier();
      await notifier.linkPair(5, 4411);

      final links = await notifier.loadForStudent(5);
      expect(links.length, 1);

      await notifier.unlink(links.first.linkId);

      final afterUnlink = await notifier.loadForStudent(5);
      expect(afterUnlink, isEmpty);

      final rows = await db.rawQuery('SELECT * FROM Sibling_Links');
      expect(rows, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // j) CHECK constraint blocks Stu1_RegID >= Stu2_RegID (raw insert test)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'j) CHECK constraint blocks Stu1_RegID >= Stu2_RegID (raw insert test)',
      () async {
        expect(
          () async => await db.rawInsert('''
          INSERT INTO Sibling_Links (LinkID, Stu1_RegID, Stu2_RegID, Relation)
          VALUES (1, 4411, 5, 'sibling')
        '''),
          throwsA(isA<DatabaseException>()),
        );

        expect(
          () async => await db.rawInsert('''
          INSERT INTO Sibling_Links (LinkID, Stu1_RegID, Stu2_RegID, Relation)
          VALUES (2, 5, 5, 'sibling')
        '''),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // k) Wizard "Link as Sibling" with new admission stores pendingSiblingIds
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'k) Wizard "Link as Sibling" with new admission stores pendingSiblingIds',
      () {
        final draftNotifier = WizardDraftNotifier();
        expect(draftNotifier.state.pendingSiblingIds, isEmpty);

        draftNotifier.setPendingSiblingIds([4414, 4415]);
        expect(draftNotifier.state.pendingSiblingIds, [4414, 4415]);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // l) submitStudentAdmission commits Sibling_Links rows after Stu_RegID assign
    // ─────────────────────────────────────────────────────────────────────────
    test('l) submitStudentAdmission commits Sibling_Links rows after Stu_RegID assign', () async {
      final draft = WizardDraft(
        nameFirst: 'Ahmad',
        fName: 'Tariq Mehmood',
        cnicNo: '38302-4567890-4',
        mobile1: '0300-1122334',
        admInClass: 13,
        classSecId: 25,
        pendingSiblingIds: [4414, 4415],
      );

      final newId = await submitStudentAdmission(draft, dbOverride: db);
      expect(newId, greaterThan(0));

      final links = await db.rawQuery(
        'SELECT * FROM Sibling_Links WHERE Stu1_RegID = ? OR Stu2_RegID = ?',
        [newId, newId],
      );
      expect(links.length, 2);

      // Verify canonical order
      for (final link in links) {
        final stu1 = link['Stu1_RegID'] as int;
        final stu2 = link['Stu2_RegID'] as int;
        expect(stu1, lessThan(stu2));
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // m) submitStudentAdmission handles UNIQUE collision (INSERT OR IGNORE)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'm) submitStudentAdmission handles UNIQUE collision (INSERT OR IGNORE)',
      () async {
        // Pre-insert link for 4414 and 4415
        final notifier = SiblingLinksNotifier();
        await notifier.linkPair(4414, 4415);

        final draft = WizardDraft(
          nameFirst: 'Bilal',
          fName: 'Tariq Mehmood',
          cnicNo: '38302-4567890-4',
          mobile1: '0300-9988776',
          admInClass: 13,
          classSecId: 25,
          pendingSiblingIds: [4414],
        );

        final newId = await submitStudentAdmission(draft, dbOverride: db);
        expect(newId, greaterThan(0));

        final links = await db.rawQuery(
          'SELECT * FROM Sibling_Links WHERE Stu1_RegID = ? OR Stu2_RegID = ?',
          [newId, newId],
        );
        expect(links.length, 1);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // n) StudentListRow.siblingCount populated from LEFT JOIN subquery
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'n) StudentListRow.siblingCount populated from LEFT JOIN subquery',
      () async {
        final notifier = SiblingLinksNotifier();
        await notifier.linkPair(4411, 4412);
        await notifier.linkPair(4411, 4413);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final students = await container.read(studentListProvider.future);
        final s4411 = students.firstWhere((s) => s.stuRegId == 4411);
        final s4412 = students.firstWhere((s) => s.stuRegId == 4412);
        final s4414 = students.firstWhere((s) => s.stuRegId == 4414);

        expect(s4411.siblingCount, 2);
        expect(s4412.siblingCount, 1);
        expect(s4414.siblingCount, 0);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // o) StudentList UI shows '-' for 0 siblings, '1' for 1, 'N' for 2+
    // ─────────────────────────────────────────────────────────────────────────
    testWidgets(
      'o) StudentList UI shows "-" for 0 siblings, "1" for 1, "N" for 2+',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final testRows = [
          const StudentListRow(
            stuRegId: 4411,
            fullName: 'Muhammad Ali Khan',
            className: 'Class 10',
            sectionName: 'A',
            status: 'Active',
            sessionYr: '2017-2018',
            siblingCount: 2,
          ),
          const StudentListRow(
            stuRegId: 4412,
            fullName: 'Usman Tariq',
            className: 'Class 10',
            sectionName: 'A',
            status: 'Active',
            sessionYr: '2017-2018',
            siblingCount: 1,
          ),
          const StudentListRow(
            stuRegId: 4413,
            fullName: 'Zainab Bibi',
            className: 'Class 10',
            sectionName: 'A',
            status: 'Active',
            sessionYr: '2017-2018',
            siblingCount: 0,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studentListProvider.overrideWith((ref) => Future.value(testRows)),
              classesProvider.overrideWith(
                (ref) => Future.value(const [
                  SchoolClass(classId: 13, cName: 'Class 10'),
                ]),
              ),
              sectionsProvider.overrideWith(
                (ref) => Future.value(const [
                  ClassSec(classSecId: 25, classId: 13, secName: 'A'),
                ]),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: StudentListScreen())),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('SIBLINGS'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('1'), findsWidgets);
        expect(find.text('-'), findsWidgets);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // p) StudentProfile Family tab loads linked siblings
    // ─────────────────────────────────────────────────────────────────────────
    testWidgets('p) StudentProfile Family tab loads linked siblings', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dummyStudent = Student(
        stuRegId: 4411,
        nameFirst: 'Muhammad',
        nameLast: 'Ali',
        fName: 'Khan Muhammad',
        cnicNo: '38302-1234567-1',
        mobile1: '0300-1234567',
        doAdmission: DateTime(2024, 8, 15),
      );

      final dummyBundle = StudentProfileBundle(
        student: dummyStudent,
        enrollments: const [],
        vouchers: const [],
        totalBilled: 0,
        totalPaid: 0,
        outstandingArrears: 0,
        classRollNo: 1,
        currentClassName: 'Class 10',
        currentSectionName: 'A',
        fatherName: 'Khan Muhammad',
        mobile1: '0300-1234567',
        feeBalanceSummary: 'Rs. 0 clear',
        advances: const [],
        exams: const [],
        attendance: const [],
      );

      final siblingRows = [
        {
          'Stu_RegID': 4412,
          'NameFirst': 'Usman',
          'NameLast': 'Tariq',
          'ClassID': 13,
          'ClassSecID': 25,
          'CName': 'Class 10',
          'SecName': 'A',
          'LinkID': 1,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentProfileProvider(4411).overrideWith((ref) => dummyBundle),
            siblingLinksForStudentProvider(4411)
                .overrideWith((ref) => Future.value(siblingRows)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudentProfileScreen(studentId: '4411')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Click on Family tab
      await tester.tap(find.text('Family'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('LINKED SIBLINGS & FAMILY MEMBERS'), findsOneWidget);
      expect(find.textContaining('Reg #4412'), findsOneWidget);
      expect(find.text('View Profile'), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // q) [Withdraw Student] button on StudentProfile opens confirmation dialog
    // ─────────────────────────────────────────────────────────────────────────
    testWidgets(
      'q) [Withdraw Student] button on StudentProfile opens confirmation dialog',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final dummyStudent = Student(
          stuRegId: 4411,
          nameFirst: 'Muhammad',
          nameLast: 'Ali',
          fName: 'Khan Muhammad',
          cnicNo: '38302-1234567-1',
          mobile1: '0300-1234567',
          doAdmission: DateTime(2024, 8, 15),
        );

        final dummyBundle = StudentProfileBundle(
          student: dummyStudent,
          enrollments: const [],
          vouchers: const [],
          totalBilled: 0,
          totalPaid: 0,
          outstandingArrears: 0,
          classRollNo: 1,
          currentClassName: 'Class 10',
          currentSectionName: 'A',
          fatherName: 'Khan Muhammad',
          mobile1: '0300-1234567',
          feeBalanceSummary: 'Rs. 0 clear',
          advances: const [],
          exams: const [],
          attendance: const [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studentProfileProvider(4411).overrideWith((ref) => dummyBundle),
            ],
            child: const MaterialApp(
              home: Scaffold(body: StudentProfileScreen(studentId: '4411')),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final withdrawBtn = find.text('Withdraw Student');
        expect(withdrawBtn, findsOneWidget);

        await tester.tap(withdrawBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Withdraw Student?'), findsOneWidget);
        expect(
          find.textContaining('School Leaving workflow to formally withdraw'),
          findsOneWidget,
        );
        expect(find.text('Continue to Withdrawal'), findsOneWidget);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // r) Confirmation navigates to /students/leaving?studentId=N
    // ─────────────────────────────────────────────────────────────────────────
    testWidgets('r) Confirmation navigates to /students/leaving?studentId=N', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dummyStudent = Student(
        stuRegId: 4411,
        nameFirst: 'Muhammad',
        nameLast: 'Ali',
        fName: 'Khan Muhammad',
        cnicNo: '38302-1234567-1',
        mobile1: '0300-1234567',
        doAdmission: DateTime(2024, 8, 15),
      );

      final dummyBundle = StudentProfileBundle(
        student: dummyStudent,
        enrollments: const [],
        vouchers: const [],
        totalBilled: 0,
        totalPaid: 0,
        outstandingArrears: 0,
        classRollNo: 1,
        currentClassName: 'Class 10',
        currentSectionName: 'A',
        fatherName: 'Khan Muhammad',
        mobile1: '0300-1234567',
        feeBalanceSummary: 'Rs. 0 clear',
        advances: const [],
        exams: const [],
        attendance: const [],
      );

      String navigatedLocation = '';
      final router = GoRouter(
        initialLocation: '/students/4411',
        routes: [
          GoRoute(
            path: '/students/leaving',
            builder: (context, state) {
              navigatedLocation = state.uri.toString();
              return const Scaffold(body: Text('Leaving Screen Target'));
            },
          ),
          GoRoute(
            path: '/students/:id',
            builder: (context, state) =>
                StudentProfileScreen(studentId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentProfileProvider(4411).overrideWith((ref) => dummyBundle),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Withdraw Student'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Continue to Withdrawal'));
      await tester.pumpAndSettle();

      expect(navigatedLocation, startsWith('/students/leaving?studentId=4411'));
      expect(find.text('Leaving Screen Target'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // s) SchoolLeavingScreen pre-selects student from query param
    // ─────────────────────────────────────────────────────────────────────────
    testWidgets('s) SchoolLeavingScreen pre-selects student from query param', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late SchoolLeavingNotifier leavingNotifier;
      await tester.runAsync(() async {
        leavingNotifier = SchoolLeavingNotifier();
        await leavingNotifier.loadInitialData();
      });

      final router = GoRouter(
        initialLocation: '/students/leaving?studentId=4413',
        routes: [
          GoRoute(
            path: '/students/leaving',
            builder: (context, state) =>
                const Scaffold(body: SchoolLeavingScreen()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolLeavingProvider.overrideWith((ref) => leavingNotifier),
            sessionProvider.overrideWith((ref) {
              final session = SessionNotifier();
              session.setSession(testUser, const [8, 9, 12, 13, 20]);
              return session;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(leavingNotifier.state.selectedStudent, isNotNull);
      expect(leavingNotifier.state.selectedStudent!.stuRegId, 4413);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Layout verification at 1440x900 AND 1440x780 with takeException() == null
    // ─────────────────────────────────────────────────────────────────────────
    testWidgets(
      'Family Tab & Profile layout fits 1440x900 AND 1440x780 without overflow',
      (tester) async {
        final dummyStudent = Student(
          stuRegId: 4411,
          nameFirst: 'Muhammad',
          nameLast: 'Ali',
          fName: 'Khan Muhammad',
          cnicNo: '38302-1234567-1',
          mobile1: '0300-1234567',
          doAdmission: DateTime(2024, 8, 15),
        );

        final dummyBundle = StudentProfileBundle(
          student: dummyStudent,
          enrollments: const [],
          vouchers: const [],
          totalBilled: 0,
          totalPaid: 0,
          outstandingArrears: 0,
          classRollNo: 1,
          currentClassName: 'Class 10',
          currentSectionName: 'A',
          fatherName: 'Khan Muhammad',
          mobile1: '0300-1234567',
          feeBalanceSummary: 'Rs. 0 clear',
          advances: const [],
          exams: const [],
          attendance: const [],
        );

        for (final size in [const Size(1440, 900), const Size(1440, 780)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                studentProfileProvider(4411).overrideWith((ref) => dummyBundle),
                selectedStudentTabProvider.overrideWith((ref) => 7),
                siblingLinksForStudentProvider(4411)
                    .overrideWith((ref) => Future.value(const [])),
              ],
              child: const MaterialApp(
                home: Scaffold(body: StudentProfileScreen(studentId: '4411')),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
