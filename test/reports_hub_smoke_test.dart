import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/providers/reports_hub_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 14 VB6 reports query + build PDF against the bundled DB', () async {
    final db = await DatabaseService.instance.database;
    expect(db, isNotNull);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final filters = container.read(reportsHubFiltersProvider);

    for (final def in kVb6Reports) {
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
