import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int? firstIntValue(List<Map<String, Object?>> rows) {
  if (rows.isEmpty || rows.first.values.isEmpty) return null;
  return rows.first.values.first as int?;
}

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
    // Apply initial migrations (DDL + M1 + app_config)
    await SchemaMigrations.migrate(db);
    // Apply seed data
    await DatabaseSeeder.seedIfEmpty(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('DatabaseSeeder populates all dashboard tables with exact row counts', () async {
    // 1. Class: 13 rows
    final classCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM Class'),
    );
    expect(classCount, 13);

    // 2. ClassSec: 26 rows (2 per class)
    final secCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ClassSec'),
    );
    expect(secCount, 26);

    // 3. Teachers: 5 staff members
    final teacherCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM Teachers'),
    );
    expect(teacherCount, 5);

    final presentTeachers = firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM Teachers WHERE TIsPresent = 'Y'"),
    );
    expect(presentTeachers, 5);

    // 4. Stu_Reg: 10 students
    final studentCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM Stu_Reg'),
    );
    expect(studentCount, 10);

    // 5. Student_Class: 10 enrolled in Class 10-A
    final enrolledCount = firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM Student_Class WHERE ClassID = 13 AND Present = 1',
      ),
    );
    expect(enrolledCount, 10);

    // 6. VoucharMas: 15 rows total
    final voucherTotal = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM VoucharMas'),
    );
    expect(voucherTotal, 15);

    // October vouchers: 10 total
    final octVouchers = firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM VoucharMas WHERE ForMonth = 'October 2017'",
      ),
    );
    expect(octVouchers, 10);

    // October vouchers: 6 paid, 4 unpaid
    final octPaid = firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM VoucharMas WHERE ForMonth = 'October 2017' AND IsPaid = 'Y'",
      ),
    );
    expect(octPaid, 6);

    final octUnpaid = firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM VoucharMas WHERE ForMonth = 'October 2017' AND IsPaid = 'N'",
      ),
    );
    expect(octUnpaid, 4);

    // September vouchers: 5 total, all unpaid
    final sepUnpaid = firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM VoucharMas WHERE ForMonth = 'September 2017' AND IsPaid = 'N'",
      ),
    );
    expect(sepUnpaid, 5);

    // Total pending vouchers (4 Oct + 5 Sep = 9)
    final totalPending = firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM VoucharMas WHERE IsPaid = 'N'"),
    );
    expect(totalPending, 9);

    // 7. VoucharDet: 27 rows
    final voucherDetCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM VoucharDet'),
    );
    expect(voucherDetCount, 27);

    // 8. FeeTransaction: 6 payments today
    final feeTransCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM FeeTransaction'),
    );
    expect(feeTransCount, 6);

    // Sum of collections in FeeTransaction: 10,800
    final collectedSum = firstIntValue(
      await db.rawQuery('SELECT SUM(PaidAmount) FROM FeeTransaction'),
    );
    expect(collectedSum, 10800);

    // October expected fee: 21,000 (8x1800 + 2x3300)
    final octExpected = firstIntValue(
      await db.rawQuery(
        "SELECT SUM(SubTotal) FROM VoucharMas WHERE ForMonth = 'October 2017'",
      ),
    );
    expect(octExpected, 21000);

    // 9. FeeParameters: 16 canonical fee heads
    final feeParamCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM FeeParameters'),
    );
    expect(feeParamCount, 16);

    // Verify key typo-preserving descriptions
    final arrearsRows = await db.rawQuery(
      "SELECT FeeParamID, ParamDesciption FROM FeeParameters WHERE ParamDesciption = 'Arears'",
    );
    expect(arrearsRows.length, 2);

    final slcRows = await db.rawQuery(
      "SELECT FeeParamID, ParamDesciption FROM FeeParameters WHERE ParamDesciption = 'SLC.Fee/'",
    );
    expect(slcRows.length, 1);

    // 10. AttMas: 1 record for Class 10-A today
    final attMasCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM AttMas'),
    );
    expect(attMasCount, 1);

    // 11. AttDet: 10 student records (8 Present, 1 Absent, 1 Leave)
    final attDetCount = firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM AttDet'),
    );
    expect(attDetCount, 10);

    final presentCount = firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM AttDet WHERE AttMasID = 1 AND AttStatus = 'Present'",
      ),
    );
    expect(presentCount, 8);

    final absentCount = firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM AttDet WHERE AttMasID = 1 AND AttStatus = 'Absent'",
      ),
    );
    expect(absentCount, 1);

    final leaveCount = firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM AttDet WHERE AttMasID = 1 AND AttStatus = 'Leave'",
      ),
    );
    expect(leaveCount, 1);

    // Verify Dashboard Attendance % calculation: 80.0%
    final attPctResult = await db.rawQuery(
      "SELECT COUNT(CASE WHEN AttStatus = 'Present' THEN 1 END) * 100.0 / COUNT(*) as attendance_pct "
      'FROM AttDet WHERE AttMasID = 1',
    );
    final attPct = attPctResult.first['attendance_pct'] as double?;
    expect(attPct, 80.0);
  });

  test(
    'DatabaseSeeder is completely idempotent when run multiple times',
    () async {
      // Run seeder a second time
      await DatabaseSeeder.seedIfEmpty(db);

      final classCount = firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM Class'),
      );
      expect(classCount, 13);

      final studentCount = firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM Stu_Reg'),
      );
      expect(studentCount, 10);

      final voucherTotal = firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM VoucharMas'),
      );
      expect(voucherTotal, 15);

      final feeParamCount = firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM FeeParameters'),
      );
      expect(feeParamCount, 16);

      final attMasCount = firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM AttMas'),
      );
      expect(attMasCount, 1);

      final attDetCount = firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM AttDet'),
      );
      expect(attDetCount, 10);
    },
  );
}
