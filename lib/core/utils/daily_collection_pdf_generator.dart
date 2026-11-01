import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 portrait Daily Fee Collection report PDF.
class DailyCollectionPdfGenerator {
  DailyCollectionPdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates a daily collection summary report table.
  ///
  /// [collections] contains map rows with:
  ///   - date / paidDate (String)
  ///   - student / studentName (String)
  ///   - class / className (String)
  ///   - voucher / voucherNo / voucherMasId (String)
  ///   - amount / paidAmt (num)
  ///   - bank / bankName (String?)
  static Future<Uint8List> generate({
    required String date,
    required List<Map<String, dynamic>> collections,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    num totalCollected = 0;
    for (final c in collections) {
      final amt = (c['amount'] ?? c['paidAmt'] ?? 0) as num;
      totalCollected += amt;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          branchName: branchName,
          branchAddress: branchAddress,
          date: date,
          count: collections.length,
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        footer: (context) =>
            ReportTheme.buildStandardFooter(context, branchName: branchName),
        build: (context) => [
          pw.SizedBox(height: 10),

          // Collection Table
          pw.Table(
            border: pw.TableBorder.all(
              color: ReportTheme.borderRuleColor,
              width: 0.6,
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(28), // #
              1: pw.FlexColumnWidth(2), // Date
              2: pw.FlexColumnWidth(3.5), // Student
              3: pw.FlexColumnWidth(2), // Class
              4: pw.FlexColumnWidth(2), // Voucher
              5: pw.FlexColumnWidth(2), // Amount
              6: pw.FlexColumnWidth(2), // Bank / Mode
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: ReportTheme.tableHeaderBg,
                ),
                children: [
                  _headerCell('#', boldFont, align: pw.TextAlign.center),
                  _headerCell('Date', boldFont, align: pw.TextAlign.center),
                  _headerCell('Student Name', boldFont),
                  _headerCell('Class', boldFont),
                  _headerCell('Voucher', boldFont, align: pw.TextAlign.center),
                  _headerCell(
                    'Amount (Rs.)',
                    boldFont,
                    align: pw.TextAlign.right,
                  ),
                  _headerCell('Bank / Mode', boldFont),
                ],
              ),

              // Rows
              if (collections.isEmpty)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(14),
                      child: pw.Center(
                        child: pw.Text(
                          'No collections recorded for $date.',
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
                ...collections.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final c = entry.value;

                  final rowDate =
                      (c['date'] ?? c['paidDate'] ?? date) as String;
                  final student =
                      (c['student'] ?? c['studentName'] ?? 'Student ${idx + 1}')
                          as String;
                  final className =
                      (c['class'] ?? c['className'] ?? '-') as String;
                  final voucher =
                      (c['voucher'] ??
                              c['voucherNo'] ??
                              c['voucherMasId'] ??
                              '-')
                          as String;
                  final amt = (c['amount'] ?? c['paidAmt'] ?? 0) as num;
                  final bank =
                      (c['bank'] ?? c['bankName'] ?? 'Counter') as String;

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
                        rowDate,
                        regularFont,
                        align: pw.TextAlign.center,
                      ),
                      _dataCell(student, regularFont, bold: true),
                      _dataCell(className, regularFont),
                      _dataCell(
                        voucher,
                        regularFont,
                        align: pw.TextAlign.center,
                      ),
                      _dataCell(
                        ReportTheme.formatCurrency(amt),
                        regularFont,
                        align: pw.TextAlign.right,
                      ),
                      _dataCell(bank, regularFont),
                    ],
                  );
                }),

              // Grand Total Row
              if (collections.isNotEmpty)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: ReportTheme.bannerBgColor,
                  ),
                  children: [
                    _dataCell('', boldFont),
                    _dataCell('TOTAL COLLECTION', boldFont, bold: true),
                    _dataCell('${collections.length} Receipts', regularFont),
                    _dataCell('', regularFont),
                    _dataCell('', regularFont),
                    _dataCell(
                      ReportTheme.formatCurrency(totalCollected),
                      boldFont,
                      align: pw.TextAlign.right,
                    ),
                    _dataCell('', regularFont),
                  ],
                ),
            ],
          ),

          pw.SizedBox(height: 24),

          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signatureLine(
                label: 'Cashier / Receiving Officer',
                boldFont: boldFont,
                regularFont: regularFont,
              ),
              _signatureLine(
                label: 'Accountant / Bursar',
                boldFont: boldFont,
                regularFont: regularFont,
              ),
              _signatureLine(
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
    required String date,
    required int count,
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
              pw.SizedBox(height: 2),
              pw.Text(
                branchAddress,
                style: ReportTheme.subtitleStyle,
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: ReportTheme.borderRuleColor, thickness: 1.0),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DAILY FEE COLLECTION REPORT',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 11,
                color: ReportTheme.primaryColor,
                letterSpacing: 0.8,
              ),
            ),
            pw.Text(
              'Date / Period: $date  |  Total Receipts: $count',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 9.5,
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

  static pw.Widget _signatureLine({
    required String label,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      children: [
        pw.Container(width: 130, height: 1, color: ReportTheme.borderRuleColor),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
        pw.Text(
          'Date & Stamp',
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
