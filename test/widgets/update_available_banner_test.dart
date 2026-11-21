import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/app_version_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/system_settings_provider.dart';
import 'package:school_automation/core/services/update_check_service.dart';
import 'package:school_automation/core/theme/app_theme_tokens.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/system/system_settings_screen.dart';
import 'package:school_automation/widgets/shell/update_available_banner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

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
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  const sampleManifest = UpdateManifest(
    version: '2.1.0',
    build: 3,
    tag: 'v2.1.0+3',
    publishedAt: '2026-11-21T00:00:00Z',
    notes: 'Bug fixes and performance enhancements.\n- Resolved camera device name overflow\n- Added update notification banner',
    assets: {
      'windows_ailyans': 'https://github.com/ahzam-shahnil/bytewave-releases/releases/download/v2.1.0+3/ailyans-school-manager-windows.zip',
      'windows_clean': 'https://github.com/ahzam-shahnil/bytewave-releases/releases/download/v2.1.0+3/bytewave-school-manager-windows.zip',
      'android_ailyans': 'https://github.com/ahzam-shahnil/bytewave-releases/releases/download/v2.1.0+3/ailyans-school-manager.apk',
      'android_clean': 'https://github.com/ahzam-shahnil/bytewave-releases/releases/download/v2.1.0+3/bytewave-school-manager.apk',
    },
  );

  Widget buildBannerTestApp(Size size, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: appTheme,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: const Align(
                alignment: Alignment.topCenter,
                child: UpdateAvailableBanner(manifest: sampleManifest),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('UpdateAvailableBanner Layout & Containment Tests', () {
    const testSizes = [
      Size(360, 800),
      Size(390, 844),
      Size(414, 896),
      Size(1366, 768),
    ];

    for (final size in testSizes) {
      testWidgets('1. Banner containment and zero overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildBannerTestApp(size));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow allowed');

        // Locate controls
        final changelogFinder = find.text('Changelog');
        final downloadFinder = find.text('Download');
        final dismissFinder = find.byTooltip('Dismiss');

        expect(changelogFinder, findsOneWidget);
        expect(downloadFinder, findsOneWidget);
        expect(dismissFinder, findsOneWidget);

        // Verify getRect containment
        final changelogRect = tester.getRect(changelogFinder);
        final downloadRect = tester.getRect(downloadFinder);
        final dismissRect = tester.getRect(dismissFinder);

        expect(changelogRect.left, greaterThanOrEqualTo(0.0));
        expect(changelogRect.right, lessThanOrEqualTo(size.width));

        expect(downloadRect.left, greaterThanOrEqualTo(0.0));
        expect(downloadRect.right, lessThanOrEqualTo(size.width));

        expect(dismissRect.left, greaterThanOrEqualTo(0.0));
        expect(dismissRect.right, lessThanOrEqualTo(size.width));
      });
    }

    testWidgets('2. Changelog button opens dialog with release notes', (tester) async {
      const size = Size(800, 600);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildBannerTestApp(size));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Changelog'));
      await tester.pumpAndSettle();

      expect(find.text("What's New in v2.1.0+3"), findsOneWidget);
      expect(find.textContaining('Bug fixes and performance enhancements'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Download'), findsWidgets);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text("What's New in v2.1.0+3"), findsNothing);
    });
  });

  group('System Settings Tab 3 Check for Updates Button Containment', () {
    const testSizes = [
      Size(360, 800),
      Size(390, 844),
      Size(414, 896),
      Size(1366, 768),
    ];

    for (final size in testSizes) {
      testWidgets('Check for Updates button containment at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final notifier = SystemSettingsNotifier();
        await tester.runAsync(() async {
          await notifier.loadInitialData();
        });
        notifier.setActiveTab(3); // Tab 3: System Information & Provenance

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              systemSettingsProvider.overrideWith((ref) => notifier),
              appVersionProvider.overrideWith((ref) => Future.value('v2.1.0+3')),
              sessionProvider.overrideWith((ref) {
                final session = SessionNotifier();
                session.setSession(
                  const User(
                    id: 1,
                    name: 'Wazahat Raza Zaidi',
                    password: 'wr',
                    userLevel: 1,
                  ),
                  [1, 2, 3, 4, 14, 22, 27],
                );
                return session;
              }),
            ],
            child: MaterialApp(
              theme: appTheme,
              home: MediaQuery(
                data: MediaQueryData(size: size),
                child: Scaffold(
                  body: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: const SystemSettingsScreen(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Check for Updates button is present and contained
        final btnFinder = find.byKey(const ValueKey('btn_check_for_updates'));
        expect(btnFinder, findsOneWidget);
        expect(tester.takeException(), isNull);

        final btnRect = tester.getRect(btnFinder);
        expect(btnRect.left, greaterThanOrEqualTo(0.0));
        expect(btnRect.right, lessThanOrEqualTo(size.width));
      });
    }
  });
}
