// Phase G / G-6a-2 — mobile ExamTermScreen loaded-state zero-overflow at
// 360x800, 390x844, 414x896. The in-memory SQLite harness and ProviderScope
// overrides are copied from test/exam_term_screen_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/exam_term_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/exams/exam_term_screen.dart';
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

  Widget wrap(Widget child, ExamTermNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/exams/terms',
      routes: [
        GoRoute(
          path: '/exams/terms',
          builder: (context, state) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/exams/marks',
          builder: (context, state) =>
              const Scaffold(body: Text('Marks Entry')),
        ),
        GoRoute(
          path: '/exams/subjects',
          builder: (context, state) =>
              const Scaffold(body: Text('Class Subjects Stub')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        examTermProvider.overrideWith((ref) => notifier),
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

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  const sizes = <Size>[Size(360, 800), Size(390, 844), Size(414, 896)];

  group('G-6a-2 mobile ExamTermScreen zero-overflow', () {
    for (final size in sizes) {
      testWidgets('loaded terms at $size', (tester) async {
        setSize(tester, size);

        late ExamTermNotifier notifier;
        await tester.runAsync(() async {
          notifier = ExamTermNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrap(const ExamTermScreen(), notifier));
        await tester.pump();

        // Let the screen's own post-frame loadInitialData complete under real
        // async so the loading spinner is replaced by the loaded catalog.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'exam_term zero-overflow at $size',
        );

        // Loaded term cards must render (not the empty catalog state).
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'mobile term cards rendered at $size',
        );

        // Session form dropdowns must be present and visible.
        final dropdownCount = find
            .byWidgetPredicate((widget) => widget is DropdownButton)
            .evaluate()
            .length;
        expect(
          dropdownCount,
          greaterThan(0),
          reason: 'dropdowns rendered at $size',
        );

        // Known seeded selected labels must be visible (not clipped).
        expect(
          find.textContaining('1st Term').evaluate().length,
          greaterThan(0),
          reason: 'selected term label visible at $size',
        );
        expect(
          find.textContaining('2017-2018').evaluate().length,
          greaterThan(0),
          reason: 'selected session label visible at $size',
        );
      });
    }
  });
}
