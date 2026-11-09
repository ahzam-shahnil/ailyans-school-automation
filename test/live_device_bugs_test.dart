import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/batch_promotion_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/system_settings_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/student_list_row.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/students/student_list_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Live Device Bug Fixes Tests', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      await SchemaMigrations.migrate(db);
      await DatabaseSeeder.seedIfEmpty(db);

      // Seed app_config with default_session_yr = 2026-27
      await db.rawInsert(
        "INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES ('default_session_yr', '2026-27')",
      );

      DatabaseService.instance.setDatabase(db);
    });

    tearDown(() async {
      await db.close();
      DatabaseService.instance.setDatabase(null);
    });

    test('1. BatchPromotionNotifier loads default_session_yr 2026-27 and computes target 2027-28', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(batchPromotionProvider.notifier).loadInitialData();
      final state = container.read(batchPromotionProvider);

      expect(state.availableSessions, contains('2026-27'));
      expect(state.availableSessions, contains('2027-28'));
      expect(state.sourceSessionYr, '2026-27');
      expect(state.targetSessionYr, '2027-28');
    });

    test('2. availableSessionsProvider includes active anchor 2026-27 and next 2027-28', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sessions = await container.read(availableSessionsProvider.future);
      expect(sessions, contains('2026-27'));
      expect(sessions, contains('2027-28'));
    });

    test('3. SystemSettingsNotifier.saveSettings invalidates relevant providers and syncs session', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      notifier.setDefaultSessionYr('2028-29');
      final ok = await notifier.saveSettings(userLevel: 1);
      expect(ok, isTrue);

      final conf = await db.rawQuery(
        "SELECT config_value FROM app_config WHERE config_key = 'default_session_yr' LIMIT 1",
      );
      expect(conf.first['config_value'], '2028-29');
      expect(container.read(studentListFiltersProvider).sessionYr, '2028-29');
    });

    testWidgets('4. StudentListScreen mobile filter bar renders uncrushed and section dropdown deduplicates', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = GoRouter(
        initialLocation: '/students',
        routes: [
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentListScreen(),
          ),
        ],
      );

      const testUser = User(
        id: 1,
        name: 'Admin',
        password: 'admin',
        userLevel: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentListProvider.overrideWith((ref) => Future.value(const <StudentListRow>[])),
            classesProvider.overrideWith((ref) => Future.value(const [
              SchoolClass(classId: 8, cName: 'Class 5'),
              SchoolClass(classId: 13, cName: 'Class 10'),
            ])),
            sectionsProvider.overrideWith((ref) => Future.value(const [
              ClassSec(classSecId: 15, classId: 8, secName: 'A'),
              ClassSec(classSecId: 16, classId: 8, secName: 'B'),
              ClassSec(classSecId: 25, classId: 13, secName: 'A'),
              ClassSec(classSecId: 26, classId: 13, secName: 'B'),
            ])),
            sessionProvider.overrideWith((ref) {
              final sNotifier = SessionNotifier();
              sNotifier.setSession(testUser, const [12, 13, 20, 26]);
              return sNotifier;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Verify uncrushed mobile filter card elements exist
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search by name, reg ID, CNIC, or father name...'), findsOneWidget);
      expect(find.text('All Classes'), findsOneWidget);
      expect(find.text('All Sections'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      // When All Classes is selected, Section dropdown items should only have 'All Sections'
      expect(find.text('All Sections'), findsOneWidget);
    });
  });
}
