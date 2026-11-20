// ignore_for_file: public_member_api_docs
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/theme/app_theme_tokens.dart';
import '../../repositories/logo_repository.dart';
import 'voucher_pdf_generator.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

class DefaulterListRow {
  final String voucherMasId;
  final int stuRegId;
  final String studentName;
  final String? fatherName;
  final String? mobile1;
  final String className;
  final String sectionName;
  final int? rollNo;
  final String forMonth;
  final int subtotal;
  final int discount;
  final int paidAmt;
  final int netPayable;
  final int balance;
  final String isPaid;
  final DateTime? dueDate;
  final int daysOverdue;

  const DefaulterListRow({
    required this.voucherMasId,
    required this.stuRegId,
    required this.studentName,
    this.fatherName,
    this.mobile1,
    required this.className,
    required this.sectionName,
    this.rollNo,
    required this.forMonth,
    required this.subtotal,
    required this.discount,
    required this.paidAmt,
    required this.netPayable,
    int? balance,
    required this.isPaid,
    this.dueDate,
    required this.daysOverdue,
  }) : balance = balance ?? netPayable;
}

class DefaulterListFilterSummary {
  final String sessionYr;
  final String? classFilter;
  final int totalDefaulters;
  final int uniqueStudents;
  final int totalOutstanding;
  final String reportMonth;
  final DateTime generatedAt;

  int get unpaidVoucherCount => totalDefaulters;
  int get defaulterStudentCount => uniqueStudents;

  const DefaulterListFilterSummary({
    required this.sessionYr,
    this.classFilter,
    required this.totalDefaulters,
    required this.uniqueStudents,
    required this.totalOutstanding,
    required this.reportMonth,
    required this.generatedAt,
  });
}

class DefaulterClassGroup {
  final String classLabel;
  final List<DefaulterListRow> rows;
  final int subtotal;

  const DefaulterClassGroup({
    required this.classLabel,
    required this.rows,
    required this.subtotal,
  });
}

// ============================================================================
// PDF GENERATOR
// ============================================================================

class DefaulterListPdfGenerator {
  static const PdfColor _navy = PdfColor.fromInt(0xFF1E3A8A);

  // Phase K-6 Run 2 (Part 10 invariant 12): uniform binding-gutter margins
  // across the preview reports — 40pt left gutter, right margin at least
  // 30pt so right-edge total/balance columns never sit on the trim edge.
  static const double kMarginLeft = 40;
  static const double kMarginTop = 30;
  static const double kMarginRight = 30;
  static const double kMarginBottom = 30;

  // Run G: Tightened side margins for A4 portrait to maximize usable table width.
  static const double kPortraitMarginLeft = 18;
  static const double kPortraitMarginRight = 18;

  /// Printable content width for [format] under this generator's page
  /// margins: `pageFormat.width − marginLeft − marginRight`. Exposed so
  /// tests can assert every table's column budget stays inside it.
  static double printableWidth(PdfPageFormat format) =>
      format.width - kMarginLeft - kMarginRight;
  static const PdfColor _lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _headerBg = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor _dangerBorder = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor _dangerBg = PdfColor.fromInt(0xFFFEF2F2);
  static const PdfColor _dangerText = PdfColor.fromInt(0xFFB91C1C);
  static const PdfColor _dangerDark = PdfColor.fromInt(0xFF991B1B);
  static const PdfColor _slate600 = PdfColor.fromInt(0xFF475569);
  static const PdfColor _slate500 = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _slate900 = PdfColor.fromInt(0xFF0F172A);

