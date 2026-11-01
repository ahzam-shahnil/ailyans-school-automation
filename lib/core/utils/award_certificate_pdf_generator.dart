import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 landscape Award of Excellence Certificate PDF.
class AwardCertificatePdfGenerator {
  AwardCertificatePdfGenerator._();

  /// Generates the certificate document as bytes.
  static Future<Uint8List> generate({
    required String examName,
    required String className,
    required Map<String, dynamic> student,
    required int rank,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.timesBold();
    final regularFont = pw.Font.times();
    final sansBold = pw.Font.helveticaBold();
    final sansRegular = pw.Font.helvetica();

    final studentName = (student['studentName'] ??
            student['name'] ??
            student['fullName'] ??
            'Student')
        .toString();
    final rollNo = (student['rollNo'] ??
            student['ClassRollNo'] ??
            student['roll'] ??
            '—')
        .toString();
    final pctVal = student['percentage'] ??
        ((student['totalMax'] is num &&
                student['totalMax'] > 0 &&
                student['totalObtained'] is num)
            ? ((student['totalObtained'] as num) /
                    (student['totalMax'] as num)) *
                100.0
            : 0.0);
    final pctStr = pctVal is num
        ? pctVal.toStringAsFixed(1)
        : pctVal.toString().replaceAll('%', '');
    final grade = (student['grade'] ?? '—').toString();

    final rankSuffix = _getOrdinalSuffix(rank);
    final rankText = '$rank$rankSuffix';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.blue900,
                width: 4.0,
              ),
            ),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.amber700,
                  width: 1.2,
                ),
                color: PdfColors.white,
              ),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 36,
                vertical: 24,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Top Header: Logo + School Branding
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Circular Logo Placeholder
                      pw.Container(
                        width: 48,
                        height: 48,
                        decoration: const pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.grey300,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'LOGO',
                          style: pw.TextStyle(
                            font: sansBold,
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 16),

                      // School Name & Address
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            branchName.isNotEmpty
                                ? branchName.toUpperCase()
                                : "AILYANS'S HIGHER SECONDARY SCHOOL",
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 18,
                              color: PdfColors.blue900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            branchAddress.isNotEmpty
                                ? branchAddress
                                : 'Muslim Bazar Mianwali',
                            style: pw.TextStyle(
                              font: sansRegular,
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Decorative Divider
                  pw.Container(
                    width: 420,
                    margin: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            height: 1,
                            color: PdfColors.amber700,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                          child: pw.Text(
                            '*',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 14,
                              color: PdfColors.amber700,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            height: 1,
                            color: PdfColors.amber700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Certificate Title
                  pw.Column(
                    children: [
                      pw.Text(
                        'AWARD OF EXCELLENCE',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'THIS CERTIFICATE IS PROUDLY PRESENTED TO',
                        style: pw.TextStyle(
                          font: sansBold,
                          fontSize: 9.5,
                          letterSpacing: 1.5,
                          color: PdfColors.amber900,
                        ),
                      ),
                    ],
                  ),

                  // Recipient Name
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 4),
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.blue900,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: pw.Text(
                      studentName,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 22,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                  // Body Paragraph
                  pw.ConstrainedBox(
                    constraints: const pw.BoxConstraints(maxWidth: 580),
                    child: pw.Text(
                      'This is to certify that Mr./Ms. $studentName of Class $className '
                      '(Roll No: $rollNo) has secured Position $rankText in the '
                      '$examName examination with $pctStr% and Grade $grade.',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 12.5,
                        lineSpacing: 3.0,
                        color: PdfColors.black,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                  // Bottom Signatures & Date
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Left: Date & Place
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              'Date: ${ReportTheme.formatDate(DateTime.now())}',
                              style: pw.TextStyle(
                                font: sansRegular,
                                fontSize: 9,
                                color: PdfColors.grey800,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Place: ${_getPlace(branchAddress)}',
                              style: pw.TextStyle(
                                font: sansRegular,
                                fontSize: 9,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),

                        // Center: Principal Signature Line
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Container(
                              width: 160,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  top: pw.BorderSide(
                                    color: PdfColors.blue900,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Principal',
                              style: pw.TextStyle(
                                font: sansBold,
                                fontSize: 10,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),

                        // Right: Controller of Examinations Signature Line
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Container(
                              width: 160,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  top: pw.BorderSide(
                                    color: PdfColors.blue900,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Exam Incharge',
                              style: pw.TextStyle(
                                font: sansBold,
                                fontSize: 10,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  static String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  static String _getPlace(String address) {
    if (address.isEmpty) return 'Mianwali';
    final parts = address.split(',');
    return parts.last.trim();
  }
}
