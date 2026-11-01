import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/system_settings_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/system/system_settings_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  const testMetadata = ShellMetadata(
    branchName: "Ailyans's Higher Secondary School Mianwali",
    branchAddress: 'Muslim Bazar Mianwali',
    branchPhone: '03334449993',
    branchPrincipal: 'Nasir ali',
    sessionYear: '2017-2018',
    studentCount: 10,
    classCount: 13,
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

    EditableText.debugDeterministicCursor = true;
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    EditableText.debugDeterministicCursor = false;
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Widget buildTestScreen({
    int userLevel = 1,
    SystemSettingsNotifier? notifier,
  }) {
    final router = GoRouter(
      initialLocation: '/system/settings',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/system/settings',
              builder: (context, state) => const SystemSettingsScreen(),
            ),
            GoRoute(
              path: '/system/users',
              builder: (context, state) =>
                  const Scaffold(body: Text('Users Stub')),
            ),
            GoRoute(
              path: '/system/permissions',
              builder: (context, state) =>
                  const Scaffold(body: Text('Permissions Stub')),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) =>
                  const Scaffold(body: Text('Dashboard Stub')),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          systemSettingsProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(
            User(
              id: 1,
              name: 'Wazahat Raza Zaidi',
              password: 'wr',
              userLevel: userLevel,
            ),
            [1, 2, 3, 4, 14, 22, 27],
          );
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => testMetadata),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('SystemSettingsProvider Unit & Business Logic Tests', () {
    test(
      'a. Initial data loads from InstBranch (BrnachID = 1) and app_config',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(systemSettingsProvider.notifier);
        await notifier.loadInitialData();

        final state = container.read(systemSettingsProvider);
        expect(state.isLoading, isFalse);
        expect(
          state.branch.branchName,
          "Ailyans's Higher Secondary School Mianwali",
        );
        expect(state.branch.secPd, 'zaidi110');
        expect(state.config.defaultSessionYr, '2017-2018');
        expect(state.schemaVersion, 8);
        expect(state.isDirty, isFalse);
      },
    );

    test('b. In dirty state, isDirty returns true when any field in InstBranch or app_config changes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      expect(container.read(systemSettingsProvider).isDirty, isFalse);

      notifier.setBranchName('New School Name');
      expect(container.read(systemSettingsProvider).isDirty, isTrue);

      notifier.discardChanges();
      expect(container.read(systemSettingsProvider).isDirty, isFalse);

      notifier.setDarkMode(true);
      expect(container.read(systemSettingsProvider).isDirty, isTrue);
    });

    test(
      'c. Discard changes restores original values and resets isDirty to false',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(systemSettingsProvider.notifier);
        await notifier.loadInitialData();

        notifier.setBranchName('Temporary Modified Name');
        notifier.setDarkMode(true);
        expect(container.read(systemSettingsProvider).isDirty, isTrue);

        notifier.discardChanges();
        final state = container.read(systemSettingsProvider);
        expect(state.isDirty, isFalse);
        expect(
          state.branch.branchName,
          "Ailyans's Higher Secondary School Mianwali",
        );
        expect(state.config.darkMode, isFalse);
      },
    );

    test(
      'd. Validation: empty branch name rejected with specific error',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(systemSettingsProvider.notifier);
        await notifier.loadInitialData();

        notifier.setBranchName('   ');
        final success = await notifier.saveSettings(userLevel: 1);

        expect(success, isFalse);
        expect(
          container.read(systemSettingsProvider).errorMessage,
          'Institution / Branch Name is required',
        );
      },
    );

    test('e. Validation: blank SecPd rejected with specific error', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      notifier.setSecPd('   ');
      final success = await notifier.saveSettings(userLevel: 1);

      expect(success, isFalse);
      expect(
        container.read(systemSettingsProvider).errorMessage,
        'Supervisory Revocation Password (SecPd) cannot be blank',
      );
    });

    test('f. Validation: modified SecPd < 6 characters rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      notifier.setSecPd('12345');
      final success = await notifier.saveSettings(userLevel: 1);

      expect(success, isFalse);
      expect(
        container.read(systemSettingsProvider).errorMessage,
        'SecPd must be at least 6 characters',
      );
    });

    test('g. Validation: non-admin (userLevel != 1) save rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      final success = await notifier.saveSettings(userLevel: 2);

      expect(success, isFalse);
      expect(
        container.read(systemSettingsProvider).errorMessage,
        "You don't have enough rights for purpose",
      );
    });

    test(
      'h. Save updates InstBranch and app_config atomically in transaction',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(systemSettingsProvider.notifier);
        await notifier.loadInitialData();

        notifier.setBranchName('Updated Central Academy');
        notifier.setDefaultSessionYr('2024-2025');

        final success = await notifier.saveSettings(userLevel: 1);
        expect(success, isTrue);

        final state = container.read(systemSettingsProvider);
        expect(state.isDirty, isFalse);
        expect(state.toastMessage, 'Settings saved successfully');

        // Verify DB rows directly
        final rows = await db.rawQuery(
          'SELECT BranchName FROM InstBranch WHERE BrnachID = 1 LIMIT 1',
        );
        expect(rows.first['BranchName'], 'Updated Central Academy');

        final configRows = await db.rawQuery(
          "SELECT config_value FROM app_config WHERE config_key = 'default_session_yr'",
        );
        expect(
          configRows.first['config_value'],
          '2024-25',
        ); // normalized from 2024-2025 by _normalizeSessionYr
      },
    );

    test(
      'i. Dark mode toggle save succeeds and shows restart hint toast',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(systemSettingsProvider.notifier);
        await notifier.loadInitialData();

        notifier.setDarkMode(true);
        final success = await notifier.saveSettings(userLevel: 1);
        expect(success, isTrue);

        final state = container.read(systemSettingsProvider);
        expect(
          state.toastMessage,
          'Settings saved successfully (Theme change requires app restart)',
        );

        final configRows = await db.rawQuery(
          "SELECT config_value FROM app_config WHERE config_key = 'dark_mode'",
        );
        expect(configRows.first['config_value'], 'true');
      },
    );

    test('j. Working days toggle correctly adds/removes days and preserves canonical order', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      // Initially Mon..Sat
      expect(container.read(systemSettingsProvider).config.workingDays, [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ]);

      // Remove Friday
      notifier.toggleWorkingDay('Friday');
      expect(container.read(systemSettingsProvider).config.workingDays, [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Saturday',
      ]);

      // Add Sunday
      notifier.toggleWorkingDay('Sunday');
      expect(container.read(systemSettingsProvider).config.workingDays, [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Saturday',
        'Sunday',
      ]);
    });

    test('k. Rotate password: non-admin rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      final err = await notifier.rotatePassword(
        userLevel: 2,
        currentPassword: 'zaidi110',
        newPassword: 'newPassword123',
        confirmPassword: 'newPassword123',
      );

      expect(err, "You don't have enough rights for purpose");
    });

    test('l. Rotate password: incorrect current password rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      final err = await notifier.rotatePassword(
        userLevel: 1,
        currentPassword: 'wrongPassword',
        newPassword: 'newPassword123',
        confirmPassword: 'newPassword123',
      );

      expect(err, 'Current password is incorrect');
    });

    test('m. Rotate password: mismatch confirmation rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      final err = await notifier.rotatePassword(
        userLevel: 1,
        currentPassword: 'zaidi110',
        newPassword: 'newPassword123',
        confirmPassword: 'differentPassword',
      );

      expect(err, 'New password confirmation does not match');
    });

    test('n. Rotate password: new password < 6 characters rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      final err = await notifier.rotatePassword(
        userLevel: 1,
        currentPassword: 'zaidi110',
        newPassword: 'abc',
        confirmPassword: 'abc',
      );

      expect(err, 'New password must be at least 6 characters');
    });

    test(
      'o. Rotate password: new password identical to current rejected',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(systemSettingsProvider.notifier);
        await notifier.loadInitialData();

        final err = await notifier.rotatePassword(
          userLevel: 1,
          currentPassword: 'zaidi110',
          newPassword: 'zaidi110',
          confirmPassword: 'zaidi110',
        );

        expect(err, 'New password must differ from current password');
      },
    );
  });

  group('SystemSettingsScreen Widget Tests', () {
    testWidgets(
      'p. Renders without exceptions at 1440x900 and 1440x780 on all 4 tabs',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;

        final notifier = SystemSettingsNotifier();
        await tester.runAsync(() async {
          await notifier.loadInitialData();
        });

        // 1. Test at 1440x900
        tester.view.physicalSize = const Size(1440, 900);
        await tester.pumpWidget(
          buildTestScreen(userLevel: 1, notifier: notifier),
        );
        await tester.pumpAndSettle();

        expect(find.text('SYSTEM SETTINGS & CONFIGURATION'), findsOneWidget);
        expect(find.text('SuperAdmin Only'), findsOneWidget);
        expect(find.text('BRANCH IDENTIFICATION & LEADERSHIP'), findsOneWidget);

        // Switch to Tab 1 (Academic Calendar)
        await tester.tap(find.text('Academic Calendar'));
        await tester.pumpAndSettle();
        expect(
          find.text('DEFAULT ENROLLMENT & BILLING SESSION'),
          findsOneWidget,
        );

        // Switch to Tab 2 (Appearance & Locale)
        await tester.tap(find.text('Appearance & Locale'));
        await tester.pumpAndSettle();
        expect(find.text('THEME & VISUAL DENSITY'), findsOneWidget);

        // Switch to Tab 3 (System Information)
        await tester.tap(find.text('System Information'));
        await tester.pumpAndSettle();
        expect(find.text('APPLICATION IDENTIFICATION'), findsOneWidget);

        // 2. Test at 1440x780
        tester.view.physicalSize = const Size(1440, 780);
        await tester.pumpWidget(
          buildTestScreen(userLevel: 1, notifier: notifier),
        );
        await tester.pumpAndSettle();

        // Tab 0
        await tester.tap(find.text('Institution Profile'));
        await tester.pumpAndSettle();
        expect(find.text('BRANCH IDENTIFICATION & LEADERSHIP'), findsOneWidget);

        // Tab 1
        await tester.tap(find.text('Academic Calendar'));
        await tester.pumpAndSettle();
        expect(
          find.text('DEFAULT ENROLLMENT & BILLING SESSION'),
          findsOneWidget,
        );

        // Tab 2
        await tester.tap(find.text('Appearance & Locale'));
        await tester.pumpAndSettle();
        expect(find.text('THEME & VISUAL DENSITY'), findsOneWidget);

        // Tab 3
        await tester.tap(find.text('System Information'));
        await tester.pumpAndSettle();
        expect(find.text('APPLICATION IDENTIFICATION'), findsOneWidget);

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      },
    );

    testWidgets('Tab 4 (Data & Backups) renders at 1440x780 without overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;

      final notifier = SystemSettingsNotifier();
      await tester.runAsync(() async {
        await notifier.loadInitialData();
      });
      notifier.setActiveTab(4);

      // 1. Test at 1440x780
      tester.view.physicalSize = const Size(1440, 780);
      await tester.pumpWidget(
        buildTestScreen(userLevel: 1, notifier: notifier),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('DATABASE BACKUP & RESTORE'), findsOneWidget);
      expect(find.text('RESTORE FROM BACKUP'), findsOneWidget);
      expect(find.text('AVAILABLE BACKUPS'), findsOneWidget);

      // 2. Test at 1440x900
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(
        buildTestScreen(userLevel: 1, notifier: notifier),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('DATABASE BACKUP & RESTORE'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
