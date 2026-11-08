// Phase G / G-6b — unified 3-screen × 3-size loaded-state zero-overflow
// suite (handoff name: mobile_layout_test.dart). Per-screen ProviderScope
// overrides + in-memory DB harness copied verbatim from the 3 per-screen
// G-6b mobile test files. The 3 focused files remain for debugging.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/library_books_provider.dart';
import 'package:school_automation/core/providers/salary_management_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/teacher_list_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/library/library_books_screen.dart';
import 'package:school_automation/screens/staff/salary_management_screen.dart';
import 'package:school_automation/screens/staff/teacher_list_screen.dart';
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

    // Seed 6th teacher as active
    await db.insert('Teachers', {
      'TeacherID': 6,
      'TName': 'Test Staff Member',
      'TFName': 'Test Father',
      'TCNIC': '38302-6666666-6',
      'TContactNo1': '03336666666',
      'TSubject': 'General',
      'DOJoing': '2018-01-01',
      'TIsPresent': 'Y',
      'TCat': 'Staff',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed TSalParam
    await db.insert('TSalParam', {
      'SalParamID': 1,
      'SalParam': 'Basic Salary',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalParam', {
      'SalParamID': 2,
      'SalParam': 'House Rent',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalParam', {
      'SalParamID': 3,
      'SalParam': 'TA/DA',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed TSalLvl
    await db.insert('TSalLvl', {
      'SalLvl': 1,
      'LvlDetail': 'Teacher Level 1',
      'AllowedLeaves': 12,
      'PerLeaveDeduct': 500,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvl', {
      'SalLvl': 2,
      'LvlDetail': 'Teacher Level 2',
      'AllowedLeaves': 18,
      'PerLeaveDeduct': 750,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvl', {
      'SalLvl': 3,
      'LvlDetail': 'Teacher Level 3',
      'AllowedLeaves': 24,
      'PerLeaveDeduct': 1000,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed TSalLvlAmount for 2017-2018
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 1,
      'SalLvl': 1,
      'SalParamID': 1,
      'Amount': 5000,
      'SalYear': '2017-2018',
      'Remarks': 'Basic',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 2,
      'SalLvl': 1,
      'SalParamID': 2,
      'Amount': 5000,
      'SalYear': '2017-2018',
      'Remarks': 'Rent',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 3,
      'SalLvl': 1,
      'SalParamID': 3,
      'Amount': 1000,
      'SalYear': '2017-2018',
      'Remarks': 'Transport',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('TSalLvlAmount', {
      'T_SalTD': 4,
      'SalLvl': 2,
      'SalParamID': 1,
      'Amount': 7000,
      'SalYear': '2017-2018',
      'Remarks': 'Basic',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 5,
      'SalLvl': 2,
      'SalParamID': 2,
      'Amount': 5000,
      'SalYear': '2017-2018',
      'Remarks': 'Rent',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 6,
      'SalLvl': 2,
      'SalParamID': 3,
      'Amount': 1000,
      'SalYear': '2017-2018',
      'Remarks': 'Transport',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('TSalLvlAmount', {
      'T_SalTD': 7,
      'SalLvl': 3,
      'SalParamID': 1,
      'Amount': 10000,
      'SalYear': '2017-2018',
      'Remarks': 'Basic',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 8,
      'SalLvl': 3,
      'SalParamID': 2,
      'Amount': 5000,
      'SalYear': '2017-2018',
      'Remarks': 'Rent',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TSalLvlAmount', {
      'T_SalTD': 9,
      'SalLvl': 3,
      'SalParamID': 3,
      'Amount': 1000,
      'SalYear': '2017-2018',
      'Remarks': 'Transport',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Seed TEmp_Lvl
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 1,
      'TeacherID': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 3,
      'TeacherID': 2,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 3,
      'TeacherID': 3,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 3,
      'TeacherID': 4,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 2,
      'TeacherID': 5,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('TEmp_Lvl', {
      'TSalLvlID': 2,
      'TeacherID': 6,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  // Copied verbatim from test/mobile_g6b_teacher_list_test.dart
  Widget wrapTeacherList(TeacherListNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/staff/teachers',
      routes: [
        GoRoute(
          path: '/staff/teachers',
          builder: (context, state) => const TeacherListScreen(),
        ),
        GoRoute(
          path: '/staff/teachers/new',
          builder: (context, state) =>
              const Scaffold(body: Text('New Teacher Stub')),
        ),
        GoRoute(
          path: '/staff/teachers/:id',
          builder: (context, state) => Scaffold(
            body: Text('Teacher Profile Stub: ${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/staff/salary',
          builder: (context, state) =>
              const Scaffold(body: Text('Salary Stub')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
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

  // Copied verbatim from test/mobile_g6b_salary_management_test.dart
  Widget wrapSalaryManagement(SalaryManagementNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/staff/salary',
      routes: [
        GoRoute(
          path: '/staff/salary',
          builder: (context, state) => const SalaryManagementScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        salaryManagementProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser, const [
            8,
            9,
            10,
            12,
            13,
            14,
            20,
            22,
          ]);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  // Copied verbatim from test/mobile_g6b_library_books_test.dart
  Widget wrapLibraryBooks(LibraryBooksNotifier notifier) {
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

  const sizes = <Size>[Size(360, 800), Size(390, 844), Size(414, 896)];

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('G-6b unified mobile staff + library screens zero-overflow', () {
    for (final size in sizes) {
      testWidgets('TeacherListScreen loaded at $size', (tester) async {
        setSize(tester, size);

        late TeacherListNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherListNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrapTeacherList(notifier));
        await tester.pump();

        // Let the screen's own post-frame loadInitialData complete under real async.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'teacher_list overflow at $size',
        );
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'teacher_list cards at $size',
        );
      });

      testWidgets('SalaryManagementScreen loaded at $size', (tester) async {
        setSize(tester, size);

        late SalaryManagementNotifier notifier;
        await tester.runAsync(() async {
          notifier = SalaryManagementNotifier();
          await notifier.loadInitialData();
          await notifier.selectEmployee(1);
        });

        await tester.pumpWidget(wrapSalaryManagement(notifier));
        await tester.pump();

        // Let the screen's own post-frame load complete under real async.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'salary_management overflow at $size',
        );
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'salary_management cards at $size',
        );
      });

      testWidgets('LibraryBooksScreen loaded at $size', (tester) async {
        setSize(tester, size);

        late LibraryBooksNotifier notifier;
        await tester.runAsync(() async {
          notifier = LibraryBooksNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrapLibraryBooks(notifier));
        await tester.pump();

        // Let the screen's own post-frame loadInitialData complete under real
        // async so the loading spinner is replaced by the loaded catalog.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();

        // Drive the real event loop and pump repeatedly so each awaited query can complete.
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
          reason: 'library_books overflow at $size',
        );
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'library_books cards at $size',
        );
      });
    }
  });
}
