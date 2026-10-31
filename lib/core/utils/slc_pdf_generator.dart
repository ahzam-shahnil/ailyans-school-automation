import 'dart:typed_data';

import 'package:intl/intl.dart';
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

    final String studentName = (slcData['studentName'] ??
            slcData['name'] ??
            slcData['stuName'] ??
            slcData['Stu_Name'] ??
            '')
        .toString()
        .trim();
    final String fatherName = (slcData['fatherName'] ??
            slcData['father'] ??
            slcData['fName'] ??
            slcData['F_Name'] ??
            '')
        .toString()
        .trim();
    final String className = (slcData['className'] ??
            slcData['classLeft'] ??
            slcData['leftClass'] ??
            slcData['LeftClass'] ??
            slcData['cName'] ??
            slcData['CName'] ??
            '')
        .toString()
        .trim();
    final String admissionDate = (slcData['admissionDate'] ??
            slcData['admDate'] ??
            slcData['admission_date'] ??
            slcData['DOAdmission'] ??
            '')
        .toString()
        .trim();
    final String leavingDate = (slcData['leavingDate'] ??
            slcData['leftDate'] ??
            slcData['LeftDate'] ??
            slcData['dateLeft'] ??
            '')
        .toString()
        .trim();
    final String conduct = (slcData['conduct'] ??
            slcData['charactor'] ??
            slcData['Charactor'] ??
            slcData['character'] ??
            '')
        .toString()
        .trim();
    final String reason = (slcData['reason'] ??
            slcData['termOfLeaving'] ??
            slcData['TermOfLeavign'] ??
            slcData['term'] ??
            '')
        .toString()
        .trim();
    final String remarks = (slcData['remarks'] ??
            slcData['slRemarks'] ??
            slcData['Remarks'] ??
            '')
        .toString()
        .trim();

    final sName = studentName.isEmpty ? '__________________' : studentName;
    final fName = fatherName.isEmpty ? '__________________' : fatherName;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            height: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900, width: 4),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Container(
              width: double.infinity,
              height: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 1),
              ),
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // ── Logo Placeholder ──
                  pw.Center(
                    child: pw.Container(
                      width: 60,
                      height: 60,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                        shape: pw.BoxShape.circle,
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'LOGO',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 10),

                  // ── Institution Name + Address ──
                  pw.Center(
                    child: pw.Text(
                      branchName,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      branchAddress,
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  // ── Document Title & Divider ──
                  pw.Center(
                    child: pw.Text(
                      'SCHOOL LEAVING CERTIFICATE',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Center(
                    child: pw.Container(
                      height: 2,
                      width: 150,
                      color: PdfColors.blue900,
                      margin: const pw.EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),

                  pw.SizedBox(height: 14),

                  // ── Body Certification Paragraph ──
                  pw.Text(
                    'This is to certify that Mr./Ms. $sName, son/daughter of Mr. $fName, was a bonafide student of this institution and has been duly enrolled in our records.',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 14,
                      lineSpacing: 1.5,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),

                  pw.SizedBox(height: 20),

                  // ── Detail Table ──
                  _buildDetailTable(
                    regularFont: regularFont,
                    boldFont: boldFont,
                    className: className,
                    admissionDate: _formatDate(admissionDate),
                    leavingDate: _formatDate(leavingDate),
                    conduct: conduct,
                    reason: reason,
                  ),

                  // ── Optional Remarks ──
                  if (remarks.isNotEmpty) ...[
                    pw.SizedBox(height: 12),
                    pw.Center(
                      child: pw.Text(
                        'Remarks: $remarks',
                        style: pw.TextStyle(
                          font: italicFont,
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ],

                  // ── Signatures Pushed to Bottom ──
                  pw.Spacer(),
                  _buildSignatureRow(
                    boldFont: boldFont,
                    regularFont: regularFont,
                  ),

                  pw.SizedBox(height: 16),

                  // ── Footer Note ──
                  pw.Center(
                    child: pw.Text(
                      'This certificate is issued on the request of the student/guardian.',
                      style: pw.TextStyle(
                        font: italicFont,
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
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

  static String _formatDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';

    DateTime? dt = DateTime.tryParse(trimmed);

    if (dt == null) {
      final datePart = trimmed.split(' ').first;
      final slashParts = datePart.split('/');
      if (slashParts.length == 3) {
        final p0 = int.tryParse(slashParts[0]);
        final p1 = int.tryParse(slashParts[1]);
        var p2 = int.tryParse(slashParts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (p2 < 100) p2 += 2000;
          if (p0 > 12) {
            // dd/MM/yyyy
            dt = DateTime(p2, p1, p0);
          } else {
            // MM/dd/yy (e.g. 04/02/24 -> 02-Apr-2024)
            dt = DateTime(p2, p0, p1);
          }
        }
      }
    }

    if (dt != null) {
      try {
        return DateFormat('dd-MMM-yyyy').format(dt);
      } catch (_) {}
    }

    return trimmed;
  }

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
      _SlcField('Class / Grade:', className),
      _SlcField('Date of Admission:', admissionDate),
      _SlcField('Date of Leaving:', leavingDate),
      _SlcField('Character & Conduct:', conduct),
      _SlcField('Reason for Leaving:', reason),
    ];

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(3.8),
      },
      children: rows.map((field) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              child: pw.Text(
                field.label,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              child: pw.Text(
                field.value.isEmpty ? '-' : field.value,
                textAlign: pw.TextAlign.left,
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
          title: 'Class Teacher',
          subtitle: 'Stamp & Signature',
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        _signatureBlock(
          title: 'Head of Department',
          subtitle: 'Stamp & Signature',
          boldFont: boldFont,
          regularFont: regularFont,
        ),
        _signatureBlock(
          title: 'Principal',
          subtitle: 'Stamp & Signature',
          boldFont: boldFont,
          regularFont: regularFont,
        ),
      ],
    );
  }

  static pw.Widget _signatureBlock({
    required String title,
    required String subtitle,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Column(
      children: [
        pw.Container(
          width: 120,
          height: 1,
          color: PdfColors.black,
          margin: const pw.EdgeInsets.only(bottom: 4),
        ),
        pw.Text(
          title,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 9,
            color: PdfColors.grey700,
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
