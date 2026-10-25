import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/bulk_enrollment_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/students/bulk_enrollment_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

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

    // Seed student 4421 into Class 5 (ClassID 8) for Session 2017-2018 per schema facts
    await db.rawInsert('''
      INSERT INTO Stu_Reg (Stu_RegID, NameFirst, NameLast, F_Name, DOAdmission, FullDiscount)
      VALUES (4421, 'Rashid', 'Minhas', 'Minhas Khan', '2017-08-01', 0)
    ''');
    await db.rawInsert('''
      INSERT INTO Student_Class (Stu_RegID, ClassID, ClassSecID, ClassRollNo, SessionYr, Present, VGen)
      VALUES (4421, 8, 15, 1, '2017-2018', 1, 'Y')
    ''');

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('BulkEnrollmentScreen Provider & Logic Tests', () {
    test('a) loads classes, sections, sessions on mount', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final classes = await container.read(classesProvider.future);
      final sections = await container.read(sectionsProvider.future);
      final state = container.read(bulkEnrollmentProvider);

      expect(classes, isNotEmpty);
      expect(classes.any((c) => c.cName == 'Class 10'), isTrue);
      expect(sections, isNotEmpty);
      expect(state.availableSessions, contains('2017-2018'));
      expect(state.selectedSessionYr, '2017-2018');
    });

    test(
      'b) loading roster for Class 10 / Sec A / 2017-2018 shows 10 students',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(bulkEnrollmentProvider.notifier);
        notifier.setClassId(13); // Class 10
        notifier.setSecId(25); // Sec A
        notifier.setSessionYr('2017-2018');

        final (ok, _) = await notifier.loadRoster();
        expect(ok, isTrue);

        final state = container.read(bulkEnrollmentProvider);
        expect(state.isRosterLoaded, isTrue);
        expect(state.roster.length, 10);
        expect(state.roster.first.stuRegId, 4411);
        expect(state.roster.first.classRollNo, 1);
      },
    );

    test('c) empty state before Load Roster (hasLoadedRoster=false)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(bulkEnrollmentProvider);
      expect(state.isRosterLoaded, isFalse);
      expect(state.roster, isEmpty);
    });

    test('d) after Load Roster with 0 students, correct empty-state text shows (hasLoadedRoster=true, roster empty)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bulkEnrollmentProvider.notifier);
      // Play Group (ClassID 1) Section A (ClassSecID 1) has 0 students in seed
      notifier.setClassId(1);
      notifier.setSecId(1);
      notifier.setSessionYr('2017-2018');

      final (ok, _) = await notifier.loadRoster();
      expect(ok, isTrue);

      final state = container.read(bulkEnrollmentProvider);
      expect(state.isRosterLoaded, isTrue);
      expect(state.roster, isEmpty);
    });

    test(
      'e) enroll new student inserts into Student_Class with MAX+1 roll',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Insert dummy student in Stu_Reg
        await db.rawInsert('''
        INSERT INTO Stu_Reg (Stu_RegID, NameFirst, NameLast, F_Name, DOAdmission, FullDiscount)
        VALUES (9999, 'TestFirst', 'TestLast', 'FatherName', '2017-08-01', 0)
      ''');

        final notifier = container.read(bulkEnrollmentProvider.notifier);
        notifier.setClassId(13);
        notifier.setSecId(25);
        notifier.setSessionYr('2017-2018');
        await notifier.loadRoster();

        final (ok, msg) = await notifier.enrollStudent(
          regIdText: '9999',
          rollNoText: '11',
        );

        expect(ok, isTrue);
        expect(msg, 'Student Enrolled Successfully');

        final state = container.read(bulkEnrollmentProvider);
        expect(state.roster.length, 11);
        expect(
          state.roster.any((r) => r.stuRegId == 9999 && r.classRollNo == 11),
          isTrue,
        );
      },
    );

    test('f) enroll blocks duplicate (4421 in Class 8 -> tries to add to Class 13 -> Student already added in Class Sec)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bulkEnrollmentProvider.notifier);
      notifier.setClassId(13);
      notifier.setSecId(25);
      notifier.setSessionYr('2017-2018');
      await notifier.loadRoster();

      // Student 4421 is already in Class 5 (ClassID 8) for session 2017-2018
      final (ok, msg) = await notifier.enrollStudent(
        regIdText: '4421',
        rollNoText: '11',
      );

      expect(ok, isFalse);
      expect(msg, 'Student already added in Class Sec');
    });

    test(
      'g) enroll blocks empty Reg ID -> Enter Student Registration ID',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(bulkEnrollmentProvider.notifier);
        notifier.setClassId(13);
        notifier.setSecId(25);
        notifier.setSessionYr('2017-2018');

        final (ok, msg) = await notifier.enrollStudent(
          regIdText: '',
          rollNoText: '11',
        );

        expect(ok, isFalse);
        expect(msg, 'Enter Student Registration ID');
      },
    );

    test(
      'h) enroll blocks nonexistent Reg ID -> Registration ID not found',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(bulkEnrollmentProvider.notifier);
        notifier.setClassId(13);
        notifier.setSecId(25);
        notifier.setSessionYr('2017-2018');

        final (ok, msg) = await notifier.enrollStudent(
          regIdText: '88888',
          rollNoText: '11',
        );

        expect(ok, isFalse);
        expect(msg, 'Registration ID not found');
      },
    );

    test('i) auto re-roll renumbers all students 1..N', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bulkEnrollmentProvider.notifier);
      notifier.setClassId(13);
      notifier.setSecId(25);
      notifier.setSessionYr('2017-2018');
      await notifier.loadRoster();

      // Corrupt roll numbers
      await db.rawUpdate(
        'UPDATE Student_Class SET ClassRollNo = 99 WHERE ClassSecID = 25',
      );

      final (ok, msg) = await notifier.autoReRollNumbers();
      expect(ok, isTrue);
      expect(msg, contains('New Roll Numbers Assigned to 10 Students'));

      final state = container.read(bulkEnrollmentProvider);
      for (int i = 0; i < state.roster.length; i++) {
        expect(state.roster[i].classRollNo, i + 1);
      }
    });

    test(
      'j) auto re-roll empty roster -> No Student for Re-Roll-Numbering',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(bulkEnrollmentProvider.notifier);
        final (ok, msg) = await notifier.autoReRollNumbers();

        expect(ok, isFalse);
        expect(msg, 'No Student for Re-Roll-Numbering');
      },
    );

    test('k) remove student deletes from Student_Class', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bulkEnrollmentProvider.notifier);
      notifier.setClassId(13);
      notifier.setSecId(25);
      notifier.setSessionYr('2017-2018');
      await notifier.loadRoster();

      final stateBefore = container.read(bulkEnrollmentProvider);
      final student4420 = stateBefore.roster.firstWhere(
        (r) => r.stuRegId == 4420,
      );

      final (ok, msg) = await notifier.removeStudent(student4420);
      expect(ok, isTrue);
      expect(msg, 'Hassan Akbar Removed');

      final stateAfter = container.read(bulkEnrollmentProvider);
      expect(stateAfter.roster.length, 9);
      expect(stateAfter.roster.any((r) => r.stuRegId == 4420), isFalse);

      final checkDb = await db.rawQuery(
        'SELECT 1 FROM Student_Class WHERE Stu_RegID = 4420 AND SessionYr = ?',
        ['2017-2018'],
      );
      expect(checkDb, isEmpty);
    });
  });

  group('BulkEnrollmentScreen UI & Responsiveness Tests', () {
    testWidgets('l) fits 1440x900 AND 1440x780 without overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/students/enrollment/bulk',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/students/enrollment/bulk',
                builder: (context, state) => const BulkEnrollmentScreen(),
              ),
            ],
          ),
        ],
      );

      Widget createWidget() {
        return ProviderScope(
          overrides: [
            classesProvider.overrideWith(
              (ref) => Future.value(const [
                SchoolClass(classId: 13, cName: 'Class 10'),
              ]),
            ),
            sectionsProvider.overrideWith(
              (ref) => Future.value(const [
                ClassSec(classSecId: 25, classId: 13, secName: 'A'),
              ]),
            ),
            sessionProvider.overrideWith((ref) {
              final notifier = SessionNotifier();
              notifier.setSession(testUser, const [12, 13, 20, 26]);
              return notifier;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        );
      }

      // 1. Test 1440x900
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BulkEnrollmentScreen), findsOneWidget);
      expect(find.text('Bulk Class Enrollment'), findsOneWidget);
      expect(find.text('+ Enroll Student'), findsOneWidget);
      expect(
        find.text('Select Class, Section, and Session, then click Load Roster'),
        findsOneWidget,
      );

      // 2. Test 1440x780
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BulkEnrollmentScreen), findsOneWidget);
    });
  });
}
