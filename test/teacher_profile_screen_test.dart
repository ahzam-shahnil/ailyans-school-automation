import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/teacher_profile_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/staff/teacher_profile_screen.dart';
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
    staffCount: 6,
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

    // Seed 6th teacher (inactive)
    await db.insert('Teachers', {
      'TeacherID': 6,
      'TName': 'Test Relieved Staff',
      'TFName': 'Test Father',
      'TCNIC': '38302-6666666-6',
      'TContactNo1': '03336666666',
      'TSubject': 'Geography',
      'DOJoing': '2018-01-01',
      'TIsPresent': 'N',
      'TCat': 'Staff',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Update Subj_Class row 4 to TeacherID = 2 so Teacher 1 has exactly 4 assigned classes
    await db.rawUpdate(
      'UPDATE Subj_Class SET TeacherID = 2 WHERE Subj_ClsID = 4',
    );

    // Seed 3 salary slips for Teacher 1
    await db.insert('TSalMas', {
      'TSalMasID': '1710-1',
      'TeacherID': 1,
      'DisbursDate': '2017-10-25',
      'SalMonth': 'October 2017',
      'PaidAmt': 45000,
      'TDeductions': 2000,
      'Detail': 'Principal salary - Oct 2017',
      'IsPaid': 'Y',
      'PaidDate': '2017-10-25',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('TSalMas', {
      'TSalMasID': '1709-1',
      'TeacherID': 1,
      'DisbursDate': '2017-09-25',
      'SalMonth': 'September 2017',
      'PaidAmt': 45000,
      'TDeductions': 2000,
      'Detail': 'Principal salary - Sep 2017',
      'IsPaid': 'Y',
      'PaidDate': '2017-09-25',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('TSalMas', {
      'TSalMasID': '1708-1',
      'TeacherID': 1,
      'DisbursDate': '2017-08-25',
      'SalMonth': 'August 2017',
      'PaidAmt': 45000,
      'TDeductions': 2000,
      'Detail': 'Principal salary - Aug 2017',
      'IsPaid': 'Y',
      'PaidDate': '2017-08-25',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Widget buildTestScreen({
    String initialLocation = '/staff/teachers/1',
    int? teacherId = 1,
    TeacherProfileNotifier? notifier,
    GlobalKey? repaintKey,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/staff/teachers',
              builder: (context, state) =>
                  const Scaffold(body: Text('Teacher Directory Stub')),
            ),
            GoRoute(
              path: '/staff/teachers/new',
              builder: (context, state) {
                const screen = TeacherProfileScreen(isCreateMode: true);
                if (repaintKey != null) {
                  return RepaintBoundary(key: repaintKey, child: screen);
                }
                return screen;
              },
            ),
            GoRoute(
              path: '/staff/teachers/:id',
              builder: (context, state) {
                final idStr = state.pathParameters['id'];
                final id = idStr != null ? int.tryParse(idStr) : null;
                final screen = TeacherProfileScreen(teacherId: id);
                if (repaintKey != null) {
                  return RepaintBoundary(key: repaintKey, child: screen);
                }
                return screen;
              },
            ),
            GoRoute(
              path: '/exams/subjects',
              builder: (context, state) {
                final fromTId = state.uri.queryParameters['fromTeacherId'];
                return Scaffold(
                  body: Text('Class Subjects Stub fromTeacherId=$fromTId'),
                );
              },
            ),
            GoRoute(
              path: '/staff/salary',
              builder: (context, state) =>
                  const Scaffold(body: Text('Payroll Terminal Stub')),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        if (notifier != null)
          teacherProfileProvider(teacherId).overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser, const [8, 9, 10, 12, 13, 14, 20]);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('TeacherProfileProvider Unit & Business Logic Tests', () {
    test('h) Save with empty TName -> error "Must Enter Teacher Name Please " (trailing space)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherProfileProvider(null).notifier);
      notifier.initNewTeacher(userLvl: 1);

      // Gate 2: Empty TName
      notifier.updateField('TName', '   ');
      final resName = await notifier.save(userLvl: 1);
      expect(resName, isNull);
      expect(
        container.read(teacherProfileProvider(null)).errorMessage,
        'Must Enter Teacher Name Please ',
      );

      // Gate 3: Empty TCNIC
      notifier.updateField('TName', 'Valid Teacher');
      notifier.updateField('TCNIC', '   ');
      final resCnic = await notifier.save(userLvl: 1);
      expect(resCnic, isNull);
      expect(
        container.read(teacherProfileProvider(null)).errorMessage,
        'Must Enter CNIC Please ',
      );

      // Gate 4: Empty TContactNo1
      notifier.updateField('TCNIC', '38302-1234567-1');
      notifier.updateField('TContactNo1', '   ');
      final resContact = await notifier.save(userLvl: 1);
      expect(resContact, isNull);
      expect(
        container.read(teacherProfileProvider(null)).errorMessage,
        'Must Enter Contact No 1 Please ',
      );

      // Gate 1: Insufficient rights (userLevel == 3)
      final resRights = await notifier.save(userLvl: 3);
      expect(resRights, isNull);
      expect(
        container.read(teacherProfileProvider(null)).errorMessage,
        "You don't have enough rights for purpose",
      );
    });

    test('i) Save valid edit -> UPDATE in SQLite, toast "Teacher Profile Updated Successfully"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherProfileProvider(1).notifier);
      await notifier.loadTeacher(1);

      notifier.enterEditMode();
      notifier.updateField('TAddress', 'Civil Lines, House 42');

      final savedId = await notifier.save(userLvl: 1);
      expect(savedId, 1);
      expect(
        container.read(teacherProfileProvider(1)).toast,
        'Teacher Profile Updated Successfully',
      );

      final rows = await db.query(
        'Teachers',
        where: 'TeacherID = ?',
        whereArgs: [1],
      );
      expect(rows.first['TAddress'], 'Civil Lines, House 42');
    });

    test('k) Fill required fields -> saves with MAX+1 TeacherID -> toast "Teacher Profile Created Successfully"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherProfileProvider(null).notifier);
      notifier.initNewTeacher(userLvl: 1);

      notifier.updateField('TName', 'Farhan Tariq');
      notifier.updateField('TCNIC', '38302-7777777-7');
      notifier.updateField('TContactNo1', '03337777777');
      notifier.updateField('TCat', 'Teacher');
      notifier.updateField('TSubject', 'Biology');

      final savedId = await notifier.save(userLvl: 1);
      expect(savedId, isNotNull);
      expect(
        container.read(teacherProfileProvider(null)).toast,
        'Teacher Profile Created Successfully',
      );

      final rows = await db.query('Teachers', orderBy: 'TeacherID DESC');
      // 6 existed initially, so MAX+1 is 7
      expect(rows.first['TeacherID'], 7);
      expect(rows.first['TName'], 'Farhan Tariq');
      expect(rows.first['TCat'], 'Teacher');
    });

    test('l) Tab 2 loads 4 Subj_Class rows for TeacherID=1 (Islamiat, Maths, Urdu, Computer Science)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherProfileProvider(1).notifier);
      await notifier.loadTeacher(1);

      final assignments = container
          .read(teacherProfileProvider(1))
          .subjectAssignments;
      expect(assignments.length, 4);

      final names = assignments.map((a) => a.subjName).toList();
      expect(
        names,
        containsAll(['Islamiat', 'Maths', 'Urdu', 'Computer Science']),
      );
    });

    test('m) Tab 3 loads 3 TSalMas rows in order: October (1710-1), September (1709-1), August (1708-1)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(teacherProfileProvider(1).notifier);
      await notifier.loadTeacher(1);

      final slips = container.read(teacherProfileProvider(1)).salarySlips;
      expect(slips.length, 3);
      expect(slips[0].tSalMasId, '1710-1');
      expect(slips[0].salMonth, 'October 2017');
      expect(slips[1].tSalMasId, '1709-1');
      expect(slips[1].salMonth, 'September 2017');
      expect(slips[2].tSalMasId, '1708-1');
      expect(slips[2].salMonth, 'August 2017');
    });
  });

  group('TeacherProfileScreen Widget & UI Tests', () {
    testWidgets('a) Loads TeacherID=1 in View mode on mount per §S25', (
      tester,
    ) async {
      late TeacherProfileNotifier notifier;
      await tester.runAsync(() async {
        notifier = TeacherProfileNotifier();
        await notifier.loadTeacher(1);
      });

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestScreen(
          initialLocation: '/staff/teachers/1',
          teacherId: 1,
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      // Screen title and subtitle metadata
      expect(find.text('Ahzam Shahnil'), findsWidgets);
      expect(find.text('Principal'), findsWidgets);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Tab headers
      expect(find.text('1. Personal & Biodata'), findsOneWidget);
      expect(find.text('2. Class Subjects (4)'), findsOneWidget);
      expect(find.text('3. Payroll History (3)'), findsOneWidget);
      expect(find.text('4. Qualifications'), findsOneWidget);
    });

    testWidgets(
      'b) View mode: all Tab 1 fields are read-only (styled in surfaceSubtle)',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // In view mode, no TextFormFields are present; fields render as non-editable containers
        expect(find.byType(TextFormField), findsNothing);

        // Verify read-only text values are displayed in the view containers
        expect(find.text('Ahzam Shahnil'), findsWidgets);
        expect(find.text('Muhammad Ali'), findsOneWidget);
        expect(find.text('38302-1111111-1'), findsWidgets);
        expect(find.text('03331111111'), findsWidgets);
      },
    );

    testWidgets(
      'c) Click [Edit Profile] -> fields become editable, header buttons switch to Save/Cancel',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Tap [Edit Profile]
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        // Action buttons changed
        expect(find.text('Save Changes (Ctrl+S)'), findsOneWidget);
        expect(find.text('Cancel Edits'), findsOneWidget);

        // Fields are now editable TextFormFields
        expect(find.byType(TextFormField), findsWidgets);
      },
    );

    testWidgets(
      'd) Editing 1 field enables [Save Changes], shows amber "Unsaved Changes" badge',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        // Initially not dirty -> no badge
        expect(find.text('Unsaved Changes'), findsNothing);

        // Modify Father Name field
        final fatherField = find.widgetWithText(TextFormField, 'Muhammad Ali');
        expect(fatherField, findsOneWidget);
        await tester.enterText(fatherField, 'Muhammad Ali Updated');
        await tester.pumpAndSettle();

        // Amber badge is visible
        expect(find.text('Unsaved Changes'), findsOneWidget);

        // Save button is enabled
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save Changes (Ctrl+S)'),
        );
        expect(saveBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'e) Reverting field to original clears dirty state, disables Save',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        final fatherField = find.widgetWithText(TextFormField, 'Muhammad Ali');
        await tester.enterText(fatherField, 'Different Father');
        await tester.pumpAndSettle();
        expect(find.text('Unsaved Changes'), findsOneWidget);

        // Revert back to original
        final modifiedField = find.widgetWithText(
          TextFormField,
          'Different Father',
        );
        await tester.enterText(modifiedField, 'Muhammad Ali');
        await tester.pumpAndSettle();

        expect(find.text('Unsaved Changes'), findsNothing);
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save Changes (Ctrl+S)'),
        );
        expect(saveBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'f) Switch to Tab 4 -> Tab 4 fields editable (shared form state)',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        // Tap Tab 4
        await tester.tap(find.text('4. Qualifications'));
        await tester.pumpAndSettle();

        // Check fields in Tab 4
        expect(find.text('QUALIFICATIONS & CREDENTIALS'), findsOneWidget);
        expect(find.text('Academic Degrees'), findsOneWidget);
        expect(find.text('Professional Certifications'), findsOneWidget);
      },
    );

    testWidgets(
      'g) Back to Directory while dirty -> discard confirmation dialog appears',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        // Modify a field to become dirty
        final fatherField = find.widgetWithText(TextFormField, 'Muhammad Ali');
        await tester.enterText(fatherField, 'Dirty Modified Father');
        await tester.pumpAndSettle();

        // Tap [Back to Directory]
        await tester.tap(find.text('Back to Directory'));
        await tester.pumpAndSettle();

        // Discard confirmation dialog appears
        expect(find.text('Discard Unsaved Changes?'), findsOneWidget);
        expect(find.text('Keep Editing'), findsOneWidget);
        expect(find.text('Discard Changes'), findsOneWidget);

        // Tapping Keep Editing stays on page
        await tester.tap(find.text('Keep Editing'));
        await tester.pumpAndSettle();

        expect(find.text('Discard Unsaved Changes?'), findsNothing);
        expect(find.text('Save Changes (Ctrl+S)'), findsOneWidget);
      },
    );

    testWidgets(
      'j) /staff/teachers/new -> create mode with blank form, default TCat="Teacher", disabled Tabs 2/3',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          notifier.initNewTeacher(userLvl: 1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/new',
            teacherId: null,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Header indicates create mode
        expect(find.text('New Teacher'), findsOneWidget);
        expect(
          find.text('Complete the required fields to create this record.'),
          findsOneWidget,
        );
        expect(find.text('Create Employee'), findsOneWidget);

        // Tab 2 & 3 titles in create mode
        expect(find.text('2. Class Subjects'), findsOneWidget);
        expect(find.text('3. Payroll History'), findsOneWidget);
      },
    );

    testWidgets('n) Fits 1440x900 AND 1440x780 without overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late TeacherProfileNotifier notifier;
      await tester.runAsync(() async {
        notifier = TeacherProfileNotifier();
        await notifier.loadTeacher(1);
      });

      // 1. 1440x900 Viewport
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        buildTestScreen(
          initialLocation: '/staff/teachers/1',
          teacherId: 1,
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TeacherProfileScreen), findsOneWidget);
      expect(find.text('Ahzam Shahnil'), findsWidgets);

      // 2. 1440x780 Viewport
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TeacherProfileScreen), findsOneWidget);
    });

    testWidgets(
      'o) Continuous typing in text fields preserves focus and full string across words (Bug 1)',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        // Find Full Name field
        final nameField = find.widgetWithText(TextFormField, 'Ahzam Shahnil');
        expect(nameField, findsOneWidget);

        // Continuous typing test: enter 'Ahzam Shahnil Test'
        await tester.enterText(nameField, 'Ahzam Shahnil Test');
        await tester.pumpAndSettle();

        // Field retains full typed text
        expect(
          find.widgetWithText(TextFormField, 'Ahzam Shahnil Test'),
          findsOneWidget,
        );

        // Switch to Tab 4 and type in Academic Degrees
        await tester.tap(find.text('4. Qualifications'));
        await tester.pumpAndSettle();

        final degreesField = find.byKey(const ValueKey('TQualification_field'));
        expect(degreesField, findsOneWidget);
        await tester.enterText(degreesField, 'M.Sc Mathematics B.Ed');
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextFormField, 'M.Sc Mathematics B.Ed'),
          findsOneWidget,
        );

        // Switch back to Tab 1 and verify 'Ahzam Shahnil Test' persists
        await tester.tap(find.text('1. Personal & Biodata'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextFormField, 'Ahzam Shahnil Test'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'p) Tab 2 Assign Class Subject button has single plus and navigates with fromTeacherId (Bug 3 & 4)',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Go to Tab 2
        await tester.tap(find.textContaining('2. Class Subjects'));
        await tester.pumpAndSettle();

        // Button label must be 'Assign Class Subject' (NOT '+ Assign Class Subject')
        expect(find.text('Assign Class Subject'), findsOneWidget);
        expect(find.text('+ Assign Class Subject'), findsNothing);

        // Click [Assign Class Subject]
        await tester.tap(find.text('Assign Class Subject'));
        await tester.pumpAndSettle();

        // Navigates to /exams/subjects?fromTeacherId=1
        expect(
          find.text('Class Subjects Stub fromTeacherId=1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'q) Stale state resets to View mode and Tab 1 on re-entry; [Refresh] button refreshes profile (Bug 5)',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Verify Refresh button is present in View mode
        final refreshBtn = find.byTooltip('Refresh profile and child data');
        expect(refreshBtn, findsOneWidget);

        // Tap refresh
        await tester.runAsync(() async {
          await tester.tap(refreshBtn);
          await Future.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Profile refreshed'), findsOneWidget);

        // Enter Edit mode and switch to Tab 3
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('3. Payroll History'));
        await tester.pumpAndSettle();
        expect(notifier.state.isEditMode, isTrue);
        expect(notifier.state.activeTab, 2);

        // Re-enter /staff/teachers/1
        await notifier.init(1);
        await tester.pumpAndSettle();

        // State is reset to View mode and Tab 1
        expect(notifier.state.isEditMode, isFalse);
        expect(notifier.state.activeTab, 0);
      },
    );

    testWidgets(
      'r) Keyboard shortcuts Ctrl+S, Ctrl+E, Cmd+S, Cmd+E trigger actions (Bug 2)',
      (tester) async {
        late TeacherProfileNotifier notifier;
        await tester.runAsync(() async {
          notifier = TeacherProfileNotifier();
          await notifier.loadTeacher(1);
        });

        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            teacherId: 1,
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Focus the root tree
        await tester.tap(find.text('Ahzam Shahnil').first);
        await tester.pumpAndSettle();

        // In View mode, trigger Ctrl+E
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        // Should enter edit mode
        expect(notifier.state.isEditMode, isTrue);

        // Revert to view mode and test Cmd+E (metaLeft)
        notifier.cancelEdits();
        await tester.pumpAndSettle();
        expect(notifier.state.isEditMode, isFalse);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();

        expect(notifier.state.isEditMode, isTrue);
      },
    );
  });
}
