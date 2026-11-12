import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/exam_term_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/exams/exam_term_screen.dart';
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

  Widget buildTestScreen({ExamTermNotifier? notifier, GlobalKey? repaintKey}) {
    final router = GoRouter(
      initialLocation: '/exams/terms',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/exams/terms',
              builder: (context, state) {
                const screen = ExamTermScreen();
                if (repaintKey != null) {
                  return RepaintBoundary(key: repaintKey, child: screen);
                }
                return screen;
              },
            ),
            GoRoute(
              path: '/exams/marks',
              builder: (context, state) =>
                  const Scaffold(body: Text('Marks Entry')),
            ),
            GoRoute(
              path: '/exams/subjects',
              builder: (context, state) =>
                  const Scaffold(body: Text('Class Subjects Stub')),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null) examTermProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser, const [8, 9, 10, 12, 13, 20]);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('ExamTerm Provider & Business Logic Tests', () {
    test('1. Form_Load loads terms, split teachers, session years, and auto-loads session #1 into EDIT mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(examTermProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(examTermProvider);
      expect(state.terms.length, 3);
      expect(state.terms.map((t) => t.termName), [
        '1st Term',
        '2nd Term',
        'Final Term',
      ]);
      expect(state.terms.first.sessionCount, 1);
      expect(state.terms[1].sessionCount, 0);

      // Teacher splitting: all 5 teachers, but only 3 with TCat == 'Teacher'
      expect(state.allTeachers.length, 5);
      expect(state.availableTeachers.length, 3);
      final availNames = state.availableTeachers
          .map((t) => t['TName'] as String)
          .toList();
      expect(
        availNames,
        containsAll(['Rehana Shaheen', 'Saima Naz', 'Yasmeen Akhtar']),
      );
      expect(availNames.contains('Ahzam Shahnil'), isFalse);

      // Auto-loads session #1
      expect(state.isEditMode, isTrue);
      expect(state.editingSession, isNotNull);
      expect(state.editingSession!.examInfoId, 1);
      expect(state.selectedTermId, 1);
      expect(state.formExTermId, 1);
      expect(state.formSessionYr, '2017-2018');
      expect(state.formLocation, 'Main Hall');
      expect(state.formDetail, '1st Term Examination 2017');
    });

    test('2. Supervisor mismatch detected on session #1 (Ahzam Shahnil is Principal) and kept until user changes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(examTermProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(examTermProvider);
      expect(state.nonTeacherSupervisor, isNotNull);
      expect(state.nonTeacherSupervisor!['TName'], 'Ahzam Shahnil');
      expect(state.nonTeacherSupervisor!['TCat'], 'Principal');

      // Selecting a valid teacher clears nonTeacherSupervisor
      notifier.setFormExamSupervisorId(2); // Rehana Shaheen
      final updatedState = container.read(examTermProvider);
      expect(updatedState.nonTeacherSupervisor, isNull);
      expect(updatedState.formExamSupervisorId, 2);
    });

    test('3. Date chronological gates fire verbatim errors', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(examTermProvider.notifier);
      await notifier.loadInitialData();

      // Gate: End date must be newer then start date
      notifier.setFormStartDate(DateTime(2017, 9, 20));
      notifier.setFormEndDate(DateTime(2017, 9, 10));
      notifier.setFormResultDate(DateTime(2017, 9, 30));
      var (res, _) = await notifier.saveSession();
      expect(res, isFalse);
      expect(
        container.read(examTermProvider).errorMessage,
        'End date must be newer then start date',
      );

      // Gate: Result must be Newer / Equal then End date
      notifier.setFormStartDate(DateTime(2017, 9, 1));
      notifier.setFormEndDate(DateTime(2017, 9, 20));
      notifier.setFormResultDate(DateTime(2017, 9, 15));
      (res, _) = await notifier.saveSession();
      expect(res, isFalse);
      expect(
        container.read(examTermProvider).errorMessage,
        'Result must be Newer / Equal then End date',
      );
    });

    test('4. Missing field gates fire verbatim errors', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(examTermProvider.notifier);
      await notifier.loadInitialData();

      // Missing term
      notifier.setFormExTermId(null);
      var (res, _) = await notifier.saveSession();
      expect(res, isFalse);
      expect(
        container.read(examTermProvider).errorMessage,
        'Select Term Name Please ',
      );

      // Missing session
      notifier.setFormExTermId(1);
      notifier.setFormSessionYr(null);
      (res, _) = await notifier.saveSession();
      expect(res, isFalse);
      expect(
        container.read(examTermProvider).errorMessage,
        'Choose Session Year ',
      );

      // Missing supervisor
      notifier.setFormSessionYr('2017-2018');
      notifier.setFormExamSupervisorId(null);
      (res, _) = await notifier.saveSession();
      expect(res, isFalse);
      expect(
        container.read(examTermProvider).errorMessage,
        'Select Exam Supervisor Please ',
      );
    });

    test(
      '5. Duplicate check in CREATE mode: (ExTermID, SessionYr) must be unique',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(examTermProvider.notifier);
        await notifier.loadInitialData();

        // Switch to CREATE mode
        notifier.newSession();
        expect(container.read(examTermProvider).isEditMode, isFalse);

        // Fill with term 1 and session 2017-2018 (which already exists as session #1)
        notifier.setFormExTermId(1);
        notifier.setFormSessionYr('2017-2018');
        notifier.setFormExamSupervisorId(2);
        notifier.setFormStartDate(DateTime(2017, 9, 1));
        notifier.setFormEndDate(DateTime(2017, 9, 15));
        notifier.setFormResultDate(DateTime(2017, 9, 30));

        final (res, _) = await notifier.saveSession();
        expect(res, isFalse);
        expect(
          container.read(examTermProvider).errorMessage,
          'Already Entered 1st Term in session 2017-2018',
        );
      },
    );

    test('6. Duplicate check in EDIT mode: changing term/sessionYr to existing pair is blocked', () async {
      // First insert another session for 2nd Term in 2017-2018
      await db.rawInsert('''
        INSERT INTO ExamInfo (ExamInfoID, ExTermID, SessionYr, StartDate, EndDate, ResultDate, ExamSupervisorID, Location, Detail)
        VALUES (2, 2, '2017-2018', '2017-12-01', '2017-12-15', '2017-12-30', 2, 'Auditorium', '2nd Term')
      ''');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(examTermProvider.notifier);
      await notifier.loadInitialData();

      // Currently editing session #1 (ExTermID: 1). Try changing ExTermID to 2 (matches session #2)
      notifier.setFormExTermId(2);
      notifier.setFormSessionYr('2017-2018');

      final (res, _) = await notifier.saveSession();
      expect(res, isFalse);
      expect(
        container.read(examTermProvider).errorMessage,
        'Already Entered 2nd Term in session 2017-2018',
      );
    });

    test(
      '7. Session update in EDIT mode updates database and history table',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(examTermProvider.notifier);
        await notifier.loadInitialData();

        // Update location and detail
        notifier.setFormLocation('Sports Complex Hall');
        notifier.setFormDetail('Updated 1st Term 2017');

        final (res, _) = await notifier.saveSession();
        expect(res, isTrue);

        final state = container.read(examTermProvider);
        expect(state.toast, 'New Exam Updated/Added Successfully');
        expect(state.currentSessions.first.location, 'Sports Complex Hall');
        expect(state.currentSessions.first.detail, 'Updated 1st Term 2017');

        // Check SQLite
        final rows = await db.rawQuery(
          'SELECT Location, Detail FROM ExamInfo WHERE ExamInfoID = 1',
        );
        expect(rows.first['Location'], 'Sports Complex Hall');
        expect(rows.first['Detail'], 'Updated 1st Term 2017');
      },
    );

    test('8. Session create in CREATE mode inserts new record with MAX+1 ExamInfoID and increments count', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(examTermProvider.notifier);
      await notifier.loadInitialData();

      // Switch to CREATE mode for 2nd Term
      await notifier.selectTerm(2);
      notifier.newSession();
      notifier.setFormExTermId(2);
      notifier.setFormSessionYr('2017-2018');
      notifier.setFormExamSupervisorId(2);
      notifier.setFormStartDate(DateTime(2017, 12, 1));
      notifier.setFormEndDate(DateTime(2017, 12, 15));
      notifier.setFormResultDate(DateTime(2017, 12, 30));
      notifier.setFormLocation('Hall B');
      notifier.setFormDetail('2nd Term Exams 2017');

      final (res, _) = await notifier.saveSession();
      expect(res, isTrue);

      final state = container.read(examTermProvider);
      expect(state.toast, 'New Exam Updated/Added Successfully');
      expect(state.isEditMode, isTrue);
      expect(state.editingSession!.examInfoId, 2);
      expect(state.currentSessions.length, 1);

      // Term 2 session count updated to 1
      final term2 = state.terms.firstWhere((t) => t.exTermId == 2);
      expect(term2.sessionCount, 1);
    });

    test('9. Session ID lookup: valid ID loads session, invalid ID shows "No Record Exit"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(examTermProvider.notifier);
      await notifier.loadInitialData();

      // Valid ID lookup: 1
      await notifier.lookupSessionById(1);
      var state = container.read(examTermProvider);
      expect(state.editingSession?.examInfoId, 1);
      expect(state.errorMessage, isNull);

      // Invalid ID lookup: 999
      await notifier.lookupSessionById(999);
      state = container.read(examTermProvider);
      expect(state.errorMessage, 'No Record Exit');
    });

    test(
      '10. Term CRUD: add term, update term, and delete term restrictions',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(examTermProvider.notifier);
        await notifier.loadInitialData();

        // Delete term 1 (which has 1 session) -> blocked
        final (delRes, _) = await notifier.deleteTerm(1);
        expect(delRes, isFalse);
        expect(
          container.read(examTermProvider).errorMessage,
          '"1st Term" has 1 scheduled session(s) and cannot be deleted. Remove its sessions first.',
        );

        // Add new term 'Special Term'
        final (addRes, _) = await notifier.addTerm(
          'Special Term',
          'Supplementary',
        );
        expect(addRes, isTrue);
        var state = container.read(examTermProvider);
        expect(state.terms.length, 4);
        final newTerm = state.terms.firstWhere(
          (t) => t.termName == 'Special Term',
        );
        expect(newTerm.termRemarks, 'Supplementary');
        expect(newTerm.sessionCount, 0);

        // Update the new term
        final (editRes, _) = await notifier.updateTerm(
          newTerm.exTermId,
          'Special Term Updated',
          'Revised',
        );
        expect(editRes, isTrue);
        state = container.read(examTermProvider);
        expect(
          state.terms.any((t) => t.termName == 'Special Term Updated'),
          isTrue,
        );

        // Delete the new empty term -> succeeds
        final (delNewRes, _) = await notifier.deleteTerm(newTerm.exTermId);
        expect(delNewRes, isTrue);
        state = container.read(examTermProvider);
        expect(state.terms.length, 3);
        expect(
          state.terms.any((t) => t.termName == 'Special Term Updated'),
          isFalse,
        );
      },
    );
  });

  group('ExamTermScreen UI & Widget Tests', () {
    testWidgets(
      '11. On-mount renders two panes, EDIT mode for session #1, and supervisor warning banner',
      (tester) async {
        late ExamTermNotifier notifier;
        await tester.runAsync(() async {
          notifier = ExamTermNotifier();
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Catalog pane (left)
        expect(find.text('EXAM TERMS CATALOG'), findsOneWidget);
        expect(find.byKey(const ValueKey('term_item_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('term_item_2')), findsOneWidget);
        expect(find.byKey(const ValueKey('term_item_3')), findsOneWidget);

        // Editor pane (right)
        expect(
          find.text('EDITING EXAMINATION SESSION: #1 (1st Term)'),
          findsOneWidget,
        );
        expect(find.text('Update Exam Session (Ctrl+S)'), findsOneWidget);
        expect(find.text('Delete Session'), findsOneWidget);

        // Supervisor warning banner
        expect(
          find.text(
            'Ahzam Shahnil is registered as Principal, not Teacher. The current assignment is kept until you choose a different supervisor.',
          ),
          findsOneWidget,
        );

        // Sessions table shows row #1
        expect(find.text('SESSION HISTORY: 1st Term (1)'), findsOneWidget);
        expect(find.text('Main Hall'), findsWidgets);
        expect(find.text('1st Term Examination 2017'), findsWidgets);
      },
    );

    testWidgets(
      '12. Selecting 2nd Term switches to blank CREATE mode and clears warning banner',
      (tester) async {
        late ExamTermNotifier notifier;
        await tester.runAsync(() async {
          notifier = ExamTermNotifier();
          await notifier.loadInitialData();
          await notifier.selectTerm(2);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Right pane should now be CREATE mode
        expect(find.text('NEW EXAMINATION SESSION (2nd Term)'), findsOneWidget);
        expect(find.text('Save Exam Session (Ctrl+S)'), findsOneWidget);
        // Warning banner should be gone
        expect(
          find.textContaining('is registered as Principal, not Teacher'),
          findsNothing,
        );
        // Empty state in history table
        expect(
          find.text('No sessions have been scheduled for this term yet.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '13. Add Term modal opens, renders input fields, and dismisses cleanly',
      (tester) async {
        late ExamTermNotifier notifier;
        await tester.runAsync(() async {
          notifier = ExamTermNotifier();
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Click Add Term button in top right of left catalog header
        final addBtn = find.widgetWithText(ElevatedButton, 'Add Term');
        expect(addBtn, findsOneWidget);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Modal should open
        expect(find.text('Add Exam Term'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('add_term_name_field')),
          findsOneWidget,
        );
        expect(find.text('Remarks'), findsOneWidget);

        // Enter term name
        await tester.enterText(
          find.byKey(const ValueKey('add_term_name_field')),
          'Mid Term Assessment',
        );
        await tester.pumpAndSettle();

        // Dismiss dialog cleanly
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Add Exam Term'), findsNothing);
      },
    );

    testWidgets('14. Layout fits 1440x900 AND 1440x780 with zero overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late ExamTermNotifier notifier;
      await tester.runAsync(() async {
        notifier = ExamTermNotifier();
        await notifier.loadInitialData();
      });

      // 1. 1440x900 Viewport
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ExamTermScreen), findsOneWidget);
      expect(find.text('Exam Terms and Sessions'), findsOneWidget);
      expect(find.text('EXAM TERMS CATALOG'), findsOneWidget);
      expect(find.text('SESSION HISTORY: 1st Term (1)'), findsOneWidget);

      // 2. 1440x780 Viewport (compact laptop height)
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ExamTermScreen), findsOneWidget);
    });

    testWidgets(
      '15. Delete Session confirmation dialog opens with session #1 details and cancels',
      (tester) async {
        late ExamTermNotifier notifier;
        await tester.runAsync(() async {
          notifier = ExamTermNotifier();
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        final deleteBtn = find.text('Delete Session');
        expect(deleteBtn, findsOneWidget);

        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('Delete session #1? This cannot be undone.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(
          find.text('Delete session #1? This cannot be undone.'),
          findsNothing,
        );
      },
    );
  });
}
