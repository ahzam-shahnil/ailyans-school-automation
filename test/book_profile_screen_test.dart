import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/book_profile_provider.dart';
import 'package:school_automation/core/providers/library_books_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/library/book_profile_screen.dart';
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
    String bookIdParam = '1',
    int userLevel = 1,
    bool hasWeakPasswordWarning = false,
    BookProfileNotifier? notifier,
  }) {
    final router = GoRouter(
      initialLocation: '/library/$bookIdParam',
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
                  const BookProfileScreen(bookIdParam: 'new'),
            ),
            GoRoute(
              path: '/library/:id',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? 'new';
                return BookProfileScreen(bookIdParam: id);
              },
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
          bookProfileProvider(bookIdParam).overrideWith((ref) => notifier)
        else
          bookProfileProvider(bookIdParam)
              .overrideWith((ref) => BookProfileNotifier(bookIdParam, ref)),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser, const [
            3,
            8,
            9,
            10,
            12,
            13,
            14,
            20,
          ], hasWeakPasswordWarning: hasWeakPasswordWarning);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('BookProfileProvider Unit & Logic Tests', () {
    test('a) /library/new: state.isNew == true, bookId == null, isEditMode == true, blank form fields', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('new').notifier);
      await notifier.loadInitialData();

      final state = container.read(bookProfileProvider('new'));
      expect(state.isNew, isTrue);
      expect(state.bookId, isNull);
      expect(state.isEditMode, isTrue);
      expect(state.bookName, '');
      expect(state.bAuthor, '');
      expect(state.bookCatSubj, isNull);
      expect(state.pages, isNull);
      expect(state.pulishedBy, '');
      expect(state.publishedYr, isNull);
      expect(state.bookPrice, isNull);
      expect(state.detail, '');
    });

    test('b) /library/1: state.isNew == false, bookId == 1, isEditMode == false, fields populated with "Islamiat Lazmi Grade 9", bookPrice == 250', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('1').notifier);
      await notifier.loadInitialData();

      final state = container.read(bookProfileProvider('1'));
      expect(state.isNew, isFalse);
      expect(state.bookId, 1);
      expect(state.isEditMode, isFalse);
      expect(state.bookName, 'Islamiat Lazmi Grade 9');
      expect(state.bAuthor, 'Maulana Muhammad Yousuf');
      expect(state.bookCatSubj, 1);
      expect(state.pages, 220);
      expect(state.pulishedBy, 'Punjab Textbook Board');
      expect(state.publishedYr, 2017);
      expect(state.bookPrice, 250);
    });

    test(
      'c) /library/999 (nonexistent): state.errorMessage == "Book not found"',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(bookProfileProvider('999').notifier);
        await notifier.loadInitialData();

        final state = container.read(bookProfileProvider('999'));
        expect(state.errorMessage, 'Book not found');
        expect(state.bookId, isNull);
      },
    );

    test('d) save() with bookCatSubj == null fires "Must Select Book Category Please.", no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('new').notifier);
      await notifier.loadInitialData();
      notifier.updateField('bookName', 'Test Book Without Category');

      final success = await notifier.save(userLvl: 1);
      expect(success, isFalse);

      final state = container.read(bookProfileProvider('new'));
      expect(state.errorMessage, 'Must Select Book Category Please.');

      final countRes = await db.rawQuery('SELECT COUNT(*) AS cnt FROM Books');
      expect(countRes.first['cnt'], 5);
    });

    test('e) save() with bookName.trim().isEmpty fires "Enter Book Name Please " (trailing space preserved), no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('new').notifier);
      await notifier.loadInitialData();
      notifier.setCategory(1);
      notifier.updateField('bookName', '   ');

      final success = await notifier.save(userLvl: 1);
      expect(success, isFalse);

      final state = container.read(bookProfileProvider('new'));
      expect(state.errorMessage, 'Enter Book Name Please ');

      final countRes = await db.rawQuery('SELECT COUNT(*) AS cnt FROM Books');
      expect(countRes.first['cnt'], 5);
    });

    test('f) save() with userLvl == 3 fires "You don\'t have enough rights for purpose", no DB write', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('new').notifier);
      await notifier.loadInitialData();
      notifier.setCategory(1);
      notifier.updateField('bookName', 'Valid Title');

      final success = await notifier.save(userLvl: 3);
      expect(success, isFalse);

      final state = container.read(bookProfileProvider('new'));
      expect(state.errorMessage, "You don't have enough rights for purpose");

      final countRes = await db.rawQuery('SELECT COUNT(*) AS cnt FROM Books');
      expect(countRes.first['cnt'], 5);
    });

    test('g) save() valid new book: INSERTs with MAX(BookID)+1 = 6 (5 seed books present), sets bookId == 6, toast "Book Saved Successfully"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('new').notifier);
      await notifier.loadInitialData();
      notifier.setCategory(2);
      notifier.updateField('bookName', 'Calculus Grade 11');
      notifier.updateField('bAuthor', 'Dr. S. M. Yusuf');
      notifier.updateField('bookPrice', 450);

      final success = await notifier.save(userLvl: 1);
      expect(success, isTrue);

      final state = container.read(bookProfileProvider('new'));
      expect(state.bookId, 6);
      expect(state.isNew, isFalse);
      expect(state.toast, 'Book Saved Successfully');

      final countRes = await db.rawQuery('SELECT COUNT(*) AS cnt FROM Books');
      expect(countRes.first['cnt'], 6);
    });

    test(
      'h) save() valid existing book: UPDATEs row 1, total book count stays 5',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(bookProfileProvider('1').notifier);
        await notifier.loadInitialData();
        notifier.updateField('bookName', 'Islamiat Lazmi Updated');

        final success = await notifier.save(userLvl: 1);
        expect(success, isTrue);

        final countRes = await db.rawQuery('SELECT COUNT(*) AS cnt FROM Books');
        expect(countRes.first['cnt'], 5);

        final updatedRow = await db.rawQuery(
          'SELECT BookName FROM Books WHERE BookID = 1',
        );
        expect(updatedRow.first['BookName'], 'Islamiat Lazmi Updated');
      },
    );

    test(
      'i) save() trims whitespace: "  Test Title  " -> DB stores "Test Title"',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(bookProfileProvider('1').notifier);
        await notifier.loadInitialData();
        notifier.updateField('bookName', '   Trimmed Title Test   ');

        final success = await notifier.save(userLvl: 1);
        expect(success, isTrue);

        final row = await db.rawQuery(
          'SELECT BookName FROM Books WHERE BookID = 1',
        );
        expect(row.first['BookName'], 'Trimmed Title Test');
      },
    );

    test('j) delete() existing book: removes row 1, book count 5 -> 4, toast "Book record removed"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('1').notifier);
      await notifier.loadInitialData();

      final success = await notifier.delete(userLvl: 1);
      expect(success, isTrue);

      final state = container.read(bookProfileProvider('1'));
      expect(state.toast, 'Book record removed');

      final countRes = await db.rawQuery('SELECT COUNT(*) AS cnt FROM Books');
      expect(countRes.first['cnt'], 4);
    });

    test('k) delete() in new mode: returns false, sets "Select Book First", no DB change', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('new').notifier);
      await notifier.loadInitialData();

      final success = await notifier.delete(userLvl: 1);
      expect(success, isFalse);

      final state = container.read(bookProfileProvider('new'));
      expect(state.errorMessage, 'Select Book First');

      final countRes = await db.rawQuery('SELECT COUNT(*) AS cnt FROM Books');
      expect(countRes.first['cnt'], 5);
    });

    test('m) Dirty tracking: typing into Title sets state.isDirty == true; discardDraft() resets isDirty == false and restores original value', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookProfileProvider('1').notifier);
      await notifier.loadInitialData();
      expect(container.read(bookProfileProvider('1')).isDirty, isFalse);

      notifier.updateField('bookName', 'Modified Name');
      expect(container.read(bookProfileProvider('1')).isDirty, isTrue);

      await notifier.discardDraft();
      final state = container.read(bookProfileProvider('1'));
      expect(state.isDirty, isFalse);
      expect(state.bookName, 'Islamiat Lazmi Grade 9');
    });

    test('o) Post-save invalidation: after save(), libraryBooksProvider reflects updated catalog state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pre-load library catalog
      final catalogNotifier = container.read(libraryBooksProvider.notifier);
      await catalogNotifier.loadInitialData();
      expect(container.read(libraryBooksProvider).totalBooksAvailable, 5);

      // Save new book
      final notifier = container.read(bookProfileProvider('new').notifier);
      await notifier.loadInitialData();
      notifier.setCategory(1);
      notifier.updateField('bookName', 'New Advanced Book');
      notifier.updateField('bookPrice', 400);

      final success = await notifier.save(userLvl: 1);
      expect(success, isTrue);

      // Invalidation updates catalog state
      expect(container.read(libraryBooksProvider).totalBooksAvailable, 6);
    });
  });

  group('BookProfileScreen Widget & UI Tests', () {
    testWidgets(
      'l) Live cover card updates: typing in Title TextField updates the Left Column cover card\'s Text after pump()',
      (tester) async {
        late BookProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = BookProfileNotifier('new');
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(bookIdParam: 'new', notifier: notifier),
        );
        await tester.pumpAndSettle();

        final titleField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Enter book title',
        );
        expect(titleField, findsOneWidget);

        await tester.enterText(titleField, 'Physics for High School');
        await tester.pump();

        expect(find.text('Physics for High School'), findsWidgets);
      },
    );

    testWidgets(
      'n) Permission gate in widget: pressing [Save Changes (Ctrl+S)] when userLvl == 3 sets "You don\'t have enough rights for purpose", no DB write',
      (tester) async {
        late BookProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = BookProfileNotifier('1');
          await notifier.loadInitialData();
          notifier.switchToEditMode();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(bookIdParam: '1', userLevel: 3, notifier: notifier),
        );
        await tester.pumpAndSettle();

        final saveButton = find.widgetWithText(
          ElevatedButton,
          'Save Changes (Ctrl+S)',
        );
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(
          find.text("You don't have enough rights for purpose"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'p) Fits 1440x900 AND 1440x780 (weak-password banner active) with tester.takeException() == null',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        late BookProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = BookProfileNotifier('1');
          await notifier.loadInitialData();
        });

        // Viewport 1: 1440x900
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        await tester.pumpWidget(
          buildTestScreen(
            bookIdParam: '1',
            notifier: notifier,
            hasWeakPasswordWarning: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BookProfileScreen), findsOneWidget);

        // Viewport 2: 1440x780 with weak-password banner
        await tester.binding.setSurfaceSize(const Size(1440, 780));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BookProfileScreen), findsOneWidget);
      },
    );
  });
}
