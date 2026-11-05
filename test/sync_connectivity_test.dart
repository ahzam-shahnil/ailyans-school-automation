import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/sync/sync_provider.dart';
import 'package:school_automation/core/sync/sync_service.dart';
import 'package:school_automation/widgets/shell/app_status_bar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeds a [SyncPushNotifier] with a deterministic state for widget tests.
class _SeededSyncNotifier extends SyncPushNotifier {
  _SeededSyncNotifier(SyncPushState seed) {
    state = seed;
  }

  @override
  Future<void> triggerSync() async {}
}

Widget _buildStatusBar(SyncPushState state, {double width = 800.0}) {
  return ProviderScope(
    overrides: [
      shellMetadataProvider.overrideWith(
        (ref) => Future.value(ShellMetadata.empty()),
      ),
      syncPushProvider.overrideWith((ref) => _SeededSyncNotifier(state)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: const AppStatusBar(showSyncStatus: true),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('SyncPushState connectivity', () {
    test('connectivity defaults to null (not yet checked)', () {
      const state = SyncPushState();
      expect(state.connectivity, isNull);
    });

    test(
      'updateConnectivity transitions state and triggers sync on '
      'offline -> online only',
      () async {
        var pushCalls = 0;
        var pullCalls = 0;

        final notifier = SyncPushNotifier(
          pushRunner: () async {
            pushCalls++;
            return const SyncPushResult(
              pushedCount: 0,
              failedCount: 0,
              errors: [],
            );
          },
          pullRunner: () async {
            pullCalls++;
            return const SyncPullResult(
              pulledCount: 0,
              failedCount: 0,
              errors: [],
            );
          },
        );
        addTearDown(notifier.dispose);

        // Boot: null -> online must NOT trigger a duplicate sync.
        notifier.updateConnectivity(ConnectivityResult.wifi);
        await pumpEventQueue();
        expect(notifier.state.connectivity, ConnectivityResult.wifi);
        expect(pushCalls, 0);
        expect(pullCalls, 0);

        // A true offline -> online edge must trigger push + pull.
        notifier.updateConnectivity(ConnectivityResult.none);
        expect(notifier.state.connectivity, ConnectivityResult.none);

        notifier.updateConnectivity(ConnectivityResult.wifi);
        await pumpEventQueue();
        expect(notifier.state.connectivity, ConnectivityResult.wifi);
        expect(pushCalls, 1);
        expect(pullCalls, 1);
      },
    );
  });

  group('triggerSync connectivity preservation', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      await SchemaMigrations.migrate(db);
      DatabaseService.instance.setDatabase(db);
    });

    tearDown(() async {
      DatabaseService.instance.setDatabase(null);
      await db.close();
    });

    test('triggerSync preserves connectivity across push + pull', () async {
      final adapter = FakeSyncRemoteAdapter()
        ..fakeFetchDelta = (table, sinceIso, offset, limit) {
          if (table == 'app_config') {
            return [
              {
                'config_key': 'f5_connectivity_probe',
                'config_value': 'ok',
                'updated_at': '2026-01-01T00:00:00.000Z',
              },
            ];
          }
          return const [];
        };
      final svc = SyncService(adapter: adapter, openDb: () async => db);
      final notifier = SyncPushNotifier(
        pushRunner: svc.pushOutbox,
        pullRunner: svc.pullDelta,
      );
      addTearDown(notifier.dispose);

      notifier.updateConnectivity(ConnectivityResult.wifi);
      expect(notifier.state.connectivity, ConnectivityResult.wifi);

      await notifier.triggerSync();

      // Regression: wholesale SyncPushState(...) construction would reset
      // connectivity to null here.
      expect(notifier.state.connectivity, ConnectivityResult.wifi);
      expect(notifier.state.isPushing, isFalse);
      expect(notifier.state.isPulling, isFalse);
      expect(notifier.state.lastPulledCount, 1);
    });
  });

  group('AppStatusBar sync status', () {
    testWidgets('renders Offline Mode when connectivity is none', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStatusBar(
          const SyncPushState(connectivity: ConnectivityResult.none),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline Mode'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
    });

    testWidgets('renders Syncing when isPushing is true', (tester) async {
      await tester.pumpWidget(
        _buildStatusBar(
          const SyncPushState(
            connectivity: ConnectivityResult.wifi,
            isPushing: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Syncing...'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
    });

    testWidgets('renders Online - Synced when connectivity is wifi and idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStatusBar(
          const SyncPushState(connectivity: ConnectivityResult.wifi),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Online - Synced'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
    });
  });
}
