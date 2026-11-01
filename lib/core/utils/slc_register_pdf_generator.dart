import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 landscape School Leaving Certificate (SLC) Register PDF document.
class SlcRegisterPdfGenerator {
  SlcRegisterPdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates a landscape table of all withdrawn/leaving students.
  ///
  /// [leavers] contains map items with:
  ///   - regId / stuRegId (dynamic)
  ///   - name / studentName (String)
  ///   - fatherName / fName (String)
  ///   - classLeft / className (String)
  ///   - dateLeft / leavingDate (String)
  ///   - reason / termOfLeaving / term (String)
  static Future<Uint8List> generate({
    required String sessionYear,
    required List<Map<String, dynamic>> leavers,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 500,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(
          branchName: branchName,
          branchAddress: branchAddress,
          sessionYear: sessionYear,
          leaversCount: leavers.length,
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        footer: (context) =>
            ReportTheme.buildStandardFooter(context, branchName: branchName),
        build: (context) => [
          pw.SizedBox(height: 10),

          // ── Leavers Register Table ──
          pw.Table(
            border: pw.TableBorder.all(
              color: ReportTheme.borderRuleColor,
              width: 0.6,
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(30), // #
              1: pw.FixedColumnWidth(60), // Reg ID
              2: pw.FlexColumnWidth(3), // Student Name
              3: pw.FlexColumnWidth(3), // Father Name
              4: pw.FlexColumnWidth(2), // Class Left
              5: pw.FlexColumnWidth(2), // Date Left
              6: pw.FlexColumnWidth(3), // Reason for Leaving
            },
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: ReportTheme.tableHeaderBg,
                ),
                children: [
                  _headerCell('#', boldFont, align: pw.TextAlign.center),
                  _headerCell('Reg ID', boldFont, align: pw.TextAlign.center),
                  _headerCell('Student Name', boldFont),
                  _headerCell('Father Name', boldFont),
                  _headerCell('Class Left', boldFont),
                  _headerCell(
                    'Date Left',
                    boldFont,
                    align: pw.TextAlign.center,
                  ),
                  _headerCell('Reason / Term', boldFont),
                ],
              ),

              // Data Rows
              if (leavers.isEmpty)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(16),
                      child: pw.Center(
                        child: pw.Text(
                          'No school leaving records found for session $sessionYear.',
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
                    pw.Container(),
                  ],
                )
              else
                ...leavers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final l = entry.value;

                  final regId =
                      (l['regId'] ??
                              l['stuRegId'] ??
                              l['StuRegID'] ??
                              l['Stu_RegID'] ??
                              '-')
                          .toString();
                  final studentName =
                      (l['name'] ??
                              l['studentName'] ??
                              l['stuName'] ??
                              l['Stu_Name'] ??
                              'Student $regId')
                          .toString();
                  final fatherName =
                      (l['fatherName'] ??
                              l['father'] ??
                              l['fName'] ??
                              l['F_Name'] ??
                              '-')
                          .toString();
                  final classLeft =
                      (l['classLeft'] ??
                              l['className'] ??
                              l['leftClass'] ??
                              l['LeftClass'] ??
                              l['cName'] ??
                              l['CName'] ??
                              '-')
                          .toString();
                  final dateLeft =
                      (l['dateLeft'] ??
                              l['leavingDate'] ??
                              l['leftDate'] ??
                              l['LeftDate'] ??
                              '-')
                          .toString();
                  final reason =
                      (l['reason'] ??
                              l['termOfLeaving'] ??
                              l['TermOfLeavign'] ??
                              l['term'] ??
                              '-')
                          .toString();

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
                      _dataCell(
                        regId,
                        regularFont,
                        align: pw.TextAlign.center,
                        bold: true,
                      ),
                      _dataCell(studentName, regularFont, bold: true),
                      _dataCell(fatherName, regularFont),
                      _dataCell(classLeft, regularFont),
                      _dataCell(
                        dateLeft,
                        regularFont,
                        align: pw.TextAlign.center,
                      ),
                      _dataCell(reason, regularFont),
                    ],
                  );
                }),
            ],
          ),

          pw.SizedBox(height: 18),

          // ── Pinned End-of-Register Summary Banner ──
          if (leavers.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border.all(
                  color: ReportTheme.borderRuleColor,
                  width: 0.8,
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Recorded Student Withdrawals: ${leavers.length}',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                  pw.Text(
                    'Official Clearance & Archival Log',
                    style: pw.TextStyle(
                      font: italicFont,
                      fontSize: 9,
                      color: ReportTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
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
    required String sessionYear,
    required int leaversCount,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(branchName, style: ReportTheme.titleStyle),
                pw.SizedBox(height: 2),
                pw.Text(branchAddress, style: ReportTheme.subtitleStyle),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'SCHOOL LEAVING CERTIFICATE REGISTER',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    color: ReportTheme.primaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Academic Session: $sessionYear  |  Total Leavers: $leaversCount',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 9,
                    color: ReportTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: ReportTheme.borderRuleColor, thickness: 1.0),
      ],
    );
  }

  static pw.Widget _headerCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.white),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black),
      ),
    );
  }
}
