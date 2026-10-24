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
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/attendance/attendance_screen.dart';
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

    // Ensure AttMas record #1 is dated 2026-10-22 for historical edit-mode testing
    await db.update('AttMas', {
      'AttDate': '2026-10-22 08:00:00',
    }, where: 'AttMasID = 1');

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  group('AttendanceScreen UI', () {
    test('a) loads classes and shows empty roster before selection', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceProvider.notifier);
      final classes = await notifier.loadClasses();
      expect(classes, isNotEmpty);

      final state = container.read(attendanceProvider);
      expect(state.classes.length, classes.length);
      expect(state.selectedClassId, isNull);
      expect(state.selectedClassSecId, isNull);
      expect(state.roster, isEmpty);
      expect(state.isEditMode, isFalse);
    });

    test('b) auto-loads roster and shows edit mode when AttMas exists for selected class/sec/date', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceProvider.notifier);
      await notifier.loadClasses();

      // Precondition: inject 2026-10-22 BEFORE loadRoster
      notifier.debugSelectDate(DateTime(2026, 10, 22));

      await notifier.loadSectionsForClass(13);
      await notifier.selectSection(25);

      final state = container.read(attendanceProvider);
      expect(state.isEditMode, isTrue);
      expect(state.existingAttMasId, 1);
      expect(state.roster.length, 10);
      expect(state.summaryCounts['Present'], 8);
      expect(state.summaryCounts['Absent'], 1);
      expect(state.summaryCounts['Leave'], 1);
    });

    test('c) status toggle updates summary chip counts', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceProvider.notifier);
      notifier.debugSelectDate(DateTime(2026, 10, 22));
      await notifier.loadSectionsForClass(13);
      await notifier.selectSection(25);

      var state = container.read(attendanceProvider);
      expect(state.summaryCounts['Present'], 8);
      expect(state.summaryCounts['Absent'], 1);

      // Student 4411 is currently Present; toggle to Absent
      notifier.updateStudentStatus(4411, 'Absent');
      state = container.read(attendanceProvider);
      expect(state.summaryCounts['Present'], 7);
      expect(state.summaryCounts['Absent'], 2);

      // Toggle to Late
      notifier.updateStudentStatus(4411, 'Late');
      state = container.read(attendanceProvider);
      expect(state.summaryCounts['Present'], 7);
      expect(state.summaryCounts['Absent'], 1);
      expect(state.summaryCounts['Late'], 1);
    });

    test('d) Mark All Present sets every row to Present', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceProvider.notifier);
      notifier.debugSelectDate(DateTime(2026, 10, 22));
      await notifier.loadSectionsForClass(13);
      await notifier.selectSection(25);

      notifier.markAllAs('Present');
      final state = container.read(attendanceProvider);
      expect(state.summaryCounts['Present'], 10);
      expect(state.summaryCounts['Absent'], 0);
      expect(state.summaryCounts['Leave'], 0);
      expect(state.summaryCounts['Late'], 0);
      for (final row in state.roster) {
        expect(row.currentStatus, 'Present');
      }
    });

    test('e) submit toasts Class Attandance Done on new record', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceProvider.notifier);
      // Pick a future date with no existing attendance
      notifier.debugSelectDate(DateTime(2026, 10, 25));
      await notifier.loadClasses();
      await notifier.loadSectionsForClass(13);
      await notifier.selectSection(25);

      // Supply teacher
      notifier.setTeacher(1);

      final result = await notifier.submitAttendance();
      expect(result, isTrue);

      final state = container.read(attendanceProvider);
      expect(state.toast, 'Class Attandance Done');
      expect(state.isEditMode, isTrue);
      expect(state.existingAttMasId, isNotNull);

      // Verify row persisted in DB
      final dbMas = await db.rawQuery(
        "SELECT * FROM AttMas WHERE DATE(AttDate) = '2026-10-25'",
      );
      expect(dbMas.length, 1);
    });

    test(
      'f) submit toasts Attandance Already done when isEditMode is true',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(attendanceProvider.notifier);
        notifier.debugSelectDate(DateTime(2026, 10, 22));
        await notifier.loadSectionsForClass(13);
        await notifier.selectSection(25);

        expect(container.read(attendanceProvider).isEditMode, isTrue);

        final result = await notifier.submitAttendance();
        expect(result, isFalse);
        expect(
          container.read(attendanceProvider).toast,
          'Attandance Already done',
        );
      },
    );

    test('g) update toasts Attandance Record Updated and re-inserts AttDet rows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(attendanceProvider.notifier);
      notifier.debugSelectDate(DateTime(2026, 10, 22));
      await notifier.loadSectionsForClass(13);
      await notifier.selectSection(25);

      notifier.setTeacher(2);
      notifier.updateStudentStatus(4411, 'Late');

      final result = await notifier.updateAttendance();
      expect(result, isTrue);

      final state = container.read(attendanceProvider);
      expect(state.toast, 'Attandance Record Updated');

      // Verify AttDet was re-inserted with student 4411 as Late
      final det = await db.rawQuery(
        'SELECT AttStatus FROM AttDet WHERE AttMasID = 1 AND Stu_RegID = 4411',
      );
      expect(det.first['AttStatus'], 'Late');
    });

    test(
      'h) no default teacher guard fires when ClassSec.SecTeacher is null',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(attendanceProvider.notifier);
        notifier.debugSelectDate(DateTime(2026, 10, 26));
        await notifier.loadClasses();
        await notifier.loadSectionsForClass(13);

        // Section 25 has SecTeacher == null in seed data
        await notifier.selectSection(25);
        // Explicitly clear teacher if set
        notifier.setTeacher(null);

        final guardMsg = notifier.validateTeacher();
        expect(
          guardMsg,
          'No Default Teacher for Section, Select Other Section Teacher.',
        );

        final result = await notifier.submitAttendance();
        expect(result, isFalse);
        expect(
          container.read(attendanceProvider).toast,
          'No Default Teacher for Section, Select Other Section Teacher.',
        );
      },
    );

    test(
      'i) discardEdits reloads saved roster and preserves cohort selection',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(attendanceProvider.notifier);
        notifier.debugSelectDate(DateTime(2026, 10, 22));
        await notifier.loadClasses();
        await notifier.loadSectionsForClass(13);
        await notifier.selectSection(25);

        // Mutate student 4411 to Absent
        notifier.updateStudentStatus(4411, 'Absent');
        expect(container.read(attendanceProvider).summaryCounts['Absent'], 2);

        // Discard edits
        notifier.discardEdits();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(attendanceProvider);
        expect(state.selectedClassId, 13);
        expect(state.selectedClassSecId, 25);
        // Reloaded saved state has 1 Absent (reverted from 2)
        expect(state.summaryCounts['Absent'], 1);
        expect(state.summaryCounts['Present'], 8);
      },
    );

    test(
      'j) clearSelection resets cohort selection and empties roster',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(attendanceProvider.notifier);
        await notifier.loadClasses();
        await notifier.loadSectionsForClass(13);

        expect(container.read(attendanceProvider).selectedClassId, 13);

        notifier.clearSelection();

        final state = container.read(attendanceProvider);
        expect(state.selectedClassId, isNull);
        expect(state.selectedClassSecId, isNull);
        expect(state.roster, isEmpty);
        // Classes list preserved so user doesn't need to reload
        expect(state.classes, isNotEmpty);
      },
    );

    testWidgets(
      'teacher dropdown shows hint and null selection when ClassSec.SecTeacher is null',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.binding.setSurfaceSize(null));
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
        await tester.pumpAndSettle();

        // 1. state.selectedTeacherId == null
        final state = container.read(attendanceProvider);
        expect(state.selectedTeacherId, isNull);

        // 2. The Teacher dropdown renders 'Select Teacher' hint text
        expect(find.text('Select Teacher'), findsOneWidget);

        // 3. Attempting submitAttendance() returns the guard error
        bool? submitResult;
        await tester.runAsync(() async {
          submitResult = await notifier.submitAttendance();
        });
        await tester.pump();
        expect(submitResult, isFalse);
        expect(
          notifier.validateTeacher(),
          'No Default Teacher for Section, Select Other Section Teacher.',
        );
        expect(
          find.text(
            'No Default Teacher for Section, Select Other Section Teacher.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('AttendanceScreen layout', () {
    testWidgets('k) fits 1440x900 without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/attendance',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/attendance',
                builder: (context, state) => const AttendanceScreen(),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
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
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AttendanceScreen), findsOneWidget);
      expect(find.text('Enrolled: 0'), findsOneWidget);
    });

    testWidgets(
      'l) fits 1440x780 (weak-password banner active) without overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 780));
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/attendance',
          routes: [
            ShellRoute(
              builder: (context, state, child) => AppShell(child: child),
              routes: [
                GoRoute(
                  path: '/attendance',
                  builder: (context, state) => const AttendanceScreen(),
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionProvider.overrideWith((ref) {
                final notifier = SessionNotifier();
                notifier.setSession(testUser, const [
                  2,
                  28,
                ], hasWeakPasswordWarning: true);
                return notifier;
              }),
              shellMetadataProvider.overrideWith(
                (ref) => Future.value(testMetadata),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AttendanceScreen), findsOneWidget);
      },
    );
  });
}
