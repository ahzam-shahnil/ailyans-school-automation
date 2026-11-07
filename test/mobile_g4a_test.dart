// Phase G / G-4a — mobile attendance roster cards, mobile student list cards,
// and a horizontally scrollable student profile tab bar at 390x844.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/attendance_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/student_profile_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/student.dart';
import 'package:school_automation/models/student_list_row.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/attendance/attendance_screen.dart';
import 'package:school_automation/screens/students/student_list_screen.dart';
import 'package:school_automation/screens/students/student_profile_screen.dart';
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
    await DatabaseSeeder.seedFeeTariffsIfEmpty(db);
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  const testUser = User(
    id: 1,
    name: 'Administrator',
    designation: 'Principal',
    password: 'securepassword123',
    userLevel: 1,
    isActive: true,
  );

  const testMetadata = ShellMetadata(
    branchName: "Ailyan's Higher Secondary School Mianwali",
    branchAddress: 'Muslim Bazar Mianwali',
    branchPhone: '0459-234567',
    branchPrincipal: 'Prof. Muhammad Tariq',
    sessionYear: '2017-2018',
    studentCount: 10,
    classCount: 1,
    staffCount: 5,
    pendingVouchers: 2,
  );

  testWidgets(
    'AttendanceScreen at 390x844 renders mobile student attendance cards '
    'with Present/Absent/Leave buttons and zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.setSession(testUser, const [2, 28]);
            return notifier;
          }),
          shellMetadataProvider.overrideWith(
            (ref) => Future.value(testMetadata),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(attendanceProvider.notifier);
      await tester.runAsync(() async {
        await notifier.loadClasses();
        await notifier.loadTeachers();
        await notifier.loadSectionsForClass(13);
        await notifier.selectSection(25);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: AttendanceScreen())),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Present'), findsWidgets);
      expect(find.text('Absent'), findsWidgets);
      expect(find.text('Leave'), findsWidgets);
    },
  );

  testWidgets(
    'StudentListScreen at 390x844 renders mobile student cards and zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      ];

      const seededClasses = [
        SchoolClass(classId: 1, cName: 'Play Group'),
        SchoolClass(classId: 13, cName: 'Class 10'),
      ];

      const seededSections = [
        ClassSec(classSecId: 25, classId: 13, secName: 'A'),
        ClassSec(classSecId: 26, classId: 13, secName: 'B'),
      ];

      final router = GoRouter(
        initialLocation: '/students',
        routes: [
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentListScreen(),
            routes: [
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentListProvider.overrideWith((ref) => Future.value(seededRows)),
            classesProvider.overrideWith((ref) => Future.value(seededClasses)),
            sectionsProvider.overrideWith(
              (ref) => Future.value(seededSections),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(DataTable), findsNothing);
    },
  );

  testWidgets(
    'StudentProfileScreen at 390x844 renders horizontally scrollable tab bar '
    'and zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      final testBundle = StudentProfileBundle(
        student: testStudent,
        enrollments: const [],
        vouchers: const [],
        totalBilled: 0,
        totalPaid: 0,
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentProfileProvider(4411).overrideWith((ref) => testBundle),
            classesProvider.overrideWith(
              (ref) => [const SchoolClass(classId: 13, cName: 'Class 10')],
            ),
            studentProfileSaverProvider.overrideWithValue((student) async {}),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudentProfileScreen(studentId: '4411')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    },
  );
}
