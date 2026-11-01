import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 portrait Exam Award List report PDF sorted by total obtained marks descending.
class ExamAwardListPdfGenerator {
  ExamAwardListPdfGenerator._();

  /// Generates the complete PDF document as bytes.
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

    // Sort students by totalObtained descending (null-safe)
    final sortedStudents = List<Map<String, dynamic>>.from(students);
    sortedStudents.sort((a, b) {
      final obtA = (a['totalObtained'] ?? a['obtained'] ?? a['obtainedMarks'] ?? 0) as num;
      final obtB = (b['totalObtained'] ?? b['obtained'] ?? b['obtainedMarks'] ?? 0) as num;
      return obtB.compareTo(obtA);
    });

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
          pw.SizedBox(height: 10),
          _buildTable(
            students: sortedStudents,
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

  static pw.Widget _buildHeader({
    required String branchName,
    required String branchAddress,
    required String examName,
    required String className,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final titleText = 'EXAM AWARD LIST - $examName ($className)';

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
              fontSize: 8.5,
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
                titleText,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: ReportTheme.primaryColor,
                ),
              ),
              pw.Text(
                'Class: $className',
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
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable({
    required List<Map<String, dynamic>> students,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    const headers = [
      'Rank',
      'Roll No',
      'Student Name',
      'Total Obtained',
      'Total Max',
      'Percentage',
      'Grade',
    ];

    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(40),
        1: pw.FixedColumnWidth(55),
        2: pw.FlexColumnWidth(3.0),
        3: pw.FixedColumnWidth(80),
        4: pw.FixedColumnWidth(65),
        5: pw.FixedColumnWidth(70),
        6: pw.FixedColumnWidth(50),
      },
      border: pw.TableBorder.all(
        color: ReportTheme.borderRuleColor,
        width: 0.5,
      ),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: ReportTheme.tableHeaderBg),
          children: headers.map((h) {
            final isRight = h == 'Total Obtained' ||
                h == 'Total Max' ||
                h == 'Percentage';
            final isCenter = h == 'Rank' || h == 'Roll No' || h == 'Grade';
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              alignment: isRight
                  ? pw.Alignment.centerRight
                  : (isCenter ? pw.Alignment.center : pw.Alignment.centerLeft),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 8.5,
                  color: PdfColors.white,
                ),
              ),
            );
          }).toList(),
        ),

        // Data Rows
        ...students.asMap().entries.map((entry) {
          final index = entry.key;
          final s = entry.value;

          final rank = '${index + 1}';
          final rollNo = (s['rollNo'] ?? s['ClassRollNo'] ?? s['roll'] ?? '—').toString();
          final name = (s['studentName'] ?? s['name'] ?? s['fullName'] ?? '—').toString();
          final obtVal = s['totalObtained'] ?? s['obtained'] ?? s['obtainedMarks'] ?? 0;
          final maxVal = s['totalMax'] ?? s['total'] ?? s['maxMarks'] ?? 100;
          final pctVal = s['percentage'] ?? (maxVal is num && maxVal > 0 && obtVal is num ? (obtVal / maxVal) * 100 : 0.0);
          final grade = (s['grade'] ?? '—').toString();

          final obtStr = obtVal is num ? (obtVal % 1 == 0 ? obtVal.toInt().toString() : obtVal.toStringAsFixed(1)) : obtVal.toString();
          final maxStr = maxVal is num ? (maxVal % 1 == 0 ? maxVal.toInt().toString() : maxVal.toStringAsFixed(1)) : maxVal.toString();
          final pctStr = pctVal is num ? '${pctVal.toStringAsFixed(1)}%' : '$pctVal%';

          final isAlt = index.isOdd;
          final rowBg = isAlt ? ReportTheme.tableRowAltBg : PdfColors.white;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  rank,
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  rollNo,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  name,
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  obtStr,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  maxStr,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  pctStr,
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  grade,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8,
                    color: grade == 'F'
                        ? ReportTheme.dangerTextColor
                        : ReportTheme.primaryColor,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSignatures({required pw.Font regularFont}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signatureBox(label: 'Class Teacher', regularFont: regularFont),
        _signatureBox(label: 'Exam Incharge', regularFont: regularFont),
        _signatureBox(label: 'Principal', regularFont: regularFont),
      ],
    );
  }

  static pw.Widget _signatureBox({
    required String label,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      children: [
        pw.Container(
          width: 130,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: ReportTheme.borderRuleColor, width: 0.8),
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
