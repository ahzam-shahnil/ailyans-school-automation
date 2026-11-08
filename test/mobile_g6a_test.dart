// Phase G / G-6a — unified 3-screen × 3-size loaded-state zero-overflow
// suite. Per-screen ProviderScope overrides + in-memory DB harness
// copied verbatim from the 3 per-screen G-6a mobile test files. The
// 3 focused files remain for debugging.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/class_subject_mapping_provider.dart';
import 'package:school_automation/core/providers/exam_term_provider.dart';
import 'package:school_automation/core/providers/marks_entry_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/exams/class_subject_mapping_screen.dart';
import 'package:school_automation/screens/exams/exam_term_screen.dart';
import 'package:school_automation/screens/exams/marks_entry_screen.dart';
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

  // ExamTermScreen + ClassSubjectMappingScreen metadata (pendingVouchers: 4).
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

  // MarksEntryScreen metadata (pendingVouchers: 2).
  const testMetadataMarks = ShellMetadata(
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

  // Copied verbatim from test/mobile_g6a_marks_entry_test.dart
  Widget wrapMarksEntry(Widget child) {
    final router = GoRouter(
      initialLocation: '/exams/marks',
      routes: [
        GoRoute(
          path: '/exams/marks',
          builder: (context, state) => Scaffold(body: child),
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
        shellMetadataProvider.overrideWith(
          (ref) => Future.value(testMetadataMarks),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  // Copied verbatim from test/mobile_g6a_exam_term_test.dart
  Widget wrapExamTerm(Widget child, ExamTermNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/exams/terms',
      routes: [
        GoRoute(
          path: '/exams/terms',
          builder: (context, state) => Scaffold(body: child),
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

  // Copied verbatim from test/mobile_g6a_class_subject_mapping_test.dart
  Widget wrapClassSubjectMapping(
    Widget child,
    ClassSubjectMappingNotifier notifier,
  ) {
    final router = GoRouter(
      initialLocation: '/exams/subjects',
      routes: [
        GoRoute(
          path: '/exams/subjects',
          builder: (context, state) => child,
        ),
        GoRoute(
          path: '/exams/marks',
          builder: (context, state) =>
              const Scaffold(body: Text('Marks Entry')),
        ),
        GoRoute(
          path: '/exams/terms',
          builder: (context, state) =>
              const Scaffold(body: Text('Exam Terms')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        classSubjectMappingProvider.overrideWith((ref) => notifier),
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

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  const sizes = <Size>[Size(360, 800), Size(390, 844), Size(414, 896)];

  group('G-6a unified mobile exam screens zero-overflow', () {
    for (final size in sizes) {
      testWidgets('MarksEntryScreen loaded at $size', (tester) async {
        setSize(tester, size);

        await tester.pumpWidget(wrapMarksEntry(const MarksEntryScreen()));
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
          reason: 'marks_entry overflow at $size',
        );
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'marks_entry cards at $size',
        );
      });

      testWidgets('ExamTermScreen loaded at $size', (tester) async {
        setSize(tester, size);

        late ExamTermNotifier notifier;
        await tester.runAsync(() async {
          notifier = ExamTermNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(
          wrapExamTerm(const ExamTermScreen(), notifier),
        );
        await tester.pump();

        // Let the screen's own post-frame loadInitialData complete under real
        // async so the loading spinner is replaced by the loaded catalog.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'exam_term overflow at $size',
        );
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'exam_term cards at $size',
        );
      });

      testWidgets('ClassSubjectMappingScreen loaded at $size', (tester) async {
        setSize(tester, size);

        late ClassSubjectMappingNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSubjectMappingNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(
          wrapClassSubjectMapping(const ClassSubjectMappingScreen(), notifier),
        );
        await tester.pump();

        // Let the screen's own post-frame loadInitialData complete under real
        // async so the loading spinner is replaced by the loaded mapping rows.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'mapping overflow at $size',
        );
        expect(
          find.byType(Card),
          findsWidgets,
          reason: 'mapping cards at $size',
        );
      });
    }
  });
}
