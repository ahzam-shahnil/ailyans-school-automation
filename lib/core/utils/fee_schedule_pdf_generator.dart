import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a simple A4 Fee Schedule PDF table.
class FeeSchedulePdfGenerator {
  FeeSchedulePdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates a fee schedule PDF for a given class and session.
  ///
  /// [feeRows] is a list of maps with keys 'displayName' (String) and
  /// 'fee' (num — a double) matching [FeeParameterRow] fields.
  ///
  /// [sessionYear] e.g. '2024-2025'
  /// [className]   e.g. 'Class 8'
  /// [branchName]  institution name for the header
  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> feeRows,
    required String sessionYear,
    required String className,
    required String branchName,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();

    final fmt = NumberFormat('#,##0.00');

    // Compute totals
    final double total = feeRows.fold(0.0, (sum, r) {
      final v = r['fee'];
      return sum + ((v is num) ? v.toDouble() : 0.0);
    });

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── HEADER ──
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      branchName,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 15,
                        letterSpacing: 0.4,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'FEE SCHEDULE',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 14,
                        letterSpacing: 2.0,
                        color: PdfColors.blueGrey800,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Session: $sessionYear    |    Class: $className',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 11,
                        color: PdfColors.blueGrey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.blueGrey400, thickness: 1.0),
              pw.SizedBox(height: 12),

              // ── TABLE HEADER ROW ──
              pw.Container(
                color: PdfColors.blueGrey800,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text(
                        '#',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Fee Head',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: 120,
                      child: pw.Text(
                        'Amount (Rs.)',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              // ── TABLE BODY ROWS ──
              if (feeRows.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.blueGrey200,
                        width: 0.6,
                      ),
                      left: pw.BorderSide(
                        color: PdfColors.blueGrey200,
                        width: 0.6,
                      ),
                      right: pw.BorderSide(
                        color: PdfColors.blueGrey200,
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'No fee parameters configured for this class and session.',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 11,
                        color: PdfColors.blueGrey500,
                      ),
                    ),
                  ),
                )
              else
                ...feeRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  final name = (row['displayName'] as String?) ?? '';
                  final fee = (row['fee'] as num?)?.toDouble() ?? 0.0;
                  final isEven = index.isEven;

                  return pw.Container(
                    color: isEven ? PdfColors.blueGrey50 : PdfColors.white,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.blueGrey200,
                          width: 0.4,
                        ),
                        left: pw.BorderSide(
                          color: PdfColors.blueGrey200,
                          width: 0.6,
                        ),
                        right: pw.BorderSide(
                          color: PdfColors.blueGrey200,
                          width: 0.6,
                        ),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 40,
                          child: pw.Text(
                            '${index + 1}.',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 11,
                              color: PdfColors.blueGrey600,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            name,
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        pw.SizedBox(
                          width: 120,
                          child: pw.Text(
                            'Rs. ${fmt.format(fee)}',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // ── TOTAL ROW ──
              pw.Container(
                color: PdfColors.blueGrey100,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.blueGrey400,
                    width: 0.8,
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 40),
                    pw.Expanded(
                      child: pw.Text(
                        'TOTAL ANNUAL PACKAGE',
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                    ),
                    pw.SizedBox(
                      width: 120,
                      child: pw.Text(
                        'Rs. ${fmt.format(total)}',
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 32),

              // ── FOOTER NOTE ──
              pw.Center(
                child: pw.Text(
                  'Fees are subject to revision. Contact the administration for the latest schedule.',
                  style: pw.TextStyle(
                    font: pw.Font.helveticaOblique(),
                    fontSize: 9,
                    color: PdfColors.blueGrey400,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
