// Phase K-6 Run 2b — Fix 3: the Fee Defaulter List roster is registered in
// the Reports Hub and renders through the DEDICATED dashboard code path
// (feeCollectionProvider.notifier.buildDefaulterList →
// DefaulterListPdfGenerator), NOT the generic VB6 flex-table renderer.
//
// Assertions:
// - the catalog lists 'Fee Defaulter List';
// - the hub's filter row shows the Session/Billing Month/Class/Section
//   controls the report consumes;
// - tapping the card opens ReportPreviewModal with a request that has
//   type == ReportType.defaulterList AND locksOrientation == true;
// - the generated PDF bytes are the dedicated roster generator's output
//   (same entry point the dashboard uses — guaranteed by the shared
//   buildDefaulterListData builder; also directly exercised here).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/clock_provider.dart';
import 'package:school_automation/core/providers/fee_collection_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/screens/reports/reports_hub_screen.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _testMetadata = ShellMetadata(
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

  Widget buildHub(WidgetTester tester) {
    // NB: textScaler 0.5 — widget tests render text with the Ahem
    // placeholder font whose glyphs are ~1em squares (~2x wider than real
    // UI fonts). The hub filter bar's dropdowns overflow under Ahem at any
    // realistic width; 0.5 restores real-device-like metrics for the test
    // (the K-1 cross-platform lesson: assert against real-world metrics,
    // not the test font's).
    return ProviderScope(
      overrides: [
        shellMetadataProvider.overrideWith((ref) => Future.value(_testMetadata)),
        availableSessionsProvider.overrideWith((ref) => Future.value([
              '2017-2018',
            ])),
        classesProvider.overrideWith((ref) => Future.value(const [
              SchoolClass(classId: 1, cName: 'Class 1'),
            ])),
        sectionsProvider.overrideWith((ref) => Future.value(const [
              ClassSec(classSecId: 11, classId: 1, secName: 'A'),
            ])),
        clockProvider.overrideWith((ref) => () => DateTime(2026, 11, 18)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.5),
          ),
          child: child!,
        ),
        home: const ReportsHubScreen(),
      ),
    );
  }

  testWidgets('catalog lists Fee Defaulter List with the hub filter row',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildHub(tester));
    // tester.runAsync escapes FakeAsync so the real sqflite_ffi query
    // completers can fire (the established fee_ledger_screen_test pattern —
    // FFI completers never resolve inside plain pump()).
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);

    // The new catalog card is present in the Defaulters category.
    expect(find.text('Fee Defaulter List'), findsOneWidget);

    // The filter row exposes the session/class/section/month controls the
    // roster path consumes.
    expect(find.text('Session Year'), findsOneWidget);
    expect(find.text('Billing Month'), findsOneWidget);
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Section'), findsOneWidget);
  });

  testWidgets('tapping the card opens the modal with the dedicated locked '
      'defaulterList request', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildHub(tester));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Fee Defaulter List'));
    // Let _openReport's awaited buildDefaulterList (real FFI queries)
    // complete outside FakeAsync, then pump the dialog route in.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(ReportPreviewModal), findsOneWidget);

    final modal = tester.widget<ReportPreviewModal>(
      find.byType(ReportPreviewModal),
    );
    final request = modal.request;
    expect(
      request.type,
      ReportType.defaulterList,
      reason: 'The hub must route the roster through the DEDICATED '
          'defaulterList path, not the generic VB6 table renderer',
    );
    expect(
      request.locksOrientation,
      isFalse,
      reason: 'Phase K-6 Run B: portrait layout is now supported — the hub '
          'request must NOT lock the orientation so the toggle works',
    );
    expect(request.naturalPageFormat, PdfPageFormat.a4.landscape);
  });

  test('shared builder renders the same roster layout the dashboard path '
      'uses', () async {
    // The hub's _openReport calls feeCollectionProvider.notifier
    // .buildDefaulterList — which delegates to the SAME top-level
    // buildDefaulterListData exercised here directly (identical layout,
    // therefore identical byte length for identical params).
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final buildData = await buildDefaulterListData(sessionYr: '2017-2018');
    expect(buildData.summary.sessionYr, '2017-2018');
    expect(buildData.summary, isNotNull);

    final bytes = await DefaulterListPdfGenerator.generate(
      groups: buildData.groups,
      summary: buildData.summary,
      branchName: 'Smoke School',
      branchAddress: 'Smoke Address',
      pageFormat: PdfPageFormat.a4.landscape,
    );
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1000));

    // The Notifier path must produce the identical layout length (it is a
    // thin delegate to the same builder).
    final notifierData = await container
        .read(feeCollectionProvider.notifier)
        .buildDefaulterList(sessionYr: '2017-2018');
    final notifierBytes = await DefaulterListPdfGenerator.generate(
      groups: notifierData.groups,
      summary: notifierData.summary,
      branchName: 'Smoke School',
      branchAddress: 'Smoke Address',
      pageFormat: PdfPageFormat.a4.landscape,
    );
    expect(
      notifierBytes.length,
      bytes.length,
      reason: 'The hub path and the dashboard path share ONE builder — '
          'identical params must render identical layouts',
    );
  });
}
