import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/class_subject_mapping_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/exams/class_subject_mapping_screen.dart';
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

  Widget buildTestScreen({
    ClassSubjectMappingNotifier? notifier,
    GlobalKey? repaintKey,
  }) {
    final router = GoRouter(
      initialLocation: '/exams/subjects',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/exams/subjects',
              builder: (context, state) {
                const screen = ClassSubjectMappingScreen();
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
              path: '/exams/terms',
              builder: (context, state) =>
                  const Scaffold(body: Text('Exam Terms')),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          classSubjectMappingProvider.overrideWith((ref) => notifier),
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

  group('ClassSubjectMappingProvider Unit & Logic Tests', () {
    test('a) loads 13 classes, 5 subjects, 3 teachers on mount', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(classSubjectMappingProvider);
      expect(state.classes.length, 13);
      expect(state.subjects.length, 5);
      expect(state.availableTeachers.length, 3); // TCat == 'Teacher'
      expect(state.allTeachers.length, 5); // 3 teachers + 1 Principal + 1 Clerk
    });

    test('b) auto-selects first class with existing mappings (Class 10 in current data) OR classes.first (Play Group) if none have mappings', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(classSubjectMappingProvider);
      // Seed database has mappings in Class 10 (ClassID = 13)
      expect(state.selectedClassId, 13);
      expect(state.selectedClassName, 'Class 10');

      // Test fallback: wipe Subj_Class and reload
      await db.delete('Subj_Class');
      final containerEmpty = ProviderContainer();
      addTearDown(containerEmpty.dispose);

      final notifierEmpty = containerEmpty.read(
        classSubjectMappingProvider.notifier,
      );
      await notifierEmpty.loadInitialData();

      final stateEmpty = containerEmpty.read(classSubjectMappingProvider);
      expect(stateEmpty.classes.isNotEmpty, isTrue);
      expect(stateEmpty.selectedClassId, 1); // Play Group (classes.first)
      expect(stateEmpty.selectedClassName, 'Play Group');
    });

    test(
      'c) selecting Class 10 loads 5 subjects, footer shows Total Marks: 500',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(classSubjectMappingProvider.notifier);
        await notifier.loadInitialData();

        final state = container.read(classSubjectMappingProvider);
        expect(state.selectedClassId, 13);
        expect(state.mappings.length, 5);
        // Islamiat (100+0) + Maths (100+0) + Urdu (100+0) + English (100+0) + CompSci (75+25) = 500
        expect(state.totalClassMarks, 500);
      },
    );

    test('d) selecting Play Group (0 mappings) shows empty state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      // Switch to Play Group (ClassID 1)
      await notifier.setClassId(1);
      final state = container.read(classSubjectMappingProvider);
      expect(state.selectedClassId, 1);
      expect(state.mappings, isEmpty);
      expect(state.totalClassMarks, 0);
    });

    test('e) adding new mapping inserts with MAX+1 Subj_ClsID', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      // Check current max Subj_ClsID in DB
      final rowsBefore = await db.rawQuery(
        'SELECT MAX(Subj_ClsID) as max_id FROM Subj_Class',
      );
      final currentMax = (rowsBefore.first['max_id'] as num?)?.toInt() ?? 0;
      expect(currentMax, 5); // 5 mappings in seed data

      // Switch to Play Group (ClassID 1) and configure a new subject mapping
      await notifier.setClassId(1);
      notifier.setFormSubjId(1); // Islamiat
      notifier.setFormTeacherId(2); // Rehana Shaheen (Teacher)
      notifier.setFormTheoryMarks('100');
      notifier.setFormPracticalMarks('0');

      final (ok, msg) = await notifier.saveMapping();
      expect(ok, isTrue);
      expect(msg, 'Subject Assigned Successfully');

      // Verify inserted row has Subj_ClsID = currentMax + 1
      final rowsAfter = await db.query(
        'Subj_Class',
        where: 'ClassID = ? AND SubjID = ?',
        whereArgs: [1, 1],
      );
      expect(rowsAfter.length, 1);
      expect(rowsAfter.first['Subj_ClsID'], currentMax + 1);
      expect(rowsAfter.first['Subj_ClsID'], 6);
    });

    test('f) adding duplicate (same SubjID + ClassID) fires {SubjName} already entered for Class {ClassName}', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      // Class 10 (ClassID 13) already has SubjID 1 (Islamiat)
      notifier.setFormSubjId(1);
      notifier.setFormTeacherId(2); // Valid teacher
      notifier.setFormTheoryMarks('100');
      notifier.setFormPracticalMarks('0');

      final (ok, msg) = await notifier.saveMapping();
      expect(ok, isFalse);
      expect(msg, 'Islamiat already entered for Class Class 10');
      expect(
        container.read(classSubjectMappingProvider).errorMessage,
        'Islamiat already entered for Class Class 10',
      );
    });

    test('g) missing Subject fires Select Subject', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      // Ensure formSubjId is null
      notifier.resetForm();
      notifier.setFormSubjId(null);
      notifier.setFormTeacherId(2);
      notifier.setFormTheoryMarks('100');
      notifier.setFormPracticalMarks('0');

      final (ok, msg) = await notifier.saveMapping();
      expect(ok, isFalse);
      expect(msg, 'Select Subject');
      expect(
        container.read(classSubjectMappingProvider).errorMessage,
        'Select Subject',
      );
    });

    test('h) missing Teacher fires Select Subject Teacher', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      // Set subject but no teacher
      notifier.setFormSubjId(1);
      notifier.setFormTeacherId(null);
      notifier.setFormTheoryMarks('100');
      notifier.setFormPracticalMarks('0');

      final (ok, msg) = await notifier.saveMapping();
      expect(ok, isFalse);
      expect(msg, 'Select Subject Teacher');
      expect(
        container.read(classSubjectMappingProvider).errorMessage,
        'Select Subject Teacher',
      );
    });

    test('i) missing Theory marks (cleared field) fires Enter Total Theory Marks for {SubjName}', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      notifier.setFormSubjId(1); // Islamiat
      notifier.setFormTeacherId(2);
      notifier.setFormTheoryMarks(''); // Empty theory marks
      notifier.setFormPracticalMarks('0');

      final (ok, msg) = await notifier.saveMapping();
      expect(ok, isFalse);
      expect(msg, 'Enter Total Theory Marks for Islamiat');
      expect(
        container.read(classSubjectMappingProvider).errorMessage,
        'Enter Total Theory Marks for Islamiat',
      );
    });

    test('j) missing Practical marks (clear field to empty) fires Enter Total Practical Marks for {SubjName}', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      notifier.setFormSubjId(1); // Islamiat
      notifier.setFormTeacherId(2);
      notifier.setFormTheoryMarks('100');
      notifier.setFormPracticalMarks(''); // Empty practical marks

      final (ok, msg) = await notifier.saveMapping();
      expect(ok, isFalse);
      expect(msg, 'Enter Total Practical Marks for Islamiat');
      expect(
        container.read(classSubjectMappingProvider).errorMessage,
        'Enter Total Practical Marks for Islamiat',
      );
    });

    test('k) editing existing mapping pre-fills form, shows update label, warning banner for Principal teacher', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSubjectMappingProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(classSubjectMappingProvider);
      expect(state.mappings.isNotEmpty, isTrue);

      // Select the first mapping (Islamiat in Class 10, taught by Ahzam Shahnil, Principal)
      final firstMapping = state.mappings.first;
      notifier.selectMappingForEdit(firstMapping.subjClsId);

      final editState = container.read(classSubjectMappingProvider);
      expect(editState.isEditMode, isTrue);
      expect(editState.editingMapping?.subjClsId, firstMapping.subjClsId);
      expect(editState.formSubjId, firstMapping.subjId);
      expect(editState.formTeacherId, firstMapping.teacherId);
      expect(editState.formTheoryMarks, '${firstMapping.totalMarks}');
      expect(
        editState.formPracticalMarks,
        '${firstMapping.totalPracticalMarks}',
      );

      // Principal teacher check
      expect(editState.nonTeacherCurrent, isNotNull);
      expect(editState.nonTeacherCurrent!['TName'], 'Ahzam Shahnil');
      expect(editState.nonTeacherCurrent!['TCat'], 'Principal');
    });

    test(
      'l) delete mapping deletes on confirm, toast  Removed Sucessfully',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(classSubjectMappingProvider.notifier);
        await notifier.loadInitialData();

        final state = container.read(classSubjectMappingProvider);
        expect(state.mappings.length, 5);

        // Delete mapping with Subj_ClsID = 1
        final (ok, msg) = await notifier.deleteMapping(1);
        expect(ok, isTrue);
        expect(msg, ' Removed Sucessfully');

        final updatedState = container.read(classSubjectMappingProvider);
        expect(updatedState.mappings.length, 4);
        expect(updatedState.mappings.any((m) => m.subjClsId == 1), isFalse);

        // Verify DB deletion
        final dbRows = await db.query(
          'Subj_Class',
          where: 'Subj_ClsID = ?',
          whereArgs: [1],
        );
        expect(dbRows, isEmpty);
      },
    );
  });

  group('ClassSubjectMappingScreen UI & Widget Tests', () {
    testWidgets(
      'UI loads Class 10 view, shows 5 subjects, Total Marks: 500, and edit banner on selection',
      (tester) async {
        late ClassSubjectMappingNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSubjectMappingNotifier();
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Screen title
        expect(find.text('Class Subject Mapping'), findsOneWidget);

        // Class syllabus table shows 5 rows for Class 10
        expect(
          find.textContaining('ASSIGNED SUBJECTS FOR CLASS 10'),
          findsOneWidget,
        );
        expect(find.text('Islamiat'), findsOneWidget);
        expect(find.text('Maths'), findsOneWidget);
        expect(find.text('Urdu'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Computer Science'), findsOneWidget);

        // Footer total marks
        expect(find.text('Total Marks: 500'), findsOneWidget);

        // Click edit on the first subject row (Islamiat)
        final editButtons = find.byTooltip('Edit Mapping');
        expect(editButtons, findsWidgets);
        await tester.tap(editButtons.first);
        await tester.pumpAndSettle();

        // Edit mode button and warning banner
        expect(find.text('Update Mapping (Ctrl+S)'), findsOneWidget);

        // Warning banner for Principal Ahzam Shahnil
        expect(
          find.textContaining('is registered as Principal, not Teacher'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Switching to Play Group shows empty state', (tester) async {
      late ClassSubjectMappingNotifier notifier;
      await tester.runAsync(() async {
        notifier = ClassSubjectMappingNotifier();
        await notifier.loadInitialData();
        await notifier.setClassId(1); // Play Group
      });

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('ASSIGNED SUBJECTS FOR PLAY GROUP'),
        findsOneWidget,
      );
      expect(
        find.text('No subjects mapped to Play Group. Assign subjects above.'),
        findsOneWidget,
      );
      expect(find.text('Total Marks: 0'), findsOneWidget);
    });

    testWidgets(
      'Delete mapping shows confirmation dialog and cancels or removes',
      (tester) async {
        late ClassSubjectMappingNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSubjectMappingNotifier();
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        final deleteButtons = find.byTooltip('Remove Mapping');
        expect(deleteButtons, findsWidgets);

        // Tap delete on first row
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.text('Remove Subject Mapping'), findsOneWidget);
        expect(find.text(' Are You Sure Want to REMOVE ? '), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);

        // Tap cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Remove Subject Mapping'), findsNothing);
        expect(find.text('Islamiat'), findsOneWidget);
      },
    );

    testWidgets('m) fits 1440x900 AND 1440x780 with zero overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late ClassSubjectMappingNotifier notifier;
      await tester.runAsync(() async {
        notifier = ClassSubjectMappingNotifier();
        await notifier.loadInitialData();
      });

      // 1. 1440x900 Viewport
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ClassSubjectMappingScreen), findsOneWidget);
      expect(find.text('Class Subject Mapping'), findsOneWidget);
      expect(
        find.textContaining('ASSIGNED SUBJECTS FOR CLASS 10'),
        findsOneWidget,
      );

      // 2. 1440x780 Viewport
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ClassSubjectMappingScreen), findsOneWidget);
    });
  });
}
