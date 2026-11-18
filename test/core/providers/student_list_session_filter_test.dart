// Phase K-6-c item 4 — session-filter regression pin for the 4782-shape
// student.
//
// Field report shape (live DB 2026-11-18): Stu_Reg row 4782 EXISTS, but its
// ONLY Student_Class row is (Stu_RegID=4782, ClassID=1, SessionYr='2025-26',
// Present=0) — a historical-only, departed enrollment with no 2026-27 row.
//
// The directory query filters `WHERE sc.SessionYr = ?` (status is a computed
// CASE column, NOT a WHERE predicate), so a historical-only row can never
// appear under default_session_yr='2026-27'. Step 0 proved NO leak — these
// tests PIN that behavior:
//
// 1. Under '2026-27' + status 'All': the 4782-shape row is EXCLUDED, while a
//    Present=1 '2026-27' positive control IS included.
// 2. Under '2025-26': the same 4782-shape row appears as 'Left' — proving
//    the row exists and the exclusion is session-driven, not data loss.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeds the exact 4782 shape + a Present=1 '2026-27' positive control
/// against the seeded fixture (ClassID 13 'Class 10', ClassSecID 25).
Future<void> _seedShape(Database db) async {
  // The 4782 shape: demographics exist, only a departed '2025-26'
  // enrollment, NO '2026-27' row.
  await db.insert('Stu_Reg', {
    'Stu_RegID': 4782,
    'NameFirst': 'Historical',
    'NameLast': 'Only',
    'DOB': '2002-04-12',
    'F_Name': 'Test Father',
    'CNIC_No': '38302-4782000-1',
    'Sex': 'Male',
    'Mobile1': '03004782001',
    'AdmClass': 13,
    'DOAdmission': '2024-08-15',
    'FullDiscount': 0,
  });
  await db.insert('Student_Class', {
    'Stu_RegID': 4782,
    'ClassID': 13,
    'ClassSecID': 25,
    'ClassRollNo': 78,
    'SessionYr': '2025-26',
    'Present': 0,
    'VGen': 'Y',
  });

  // Positive control: actively enrolled under '2026-27'.
  await db.insert('Stu_Reg', {
    'Stu_RegID': 4783,
    'NameFirst': 'Active',
    'NameLast': 'Control',
    'DOB': '2002-04-12',
    'F_Name': 'Test Father',
    'CNIC_No': '38302-4783000-1',
    'Sex': 'Male',
    'Mobile1': '03004783001',
    'AdmClass': 13,
    'DOAdmission': '2024-08-15',
    'FullDiscount': 0,
  });
  await db.insert('Student_Class', {
    'Stu_RegID': 4783,
    'ClassID': 13,
    'ClassSecID': 25,
    'ClassRollNo': 79,
    'SessionYr': '2026-27',
    'Present': 1,
    'VGen': 'Y',
  });
}

/// A filters notifier pinned to [sessionYr] with status 'All' — isolating
/// the SessionYr predicate from the status filter (a null-ref constructor
/// skips the metadata sync and the config bootstrap entirely).
StudentListFiltersNotifier _filtersFor(String sessionYr) {
  final notifier = StudentListFiltersNotifier(null, sessionYr);
  notifier.setStatus('All');
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late ProviderContainer container;

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
    await _seedShape(db);
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  test('4782-shape row is EXCLUDED under default_session_yr 2026-27; '
      'the Present=1 2026-27 control IS included', () async {
    container = ProviderContainer(
      overrides: [
        studentListFiltersProvider.overrideWith((ref) => _filtersFor('2026-27')),
      ],
    );

    final rows = await container.read(studentListProvider.future);
    final ids = rows.map((r) => r.stuRegId).toList();

    expect(
      ids,
      contains(4783),
      reason: 'Positive control: a Present=1 2026-27 enrollment appears',
    );
    expect(
      ids,
      isNot(contains(4782)),
      reason: 'A historical-only Present=0 2025-26 row can NEVER appear '
          'under the 2026-27 session filter (WHERE sc.SessionYr = ?)',
    );
    // The seeded 2017-2018 fixture students are excluded too.
    expect(ids, isNot(contains(4411)));
  });

  test('the SAME 4782-shape row appears under 2025-26 as Left — the '
      'exclusion is session-driven, not missing data', () async {
    container = ProviderContainer(
      overrides: [
        studentListFiltersProvider.overrideWith((ref) => _filtersFor('2025-26')),
      ],
    );

    final rows = await container.read(studentListProvider.future);
    final shape = rows.where((r) => r.stuRegId == 4782).toList();

    expect(shape, hasLength(1));
    expect(shape.single.sessionYr, '2025-26');
    expect(shape.single.status, 'Left');
  });
}