  static Future<Uint8List> generate({
    required List<DefaulterClassGroup> groups,
    required DefaulterListFilterSummary summary,
    required String branchName,
    required String branchAddress,
    String? branchPhone,
    String? branchPrincipal,
    /// Phase K-6 Run 2: page format from the preview modal's
    /// Portrait/Landscape override. Null = the report's natural A4
    /// landscape (K-3b contract — the default render is unchanged).
    PdfPageFormat? pageFormat,
  }) async {
    final logoBytes = await LogoRepository.loadLogoBytes();
    final doc = pw.Document();
    final activeFormat = pageFormat ?? PdfPageFormat.a4.landscape;
    // Portrait when height > width (portrait A4: 595×841; landscape: 841×595).
    final isPortrait = activeFormat.height > activeFormat.width;

    doc.addPage(
      pw.MultiPage(
        pageFormat: activeFormat,
        margin: pw.EdgeInsets.fromLTRB(
          isPortrait ? kPortraitMarginLeft : kMarginLeft,
          kMarginTop,
          isPortrait ? kPortraitMarginRight : kMarginRight,
          kMarginBottom,
        ),
        header: (context) => context.pageNumber == 1
            ? _buildHeader(
                summary: summary,
                branchName: branchName,
                branchAddress: branchAddress,
                branchPhone: branchPhone,
                branchPrincipal: branchPrincipal,
                logoBytes: logoBytes,
                isPortrait: isPortrait,
              )
            : _buildContinuationHeader(summary: summary),
        footer: (context) => isPortrait
            ? _buildPortraitFooter(context, branchName: branchName)
            : ReportTheme.buildStandardFooter(context, branchName: branchName),
        build: (context) => [
          // 1. Executive KPI Summary Strip
          _buildKpiSummary(summary),
          pw.SizedBox(height: 6),

          // 2. Empty State or Grouped Tables
          // Phase K-6 Run B: portrait renders an 8-column merged layout;
          // landscape renders the original 10-column layout unchanged.
          if (groups.isEmpty)
            _buildEmptyState()
          else ...[
            for (final group in groups) ...[
              _buildClassGroup(group, isPortrait: isPortrait),
              pw.SizedBox(height: 6),
            ],

            // 3. Grand Total Banner
            _buildGrandTotal(summary, groups.length),
          ],

          // 4. Signature Footer
          pw.SizedBox(height: 12),
          ReportTheme.signatureFooter(
            leftLabel: 'Prepared By (Cashier / Clerk)',
            rightLabel: 'Verified By (Accountant / Bursar)',
            thirdLabel: 'Principal Signature & Stamp',
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildContinuationHeader({
    required DefaulterListFilterSummary summary,
  }) {
    final scope = summary.classFilter ?? 'All Classes';
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 3),
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        'FEE DEFAULTERS ROSTER  |  Session: ${summary.sessionYr}  |  '
        'Scope: $scope (${summary.reportMonth})  |  '
        '${summary.totalDefaulters} Vouchers / ${summary.uniqueStudents} Stu',
        style: const pw.TextStyle(fontSize: 7.5, color: _slate900),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  static pw.Widget _buildHeader({
    required DefaulterListFilterSummary summary,
    required String branchName,
    required String branchAddress,
    String? branchPhone,
    String? branchPrincipal,
    Uint8List? logoBytes,
    bool isPortrait = false,
  }) {
    if (isPortrait) {
      return _buildPortraitHeader(
        summary: summary,
        branchName: branchName,
        branchAddress: branchAddress,
        branchPhone: branchPhone,
        branchPrincipal: branchPrincipal,
        logoBytes: logoBytes,
      );
    }

    final phone = (branchPhone != null && branchPhone.trim().isNotEmpty)
        ? branchPhone.trim()
        : '03334449993';
    final principal =
        (branchPrincipal != null && branchPrincipal.trim().isNotEmpty)
        ? branchPrincipal.trim()
        : '-';

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 2)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Institutional branding
          pw.Expanded(
            flex: 3,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                logoBytes != null
                    ? pw.Container(
                        width: 48,
                        height: 48,
                        alignment: pw.Alignment.center,
                        child: pw.Image(
                          pw.MemoryImage(logoBytes),
                          fit: pw.BoxFit.contain,
                        ),
                      )
                    : pw.Container(
                        width: 48,
                        height: 48,
                        decoration: const pw.BoxDecoration(
                          color: _navy,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'AH',
                          style: const pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                pw.SizedBox(width: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      branchName,
                      style: const pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      branchAddress,
                      style: const pw.TextStyle(fontSize: 8.5, color: _slate600),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Phone: $phone  |  Principal: $principal',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: _slate500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Center: Title & Scope
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'INSTITUTIONAL FEE DEFAULTERS ROSTER',
                  style: const pw.TextStyle(
                    fontSize: 13.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Session: ${summary.sessionYr}  |  Scope: ${summary.classFilter ?? "All Classes"} (${summary.reportMonth})',
                  style: const pw.TextStyle(fontSize: 8.5, color: _slate600),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

          // Right: Audit Control Box
          pw.Container(
            width: 150,
            decoration: pw.BoxDecoration(
              color: _dangerBg,
              border: pw.Border.all(color: _dangerBorder, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FEE RECOVERY REGISTER',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _dangerText,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Defaulters: ${summary.totalDefaulters} Vouchers (${summary.uniqueStudents} Stu)',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _slate900,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Generated: ${ReportTheme.formatDate(summary.generatedAt)}',
                  style: const pw.TextStyle(fontSize: 6.5, color: _slate600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Phase K-6 Run C: Portrait stacked header so title never wraps at 525pt printable width.
  static pw.Widget _buildPortraitHeader({
    required DefaulterListFilterSummary summary,
    required String branchName,
    required String branchAddress,
    String? branchPhone,
    String? branchPrincipal,
    Uint8List? logoBytes,
  }) {
    final phone = (branchPhone != null && branchPhone.trim().isNotEmpty)
        ? branchPhone.trim()
        : '03334449993';
    final principal =
        (branchPrincipal != null && branchPrincipal.trim().isNotEmpty)
        ? branchPrincipal.trim()
        : '-';

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 2)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Line 1: Institutional branding (full width)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              logoBytes != null
                  ? pw.Container(
                      width: 48,
                      height: 48,
                      alignment: pw.Alignment.center,
                      child: pw.Image(
                        pw.MemoryImage(logoBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  : pw.Container(
                      width: 48,
                      height: 48,
                      decoration: const pw.BoxDecoration(
                        color: _navy,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'AH',
                        style: const pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      branchName,
                      style: const pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      '$branchAddress  |  Phone: $phone  |  Principal: $principal',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: _slate600,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),

          // Line 2: 'INSTITUTIONAL FEE DEFAULTERS ROSTER' (full width, MUST NOT wrap)
          pw.Text(
            'INSTITUTIONAL FEE DEFAULTERS ROSTER',
            style: const pw.TextStyle(
              fontSize: 13.5,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),

          // Line 3: session/scope
          pw.Text(
            'Session: ${summary.sessionYr}  |  Scope: ${summary.classFilter ?? "All Classes"} (${summary.reportMonth})',
            style: const pw.TextStyle(fontSize: 8, color: _slate600),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 5),

          // Line 4: Audit box full-width below
          pw.Container(
            decoration: pw.BoxDecoration(
              color: _dangerBg,
              border: pw.Border.all(color: _dangerBorder, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FEE RECOVERY REGISTER  |  Defaulters: ${summary.totalDefaulters} Vouchers (${summary.uniqueStudents} Stu)',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _dangerText,
                  ),
                ),
                pw.Text(
                  'Generated: ${ReportTheme.formatDate(summary.generatedAt)}',
                  style: const pw.TextStyle(fontSize: 8.5, color: _slate600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Phase K-6 Run C: Portrait footer without stretched glyphs at 525pt printable width.
  static pw.Widget _buildPortraitFooter(
    pw.Context context, {
    String? branchName,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _borderColor, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              branchName ?? 'Ailyans Higher Secondary School',
              style: const pw.TextStyle(fontSize: 7.5, color: _slate600),
              maxLines: 1,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            'Generated: ${ReportTheme.formatDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7.5, color: _slate600),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiSummary(DefaulterListFilterSummary summary) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _lightBg),
          children: [
            _kpiCell(
              'UNPAID VOUCHERS',
              '${summary.totalDefaulters} Records',
              valueColor: summary.totalDefaulters > 0 ? _dangerText : null,
              isBold: true,
              valueSize: 13,
            ),
            _kpiCell(
              'DEFAULTING STUDENTS',
              '${summary.uniqueStudents} Students',
              valueColor: _slate900,
              isBold: true,
              valueSize: 13,
            ),
            _kpiCell(
              'CLASS COHORT',
              summary.classFilter ?? 'All Classes',
              valueSize: 13,
            ),
            _kpiCell(
              'BILLING PERIOD',
              summary.reportMonth,
              valueSize: 13,
            ),
            _kpiCell(
              'TOTAL ARREARS RECEIVABLE',
              'Rs. ${ReportTheme.formatCurrency(summary.totalOutstanding)}',
              valueColor: _dangerText,
              isBold: true,
              valueSize: 13,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _kpiCell(
    String label,
    String value, {
    PdfColor? valueColor,
    bool isBold = false,
    double valueSize = 13,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: valueSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClassGroup(DefaulterClassGroup group, {bool isPortrait = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Group Header Banner (identical for both orientations)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          margin: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(2),
              topRight: pw.Radius.circular(2),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'COHORT: ${group.classLabel.toUpperCase()}  (${group.rows.length} Unpaid Vouchers)',
                style: const pw.TextStyle(
                  fontSize: 11.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                'Class Arrears Subtotal: Rs. ${ReportTheme.formatCurrency(group.subtotal)}',
                style: const pw.TextStyle(
                  fontSize: 11.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),

        if (isPortrait)
          // Run G: 8-column portrait layout with enlarged 9.5pt typography.
          // Side margins 18/18pt -> 559.28pt printable width.
          // Fixed budget: 22+28+42+76+68+78+74 = 388pt. Flex (~171pt) for Student/Father.
          pw.Table(
            border: pw.TableBorder.all(color: _borderColor, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(22),  // #
              1: pw.FixedColumnWidth(28),  // Roll
              2: pw.FixedColumnWidth(42),  // Reg ID
              3: pw.FlexColumnWidth(1),    // Student / Father (stacked, ~171pt)
              4: pw.FixedColumnWidth(76),  // Contact Mobile
              5: pw.FixedColumnWidth(68),  // Voucher / Month (stacked)
              6: pw.FixedColumnWidth(78),  // Due Date / Status
              7: pw.FixedColumnWidth(74),  // Balance (Rs)
            },
            children: [
              // Table Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _headerBg),
                children: [
                  _thCell('#', alignment: pw.Alignment.center, fontSize: 9.5),
                  _thCell('Roll', alignment: pw.Alignment.center, fontSize: 9.5),
                  _thCell('Reg ID', alignment: pw.Alignment.center, fontSize: 9.5),
                  _thCell('Student / Father', fontSize: 9.5),
                  _thCell('Contact', fontSize: 9.5),
                  _thCell('Voucher\nMonth', fontSize: 9.0),
                  _thCell('Due / Status', alignment: pw.Alignment.center, fontSize: 9.5),
                  _thCell('Balance', alignment: pw.Alignment.centerRight, fontSize: 9.5),
                ],
              ),

              // Data Rows
              for (int i = 0; i < group.rows.length; i++)
                _buildDataRowPortrait(i, group.rows[i]),

              // Group Subtotal Footer Row (8 cols)
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightBg),
                children: [
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(
                    '${group.classLabel} Subtotal (${group.rows.length} Vouchers)',
                    isBold: true,
                    fontSize: 9.5,
                  ),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3.5,
                    ),
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Rs. ${ReportTheme.formatCurrency(group.subtotal)}',
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _dangerText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          // Original 10-column landscape layout — UNCHANGED byte-for-byte.
          pw.Table(
            border: pw.TableBorder.all(color: _borderColor, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FixedColumnWidth(32),
              2: pw.FixedColumnWidth(42),
              3: pw.FlexColumnWidth(2.3),
              4: pw.FlexColumnWidth(2.1),
              5: pw.FixedColumnWidth(76),
              6: pw.FixedColumnWidth(58),
              7: pw.FixedColumnWidth(68),
              8: pw.FixedColumnWidth(78),
              9: pw.FixedColumnWidth(72),
            },
            children: [
              // Table Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _headerBg),
                children: [
                  _thCell('#', alignment: pw.Alignment.center),
                  _thCell('Roll', alignment: pw.Alignment.center),
                  _thCell('Reg ID', alignment: pw.Alignment.center),
                  _thCell('Student Full Name'),
                  _thCell('Father / Guardian Name'),
                  _thCell('Contact Mobile'),
                  _thCell('Voucher ID', alignment: pw.Alignment.center),
                  _thCell('Billing Month'),
                  _thCell('Due Date / Status', alignment: pw.Alignment.center),
                  _thCell('Balance (Rs)', alignment: pw.Alignment.centerRight),
                ],
              ),

              // Data Rows
              for (int i = 0; i < group.rows.length; i++)
                _buildDataRow(i, group.rows[i]),

              // Group Subtotal Footer Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightBg),
                children: [
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(
                    '${group.classLabel} Subtotal (${group.rows.length} Vouchers)',
                    isBold: true,
                  ),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  _subtotalLabelCell(''),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3.5,
                    ),
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Rs. ${ReportTheme.formatCurrency(group.subtotal)}',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _dangerText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  static pw.TableRow _buildDataRow(int index, DefaulterListRow row) {
    final bg = index.isEven ? PdfColors.white : _lightBg;

    // Due Date / Status string
    String statusStr = '-';
    bool isOverdue = false;
    if (row.dueDate != null) {
      final dateStr = ReportTheme.formatDate(row.dueDate);
      if (row.daysOverdue > 0 && row.daysOverdue <= 365) {
        statusStr = '$dateStr (${row.daysOverdue}d)';
        isOverdue = true;
      } else if (row.isPaid == 'O') {
        statusStr = '$dateStr [OVERDUE]';
        isOverdue = true;
      } else {
        statusStr = dateStr;
      }
    } else if (row.isPaid == 'O') {
      statusStr = '[OVERDUE]';
      isOverdue = true;
    }

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: [
        _tdCell('${index + 1}', alignment: pw.Alignment.center),
        _tdCell(
          row.rollNo != null ? row.rollNo.toString().padLeft(2, '0') : '-',
          alignment: pw.Alignment.center,
        ),
        _tdCell('${row.stuRegId}', alignment: pw.Alignment.center),
        _tdCell(row.studentName, isBold: true),
        _tdCell(row.fatherName ?? '-'),
        _tdCell(
          row.mobile1 != null && row.mobile1!.trim().isNotEmpty
              ? row.mobile1!.trim()
              : '-',
        ),
        _tdCell(row.voucherMasId, alignment: pw.Alignment.center),
        _tdCell(row.forMonth),
        _tdCell(
          statusStr,
          alignment: pw.Alignment.center,
          color: isOverdue ? _dangerText : null,
          isBold: isOverdue,
        ),
        _tdCell(
          ReportTheme.formatCurrency(row.balance),
          alignment: pw.Alignment.centerRight,
          color: _dangerText,
          isBold: true,
        ),
      ],
    );
  }

  /// Phase K-6 Run B: portrait 8-column data row.
  /// Merges Student+Father into one stacked cell, Voucher ID+Month into one.
  static pw.TableRow _buildDataRowPortrait(int index, DefaulterListRow row) {
    final bg = index.isEven ? PdfColors.white : _lightBg;

    // Due Date / Status string (identical logic as landscape)
    String statusStr = '-';
    bool isOverdue = false;
    if (row.dueDate != null) {
      final dateStr = ReportTheme.formatDate(row.dueDate);
      if (row.daysOverdue > 0 && row.daysOverdue <= 365) {
        statusStr = '$dateStr (${row.daysOverdue}d)';
        isOverdue = true;
      } else if (row.isPaid == 'O') {
        statusStr = '$dateStr [OVD]';
        isOverdue = true;
      } else {
        statusStr = dateStr;
      }
    } else if (row.isPaid == 'O') {
      statusStr = '[OVERDUE]';
      isOverdue = true;
    }

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: [
        // Col 0: #
        _tdCell('${index + 1}', alignment: pw.Alignment.center, fontSize: 9.5),
        // Col 1: Roll
        _tdCell(
          row.rollNo != null ? row.rollNo.toString().padLeft(2, '0') : '-',
          alignment: pw.Alignment.center,
          fontSize: 9.5,
        ),
        // Col 2: Reg ID
        _tdCell('${row.stuRegId}', alignment: pw.Alignment.center, fontSize: 9.5),
        // Col 3: Student / Father stacked
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                row.studentName,
                maxLines: 1,
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (row.fatherName != null && row.fatherName!.isNotEmpty)
                pw.Text(
                  row.fatherName!,
                  maxLines: 1,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: _slate600,
                  ),
                ),
            ],
          ),
        ),
        // Col 4: Contact (single line)
        _tdCell(
          row.mobile1 != null && row.mobile1!.trim().isNotEmpty
              ? row.mobile1!.trim()
              : '-',
          fontSize: 9.5,
          maxLines: 1,
        ),
        // Col 5: Voucher ID / Month stacked
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                row.voucherMasId,
                maxLines: 1,
                style: const pw.TextStyle(
                  fontSize: 9.0,
                  fontWeight: pw.FontWeight.bold,
                  color: _slate900,
                ),
              ),
              pw.Text(
                row.forMonth,
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 8.0, color: _slate600),
              ),
            ],
          ),
        ),
        // Col 6: Due / Status (single line)
        _tdCell(
          statusStr,
          alignment: pw.Alignment.center,
          color: isOverdue ? _dangerText : null,
          isBold: isOverdue,
          fontSize: 9.5,
          maxLines: 1,
        ),
        // Col 7: Balance (single line)
        _tdCell(
          ReportTheme.formatCurrency(row.balance),
          alignment: pw.Alignment.centerRight,
          color: _dangerText,
          isBold: true,
          fontSize: 9.5,
          maxLines: 1,
        ),
      ],
    );
  }

  static pw.Widget _thCell(
    String text, {
    pw.Alignment? alignment,
    double fontSize = 7,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      alignment: alignment ?? pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          color: _navy,
        ),
      ),
    );
  }

  static pw.Widget _tdCell(
    String text, {
    pw.Alignment? alignment,
    bool isBold = false,
    PdfColor? color,
    double fontSize = 7.5,
    int? maxLines,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: alignment ?? pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        maxLines: maxLines,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _subtotalLabelCell(
    String text, {
    bool isBold = false,
    double fontSize = 7.5,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _slate900,
        ),
      ),
    );
  }

  static pw.Widget _buildGrandTotal(
    DefaulterListFilterSummary summary,
    int cohortCount,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _dangerBg,
        border: pw.Border.all(color: _dangerBorder, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'GRAND TOTAL OUTSTANDING ARREARS (${summary.totalDefaulters} Vouchers across $cohortCount Class Cohorts)',
            style: const pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _dangerDark,
            ),
          ),
          pw.Text(
            'Rs. ${ReportTheme.formatCurrency(summary.totalOutstanding)}',
            style: const pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _dangerText,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEmptyState() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF0FDF4),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFF86EFAC),
          width: 1,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'NO OUTSTANDING DEFAULTERS',
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF047857),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'All vouchers for the selected class and billing period have been settled in full.',
            style: const pw.TextStyle(fontSize: 9, color: _slate600),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER FILTER CONTROLS FOR REPORT PREVIEW MODAL
// ============================================================================

class DefaulterFilterControls extends StatefulWidget {
  final int? initialClassId;
  final String? initialMonth;
  final void Function({int? classId, String? month})? onFiltersChanged;

  const DefaulterFilterControls({
    super.key,
    this.initialClassId,
    this.initialMonth,
    this.onFiltersChanged,
  });

  @override
  State<DefaulterFilterControls> createState() =>
      _DefaulterFilterControlsState();
}

class _DefaulterFilterControlsState extends State<DefaulterFilterControls> {
  int? _classId;
  String? _month;

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.onFiltersChanged?.call(classId: _classId, month: _month);
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_list,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _month ?? 'Defaulter Filters',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
