import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 portrait Exam Performance Summary report PDF.
class ExamSummaryPdfGenerator {
  ExamSummaryPdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates an exam-wide subject-wise performance summary table PDF.
  ///
  /// [subjects] contains map entries with:
  ///   - 'subject' or 'subjectName' (String)
  ///   - 'totalStudents' or 'total' (int/num)
  ///   - 'passed' (int/num)
  ///   - 'failed' (int/num)
  ///   - 'passPercentage' or 'passPct' or 'percentage' (num/String?)
  static Future<Uint8List> generate({
    required String examName,
    required List<Map<String, dynamic>> subjects,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          branchName: branchName,
          branchAddress: branchAddress,
          examName: examName,
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        footer: (context) => _buildFooter(
          context: context,
          regularFont: regularFont,
          italicFont: italicFont,
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildTable(
            subjects: subjects,
            boldFont: boldFont,
            regularFont: regularFont,
          ),
          pw.SizedBox(height: 24),
          _buildSignatures(regularFont: regularFont),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Header & Footer
  // ---------------------------------------------------------------------------

  static pw.Widget _buildHeader({
    required String branchName,
    required String branchAddress,
    required String examName,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          branchName.isNotEmpty ? branchName.toUpperCase() : 'SCHOOL AUTOMATION',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            color: ReportTheme.primaryColor,
          ),
          textAlign: pw.TextAlign.center,
        ),
        if (branchAddress.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            branchAddress,
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 8,
              color: ReportTheme.secondaryColor,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: const pw.BoxDecoration(
            color: ReportTheme.bannerBgColor,
            border: pw.Border(
              top: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
              bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'EXAM PERFORMANCE SUMMARY',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: ReportTheme.primaryColor,
                ),
              ),
              pw.Text(
                'Examination: $examName',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 9,
                  color: ReportTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required pw.Font regularFont,
    required pw.Font italicFont,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: ReportTheme.borderRuleColor, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${ReportTheme.formatDate(DateTime.now())}',
            style: pw.TextStyle(
              font: italicFont,
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table
  // ---------------------------------------------------------------------------

  static pw.Widget _buildTable({
    required List<Map<String, dynamic>> subjects,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    const colSr = 0;
    const colSubject = 1;
    const colTotal = 2;
    const colPassed = 3;
    const colFailed = 4;
    const colPct = 5;

    final headers = ['#', 'Subject', 'Total Students', 'Passed', 'Failed', 'Pass %'];

    int sumTotal = 0;
    int sumPassed = 0;
    int sumFailed = 0;

    final rows = <List<String>>[];
    for (int i = 0; i < subjects.length; i++) {
      final s = subjects[i];
      final name = (s['subject'] ?? s['subjectName'] ?? 'N/A').toString();
      final total = ((s['totalStudents'] ?? s['total'] ?? 0) as num).toInt();
      final passed = ((s['passed'] ?? 0) as num).toInt();
      final failed = ((s['failed'] ?? 0) as num).toInt();

      sumTotal += total;
      sumPassed += passed;
      sumFailed += failed;

      String pctStr;
      if (s.containsKey('passPercentage') || s.containsKey('passPct') || s.containsKey('percentage')) {
        final rawPct = s['passPercentage'] ?? s['passPct'] ?? s['percentage'];
        pctStr = rawPct is num ? '${rawPct.toStringAsFixed(1)}%' : rawPct.toString();
      } else {
        final pct = total > 0 ? (passed / total) * 100.0 : 0.0;
        pctStr = '${pct.toStringAsFixed(1)}%';
      }

      rows.add([(i + 1).toString(), name, total.toString(), passed.toString(), failed.toString(), pctStr]);
    }

    final overallPct = sumTotal > 0 ? (sumPassed / sumTotal) * 100.0 : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
            font: boldFont,
            fontSize: 8,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: ReportTheme.tableHeaderBg,
          ),
          cellStyle: pw.TextStyle(
            font: regularFont,
            fontSize: 8,
          ),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: ReportTheme.borderRuleColor, width: 0.5),
            ),
          ),
          columnWidths: {
            colSr: const pw.FixedColumnWidth(28),
            colSubject: const pw.FlexColumnWidth(3),
            colTotal: const pw.FixedColumnWidth(75),
            colPassed: const pw.FixedColumnWidth(60),
            colFailed: const pw.FixedColumnWidth(60),
            colPct: const pw.FixedColumnWidth(60),
          },
          cellAlignments: {
            colSr: pw.Alignment.center,
            colSubject: pw.Alignment.centerLeft,
            colTotal: pw.Alignment.centerRight,
            colPassed: pw.Alignment.centerRight,
            colFailed: pw.Alignment.centerRight,
            colPct: pw.Alignment.centerRight,
          },
        ),
        // Total / Summary Row
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const pw.BoxDecoration(
            color: ReportTheme.tableRowAltBg,
            border: pw.Border(
              top: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.0),
              bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.0),
            ),
          ),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 28),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  'Total / Overall',
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ),
              pw.SizedBox(
                width: 75,
                child: pw.Text(
                  sumTotal.toString(),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ),
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  sumPassed.toString(),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8,
                    color: ReportTheme.successTextColor,
                  ),
                ),
              ),
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  sumFailed.toString(),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8,
                    color: ReportTheme.dangerTextColor,
                  ),
                ),
              ),
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  '${overallPct.toStringAsFixed(1)}%',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Signatures
  // ---------------------------------------------------------------------------

  static pw.Widget _buildSignatures({required pw.Font regularFont}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildSignBlock(label: 'Prepared By', regularFont: regularFont),
        _buildSignBlock(label: 'Controller of Examinations', regularFont: regularFont),
        _buildSignBlock(label: 'Principal', regularFont: regularFont),
      ],
    );
  }

  static pw.Widget _buildSignBlock({
    required String label,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 130,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 8,
            color: ReportTheme.secondaryColor,
          ),
        ),
      ],
    );
  }
}
