import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/providers/fee_collection_provider.dart';
import 'package:school_automation/core/providers/reports_hub_provider.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all VB6 reports query + build PDF against the bundled DB', () async {
    final db = await DatabaseService.instance.database;
    expect(db, isNotNull);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final filters = container.read(reportsHubFiltersProvider);

    for (final def in kVb6Reports) {
      // Phase K-6 Run 2b: the Fee Defaulter List roster is NOT a generic
      // VB6 flex-table report — it renders through the dedicated
      // buildDefaulterListData builder + DefaulterListPdfGenerator (the
      // exact code path the dashboard / fee screens use), with a locked
      // A4-landscape orientation. fetchVb6ReportRows guards against
      // routing it through the generic renderer.
      if (def.id == 'fee_defaulter_list') {
        final buildData = await buildDefaulterListData(
          sessionYr: filters.sessionYr,
        );
        expect(buildData.summary.totalDefaulters,
            buildData.groups.fold<int>(0, (sum, g) => sum + g.rows.length),
            reason: '${def.id} group/summary consistency');
        final bytes = await DefaulterListPdfGenerator.generate(
          groups: buildData.groups,
          summary: buildData.summary,
          branchName: 'Smoke School',
          branchAddress: 'Smoke Address',
          pageFormat: PdfPageFormat.a4.landscape,
        );
        expect(bytes.length, greaterThan(1000), reason: '${def.id} pdf bytes');
        continue;
      }

      final data = await fetchVb6ReportRows(def.id, filters);
      expect(data.headers, isNotEmpty, reason: '${def.id} headers');
      for (final row in data.rows) {
        expect(row.length, data.headers.length,
            reason: '${def.id} row width');
      }
      if (data.groups != null) {
        for (final g in data.groups!) {
          for (final row in g.rows) {
            expect(row.length, data.headers.length,
                reason: '${def.id} group row width');
          }
        }
      }
      final bytes = await buildVb6ReportPdf(
        reportId: def.id,
        title: def.title,
        filters: filters,
        branchName: 'Smoke School',
        branchAddress: 'Smoke Address',
      );
      expect(bytes.length, greaterThan(1000),
          reason: '${def.id} pdf bytes');
    }
  });
}
