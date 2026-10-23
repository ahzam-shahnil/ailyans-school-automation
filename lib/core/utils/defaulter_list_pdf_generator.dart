// ignore_for_file: public_member_api_docs
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../db/database.dart';
import '../../core/providers/fee_collection_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
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
    required this.isPaid,
    this.dueDate,
    required this.daysOverdue,
  });
}

class DefaulterListFilterSummary {
  final String sessionYr;
  final String? classFilter;
  final int totalDefaulters;
  final int uniqueStudents;
  final int totalOutstanding;
  final String reportMonth;
  final DateTime generatedAt;

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
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        header: (context) => _buildHeader(
          summary: summary,
          branchName: branchName,
          branchAddress: branchAddress,
          branchPhone: branchPhone,
          branchPrincipal: branchPrincipal,
        ),
        footer: (context) =>
            ReportTheme.buildStandardFooter(context, branchName: branchName),
        build: (context) => [
          // 1. Executive KPI Summary Strip
          _buildKpiSummary(summary),
          pw.SizedBox(height: 6),

          // 2. Empty State or Grouped Tables
          if (groups.isEmpty)
            _buildEmptyState()
          else ...[
            for (final group in groups) ...[
              _buildClassGroup(group),
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

  static pw.Widget _buildHeader({
    required DefaulterListFilterSummary summary,
    required String branchName,
    required String branchAddress,
    String? branchPhone,
    String? branchPrincipal,
  }) {
    final phone = (branchPhone != null && branchPhone.trim().isNotEmpty)
        ? branchPhone.trim()
        : '03334449993';
    final principal =
        (branchPrincipal != null && branchPrincipal.trim().isNotEmpty)
        ? branchPrincipal.trim()
        : 'Nasir ali';

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
                pw.Container(
                  width: 26,
                  height: 26,
                  decoration: const pw.BoxDecoration(
                    color: _navy,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'AH',
                    style: const pw.TextStyle(
                      fontSize: 10,
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
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      branchAddress,
                      style: const pw.TextStyle(fontSize: 8, color: _slate600),
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
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Session: ${summary.sessionYr}  |  Scope: ${summary.classFilter ?? "All Classes"} (${summary.reportMonth})',
                  style: const pw.TextStyle(fontSize: 8, color: _slate600),
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
            ),
            _kpiCell(
              'DEFAULTING STUDENTS',
              '${summary.uniqueStudents} Students',
              valueColor: _slate900,
              isBold: true,
            ),
            _kpiCell('CLASS COHORT', summary.classFilter ?? 'All Classes'),
            _kpiCell('BILLING PERIOD', summary.reportMonth),
            _kpiCell(
              'TOTAL ARREARS RECEIVABLE',
              'Rs. ${ReportTheme.formatCurrency(summary.totalOutstanding)}',
              valueColor: _dangerText,
              isBold: true,
              valueSize: 9.5,
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
    double valueSize = 8,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 1),
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

  static pw.Widget _buildClassGroup(DefaulterClassGroup group) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Group Header Banner
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                'Class Arrears Subtotal: Rs. ${ReportTheme.formatCurrency(group.subtotal)}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),

        // 10-Column Bordered Table
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
          ReportTheme.formatCurrency(row.netPayable),
          alignment: pw.Alignment.centerRight,
          color: _dangerText,
          isBold: true,
        ),
      ],
    );
  }

  static pw.Widget _thCell(String text, {pw.Alignment? alignment}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      alignment: alignment ?? pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 7,
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
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: alignment ?? pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _subtotalLabelCell(String text, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
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
// INTERACTIVE PREVIEW DIALOG
// ============================================================================

Future<void> showDefaulterListPrintPreviewDialog(
  BuildContext context, {
  required List<DefaulterClassGroup> initialGroups,
  required DefaulterListFilterSummary initialSummary,
  required String branchName,
  required String branchAddress,
  String? branchPhone,
  String? branchPrincipal,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _DefaulterPreviewDialog(
      initialGroups: initialGroups,
      initialSummary: initialSummary,
      branchName: branchName,
      branchAddress: branchAddress,
      branchPhone: branchPhone,
      branchPrincipal: branchPrincipal,
    ),
  );
}

class _DefaulterPreviewDialog extends ConsumerStatefulWidget {
  const _DefaulterPreviewDialog({
    required this.initialGroups,
    required this.initialSummary,
    required this.branchName,
    required this.branchAddress,
    this.branchPhone,
    this.branchPrincipal,
  });

  final List<DefaulterClassGroup> initialGroups;
  final DefaulterListFilterSummary initialSummary;
  final String branchName;
  final String branchAddress;
  final String? branchPhone;
  final String? branchPrincipal;

  @override
  ConsumerState<_DefaulterPreviewDialog> createState() =>
      _DefaulterPreviewDialogState();
}

class _DefaulterPreviewDialogState
    extends ConsumerState<_DefaulterPreviewDialog> {
  final GlobalKey _shareButtonKey = GlobalKey();

  String? _selectedClass;
  String? _selectedMonth;
  List<String> _availableClasses = [];
  List<String> _availableMonths = [];

  late Future<
    ({List<DefaulterClassGroup> groups, DefaulterListFilterSummary summary})
  >
  _currentBuild;

  @override
  void initState() {
    super.initState();
    _currentBuild = Future.value((
      groups: widget.initialGroups,
      summary: widget.initialSummary,
    ));
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final db = await DatabaseService.instance.database;
      final cRows = await db.rawQuery(
        'SELECT CName FROM Class ORDER BY ClassID ASC',
      );
      final mRows = await db.rawQuery(
        "SELECT DISTINCT ForMonth FROM VoucharMas ORDER BY ForMonth DESC",
      );

      if (!mounted) return;
      setState(() {
        _availableClasses = cRows
            .map((r) => r['CName']?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        _availableMonths = mRows
            .map((r) => r['ForMonth']?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        // Sort chronologically DESC (newest first) so alphabetical
        // month names (e.g. April vs January) don't affect display order.
        _availableMonths.sort((a, b) {
          final da = _parseMonthYear(a);
          final db = _parseMonthYear(b);
          return db.compareTo(da);
        });
        debugPrint('[DEBUG] Sorted months: $_availableMonths');
      });
    } catch (_) {}
  }

  DateTime _parseMonthYear(String s) {
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    final parts = s.trim().toLowerCase().split(RegExp(r'\s+'));
    if (parts.length < 2) return DateTime(1970);
    final m = months[parts[0]] ?? 1;
    final y = int.tryParse(parts[1]) ?? 1970;
    return DateTime(y, m);
  }

  void _onFilterChanged() {
    setState(() {
      _currentBuild = ref
          .read(feeCollectionProvider.notifier)
          .buildDefaulterList(
            classFilter: _selectedClass,
            monthFilter: _selectedMonth,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: SizedBox(
        width: 1120,
        height: 800,
        child: Column(
          children: [
            // Top Header Bar with Filters and Actions
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderDefault),
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.statusErrorText,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text('Fee Defaulters Roster', style: AppTypography.h3),
                  const SizedBox(width: 10),

                  // Interactive Class Filter Dropdown
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      border: Border.all(color: AppColors.borderDefault),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedClass,
                        hint: const Text(
                          'All Classes',
                          style: TextStyle(fontSize: 12),
                        ),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'All Classes',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          for (final c in _availableClasses)
                            DropdownMenuItem<String?>(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                        onChanged: (val) {
                          if (val == _selectedClass) return;
                          _selectedClass = val;
                          _onFilterChanged();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Interactive Month Filter Dropdown
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      border: Border.all(color: AppColors.borderDefault),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedMonth,
                        hint: const Text(
                          'All Months',
                          style: TextStyle(fontSize: 12),
                        ),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'All Months',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          for (final m in _availableMonths)
                            DropdownMenuItem<String?>(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                        onChanged: (val) {
                          if (val == _selectedMonth) return;
                          _selectedMonth = val;
                          _onFilterChanged();
                        },
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Share / Save PDF Button
                  OutlinedButton.icon(
                    key: _shareButtonKey,
                    onPressed: () async {
                      final buildData = await _currentBuild;
                      final bytes = await DefaulterListPdfGenerator.generate(
                        groups: buildData.groups,
                        summary: buildData.summary,
                        branchName: widget.branchName,
                        branchAddress: widget.branchAddress,
                        branchPhone: widget.branchPhone,
                        branchPrincipal: widget.branchPrincipal,
                      );
                      final box =
                          _shareButtonKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      final bounds = box != null
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename:
                            'fee_defaulters_${DateTime.now().millisecondsSinceEpoch}.pdf',
                        bounds: bounds,
                      );
                    },
                    icon: const Icon(Icons.ios_share, size: 16),
                    label: const Text('Share / Save PDF'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Print Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final buildData = await _currentBuild;
                      await Printing.layoutPdf(
                        onLayout: (_) => DefaulterListPdfGenerator.generate(
                          groups: buildData.groups,
                          summary: buildData.summary,
                          branchName: widget.branchName,
                          branchAddress: widget.branchAddress,
                          branchPhone: widget.branchPhone,
                          branchPrincipal: widget.branchPrincipal,
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print Roster (Ctrl+P)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Close Button
                  Tooltip(
                    message: 'Close (Esc)',
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

            // PDF Preview Body with Dynamic FutureBuilder
            Expanded(
              child:
                  FutureBuilder<
                    ({
                      List<DefaulterClassGroup> groups,
                      DefaulterListFilterSummary summary,
                    })
                  >(
                    future: _currentBuild,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Error loading defaulter roster: ${snapshot.error}',
                              style: const TextStyle(
                                color: AppColors.statusErrorText,
                              ),
                            ),
                          ),
                        );
                      }

                      final data = snapshot.data!;
                      return PdfPreview(
                        build: (_) => DefaulterListPdfGenerator.generate(
                          groups: data.groups,
                          summary: data.summary,
                          branchName: widget.branchName,
                          branchAddress: widget.branchAddress,
                          branchPhone: widget.branchPhone,
                          branchPrincipal: widget.branchPrincipal,
                        ),
                        useActions: false,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        pdfFileName:
                            'fee_defaulters_roster_${DateTime.now().millisecondsSinceEpoch}.pdf',
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
