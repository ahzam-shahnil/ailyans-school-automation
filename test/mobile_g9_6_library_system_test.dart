import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
import 'package:school_automation/screens/system/permission_matrix_screen.dart';
import 'package:school_automation/screens/system/user_management_screen.dart';
import 'package:school_automation/widgets/mobile/mobile_kpi_card.dart';
import 'package:school_automation/widgets/mobile/mobile_status_pill.dart';

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

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget wrapLibraryBooks({LibraryBooksNotifier? notifier}) {
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

    return ProviderScope(
      overrides: [
        if (notifier != null)
          libraryBooksProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [3, 8, 9, 10, 12, 13, 14, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapBookProfile({
    String bookIdParam = '1',
    BookProfileNotifier? notifier,
  }) {
    final router = GoRouter(
      initialLocation: '/library/$bookIdParam',
      routes: [
        GoRoute(
          path: '/library',
          builder: (context, state) =>
              const Scaffold(body: Text('Library Directory Stub')),
        ),
        GoRoute(
          path: '/library/new',
          builder: (context, state) =>
              const BookProfileScreen(bookIdParam: 'new'),
        ),
        GoRoute(
          path: '/library/:id',
          builder: (context, state) => BookProfileScreen(
            bookIdParam: state.pathParameters['id'] ?? '1',
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          bookProfileProvider(bookIdParam).overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [3, 8, 9, 10, 12, 13, 14, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapUserManagement() {
    final router = GoRouter(
      initialLocation: '/system/users',
      routes: [
        GoRoute(
          path: '/system/users',
          builder: (context, state) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/system/permissions',
          builder: (context, state) =>
              const Scaffold(body: Text('Permissions Stub')),
        ),
        GoRoute(
          path: '/system/settings',
          builder: (context, state) =>
              const Scaffold(body: Text('Settings Stub')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [8, 9, 10, 12, 13, 14, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapPermissionMatrix() {
    final router = GoRouter(
      initialLocation: '/system/permissions',
      routes: [
        GoRoute(
          path: '/system/permissions',
          builder: (context, state) => const PermissionMatrixScreen(),
        ),
        GoRoute(
          path: '/system/users',
          builder: (context, state) =>
              const Scaffold(body: Text('Users Directory Stub')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) {
          final sNotifier = SessionNotifier();
          sNotifier.setSession(testUser, const [8, 9, 10, 12, 13, 14, 20]);
          return sNotifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> settleScreen(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  testWidgets(
    'LibraryBooksScreen at 360x800 renders MobileKpiCard strip, 44px filter card, and left-strip book cards with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late LibraryBooksNotifier notifier;
      await tester.runAsync(() async {
        notifier = LibraryBooksNotifier();
        await notifier.loadInitialData();
      });

      await tester.pumpWidget(wrapLibraryBooks(notifier: notifier));
      await tester.pump();
      await settleScreen(tester);

      expect(tester.takeException(), isNull);

      // Verify header and 2-up MobileKpiCard strip
      expect(find.text('Library Book Catalog'), findsOneWidget);
      expect(find.byType(MobileKpiCard), findsNWidgets(2));
      expect(find.text('BOOKS AVAILABLE'), findsOneWidget);
      expect(find.text('CATEGORIES'), findsOneWidget);

      // Verify book cards with left strip and status pill
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(MobileStatusPill), findsWidgets);
      expect(find.text('Islamiat Lazmi Grade 9'), findsWidgets);

      // Verify sticky bottom action
      expect(find.text('+ Add New Book (Ctrl+N)'), findsOneWidget);
    },
  );

  testWidgets(
    'BookProfileScreen at 360x800 renders book hero card, inline form controllers, and sticky save bar with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));

      late BookProfileNotifier notifier;
      await tester.runAsync(() async {
        notifier = BookProfileNotifier('1');
        await notifier.loadInitialData();
      });

      await tester.pumpWidget(
        wrapBookProfile(bookIdParam: '1', notifier: notifier),
      );
      await tester.pump();
      await settleScreen(tester);

      expect(tester.takeException(), isNull);

      // Verify hero card
      expect(find.text('Book Profile'), findsOneWidget);
      expect(find.text('Islamiat Lazmi Grade 9'), findsWidgets);
      expect(find.text('Accession #1'), findsOneWidget);

      // Verify form fields
      expect(find.text('BIBLIOGRAPHIC & PUBLICATION METADATA'), findsOneWidget);
      expect(find.text('Book Title *'), findsOneWidget);
      expect(find.text('Subject Category *'), findsOneWidget);

      // Verify view-mode sticky actions
      expect(find.text('Edit Book (Ctrl+E)'), findsOneWidget);
      expect(find.text('Delete Book'), findsOneWidget);

      // Switch to edit mode
      await tester.tap(find.text('Edit Book (Ctrl+E)'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Save Changes (Ctrl+S)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  testWidgets(
    'UserManagementScreen at 360x800 and 390x844 renders operator cards, inline editor form, and sticky action bar with zero overflow',
    (tester) async {
      for (final size in [const Size(360, 800), const Size(390, 844)]) {
        setViewport(tester, size);

        await tester.pumpWidget(wrapUserManagement());
        await tester.pump();
        await settleScreen(tester);

        expect(tester.takeException(), isNull, reason: 'zero overflow at $size');

        // Verify header and 2-up MobileKpiCard strip
        expect(find.text('OPERATOR DIRECTORY'), findsOneWidget);
        expect(find.byType(MobileKpiCard), findsNWidgets(2));
        expect(find.text('TOTAL OPERATORS'), findsOneWidget);
        expect(find.text('SUPERADMINS'), findsOneWidget);

        // Verify operator cards and pills
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(MobileStatusPill), findsWidgets);
        expect(find.text('Wazahat Raza Zaidi'), findsWidgets);

        // Verify form fields
        expect(find.text('Full Name *'), findsOneWidget);
        expect(find.text('Designation / Job Title'), findsOneWidget);
        expect(find.text('Access Authorization Level *'), findsOneWidget);

        // Verify sticky bottom action bar
        expect(find.text('New User (Ctrl+N)'), findsOneWidget);
        expect(find.text('Save User (Ctrl+S)'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'PermissionMatrixScreen at 360x800 and 390x844 renders operator selector, permission toggle cards, and sticky Save Rights bar with zero overflow',
    (tester) async {
      for (final size in [const Size(360, 800), const Size(390, 844)]) {
        setViewport(tester, size);

        await tester.pumpWidget(wrapPermissionMatrix());
        await tester.pump();
        await settleScreen(tester);

        expect(tester.takeException(), isNull, reason: 'zero overflow at $size');

        // Verify header and 2-up MobileKpiCard strip
        expect(find.text('USER ACCESS CONTROL MATRIX'), findsOneWidget);
        expect(find.byType(MobileKpiCard), findsNWidgets(2));
        expect(find.text('AUTHORIZED'), findsOneWidget);
        expect(find.text('TOTAL OBJECTS'), findsOneWidget);

        // Verify bulk actions
        expect(find.text('Select All'), findsOneWidget);
        expect(find.text('Deselect All'), findsOneWidget);

        // Verify module category sections and checkboxes
        expect(find.byType(Checkbox), findsWidgets);
        expect(find.byType(Card), findsWidgets);

        // Verify sticky bottom action bar
        expect(find.text('Save Access Rights (Ctrl+S)'), findsOneWidget);
      }
    },
  );
}
