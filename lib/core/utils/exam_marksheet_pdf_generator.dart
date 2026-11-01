import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 portrait Exam Marksheet / Award List report PDF.
class ExamMarksheetPdfGenerator {
  ExamMarksheetPdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates a class-wide exam marksheet / award list PDF.
  ///
  /// [students] contains map entries with:
  ///   - 'rollNo' (int or String)
  ///   - 'studentName' or 'name' (String)
  ///   - 'subject' or 'subjectName' (String?)
  ///   - 'obtained' or 'obtainedMarks' or 'totalObtained' (num?)
  ///   - 'total' or 'totalMarks' or 'totalMax' (num?)
  ///   - 'grade' (String?)
  ///   - 'isAbsent' (bool?)
  static Future<Uint8List> generate({
    required String examName,
    required String className,
    required List<Map<String, dynamic>> students,
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
          className: className,
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
            students: students,
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
    required String className,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          branchName.isNotEmpty
              ? branchName.toUpperCase()
              : 'SCHOOL AUTOMATION',
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
              bottom: pw.BorderSide(
                color: ReportTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'EXAM MARKSHEET / AWARD LIST',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: ReportTheme.primaryColor,
                ),
              ),
              pw.Text(
                'Exam: $examName | Class: $className',
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
    required List<Map<String, dynamic>> students,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    const colRoll = 0;
    const colName = 1;
    const colSubject = 2;
    const colObt = 3;
    const colTotal = 4;
    const colGrade = 5;

    final headers = [
      'Roll #',
      'Student Name',
      'Subject',
      'Obtained',
      'Total',
      'Grade',
    ];

    final rows = <List<String>>[];
    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      final roll = (s['rollNo'] ?? (i + 1)).toString();
      final name = (s['studentName'] ?? s['name'] ?? 'N/A').toString();
      final subject = (s['subject'] ?? s['subjectName'] ?? '').toString();
      final isAbsent = s['isAbsent'] == true;
      final obtVal = s['obtained'] ?? s['obtainedMarks'] ?? s['totalObtained'];
      final obt = isAbsent ? 'ABS' : (obtVal != null ? obtVal.toString() : '-');
      final totVal = s['total'] ?? s['totalMarks'] ?? s['totalMax'];
      final total = totVal != null ? totVal.toString() : '-';
      final grade = (s['grade'] ?? (isAbsent ? 'ABS' : '')).toString();

      rows.add([roll, name, subject, obt, total, grade]);
    }

    return pw.TableHelper.fromTextArray(
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
      cellStyle: pw.TextStyle(font: regularFont, fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: ReportTheme.borderRuleColor, width: 0.5),
        ),
      ),
      columnWidths: {
        colRoll: const pw.FixedColumnWidth(40),
        colName: const pw.FlexColumnWidth(3),
        colSubject: const pw.FlexColumnWidth(2),
        colObt: const pw.FixedColumnWidth(55),
        colTotal: const pw.FixedColumnWidth(50),
        colGrade: const pw.FixedColumnWidth(45),
      },
      cellAlignments: {
        colRoll: pw.Alignment.center,
        colName: pw.Alignment.centerLeft,
        colSubject: pw.Alignment.centerLeft,
        colObt: pw.Alignment.centerRight,
        colTotal: pw.Alignment.centerRight,
        colGrade: pw.Alignment.center,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Signatures
  // ---------------------------------------------------------------------------

  static pw.Widget _buildSignatures({required pw.Font regularFont}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildSignBlock(label: 'Subject Teacher', regularFont: regularFont),
        _buildSignBlock(
          label: 'Incharge Examination',
          regularFont: regularFont,
        ),
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
          width: 120,
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
