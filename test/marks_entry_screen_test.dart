import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/marks_entry_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/marks_entry_row.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/exams/marks_entry_screen.dart';
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

  group('MarksEntryScreen Provider & Logic Tests', () {
    test('a) loads sessions, terms, classes, sections on mount', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(marksEntryProvider);
      expect(state.sessionYears, contains('2017-2018'));
      expect(state.terms.length, 3); // 1st Term, 2nd Term, Final Term
      expect(state.classes, isNotEmpty);
      expect(state.isLoading, isFalse);
    });

    test('b) selecting Class 10/Sec A/1st Term loads 10 students', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setExTermId(1); // 1st Term
      await notifier.setClassId(13); // Class 10
      notifier.setClassSecId(25); // Sec A

      await notifier.loadEnrolledStudents();

      final state = container.read(marksEntryProvider);
      expect(state.roster.length, 10);
      expect(state.roster.first.stuRegId, 4411);
      expect(state.roster.first.rollNo, 1);
    });

    test('c) loading subjects for Class 10 shows 5 (Islamiat, Maths, Urdu, English, Computer Science)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setClassId(13);

      final state = container.read(marksEntryProvider);
      expect(state.subjects.length, 5);
      final names = state.subjects.map((s) => s['SubjName'] as String).toList();
      expect(names, [
        'Islamiat',
        'Maths',
        'Urdu',
        'English',
        'Computer Science',
      ]);
    });

    test('d) Generate Exam Cohort creates ExamMas for all 10, toast Already exist = 0. New Students Added= 10', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setExTermId(1);
      await notifier.setClassId(13);
      notifier.setClassSecId(25);
      await notifier.loadEnrolledStudents();

      await notifier.generateExamCohort();

      final state = container.read(marksEntryProvider);
      expect(state.toast, 'Already exist = 0. New Students Added= 10');

      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM ExamMas WHERE ExamInfoID = 1 AND ClassID = 13',
      );
      expect(countRows.first['c'], 10);
    });

    test('e) Generate Exam Cohort idempotent: second run toast Already exist = 10. New Students Added= 0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setExTermId(1);
      await notifier.setClassId(13);
      notifier.setClassSecId(25);
      await notifier.loadEnrolledStudents();

      await notifier.generateExamCohort();
      await notifier.generateExamCohort();

      final state = container.read(marksEntryProvider);
      expect(state.toast, 'Already exist = 10. New Students Added= 0');
    });

    test('f) Enter key moves focus to next row theory field', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setExTermId(1);
      await notifier.setClassId(13);
      notifier.setClassSecId(25);
      notifier.setSubjId(2); // Maths (100 theory, 0 practical)
      await notifier.loadEnrolledStudents();

      final state = container.read(marksEntryProvider);
      expect(state.roster.length, 10);
      expect(state.practicalMax, 0);

      // Verify theory input for row 0
      notifier.updateTheory(state.roster[0].stuRegId, 85.0);
      expect(container.read(marksEntryProvider).roster[0].theoryObtained, 85.0);

      // Verify row 1 is ready to be focused / updated
      notifier.updateTheory(state.roster[1].stuRegId, 92.0);
      expect(container.read(marksEntryProvider).roster[1].theoryObtained, 92.0);
    });

    test('g) Absent checkbox zeroes marks and shows ABS grade', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setClassId(13);
      notifier.setClassSecId(25);
      notifier.setSubjId(2);
      await notifier.loadEnrolledStudents();

      final stuId = container.read(marksEntryProvider).roster.first.stuRegId;
      notifier.updateTheory(stuId, 85.0);
      expect(
        container.read(marksEntryProvider).roster.first.theoryObtained,
        85.0,
      );

      notifier.toggleAbsent(stuId);
      final absentRow = container.read(marksEntryProvider).roster.first;
      expect(absentRow.isAbsent, isTrue);
      expect(absentRow.theoryObtained, 0.0);
      expect(absentRow.totalObtained, 0.0);
      expect(
        absentRow.computeGrade(container.read(marksEntryProvider).exGradeRows),
        'ABS',
      );
    });

    test('h) Grade calc: 95%->A, 82%->B, 74%->C, 65%->D, 45%->F; 30% with no ExGrade rows -> F (33% fallback)', () {
      final exGrades = [
        {'Grad': 'A', 'GradMinMarks': 90, 'GradMaxMarks': 100},
        {'Grad': 'B', 'GradMinMarks': 80, 'GradMaxMarks': 89},
        {'Grad': 'C', 'GradMinMarks': 70, 'GradMaxMarks': 79},
        {'Grad': 'D', 'GradMinMarks': 60, 'GradMaxMarks': 69},
        {'Grad': 'F', 'GradMinMarks': 0, 'GradMaxMarks': 59},
      ];

      const rowA = MarksEntryRow(
        stuRegId: 1,
        rollNo: 1,
        nameFirst: 'A',
        nameLast: 'Student',
        theoryObtained: 95,
        theoryMax: 100,
      );
      expect(rowA.computeGrade(exGrades), 'A');

      const rowB = MarksEntryRow(
        stuRegId: 2,
        rollNo: 2,
        nameFirst: 'B',
        nameLast: 'Student',
        theoryObtained: 82,
        theoryMax: 100,
      );
      expect(rowB.computeGrade(exGrades), 'B');

      const rowC = MarksEntryRow(
        stuRegId: 3,
        rollNo: 3,
        nameFirst: 'C',
        nameLast: 'Student',
        theoryObtained: 74,
        theoryMax: 100,
      );
      expect(rowC.computeGrade(exGrades), 'C');

      const rowD = MarksEntryRow(
        stuRegId: 4,
        rollNo: 4,
        nameFirst: 'D',
        nameLast: 'Student',
        theoryObtained: 65,
        theoryMax: 100,
      );
      expect(rowD.computeGrade(exGrades), 'D');

      const rowF = MarksEntryRow(
        stuRegId: 5,
        rollNo: 5,
        nameFirst: 'F',
        nameLast: 'Student',
        theoryObtained: 45,
        theoryMax: 100,
      );
      expect(rowF.computeGrade(exGrades), 'F');

      // Fallback with empty exGradeRows
      const fallbackFail = MarksEntryRow(
        stuRegId: 6,
        rollNo: 6,
        nameFirst: 'Fail',
        nameLast: 'Student',
        theoryObtained: 30,
        theoryMax: 100,
      );
      expect(fallbackFail.computeGrade(const []), 'F');

      const fallbackPass = MarksEntryRow(
        stuRegId: 7,
        rollNo: 7,
        nameFirst: 'Pass',
        nameLast: 'Student',
        theoryObtained: 35,
        theoryMax: 100,
      );
      expect(fallbackPass.computeGrade(const []), 'PASS');
    });

    test('i) Save persists with MAX+1 ExDetID and audit toast', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setExTermId(1);
      await notifier.setClassId(13);
      notifier.setClassSecId(25);
      notifier.setSubjId(2);
      await notifier.loadEnrolledStudents();

      for (final r in container.read(marksEntryProvider).roster) {
        notifier.updateTheory(r.stuRegId, 75.0);
      }

      final success = await notifier.saveAllMarks(overwriteConfirmed: true);
      expect(success, isTrue);

      final state = container.read(marksEntryProvider);
      expect(
        state.toast,
        contains(
          'You Selected 10 Students. Marks Entered for 10 Students and Marks Changed for 0 Students not appeared are 0',
        ),
      );

      final detRows = await db.rawQuery(
        'SELECT * FROM ExamDet WHERE SubjID = 2',
      );
      expect(detRows.length, 10);
      expect(detRows.first['ExDetID'], isNotNull);
    });

    test(
      'j) Save updates existing ExamDet on second save (no duplicate)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(marksEntryProvider.notifier);
        await notifier.loadInitialData();
        await notifier.setExTermId(1);
        await notifier.setClassId(13);
        notifier.setClassSecId(25);
        notifier.setSubjId(2);
        await notifier.loadEnrolledStudents();

        for (final r in container.read(marksEntryProvider).roster) {
          notifier.updateTheory(r.stuRegId, 75.0);
        }
        await notifier.saveAllMarks(overwriteConfirmed: true);

        // Now change marks for student 4411
        notifier.updateTheory(4411, 88.0);
        final secondSave = await notifier.saveAllMarks(
          overwriteConfirmed: true,
        );
        expect(secondSave, isTrue);

        final state = container.read(marksEntryProvider);
        expect(
          state.toast,
          contains(
            'Marks Entered for 0 Students and Marks Changed for 1 Students',
          ),
        );

        final detRows = await db.rawQuery(
          'SELECT * FROM ExamDet WHERE SubjID = 2',
        );
        expect(detRows.length, 10); // still 10, no duplicate rows
      },
    );

    test('k) Save validation gates fire verbatim', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();

      // Gate 1: Subject not chosen
      final gate1 = await notifier.saveAllMarks();
      expect(gate1, isFalse);
      expect(
        container.read(marksEntryProvider).errorMessage,
        'Choose Subject please',
      );

      // Set term (which sets ExamInfo) and subject, but roster empty
      await notifier.setExTermId(1);
      notifier.setSubjId(1);
      final gate2 = await notifier.saveAllMarks();
      expect(gate2, isFalse);
      expect(
        container.read(marksEntryProvider).errorMessage,
        'Load class students for Marks',
      );

      // Load students, but deselect all
      await notifier.setExTermId(1);
      await notifier.setClassId(13);
      notifier.setClassSecId(25);
      notifier.setSubjId(1);
      await notifier.loadEnrolledStudents();
      notifier.toggleSelectAll(); // unselect all

      final gate3 = await notifier.saveAllMarks();
      expect(gate3, isFalse);
      expect(
        container.read(marksEntryProvider).errorMessage,
        ' No Student Selected for Marks.',
      );
    });

    test('l) Total/percentage: CS 65/75+20/25 = 85/100 = 85% -> B', () {
      final exGrades = [
        {'Grad': 'A', 'GradMinMarks': 90, 'GradMaxMarks': 100},
        {'Grad': 'B', 'GradMinMarks': 80, 'GradMaxMarks': 89},
        {'Grad': 'C', 'GradMinMarks': 70, 'GradMaxMarks': 79},
        {'Grad': 'D', 'GradMinMarks': 60, 'GradMaxMarks': 69},
        {'Grad': 'F', 'GradMinMarks': 0, 'GradMaxMarks': 59},
      ];

      const csRow = MarksEntryRow(
        stuRegId: 4411,
        rollNo: 1,
        nameFirst: 'Ali',
        nameLast: 'Ahmed',
        theoryObtained: 65,
        practicalObtained: 20,
        theoryMax: 75,
        practicalMax: 25,
      );

      expect(csRow.totalObtained, 85.0);
      expect(csRow.totalMax, 100);
      expect(csRow.percentage, 85.0);
      expect(csRow.computeGrade(exGrades), 'B');
    });

    test('o) teacher override updates state and cohort creation', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(marksEntryProvider.notifier);
      await notifier.loadInitialData();
      expect(container.read(marksEntryProvider).teachers, isNotEmpty);

      notifier.setTeacherOverride(2);
      expect(container.read(marksEntryProvider).selectedTeacherIdOverride, 2);

      notifier.setTeacherOverride(null);
      expect(
        container.read(marksEntryProvider).selectedTeacherIdOverride,
        isNull,
      );
    });
  });

  group('MarksEntryScreen Layout & Responsiveness', () {
    testWidgets('m) Fits 1440x900 without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/exams/marks',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/exams/marks',
                builder: (context, state) => const MarksEntryScreen(),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableSessionsProvider.overrideWith(
              (ref) async => ['2017-2018'],
            ),
            sessionProvider.overrideWith((ref) {
              final notifier = SessionNotifier();
              notifier.setSession(testUser, const [10, 23, 24]);
              return notifier;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MarksEntryScreen), findsOneWidget);
      expect(find.text('Save All Marks (Ctrl+S)'), findsOneWidget);
    });

    testWidgets('n) Fits 1440x780 without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/exams/marks',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/exams/marks',
                builder: (context, state) => const MarksEntryScreen(),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableSessionsProvider.overrideWith(
              (ref) async => ['2017-2018'],
            ),
            sessionProvider.overrideWith((ref) {
              final notifier = SessionNotifier();
              notifier.setSession(testUser, const [
                10,
                23,
                24,
              ], hasWeakPasswordWarning: true);
              return notifier;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MarksEntryScreen), findsOneWidget);
    });
  });
}
