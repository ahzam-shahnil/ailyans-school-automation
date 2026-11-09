// Phase G-9 Shot 2b — Stitch mobile UX tests for ClassSubjectMappingScreen,
// ClassSectionScreen and SubjectCatalogScreen at 360x800 / 390x844.
// Harnesses copied from test/mobile_g6a_class_subject_mapping_test.dart,
// test/class_section_screen_test.dart and test/subject_catalog_screen_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/class_section_provider.dart';
import 'package:school_automation/core/providers/class_subject_mapping_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/subject_catalog_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/academics/class_section_screen.dart';
import 'package:school_automation/screens/academics/subject_catalog_screen.dart';
import 'package:school_automation/screens/exams/class_subject_mapping_screen.dart';
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
    classCount: 13,
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

  /// Shared provider overrides wired to a preloaded notifier.
  Widget wrapWith(List<Override> overrides, List<RouteBase> routes,
      String initialLocation) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: routes,
    );
    return ProviderScope(
      overrides: [
        ...overrides,
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(
            testUser,
            const [1, 4, 8, 9, 10, 12, 13, 20, 23, 24, 25],
          );
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget wrapClassSubjectMapping(ClassSubjectMappingNotifier notifier) {
    return wrapWith(
      [classSubjectMappingProvider.overrideWith((ref) => notifier)],
      [
        GoRoute(
          path: '/exams/subjects',
          builder: (context, state) => const ClassSubjectMappingScreen(),
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
        GoRoute(
          path: '/staff/teachers/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('Teacher Profile')),
        ),
      ],
      '/exams/subjects',
    );
  }

  Widget wrapClassSection(ClassSectionNotifier notifier) {
    return wrapWith(
      [classSectionProvider.overrideWith((ref) => notifier)],
      [
        GoRoute(
          path: '/academics/classes',
          builder: (context, state) => const ClassSectionScreen(),
        ),
        GoRoute(
          path: '/academics/subjects',
          builder: (context, state) =>
              const Scaffold(body: Text('Subject Catalog')),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) =>
              const Scaffold(body: Text('Dashboard Stub')),
        ),
      ],
      '/academics/classes',
    );
  }

  Widget wrapSubjectCatalog(SubjectCatalogNotifier notifier) {
    return wrapWith(
      [subjectCatalogProvider.overrideWith((ref) => notifier)],
      [
        GoRoute(
          path: '/academics/subjects',
          builder: (context, state) => const SubjectCatalogScreen(),
        ),
        GoRoute(
          path: '/academics/classes',
          builder: (context, state) =>
              const Scaffold(body: Text('Classes Stub')),
        ),
        GoRoute(
          path: '/exams/subjects',
          builder: (context, state) =>
              const Scaffold(body: Text('Exams Subjects Stub')),
        ),
      ],
      '/academics/subjects',
    );
  }

  group('G-9-2b ClassSubjectMappingScreen mobile Stitch UX', () {
    testWidgets(
      'ClassSubjectMappingScreen at 360x800 renders MobileKpiCard summary and left-strip subject cards with zero overflow',
      (tester) async {
        setSize(tester, const Size(360, 800));

        late ClassSubjectMappingNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSubjectMappingNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrapClassSubjectMapping(notifier));
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
          reason: 'zero overflow at 360x800',
        );

        // 2-up KPI summary row.
        expect(find.byType(MobileKpiCard), findsNWidgets(2));
        expect(find.text('MAPPED SUBJECTS'), findsOneWidget);
        expect(find.text('AVAILABLE SUBJECTS'), findsOneWidget);

        // Left-strip mapping cards still render (Class 10 has 5 mappings).
        expect(find.byType(Card), findsWidgets);
        expect(
          find.textContaining('ASSIGNED SUBJECTS FOR CLASS 10').evaluate().length,
          greaterThan(0),
        );
        expect(
          find.textContaining('Total Marks: 500').evaluate().length,
          greaterThan(0),
        );
        final cards = find.byType(MobileStatusPill).evaluate().length;
        expect(cards, greaterThan(0));

        // Sticky bottom action bar with the primary save button.
        expect(find.text('Save Mapping (Ctrl+S)'), findsOneWidget);
        expect(find.text('Reset Form'), findsOneWidget);
      },
    );
  });

  group('G-9-2b ClassSectionScreen mobile Stitch UX', () {
    testWidgets(
      'ClassSectionScreen at 360x800 renders mobile class cards, section cards, and sticky action bar with zero overflow',
      (tester) async {
        setSize(tester, const Size(360, 800));

        late ClassSectionNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSectionNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrapClassSection(notifier));
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

        // Header + 2-up KPI strip.
        expect(find.text('Class & Section Management'), findsOneWidget);
        expect(find.byType(MobileKpiCard), findsNWidgets(2));
        expect(find.text('TOTAL CLASSES'), findsOneWidget);
        expect(find.text('TOTAL SECTIONS'), findsOneWidget);

        // CLASSES list renders class cards with pills and 44px edit targets.
        expect(find.textContaining('CLASSES'), findsWidgets);
        expect(find.textContaining('Play Group'), findsAtLeastNWidgets(1));
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(MobileStatusPill), findsAtLeastNWidgets(1));

        // SECTIONS list renders section cards for the default class.
        expect(find.textContaining('SECTIONS'), findsAtLeastNWidgets(1));
        expect(find.textContaining('Teacher:'), findsAtLeastNWidgets(1));
        expect(find.byTooltip('Edit class'), findsWidgets);
        expect(find.text('Edit'), findsWidgets);
        expect(find.text('Delete'), findsWidgets);

        // Sticky bottom action bar.
        expect(find.text('+ Add Class'), findsOneWidget);
        expect(find.text('+ Add Section'), findsOneWidget);
      },
    );

    testWidgets(
      'ClassSectionScreen at 390x844 selecting a class updates sections list with zero overflow',
      (tester) async {
        setSize(tester, const Size(390, 844));

        late ClassSectionNotifier notifier;
        await tester.runAsync(() async {
          notifier = ClassSectionNotifier();
          await notifier.loadInitialData();
        });

        await tester.pumpWidget(wrapClassSection(notifier));
        await tester.pump();

        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Default selection is Play Group (2 seeded sections).
        expect(
          find.textContaining('for Play Group').evaluate().length,
          greaterThan(0),
        );
        expect(find.textContaining('Teacher:').evaluate().length, 2);

        // Tap the 'Class 10' class card (scroll it into view first).
        final classTenCard = find.textContaining('Class 10').first;
        await tester.ensureVisible(classTenCard);
        await tester.pump();
        await tester.ensureVisible(classTenCard);
        await tester.pump();
        await tester.tap(classTenCard);
        await tester.pump();

        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason: 'zero overflow after selecting Class 10 at 390x844',
        );

        // Sections heading now targets Class 10; class 10's two seeded
        // sections replace the Play Group rows, and the section subscribed to
        // the 10 seeded students surfaces the '10 students' pill.
        expect(
          find.textContaining('for Class 10').evaluate().length,
          greaterThan(0),
        );
        expect(find.textContaining('Teacher:').evaluate().length, 2);
        expect(find.textContaining('10 students').evaluate().length,
            greaterThan(0));
      },
    );
  });

  group('G-9-2b SubjectCatalogScreen mobile Stitch UX', () {
    const sizes = <Size>[Size(360, 800), Size(390, 844)];

    for (final size in sizes) {
      testWidgets(
        'SubjectCatalogScreen at $size renders mobile subject cards with MobileStatusPill and inline form controls with zero overflow',
        (tester) async {
          setSize(tester, size);

          late SubjectCatalogNotifier notifier;
          await tester.runAsync(() async {
            notifier = SubjectCatalogNotifier();
            await notifier.loadInitialData();
          });

          await tester.pumpWidget(wrapSubjectCatalog(notifier));
          await tester.pump();

          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          });
          await tester.pump();
          await tester.pumpAndSettle(const Duration(milliseconds: 300));

          expect(
            tester.takeException(),
            isNull,
            reason: 'zero overflow (catalog) at $size',
          );

          // Header + search + 2-up KPI strip.
          expect(find.text('Subject Catalog'), findsOneWidget);
          expect(find.byType(MobileKpiCard), findsNWidgets(2));
          expect(find.text('TOTAL SUBJECTS'), findsOneWidget);
          expect(find.text('CLASSES ASSIGNED'), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);

          // Left-strip subject cards for the 5 seeded subjects.
          expect(find.textContaining('SUBJECTS'), findsAtLeastNWidgets(1));
          expect(find.byType(Card), findsNWidgets(5));
          expect(find.text('Islamiat'), findsOneWidget);
          expect(find.text('Maths'), findsOneWidget);
          expect(find.text('Computer Science'), findsOneWidget);
          expect(find.byType(MobileStatusPill), findsAtLeastNWidgets(1));
          expect(find.text('Edit'), findsNWidgets(5));

          // Sticky bar primary CTA before the drawer opens.
          expect(find.text('Add New Subject (Ctrl+N)'), findsOneWidget);

          // Open the inline add/edit form via the desktop edit handler.
          await tester.tap(find.text('Edit').first);
          await tester.pump();
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          });
          await tester.pump();
          await tester.pumpAndSettle(const Duration(milliseconds: 300));

          expect(
            tester.takeException(),
            isNull,
            reason: 'zero overflow (edit form) at $size',
          );
          expect(find.text('Edit Subject #1'), findsOneWidget);
          expect(find.text('Subject ID'), findsOneWidget);
          expect(find.text('Subject Name *'), findsOneWidget);
          // Sticky bar switches to the save CTA.
          expect(find.text('Save Subject (Ctrl+S)'), findsOneWidget);
        },
      );
    }
  });
}
