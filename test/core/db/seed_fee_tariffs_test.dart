import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
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

  group('seedFeeTariffsIfEmpty Tests', () {
    test('seeds 9 rows in Cls_Param_Fee with FeeYr=2017-2018', () async {
      await DatabaseSeeder.seedFeeTariffsIfEmpty(db);

      final rows = await db.query('Cls_Param_Fee');
      expect(rows.length, 9);

      for (final r in rows) {
        expect(r['FeeYr'], '2017-2018');
      }

      // Verify Class 10 has 3 rows with correct fee parameters and values
      final class10Rows = await db.rawQuery(
        'SELECT * FROM Cls_Param_Fee '
        'WHERE ClassID = (SELECT ClassID FROM Class WHERE CName = ?) '
        'ORDER BY FeeParamID ASC',
        ['Class 10'],
      );
      expect(class10Rows.length, 3);
      expect(class10Rows[0]['FeeParamID'], 2);
      expect(class10Rows[0]['Fee'], 1500.0);
      expect(class10Rows[1]['FeeParamID'], 3);
      expect(class10Rows[1]['Fee'], 300.0);
      expect(class10Rows[2]['FeeParamID'], 7);
      expect(class10Rows[2]['Fee'], 120.0);

      // Verify Class 5 has 3 rows
      final class5Rows = await db.rawQuery(
        'SELECT * FROM Cls_Param_Fee '
        'WHERE ClassID = (SELECT ClassID FROM Class WHERE CName = ?) '
        'ORDER BY FeeParamID ASC',
        ['Class 5'],
      );
      expect(class5Rows.length, 3);
      expect(class5Rows[0]['FeeParamID'], 2);
      expect(class5Rows[0]['Fee'], 1200.0);
      expect(class5Rows[1]['FeeParamID'], 3);
      expect(class5Rows[1]['Fee'], 250.0);
      expect(class5Rows[2]['FeeParamID'], 7);
      expect(class5Rows[2]['Fee'], 100.0);

      // Verify Class 3 has 3 rows
      final class3Rows = await db.rawQuery(
        'SELECT * FROM Cls_Param_Fee '
        'WHERE ClassID = (SELECT ClassID FROM Class WHERE CName = ?) '
        'ORDER BY FeeParamID ASC',
        ['Class 3'],
      );
      expect(class3Rows.length, 3);
      expect(class3Rows[0]['FeeParamID'], 2);
      expect(class3Rows[0]['Fee'], 1000.0);
      expect(class3Rows[1]['FeeParamID'], 3);
      expect(class3Rows[1]['Fee'], 200.0);
      expect(class3Rows[2]['FeeParamID'], 7);
      expect(class3Rows[2]['Fee'], 80.0);
    });

    test('is completely idempotent when re-run', () async {
      await DatabaseSeeder.seedFeeTariffsIfEmpty(db);
      final countFirst =
          (await db.rawQuery('SELECT COUNT(*) as cnt FROM Cls_Param_Fee'))
                  .first['cnt']
              as int;
      expect(countFirst, 9);

      // Re-run seed
      await DatabaseSeeder.seedFeeTariffsIfEmpty(db);
      final countSecond =
          (await db.rawQuery('SELECT COUNT(*) as cnt FROM Cls_Param_Fee'))
                  .first['cnt']
              as int;
      expect(countSecond, 9);
    });
  });
}
