import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/student_registration_provider.dart';
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

  group('Sibling Discovery Provider & Query Tests', () {
    test(
      '1. Exact 15-character CNIC matches 2 seed siblings (4414 & 4415)',
      () async {
        final siblings = await fetchSiblings(db, cnic: '38302-4567890-4');

        expect(siblings.length, 2);
        expect(siblings[0].stuRegId, 4414);
        expect(siblings[0].fullName, 'Fatima Zahra');
        expect(siblings[0].fName, 'Tariq Mehmood');
        expect(siblings[0].cnicNo, '38302-4567890-4');
        expect(siblings[0].className, 'Class 10');
        expect(siblings[0].sectionName, 'A');

        expect(siblings[1].stuRegId, 4415);
        expect(siblings[1].fullName, 'Usman Tariq');
        expect(siblings[1].fName, 'Tariq Mehmood');
      },
    );

    test('2. Raw 13 digits without hyphens matches 2 seed siblings', () async {
      final siblings = await fetchSiblings(db, cnic: '3830245678904');

      expect(siblings.length, 2);
      expect(siblings.map((s) => s.stuRegId), containsAll([4414, 4415]));
    });

    test(
      '3. 10-character prefix (38302-4567) matches 2 seed siblings',
      () async {
        final siblings = await fetchSiblings(db, cnic: '38302-4567');

        expect(siblings.length, 2);
        expect(siblings.map((s) => s.stuRegId), containsAll([4414, 4415]));
      },
    );

    test('4. Under-threshold CNIC (3830) returns empty list', () async {
      final siblings = await fetchSiblings(db, cnic: '3830');

      expect(siblings, isEmpty);
    });

    test(
      '5. Father Name fallback matches 2 seed siblings (>= 5 chars)',
      () async {
        final siblings = await fetchSiblings(db, fatherName: 'Tariq Mehmood');

        expect(siblings.length, 2);
        expect(siblings[0].stuRegId, 4414);
        expect(siblings[1].stuRegId, 4415);
      },
    );

    test('6. Father Name fallback is case-insensitive', () async {
      final siblings = await fetchSiblings(db, fatherName: 'tariq mehmood');

      expect(siblings.length, 2);
    });

    test(
      '7. Under-threshold Father Name ("Tar" < 5 chars) returns empty list',
      () async {
        final siblings = await fetchSiblings(db, fatherName: 'Tar');

        expect(siblings, isEmpty);
      },
    );

    test(
      '8. Riverpod siblingDiscoveryProvider resolves with SiblingQuery',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final result = await container.read(
          siblingDiscoveryProvider(const SiblingQuery('38302-4567890-4', ''))
              .future,
        );

        expect(result.length, 2);
        expect(result.first.stuRegId, 4414);
        expect(result.last.stuRegId, 4415);
      },
    );

    test(
      '9. Riverpod siblingDiscoveryProvider resolves with Father Name query',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final result = await container.read(
          siblingDiscoveryProvider(const SiblingQuery('', 'Tariq Mehmood'))
              .future,
        );

        expect(result.length, 2);
        expect(result.first.stuRegId, 4414);
        expect(result.last.stuRegId, 4415);
      },
    );

    test('10. Copy Family info picks highest Stu_RegID (4415) and does not overwrite user input', () {
      const olderSibling = SiblingInfo(
        stuRegId: 4414,
        nameFirst: 'Fatima',
        nameLast: 'Zahra',
        fName: 'Tariq Mehmood',
        pAddress: 'Old Address St 1, Block A',
        tAddress: 'Old Address St 1, Block A',
        occupation: 'Senior Clerk',
        mobile1: '03001111111',
        emerContName: 'Uncle Tariq',
        emerContMobile: '03009999991',
      );

      const youngerSibling = SiblingInfo(
        stuRegId: 4415,
        nameFirst: 'Usman',
        nameLast: 'Tariq',
        fName: 'Tariq Mehmood',
        pAddress: 'New Address St 9, Block C',
        tAddress: 'New Address St 9, Block C',
        occupation: 'Branch Manager',
        mobile1: '03004567890',
        emerContName: 'Tariq Mehmood',
        emerContMobile: '03009999992',
      );

      final siblings = [olderSibling, youngerSibling];

      // Highest Stu_RegID resolution logic
      final selected = siblings.reduce(
        (curr, next) => curr.stuRegId > next.stuRegId ? curr : next,
      );
      expect(selected.stuRegId, 4415);
      expect(selected.pAddress, 'New Address St 9, Block C');
      expect(selected.occupation, 'Branch Manager');

      // Test copy on empty draft: all fields populated from selected sibling (4415)
      final emptyDraft = WizardDraft();
      emptyDraft.copyFamilyFromSibling(selected);
      expect(emptyDraft.pAddress, 'New Address St 9, Block C');
      expect(emptyDraft.tAddress, 'New Address St 9, Block C');
      expect(emptyDraft.occupation, 'Branch Manager');
      expect(emptyDraft.mobile1, '03004567890');
      expect(emptyDraft.emerContName, 'Tariq Mehmood');
      expect(emptyDraft.emerContMobile, '03009999992');

      // Test copy with existing user input: existing fields are NOT overwritten
      final dirtyDraft = WizardDraft()
        ..pAddress = 'User Custom Permanent Address'
        ..mobile1 = '03337777777';

      dirtyDraft.copyFamilyFromSibling(selected);
      expect(
        dirtyDraft.pAddress,
        'User Custom Permanent Address',
      ); // Preserved!
      expect(dirtyDraft.mobile1, '03337777777'); // Preserved!
      expect(dirtyDraft.tAddress, 'New Address St 9, Block C'); // Populated!
      expect(dirtyDraft.occupation, 'Branch Manager'); // Populated!
      expect(dirtyDraft.emerContName, 'Tariq Mehmood'); // Populated!
      expect(dirtyDraft.emerContMobile, '03009999992'); // Populated!
    });
  });
}
