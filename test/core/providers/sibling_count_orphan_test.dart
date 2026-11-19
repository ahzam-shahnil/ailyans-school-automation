// Tests for:
// 1. Excluding orphaned Sibling_Links from directory siblingCount
// 2. Cleaning Sibling_Links on student permanent deletion
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/student_profile_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int? _firstIntValue(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return null;
  return rows.first.values.first as int?;
}

StudentListFiltersNotifier _filtersFor(String sessionYr) {
  final notifier = StudentListFiltersNotifier(null, sessionYr);
  notifier.setStatus('All');
  return notifier;
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
    await SchemaMigrations.migrate(db);
    await DatabaseSeeder.seedIfEmpty(db);
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  test('T1 (orphan exclusion): studentListProvider excludes orphaned Sibling_Links', () async {
    // Seed Stu_Reg for 4777, 4792, 4727 (4782 is deliberately omitted)
    for (final regId in [4777, 4792, 4727]) {
      await db.insert('Stu_Reg', {
        'Stu_RegID': regId,
        'NameFirst': 'Student',
        'NameLast': '$regId',
        'DOB': '2010-06-15',
        'F_Name': 'Father $regId',
        'Sex': 'Male',
        'AdmClass': 13,
        'DOAdmission': '2024-08-15',
        'FullDiscount': 0,
      });

      await db.insert('Student_Class', {
        'Stu_RegID': regId,
        'ClassID': 13,
        'ClassSecID': 25,
        'ClassRollNo': regId % 100,
        'SessionYr': '2026-27',
        'Present': 1,
        'VGen': 'Y',
      });
    }

    // Seed Sibling_Links:
    // (4727, 4777) - valid peer (4727 in Stu_Reg)
    // (4777, 4782) - ORPHAN peer (4782 is NOT in Stu_Reg)
    // (4777, 4792) - valid peer (4792 in Stu_Reg)
    await db.insert('Sibling_Links', {
      'LinkID': 1,
      'Stu1_RegID': 4727,
      'Stu2_RegID': 4777,
      'Relation': 'Brother',
    });
    await db.insert('Sibling_Links', {
      'LinkID': 2,
      'Stu1_RegID': 4777,
      'Stu2_RegID': 4782,
      'Relation': 'Brother',
    });
    await db.insert('Sibling_Links', {
      'LinkID': 3,
      'Stu1_RegID': 4777,
      'Stu2_RegID': 4792,
      'Relation': 'Brother',
    });

    final container = ProviderContainer(
      overrides: [
        studentListFiltersProvider.overrideWith((ref) => _filtersFor('2026-27')),
      ],
    );
    addTearDown(container.dispose);

    final students = await container.read(studentListProvider.future);
    final s4777 = students.firstWhere((s) => s.stuRegId == 4777);
    final s4727 = students.firstWhere((s) => s.stuRegId == 4727);
    final s4792 = students.firstWhere((s) => s.stuRegId == 4792);

    // 4777 has 3 link records, but 4782 does not exist in Stu_Reg.
    // siblingCount must be 2 (NOT 3).
    expect(s4777.siblingCount, equals(2));
    expect(s4727.siblingCount, equals(1));
    expect(s4792.siblingCount, equals(1));
  });

  test('T2 (delete cleanup): permanentlyDeleteStudent deletes Sibling_Links for the student', () async {
    // Seed 4777 and 4782
    for (final regId in [4777, 4782]) {
      await db.insert('Stu_Reg', {
        'Stu_RegID': regId,
        'NameFirst': 'Student',
        'NameLast': '$regId',
        'DOB': '2010-06-15',
        'F_Name': 'Father $regId',
        'Sex': 'Male',
        'AdmClass': 13,
        'DOAdmission': '2024-08-15',
        'FullDiscount': 0,
      });

      await db.insert('Student_Class', {
        'Stu_RegID': regId,
        'ClassID': 13,
        'ClassSecID': 25,
        'ClassRollNo': regId % 100,
        'SessionYr': '2026-27',
        'Present': 1,
        'VGen': 'Y',
      });
    }

    // Link (4777, 4782)
    await db.insert('Sibling_Links', {
      'LinkID': 10,
      'Stu1_RegID': 4777,
      'Stu2_RegID': 4782,
      'Relation': 'Brother',
    });

    // Verify link exists prior to delete
    final beforeCount = _firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM Sibling_Links WHERE Stu1_RegID = ? OR Stu2_RegID = ?',
      [4782, 4782],
    ));
    expect(beforeCount, equals(1));

    // Permanently delete 4782
    await permanentlyDeleteStudent(4782);

    // Verify Sibling_Links for 4782 are cleaned up
    final afterCount = _firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM Sibling_Links WHERE Stu1_RegID = ? OR Stu2_RegID = ?',
      [4782, 4782],
    ));
    expect(afterCount, equals(0));

    // Verify 4777 has no links remaining either
    final count4777 = _firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM Sibling_Links WHERE Stu1_RegID = ? OR Stu2_RegID = ?',
      [4777, 4777],
    ));
    expect(count4777, equals(0));

    // Verify Stu_Reg row for 4782 is gone
    final stuReg4782 = await db.query(
      'Stu_Reg',
      where: 'Stu_RegID = ?',
      whereArgs: [4782],
    );
    expect(stuReg4782, isEmpty);
  });
}
