import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/models/user.dart';
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
    // Execute migrations (initial schema load + M1)
    await SchemaMigrations.migrate(db);
    // Execute seed
    await DatabaseSeeder.seedIfEmpty(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'Database has 53 active tables, app_config, and IsActive column on Users',
    () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      expect(tables.length, 53);

      final tableNames = tables.map((t) => t['name'] as String).toList();
      expect(tableNames.contains('app_config'), isTrue);

      final columns = await db.rawQuery('PRAGMA table_info(Users)');
      final colNames = columns.map((c) => c['name']).toList();
      expect(colNames.contains('IsActive'), isTrue);
    },
  );

  test(
    'DatabaseSeeder correctly seeds InstBranch, Users, AccObj, and AccRhts',
    () async {
      // 1. InstBranch (1 row)
      final branchRows = await db.rawQuery('SELECT * FROM InstBranch');
      expect(branchRows.length, 1);
      expect(branchRows.first['BrnachID'], 1);
      expect(
        branchRows.first['BranchName'],
        "Ailyans's Higher Secondary School Mianwali",
      );
      expect(branchRows.first['SecPd'], 'zaidi110');

      // 2. Users (1 row - Director)
      final userRows = await db.rawQuery('SELECT * FROM Users');
      expect(userRows.length, 1);
      final user = User.fromMap(userRows.first);
      expect(user.name, 'Wazahat Raza Zaidi');
      expect(user.designation, 'Director');
      expect(user.userLevel, 1);
      expect(user.isActive, isTrue);
      // Legacy password 'wr' verification
      expect(BCrypt.checkpw('wr', user.password), isTrue);

      // 3. AccObj (28 rows verbatim)
      final accObjRows = await db.rawQuery(
        'SELECT * FROM AccObj ORDER BY ObjID',
      );
      expect(accObjRows.length, 28);
      final accObjIds = accObjRows.map((r) => r['ObjID'] as int).toList();
      expect(accObjIds, [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        28,
        29,
      ]);

      // 4. AccRhts (25 rows for Director UID = 1, excludes 5, 6, 7)
      final accRhtsRows = await db.rawQuery(
        'SELECT ObjID FROM AccRhts WHERE UID = 1 ORDER BY ObjID',
      );
      expect(accRhtsRows.length, 25);
      final allowedIds = accRhtsRows.map((r) => r['ObjID'] as int).toList();
      expect(allowedIds.contains(5), isFalse);
      expect(allowedIds.contains(6), isFalse);
      expect(allowedIds.contains(7), isFalse);
      expect(allowedIds, [
        1,
        2,
        3,
        4,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        28,
        29,
      ]);
    },
  );

  test('AccessObject filtering excludes ObjID 25', () async {
    final results = await db.rawQuery(
      'SELECT * FROM AccObj WHERE ObjID != 25 ORDER BY ObjID',
    );
    final ids = results.map((r) => r['ObjID'] as int).toList();
    expect(ids.length, 27);
    expect(ids.contains(25), isFalse);
  });
}
