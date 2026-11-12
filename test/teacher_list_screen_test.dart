import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/teacher_list_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/staff/teacher_list_screen.dart';
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

    // Ensure inactive 6th teacher exists in in-memory test DB
    await db.insert('Teachers', {
      'TeacherID': 6,
      'TName': 'Test Relieved Staff',
      'TFName': 'Test Father',
      'TCNIC': '38302-6666666-6',
      'TContactNo1': '03336666666',
      'TSubject': 'Geography',
      'DOJoing': '2018-01-01',
      'TIsPresent': 'N',
      'TCat': 'Staff',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Widget buildTestScreen({
    TeacherListNotifier? notifier,
    GlobalKey? repaintKey,
  }) {
    final router = GoRouter(
      initialLocation: '/staff/teachers',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/staff/teachers',
              builder: (context, state) {
                const screen = TeacherListScreen();
                if (repaintKey != null) {
                  return RepaintBoundary(key: repaintKey, child: screen);
                }
                return screen;
              },
            ),
            GoRoute(
              path: '/staff/teachers/new',
              builder: (context, state) =>
                  const Scaffold(body: Text('New Teacher Stub')),
            ),
            GoRoute(
              path: '/staff/teachers/:id',
              builder: (context, state) => Scaffold(
                body: Text(
                  'Teacher Profile Stub: ${state.pathParameters['id']}',
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          teacherListProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser, const [8, 9, 10, 12, 13, 14, 20]);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('TeacherListProvider Unit & Logic Tests', () {
    test('a) loads 6 teachers on mount (5 active + 1 relieved)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(teacherListProvider);
      expect(state.allTeachers.length, 6);
      expect(state.totalStaffCount, 6);
      expect(state.teacherCount, 3);
      expect(state.staffAdminCount, 2);
      expect(state.activeStaffCount, 5);
    });

    test('b) auto-shows only active by default (5 rows, Test Relieved Staff hidden)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(teacherListProvider);
      expect(state.onlyActive, isTrue);
      expect(state.filteredTeachers.length, 5);
      expect(
        state.filteredTeachers.any((t) => t.tName == 'Test Relieved Staff'),
        isFalse,
      );
    });

    test('c) unchecking Only Active shows all 6 including relieved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      await notifier.setOnlyActive(false);
      final state = container.read(teacherListProvider);
      expect(state.onlyActive, isFalse);
      expect(state.filteredTeachers.length, 6);
      expect(
        state.filteredTeachers.any((t) => t.tName == 'Test Relieved Staff'),
        isTrue,
      );
    });

    test('d) category filter Teacher shows only 3 teachers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      await notifier.setCategoryFilter('Teacher');
      final state = container.read(teacherListProvider);
      expect(state.filteredTeachers.length, 3);
      expect(state.filteredTeachers.every((t) => t.tCat == 'Teacher'), isTrue);
    });

    test('e) category filter Staff shows 2 (Akram Ali + Test Relieved Staff when active unchecked; only Akram Ali when active checked)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      // 1. When only active is checked (default)
      await notifier.setCategoryFilter('Staff');
      var state = container.read(teacherListProvider);
      expect(state.filteredTeachers.length, 1);
      expect(state.filteredTeachers.first.tName, 'Akram Ali');

      // 2. When only active is unchecked
      await notifier.setOnlyActive(false);
      state = container.read(teacherListProvider);
      expect(state.filteredTeachers.length, 2);
      expect(
        state.filteredTeachers.map((t) => t.tName).toList(),
        containsAll(['Akram Ali', 'Test Relieved Staff']),
      );
    });

    test('f) search Rehana shows 1 result', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      await notifier.setSearchQuery('Rehana');
      final state = container.read(teacherListProvider);
      expect(state.filteredTeachers.length, 1);
      expect(state.filteredTeachers.first.tName, 'Rehana Shaheen');
    });

    test('g) search 38302-2222222-2 (CNIC) shows Rehana', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      await notifier.setSearchQuery('38302-2222222-2');
      final state = container.read(teacherListProvider);
      expect(state.filteredTeachers.length, 1);
      expect(state.filteredTeachers.first.tName, 'Rehana Shaheen');
    });

    test('h) search Mathematics (subject) shows Saima Naz', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      await notifier.setSearchQuery('Mathematics');
      final state = container.read(teacherListProvider);
      expect(state.filteredTeachers.length, 1);
      expect(state.filteredTeachers.first.tName, 'Saima Naz');
    });

    test('i) search xyz123 shows empty state with Record Not Found', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      await notifier.setSearchQuery('xyz123');
      final state = container.read(teacherListProvider);
      expect(state.filteredTeachers, isEmpty);
    });

    test('j) reset filters restores 5 default rows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherListProvider.notifier);
      await notifier.loadInitialData();

      // Modify filters
      await notifier.setSearchQuery('Rehana');
      await notifier.setCategoryFilter('Teacher');
      await notifier.setOnlyActive(false);

      // Reset
      await notifier.resetFilters();
      final state = container.read(teacherListProvider);
      expect(state.searchQuery, isEmpty);
      expect(state.categoryFilter, 'All');
      expect(state.onlyActive, isTrue);
      expect(state.filteredTeachers.length, 5);
    });
  });

  group('TeacherListScreen UI & Widget Tests', () {
    testWidgets(
      'UI renders 4 metric badges and initial 5 active staff members',
      (tester) async {
        late TeacherListNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherListNotifier();
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Screen title
        expect(find.text('Faculty & Staff Directory'), findsOneWidget);

        // 4 Metric Badges
        expect(find.text('6 Total Staff'), findsOneWidget);
        expect(find.text('3 Teachers'), findsOneWidget);
        expect(find.text('2 Staff/Admin'), findsOneWidget);
        expect(find.text('5 Active'), findsOneWidget);

        // Initial 5 active staff members in the table
        expect(find.text('Ahzam Shahnil'), findsOneWidget);
        expect(find.text('Rehana Shaheen'), findsOneWidget);
        expect(find.text('Saima Naz'), findsOneWidget);
        expect(find.text('Yasmeen Akhtar'), findsOneWidget);
        expect(find.text('Akram Ali'), findsOneWidget);
        expect(find.text('Test Relieved Staff'), findsNothing);

        // Action toolbar buttons
        expect(find.text('Add New Teacher (Ctrl+N)'), findsOneWidget);
        expect(find.text('Export CSV'), findsOneWidget);
        expect(find.text('Print Faculty Roster'), findsOneWidget);
      },
    );

    testWidgets(
      'Empty search shows Record Not Found and Reset Filters button',
      (tester) async {
        late TeacherListNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherListNotifier();
          await notifier.loadInitialData();
          await notifier.setSearchQuery('xyz123');
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        expect(find.text('Record Not Found'), findsOneWidget);
        expect(
          find.text('No staff members found matching your search criteria.'),
          findsOneWidget,
        );

        // Reset filters button exists in empty state
        expect(
          find.widgetWithText(OutlinedButton, 'Reset Filters'),
          findsWidgets,
        );
      },
    );

    testWidgets('k) row click navigates to /staff/teachers/:id stub', (
      tester,
    ) async {
      late TeacherListNotifier notifier;
      await tester.runAsync(() async {
        notifier = TeacherListNotifier();
        await notifier.loadInitialData();
      });

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      // Click on Rehana Shaheen
      await tester.tap(find.text('Rehana Shaheen'));
      await tester.pumpAndSettle();

      expect(find.text('Teacher Profile Stub: 2'), findsOneWidget);
    });

    testWidgets('l) fits 1440x900 AND 1440x780 without overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late TeacherListNotifier notifier;
      await tester.runAsync(() async {
        notifier = TeacherListNotifier();
        await notifier.loadInitialData();
      });

      // 1. 1440x900 Viewport
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TeacherListScreen), findsOneWidget);
      expect(find.text('Faculty & Staff Directory'), findsOneWidget);

      // 2. 1440x780 Viewport
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TeacherListScreen), findsOneWidget);
    });
  });
}
