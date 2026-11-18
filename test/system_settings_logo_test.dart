import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/system_settings_provider.dart';
import 'package:school_automation/core/sync/sync_service.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/system/system_settings_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late Directory tempDir;
  late File samplePngFile;

  // Canonical 1x1 transparent PNG base64
  const samplePngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  const testMetadata = ShellMetadata(
    branchName: "Ailyans's Higher Secondary School Mianwali",
    branchAddress: 'Muslim Bazar Mianwali',
    branchPhone: '03334449993',
    branchPrincipal: 'Ahzam Shahnil',
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

    tempDir = await Directory.systemTemp.createTemp('logo_test_');
    samplePngFile = File(p.join(tempDir.path, 'sample_logo.png'));
    await samplePngFile.writeAsBytes(base64Decode(samplePngBase64));
  });

  tearDown(() async {
    EditableText.debugDeterministicCursor = false;
    await db.close();
    DatabaseService.instance.setDatabase(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Builds the test screen, pre-loading initial data and switching to Tab 2.
  Widget buildTab2Screen({
    SystemSettingsNotifier? notifier,
    int userLevel = 1,
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

  group('Sync & State Contract — school_logo_path', () {
    test('school_logo_path is in kProtectedConfigKeys so sync push skips it', () {
      expect(kProtectedConfigKeys.contains('school_logo_path'), isTrue);
    });

    test('kDeviceLocalConfigKeys literal is untouched', () {
      expect(kDeviceLocalConfigKeys.contains('school_logo_path'), isFalse);
    });

    test('isDirty is false when only logoPath changes (immediate persistence)', () {
      final state = const SystemSettingsState().copyWith(
        logoPath: () => '/path/to/logo.png',
      );
      expect(state.isDirty, isFalse);
    });
  });

  group('School Logo Section — Viewport & Containment Matrix', () {
    Future<SystemSettingsNotifier> prepareNotifier({String? logoPath}) async {
      final notifier = SystemSettingsNotifier();
      await notifier.loadInitialData();
      if (logoPath != null) {
        await db.rawInsert(
          'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
          ['school_logo_path', logoPath],
        );
        await notifier.loadInitialData();
      }
      notifier.setActiveTab(2);
      return notifier;
    }

    for (final size in [
      const Size(360, 800),
      const Size(390, 844),
      const Size(414, 896),
      const Size(1366, 768),
    ]) {
      testWidgets(
        'renders without overflow at ${size.width.toInt()}x${size.height.toInt()} (no logo)',
        (tester) async {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = size;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final notifier = await tester.runAsync(prepareNotifier);

          await tester.pumpWidget(buildTab2Screen(notifier: notifier));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Mobile navigation to Tab 2
          if (size.width < 800) {
            final appearanceTab = find.text('Appearance & Locale');
            if (appearanceTab.evaluate().isNotEmpty) {
              await tester.tap(appearanceTab);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));
            }
          }

          expect(tester.takeException(), isNull);
          expect(find.text('SCHOOL LOGO'), findsOneWidget);

          // Upload button present & contained within viewport width
          final uploadFinder = find.byKey(const ValueKey('school_logo_upload'));
          expect(uploadFinder, findsOneWidget);
          final uploadRect = tester.getRect(uploadFinder);
          expect(uploadRect.left, greaterThanOrEqualTo(0.0));
          expect(uploadRect.right, lessThanOrEqualTo(size.width));

          // Placeholder present; Remove button hidden
          expect(find.text('No logo uploaded'), findsOneWidget);
          expect(find.byIcon(Icons.business), findsOneWidget);
          expect(find.byKey(const ValueKey('school_logo_remove')), findsNothing);
          expect(find.byKey(const ValueKey('school_logo_preview')), findsNothing);
        },
      );

      testWidgets(
        'renders with real PNG logo at ${size.width.toInt()}x${size.height.toInt()} with button containment',
        (tester) async {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = size;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final notifier = await tester.runAsync(
            () => prepareNotifier(logoPath: samplePngFile.path),
          );

          await tester.pumpWidget(buildTab2Screen(notifier: notifier));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          if (size.width < 800) {
            final appearanceTab = find.text('Appearance & Locale');
            if (appearanceTab.evaluate().isNotEmpty) {
              await tester.tap(appearanceTab);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));
            }
          }

          expect(tester.takeException(), isNull);

          // Preview is displayed
          expect(find.byKey(const ValueKey('school_logo_preview')), findsOneWidget);

          // Both buttons present and contained within screen width
          final uploadFinder = find.byKey(const ValueKey('school_logo_upload'));
          final removeFinder = find.byKey(const ValueKey('school_logo_remove'));
          expect(uploadFinder, findsOneWidget);
          expect(removeFinder, findsOneWidget);

          final uploadRect = tester.getRect(uploadFinder);
          final removeRect = tester.getRect(removeFinder);
          expect(uploadRect.left, greaterThanOrEqualTo(0.0));
          expect(uploadRect.right, lessThanOrEqualTo(size.width));
          expect(removeRect.left, greaterThanOrEqualTo(0.0));
          expect(removeRect.right, lessThanOrEqualTo(size.width));
        },
      );
    }

    testWidgets(
      'missing/corrupt logo file renders placeholder fallback without crashing',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1366, 768);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final missingPath = p.join(tempDir.path, 'missing_logo.png');
        final notifier = await tester.runAsync(
          () => prepareNotifier(logoPath: missingPath),
        );

        await tester.pumpWidget(buildTab2Screen(notifier: notifier));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        // Because File(missingPath).existsSync() is false, it falls back to the placeholder
        expect(find.text('No logo uploaded'), findsOneWidget);
        expect(find.byIcon(Icons.business), findsOneWidget);
      },
    );

    testWidgets(
      'removeLogo removes app_config row and cleans state',
      (tester) async {
        final notifier = await tester.runAsync(
          () => prepareNotifier(logoPath: samplePngFile.path),
        );
        expect(notifier!.state.logoPath, samplePngFile.path);

        await tester.runAsync(notifier.removeLogo);
        expect(notifier.state.logoPath, isNull);

        final rows = await tester.runAsync(
          () => db.query(
            'app_config',
            where: "config_key = 'school_logo_path'",
          ),
        );
        expect(rows, isEmpty);
      },
    );
  });
}
