import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/student_registration_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/screens/students/student_registration_wizard.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  const testClasses = [
    SchoolClass(classId: 13, cName: 'Class 10'),
    SchoolClass(classId: 12, cName: 'Class 9'),
  ];

  const testSections = [
    ClassSec(classSecId: 25, classId: 13, secName: 'A'),
    ClassSec(classSecId: 26, classId: 13, secName: 'B'),
  ];

  const testSiblings = [
    SiblingInfo(
      stuRegId: 4414,
      nameFirst: 'Fatima',
      nameLast: 'Zahra',
      fName: 'Tariq Mehmood',
      cnicNo: '38302-4567890-4',
      className: 'Class 10',
      sectionName: 'A',
      classRollNo: 4,
    ),
    SiblingInfo(
      stuRegId: 4415,
      nameFirst: 'Usman',
      nameLast: 'Tariq',
      fName: 'Tariq Mehmood',
      cnicNo: '38302-4567890-4',
      className: 'Class 10',
      sectionName: 'A',
      classRollNo: 5,
    ),
  ];

  final testFeeParameters = [
    {'Fee': 2500, 'ParamDesciption': 'Tuition Fee'},
    {'Fee': 300, 'ParamDesciption': 'Exam Fee'},
  ];

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

  Widget buildTestWizard({GoRouter? customRouter}) {
    final router =
        customRouter ??
        GoRouter(
          initialLocation: '/students/new',
          routes: [
            GoRoute(
              path: '/students/new',
              builder: (context, state) =>
                  const Scaffold(body: StudentRegistrationWizard()),
            ),
            GoRoute(
              path: '/students/:id',
              builder: (context, state) => Scaffold(
                body: Text(
                  'Student Profile Screen ${state.pathParameters['id']}',
                ),
              ),
            ),
            GoRoute(
              path: '/students',
              builder: (context, state) =>
                  const Scaffold(body: Text('Students Directory Screen')),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) =>
                  const Scaffold(body: Text('Dashboard Screen')),
            ),
          ],
        );

    return ProviderScope(
      overrides: [
        classesProvider.overrideWith((ref) => testClasses),
        sectionsProvider.overrideWith((ref) => testSections),
        feePreviewProvider.overrideWith((ref, classId) => testFeeParameters),
        siblingDiscoveryProvider.overrideWith((ref, cnic) {
          if (cnic.trim() == '38302-4567890-4') {
            return testSiblings;
          }
          return [];
        }),
        studentAdmissionSubmitterProvider.overrideWithValue(
          (draft, {sessionYr}) async => 4421,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('StudentRegistrationWizard UI & Workflow Tests', () {
    testWidgets('1. Wizard renders Step 1 with all identity fields', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWizard());
      await tester.pumpAndSettle();

      // Check Breadcrumb & Stepper
      expect(find.text('New Student'), findsOneWidget);
      expect(find.text('Step 1: Personal Info'), findsOneWidget);
      expect(find.text('Step 2: Guardian & Family'), findsOneWidget);
      expect(find.text('Step 3: Contact & Address'), findsOneWidget);
      expect(find.text('Step 4: Academic Placement'), findsOneWidget);

      // Check Step 1 Title
      expect(find.text('Step 1 of 4: Personal Information'), findsOneWidget);

      // Check Form Fields
      expect(find.text('First Name *'), findsOneWidget);
      expect(find.text('Middle Name'), findsOneWidget);
      expect(find.text('Last Name *'), findsOneWidget);
      expect(find.text('Date of Birth *'), findsOneWidget);
      expect(find.text('Gender *'), findsOneWidget);
      expect(find.text('Blood Group'), findsOneWidget);
      expect(find.text('Child Form-B / CRC No'), findsOneWidget);
      expect(find.text('Nationality'), findsOneWidget);
      expect(find.text('Religion / Community'), findsOneWidget);

      // Check Photo Dropzone
      expect(find.text('Click to choose photo'), findsOneWidget);
      expect(find.text('Choose Photo'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);
    });

    testWidgets(
      '2. Empty NameFirst -> advance -> shows "Enter Fisrt Name Please "',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWizard());
        await tester.pumpAndSettle();

        // Click Save & Continue without NameFirst
        await tester.tap(find.text('Save & Continue'));
        await tester.pumpAndSettle();

        // Exact verbatim typo check
        expect(find.text('Enter Fisrt Name Please '), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('3. Fill NameFirst + DOB -> advance to Step 2', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWizard());
      await tester.pumpAndSettle();

      // Fill First Name
      final firstNameField = find.widgetWithText(
        TextField,
        'Enter student first given name',
      );
      await tester.enterText(firstNameField, 'Muhammad');

      // Click Save & Continue -> should fail on Date of Birth
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Date of Birth Please '), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      // Dismiss SnackBar and pick Date of Birth programmatically via draft
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudentRegistrationWizard)),
      );
      container
          .read(wizardDraftProvider.notifier)
          .setDob(DateTime(2005, 5, 20));
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      // Verify Step 2 is active
      expect(find.text('Step 2 of 4: Guardian & Family'), findsOneWidget);
      expect(find.text('Father / Guardian Name *'), findsOneWidget);
      expect(find.text('Father CNIC *'), findsOneWidget);
    });

    testWidgets(
      '4. Enter father CNIC 38302-4567890-4 -> sibling panel appears with 2 students (4414, 4415)',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWizard());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(StudentRegistrationWizard)),
        );
        // Fill Step 1
        container.read(wizardDraftProvider.notifier).setNameFirst('Ahmad');
        container
            .read(wizardDraftProvider.notifier)
            .setDob(DateTime(2006, 8, 14));
        container.read(wizardStepProvider.notifier).state = 1;
        await tester.pumpAndSettle();

        expect(find.text('Step 2 of 4: Guardian & Family'), findsOneWidget);

        // Enter Father CNIC for Tariq Mehmood (father of seeded students 4414 & 4415)
        final cnicField = find.widgetWithText(TextField, 'XXXXX-XXXXXXX-X');
        await tester.enterText(cnicField, '38302-4567890-4');

        // Wait for debounce timer (300ms)
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Verify sibling panel appears
        expect(
          find.text('2 Existing Siblings Found Under This Father CNIC'),
          findsOneWidget,
        );
        expect(find.text('(Reg #4414)'), findsOneWidget);
        expect(find.text('(Reg #4415)'), findsOneWidget);
        expect(find.text('Fatima Zahra'), findsOneWidget);
        expect(find.text('Usman Tariq'), findsOneWidget);
      },
    );

    testWidgets('5. Fill Step 2 -> advance to Step 3', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWizard());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudentRegistrationWizard)),
      );
      // Pre-set Step 1 and move to Step 2
      container.read(wizardDraftProvider.notifier).setNameFirst('Ahmad');
      container
          .read(wizardDraftProvider.notifier)
          .setDob(DateTime(2006, 8, 14));
      container.read(wizardStepProvider.notifier).state = 1;
      await tester.pumpAndSettle();

      // Click advance without CNIC -> error
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Father CNIC Please '), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      // Fill CNIC but leave Father Name empty -> error
      container.read(wizardDraftProvider.notifier).setCnicNo('38302-1111111-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Father / Guradian Name Please '), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      // Fill Father Name
      container.read(wizardDraftProvider.notifier).setFName('Rashid Khan');
      await tester.pumpAndSettle();

      // Advance to Step 3
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 4: Contact & Address'), findsOneWidget);
      expect(find.text('Mobile 1 * (SMS notifications)'), findsOneWidget);
      expect(find.text('Permanent Address'), findsOneWidget);
    });

    testWidgets('6. Fill Step 3 -> advance to Step 4', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWizard());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudentRegistrationWizard)),
      );
      container.read(wizardDraftProvider.notifier).setNameFirst('Ahmad');
      container
          .read(wizardDraftProvider.notifier)
          .setDob(DateTime(2006, 8, 14));
      container.read(wizardDraftProvider.notifier).setCnicNo('38302-1111111-1');
      container.read(wizardDraftProvider.notifier).setFName('Rashid Khan');
      container.read(wizardStepProvider.notifier).state = 2;
      await tester.pumpAndSettle();

      // Click advance without Mobile 1 -> error
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Mobile # 1  Please '), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      // Fill Mobile 1
      final mobile1Field = find.widgetWithText(TextField, '0300-1234567');
      await tester.enterText(mobile1Field, '0300-9876543');
      await tester.pumpAndSettle();

      // Advance to Step 4
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 4 of 4: Academic Placement'), findsOneWidget);
      expect(find.text('Admission In Class *'), findsOneWidget);
      expect(find.text('Assigned Section *'), findsOneWidget);
      expect(find.text('Complete Admission'), findsOneWidget);
    });

    testWidgets(
      '7. Without AdmInClass -> Complete Admission -> shows "Select Admission In Class  Please "',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWizard());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(StudentRegistrationWizard)),
        );
        container.read(wizardDraftProvider.notifier).setNameFirst('Ahmad');
        container
            .read(wizardDraftProvider.notifier)
            .setDob(DateTime(2006, 8, 14));
        container
            .read(wizardDraftProvider.notifier)
            .setCnicNo('38302-1111111-1');
        container.read(wizardDraftProvider.notifier).setFName('Rashid Khan');
        container.read(wizardDraftProvider.notifier).setMobile1('0300-9876543');
        container.read(wizardStepProvider.notifier).state = 3;
        await tester.pumpAndSettle();

        // Attempt Complete Admission without selecting Class
        await tester.tap(find.text('Complete Admission'));
        await tester.pumpAndSettle();

        expect(find.text('Select Admission In Class  Please '), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('8. Complete Admission -> navigates to /students/4421', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWizard());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudentRegistrationWizard)),
      );
      container.read(wizardDraftProvider.notifier).setNameFirst('Ahmad');
      container.read(wizardDraftProvider.notifier).setNameLast('Rashid');
      container
          .read(wizardDraftProvider.notifier)
          .setDob(DateTime(2006, 8, 14));
      container.read(wizardDraftProvider.notifier).setCnicNo('38302-1111111-1');
      container.read(wizardDraftProvider.notifier).setFName('Rashid Khan');
      container.read(wizardDraftProvider.notifier).setMobile1('0300-9876543');
      container
          .read(wizardDraftProvider.notifier)
          .setAdmInClass(13); // Class 10
      container
          .read(wizardDraftProvider.notifier)
          .setClassSecId(25); // Section A
      container.read(wizardStepProvider.notifier).state = 3;
      await tester.pumpAndSettle();

      // Submit Complete Admission
      await tester.tap(find.text('Complete Admission'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify Navigation to /students/4421
      expect(find.text('Student Profile Screen 4421'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    test(
      '9. SQLite integration: sibling discovery raw query on seeded database',
      () async {
        final rows = await db.rawQuery(
          '''
        SELECT 
          sr.Stu_RegID,
          sr.NameFirst,
          sr.NameLast,
          sr.F_Name,
          sr.CNIC_No,
          c.CName as class_name,
          cs.SecName as section_name,
          sc.ClassRollNo
        FROM Stu_Reg sr
        LEFT JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID
        LEFT JOIN Class c ON sc.ClassID = c.ClassID
        LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
        WHERE sr.CNIC_No = ?
        GROUP BY sr.Stu_RegID
        ORDER BY sr.Stu_RegID ASC
        ''',
          ['38302-4567890-4'],
        );

        expect(rows.length, 2);
        expect(rows[0]['Stu_RegID'], 4414);
        expect(rows[0]['NameFirst'], 'Fatima');
        expect(rows[0]['NameLast'], 'Zahra');
        expect(rows[0]['F_Name'], 'Tariq Mehmood');

        expect(rows[1]['Stu_RegID'], 4415);
        expect(rows[1]['NameFirst'], 'Usman');
        expect(rows[1]['NameLast'], 'Tariq');
        expect(rows[1]['F_Name'], 'Tariq Mehmood');
      },
    );

    test('10. SQLite integration: submitStudentAdmission creates Stu_Reg & Student_Class with NodeIdAllocator block (400000)', () async {
      await db.rawUpdate(
        "UPDATE _sync_state SET node_block_start = 400000, "
        "node_block_end = 499999, next_allocated_id = 400000 "
        "WHERE table_name = '__node__'",
      );

      final draft = WizardDraft()
        ..nameFirst = 'Ahmad'
        ..nameLast = 'Rashid'
        ..dob = DateTime(2006, 8, 14)
        ..cnicNo = '38302-1111111-1'
        ..fName = 'Rashid Khan'
        ..mobile1 = '0300-9876543'
        ..admInClass = 13
        ..classSecId = 25
        ..remarks = 'Admitted under general merit.';

      final newId = await submitStudentAdmission(draft);
      expect(newId, 400000);

      // Verify Stu_Reg row (including verbatim typo Remarls)
      final studentRows = await db.query(
        'Stu_Reg',
        where: 'Stu_RegID = ?',
        whereArgs: [400000],
      );
      expect(studentRows.length, 1);
      final student = studentRows.first;
      expect(student['NameFirst'], 'Ahmad');
      expect(student['NameLast'], 'Rashid');
      expect(student['F_Name'], 'Rashid Khan');
      expect(student['CNIC_No'], '38302-1111111-1');
      expect(student['Mobile1'], '0300-9876543');
      expect(student['AdmInClass'], 13);
      expect(student['Remarls'], 'Admitted under general merit.');

      // Verify Student_Class row (Roll 11, Session 2017-2018, VGen Y, Present 1)
      final classRows = await db.query(
        'Student_Class',
        where: 'Stu_RegID = ?',
        whereArgs: [400000],
      );
      expect(classRows.length, 1);
      final enrollment = classRows.first;
      expect(enrollment['ClassID'], 13);
      expect(enrollment['ClassSecID'], 25);
      expect(enrollment['ClassRollNo'], 11);
      expect(enrollment['SessionYr'], '2017-2018');
      expect(enrollment['Present'], 1);
      expect(enrollment['VGen'], 'Y');
    });
  });
}
