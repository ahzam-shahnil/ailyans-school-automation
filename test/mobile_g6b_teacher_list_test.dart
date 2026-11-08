// Phase G / G-6b-1 — mobile TeacherListScreen loaded-state zero-overflow at
// 360x800, 390x844, 414x896. The in-memory SQLite harness and ProviderScope
// overrides are copied from test/teacher_list_screen_test.dart.
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

  Widget wrap(TeacherListNotifier notifier) {
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

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  const sizes = <Size>[Size(360, 800), Size(390, 844), Size(414, 896)];

  group('G-6b-1 mobile TeacherListScreen zero-overflow', () {
    for (final size in sizes) {
      testWidgets('loaded directory at $size', (tester) async {
        setSize(tester, size);

        late TeacherListNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherListNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrap(notifier));
        await tester.pump();

        // Let the screen's own post-frame loadInitialData complete under real
        // async so the loading spinner is replaced by the loaded directory.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'teacher_list zero-overflow at $size',
        );

        // Loaded teacher cards must render (not the empty state).
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'mobile teacher cards rendered at $size',
        );

        // Known seeded staff names must be visible (not clipped).
        expect(
          find.textContaining('Nasir Ali').evaluate().length,
          greaterThan(0),
          reason: 'seeded teacher name visible at $size',
        );
        expect(
          find.textContaining('Faculty & Staff Directory').evaluate().length,
          greaterThan(0),
          reason: 'header visible at $size',
        );
      });
    }
  });
}
