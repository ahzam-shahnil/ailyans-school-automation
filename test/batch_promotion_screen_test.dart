import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/batch_promotion_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/students/batch_promotion_screen.dart';
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

  group('BatchPromotionScreen Provider & Logic Tests', () {
    test('a) loads sessions incl 2018-2019 and 2017-2018', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(batchPromotionProvider.notifier).loadInitialData();
      final state = container.read(batchPromotionProvider);

      expect(state.availableSessions, contains('2018-2019'));
      expect(state.availableSessions, contains('2017-2018'));
      expect(state.sourceSessionYr, '2017-2018');
      expect(state.targetSessionYr, '2018-2019');
      expect(state.classes, isNotEmpty);
    });

    test(
      'b) source Class 5-A / 2017-2018 -> Load -> candidates loaded',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(batchPromotionProvider.notifier);
        await notifier.loadInitialData();
        await notifier.setSourceClassId(8); // Class 5
        notifier.setSourceClassSecId(15); // Sec A
        notifier.setSourceSessionYr('2017-2018');

        final (ok, msg) = await notifier.loadCandidates();
        expect(ok, isTrue);
        expect(msg, 'Cohort loaded');

        final state = container.read(batchPromotionProvider);
        expect(state.loadedRoster, isTrue);
        expect(state.candidates.length, 2);
        expect(state.candidates[0].stuRegId, 4421);
        expect(state.candidates[1].stuRegId, 4422);
        expect(state.candidates[0].isSelected, isTrue);
        expect(state.candidates[1].isSelected, isTrue);
      },
    );

    test('c) source 0 students -> No Student to Promote', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchPromotionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setSourceClassId(7); // Class 4 (0 students)
      notifier.setSourceClassSecId(13); // Sec A
      notifier.setSourceSessionYr('2017-2018');

      final (ok, msg) = await notifier.loadCandidates();
      expect(ok, isFalse);
      expect(msg, 'No Student to Promote');

      final state = container.read(batchPromotionProvider);
      expect(state.loadedRoster, isTrue);
      expect(state.candidates, isEmpty);
    });

    test('d) Select All toggles', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchPromotionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setSourceClassId(8);
      notifier.setSourceClassSecId(15);
      notifier.setSourceSessionYr('2017-2018');
      await notifier.loadCandidates();

      var state = container.read(batchPromotionProvider);
      expect(state.selectedCount, 2);

      // Deselect all
      notifier.toggleSelectAll();
      state = container.read(batchPromotionProvider);
      expect(state.selectedCount, 0);

      // Select all
      notifier.toggleSelectAll();
      state = container.read(batchPromotionProvider);
      expect(state.selectedCount, 2);
    });

    test(
      'e) marks < default (35 < 40) -> failed, unchecked, disabled',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(batchPromotionProvider.notifier);
        await notifier.loadInitialData();
        await notifier.setSourceClassId(8);
        notifier.setSourceClassSecId(15);
        notifier.setSourceSessionYr('2017-2018');
        await notifier.loadCandidates();

        // Update student 4421 marks to 35 (below default 40)
        notifier.updateRowPassingMarks(4421, 35);

        final state = container.read(batchPromotionProvider);
        final student = state.candidates.firstWhere((c) => c.stuRegId == 4421);
        expect(student.isFailed, isTrue);
        expect(student.isSelected, isFalse);

        // Attempting to toggle selection should stay false when failed
        notifier.toggleRowSelected(4421);
        final stateAfter = container.read(batchPromotionProvider);
        expect(
          stateAfter.candidates
              .firstWhere((c) => c.stuRegId == 4421)
              .isSelected,
          isFalse,
        );
      },
    );

    test('f) default marks change re-seeds only non-manually-edited', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchPromotionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setSourceClassId(8);
      notifier.setSourceClassSecId(15);
      notifier.setSourceSessionYr('2017-2018');
      await notifier.loadCandidates();

      // Manually edit 4421 to 75
      notifier.updateRowPassingMarks(4421, 75);

      // Change default marks to 50
      notifier.setDefaultPassingMarks(50);

      final state = container.read(batchPromotionProvider);
      final c1 = state.candidates.firstWhere((c) => c.stuRegId == 4421);
      final c2 = state.candidates.firstWhere((c) => c.stuRegId == 4422);

      expect(c1.currentPassingMarks, 75); // preserved
      expect(c2.currentPassingMarks, 50); // updated to new default
    });

    test('g) route strip red when targetClassId < sourceClassId', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchPromotionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setSourceClassId(8); // Class 5
      await notifier.setTargetClassId(7); // Class 4 (lower)

      final (valid, err) = notifier.validateBeforePromote();
      expect(valid, isFalse);
      expect(
        err,
        'Target class is lower than source class. Choose the same or a higher class.',
      );
    });

    test(
      'h) route strip red when targetSessionYr <= sourceSessionYr',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(batchPromotionProvider.notifier);
        await notifier.loadInitialData();
        await notifier.setSourceClassId(8); // Class 5
        notifier.setSourceClassSecId(15);
        notifier.setSourceSessionYr('2017-2018');
        await notifier.setTargetClassId(9); // Class 6
        notifier.setTargetClassSecId(17);
        notifier.setTargetSessionYr('2017-2018'); // Same year

        final (valid, err) = notifier.validateBeforePromote();
        expect(valid, isFalse);
        expect(err, 'Target session must be later than source session.');
      },
    );

    test(
      'i) source Class 10 -> graduation banner + target dropdowns disabled',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(batchPromotionProvider.notifier);
        await notifier.loadInitialData();
        await notifier.setSourceClassId(13); // Class 10

        final state = container.read(batchPromotionProvider);
        expect(state.isGraduationMode, isTrue);
        expect(state.targetClassId, isNull);
        expect(state.targetSections, isEmpty);
      },
    );

    test('j) regular promotion Class 5 -> Class 6 in 2018-2019: source Present=0, target Present=1 VGen=N, target rolls 1..N, TempPromoHistory 1 row', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchPromotionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setSourceClassId(8); // Class 5
      notifier.setSourceClassSecId(15);
      notifier.setSourceSessionYr('2017-2018');
      await notifier.setTargetClassId(9); // Class 6
      notifier.setTargetClassSecId(17); // Sec A
      notifier.setTargetSessionYr('2018-2019');
      await notifier.loadCandidates();

      final (ok, msg) = await notifier.promoteSelectedStudents();
      expect(ok, isTrue);
      expect(msg, '2 Students Promoted to Next Class');

      // Verify source records Present=0
      final sourceRows = await db.rawQuery(
        'SELECT Present, PromotionDate, PassingMarks FROM Student_Class WHERE ClassID = ? AND SessionYr = ?',
        [8, '2017-2018'],
      );
      expect(sourceRows.length, 2);
      for (final r in sourceRows) {
        expect(r['Present'], 0);
        expect(r['PromotionDate'], isNotNull);
      }

      // Verify target records Present=1, VGen='N', ClassRollNo sequential 1..2
      final targetRows = await db.rawQuery(
        'SELECT Stu_RegID, ClassRollNo, Present, VGen FROM Student_Class WHERE ClassID = ? AND SessionYr = ? ORDER BY ClassRollNo ASC',
        [9, '2018-2019'],
      );
      expect(targetRows.length, 2);
      expect(targetRows[0]['ClassRollNo'], 1);
      expect(targetRows[0]['Present'], 1);
      expect(targetRows[0]['VGen'], 'N');
      expect(targetRows[1]['ClassRollNo'], 2);
      expect(targetRows[1]['Present'], 1);
      expect(targetRows[1]['VGen'], 'N');

      // Verify TempPromoHistory
      final histRows = await db.rawQuery('SELECT * FROM TempPromoHistory');
      expect(histRows.length, 1);
      expect(histRows.first['FromClass'], 'Class 5');
      expect(histRows.first['ToClass'], 'Class 6');
      expect(histRows.first['Strenght'], 2);
    });

    test('k) graduation: source Present=0, SchLeaving rows inserted, NO Student_Class target inserts, TempPromoHistory has ToClass=Graduated', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchPromotionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.setSourceClassId(13); // Class 10
      notifier.setSourceClassSecId(25);
      notifier.setSourceSessionYr('2017-2018');
      await notifier.loadCandidates();

      final (ok, msg) = await notifier.promoteSelectedStudents();
      expect(ok, isTrue);
      expect(msg, '10 Students Graduated and Recorded in School Leaving');

      // Verify source Present=0
      final sourceRows = await db.rawQuery(
        'SELECT Present FROM Student_Class WHERE ClassID = ? AND SessionYr = ?',
        [13, '2017-2018'],
      );
      expect(sourceRows.length, 10);
      for (final r in sourceRows) {
        expect(r['Present'], 0);
      }

      // Verify SchLeaving has 10 rows
      final slRows = await db.rawQuery('SELECT * FROM SchLeaving');
      expect(slRows.length, 10);
      expect(slRows.first['Charactor'], 'Good ');
      expect(slRows.first['TermOfLeavign'], 'Completed Studies');

      // Verify NO new Student_Class rows for 2018-2019
      final targetCheck = await db.rawQuery(
        'SELECT * FROM Student_Class WHERE SessionYr = ?',
        ['2018-2019'],
      );
      expect(targetCheck, isEmpty);

      // Verify TempPromoHistory
      final histRows = await db.rawQuery('SELECT * FROM TempPromoHistory');
      expect(histRows.length, 1);
      expect(histRows.first['ToClass'], 'Graduated');
      expect(histRows.first['ToSection'], '-');
      expect(histRows.first['Strenght'], 10);
    });

    test(
      'l) duplicate detection: student already in target class skips',
      () async {
        // Pre-insert student 4421 in target class 6
        await db.rawInsert('''
        INSERT INTO Student_Class (Stu_RegID, ClassID, ClassSecID, ClassRollNo, SessionYr, Present, VGen)
        VALUES (4421, 9, 17, 10, '2018-2019', 1, 'N')
      ''');

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(batchPromotionProvider.notifier);
        await notifier.loadInitialData();
        await notifier.setSourceClassId(8); // Class 5
        notifier.setSourceClassSecId(15);
        notifier.setSourceSessionYr('2017-2018');
        await notifier.setTargetClassId(9); // Class 6
        notifier.setTargetClassSecId(17);
        notifier.setTargetSessionYr('2018-2019');
        await notifier.loadCandidates();

        final (ok, msg) = await notifier.promoteSelectedStudents();
        expect(ok, isTrue);
        // Student 4421 was skipped, only 4422 promoted
        expect(msg, '1 Students Promoted to Next Class');

        // Target cohort has 2 students (4421 pre-existing, 4422 newly promoted)
        final targetCohort = await db.rawQuery(
          'SELECT Stu_RegID, ClassRollNo FROM Student_Class WHERE ClassID = ? AND SessionYr = ? ORDER BY ClassRollNo ASC',
          [9, '2018-2019'],
        );
        expect(targetCohort.length, 2);
      },
    );

    test('m) validation gates fire verbatim (Select Class Want To Promote, Select - TO Section , No Student Selected)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchPromotionProvider.notifier);
      await notifier.loadInitialData();

      // Gate 1: No source class
      var (ok, err) = notifier.validateBeforePromote();
      expect(ok, isFalse);
      expect(err, 'Select Class Want To Promote');

      // Set source class
      await notifier.setSourceClassId(8);
      notifier.setSourceClassSecId(15);
      notifier.setSourceSessionYr('2017-2018');
      await notifier.setTargetClassId(9);
      notifier.setTargetClassSecId(null); // Clear target section

      // Gate 2: Missing target section
      (ok, err) = notifier.validateBeforePromote();
      expect(ok, isFalse);
      expect(err, 'Select - TO Section ');

      // Set target section, but candidates not loaded yet
      notifier.setTargetClassSecId(17);
      (ok, err) = notifier.validateBeforePromote();
      expect(ok, isFalse);
      expect(err, 'No Student to Promote');

      // Load candidates, then deselect all
      await notifier.loadCandidates();
      notifier.toggleSelectAll(); // 0 selected

      // Gate 4: No Student Selected
      (ok, err) = notifier.validateBeforePromote();
      expect(ok, isFalse);
      expect(err, 'No Student Selected');
    });
  });

  group('BatchPromotionScreen UI & Responsiveness Tests', () {
    testWidgets('n) fits 1440x900 AND 1440x780', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/students/promote',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/students/promote',
                builder: (context, state) => const BatchPromotionScreen(),
              ),
            ],
          ),
        ],
      );

      Widget createWidget() {
        return ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) {
              final notifier = SessionNotifier();
              notifier.setSession(testUser, const [8, 12, 13, 20]);
              return notifier;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        );
      }

      // 1. Test 1440x900
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BatchPromotionScreen), findsOneWidget);
      expect(find.text('Batch Promotion'), findsOneWidget);
      expect(find.text('SOURCE COHORT (FROM)'), findsOneWidget);
      expect(find.text('DESTINATION COHORT (TO)'), findsOneWidget);
      expect(find.text('Load Candidates (Ctrl+L)'), findsOneWidget);

      // 2. Test 1440x780
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BatchPromotionScreen), findsOneWidget);
    });
  });
}
