import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 portrait Class Subject Syllabus PDF document.
class ClassSyllabusPdfGenerator {
  ClassSyllabusPdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates a curriculum syllabus PDF table for a class.
  ///
  /// [subjects] contains map elements with:
  ///   - subjectName / subjName (String)
  ///   - teacherName / tName (String)
  ///   - totalMarks (num / int)
  ///   - practicalMarks / totalPracticalMarks (num / int)
  static Future<Uint8List> generate({
    required String className,
    required String sessionYear,
    required List<Map<String, dynamic>> subjects,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    // Calculate totals
    int grandTotalTheory = 0;
    int grandTotalPractical = 0;

    for (final s in subjects) {
      final tMarks = (s['totalMarks'] as num?)?.toInt() ?? 0;
      final pMarks = (s['practicalMarks'] ?? s['totalPracticalMarks']) as num?;
      grandTotalTheory += tMarks;
      grandTotalPractical += (pMarks?.toInt() ?? 0);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildHeader(
          branchName: branchName,
          branchAddress: branchAddress,
          className: className,
          sessionYear: sessionYear,
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        footer: (context) =>
            ReportTheme.buildStandardFooter(context, branchName: branchName),
        build: (context) => [
          pw.SizedBox(height: 12),

          // ── Data Table ──
          pw.Table(
            border: pw.TableBorder.all(
              color: ReportTheme.borderRuleColor,
              width: 0.6,
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(30), // #
              1: pw.FlexColumnWidth(3), // Subject Name
              2: pw.FlexColumnWidth(3), // Teacher Name
              3: pw.FlexColumnWidth(1.5), // Total Marks
              4: pw.FlexColumnWidth(1.5), // Practical Marks
              5: pw.FlexColumnWidth(1.5), // Combined
            },
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: ReportTheme.tableHeaderBg,
                ),
                children: [
                  _headerCell('#', boldFont, align: pw.TextAlign.center),
                  _headerCell('Subject Name', boldFont),
                  _headerCell('Teacher', boldFont),
                  _headerCell(
                    'Total Marks',
                    boldFont,
                    align: pw.TextAlign.right,
                  ),
                  _headerCell(
                    'Practical Marks',
                    boldFont,
                    align: pw.TextAlign.right,
                  ),
                  _headerCell('Combined', boldFont, align: pw.TextAlign.right),
                ],
              ),

              // Data Rows
              if (subjects.isEmpty)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(16),
                      child: pw.Center(
                        child: pw.Text(
                          'No subjects configured for this class.',
                          style: pw.TextStyle(
                            font: italicFont,
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                    ),
                    pw.Container(),
                    pw.Container(),
                    pw.Container(),
                    pw.Container(),
                    pw.Container(),
                  ],
                )
              else
                ...subjects.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;

                  final subjectName =
                      (s['subjectName'] ??
                              s['subjName'] ??
                              'Subject ${idx + 1}')
                          as String;
                  final teacherName =
                      (s['teacherName'] ?? s['tName'] ?? 'Unassigned')
                          as String;
                  final totalMarks = (s['totalMarks'] as num?)?.toInt() ?? 0;
                  final practicalMarks =
                      ((s['practicalMarks'] ?? s['totalPracticalMarks'])
                              as num?)
                          ?.toInt() ??
                      0;
                  final combined = totalMarks + practicalMarks;

                  final isEven = idx.isEven;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven
                          ? PdfColors.white
                          : ReportTheme.tableRowAltBg,
                    ),
                    children: [
                      _dataCell(
                        '${idx + 1}',
                        regularFont,
                        align: pw.TextAlign.center,
                      ),
                      _dataCell(subjectName, regularFont, bold: true),
                      _dataCell(teacherName, regularFont),
                      _dataCell(
                        '$totalMarks',
                        regularFont,
                        align: pw.TextAlign.right,
                      ),
                      _dataCell(
                        '$practicalMarks',
                        regularFont,
                        align: pw.TextAlign.right,
                      ),
                      _dataCell(
                        '$combined',
                        boldFont,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }),

              // Total Summary Row
              if (subjects.isNotEmpty)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: ReportTheme.bannerBgColor,
                  ),
                  children: [
                    _dataCell('', boldFont),
                    _dataCell('TOTAL ALLOCATED MARKS', boldFont, bold: true),
                    _dataCell('${subjects.length} Subjects', regularFont),
                    _dataCell(
                      '$grandTotalTheory',
                      boldFont,
                      align: pw.TextAlign.right,
                    ),
                    _dataCell(
                      '$grandTotalPractical',
                      boldFont,
                      align: pw.TextAlign.right,
                    ),
                    _dataCell(
                      '${grandTotalTheory + grandTotalPractical}',
                      boldFont,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Signatures ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signatureBlock(
                label: 'Incharge Curriculum / Academic Coord',
                boldFont: boldFont,
                regularFont: regularFont,
              ),
              _signatureBlock(
                label: 'Examination Controller',
                boldFont: boldFont,
                regularFont: regularFont,
              ),
              _signatureBlock(
                label: 'Principal',
                boldFont: boldFont,
                regularFont: regularFont,
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static pw.Widget _buildHeader({
    required String branchName,
    required String branchAddress,
    required String className,
    required String sessionYear,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                branchName,
                style: ReportTheme.titleStyle,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                branchAddress,
                style: ReportTheme.subtitleStyle,
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: ReportTheme.borderRuleColor, thickness: 1.0),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CLASS SUBJECT SYLLABUS: $className',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 12,
                color: ReportTheme.primaryColor,
              ),
            ),
            pw.Text(
              'Academic Session: $sessionYear',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                color: ReportTheme.secondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _headerCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _dataCell(
    String text,
    pw.Font font, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _signatureBlock({
    required String label,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      children: [
        pw.Container(width: 140, height: 1, color: ReportTheme.borderRuleColor),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 8)),
        pw.Text(
          'Signature & Stamp',
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 7.5,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }
}
