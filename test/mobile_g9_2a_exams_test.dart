// Phase G-9 Shot 2a — Stitch mobile UX tests for MarksEntryScreen and
// ExamTermScreen at 360x800 and 390x844. Harness copied from the
// test/mobile_g6a_* files, which copy test/marks_entry_screen_test.dart
// and test/exam_term_screen_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/exam_term_provider.dart';
import 'package:school_automation/core/providers/marks_entry_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/exams/exam_term_screen.dart';
import 'package:school_automation/screens/exams/marks_entry_screen.dart';
import 'package:school_automation/widgets/mobile/mobile_kpi_card.dart';
import 'package:school_automation/widgets/mobile/mobile_status_pill.dart';
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

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget wrapMarksEntry() {
    final router = GoRouter(
      initialLocation: '/exams/marks',
      routes: [
        GoRoute(
          path: '/exams/marks',
          builder: (context, state) => const Scaffold(body: MarksEntryScreen()),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        availableSessionsProvider.overrideWith((ref) async => ['2017-2018']),
        sessionProvider.overrideWith((ref) {
          final notifier = SessionNotifier();
          notifier.setSession(testUser, const [10, 23, 24]);
          return notifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapExamTerm(ExamTermNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/exams/terms',
      routes: [
        GoRoute(
          path: '/exams/terms',
          builder: (context, state) => const Scaffold(body: ExamTermScreen()),
        ),
        GoRoute(
          path: '/exams/marks',
          builder: (context, state) =>
              const Scaffold(body: Text('Marks Entry')),
        ),
        GoRoute(
          path: '/exams/subjects',
          builder: (context, state) =>
              const Scaffold(body: Text('Class Subjects Stub')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        examTermProvider.overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(testUser, const [8, 9, 10, 12, 13, 20]);
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('G-9-2a MarksEntryScreen mobile Stitch UX', () {
    testWidgets(
      'MarksEntryScreen at 360x800 renders Stitch filter card and loaded student marks cards with MobileStatusPill and zero overflow',
      (tester) async {
        setSize(tester, const Size(360, 800));

        await tester.pumpWidget(wrapMarksEntry());
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        final element = tester.element(find.byType(MarksEntryScreen));
        final container = ProviderScope.containerOf(element, listen: false);

        await tester.runAsync(() async {
          final notifier = container.read(marksEntryProvider.notifier);
          await notifier.loadInitialData();
          await notifier.setExTermId(1); // 1st Term
          await notifier.setClassId(13); // Class 10
          notifier.setClassSecId(25); // Sec A
          notifier.setSubjId(2); // Maths
          await notifier.loadEnrolledStudents();
        });
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'zero overflow at 360x800',
        );

        // Stitch filter card with primary action.
        expect(find.text('Load Students'), findsOneWidget);
        expect(find.text('Register Students for Exam'), findsOneWidget);
        final dropdownCount = find
            .byWidgetPredicate((w) => w is DropdownButton)
            .evaluate()
            .length;
        expect(dropdownCount, greaterThan(0));

        // Loaded roster: student cards with MobileStatusPill grade badges.
        expect(find.byType(MobileStatusPill), findsAtLeastNWidgets(1));
        expect(find.textContaining('Khan'), findsAtLeastNWidgets(1));
        expect(find.text('Total: '), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'MarksEntryScreen at 390x844 renders 2x2 summary KPIs and sticky Save action bar with zero overflow',
      (tester) async {
        setSize(tester, const Size(390, 844));

        await tester.pumpWidget(wrapMarksEntry());
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        final element = tester.element(find.byType(MarksEntryScreen));
        final container = ProviderScope.containerOf(element, listen: false);

        await tester.runAsync(() async {
          final notifier = container.read(marksEntryProvider.notifier);
          await notifier.loadInitialData();
          await notifier.setExTermId(1);
          await notifier.setClassId(13);
          notifier.setClassSecId(25);
          notifier.setSubjId(2);
          await notifier.loadEnrolledStudents();
        });
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'zero overflow at 390x844',
        );

        // 2x2 KPI summary strip renders four cards.
        expect(find.byType(MobileKpiCard), findsNWidgets(4));
        expect(find.text('MAX MARKS'), findsOneWidget);
        expect(find.text('PASS MARKS'), findsOneWidget);
        expect(find.text('PRESENT'), findsOneWidget);
        expect(find.text('PASS / FAIL'), findsOneWidget);

        // Sticky bottom action bar pins Save plus secondary report actions.
        expect(find.text('Save All Marks (Ctrl+S)'), findsOneWidget);
        expect(find.text('Mark Sheets'), findsOneWidget);
        expect(find.text('Award List'), findsOneWidget);
        expect(find.text('Award Certificate'), findsOneWidget);
        expect(find.text('Statistics'), findsOneWidget);

        // Counter line stays in the scroll body.
        expect(find.textContaining('Entered,'), findsOneWidget);
      },
    );
  });

  group('G-9-2a ExamTermScreen mobile Stitch UX', () {
    testWidgets(
      'ExamTermScreen at 360x800 renders MobileKpiCard summary and left-accent exam term cards with zero overflow',
      (tester) async {
        setSize(tester, const Size(360, 800));

        late ExamTermNotifier notifier;
        await tester.runAsync(() async {
          notifier = ExamTermNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrapExamTerm(notifier));
        await tester.pump();

        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'zero overflow at 360x800',
        );

        // 2-up MobileKpiCard summary row.
        expect(find.byType(MobileKpiCard), findsNWidgets(2));
        expect(find.text('TOTAL EXAM TERMS'), findsOneWidget);
        expect(find.text('TERM SESSIONS'), findsOneWidget);

        // Left-accent term cards in the catalog.
        expect(find.text('EXAM TERMS CATALOG'), findsOneWidget);
        expect(find.textContaining('1st Term'), findsAtLeastNWidgets(1));
        expect(find.byType(MobileStatusPill), findsAtLeastNWidgets(1));
        expect(find.text('Add Term'), findsOneWidget);
      },
    );

    testWidgets(
      'ExamTermScreen at 390x844 renders form controls and action buttons with zero overflow',
      (tester) async {
        setSize(tester, const Size(390, 844));

        late ExamTermNotifier notifier;
        await tester.runAsync(() async {
          notifier = ExamTermNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrapExamTerm(notifier));
        await tester.pump();

        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'zero overflow at 390x844',
        );

        // Session form controls render inside the form card (edit mode #1).
        expect(
          find.text('EDITING EXAMINATION SESSION: #1 (1st Term)'),
          findsOneWidget,
        );
        final dropdownCount = find
            .byWidgetPredicate((w) => w is DropdownButton)
            .evaluate()
            .length;
        expect(dropdownCount, greaterThan(2));
        expect(find.text('Go'), findsOneWidget);

        // Pinned sticky action bar.
        expect(find.text('Clear Form'), findsOneWidget);
        expect(find.text('Delete Session'), findsOneWidget);
        expect(find.text('Update Exam Session (Ctrl+S)'), findsOneWidget);

        // Scroll action-bar buttons are preserved.
        expect(find.text('Add Term'), findsOneWidget);
        expect(find.text('Print Catalog'), findsOneWidget);
        expect(find.text('Marks Entry'), findsOneWidget);
        expect(find.text('Exam Subjects'), findsOneWidget);
      },
    );
  });
}
