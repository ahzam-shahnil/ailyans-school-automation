import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates formal PDF documents for salary slips and payroll registers.
class SalarySlipPdfGenerator {
  SalarySlipPdfGenerator._();

  // ---------------------------------------------------------------------------
  // 1. Individual Salary Slip (A5)
  // ---------------------------------------------------------------------------

  /// Generates a single employee salary payment slip.
  ///
  /// [salaryData] contains:
  ///   - teacherName / name (String)
  ///   - teacherCat / designation (String?)
  ///   - teacherCnic / cnic (String?)
  ///   - salMonth / month (String)
  ///   - paidAmt / gross (num)
  ///   - tDeductions / deductions (num)
  ///   - netAmount / net (num)
  ///   - paidDate / disbursDate / date (String?)
  ///   - bank / bankName (String?)
  static Future<Uint8List> generateSlip({
    required Map<String, dynamic> salaryData,
    required String branchName,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    final teacherName =
        (salaryData['teacherName'] ?? salaryData['name'] ?? 'Employee')
            as String;
    final designation =
        (salaryData['teacherCat'] ?? salaryData['designation'] ?? 'Staff')
            as String;
    final cnic =
        (salaryData['teacherCnic'] ?? salaryData['cnic'] ?? '-') as String;
    final month =
        (salaryData['salMonth'] ?? salaryData['month'] ?? 'N/A') as String;
    final paidDate =
        (salaryData['paidDate'] ??
                salaryData['disbursDate'] ??
                salaryData['date'] ??
                '-')
            as String;
    final bank =
        (salaryData['bank'] ?? salaryData['bankName'] ?? 'Cash / Transfer')
            as String;

    final grossVal = (salaryData['paidAmt'] ?? salaryData['gross'] ?? 0) as num;
    final dedVal =
        (salaryData['tDeductions'] ?? salaryData['deductions'] ?? 0) as num;
    final netVal =
        (salaryData['netAmount'] ?? salaryData['net'] ?? (grossVal - dedVal))
            as num;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      branchName,
                      style: ReportTheme.titleStyle.copyWith(fontSize: 14),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'SALARY PAYMENT SLIP - $month',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 11,
                        color: ReportTheme.primaryColor,
                        letterSpacing: 1.0,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(color: ReportTheme.borderRuleColor, thickness: 1.0),
              pw.SizedBox(height: 8),

              // Employee Details Strip
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: ReportTheme.bannerBgColor,
                  border: pw.Border.all(
                    color: ReportTheme.borderRuleColor,
                    width: 0.6,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Employee: $teacherName',
                          style: pw.TextStyle(font: boldFont, fontSize: 10),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Designation: $designation',
                          style: pw.TextStyle(font: regularFont, fontSize: 9),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'CNIC: $cnic',
                          style: pw.TextStyle(font: regularFont, fontSize: 9),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Disbursed: $paidDate',
                          style: pw.TextStyle(font: regularFont, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Breakdown Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: ReportTheme.borderRuleColor,
                  width: 0.6,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: ReportTheme.tableHeaderBg,
                    ),
                    children: [
                      _cell(
                        'Item Description',
                        boldFont,
                        color: PdfColors.white,
                      ),
                      _cell(
                        'Amount (Rs.)',
                        boldFont,
                        color: PdfColors.white,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Gross Salary', regularFont),
                      _cell(
                        ReportTheme.formatCurrency(grossVal),
                        regularFont,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: ReportTheme.tableRowAltBg,
                    ),
                    children: [
                      _cell('Total Deductions', regularFont),
                      _cell(
                        ReportTheme.formatCurrency(dedVal),
                        regularFont,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: ReportTheme.bannerBgColor,
                    ),
                    children: [
                      _cell('NET SALARY PAYABLE', boldFont),
                      _cell(
                        ReportTheme.formatCurrency(netVal),
                        boldFont,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Text(
                'Payment Mode: $bank',
                style: pw.TextStyle(
                  font: italicFont,
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureLine(
                    label: 'Employee Signature',
                    boldFont: boldFont,
                    regularFont: regularFont,
                  ),
                  _signatureLine(
                    label: 'Accountant / Principal',
                    boldFont: boldFont,
                    regularFont: regularFont,
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Automated School Management System',
                  style: pw.TextStyle(
                    font: italicFont,
                    fontSize: 7.5,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // 2. Payroll Register (A4 Landscape)
  // ---------------------------------------------------------------------------

  /// Generates a full monthly payroll register table.
  ///
  /// [salaries] contains rows matching [SalarySlipRow] or map keys:
  ///   - teacherName / name
  ///   - paidAmt / gross
  ///   - tDeductions / deductions
  ///   - netAmount / net
  ///   - paidDate / disbursDate / date
  ///   - bank / bankName / isPaid
  static Future<Uint8List> generateRegister({
    required List<Map<String, dynamic>> salaries,
    required String month,
    required String branchName,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    num totalGross = 0;
    num totalDeductions = 0;
    num totalNet = 0;

    for (final s in salaries) {
      final g = (s['paidAmt'] ?? s['gross'] ?? 0) as num;
      final d = (s['tDeductions'] ?? s['deductions'] ?? 0) as num;
      final n = (s['netAmount'] ?? s['net'] ?? (g - d)) as num;
      totalGross += g;
      totalDeductions += d;
      totalNet += n;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildRegisterHeader(
          branchName: branchName,
          month: month,
          count: salaries.length,
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        footer: (context) =>
            ReportTheme.buildStandardFooter(context, branchName: branchName),
        build: (context) => [
          pw.SizedBox(height: 10),

          // Register Table
          pw.Table(
            border: pw.TableBorder.all(
              color: ReportTheme.borderRuleColor,
              width: 0.6,
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(30), // #
              1: pw.FlexColumnWidth(3), // Name
              2: pw.FlexColumnWidth(2), // Gross
              3: pw.FlexColumnWidth(2), // Deduction
              4: pw.FlexColumnWidth(2), // Net
              5: pw.FlexColumnWidth(2), // Paid Date
              6: pw.FlexColumnWidth(2), // Status / Mode
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: ReportTheme.tableHeaderBg,
                ),
                children: [
                  _regHeaderCell('#', boldFont, align: pw.TextAlign.center),
                  _regHeaderCell('Teacher / Employee Name', boldFont),
                  _regHeaderCell(
                    'Gross (Rs.)',
                    boldFont,
                    align: pw.TextAlign.right,
                  ),
                  _regHeaderCell(
                    'Deduction (Rs.)',
                    boldFont,
                    align: pw.TextAlign.right,
                  ),
                  _regHeaderCell(
                    'Net Paid (Rs.)',
                    boldFont,
                    align: pw.TextAlign.right,
                  ),
                  _regHeaderCell(
                    'Paid Date',
                    boldFont,
                    align: pw.TextAlign.center,
                  ),
                  _regHeaderCell('Status / Mode', boldFont),
                ],
              ),

              // Rows
              if (salaries.isEmpty)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(14),
                      child: pw.Center(
                        child: pw.Text(
                          'No payroll records found for $month.',
                          style: pw.TextStyle(
                            font: italicFont,
                            fontSize: 9.5,
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
                ...salaries.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;

                  final name =
                      (s['teacherName'] ?? s['name'] ?? 'Employee ${idx + 1}')
                          as String;
                  final g = (s['paidAmt'] ?? s['gross'] ?? 0) as num;
                  final d = (s['tDeductions'] ?? s['deductions'] ?? 0) as num;
                  final n = (s['netAmount'] ?? s['net'] ?? (g - d)) as num;
                  final date =
                      (s['paidDate'] ?? s['disbursDate'] ?? s['date'] ?? '-')
                          as String;
                  final status =
                      (s['bank'] ??
                              s['bankName'] ??
                              (s['isPaid'] == 'Y' ? 'Paid' : 'Pending'))
                          as String;

                  final isEven = idx.isEven;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven
                          ? PdfColors.white
                          : ReportTheme.tableRowAltBg,
                    ),
                    children: [
                      _regDataCell(
                        '${idx + 1}',
                        regularFont,
                        align: pw.TextAlign.center,
                      ),
                      _regDataCell(name, regularFont, bold: true),
                      _regDataCell(
                        ReportTheme.formatCurrency(g),
                        regularFont,
                        align: pw.TextAlign.right,
                      ),
                      _regDataCell(
                        ReportTheme.formatCurrency(d),
                        regularFont,
                        align: pw.TextAlign.right,
                      ),
                      _regDataCell(
                        ReportTheme.formatCurrency(n),
                        boldFont,
                        align: pw.TextAlign.right,
                      ),
                      _regDataCell(
                        date,
                        regularFont,
                        align: pw.TextAlign.center,
                      ),
                      _regDataCell(status, regularFont),
                    ],
                  );
                }),

              // Grand Total Row
              if (salaries.isNotEmpty)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: ReportTheme.bannerBgColor,
                  ),
                  children: [
                    _regDataCell('', boldFont),
                    _regDataCell(
                      'GRAND TOTAL (${salaries.length})',
                      boldFont,
                      bold: true,
                    ),
                    _regDataCell(
                      ReportTheme.formatCurrency(totalGross),
                      boldFont,
                      align: pw.TextAlign.right,
                    ),
                    _regDataCell(
                      ReportTheme.formatCurrency(totalDeductions),
                      boldFont,
                      align: pw.TextAlign.right,
                    ),
                    _regDataCell(
                      ReportTheme.formatCurrency(totalNet),
                      boldFont,
                      align: pw.TextAlign.right,
                    ),
                    _regDataCell('', regularFont),
                    _regDataCell('', regularFont),
                  ],
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

  static pw.Widget _cell(
    String text,
    pw.Font font, {
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _signatureLine({
    required String label,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      children: [
        pw.Container(width: 120, height: 1, color: ReportTheme.borderRuleColor),
        pw.SizedBox(height: 3),
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
      ],
    );
  }

  static pw.Widget _buildRegisterHeader({
    required String branchName,
    required String month,
    required int count,
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
            pw.Text(branchName, style: ReportTheme.titleStyle),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'STAFF PAYROLL REGISTER: $month',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    color: ReportTheme.primaryColor,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Total Records: $count',
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

  static pw.Widget _regHeaderCell(
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

  static pw.Widget _regDataCell(
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
