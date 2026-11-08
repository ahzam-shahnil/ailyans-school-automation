// Phase G / G-6a-1 — mobile MarksEntryScreen loaded-roster zero-overflow at
// 360x800, 390x844, 414x896. The in-memory SQLite harness and ProviderScope
// overrides are copied from test/marks_entry_screen_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/marks_entry_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/exams/marks_entry_screen.dart';
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
    pendingVouchers: 2,
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

  Widget wrap(Widget child) {
    final router = GoRouter(
      initialLocation: '/exams/marks',
      routes: [
        GoRoute(
          path: '/exams/marks',
          builder: (context, state) => Scaffold(body: child),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        availableSessionsProvider.overrideWith((ref) async => ['2017-2018']),
        sessionProvider.overrideWith((ref) {
          final notifier = SessionNotifier();
          notifier.setSession(testUser, const [10, 23, 24]);
          return notifier;
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

  group('G-6a-1 mobile MarksEntryScreen zero-overflow', () {
    for (final size in sizes) {
      testWidgets('loaded roster at $size', (tester) async {
        setSize(tester, size);

        await tester.pumpWidget(wrap(const MarksEntryScreen()));
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        final element = tester.element(find.byType(MarksEntryScreen));
        final container = ProviderScope.containerOf(element, listen: false);

        await tester.runAsync(() async {
          final notifier = container.read(marksEntryProvider.notifier);
          await notifier.loadInitialData();
          await notifier.setExTermId(1); // 1st Term
          await notifier.setClassId(13); // Class 10
          notifier.setClassSecId(25); // Sec A
          notifier.setSubjId(2); // Maths
          await notifier.loadEnrolledStudents();
        });
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'marks_entry zero-overflow at $size',
        );

        // Loaded roster cards must render (not the empty state).
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'mobile student cards rendered at $size',
        );

        // Mobile dropdowns must be present and visible.
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
          find.textContaining('Maths').evaluate().length,
          greaterThan(0),
          reason: 'selected subject label visible at $size',
        );
        expect(
          find.textContaining('Class 10').evaluate().length,
          greaterThan(0),
          reason: 'selected class label visible at $size',
        );
      });
    }
  });
}
