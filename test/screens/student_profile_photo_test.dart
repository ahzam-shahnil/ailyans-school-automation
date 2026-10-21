import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
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

  late Database db;

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
    photoPath: null,
  );

  final testBundle = StudentProfileBundle(
    student: testStudent,
    enrollments: const [
      StudentEnrollment(
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
    ],
    vouchers: [
      StudentVoucher(
        voucherMasId: '1710-4411',
        vDate: DateTime(2017, 10, 1),
        forMonth: 'October 2017',
        subtotal: 1800,
        discount: 0,
        paidAmount: 1800,
        paidDate: DateTime(2017, 10, 5),
        isPaid: 'Y',
        dueDate: DateTime(2017, 10, 10),
      ),
    ],
    totalBilled: 1800,
    totalPaid: 1800,
    outstandingArrears: 0,
    classRollNo: 1,
    currentClassName: 'Class 10',
    currentSectionName: 'A',
    fatherName: 'Khan Muhammad',
    mobile1: '0300-1234567',
    feeBalanceSummary: 'Rs. 0 outstanding',
    advances: const [],
    exams: const [],
    attendance: const [],
  );

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

  Widget buildTestScreen() {
    return ProviderScope(
      overrides: [
        studentProfileProvider(4411).overrideWith((ref) => testBundle),
        classesProvider.overrideWith(
          (ref) => [
            const SchoolClass(classId: 13, cName: 'Class 10'),
            const SchoolClass(classId: 12, cName: 'Class 9'),
          ],
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: StudentProfileScreen(studentId: '4411')),
      ),
    );
  }

  group('StudentProfilePhoto Tests', () {
    testWidgets('1. Avatar is wrapped in an InkWell with tooltip hint', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Find initials avatar
      expect(find.text('MK'), findsOneWidget);

      // Verify Tooltip wraps avatar with message "Click to change photo"
      final tooltipFinder = find.widgetWithText(Tooltip, 'MK');
      expect(tooltipFinder, findsOneWidget);
      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, 'Click to change photo');

      // Verify InkWell wraps the avatar
      final inkWellFinder = find.ancestor(
        of: find.text('MK'),
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsOneWidget);
      final inkWell = tester.widget<InkWell>(inkWellFinder);
      expect(inkWell.onTap, isNotNull);
      expect(inkWell.borderRadius, BorderRadius.circular(8));
    });

    test(
      '2. saveStudentProfile updates photoPath in SQLite persistence',
      () async {
        const newPhoto = '/Users/test/Documents/Ailyans/photos/4411.jpg';
        final updated = testStudent.copyWith(photoPath: newPhoto);

        await saveStudentProfile(updated);

        final rows = await db.query(
          'Stu_Reg',
          columns: ['Stu_RegID', 'photo_path'],
          where: 'Stu_RegID = ?',
          whereArgs: [4411],
        );
        expect(rows.length, 1);
        expect(rows.first['photo_path'], newPhoto);
      },
    );
  });
}
