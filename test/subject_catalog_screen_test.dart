import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/subject_catalog_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/academics/subject_catalog_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  const testMetadata = ShellMetadata(
    branchName: "Ailyan's Higher Secondary School Mianwali",
    branchAddress: 'Muslim Bazar Mianwali',
    branchPhone: '0459-234567',
    branchPrincipal: 'Prof. Muhammad Tariq',
    sessionYear: '2017-2018',
    studentCount: 10,
    classCount: 13,
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

    // Insert 10 fixture rows into ExamDet for SubjID=1
    // (ExamDet is not seeded by seedIfEmpty, live rows were created manually)
    for (var i = 1; i <= 10; i++) {
      await db.insert('ExamDet', {
        'ExamMasID': i,
        'SubjID': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    EditableText.debugDeterministicCursor = true;
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    EditableText.debugDeterministicCursor = false;
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Widget buildTestScreen({
    int userLevel = 1,
    bool hasWeakPasswordWarning = false,
    SubjectCatalogNotifier? notifier,
  }) {
    final router = GoRouter(
      initialLocation: '/academics/subjects',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/academics/subjects',
              builder: (context, state) => const SubjectCatalogScreen(),
            ),
            GoRoute(
              path: '/academics/classes',
              builder: (context, state) =>
                  const Scaffold(body: Text('Classes Stub')),
            ),
            GoRoute(
              path: '/exams/subjects',
              builder: (context, state) =>
                  const Scaffold(body: Text('Exams Subjects Stub')),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) =>
                  const Scaffold(body: Text('Dashboard Stub')),
            ),
          ],
        ),
      ],
    );

    final testUser = User(
      id: 1,
      name: 'Test Administrator',
      designation: 'Registrar',
      password: 'password123',
      userLevel: userLevel,
      isActive: true,
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          subjectCatalogProvider.overrideWith((ref) => notifier)
        else
          subjectCatalogProvider.overrideWith(
            (ref) => SubjectCatalogNotifier(),
          ),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser, const [
            1,
            4,
            12,
            13,
            20,
            25,
          ], hasWeakPasswordWarning: hasWeakPasswordWarning);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('SubjectCatalogProvider Unit & Business Logic Tests', () {
    test('a) loadInitialData: 5 subjects, ordered by SubjID ASC, each AssignedClasses == 1', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(subjectCatalogProvider);
      expect(state.subjects.length, 5);
      expect(state.subjects[0]['SubjID'], 1);
      expect(state.subjects[0]['SubjName'], 'Islamiat');
      expect(state.subjects[0]['AssignedClasses'], 1);

      expect(state.subjects[1]['SubjID'], 2);
      expect(state.subjects[1]['SubjName'], 'Maths');
      expect(state.subjects[1]['AssignedClasses'], 1);

      expect(state.subjects[2]['SubjID'], 3);
      expect(state.subjects[2]['SubjName'], 'Urdu');
      expect(state.subjects[2]['AssignedClasses'], 1);

      expect(state.subjects[3]['SubjID'], 4);
      expect(state.subjects[3]['SubjName'], 'English');
      expect(state.subjects[3]['AssignedClasses'], 1);

      expect(state.subjects[4]['SubjID'], 5);
      expect(state.subjects[4]['SubjName'], 'Computer Science');
      expect(state.subjects[4]['AssignedClasses'], 1);
    });

    test('b) subjectCount == 5, totalMappedClasses == 5', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(subjectCatalogProvider);
      expect(state.subjectCount, 5);
      expect(state.totalMappedClasses, 5);
    });

    test('c) enterAddNewMode: isAddingNew == true, editingSubjectId == null, nextSubjId == 6, blank fields', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();
      await notifier.enterAddNewMode();

      final state = container.read(subjectCatalogProvider);
      expect(state.isAddingNew, isTrue);
      expect(state.editingSubjectId, isNull);
      expect(state.nextSubjId, 6);
      expect(state.editingSubjName, isEmpty);
      expect(state.editingSubjDetail, isEmpty);
      expect(state.isDrawerOpen, isTrue);
    });

    test('d) enterEditMode(1): isAddingNew == false, editingSubjectId == 1, editingSubjName == \'Islamiat\', editingSubjDetail == \'Compulsory religious studies\'', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();
      notifier.enterEditMode(1);

      final state = container.read(subjectCatalogProvider);
      expect(state.isAddingNew, isFalse);
      expect(state.editingSubjectId, 1);
      expect(state.editingSubjName, 'Islamiat');
      expect(state.editingSubjDetail, 'Compulsory religious studies');
      expect(state.isDrawerOpen, isTrue);
    });

    test('e) saveSubject empty name fires \'Subject Name is required\', no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();
      await notifier.enterAddNewMode();

      notifier.setEditingSubjName('   ');
      final ok = await notifier.saveSubject();

      expect(ok, isFalse);
      final state = container.read(subjectCatalogProvider);
      expect(state.errorMessage, 'Subject Name is required');

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Subject');
      expect((countRes.first['cnt'] as num).toInt(), 5);
    });

    test('f) saveSubject userLvl == 3 fires "You don\'t have enough rights for purpose", no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();
      await notifier.enterAddNewMode();

      notifier.setEditingSubjName('Biology');
      final ok = await notifier.saveSubject(currentUserLvl: 3);

      expect(ok, isFalse);
      final state = container.read(subjectCatalogProvider);
      expect(state.errorMessage, "You don't have enough rights for purpose");

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Subject');
      expect((countRes.first['cnt'] as num).toInt(), 5);
    });

    test('g) saveSubject duplicate \'Islamiat\' (adding new) fires \'Subject with this name already exists\', no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();
      await notifier.enterAddNewMode();

      notifier.setEditingSubjName('Islamiat');
      final ok = await notifier.saveSubject();

      expect(ok, isFalse);
      final state = container.read(subjectCatalogProvider);
      expect(state.errorMessage, 'Subject with this name already exists');

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Subject');
      expect((countRes.first['cnt'] as num).toInt(), 5);
    });

    test('h) saveSubject duplicate \'islamiat\' lowercase (adding new) fires same error (case-insensitive)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();
      await notifier.enterAddNewMode();

      notifier.setEditingSubjName('islamiat');
      final ok = await notifier.saveSubject();

      expect(ok, isFalse);
      final state = container.read(subjectCatalogProvider);
      expect(state.errorMessage, 'Subject with this name already exists');

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Subject');
      expect((countRes.first['cnt'] as num).toInt(), 5);
    });

    test('i) saveSubject new \'Physics\': SubjID == 6, INSERT, count 5 -> 6, drawer closes, toast \'Subject Saved Successfully\'. THEN verify deleteSubject(6) (0 refs) succeeds: count 6 -> 5, toast \'Subject removed\', Physics removed from DB.', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();
      await notifier.enterAddNewMode();

      notifier.setEditingSubjName('Physics');
      notifier.setEditingSubjDetail('Classical mechanics and thermodynamics');
      final ok = await notifier.saveSubject();

      expect(ok, isTrue);
      var state = container.read(subjectCatalogProvider);
      expect(state.subjectCount, 6);
      expect(state.isDrawerOpen, isFalse);
      expect(state.toast, 'Subject Saved Successfully');

      // Verify Physics in DB with SubjID 6
      final physRow = await db.rawQuery(
        'SELECT * FROM Subject WHERE SubjID = 6',
      );
      expect(physRow.length, 1);
      expect(physRow.first['SubjName'], 'Physics');

      // Now delete SubjID 6 (0 refs in all 3 tables)
      final delOk = await notifier.deleteSubject(6);
      expect(delOk, isTrue);

      state = container.read(subjectCatalogProvider);
      expect(state.subjectCount, 5);
      expect(state.toast, 'Subject removed');

      final checkDel = await db.rawQuery(
        'SELECT * FROM Subject WHERE SubjID = 6',
      );
      expect(checkDel.isEmpty, isTrue);
    });

    test('j) saveSubject existing (edit SubjID 2 name to \'Mathematics\'): UPDATE, count stays 5, toast', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();
      notifier.enterEditMode(2);

      notifier.setEditingSubjName('Mathematics');
      final ok = await notifier.saveSubject();

      expect(ok, isTrue);
      final state = container.read(subjectCatalogProvider);
      expect(state.subjectCount, 5);
      expect(state.toast, 'Subject Saved Successfully');

      final updated = await db.rawQuery(
        'SELECT SubjName FROM Subject WHERE SubjID = 2',
      );
      expect(updated.first['SubjName'], 'Mathematics');
    });

    test('k) deleteSubject(1) with 10 ExamDet fixture rows for SubjID=1: blocked, errorMessage == \'Cannot delete subject: Currently mapped to classes, exams, or library books (1 classes, 10 exam records, 1 library books)\', no DB delete, 5 subjects still present', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();

      final ok = await notifier.deleteSubject(1);
      expect(ok, isFalse);

      final state = container.read(subjectCatalogProvider);
      expect(
        state.errorMessage,
        'Cannot delete subject: Currently mapped to classes, exams, or library books (1 classes, 10 exam records, 1 library books)',
      );

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Subject');
      expect((countRes.first['cnt'] as num).toInt(), 5);
    });

    test('l) deleteSubject(5) (CS: 1 Subj_Class + 1 Books, 0 ExamDet): blocked, errorMessage == \'Cannot delete subject: Currently mapped to classes, exams, or library books (1 classes, 1 library books)\', no DB delete', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();

      final ok = await notifier.deleteSubject(5);
      expect(ok, isFalse);

      final state = container.read(subjectCatalogProvider);
      expect(
        state.errorMessage,
        'Cannot delete subject: Currently mapped to classes, exams, or library books (1 classes, 1 library books)',
      );

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Subject');
      expect((countRes.first['cnt'] as num).toInt(), 5);
    });

    test('m) deleteSubject userLvl == 3 fires "You don\'t have enough rights for purpose", no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(subjectCatalogProvider.notifier);
      await notifier.loadInitialData();

      final ok = await notifier.deleteSubject(1, currentUserLvl: 3);
      expect(ok, isFalse);

      final state = container.read(subjectCatalogProvider);
      expect(state.errorMessage, "You don't have enough rights for purpose");

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Subject');
      expect((countRes.first['cnt'] as num).toInt(), 5);
    });
  });

  group('SubjectCatalogScreen Widget & Layout Tests', () {
    testWidgets(
      'n) Fits 1440x900 AND 1440x780 (with drawer CLOSED and with drawer OPEN) with tester.takeException() == null',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        late SubjectCatalogNotifier notifier;
        await tester.runAsync(() async {
          notifier = SubjectCatalogNotifier();
          await notifier.loadInitialData();
        });

        // 1. Viewport 1440x900, drawer closed
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        await tester.pumpWidget(
          buildTestScreen(notifier: notifier, hasWeakPasswordWarning: true),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SubjectCatalogScreen), findsOneWidget);
        expect(find.text('Academic Subject Catalog'), findsOneWidget);
        expect(find.text('5 Subjects Configured'), findsOneWidget);
        expect(find.text('5 Classes Assigned'), findsOneWidget);
        expect(find.text('Islamiat'), findsOneWidget);
        expect(find.text('Maths'), findsOneWidget);
        expect(find.text('Computer Science'), findsOneWidget);

        // 2. Open drawer via Add New button
        final addBtn = find.text('Add New Subject (Ctrl+N)');
        expect(addBtn, findsOneWidget);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Add New Subject'), findsOneWidget);
        expect(find.text('Auto (next: #6)'), findsOneWidget);
        // Master grid should still have its Actions buttons visible and clickable
        expect(find.byTooltip('Edit subject'), findsWidgets);

        // 3. Viewport 1440x780, drawer OPEN
        await tester.binding.setSurfaceSize(const Size(1440, 780));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Add New Subject'), findsOneWidget);

        // 4. Close drawer at 1440x780
        final cancelBtn = find.text('Cancel (Esc)');
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Add New Subject'), findsNothing);
      },
    );
  });
}
