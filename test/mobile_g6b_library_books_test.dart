// Phase G / G-6b-3 — mobile LibraryBooksScreen loaded-state zero-overflow at
// 360x800, 390x844, 414x896. The in-memory SQLite harness and ProviderScope
// overrides are copied from test/library_books_screen_test.dart.
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

  Widget wrap(LibraryBooksNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/library',
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
    );

    const testUser = User(
      id: 1,
      name: 'Test Operator',
      designation: 'Librarian',
      password: 'password123',
      userLevel: 1,
      isActive: true,
    );

    return ProviderScope(
      overrides: [
        libraryBooksProvider.overrideWith((ref) => notifier),
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
          ]);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  const sizes = <Size>[Size(360, 800), Size(390, 844), Size(414, 896)];

  group('G-6b-3 mobile LibraryBooksScreen zero-overflow', () {
    for (final size in sizes) {
      testWidgets('loaded catalog at $size', (tester) async {
        setSize(tester, size);

        late LibraryBooksNotifier notifier;
        await tester.runAsync(() async {
          notifier = LibraryBooksNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrap(notifier));
        await tester.pump();

        // Let the screen's own post-frame loadInitialData complete under real
        // async so the loading spinner is replaced by the loaded catalog.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();

        // The screen's own post-frame loadInitialData performs several
        // sequential real-async DB queries. Drive the real event loop and
        // pump repeatedly so each awaited query can complete.
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'library_books zero-overflow at $size',
        );

        // Loaded book cards must render (not the empty state).
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'mobile book cards rendered at $size',
        );

        // Seeded catalog data must be visible (not clipped).
        expect(
          find.textContaining('Library Book Catalog').evaluate().length,
          greaterThan(0),
          reason: 'header visible at $size',
        );
        expect(
          find.textContaining('5 Books Available').evaluate().length,
          greaterThan(0),
          reason: 'book count badge visible at $size',
        );
      });
    }
  });
}
