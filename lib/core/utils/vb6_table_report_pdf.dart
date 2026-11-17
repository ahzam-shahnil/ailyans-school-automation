import 'package:flutter/foundation.dart';
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
  // Phase K-6 Run 2 (Part 10 invariant 12): binding-gutter page margins.
  // 40pt left gutter (invariant — unchanged); the right margin is bumped
  // 24 -> 30pt so right-edge amount/status columns never sit on the trim
  // edge. All tables are FlexColumnWidth-based and therefore always fill
  // exactly the printable width below — they can never overflow the page.
  static const double kMarginLeft = 40;
  static const double kMarginTop = 30;
  static const double kMarginRight = 30;
  static const double kMarginBottom = 30;

  /// Printable content width for [format] under this generator's page
  /// margins: `pageFormat.width − marginLeft − marginRight`. Exposed so
  /// tests can assert the per-report width budget.
  static double printableWidth(PdfPageFormat format) =>
      format.width - kMarginLeft - kMarginRight;
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
    /// Phase K Shot 3b-vb6: explicit page format from the preview modal's
    /// Portrait/Landscape toggle. Null falls back to the `landscape` flag.
    PdfPageFormat? pageFormat,
    /// Phase K Shot 3c-columns: indices into headers/rows that may be
    /// dropped when rendering in portrait with more columns than fit.
    List<int> optionalColumnIndices = const [],
  }) async {
    // Rebind to local mutable variables so the optional-column stripping
    // block can reassign them.
    var headersL = headers;
    var rowsL = rows;
    var groupsL = groups;
    var columnAlignsL = columnAligns;

    final doc = pw.Document();
    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final aligns = columnAlignsL ??
        List<Vb6ColumnAlign>.filled(headersL.length, Vb6ColumnAlign.left);

    // Phase K Shot 3b-vb6: the modal's orientation override wins; otherwise
    // the report's own `landscape` flag decides the format.
    final activeFormat = pageFormat ??
        (landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4);

    // ---- Phase K Shot 3c-columns: portrait-mode optional-column stripping --
    // When the report is being rendered in portrait and has more columns
    // than fit comfortably, drop the declared optional columns (e.g.
    // Emergency No + Permanent Address on the class/section roster) so no
    // cell wraps onto multiple lines. (pdf 3.13.x PdfPageFormat has no
    // isLandscape getter — compare width/height.)
    final isLandscapeFormat = activeFormat.width > activeFormat.height;
    if (!isLandscapeFormat &&
        headersL.length > 7 &&
        optionalColumnIndices.isNotEmpty) {
      final optionalSet = optionalColumnIndices.toSet();
      final kept = List<int>.generate(headersL.length, (i) => i)
          .where((i) => !optionalSet.contains(i))
          .toList();
      final sourceAligns = columnAlignsL;
      headersL = kept.map((i) => headersL[i]).toList();
      rowsL = [
        for (final r in rowsL) [for (final i in kept) i < r.length ? r[i] : ''],
      ];
      groupsL = groupsL
          ?.map(
            (g) => Vb6ReportGroup(
              bandTitle: g.bandTitle,
              rows: [
                for (final r in g.rows)
                  [for (final i in kept) i < r.length ? r[i] : ''],
              ],
            ),
          )
          .toList();
      columnAlignsL = kept
          .map((i) => (sourceAligns != null && i < sourceAligns.length)
              ? sourceAligns[i]
              : Vb6ColumnAlign.left)
          .toList();
    }

    // ---- Phase K Shot 4: strict empty-column stripping ----------------------
    // A column is dropped ONLY when its header trims to empty AND every data
    // cell at that index (across [rows] and all [groups]) is empty. Columns
    // with a non-empty header — Balance, Actions, Unpaid Vouchers, blank
    // manual-entry columns, numeric zeros — are ALWAYS kept.
    bool cellHasData(List<List<String>> data, int c) =>
        data.any((r) => c < r.length && r[c].trim().isNotEmpty);

    final keptIndices = <int>[];
    for (var c = 0; c < headersL.length; c++) {
      if (headersL[c].trim().isNotEmpty ||
          cellHasData(rowsL, c) ||
          (groupsL?.any((g) => cellHasData(g.rows, c)) ?? false)) {
        keptIndices.add(c);
      }
    }
    // Defensive: never let a pathological all-empty definition yield a
    // zero-column table — fall back to the unfiltered definition.
    final useFiltering = keptIndices.isNotEmpty;

    // ---- Phase K Shot 4: column-count integrity -----------------------------
    // Every row must carry exactly one cell per header. Short rows are padded
    // with '' and over-long rows truncated so a bad report definition can
    // never crash production PDF generation; debug builds surface a warning.
    void warnShapeMismatch(String source, int actual) {
      if (kDebugMode) {
        debugPrint(
          'Vb6TableReportPdf: $source row has $actual cells but the report '
          'defines ${headersL.length} headers — padded/truncated to match.',
        );
      }
    }

    List<String> normalizeRow(List<String> row, String source) {
      if (row.length == headersL.length) return row;
      warnShapeMismatch(source, row.length);
      final fixed = List<String>.of(row);
      if (fixed.length < headersL.length) {
        fixed.addAll(List<String>.filled(headersL.length - fixed.length, ''));
      } else {
        fixed.length = headersL.length;
      }
      return fixed;
    }

    // ---- Phase K Shot 4: timestamp cleanup ----------------------------------
    // SQLite date storage often surfaces as `10/14/22 00:00:00` or
    // `2022-10-14T00:00:00`; the trailing midnight time is pure noise on a
    // printed report. Strip it from every rendered cell.
    String cleanCell(String v) =>
        v.replaceAll(RegExp(r'[ T]00:00:00$'), '');

    final normalizedRows = [
      for (var i = 0; i < rowsL.length; i++)
        normalizeRow(rowsL[i], 'row $i (rows[$i])'),
    ];
    final normalizedGroups = [
      if (groupsL != null)
        for (var gi = 0; gi < groupsL.length; gi++)
          Vb6ReportGroup(
            bandTitle: groupsL[gi].bandTitle,
            rows: [
              for (var i = 0; i < groupsL[gi].rows.length; i++)
                normalizeRow(
                    groupsL[gi].rows[i], 'group $gi row $i (groups[$gi])'),
            ],
          ),
    ];

    // Apply the kept-column filter + timestamp cleanup to rows and groups.
    List<String> filterRow(List<String> row) => [
          for (final c in keptIndices) cleanCell(row[c]),
        ];

    final keptRows = useFiltering
        ? [for (final row in normalizedRows) filterRow(row)]
        : [for (final row in normalizedRows) [for (final c in row) cleanCell(c)]];
    final keptGroups = [
      for (final g in normalizedGroups)
        Vb6ReportGroup(
          bandTitle: g.bandTitle,
          rows: useFiltering
              ? [for (final row in g.rows) filterRow(row)]
              : [for (final row in g.rows) [for (final c in row) cleanCell(c)]],
        ),
    ];
    final keptHeaders = useFiltering
        ? [for (final c in keptIndices) headersL[c]]
        : headersL;
    final keptAligns = [
      for (final c in useFiltering
          ? keptIndices
          : List<int>.generate(headersL.length, (i) => i))
        c < aligns.length ? aligns[c] : Vb6ColumnAlign.left,
    ];

    // Column-count integrity assertions (debug builds only; release code
    // above already pads/truncates so these hold by construction).
    assert(keptHeaders.length ==
        (useFiltering ? keptIndices.length : headersL.length));
    for (final row in keptRows) {
      assert(row.length == keptHeaders.length);
    }
    for (final g in keptGroups) {
      for (final row in g.rows) {
        assert(row.length == keptHeaders.length);
      }
    }

    // ---- Phase K Shot 4: table layout polish --------------------------------
    // Content-aware column weights: wider columns for long content, but
    // clamped so a single wide column can never starve the rest of the table.
    int columnMaxLen(int c) {
      var maxLen = keptHeaders[c].trim().length;
      for (final row in keptRows) {
        if (c < row.length && row[c].trim().length > maxLen) {
          maxLen = row[c].trim().length;
        }
      }
      for (final g in keptGroups) {
        for (final row in g.rows) {
          if (c < row.length && row[c].trim().length > maxLen) {
            maxLen = row[c].trim().length;
          }
        }
      }
      return maxLen;
    }

    final keptColumnWidths = <int, pw.TableColumnWidth>{
      for (var c = 0; c < keptHeaders.length; c++)
        c: pw.FlexColumnWidth((columnMaxLen(c) / 8.0).clamp(0.7, 3.2)),
    };

    pw.Alignment alignFor(int i) {
      if (i >= keptAligns.length) return pw.Alignment.centerLeft;
      return switch (keptAligns[i]) {
        Vb6ColumnAlign.right => pw.Alignment.centerRight,
        Vb6ColumnAlign.center => pw.Alignment.center,
        Vb6ColumnAlign.left => pw.Alignment.centerLeft,
      };
    }

    pw.Widget tableFor(List<List<String>> data) => pw.TableHelper.fromTextArray(
          headers: keptHeaders,
          data: data,
          columnWidths: keptColumnWidths,
          border: pw.TableBorder.all(
            color: ReportTheme.borderRuleColor,
            width: 0.5,
          ),
          headerStyle:
              ReportTheme.tableHeaderStyle.copyWith(fontSize: 8.5),
          headerDecoration: const pw.BoxDecoration(
            color: ReportTheme.primaryColor,
          ),
          headerAlignments: {
            for (var i = 0; i < keptHeaders.length; i++) i: alignFor(i),
          },
          headerPadding: const pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 5,
          ),
          cellStyle: ReportTheme.tableCellStyle.copyWith(fontSize: 8.0),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: {
            for (var i = 0; i < keptHeaders.length; i++) i: alignFor(i),
          },
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 3.5,
          ),
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
                // Phase K-6 Run 2: Expanded-wrapped — the title + filter
                // subtitle measured ~95% of the portrait printable width
                // (within the K-1 5% cross-platform danger zone), so they
                // wrap instead of overflowing the right page edge.
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      title.toUpperCase(),
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 10,
                        color: ReportTheme.primaryColor,
                      ),
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    pw.Expanded(
                      child: pw.Text(
                        subtitle,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 9,
                          color: ReportTheme.secondaryColor,
                        ),
                        textAlign: pw.TextAlign.right,
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
          tableFor(rowsL),
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

    if (groupsL == null || groupsL.isEmpty) {
      // Current behavior: no grouping. Single MultiPage with all rows.
      doc.addPage(
        pw.MultiPage(
          pageFormat: activeFormat,
          margin: const pw.EdgeInsets.fromLTRB(
            kMarginLeft,
            kMarginTop,
            kMarginRight,
            kMarginBottom,
          ),
          // Whole-school rosters legitimately span many pages; the package
          // default of 20 pages is far too low for institutional reports.
          maxPages: 2000,
          header: buildHeader,
          footer: buildFooter,
          build: (context) {
            return [
              tableFor(keptRows),
              pw.SizedBox(height: 8),
            ];
          },
        ),
      );
    } else if (!breakPerGroup) {
      // Current behavior: all groups on shared pages.
      doc.addPage(
        pw.MultiPage(
          pageFormat: activeFormat,
          margin: const pw.EdgeInsets.fromLTRB(
            kMarginLeft,
            kMarginTop,
            kMarginRight,
            kMarginBottom,
          ),
          // Whole-school rosters legitimately span many pages; the package
          // default of 20 pages is far too low for institutional reports.
          maxPages: 2000,
          header: buildHeader,
          footer: buildFooter,
          build: (context) => buildBody(keptGroups),
        ),
      );
    } else {
      // NEW (Phase K Shot 3): one MultiPage per group — each class/section
      // band starts on a fresh page.
      for (final group in keptGroups) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: activeFormat,
            margin: const pw.EdgeInsets.fromLTRB(
            kMarginLeft,
            kMarginTop,
            kMarginRight,
            kMarginBottom,
          ),
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
