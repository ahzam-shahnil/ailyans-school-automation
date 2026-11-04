import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/sync/supabase_client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    SupabaseClientWrapper.resetForTesting();

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
    SupabaseClientWrapper.resetForTesting();
    DatabaseService.instance.setDatabase(null);
    await db.close();
  });

  group('SupabaseClientWrapper', () {
    test(
      '1. init returns false when both url and anonKey are empty and app_config empty',
      () async {
        final success = await SupabaseClientWrapper.init();
        expect(success, isFalse);
      },
    );

    test(
      '2. init returns false when only SUPABASE_URL is configured in app_config (anonKey missing)',
      () async {
        await db.insert('app_config', {
          'config_key': 'supabase_url',
          'config_value': 'https://example.supabase.co',
        });

        final success = await SupabaseClientWrapper.init();
        expect(success, isFalse);
      },
    );

    test(
      '3. init is idempotent: calling twice with no creds returns false twice',
      () async {
        final r1 = await SupabaseClientWrapper.init();
        final r2 = await SupabaseClientWrapper.init();
        expect(r1, isFalse);
        expect(r2, isFalse);
      },
    );

    test(
      '4. resetForTesting clears _initialized and _authReady',
      () async {
        final r1 = await SupabaseClientWrapper.init();
        expect(r1, isFalse);

        SupabaseClientWrapper.resetForTesting();

        final r2 = await SupabaseClientWrapper.init();
        expect(r2, isFalse);
      },
    );
  });
}
