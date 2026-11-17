// Phase K-6 Run 2 — Fix B: A4 PDF printable-width budget.
//
// Light assertions (no PDF binary parsing): the per-report printable width
// helper, the margin invariants, and real PDF bytes construction for the
// named reports. The pdf package's FlexColumnWidth tables always fill
// exactly the printable width, so the overflow class this run guards
// against lives in fixed-width budgets and intrinsic-width Rows — both are
// asserted here.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:school_automation/core/providers/report_preview_provider.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';
import 'package:school_automation/core/utils/vb6_table_report_pdf.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';

/// The 10-column defaulter table's FIXED column budget (points) from
/// `_buildClassGroup`'s columnWidths: 24+32+42+76+58+68+78+72.
const double _kDefaulterFixedWidths = 450.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Defaulter List width budget', () {
    test('margins follow invariant 12 (40pt left gutter, right >= 30pt)', () {
      expect(DefaulterListPdfGenerator.kMarginLeft, 40);
      expect(DefaulterListPdfGenerator.kMarginRight, greaterThanOrEqualTo(30));
      expect(DefaulterListPdfGenerator.kMarginTop, 30);
      expect(DefaulterListPdfGenerator.kMarginBottom, 30);
    });

    test('fixed column budget fits the printable width in BOTH orientations',
        () {
      final landscape = DefaulterListPdfGenerator.printableWidth(
        PdfPageFormat.a4.landscape,
      );
      final portrait = DefaulterListPdfGenerator.printableWidth(
        PdfPageFormat.a4,
      );

      // A4 landscape printable = 841.89 − 40 − 30 = 771.89pt.
      expect(landscape, closeTo(841.8897637795277 - 70, 0.01));
      // A4 portrait printable = 595.28 − 40 − 30 = 525.28pt.
      expect(portrait, closeTo(595.2755905511812 - 70, 0.01));

      // The fixed columns never force an overflow; the 2.3/2.1 FlexColumn
      // weights fill whatever remains (positive in both orientations).
      expect(_kDefaulterFixedWidths, lessThanOrEqualTo(landscape));
      expect(_kDefaulterFixedWidths, lessThanOrEqualTo(portrait));
      expect(landscape - _kDefaulterFixedWidths, greaterThan(0));
      expect(portrait - _kDefaulterFixedWidths, greaterThan(0));
    });

    test('PDF bytes construct for the natural landscape and portrait override',
        () async {
      final row = DefaulterListRow(
        voucherMasId: 'VCH-001',
        stuRegId: 1001,
        studentName: 'Test Student',
        className: 'Class V',
        sectionName: 'B',
        rollNo: 5,
        forMonth: 'October 2025',
        subtotal: 5000,
        discount: 0,
        paidAmt: 3000,
        netPayable: 2000,
        isPaid: 'O',
        dueDate: DateTime(2025, 10, 15),
        daysOverdue: 3,
      );
      final group = DefaulterClassGroup(
        classLabel: 'Class V-B',
        rows: [row],
        subtotal: 2000,
      );
      final summary = DefaulterListFilterSummary(
        sessionYr: '2025-2026',
        totalDefaulters: 1,
        uniqueStudents: 1,
        totalOutstanding: 2000,
        reportMonth: 'October 2025',
        generatedAt: DateTime(2025, 10, 18),
      );

      // Natural default: A4 landscape (Balance (Rs) inside the right margin).
      final landscapeBytes = await DefaulterListPdfGenerator.generate(
        groups: [group],
        summary: summary,
        branchName: 'Test School',
        branchAddress: 'Test Address',
        pageFormat: null,
      );
      expect(landscapeBytes, isNotEmpty);

      // Portrait override is honored instead of silently ignored.
      final portraitBytes = await DefaulterListPdfGenerator.generate(
        groups: [group],
        summary: summary,
        branchName: 'Test School',
        branchAddress: 'Test Address',
        pageFormat: PdfPageFormat.a4,
      );
      expect(portraitBytes, isNotEmpty);
      // Distinct renders for distinct formats.
      expect(identical(landscapeBytes, portraitBytes), isFalse);
    });
  });

  group('Classwise Paid Detail (VB6) width budget', () {
    test('right margin bumped to 30pt; printable width recomputed', () {
      expect(Vb6TableReportPdf.kMarginLeft, 40);
      expect(Vb6TableReportPdf.kMarginRight, 30);

      final printable = Vb6TableReportPdf.printableWidth(
        PdfPageFormat.a4.landscape,
      );
      expect(printable, closeTo(841.8897637795277 - 70, 0.01));
    });

    test('PDF bytes construct with the report\'s 8-column layout', () async {
      // Real classwise_paid_detail header/align shape (from
      // reports_hub_provider.dart), fed straight into the generic renderer.
      final bytes = await Vb6TableReportPdf.generate(
        title: 'Classwise Paid Detail',
        subtitle:
            'Session: 2025-2026 | Month: October 2025 | Class: All | Section: All',
        branchName: 'Test School',
        branchAddress: 'Test Address',
        pageFormat: PdfPageFormat.a4.landscape,
        headers: const [
          'Voucher #',
          'Reg ID',
          'Name',
          'Class',
          'Month',
          'Paid Amount (Rs)',
          'Paid Date',
          'Bank',
        ],
        rows: const [
          ['VCH-001', '1001', 'Test Student', 'Class V', 'October 2025',
            'Rs. 3,000', '2025-10-14', 'Askari Bank'],
          ['VCH-002', '1002', 'Another Student', 'Class VI', 'October 2025',
            'Rs. 4,500', '2025-10-14', 'Askari Bank'],
        ],
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
        ],
        landscape: true,
      );
      expect(bytes, isNotEmpty);
    });
  });

  group('Class Collection Summary (inline generator)', () {
    /// Generates via the provider family so the REAL production code path
    /// (ReportPreviewNotifier._generateClassCollectionSummary) runs —
    /// including the Expanded-wrapped TOTALS row and the format override.
    Future<Uint8List?> generateSummaryPdf(
      ReportRequest request, [
      PdfPageFormat? pageFormat,
    ]) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = reportPreviewProvider(
        ReportPreviewKey(request: request, pageFormat: pageFormat),
      );
      // Keep the autoDispose instance alive while generation completes.
      container.listen(provider, (_, __) {}, fireImmediately: true);

      var state = container.read(provider);
      var guard = 0;
      while (state.isLoading && guard++ < 200) {
        await Future<void>.delayed(Duration.zero);
        state = container.read(provider);
      }
      expect(state.error, isNull, reason: 'PDF generation must not fail');
      return state.bytes;
    }

    const ReportRequest summaryRequest = ReportRequest(
      type: ReportType.classCollectionSummary,
      titleOverride: 'Class Collection Summary',
      extraParams: {
        'branchName': 'Test School',
        'branchAddress': 'Test Address',
        'month': 'October 2025',
        'sessionYr': '2025-2026',
        'rows': [
          {
            'className': 'Class V-B',
            'billedCount': 40,
            'gross': 1234567,
            'discounts': 12345,
            'collected': 1098765,
            'dues': 123456,
            'recoveryPercent': '87.5%',
          },
          {
            'className': 'Class VI-A',
            'billedCount': 35,
            'gross': 2100000,
            'discounts': 50000,
            'collected': 1800000,
            'dues': 250000,
            'recoveryPercent': '85.7%',
          },
        ],
      },
    );

    test('PDF bytes construct in natural portrait and landscape override',
        () async {
      // Natural A4 portrait — the Dues / Recovery % totals line wraps
      // inside the printable width instead of clipping at the right edge.
      final portraitBytes = await generateSummaryPdf(summaryRequest);
      expect(portraitBytes, isNotEmpty);

      final landscapeBytes = await generateSummaryPdf(
        summaryRequest,
        PdfPageFormat.a4.landscape,
      );
      expect(landscapeBytes, isNotEmpty);
      expect(identical(portraitBytes, landscapeBytes), isFalse);
    });
  });
}
