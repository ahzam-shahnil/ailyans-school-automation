import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/student_profile_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/student.dart';
import 'package:school_automation/models/student_enrollment.dart';
import 'package:school_automation/models/student_voucher.dart';
import 'package:school_automation/screens/students/student_profile_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('StudentProfileScreen UI & Behavior Tests', () {
    final testStudent = Student(
      stuRegId: 4411,
      nameFirst: 'Muhammad',
      nameMiddle: 'Ali',
      nameLast: 'Khan',
      dob: DateTime(2002, 4, 12),
      bFormNo: '38302-9988112-5',
      fName: 'Khan Muhammad',
      cnicNo: '38302-1234567-1',
      occupation: 'Civil Engineer',
      pAddress: 'House 14, Street 2, Civil Lines, Mianwali',
      tAddress: 'Same as permanent',
      mobile1: '0300-1234567',
      mobile2: '0321-7654321',
      religion: 'Islam',
      pSchool: 'Govt High School Kundian',
      pClass: 'Class 9',
      slCertificate: 'SLC-9921',
      admInClass: 13,
      admClass: 13,
      doAdmission: DateTime(2024, 8, 15),
      discount: 0.0,
      vmDiscount: 0,
      fullDiscount: 0,
      emerContName: 'Tariq Mehmood',
      emerContMobile: '0345-7654321',
      remarls: 'Admitted on transfer merit.',
      nationality: 'Pakistani',
      sex: 'Male',
    );

    final testEnrollments = [
      const StudentEnrollment(
        stuRegId: 4411,
        classId: 13,
        classSecId: 25,
        classRollNo: 1,
        sessionYr: '2017-2018',
        present: 1,
        vGen: 'Y',
        className: 'Class 10',
        sectionName: 'A',
      ),
    ];

    final testVouchers = [
      StudentVoucher(
        voucherMasId: '1710-4411',
        vDate: DateTime(2017, 10, 1),
        forMonth: 'October 2017',
        subtotal: 1800,
        discount: 0,
        paidAmount: 1800,
        paidDate: DateTime(2017, 10, 20),
        isPaid: 'Y',
        dueDate: DateTime(2017, 10, 10),
      ),
      StudentVoucher(
        voucherMasId: '1709-4411',
        vDate: DateTime(2017, 9, 1),
        forMonth: 'September 2017',
        subtotal: 1800,
        discount: 0,
        paidAmount: null,
        paidDate: null,
        isPaid: 'N',
        dueDate: DateTime(2017, 9, 10),
      ),
    ];

    final testBundle = StudentProfileBundle(
      student: testStudent,
      enrollments: testEnrollments,
      vouchers: testVouchers,
      totalBilled: 3600,
      totalPaid: 1800,
      outstandingArrears: 1800,
      classRollNo: 1,
      currentClassName: 'Class 10',
      currentSectionName: 'A',
      fatherName: 'Khan Muhammad',
      mobile1: '0300-1234567',
      feeBalanceSummary: 'Rs. 1,800 outstanding',
      advances: const [],
      exams: const [],
      attendance: const [
        {'AttStatus': 'Present', 'AttDate': '2026-10-21 08:00:00'},
      ],
    );

    Widget buildTestScreen({
      String studentId = '4411',
      StudentProfileBundle? bundle,
      Object? error,
    }) {
      return ProviderScope(
        overrides: [
          studentProfileProvider(int.parse(studentId)).overrideWith((ref) {
            if (error != null) throw error;
            return bundle ?? testBundle;
          }),
          classesProvider.overrideWith(
            (ref) => [
              const SchoolClass(classId: 13, cName: 'Class 10'),
              const SchoolClass(classId: 12, cName: 'Class 9'),
            ],
          ),
          studentProfileSaverProvider.overrideWithValue((student) async {}),
        ],
        child: MaterialApp(
          home: Scaffold(body: StudentProfileScreen(studentId: studentId)),
        ),
      );
    }

    testWidgets('1. Renders header with student name, reg ID, class badge', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Muhammad Ali Khan'), findsOneWidget);
      expect(find.text('#4411'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(
        find.textContaining('Class Class 10-A  •  Roll: 1'),
        findsOneWidget,
      );
      expect(find.textContaining('Father: Khan Muhammad'), findsOneWidget);
      expect(find.text('Rs. 1,800 outstanding'), findsOneWidget);
      expect(find.text('Edit Profile (F2)'), findsWidgets);
    });

    testWidgets('2. Overview tab shows all 4 sections in view mode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('1. Personal & Identity Details'), findsOneWidget);
      expect(find.text('2. Guardian & Family Details'), findsOneWidget);
      expect(
        find.text('3. Contact Channels & Residential Address'),
        findsOneWidget,
      );
      expect(
        find.text('4. Academic Placement & Fee Concessions'),
        findsOneWidget,
      );

      // Verify specific field values
      expect(find.text('12-Apr-2002'), findsOneWidget);
      expect(find.text('38302-1234567-1'), findsOneWidget);
      expect(find.text('0300-1234567'), findsWidgets);
      expect(
        find.text('House 14, Street 2, Civil Lines, Mianwali'),
        findsOneWidget,
      );
    });

    testWidgets('3. Click Edit Profile -> all fields become editable', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Click Edit Profile (F2)
      await tester.tap(find.text('Edit Profile (F2)').first);
      await tester.pumpAndSettle();

      expect(find.text('[Editing Active - Unsaved Changes]'), findsOneWidget);
      expect(find.text('Save Profile Changes (Ctrl+S)'), findsOneWidget);
      expect(find.text('Cancel Changes (Esc)'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets(
      '4. Empty NameFirst + save -> shows verbatim "Enter Fisrt Name Please "',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1300, 900));
        await tester.pumpWidget(buildTestScreen());
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.text('Edit Profile (F2)').first);
        await tester.pumpAndSettle();

        // Clear First Name field
        final firstNameFinder = find.widgetWithText(TextFormField, 'Muhammad');
        await tester.enterText(firstNameFinder, '');
        await tester.pumpAndSettle();

        // Click Save
        await tester.tap(find.text('Save Profile Changes (Ctrl+S)'));
        await tester.pumpAndSettle();

        // Expect verbatim typo "Enter Fisrt Name Please "
        expect(find.textContaining('Enter Fisrt Name Please '), findsWidgets);
      },
    );

    testWidgets(
      '5. Save with valid data -> success, exits edit mode & shows "Student Saved Successfully"',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1300, 900));
        await tester.pumpWidget(buildTestScreen());
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.text('Edit Profile (F2)').first);
        await tester.pumpAndSettle();

        // Middle name is empty/cleared (verifying NameMiddle is optional and not validated)
        final middleNameFinder = find.widgetWithText(TextFormField, 'Ali');
        await tester.enterText(middleNameFinder, '');
        await tester.pumpAndSettle();

        // Click Save with valid fields
        await tester.tap(find.text('Save Profile Changes (Ctrl+S)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Student Saved Successfully'), findsOneWidget);
      },
    );

    testWidgets('6. Tab switching works (Overview -> Fee Ledger -> back)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Click Fee Ledger tab
      await tester.tap(find.text('Fee Ledger'));
      await tester.pumpAndSettle();

      expect(
        find.text('OFFICIAL VOUCHER ISSUANCE & PAYMENT LEDGER'),
        findsOneWidget,
      );

      // Click back to Overview tab
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      expect(find.text('1. Personal & Identity Details'), findsOneWidget);
    });

    testWidgets('7. Fee Ledger shows 3 KPI cards + voucher table', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Switch to Fee Ledger
      await tester.tap(find.text('Fee Ledger'));
      await tester.pumpAndSettle();

      // Check 3 KPI cards
      expect(find.text('TOTAL BILLED (2017-2018 SESSION)'), findsOneWidget);
      expect(find.text('Rs. 3,600'), findsOneWidget);
      expect(find.text('TOTAL PAID TO DATE'), findsOneWidget);
      expect(find.text('OUTSTANDING ARREARS'), findsOneWidget);
      expect(find.text('Rs. 1,800'), findsWidgets);
      expect(find.text('50% Realization Rate'), findsOneWidget);

      // Check Voucher Table
      expect(find.text('1710-4411'), findsOneWidget);
      expect(find.text('October 2017'), findsOneWidget);
      expect(find.text('1709-4411'), findsOneWidget);
      expect(find.text('September 2017'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets(
      '8. Navigate to /students/4411 via GoRouter -> correct student loaded',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1300, 900));

        final testRouter = GoRouter(
          initialLocation: '/students/4411',
          routes: [
            GoRoute(
              path: '/students/:id',
              builder: (context, state) {
                return StudentProfileScreen(
                  studentId: state.pathParameters['id'] ?? '',
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studentProfileProvider(4411).overrideWith((ref) => testBundle),
              classesProvider.overrideWith(
                (ref) => [const SchoolClass(classId: 13, cName: 'Class 10')],
              ),
            ],
            child: MaterialApp.router(routerConfig: testRouter),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Muhammad Ali Khan'), findsOneWidget);
        expect(find.text('#4411'), findsOneWidget);
      },
    );

    testWidgets(
      '9. Navigate to /students/9999 (nonexistent) -> shows "Student not found" error state',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1300, 900));
        await tester.pumpWidget(
          buildTestScreen(
            studentId: '9999',
            error: Exception('Student not found'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Student not found'), findsOneWidget);
        expect(
          find.text('No student record exists with Registration ID #9999.'),
          findsOneWidget,
        );
        expect(find.text('Back to Students'), findsOneWidget);
      },
    );

    test(
      '10. SQLite live integration: queries produce exact StudentProfileBundle',
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

        // Query student 4411
        final studentRows = await db.query(
          'Stu_Reg',
          where: 'Stu_RegID = ?',
          whereArgs: [4411],
        );
        expect(studentRows.length, 1);
        final student = Student.fromMap(studentRows.first);
        expect(student.stuRegId, 4411);
        expect(student.nameFirst, 'Muhammad Ali');
        expect(student.nameLast, 'Khan');
        expect(student.fName, 'Khan Muhammad');

        // Query enrollments
        final enrollmentRows = await db.rawQuery('''
        SELECT sc.*, c.CName, cs.SecName 
        FROM Student_Class sc
        JOIN Class c ON sc.ClassID = c.ClassID
        LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
        WHERE sc.Stu_RegID = 4411
        ORDER BY sc.SessionYr DESC
      ''');
        expect(enrollmentRows.length, 1);
        expect(enrollmentRows.first['CName'], 'Class 10');
        expect(enrollmentRows.first['SecName'], 'A');
        expect(enrollmentRows.first['ClassRollNo'], 1);

        // Query vouchers
        final voucherRows = await db.rawQuery('''
        SELECT vm.VoucherMasID, vm.VDate, vm.SubTotal, vm.ForMonth, vm.IsPaid,
               ft.PaidAmount, ft.SubmissionDate
        FROM VoucharMas vm
        LEFT JOIN FeeTransaction ft ON vm.VoucherMasID = ft.VoucharNo
        WHERE vm.Student_Class_StuRegID = 4411
        ORDER BY vm.VDate DESC
      ''');
        expect(voucherRows.length, 2);
        expect(voucherRows.first['VoucherMasID'], '1710-4411');
        expect(voucherRows.first['IsPaid'], 'Y');
        expect(voucherRows.first['PaidAmount'], 1800);

        await db.close();
      },
    );
  });
}
