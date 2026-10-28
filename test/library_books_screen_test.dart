import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/library_books_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/library/library_books_screen.dart';
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

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Widget buildTestScreen({
    int userLevel = 1,
    bool hasWeakPasswordWarning = false,
    LibraryBooksNotifier? notifier,
  }) {
    final router = GoRouter(
      initialLocation: '/library',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryBooksScreen(),
            ),
            GoRoute(
              path: '/library/new',
              builder: (context, state) =>
                  const Scaffold(body: Text('New Book Stub')),
            ),
            GoRoute(
              path: '/library/:id',
              builder: (context, state) => Scaffold(
                body: Text('Book Profile Stub: ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ],
    );

    final testUser = User(
      id: 1,
      name: 'Test Operator',
      designation: 'Librarian',
      password: 'password123',
      userLevel: userLevel,
      isActive: true,
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          libraryBooksProvider.overrideWith((ref) => notifier)
        else
          libraryBooksProvider.overrideWith((ref) => LibraryBooksNotifier()),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(
            testUser,
            const [3, 8, 9, 10, 12, 13, 14, 20],
            hasWeakPasswordWarning: hasWeakPasswordWarning,
          );
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('LibraryBooksProvider Unit & Logic Tests', () {
    test('a) On mount: totalBooksAvailable == 5, categoryCount == 5, totalValuation == 1750', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(libraryBooksProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(libraryBooksProvider);
      expect(state.totalBooksAvailable, 5);
      expect(state.categoryCount, 5);
      expect(state.totalValuation, 1750);
    });

    test('b) On mount: rows.length == 5, sorted by BookCatSubj ASC (1,2,3,4,5 order)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(libraryBooksProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(libraryBooksProvider);
      expect(state.rows.length, 5);
      expect(state.rows.map((r) => r.bookCatSubj).toList(), [1, 2, 3, 4, 5]);
    });

    test('c) Search "Wren": after debounce flush, allRows.length == 1, rows[0].bookId == 4', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(libraryBooksProvider.notifier);
      await notifier.loadInitialData();

      notifier.setSearchQuery('Wren');
      await Future.delayed(const Duration(milliseconds: 300));

      final state = container.read(libraryBooksProvider);
      expect(state.allRows.length, 1);
      expect(state.rows.first.bookId, 4);
    });

    test('d) Search "zzz": allRows.length == 0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(libraryBooksProvider.notifier);
      await notifier.loadInitialData();

      notifier.setSearchQuery('zzz');
      await Future.delayed(const Duration(milliseconds: 300));

      final state = container.read(libraryBooksProvider);
      expect(state.allRows.length, 0);
      expect(state.rows.length, 0);
    });

    test('e) Category filter setCategory(5): allRows.length == 1, rows[0].bookName contains "Computer"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(libraryBooksProvider.notifier);
      await notifier.loadInitialData();

      await notifier.setCategory(5);

      final state = container.read(libraryBooksProvider);
      expect(state.allRows.length, 1);
      expect(state.rows.first.bookName.contains('Computer'), isTrue);
    });

    test('f) Category filter on empty result and null category validation', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(libraryBooksProvider.notifier);
      await notifier.loadInitialData();

      // Test applyCategoryFilter with selectedCategoryId == null
      final appliedNull = await notifier.applyCategoryFilter();
      expect(appliedNull, isFalse);
      expect(
        container.read(libraryBooksProvider).errorMessage,
        'Must Select Book Category Please.',
      );

      // Delete book 5 in test DB
      await db.delete('Books', where: 'BookID = ?', whereArgs: [5]);
      await notifier.loadInitialData();

      await notifier.setCategory(5);
      final state = container.read(libraryBooksProvider);
      expect(state.allRows.length, 0);
      expect(
        state.toast,
        ' No Books Available in Computer Science Category',
      );
    });

    test('g) Pagination: setPageSize(2) with 5 books -> totalPages == 3; setPage(3) -> rows.length == 1', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(libraryBooksProvider.notifier);
      await notifier.loadInitialData();

      notifier.setPageSize(2);
      var state = container.read(libraryBooksProvider);
      expect(state.totalPages, 3);
      expect(state.rows.length, 2);

      notifier.setPage(3);
      state = container.read(libraryBooksProvider);
      expect(state.currentPage, 3);
      expect(state.rows.length, 1);
    });

    test('h) resetFilters(): clears search and category, restores full catalog', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(libraryBooksProvider.notifier);
      await notifier.loadInitialData();

      notifier.setSearchQuery('Wren');
      await Future.delayed(const Duration(milliseconds: 300));
      await notifier.setCategory(1);

      await notifier.resetFilters();

      final state = container.read(libraryBooksProvider);
      expect(state.searchQuery, '');
      expect(state.selectedCategoryId, isNull);
      expect(state.allRows.length, 5);
    });
  });

  group('LibraryBooksScreen Widget & Integration Tests', () {
    testWidgets('i) [Add New Book] press when readOnly == true (userLvl == 3): Widget tap on button DOES NOT navigate (route stays /library) AND state.errorMessage == "You don\'t have enough rights for purpose"', (tester) async {
      late LibraryBooksNotifier notifier;
      await tester.runAsync(() async {
        notifier = LibraryBooksNotifier();
        await notifier.loadInitialData();
      });

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestScreen(userLevel: 3, notifier: notifier));
      await tester.pumpAndSettle();

      final addButton = find.widgetWithText(
        ElevatedButton,
        'Add New Book (Ctrl+N)',
      );
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('New Book Stub'), findsNothing);
      expect(find.text('Library Book Catalog'), findsOneWidget);
      expect(
        find.text("You don't have enough rights for purpose"),
        findsOneWidget,
      );
    });

    testWidgets('j) [Add New Book] press when readOnly == false (userLvl == 1): navigates to /library/new', (tester) async {
      late LibraryBooksNotifier notifier;
      await tester.runAsync(() async {
        notifier = LibraryBooksNotifier();
        await notifier.loadInitialData();
      });

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestScreen(userLevel: 1, notifier: notifier));
      await tester.pumpAndSettle();

      final addButton = find.widgetWithText(
        ElevatedButton,
        'Add New Book (Ctrl+N)',
      );
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('New Book Stub'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('k) Row Title InkWell tap: navigates to /library/1', (tester) async {
      late LibraryBooksNotifier notifier;
      await tester.runAsync(() async {
        notifier = LibraryBooksNotifier();
        await notifier.loadInitialData();
      });

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      final titleInkWell = find.text('Islamiat Lazmi Grade 9');
      expect(titleInkWell, findsOneWidget);
      await tester.tap(titleInkWell);
      await tester.pumpAndSettle();

      expect(find.text('Book Profile Stub: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('l) Empty state renders "No books match the current search criteria" when allRows.isEmpty', (tester) async {
      late LibraryBooksNotifier notifier;
      await tester.runAsync(() async {
        notifier = LibraryBooksNotifier();
        await notifier.loadInitialData();
        notifier.setSearchQuery('zzz');
        await Future.delayed(const Duration(milliseconds: 300));
      });

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(
        find.text('No books match the current search criteria'),
        findsOneWidget,
      );
      expect(
        find.text('Adjust filters or clear search to see the full catalog'),
        findsOneWidget,
      );
    });

    testWidgets('m) Fits 1440x900 with tester.takeException() == null', (tester) async {
      late LibraryBooksNotifier notifier;
      await tester.runAsync(() async {
        notifier = LibraryBooksNotifier();
        await notifier.loadInitialData();
      });

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('n) Fits 1440x780 (weak-password banner active) with tester.takeException() == null', (tester) async {
      late LibraryBooksNotifier notifier;
      await tester.runAsync(() async {
        notifier = LibraryBooksNotifier();
        await notifier.loadInitialData();
      });

      await tester.binding.setSurfaceSize(const Size(1440, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestScreen(
        notifier: notifier,
        hasWeakPasswordWarning: true,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
