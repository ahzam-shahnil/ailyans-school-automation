// Phase G / G-6a-3 — mobile ClassSubjectMappingScreen loaded-state
// zero-overflow at 360x800, 390x844, 414x896. The in-memory SQLite harness and
// ProviderScope overrides are copied from test/class_subject_mapping_screen_test.dart.
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

  Widget wrap(ClassSubjectMappingNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/exams/subjects',
      routes: [
        GoRoute(
          path: '/exams/subjects',
          builder: (context, state) => const ClassSubjectMappingScreen(),
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
    );

    return ProviderScope(
      overrides: [
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

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  const sizes = <Size>[Size(360, 800), Size(390, 844), Size(414, 896)];

  group('G-6a-3 mobile ClassSubjectMappingScreen zero-overflow', () {
    for (final size in sizes) {
      testWidgets('loaded mappings at $size', (tester) async {
        setSize(tester, size);

        late ClassSubjectMappingNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSubjectMappingNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrap(notifier));
        await tester.pump();

        // Let the screen's own post-frame loadInitialData complete under real
        // async so the loading spinner is replaced by the loaded mapping rows.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'class_subject_mapping zero-overflow at $size',
        );

        // Loaded mapping cards must render (Class 10 has 5 seeded mappings).
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'mobile mapping cards rendered at $size',
        );

        // Selected class label and total marks footer must be visible.
        expect(
          find.textContaining('ASSIGNED SUBJECTS FOR CLASS 10').evaluate().length,
          greaterThan(0),
          reason: 'class 10 header visible at $size',
        );
        expect(
          find.textContaining('Total Marks: 500').evaluate().length,
          greaterThan(0),
          reason: 'total marks footer visible at $size',
        );
      });
    }
  });
}
