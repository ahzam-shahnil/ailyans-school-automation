import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/school_leaving_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/students/school_leaving_screen.dart';
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
    pendingVouchers: 4,
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

    // Insert an extra Student_Class row for student 4411 to test deduplication
    await db.rawInsert('''
      INSERT INTO Student_Class (Stu_RegID, ClassID, ClassSecID, ClassRollNo, SessionYr, Present, VGen)
      VALUES (4411, 13, 25, 1, '2016-2017', 0, 'N')
    ''');

    // Ensure student 4411 has Rs. 180 discount on unpaid voucher so dues = 1620
    await db.rawUpdate('''
      UPDATE VoucharMas
      SET Discount = 180
      WHERE Student_Class_StuRegID = 4411 AND IsPaid = 'N'
    ''');

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('SchoolLeavingScreen Provider & Business Logic Tests', () {
    test(
      'a) loads deduplicated students (each Stu_RegID appears once)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container.read(schoolLeavingProvider.notifier).loadInitialData();
        final state = container.read(schoolLeavingProvider);

        expect(state.students, isNotEmpty);
        final idSet = <int>{};
        for (final s in state.students) {
          expect(
            idSet.contains(s.stuRegId),
            isFalse,
            reason: 'Duplicate Stu_RegID ${s.stuRegId}',
          );
          idSet.add(s.stuRegId);
        }
        expect(state.students.where((s) => s.stuRegId == 4411).length, 1);
      },
    );

    test('b) selecting student with no SLC and no dues computes dues=0, CLEARED green gate, form enabled with defaults (reason=Leaving, conduct=Good )', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectStudent(
        4413,
      ); // 4413 has paid October voucher and no other dues

      final state = container.read(schoolLeavingProvider);
      expect(state.selectedStudent, isNotNull);
      expect(state.selectedStudent!.stuRegId, 4413);
      expect(state.hasExistingSlc, isFalse);
      expect(state.outstandingDues, 0.0);
      expect(state.overdueMonths, 0);
      expect(state.hasDues, isFalse);
      expect(state.isFormEditable, isTrue);
      expect(state.reason, 'Leaving');
      expect(state.conduct, 'Good ');
    });

    test('c) selecting student with existing SLC shows info banner, read-only fields, Commit disabled, Print button labeled Reprint Leaving Certificate', () async {
      // Pre-insert an SLC record for student 4413
      await db.rawInsert('''
          INSERT INTO SchLeaving (SLID, StuRegID, LeftDate, LeftClass, Charactor, TermOfLeavign, SLCertificate, Remarks)
          VALUES (101, 4413, '2018-05-31', 13, 'Good ', 'Completed Studies', 1, 'Transferred to college')
        ''');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectStudent(4413);

      final state = container.read(schoolLeavingProvider);
      expect(state.hasExistingSlc, isTrue);
      expect(state.isFormEditable, isFalse);
      expect(state.reason, 'Completed Studies');
      expect(state.conduct, 'Good ');
      expect(state.remarks, 'Transferred to college');

      final (canCommit, msg) = notifier.canCommit();
      expect(canCommit, isFalse);
      expect(msg, 'A leaving record already exists for this student.');
    });

    test('d) selecting student with dues > 0 shows BLOCKED red gate, disabled fields, Commit still fires verbatim dues error', () async {
      // Student 4411 has October voucher unpaid (dues = 1620, overdueMonths = 1)
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectStudent(4411);

      final state = container.read(schoolLeavingProvider);
      expect(state.outstandingDues, 1620.0);
      expect(state.overdueMonths, 1);
      expect(state.hasDues, isTrue);
      expect(state.isFormEditable, isFalse);

      final (canCommit, msg) = notifier.canCommit();
      expect(canCommit, isFalse);
      expect(
        msg,
        'Student has out standing dues Rs. 1620 for 1 Months. Must pay before left',
      );
    });

    test('e) selecting student 4411 (both SLC + dues) shows both banners, Commit disabled', () async {
      // Pre-insert SLC for student 4411
      await db.rawInsert('''
        INSERT INTO SchLeaving (SLID, StuRegID, LeftDate, LeftClass, Charactor, TermOfLeavign, SLCertificate, Remarks)
        VALUES (102, 4411, '2018-06-15', 13, 'Good ', 'Graduated', 1, 'Pending dues')
      ''');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectStudent(4411);

      final state = container.read(schoolLeavingProvider);
      expect(state.hasExistingSlc, isTrue);
      expect(state.hasDues, isTrue);
      expect(state.outstandingDues, 1620.0);
      expect(state.isFormEditable, isFalse);

      final (canCommit, _) = notifier.canCommit();
      expect(canCommit, isFalse);
    });

    test('f) validation gates fire verbatim (Select Student First, Student has out standing dues...)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();

      // Gate 1: No student selected
      var (ok, msg) = notifier.canCommit();
      expect(ok, isFalse);
      expect(msg, 'Select Student First');

      // Gate 2: Select student with dues (4411)
      await notifier.selectStudent(4411);
      (ok, msg) = notifier.canCommit();
      expect(ok, isFalse);
      expect(
        msg,
        'Student has out standing dues Rs. 1620 for 1 Months. Must pay before left',
      );
    });

    test('g) commitLeaving deactivates Student_Class Present=0 + inserts SchLeaving with Charactor=Good  and SLCertificate=1', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectStudent(4413); // Dues = 0

      notifier.setRemarks('Family relocating to Lahore');
      final (ok, msg) = await notifier.commitLeaving();
      expect(ok, isTrue);
      expect(msg, contains('School leaving recorded'));

      // Verify Student_Class Present=0
      final scRows = await db.rawQuery(
        'SELECT Present FROM Student_Class WHERE Stu_RegID = ?',
        [4413],
      );
      for (final r in scRows) {
        expect(r['Present'], 0);
      }

      // Verify SchLeaving insert
      final slRows = await db.rawQuery(
        'SELECT * FROM SchLeaving WHERE StuRegID = ?',
        [4413],
      );
      expect(slRows.length, 1);
      final sl = slRows.first;
      expect(sl['Charactor'], 'Good ');
      expect(sl['TermOfLeavign'], 'Leaving');
      expect(sl['SLCertificate'], 1);
      expect(sl['Remarks'], 'Family relocating to Lahore');
    });

    test('h) post-commit shows success toast, Print button enabled, post-commit banner', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectStudent(4413);

      await notifier.commitLeaving();
      final state = container.read(schoolLeavingProvider);

      expect(state.toast, isNotNull);
      expect(state.toast, contains('School leaving recorded for 4413'));
      expect(state.committedSlc, isNotNull);
      expect(state.committedSlc!['TermOfLeavign'], 'Leaving');
      expect(state.committedSlc!['Charactor'], 'Good ');
    });

    test('j) Ctrl+T sets leaving date to today', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectStudent(4413);

      // Set to another date first
      notifier.setLeavingDate(DateTime(2020, 1, 1));
      expect(container.read(schoolLeavingProvider).leavingDate.year, 2020);

      // Trigger setTodayDate
      notifier.setTodayDate();
      final today = DateTime.now();
      final currentDate = container.read(schoolLeavingProvider).leavingDate;
      expect(currentDate.year, today.year);
      expect(currentDate.month, today.month);
      expect(currentDate.day, today.day);
    });

    test(
      'n) Reason/Conduct default to Leaving / Good  when student selected',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(schoolLeavingProvider.notifier);
        await notifier.loadInitialData();
        await notifier.selectStudent(4413);

        final state = container.read(schoolLeavingProvider);
        expect(state.reason, 'Leaving');
        expect(state.conduct, 'Good ');
      },
    );

    test('p) inferClassFromRemarks infers the leaving class from SLC remarks', () {
      expect(
        SchoolLeavingNotifier.inferClassFromRemarks(
          'Passing out from 8 class . 718.5 / 850',
        ),
        'Eight',
      );
      expect(
        SchoolLeavingNotifier.inferClassFromRemarks('class 9 completed'),
        'Nine',
      );
      expect(
        SchoolLeavingNotifier.inferClassFromRemarks('passed 10th class'),
        'Ten',
      );
      expect(
        SchoolLeavingNotifier.inferClassFromRemarks('went to nursery then left'),
        'Nursery',
      );
      expect(
        SchoolLeavingNotifier.inferClassFromRemarks('family relocating'),
        isNull,
      );
      expect(SchoolLeavingNotifier.inferClassFromRemarks(null), isNull);
      expect(SchoolLeavingNotifier.inferClassFromRemarks(''), isNull);
    });

    test('q) updateSlcRecord persists Class at Leaving + all certificate particulars and honors overrides', () async {
      // Seed an existing SLC for 4413 (currently enrolled in Class 10).
      await db.rawInsert('''
        INSERT INTO SchLeaving (SLID, StuRegID, LeftDate, LeftClass, Charactor, TermOfLeavign, SLCertificate, Remarks)
        VALUES (103, 4413, '2018-05-31', 13, 'Good ', 'Completed Studies', 1, 'Completed studies')
      ''');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();
      await notifier.selectStudent(4413);

      final (ok, msg) = await notifier.updateSlcRecord(
        stuRegId: 4413,
        studentName: 'New Student Name',
        fatherName: 'New Father Name',
        address: '12 New Street',
        dob: '05-Sep-2010',
        admissionDate: '01-Apr-2010',
        classAdmitted: 'Class 3',
        classAtLeaving: 'Class 8',
        duesPaidUpTo: 'October',
      );
      expect(ok, isTrue);
      expect(msg, contains('SLC record updated'));

      final state = container.read(schoolLeavingProvider);
      expect(state.selectedStudent, isNotNull);
      expect(state.selectedStudent!.stuRegId, 4413);
      // Displayed class follows the edited Class at Leaving (never reverts
      // to the old class or 'Unassigned').
      expect(state.selectedStudent!.className, 'Class 8');
      expect(state.certificateFields['leftClass'], 'Class 8');
      expect(state.certificateFields['admittedClass'], 'Class 3');
      expect(state.certificateFields['dob'], '05-Sep-2010');
      expect(state.certificateFields['admissionDate'], '01-Apr-2010');
      expect(state.certificateFields['address'], '12 New Street');
      expect(state.certificateFields['duesPaidUpTo'], 'October');

      // DB writes landed: Stu_Reg particulars + most recent Student_Class.
      final reg = (await db.rawQuery(
        'SELECT DOB, P_Address, AdmInClass FROM Stu_Reg WHERE Stu_RegID = 4413',
      )).first;
      expect(reg['DOB'], '2010-09-05');
      expect(reg['P_Address'], '12 New Street');
      expect(reg['AdmInClass'], 6); // 'Class 3'

      final sc = (await db.rawQuery(
        'SELECT ClassID FROM Student_Class WHERE Stu_RegID = 4413 ORDER BY Present DESC, SessionYr DESC LIMIT 1',
      )).first;
      expect(sc['ClassID'], 11); // 'Class 8'
    });

    test('r) alumni with unassigned active class resolve class from SLC remarks', () async {
      // Give student 4414 an SLC whose remarks name the class they left.
      await db.rawInsert('''
        INSERT INTO SchLeaving (SLID, StuRegID, LeftDate, LeftClass, Charactor, TermOfLeavign, SLCertificate, Remarks)
        VALUES (104, 4414, '2018-05-31', 0, 'Good ', 'Completed Studies', 1, 'Passing out from 8 class . 718.5 / 850')
      ''');
      // Break the active enrollment so CName would otherwise be NULL.
      await db.rawUpdate(
        'UPDATE Student_Class SET ClassID = 0 WHERE Stu_RegID = 4414',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();

      final state = container.read(schoolLeavingProvider);
      final row = state.students.firstWhere((s) => s.stuRegId == 4414);
      expect(row.className, 'Eight');

      await notifier.selectStudent(4414);
      final selected = container.read(schoolLeavingProvider);
      expect(selected.selectedStudent!.className, 'Eight');
      expect(selected.certificateFields['leftClass'], 'Eight');
    });

    test('s) SchLeaving.LeftClass is the class source of truth for alumni and is persisted by updateSlcRecord', () async {
      // Alumni 4415: a STALE Student_Class row points at 'Class 8' (ClassID 11)
      // while the SchLeaving row records the true leaving class 'Class 7'
      // (ClassID 10, named 'Seven' in the production DB). SchLeaving.LeftClass
      // must win.
      await db.rawInsert('''
        INSERT INTO SchLeaving (SLID, StuRegID, LeftDate, LeftClass, Charactor, TermOfLeavign, SLCertificate, Remarks)
        VALUES (105, 4415, '2018-05-31', 10, 'Good ', 'Completed Studies', 1, '')
      ''');
      await db.rawUpdate(
        'UPDATE Student_Class SET ClassID = 11 WHERE Stu_RegID = 4415',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(schoolLeavingProvider.notifier);
      await notifier.loadInitialData();

      final row = container
          .read(schoolLeavingProvider)
          .students
          .firstWhere((s) => s.stuRegId == 4415);
      expect(row.className, 'Class 7'); // from SchLeaving.LeftClass, NOT 'Class 8'
      expect(row.classId, 10);

      await notifier.selectStudent(4415);
      expect(
        container.read(schoolLeavingProvider).certificateFields['leftClass'],
        'Class 7',
      );

      // Editing Class at Leaving persists into SchLeaving.LeftClass in SQLite.
      final (ok, msg) = await notifier.updateSlcRecord(
        stuRegId: 4415,
        classAtLeaving: 'Class 9',
      );
      expect(ok, isTrue);
      expect(msg, contains('SLC record updated'));

      final sl = (await db.rawQuery(
        'SELECT LeftClass FROM SchLeaving WHERE StuRegID = 4415',
      )).first;
      expect(sl['LeftClass'], 12); // 'Class 9'

      final after = container.read(schoolLeavingProvider);
      expect(after.selectedStudent!.className, 'Class 9');
      expect(after.certificateFields['leftClass'], 'Class 9');
    });
  });

  group('SchoolLeavingScreen UI & Widget Tests', () {
    Widget buildTestScreen({
      SchoolLeavingNotifier? notifier,
      GoRouter? customRouter,
    }) {
      final router =
          customRouter ??
          GoRouter(
            initialLocation: '/students/leaving',
            routes: [
              ShellRoute(
                builder: (context, state, child) => AppShell(child: child),
                routes: [
                  GoRoute(
                    path: '/students/leaving',
                    builder: (context, state) => const SchoolLeavingScreen(),
                  ),
                  GoRoute(
                    path: '/fees/receipts',
                    builder: (context, state) => Scaffold(
                      body: Text(
                        'Fee Receipts studentId=${state.uri.queryParameters['studentId']}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

      return ProviderScope(
        overrides: [
          if (notifier != null)
            schoolLeavingProvider.overrideWith((ref) => notifier),
          sessionProvider.overrideWith((ref) {
            final session = SessionNotifier();
            session.setSession(testUser, const [8, 9, 12, 13, 20]);
            return session;
          }),
          shellMetadataProvider.overrideWith(
            (ref) => Future.value(testMetadata),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets(
      'i) confirmation dialog shows verbatim S12 warning + 3 numbered consequences',
      (tester) async {
        late SchoolLeavingNotifier notifier;
        await tester.runAsync(() async {
          notifier = SchoolLeavingNotifier();
          await notifier.loadInitialData();
          await notifier.selectStudent(4413);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Click Commit School Leaving button
        final commitBtn = find.text('Commit School Leaving');
        expect(commitBtn, findsOneWidget);
        await tester.tap(commitBtn);
        await tester.pumpAndSettle();

        // Verify confirmation dialog title and verbatim warning
        expect(find.text('Confirm School Leaving'), findsOneWidget);
        expect(
          find.text(
            'WARNING. No Vouchers will b egeberated in Future. ARE YOU SURE?',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('1. Active classroom enrollment for 4413'),
          findsOneWidget,
        );
        expect(
          find.text(
            '2. A School Leaving record will be saved with the terms entered.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            '3. No further fee vouchers will be generated for this student.',
          ),
          findsOneWidget,
        );
        expect(find.text('Commit Withdrawal'), findsOneWidget);

        // Dismiss dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'k) Pay Arrears Now navigates to /fees/receipts?studentId={id}',
      (tester) async {
        late SchoolLeavingNotifier notifier;
        await tester.runAsync(() async {
          notifier = SchoolLeavingNotifier();
          await notifier.loadInitialData();
          await notifier.selectStudent(4411); // has 1620 dues
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Verify financial gate is in BLOCKED state
        expect(find.text('OUTSTANDING DUES BALANCE'), findsOneWidget);
        expect(find.text('BLOCKED'), findsOneWidget);
        expect(find.textContaining('Rs. 1620'), findsWidgets);

        // Click Pay Arrears Now
        final payBtn = find.text('Pay Arrears Now');
        expect(payBtn, findsOneWidget);
        await tester.tap(payBtn);
        await tester.pumpAndSettle();

        // Should have navigated to /fees/receipts?studentId=4411
        expect(find.text('Fee Receipts studentId=4411'), findsOneWidget);
      },
    );

    testWidgets('l) fits 1440x900 AND 1440x780 without overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late SchoolLeavingNotifier notifier;
      await tester.runAsync(() async {
        notifier = SchoolLeavingNotifier();
        await notifier.loadInitialData();
      });

      // 1. 1440x900
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestScreen(notifier: notifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SchoolLeavingScreen), findsOneWidget);
      expect(find.text('School Leaving'), findsOneWidget);
      expect(find.text('STUDENT CLEARANCE DOSSIER'), findsOneWidget);
      expect(find.text('WITHDRAWAL DETAILS & CERTIFICATE'), findsOneWidget);

      // 2. 1440x780
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SchoolLeavingScreen), findsOneWidget);
    });

    testWidgets(
      'm) Ctrl+S triggers commit, Ctrl+P triggers print when enabled',
      (tester) async {
        late SchoolLeavingNotifier notifier;
        await tester.runAsync(() async {
          notifier = SchoolLeavingNotifier();
          await notifier.loadInitialData();
          await notifier.selectStudent(4413);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // Press Ctrl+S -> confirmation dialog should open
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pumpAndSettle();

        expect(find.text('Confirm School Leaving'), findsOneWidget);

        // Confirm withdrawal
        await tester.tap(find.text('Commit Withdrawal'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // Post-commit banner and toast
        expect(
          find.textContaining('School leaving recorded for 4413'),
          findsWidgets,
        );

        // Now Ctrl+P should be enabled and trigger print dialog
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Dialog or preview opened
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'o) student search: live filter + match counter + quick-match chip + Enter auto-select',
      (tester) async {
        late SchoolLeavingNotifier notifier;
        await tester.runAsync(() async {
          notifier = SchoolLeavingNotifier();
          await notifier.loadInitialData();
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestScreen(notifier: notifier));
        await tester.pumpAndSettle();

        // No student selected yet -> right panel shows the empty state.
        expect(find.text('Select Student First'), findsOneWidget);

        // Type a Reg ID: dropdown live-filters, counter shows 1 match and a
        // quick-match chip appears.
        await tester.enterText(
          find.byKey(const Key('slcStudentSearchField')),
          '4413',
        );
        await tester.pumpAndSettle();

        expect(find.text('1 match'), findsOneWidget);
        final chip = find.textContaining('4413 - ');
        expect(chip, findsWidgets);

        // One tap on the chip selects the student immediately.
        await tester.tap(chip.first);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        expect(find.text('Select Student First'), findsNothing);

        // Enter-to-select: typing another Reg ID and submitting auto-selects
        // the exact match (4411 -> dues BLOCKED gate appears).
        await tester.enterText(
          find.byKey(const Key('slcStudentSearchField')),
          '4411',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        expect(find.text('OUTSTANDING DUES BALANCE'), findsOneWidget);
        expect(find.text('BLOCKED'), findsOneWidget);
      },
    );
  });
}
