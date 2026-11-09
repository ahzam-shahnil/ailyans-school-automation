import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/batch_promotion_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/sibling_links_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/student_profile_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/student.dart';
import 'package:school_automation/models/student_enrollment.dart';
import 'package:school_automation/models/student_list_row.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/students/batch_promotion_screen.dart';
import 'package:school_automation/screens/students/student_list_screen.dart';
import 'package:school_automation/screens/students/student_profile_screen.dart';
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
    await DatabaseSeeder.seedIfEmpty(db);
    await DatabaseSeeder.seedFeeTariffsIfEmpty(db);

    // Seed test students for batch promotion tests
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

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget wrapStudentList({List<StudentListRow>? seededRows}) {
    final rows = seededRows ??
        const [
          StudentListRow(
            stuRegId: 4411,
            fullName: 'Muhammad Ahsan Khan',
            fatherName: 'Muhammad Tariq',
            className: 'Class 10',
            sectionName: 'A',
            rollNo: 1,
            status: 'Active',
            sessionYr: '2017-2018',
          ),
          StudentListRow(
            stuRegId: 4412,
            fullName: 'Ayesha Noor',
            fatherName: 'Tariq Mehmood',
            className: 'Class 10',
            sectionName: 'A',
            rollNo: 2,
            status: 'Active',
            sessionYr: '2017-2018',
          ),
          StudentListRow(
            stuRegId: 4413,
            fullName: 'Hamza Ali',
            fatherName: 'Liaquat Ali',
            className: 'Class 10',
            sectionName: 'A',
            rollNo: 3,
            status: 'Active',
            sessionYr: '2017-2018',
          ),
        ];

    const seededClasses = [
      SchoolClass(classId: 1, cName: 'Play Group'),
      SchoolClass(classId: 8, cName: 'Class 5'),
      SchoolClass(classId: 13, cName: 'Class 10'),
    ];

    const seededSections = [
      ClassSec(classSecId: 15, classId: 8, secName: 'A'),
      ClassSec(classSecId: 25, classId: 13, secName: 'A'),
      ClassSec(classSecId: 26, classId: 13, secName: 'B'),
    ];

    final router = GoRouter(
      initialLocation: '/students',
      routes: [
        GoRoute(
          path: '/students',
          builder: (context, state) => const StudentListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => Scaffold(
                body: Text('Student Profile ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        studentListProvider.overrideWith((ref) => Future.value(rows)),
        classesProvider.overrideWith((ref) => Future.value(seededClasses)),
        sectionsProvider.overrideWith((ref) => Future.value(seededSections)),
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

  testWidgets(
    'StudentListScreen at 360x800 renders Stitch 3-up quick launch tiles, collapsible filter card, and whole-page CustomScrollView with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      await tester.pumpWidget(wrapStudentList());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify whole-page CustomScrollView
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify 3-up Quick Launch Tiles
      expect(find.text('Enrollment'), findsOneWidget);
      expect(find.text('Promotion'), findsOneWidget);
      expect(find.text('Departure'), findsOneWidget);

      // Verify Collapsible Filters Header
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('All Classes'), findsOneWidget);
      expect(find.text('All Sections'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
    },
  );

  testWidgets(
    'StudentListScreen at 390x844 renders Stitch student cards with Father Name, #stuRegId monospace badge, and sticky pagination bar with zero overflow',
    (tester) async {
      setViewport(tester, const Size(390, 844));

      await tester.pumpWidget(wrapStudentList());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify student card details
      expect(find.text('Muhammad Ahsan Khan'), findsOneWidget);
      expect(find.text('F/N: Muhammad Tariq'), findsOneWidget);
      expect(find.text('#4411'), findsOneWidget);
      expect(find.byType(Card), findsWidgets);

      // Verify sticky pagination bar at bottom
      expect(find.textContaining('Showing'), findsOneWidget);
      expect(find.textContaining('1 / 1'), findsOneWidget);
    },
  );

  testWidgets(
    'BatchPromotionScreen at 360x800 renders Stitch route hero card, 2-up KPI cards, and target cohort parameters card with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late BatchPromotionNotifier notifier;
      await tester.runAsync(() async {
        notifier = BatchPromotionNotifier();
        await notifier.loadInitialData();
      });

      await tester.pumpWidget(wrapBatchPromotion(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify Route Hero Card overline
      expect(find.text('Batch Promotion'), findsOneWidget);

      // Verify 2-up KPI Cards
      expect(find.text('Eligible for Promotion'), findsOneWidget);
      expect(find.text('Conditional / Hold'), findsOneWidget);

      // Verify Target Cohort Parameters Card
      expect(find.text('TARGET COHORT PARAMETERS'), findsOneWidget);
      expect(find.text('SOURCE CLASS'), findsOneWidget);
      expect(find.text('TARGET CLASS'), findsOneWidget);
    },
  );

  testWidgets(
    'BatchPromotionScreen at 390x844 renders Stitch candidate cards with Promoted pill and sticky Promote Cohort bar with zero overflow',
    (tester) async {
      setViewport(tester, const Size(390, 844));

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

      // Verify candidate cards with promoted pills
      expect(find.text('Rashid Minhas'), findsOneWidget);
      expect(find.text('Tariq Aziz'), findsOneWidget);
      expect(find.text('#4421'), findsOneWidget);
      expect(find.text('#4422'), findsOneWidget);
      expect(find.textContaining('Promoted to'), findsWidgets);

      // Verify sticky promote cohort bar
      expect(find.text('2 Selected'), findsOneWidget);
      expect(find.textContaining('Promote'), findsWidgets);
    },
  );

  final testProfileStudent = Student(
    stuRegId: 4411,
    nameFirst: 'Muhammad',
    nameMiddle: 'Ahsan',
    nameLast: 'Khan',
    dob: DateTime(2010, 8, 14),
    bFormNo: '37405-1294819-1',
    fName: 'Muhammad Tariq',
    cnicNo: '37405-8821943-7',
    pAddress: 'House #14, St 2, Mohallah Khel, Mianwali',
    mobile1: '+92 300 9481204',
    religion: 'Islam',
    sex: 'Male',
    doAdmission: DateTime(2018, 4, 10),
    remarls: 'Class Representative. Exemplary laboratory conduct.',
  );

  final testProfileBundle = StudentProfileBundle(
    student: testProfileStudent,
    enrollments: const [
      StudentEnrollment(
        stuRegId: 4411,
        classId: 13,
        classSecId: 25,
        classRollNo: 1,
        sessionYr: '2026-27',
        present: 1,
        vGen: 'Y',
        className: 'Class 10',
        sectionName: 'A',
      ),
    ],
    vouchers: const [],
    totalBilled: 0,
    totalPaid: 0,
    outstandingArrears: 0,
    classRollNo: 1,
    currentClassName: 'Class 10',
    currentSectionName: 'A',
    fatherName: 'Muhammad Tariq',
    mobile1: '+92 300 9481204',
    feeBalanceSummary: 'Rs. 0 outstanding',
    advances: const [],
    exams: const [],
    attendance: const [
      {'Present': 1, 'Status': 'P'},
      {'Present': 1, 'Status': 'P'},
    ],
    isEnrolled: true,
  );

  Widget wrapStudentProfile({
    required StudentProfileBundle bundle,
    List<Map<String, dynamic>>? siblings,
  }) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [8, 12, 13, 20]);
          return sNotifier;
        }),
        studentProfileProvider(bundle.student.stuRegId)
            .overrideWith((ref) => bundle),
        if (siblings != null)
          siblingLinksForStudentProvider(bundle.student.stuRegId)
              .overrideWith((ref) => Future.value(siblings)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StudentProfileScreen(studentId: '${bundle.student.stuRegId}'),
        ),
      ),
    );
  }

  testWidgets(
    'StudentProfileScreen at 360x800 renders Stitch mobile hero card, 3-column metrics well, and zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      final mockSiblings = [
        {
          'Stu_RegID': 4412,
          'NameFirst': 'Zainab',
          'NameLast': 'Tariq',
          'CName': 'Class 7',
          'SecName': 'B',
          'ClassRollNo': 5,
        },
      ];

      await tester.pumpWidget(
        wrapStudentProfile(
          bundle: testProfileBundle,
          siblings: mockSiblings,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify Top Navigation
      expect(find.text('Back to Students Directory'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      // Verify Hero Identity Card
      expect(find.text('Muhammad Ahsan Khan'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('F/N: Muhammad Tariq'), findsOneWidget);
      expect(find.text('Reg #4411'), findsOneWidget);
      expect(
        find.textContaining('Class Class 10-A · Roll #01'),
        findsOneWidget,
      );
      expect(find.text('Session 2026-27'), findsOneWidget);

      // Verify 3-Column Metrics Well
      expect(find.text('FEE DUES'), findsOneWidget);
      expect(find.text('Rs. 0'), findsOneWidget);
      expect(find.text('ATTENDANCE'), findsOneWidget);
      expect(find.text('SIBLINGS'), findsOneWidget);
      expect(find.text('1 Enrolled'), findsOneWidget);

      // Verify Sticky Bottom Action Bar
      expect(find.text('Live Record Synced'), findsOneWidget);
      expect(find.text('Collect Fee'), findsOneWidget);
      expect(find.text('Edit Dossier'), findsOneWidget);
    },
  );

  testWidgets(
    'StudentProfileScreen at 390x844 renders Stitch bento cards (Personal, Guardian, Academic), sibling network, and zero overflow',
    (tester) async {
      setViewport(tester, const Size(390, 844));

      final mockSiblings = [
        {
          'Stu_RegID': 4412,
          'NameFirst': 'Zainab',
          'NameLast': 'Tariq',
          'CName': 'Class 7',
          'SecName': 'B',
          'ClassRollNo': 5,
        },
        {
          'Stu_RegID': 4413,
          'NameFirst': 'Bilal',
          'NameLast': 'Tariq',
          'CName': 'Class 4',
          'SecName': 'A',
          'ClassRollNo': 12,
        },
      ];

      await tester.pumpWidget(
        wrapStudentProfile(
          bundle: testProfileBundle,
          siblings: mockSiblings,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify Card A: Personal & Demographic Record
      expect(find.text('PERSONAL & DEMOGRAPHIC RECORD'), findsOneWidget);
      expect(find.text('ID-VERIFIED'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('14-Aug-2010'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Student B-Form / CNIC'), findsOneWidget);
      expect(find.text('37405-1294819-1'), findsOneWidget);
      expect(find.text('Blood Group'), findsOneWidget);
      expect(find.text('B+ Positive'), findsOneWidget);
      expect(find.text('Religion'), findsOneWidget);
      expect(find.text('Islam'), findsOneWidget);
      expect(find.text('Domicile Territory'), findsOneWidget);

      // Verify Card B: Guardian & Sibling Network
      expect(find.text('GUARDIAN & SIBLING NETWORK'), findsOneWidget);
      expect(find.text('Primary Guardian'), findsOneWidget);
      expect(find.textContaining('Muhammad Tariq (Father)'), findsOneWidget);
      expect(find.text('37405-8821943-7'), findsOneWidget);
      expect(find.text('Emergency Contact'), findsOneWidget);
      expect(find.text('+92 300 9481204'), findsOneWidget);
      expect(find.text('Permanent Residence'), findsOneWidget);
      expect(find.text('Registered Siblings in Ailyans'), findsOneWidget);
      expect(find.text('Kinship Concession Applied'), findsOneWidget);
      expect(find.text('Zainab Tariq'), findsOneWidget);
      expect(find.text('Bilal Tariq'), findsOneWidget);

      // Verify Card C: Academic History & Placement
      expect(find.text('ACADEMIC HISTORY & PLACEMENT'), findsOneWidget);
      expect(find.text('8th Year'), findsOneWidget);
      expect(find.text('Initial Admission'), findsOneWidget);
      expect(find.text('10-Apr-2018'), findsOneWidget);
      expect(find.text('Admitted In'), findsOneWidget);
      expect(find.text('Current Placement'), findsOneWidget);
      expect(find.text('Medium of Instruction'), findsOneWidget);

      // Verify Card D: Assigned Campus
      expect(find.text('ASSIGNED CAMPUS'), findsOneWidget);
      expect(find.text('Main Girls & Boys Senior Wing'), findsOneWidget);
    },
  );
}
