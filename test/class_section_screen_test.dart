import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/class_section_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/academics/class_section_screen.dart';
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

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Widget buildTestScreen({
    int userLevel = 1,
    bool hasWeakPasswordWarning = false,
    ClassSectionNotifier? notifier,
  }) {
    final router = GoRouter(
      initialLocation: '/academics/classes',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/academics/classes',
              builder: (context, state) => const ClassSectionScreen(),
            ),
            GoRoute(
              path: '/academics/subjects',
              builder: (context, state) =>
                  const Scaffold(body: Text('Subject Catalog Stub')),
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
          classSectionProvider.overrideWith((ref) => notifier)
        else
          classSectionProvider.overrideWith((ref) => ClassSectionNotifier()),
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

  group('ClassSectionProvider Unit & Business Logic Tests', () {
    test('a) loadInitialData: 13 classes loaded, first class (Play Group, ClassID 1) auto-selected, teacherOptions contains only TCat=\'Teacher\' rows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(classSectionProvider);
      expect(state.classes.length, 13);
      expect(state.selectedClassId, 1);
      expect(state.selectedClassName, 'Play Group');
      expect(state.sections.length, 2); // Sections A and B

      // Verify teacher options has only TCat = 'Teacher'
      expect(state.teacherOptions, isNotEmpty);
      final nonTeachers = await db.rawQuery(
        "SELECT TeacherID FROM Teachers WHERE TCat != 'Teacher'",
      );
      final nonTeacherIds = nonTeachers
          .map((r) => (r['TeacherID'] as num).toInt())
          .toSet();
      for (final t in state.teacherOptions) {
        expect(
          nonTeacherIds.contains((t['TeacherID'] as num).toInt()),
          isFalse,
        );
      }
    });

    test('b) selectClass(2): sections for Nursery load (A and B), EnrolledCount==0 for both', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      await notifier.selectClass(2);
      final state = container.read(classSectionProvider);

      expect(state.selectedClassId, 2);
      expect(state.selectedClassName, 'Nursery');
      expect(state.sections.length, 2);
      for (final s in state.sections) {
        expect((s['EnrolledCount'] as num).toInt(), 0);
      }
    });

    test('c) selectClass(13): Class 10 loads. ClassSecID 25 (section A) shows EnrolledCount=10, ClassSecID 26 (section B) shows EnrolledCount=0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      await notifier.selectClass(13);
      final state = container.read(classSectionProvider);

      expect(state.selectedClassId, 13);
      expect(state.selectedClassName, 'Class 10');
      expect(state.sections.length, 2);

      final secA = state.sections.firstWhere((s) => s['ClassSecID'] == 25);
      final secB = state.sections.firstWhere((s) => s['ClassSecID'] == 26);
      expect((secA['EnrolledCount'] as num).toInt(), 10);
      expect((secB['EnrolledCount'] as num).toInt(), 0);
    });

    test('d) saveClass with empty name fires \'Enter Class Name Please \' (trailing space preserved), no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      final ok = await notifier.saveClass(className: '   ', currentUserLvl: 1);
      expect(ok, isFalse);

      final state = container.read(classSectionProvider);
      expect(state.errorMessage, 'Enter Class Name Please ');

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Class');
      expect((countRes.first['cnt'] as num).toInt(), 13);
    });

    test('e) saveClass with userLvl=3 fires "You don\'t have enough rights for purpose", no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      final ok = await notifier.saveClass(
        className: 'Class 11',
        currentUserLvl: 3,
      );
      expect(ok, isFalse);

      final state = container.read(classSectionProvider);
      expect(state.errorMessage, "You don't have enough rights for purpose");

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Class');
      expect((countRes.first['cnt'] as num).toInt(), 13);
    });

    test('f) saveClass in new mode: MAX(ClassID)=13 -> nextId=14, inserts row, class count 13->14, toast \'Class Updated/Added Successfully\'', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      notifier.enterNewClassMode();
      final ok = await notifier.saveClass(
        className: 'Grade 11',
        currentUserLvl: 1,
      );
      expect(ok, isTrue);

      final state = container.read(classSectionProvider);
      expect(state.toast, 'Class Updated/Added Successfully');
      expect(state.selectedClassId, 14);
      expect(state.classes.length, 14);

      final row = await db.rawQuery('SELECT * FROM Class WHERE ClassID = 14');
      expect(row.length, 1);
      expect(row.first['CName'], 'Grade 11');
    });

    test('g) saveClass existing: UPDATE CName on selected class, no new rows, count stays 13', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      await notifier.selectClass(1);
      notifier.enterEditClassMode();
      final ok = await notifier.saveClass(
        className: 'Play Group Senior',
        currentUserLvl: 1,
      );
      expect(ok, isTrue);

      final state = container.read(classSectionProvider);
      expect(state.toast, 'Class Updated/Added Successfully');
      expect(state.selectedClassName, 'Play Group Senior');

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Class');
      expect((countRes.first['cnt'] as num).toInt(), 13);

      final row = await db.rawQuery(
        'SELECT CName FROM Class WHERE ClassID = 1',
      );
      expect(row.first['CName'], 'Play Group Senior');
    });

    test('h) saveSection with selectedClassId==null fires \'Choose Class to add Section please\', no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      // Don't select a class
      notifier.enterNewClassMode(); // Clears selectedClassId

      notifier.setEditingSecName('C');
      final ok = await notifier.saveSection(currentUserLvl: 1);
      expect(ok, isFalse);

      final state = container.read(classSectionProvider);
      expect(state.errorMessage, 'Choose Class to add Section please');
    });

    test('i) saveSection with empty editingSecName fires \'Enter Section Name Please\', no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      notifier.enterNewSectionMode();
      notifier.setEditingSecName('   ');
      final ok = await notifier.saveSection(currentUserLvl: 1);
      expect(ok, isFalse);

      final state = container.read(classSectionProvider);
      expect(state.errorMessage, 'Enter Section Name Please');
    });

    test('j) saveSection duplicate (add section \'A\' to Class 1 where \'A\' already exists): fires \'Section with this name already exists in this Class\', case-insensitive \'a\' blocked', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectClass(1);

      // 1. Try exact 'A'
      notifier.enterNewSectionMode();
      notifier.setEditingSecName('A');
      var ok = await notifier.saveSection(currentUserLvl: 1);
      expect(ok, isFalse);
      expect(
        container.read(classSectionProvider).errorMessage,
        'Section with this name already exists in this Class',
      );

      // 2. Try lowercase 'a'
      notifier.setEditingSecName('a');
      ok = await notifier.saveSection(currentUserLvl: 1);
      expect(ok, isFalse);
      expect(
        container.read(classSectionProvider).errorMessage,
        'Section with this name already exists in this Class',
      );
    });

    test('k) saveSection with userLvl=3 fires "You don\'t have enough rights for purpose", no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectClass(1);

      notifier.enterNewSectionMode();
      notifier.setEditingSecName('C');
      final ok = await notifier.saveSection(currentUserLvl: 3);
      expect(ok, isFalse);

      final state = container.read(classSectionProvider);
      expect(state.errorMessage, "You don't have enough rights for purpose");

      final countRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ClassSec',
      );
      expect((countRes.first['cnt'] as num).toInt(), 26);
    });

    test('l) saveSection new: MAX(ClassSecID)=26 -> nextId=27, inserts row, LEFT panel Play Group badge goes from \'2 Sec\' to \'3 Sec\' immediately, toast \'Section Saved Successfully\'', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectClass(1);

      notifier.enterNewSectionMode();
      notifier.setEditingSecName('C');
      notifier.setEditingRoomNo('301');
      notifier.setEditingSecRemarks('New wing');

      final ok = await notifier.saveSection(currentUserLvl: 1);
      expect(ok, isTrue);

      final state = container.read(classSectionProvider);
      expect(state.toast, 'Section Saved Successfully');
      expect(state.sections.length, 3);

      // Verify LEFT panel Play Group SectionCount updated to 3
      final pgClass = state.classes.firstWhere((c) => c['ClassID'] == 1);
      expect((pgClass['SectionCount'] as num).toInt(), 3);

      final row = await db.rawQuery(
        'SELECT * FROM ClassSec WHERE ClassSecID = 27',
      );
      expect(row.length, 1);
      expect(row.first['SecName'], 'C');
      expect(row.first['RoomNo'], '301');
      expect(row.first['Remarks'], 'New wing');
    });

    test('m) saveSection existing: UPDATE SecName/SecTeacher/SecProctor/RoomNo/Remarks, no new rows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectClass(1);

      notifier.enterEditSectionMode(1);
      notifier.setEditingRoomNo('101A');
      notifier.setEditingSecRemarks('Updated remarks');

      final ok = await notifier.saveSection(currentUserLvl: 1);
      expect(ok, isTrue);

      final countRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ClassSec',
      );
      expect((countRes.first['cnt'] as num).toInt(), 26);

      final row = await db.rawQuery(
        'SELECT RoomNo, Remarks FROM ClassSec WHERE ClassSecID = 1',
      );
      expect(row.first['RoomNo'], '101A');
      expect(row.first['Remarks'], 'Updated remarks');
    });

    test('n) deleteSection on ClassSecID 1 (Play Group A, 0 students): deletes, count 26->25, LEFT panel Play Group badge goes from \'2 Sec\' to \'1 Sec\', toast \'Section Removed Successfully\'', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectClass(1);

      final ok = await notifier.deleteSection(1, currentUserLvl: 1);
      expect(ok, isTrue);

      final state = container.read(classSectionProvider);
      expect(state.toast, 'Section Removed Successfully');
      expect(state.sections.length, 1);

      final pgClass = state.classes.firstWhere((c) => c['ClassID'] == 1);
      expect((pgClass['SectionCount'] as num).toInt(), 1);

      final countRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ClassSec',
      );
      expect((countRes.first['cnt'] as num).toInt(), 25);
    });

    test('o) deleteSection on ClassSecID 25 (10 students from seedIfEmpty): blocked, error \'Cannot delete section: 10 students currently enrolled\', no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectClass(13);

      final ok = await notifier.deleteSection(25, currentUserLvl: 1);
      expect(ok, isFalse);

      final state = container.read(classSectionProvider);
      expect(
        state.errorMessage,
        'Cannot delete section: 10 students currently enrolled',
      );

      final countRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ClassSec',
      );
      expect((countRes.first['cnt'] as num).toInt(), 26);
    });

    test('p) deleteSection with userLvl=3 fires "You don\'t have enough rights for purpose", no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectClass(1);

      final ok = await notifier.deleteSection(1, currentUserLvl: 3);
      expect(ok, isFalse);

      final state = container.read(classSectionProvider);
      expect(state.errorMessage, "You don't have enough rights for purpose");

      final countRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ClassSec',
      );
      expect((countRes.first['cnt'] as num).toInt(), 26);
    });

    test('s) saveClass duplicate name (add \'Play Group\' again): fires \'Class with this name already exists\', no DB write, case-insensitive', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(classSectionProvider.notifier);
      await notifier.loadInitialData();

      // 1. Exact match
      notifier.enterNewClassMode();
      var ok = await notifier.saveClass(
        className: 'Play Group',
        currentUserLvl: 1,
      );
      expect(ok, isFalse);
      expect(
        container.read(classSectionProvider).errorMessage,
        'Class with this name already exists',
      );

      // 2. Case-insensitive
      ok = await notifier.saveClass(className: 'play group', currentUserLvl: 1);
      expect(ok, isFalse);
      expect(
        container.read(classSectionProvider).errorMessage,
        'Class with this name already exists',
      );

      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM Class');
      expect((countRes.first['cnt'] as num).toInt(), 13);
    });
  });

  group('ClassSectionScreen Widget & UI Tests', () {
    testWidgets(
      'q) Fits 1440x900 AND 1440x780 (weak-password banner active) with tester.takeException() == null',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        late ClassSectionNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSectionNotifier();
          await notifier.loadInitialData();
        });

        // Viewport 1: 1440x900
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        await tester.pumpWidget(
          buildTestScreen(notifier: notifier, hasWeakPasswordWarning: true),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ClassSectionScreen), findsOneWidget);
        expect(find.text('Classes & Sections'), findsOneWidget);
        expect(find.text('Play Group'), findsWidgets);

        // Viewport 2: 1440x780
        await tester.binding.setSurfaceSize(const Size(1440, 780));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ClassSectionScreen), findsOneWidget);
      },
    );

    testWidgets(
      'r) Nullable dropdowns: SecTeacher/SecProctor null render \'Not assigned\' cleanly in both table and modal without crash',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        late ClassSectionNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSectionNotifier();
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Play Group sections A and B have null SecTeacher and SecProctor
        // Should show 'Not assigned' in table
        expect(find.text('Not assigned'), findsWidgets);

        // Open modal for section A
        final editButtons = find.byTooltip('Edit section');
        expect(editButtons, findsWidgets);
        await tester.tap(editButtons.first);
        await tester.pumpAndSettle();

        // Modal should render dropdowns displaying 'Not assigned' without throwing
        expect(tester.takeException(), isNull);
        expect(find.text('Edit Section'), findsOneWidget);

        // Close modal
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
  });
}
