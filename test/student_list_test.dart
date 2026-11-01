import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/student_list_row.dart';
import 'package:school_automation/screens/students/student_list_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('StudentListScreen UI & Live Data Integration Tests', () {
    const seededRows = [
      StudentListRow(
        stuRegId: 4411,
        fullName: 'Muhammad Ali Khan',
        fatherName: 'Khan Muhammad',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 1,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4412,
        fullName: 'Zainab Ahmed',
        fatherName: 'Ahmed Hassan',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 2,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4413,
        fullName: 'Bilal Hussain',
        fatherName: 'Hussain Shah',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 3,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4414,
        fullName: 'Fatima Zahra',
        fatherName: 'Tariq Mehmood',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 4,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4415,
        fullName: 'Usman Tariq',
        fatherName: 'Tariq Mehmood',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 5,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4416,
        fullName: 'Hamza Nadeem',
        fatherName: 'Nadeem Akhtar',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 6,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4417,
        fullName: 'Ayesha Ramzan',
        fatherName: 'Muhammad Ramzan',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 7,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4418,
        fullName: 'Ahmed Raza',
        fatherName: 'Farooq Raza',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 8,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4419,
        fullName: 'Sana Iqbal',
        fatherName: 'Iqbal Hussain',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 9,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
      StudentListRow(
        stuRegId: 4420,
        fullName: 'Hassan Akbar',
        fatherName: 'Akbar Shah',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 10,
        status: 'Active',
        sessionYr: '2017-2018',
      ),
    ];

    const seededClasses = [
      SchoolClass(classId: 1, cName: 'Play Group'),
      SchoolClass(classId: 13, cName: 'Class 10'),
    ];

    const seededSections = [
      ClassSec(classSecId: 25, classId: 13, secName: 'A'),
      ClassSec(classSecId: 26, classId: 13, secName: 'B'),
    ];

    Widget createTestApp({
      List<StudentListRow> students = seededRows,
      List<SchoolClass> classes = seededClasses,
      List<ClassSec> sections = seededSections,
    }) {
      final router = GoRouter(
        initialLocation: '/students',
        routes: [
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) =>
                    const Scaffold(body: Text('New Student Wizard Screen')),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => Scaffold(
                  body: Text('Student Profile ${state.pathParameters['id']}'),
                ),
              ),
            ],
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          studentListProvider.overrideWith((ref) {
            final filters = ref.watch(studentListFiltersProvider);

            // Filter the test dataset in memory matching SQLite behavior
            var list = List<StudentListRow>.from(students);

            if (filters.search.isNotEmpty) {
              final q = filters.search.toLowerCase();
              list = list.where((s) {
                return s.fullName.toLowerCase().contains(q) ||
                    '${s.stuRegId}'.contains(q) ||
                    (s.fatherName?.toLowerCase().contains(q) ?? false);
              }).toList();
            }

            if (filters.classId != null) {
              // 13 = Class 10
              if (filters.classId == 13) {
                list = list.where((s) => s.className == 'Class 10').toList();
              } else {
                list = [];
              }
            }

            if (filters.status != 'All') {
              list = list.where((s) => s.status == filters.status).toList();
            }

            return Future.value(list);
          }),
          classesProvider.overrideWith((ref) => Future.value(classes)),
          sectionsProvider.overrideWith((ref) => Future.value(sections)),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('Renders 10 rows from seeded Stu_Reg and pagination', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header and badge
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('10 Active Students'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('+ New Student (Ctrl+N)'), findsOneWidget);

      // Verify all 10 students rendered
      expect(find.text('Muhammad Ali Khan'), findsOneWidget);
      expect(find.text('Zainab Ahmed'), findsOneWidget);
      expect(find.text('Bilal Hussain'), findsOneWidget);
      expect(find.text('Fatima Zahra'), findsOneWidget);
      expect(find.text('Usman Tariq'), findsOneWidget);
      expect(find.text('Hamza Nadeem'), findsOneWidget);
      expect(find.text('Ayesha Ramzan'), findsOneWidget);
      expect(find.text('Ahmed Raza'), findsOneWidget);
      expect(find.text('Sana Iqbal'), findsOneWidget);
      expect(find.text('Hassan Akbar'), findsOneWidget);

      // Plain integer reg IDs (without # prefix)
      expect(find.text('4411'), findsOneWidget);
      expect(find.text('4420'), findsOneWidget);

      // Pagination
      expect(find.text('Showing 1-10 of 10 students'), findsOneWidget);
    });

    testWidgets('Search "Muhammad" filters to matching rows', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Muhammad');
      // Wait for debounce timer (300ms)
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Matches Muhammad Ali Khan and Ayesha Ramzan (father: Muhammad Ramzan)
      expect(find.text('Muhammad Ali Khan'), findsOneWidget);
      expect(find.text('Ayesha Ramzan'), findsOneWidget);
      expect(find.text('Zainab Ahmed'), findsNothing);
      expect(find.text('Showing 1-2 of 2 students'), findsOneWidget);
    });

    testWidgets('Class filter = Class 10 shows only Class 10 students', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Class dropdown
      await tester.tap(find.text('All Classes'));
      await tester.pumpAndSettle();

      // Select Class 10
      await tester.tap(find.text('Class 10').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Still has 10 students
      expect(find.text('Muhammad Ali Khan'), findsOneWidget);
      expect(find.text('Showing 1-10 of 10 students'), findsOneWidget);
    });

    testWidgets('Status = All shows all 10 students', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Status dropdown
      await tester.tap(find.text('Active').first);
      await tester.pumpAndSettle();

      // Select 'All'
      await tester.tap(find.text('All').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('10 Total Students'), findsOneWidget);
      expect(find.text('Showing 1-10 of 10 students'), findsOneWidget);
    });

    testWidgets('Empty state renders when filter returns 0 matches', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Search non-existent query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'zzzzz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Empty state verification
      expect(find.text('No Student Found'), findsOneWidget);
      expect(
        find.text(
          'No students match your active search or filter criteria. Check your spelling or reset filters to see the full directory.',
        ),
        findsOneWidget,
      );
      expect(find.text('Showing 0-0 of 0 students'), findsOneWidget);
    });

    testWidgets('Click row or "View →" navigates to /students/4411', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "View →" on the first student row (4411)
      await tester.tap(find.text('View →').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Student Profile 4411'), findsOneWidget);
    });

    test(
      'SQLite queries produce exact student rows and filter results',
      () async {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys = ON');
            },
          ),
        );
        await SchemaMigrations.migrate(db);
        await DatabaseSeeder.seedIfEmpty(db);

        // 1. All students in Session 2017-2018
        final allRows = await db.rawQuery('''
        SELECT
          sr.Stu_RegID,
          sr.NameFirst,
          sr.NameLast,
          sr.F_Name,
          sr.photo_path,
          c.CName as class_name,
          cs.SecName as section_name,
          sc.ClassRollNo,
          sc.SessionYr,
          CASE
            WHEN sl.StuRegID IS NOT NULL THEN 'Left'
            ELSE 'Active'
          END as status
        FROM Stu_Reg sr
        JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID
        JOIN Class c ON sc.ClassID = c.ClassID
        LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
        LEFT JOIN SchLeaving sl ON sr.Stu_RegID = sl.StuRegID
        WHERE sc.SessionYr = '2017-2018'
        ORDER BY c.ClassID ASC, cs.SecName ASC, sc.ClassRollNo ASC
      ''');
        expect(allRows.length, 10);
        expect(allRows.first['Stu_RegID'], 4411);
        expect(allRows.first['NameFirst'], 'Muhammad Ali');
        expect(allRows.first['NameLast'], 'Khan');
        expect(allRows.first['class_name'], 'Class 10');
        expect(allRows.first['section_name'], 'A');
        expect(allRows.first['ClassRollNo'], 1);
        expect(allRows.first['status'], 'Active');

        // 2. Search query test for "Muhammad"
        final searchRows = await db.rawQuery('''
        SELECT sr.Stu_RegID, sr.NameFirst, sr.NameLast
        FROM Stu_Reg sr
        JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID
        WHERE sc.SessionYr = '2017-2018'
          AND (LOWER(sr.NameFirst || ' ' || COALESCE(sr.NameLast, '')) LIKE '%muhammad%'
               OR CAST(sr.Stu_RegID AS TEXT) LIKE '%muhammad%'
               OR LOWER(COALESCE(sr.F_Name, '')) LIKE '%muhammad%')
      ''');
        expect(searchRows.length, 2);

        // 3. Class filter for ClassID 13 (Class 10)
        final class10Rows = await db.rawQuery('''
        SELECT sr.Stu_RegID
        FROM Stu_Reg sr
        JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID
        WHERE sc.SessionYr = '2017-2018' AND sc.ClassID = 13
      ''');
        expect(class10Rows.length, 10);

        // 4. Class filter for ClassID 1 (Play Group) -> 0 rows
        final playGroupRows = await db.rawQuery('''
        SELECT sr.Stu_RegID
        FROM Stu_Reg sr
        JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID
        WHERE sc.SessionYr = '2017-2018' AND sc.ClassID = 1
      ''');
        expect(playGroupRows.length, 0);

        await db.close();
      },
    );
  });
}
