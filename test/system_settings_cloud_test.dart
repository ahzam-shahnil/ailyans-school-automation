import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/system_settings_provider.dart';
import 'package:school_automation/core/sync/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Records the difference between seeded and reset retry counters, and calls
/// through to the real [SyncService.pushOutbox].
class _RecordingSyncService extends SyncService {
  _RecordingSyncService({required super.openDb, super.adapter});

  int calls = 0;
  int retryRowsAtFirstCall = -1;

  @override
  Future<SyncPushResult> pushOutbox() async {
    calls++;
    if (retryRowsAtFirstCall < 0) {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM _sync_outbox WHERE retry_count > 0',
      );
      retryRowsAtFirstCall = (rows.first['n'] as num?)?.toInt() ?? 0;
    }
    return super.pushOutbox();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

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

  test('AppConfigData defaults: empty supabaseUrl/supabaseAnonKey, nodeId '
      'defaults to windows', () {
    const config = AppConfigData();
    expect(config.supabaseUrl, '');
    expect(config.supabaseAnonKey, '');
    expect(config.nodeId, 'windows');
  });

  test('setSupabaseUrl, setSupabaseAnonKey, and setNodeId update config via '
      'copyWith and mark state dirty', () {
    final notifier = SystemSettingsNotifier();

    expect(notifier.state.isDirty, isFalse);

    notifier.setSupabaseUrl('https://example.supabase.co');
    notifier.setSupabaseAnonKey('anon-key');
    notifier.setNodeId('android_a');

    expect(notifier.state.config.supabaseUrl, 'https://example.supabase.co');
    expect(notifier.state.config.supabaseAnonKey, 'anon-key');
    expect(notifier.state.config.nodeId, 'android_a');

    // originalConfig still holds defaults, so the state must be dirty.
    expect(notifier.state.originalConfig.supabaseUrl, '');
    expect(notifier.state.originalConfig.supabaseAnonKey, '');
    expect(notifier.state.originalConfig.nodeId, 'windows');
    expect(notifier.state.isDirty, isTrue);
  });

  test('saveSettings writes supabase_url, supabase_anon_key, and node_id to '
      'app_config without leaving device-local keys in _sync_outbox', () async {
    await DatabaseSeeder.seedIfEmpty(db);

    final notifier = SystemSettingsNotifier(
      configureNodeBlockRunner: (_) async {},
      reconfigureRunner: () async => true,
    );
    await notifier.loadInitialData();

    notifier.setSupabaseUrl('https://new-project.supabase.co');
    notifier.setSupabaseAnonKey('new-anon-key');
    notifier.setNodeId('android_b');

    final ok = await notifier.saveSettings(userLevel: 1);
    expect(ok, isTrue);

    final rows = await db.query(
      'app_config',
      where: 'config_key IN (?, ?, ?)',
      whereArgs: ['supabase_url', 'supabase_anon_key', 'node_id'],
    );
    final map = {
      for (final row in rows)
        row['config_key'] as String: row['config_value'] as String,
    };
    expect(map['supabase_url'], 'https://new-project.supabase.co');
    expect(map['supabase_anon_key'], 'new-anon-key');
    expect(map['node_id'], 'android_b');

    for (final key in ['supabase_url', 'supabase_anon_key', 'node_id']) {
      final outbox = await db.query(
        '_sync_outbox',
        where: "table_name = 'app_config' AND record_pk = ?",
        whereArgs: [key],
      );
      expect(outbox, isEmpty, reason: '$key must not leak to the outbox');
    }
  });

