import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// One grouped band in a report (e.g. a Class/Section block in the student
/// roster). The band title is rendered above the group's rows, VB6 style:
/// `Class: <CName> | Section: <SecName> | No of students: <N>`.
class Vb6ReportGroup {
  final String bandTitle;
  final List<List<String>> rows;

  const Vb6ReportGroup({required this.bandTitle, required this.rows});
}

/// Column alignment for a single report column.
enum Vb6ColumnAlign { left, right, center }

/// Generic VB6-style tabular report PDF used by the Reports Hub one-click
/// launcher: school header, title banner with the active session/month
/// subtitle, optional `Class / Section / No of students` band headers, zebra
/// table, and the standard report footer.
class Vb6TableReportPdf {
  static Future<Uint8List> generate({
    required String title,
    required String subtitle,
    required String branchName,
    required String branchAddress,
    required List<String> headers,
    required List<List<String>> rows,
    List<Vb6ReportGroup>? groups,
    List<Vb6ColumnAlign>? columnAligns,
    bool landscape = false,
  }) async {
    final doc = pw.Document();
    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final aligns = columnAligns ??
        List<Vb6ColumnAlign>.filled(headers.length, Vb6ColumnAlign.left);

    pw.Alignment alignFor(int i) {
      if (i >= aligns.length) return pw.Alignment.centerLeft;
      return switch (aligns[i]) {
        Vb6ColumnAlign.right => pw.Alignment.centerRight,
        Vb6ColumnAlign.center => pw.Alignment.center,
        Vb6ColumnAlign.left => pw.Alignment.centerLeft,
      };
    }

    pw.Widget tableFor(List<List<String>> data) => pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(
            color: ReportTheme.borderRuleColor,
            width: 0.5,
          ),
          headerStyle: ReportTheme.tableHeaderStyle,
          headerDecoration: const pw.BoxDecoration(
            color: ReportTheme.primaryColor,
          ),
          headerAlignments: {
            for (var i = 0; i < headers.length; i++) i: alignFor(i),
          },
          cellStyle: ReportTheme.tableCellStyle,
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: {
            for (var i = 0; i < headers.length; i++) i: alignFor(i),
          },
          rowDecoration: const pw.BoxDecoration(
            color: ReportTheme.tableRowAltBg,
          ),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        // Whole-school rosters legitimately span many pages; the package default
        // of 20 pages is far too low for institutional reports.
        maxPages: 2000,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              branchName.isNotEmpty ? branchName.toUpperCase() : 'SCHOOL',
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
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 8,
              ),
              decoration: const pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border(
                  top: pw.BorderSide(
                    color: ReportTheme.primaryColor,
                    width: 1.5,
                  ),
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
                    title.toUpperCase(),
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    pw.Text(
                      subtitle,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 9,
                        color: ReportTheme.secondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => ReportTheme.buildStandardFooter(
          context,
          branchName: branchName,
        ),
        build: (context) {
          final bandGroups = groups;
          if (bandGroups == null || bandGroups.isEmpty) {
            return [
              tableFor(rows),
              pw.SizedBox(height: 8),
            ];
          }
          return [
            for (final group in bandGroups) ...[
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 6,
                ),
                decoration: const pw.BoxDecoration(
                  color: ReportTheme.bannerBgColor,
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: ReportTheme.primaryColor,
                      width: 0.8,
                    ),
                  ),
                ),
                child: pw.Text(
                  group.bandTitle,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 9,
                    color: ReportTheme.primaryColor,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              tableFor(group.rows),
              pw.SizedBox(height: 10),
            ],
          ];
        },
      ),
    );

    return doc.save();
  }
}
