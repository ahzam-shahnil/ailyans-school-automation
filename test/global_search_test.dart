import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/global_search_provider.dart';
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

    // Apply schema migrations and seed classes/sections/banks
    await SchemaMigrations.migrate(db);
    await DatabaseSeeder.seedIfEmpty(db);

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('Phase H Shot 6k — Global Omni-Search deduplication', () {
    test(
      'student with multi-session enrollments appears exactly once with the active enrollment',
      () async {
        // Student 5000: two Student_Class rows — an inactive 2025-26
        // enrollment and the active 2026-27 enrollment (screenshot bug:
        // `#4777 Aimal Khan` appeared twice).
        await db.insert('Stu_Reg', {
          'Stu_RegID': 5000,
          'NameFirst': 'Aimal',
          'NameLast': 'Khan',
          'DOB': '2015-01-10',
          'F_Name': 'Khan Muhammad',
          'CNIC_No': '38302-9999999-9',
          'Sex': 'Male',
          'Mobile1': '03009999999',
          'AdmClass': 1,
          'DOAdmission': '2025-04-01',
          'FullDiscount': 0,
        });
        await db.insert('Student_Class', {
          'Stu_RegID': 5000,
          'ClassID': 1, // Play Group
          'ClassSecID': 1, // Sec A
          'ClassRollNo': 1,
          'SessionYr': '2025-26',
          'Present': 0,
          'VGen': 'Y',
        });
        await db.insert('Student_Class', {
          'Stu_RegID': 5000,
          'ClassID': 1, // Play Group
          'ClassSecID': 1, // Sec A
          'ClassRollNo': 1,
          'SessionYr': '2026-27',
          'Present': 1,
          'VGen': 'Y',
        });

        // A single voucher for this student must also appear exactly once.
        await db.insert('VoucharMas', {
          'VoucherMasID': '2710-5000',
          'VDate': '2026-10-01',
          'Student_Class_StuRegID': 5000,
          'ClassID': 1,
          'SubTotal': 1500,
          'ForMonth': 'October 2026',
          'Discount': 0,
          'DueDate': '2026-10-10',
          'IsPaid': 'N',
          'SessionYr': '2026-27',
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final results = await container.read(globalSearchProvider('5000').future);

        // Exactly ONE student hit for Stu_RegID 5000 (deduplicated).
        final studentHits = results.students
            .where((s) => s.stuRegId == 5000)
            .toList();
        expect(studentHits, hasLength(1));
        // The canonical enrollment is the active 2026-27 row (Present = 1).
        expect(studentHits.first.isPresent, isTrue);
        expect(studentHits.first.className, 'Play Group');
        expect(studentHits.first.secName, 'A');
        expect(studentHits.first.rollNo, 1);

        // Exact Reg-ID match is ordered first.
        expect(results.students.first.stuRegId, 5000);

        // Exactly ONE voucher hit for the student's voucher 2710-5000.
        final voucherHits = results.vouchers
            .where((v) => v.voucherId == '2710-5000')
            .toList();
        expect(voucherHits, hasLength(1));
        expect(voucherHits.first.stuRegId, 5000);
      },
    );

    test(
      'student re-enrolled in the same class across sessions is not duplicated',
      () async {
        // Screenshot reproduction: two ACTIVE (Present = 1) enrollments for
        // the same class in different sessions — the case that actually
        // duplicated `#4777 Aimal Khan` in the old query.
        await db.insert('Stu_Reg', {
          'Stu_RegID': 4777,
          'NameFirst': 'Aimal',
          'NameLast': 'Khan',
          'DOB': '2015-01-10',
          'F_Name': 'Khan Muhammad',
          'CNIC_No': '38302-8888888-8',
          'Sex': 'Male',
          'Mobile1': '03008888888',
          'AdmClass': 1,
          'DOAdmission': '2025-04-01',
          'FullDiscount': 0,
        });
        await db.insert('Student_Class', {
          'Stu_RegID': 4777,
          'ClassID': 1,
          'ClassSecID': 1,
          'ClassRollNo': 1,
          'SessionYr': '2025-26',
          'Present': 1,
          'VGen': 'Y',
        });
        await db.insert('Student_Class', {
          'Stu_RegID': 4777,
          'ClassID': 1,
          'ClassSecID': 1,
          'ClassRollNo': 1,
          'SessionYr': '2026-27',
          'Present': 1,
          'VGen': 'Y',
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final results = await container.read(globalSearchProvider('4777').future);

        final studentHits = results.students
            .where((s) => s.stuRegId == 4777)
            .toList();
        expect(studentHits, hasLength(1));
        // Canonical row is the newest session (2026-27), still Present = 1.
        expect(studentHits.first.isPresent, isTrue);
        expect(studentHits.first.className, 'Play Group');
        // Exact Reg-ID match ordered first.
        expect(results.students.first.stuRegId, 4777);
      },
    );
  });
}
