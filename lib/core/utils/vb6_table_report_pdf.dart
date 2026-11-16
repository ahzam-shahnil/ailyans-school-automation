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
    /// Phase K Shot 3: when true and [groups] is non-empty, each group
    /// (e.g. each Class/Section band) starts on its own fresh page instead of
    /// sharing pages with neighbouring bands. Only enabled for the
    /// `student_class_sec_wise` roster report.
    bool breakPerGroup = false,
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

    // Header closure — extracted verbatim so every page (single-MultiPage or
    // per-group MultiPage) renders the identical school header + title banner.
    pw.Widget buildHeader(pw.Context context) => pw.Column(
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
        );

    // Footer closure — identical on every page.
    pw.Widget buildFooter(pw.Context context) => ReportTheme.buildStandardFooter(
          context,
          branchName: branchName,
        );

    // Body builder — extracted verbatim from the previous `build:` closure.
    // [groupsForPage] scopes which group bands render on this page: all
    // groups for shared-page mode, exactly one group for break-per-group mode.
    List<pw.Widget> buildBody(List<Vb6ReportGroup> groupsForPage) {
      if (groupsForPage.isEmpty) {
        return [
          tableFor(rows),
          pw.SizedBox(height: 8),
        ];
      }
      return [
        for (final group in groupsForPage) ...[
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
    }

    if (groups == null || groups.isEmpty) {
      // Current behavior: no grouping. Single MultiPage with all rows.
      doc.addPage(
        pw.MultiPage(
          pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          // Whole-school rosters legitimately span many pages; the package
          // default of 20 pages is far too low for institutional reports.
          maxPages: 2000,
          header: buildHeader,
          footer: buildFooter,
          build: (context) {
            return [
              tableFor(rows),
              pw.SizedBox(height: 8),
            ];
          },
        ),
      );
    } else if (!breakPerGroup) {
      // Current behavior: all groups on shared pages.
      doc.addPage(
        pw.MultiPage(
          pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          // Whole-school rosters legitimately span many pages; the package
          // default of 20 pages is far too low for institutional reports.
          maxPages: 2000,
          header: buildHeader,
          footer: buildFooter,
          build: (context) => buildBody(groups),
        ),
      );
    } else {
      // NEW (Phase K Shot 3): one MultiPage per group — each class/section
      // band starts on a fresh page.
      for (final group in groups) {
        doc.addPage(
          pw.MultiPage(
            pageFormat:
                landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            // Whole-school rosters legitimately span many pages; the package
            // default of 20 pages is far too low for institutional reports.
            maxPages: 2000,
            header: buildHeader,
            footer: buildFooter,
            build: (context) => buildBody([group]),
          ),
        );
      }
    }

    return doc.save();
  }
}