  test('saveSettings invokes configureNodeBlockRunner when nodeId changes and '
      'reconfigureRunner when URL/key changes', () async {
    await DatabaseSeeder.seedIfEmpty(db);

    final nodeCalls = <String>[];
    var reconfigureCalls = 0;

    final notifier = SystemSettingsNotifier(
      configureNodeBlockRunner: (id) async => nodeCalls.add(id),
      reconfigureRunner: () async {
        reconfigureCalls++;
        return true;
      },
    );
    await notifier.loadInitialData();

    notifier.setNodeId('android_a');
    notifier.setSupabaseUrl('https://changed.supabase.co');
    notifier.setSupabaseAnonKey('changed-anon-key');

    final ok = await notifier.saveSettings(userLevel: 1);
    expect(ok, isTrue);
    expect(nodeCalls, ['android_a']);
    expect(reconfigureCalls, 1);

    // A no-op save must not re-run either follow-up.
    final okAgain = await notifier.saveSettings(userLevel: 1);
    expect(okAgain, isTrue);
    expect(nodeCalls, ['android_a']);
    expect(reconfigureCalls, 1);
  });

  test('SyncService.runForcePushAll resets retry_count and drains outbox to 0 '
      'via injected serviceFactory', () async {
    // Three shared app_config rows -> three outbox entries.
    for (final key in ['k1', 'k2', 'k3']) {
      await db.insert('app_config', {
        'config_key': key,
        'config_value': 'value-$key',
      });
    }
    await db.rawUpdate(
      'UPDATE _sync_outbox SET retry_count = 2, last_error = ?',
      ['stale failure'],
    );

    final adapter = FakeSyncRemoteAdapter();
    final service = _RecordingSyncService(
      openDb: () async => db,
      adapter: adapter,
    );

    final result = await SyncService.runForcePushAll(
      serviceFactory: () => service,
    );

    expect(service.calls, greaterThanOrEqualTo(1));
    expect(service.retryRowsAtFirstCall, 0,
        reason: 'retry counters must be reset before the first push');
    expect(result.failedCount, 0);
    expect(result.pushedCount, 3);
    expect(adapter.upserts.length, 3);

    final remaining =
        await db.rawQuery('SELECT COUNT(*) AS n FROM _sync_outbox');
    expect((remaining.first['n'] as num?)?.toInt(), 0);
  });

  test('kDeviceLocalConfigKeys: node_id and supabase_* are excluded from both '
      'pushOutbox and pullDelta', () async {
    expect(
      kDeviceLocalConfigKeys,
      {
        'node_id',
        'supabase_url',
        'supabase_anon_key',
        'supabase_sync_email',
        'supabase_sync_password',
      },
    );

    // Local device-local key plus one shared key (both create outbox rows).
    await db.insert('app_config', {
      'config_key': 'node_id',
      'config_value': 'android_a',
    });
    await db.insert('app_config', {
      'config_key': 'dark_mode',
      'config_value': 'true',
    });

    final adapter = FakeSyncRemoteAdapter();
    final service = SyncService(adapter: adapter, openDb: () async => db);

    // --- Push: node_id must be dropped without any remote call. ---
    await service.pushOutbox();

    final pushedKeys = adapter.upserts
        .where((u) => u.table == 'app_config')
        .map((u) => u.payload['config_key'])
        .toList();
    expect(pushedKeys, isNot(contains('node_id')));
    expect(pushedKeys, contains('dark_mode'));

    final nodeOutbox = await db.query(
      '_sync_outbox',
      where: "table_name = 'app_config' AND record_pk = 'node_id'",
    );
    expect(nodeOutbox, isEmpty);

    // --- Pull: remote node_id must not overwrite the local value. ---
    await db.delete('_sync_outbox');
    adapter.fakeFetchDelta = (table, sinceIso, offset, limit) {
      if (table != 'app_config' || offset > 0) return const [];
      return [
        {
          'config_key': 'node_id',
          'config_value': 'android_b',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        {
          'config_key': 'dark_mode',
          'config_value': 'false',
          'updated_at': '2026-01-01T00:00:01Z',
        },
      ];
    };

    await service.pullDelta();

    final localNode = await db.query(
      'app_config',
      where: "config_key = 'node_id'",
    );
    expect(localNode.single['config_value'], 'android_a');

    final localDark = await db.query(
      'app_config',
      where: "config_key = 'dark_mode'",
    );
    expect(localDark.single['config_value'], 'false');
  });
}
