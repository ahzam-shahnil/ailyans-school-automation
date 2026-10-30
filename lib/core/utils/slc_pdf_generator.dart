import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a formal A4 School Leaving Certificate (SLC) PDF.
class SlcPdfGenerator {
  SlcPdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates a formal SLC PDF document.
  ///
  /// [slcData] must contain:
  ///   - studentName (String)
  ///   - fatherName  (String)
  ///   - className   (String)
  ///   - admissionDate (String)
  ///   - leavingDate   (String)
  ///   - conduct       (String)
  ///   - reason        (String)
  ///   - remarks       (String)
  ///
  /// [branchName] and [branchAddress] are printed in the header.
  static Future<Uint8List> generate({
    required Map<String, dynamic> slcData,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    final String studentName = (slcData['studentName'] as String?) ?? '';
    final String fatherName = (slcData['fatherName'] as String?) ?? '';
    final String className = (slcData['className'] as String?) ?? '';
    final String admissionDate = (slcData['admissionDate'] as String?) ?? '';
    final String leavingDate = (slcData['leavingDate'] as String?) ?? '';
    final String conduct = (slcData['conduct'] as String?)?.trim() ?? '';
    final String reason = (slcData['reason'] as String?)?.trim() ?? '';
    final String remarks = (slcData['remarks'] as String?) ?? '';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.blueGrey800,
                width: 2.5,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── Outer border accent top strip ──
                pw.Container(
                  height: 6,
                  color: PdfColors.blueGrey800,
                ),

                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // ── HEADER: Institution name + address ──
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.Text(
                              branchName,
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              branchAddress,
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 11,
                                color: PdfColors.blueGrey700,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 16),
                      pw.Divider(color: PdfColors.blueGrey300, thickness: 0.8),
                      pw.SizedBox(height: 12),

                      // ── DOCUMENT TITLE ──
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.Text(
                              'SCHOOL LEAVING CERTIFICATE',
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 18,
                                letterSpacing: 2.0,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              height: 2,
                              width: 260,
                              color: PdfColors.blueGrey800,
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 28),

                      // ── INTRODUCTORY PARAGRAPH ──
                      pw.RichText(
                        text: pw.TextSpan(
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 12,
                            lineSpacing: 4,
                          ),
                          children: [
                            const pw.TextSpan(
                              text: 'This is to certify that ',
                            ),
                            pw.TextSpan(
                              text: studentName.isEmpty ? '__________________' : studentName,
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 12,
                                decoration: pw.TextDecoration.underline,
                              ),
                            ),
                            const pw.TextSpan(
                              text: ', son/daughter of ',
                            ),
                            pw.TextSpan(
                              text: fatherName.isEmpty ? '__________________' : fatherName,
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 12,
                                decoration: pw.TextDecoration.underline,
                              ),
                            ),
                            const pw.TextSpan(
                              text:
                                  ', was a bonafide student of this institution '
                                  'and has been duly enrolled in our records.',
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 24),

                      // ── DETAIL TABLE ──
                      _buildDetailTable(
                        regularFont: regularFont,
                        boldFont: boldFont,
                        className: className,
                        admissionDate: admissionDate,
                        leavingDate: leavingDate,
                        conduct: conduct,
                        reason: reason,
                      ),

                      pw.SizedBox(height: 20),

                      // ── REMARKS ──
                      if (remarks.trim().isNotEmpty) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColors.blueGrey200,
                              width: 0.8,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Administrative Remarks:',
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 11,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                remarks,
                                style: pw.TextStyle(
                                  font: italicFont,
                                  fontSize: 11,
                                  color: PdfColors.blueGrey700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 20),
                      ],

                      // ── SIGNATURE SECTION ──
                      pw.Spacer(),
                      pw.SizedBox(height: 40),
                      _buildSignatureRow(boldFont: boldFont, regularFont: regularFont),

                      pw.SizedBox(height: 16),

                      // ── FOOTER NOTE ──
                      pw.Center(
                        child: pw.Text(
                          'This certificate is issued on the request of the student/guardian.',
                          style: pw.TextStyle(
                            font: italicFont,
                            fontSize: 9,
                            color: PdfColors.blueGrey500,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Outer border accent bottom strip ──
                pw.Container(
                  height: 6,
                  color: PdfColors.blueGrey800,
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static pw.Widget _buildDetailTable({
    required pw.Font regularFont,
    required pw.Font boldFont,
    required String className,
    required String admissionDate,
    required String leavingDate,
    required String conduct,
    required String reason,
  }) {
    final rows = <_SlcField>[
      _SlcField('Class / Grade', className),
      _SlcField('Date of Admission', admissionDate),
      _SlcField('Date of Leaving', leavingDate),
      _SlcField('Character & Conduct', conduct),
      _SlcField('Reason for Leaving', reason),
    ];

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.blueGrey200,
        width: 0.6,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
      },
      children: rows.map((field) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              child: pw.Text(
                field.label,
                style: pw.TextStyle(font: boldFont, fontSize: 11),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              child: pw.Text(
                field.value.isEmpty ? '-' : field.value,
                style: pw.TextStyle(font: regularFont, fontSize: 11),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _buildSignatureRow({
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signatureBlock(
          label: 'Class Teacher',
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        _signatureBlock(
          label: 'Head of Department',
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        _signatureBlock(
          label: 'Principal',
          boldFont: boldFont,
          regularFont: regularFont,
        ),
      ],
    );
  }

  static pw.Widget _signatureBlock({
    required String label,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      children: [
        pw.Container(
          width: 130,
          height: 1,
          color: PdfColors.blueGrey600,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(font: boldFont, fontSize: 10),
        ),
        pw.Text(
          'Stamp & Signature',
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 9,
            color: PdfColors.blueGrey500,
          ),
        ),
      ],
    );
  }
}

class _SlcField {
  final String label;
  final String value;
  const _SlcField(this.label, this.value);
}
