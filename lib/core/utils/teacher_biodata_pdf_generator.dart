import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart' show ReportTheme;

/// Generates an A4 portrait Teacher Biodata PDF document.
class TeacherBiodataPdfGenerator {
  TeacherBiodataPdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates a teacher biodata dossier PDF.
  ///
  /// [teacherData] contains teacher fields:
  ///   - name / tName (String)
  ///   - designation / tCat (String)
  ///   - cnic / tCnic (String)
  ///   - phone / tContactNo1 (String)
  ///   - address / tAddress (String)
  ///   - joiningDate / doJoing (String)
  ///   - photoPath (String?, optional)
  ///
  /// [branchName] and [branchAddress] are printed in the institutional header.
  static Future<Uint8List> generate({
    required Map<String, dynamic> teacherData,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    final String name =
        (teacherData['name'] ?? teacherData['tName'] ?? '') as String;
    final String designation =
        (teacherData['designation'] ?? teacherData['tCat'] ?? '') as String;
    final String cnic =
        (teacherData['cnic'] ?? teacherData['tCnic'] ?? '') as String;
    final String phone =
        (teacherData['phone'] ?? teacherData['tContactNo1'] ?? '') as String;
    final String address =
        (teacherData['address'] ?? teacherData['tAddress'] ?? '') as String;
    final String joiningDate =
        (teacherData['joiningDate'] ?? teacherData['doJoing'] ?? '') as String;
    final String? photoPath = (teacherData['photoPath'] as String?)?.trim();

    Uint8List? photoBytes;
    if (photoPath != null && photoPath.isNotEmpty) {
      try {
        final file = File(photoPath);
        if (file.existsSync() && file.lengthSync() < 2 * 1024 * 1024) {
          photoBytes = file.readAsBytesSync();
        }
      } catch (_) {}
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── 1. Institutional Header ──
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      branchName,
                      style: ReportTheme.titleStyle,
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      branchAddress,
                      style: ReportTheme.subtitleStyle,
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(color: ReportTheme.borderRuleColor, thickness: 1.0),
              pw.SizedBox(height: 8),

              // ── 2. Document Title Banner ──
              pw.Container(
                color: ReportTheme.tableHeaderBg,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'TEACHER BIODATA',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 13,
                    color: PdfColors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              pw.SizedBox(height: 16),

              // ── 3. Overview Card (Photo & Primary Identifiers) ──
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: ReportTheme.bannerBgColor,
                  border: pw.Border.all(
                    color: ReportTheme.borderRuleColor,
                    width: 0.8,
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Photo Box or Initials Placeholder
                    pw.Container(
                      width: 80,
                      height: 96,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        border: pw.Border.all(
                          color: ReportTheme.borderRuleColor,
                          width: 1.0,
                        ),
                      ),
                      alignment: pw.Alignment.center,
                      child: photoBytes != null
                          ? pw.Image(
                              pw.MemoryImage(photoBytes),
                              fit: pw.BoxFit.cover,
                            )
                          : pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'PHOTO',
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 10,
                                    color: PdfColors.blueGrey400,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    pw.SizedBox(width: 16),

                    // Name and Designation Header
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            name.isNotEmpty ? name : 'Employee Name',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 15,
                              color: ReportTheme.primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            designation.isNotEmpty
                                ? 'Designation: $designation'
                                : 'Faculty Member',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 11,
                              color: ReportTheme.secondaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Institutional Employee Profile & Record Dossier',
                            style: pw.TextStyle(
                              font: italicFont,
                              fontSize: 9,
                              color: PdfColors.blueGrey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── 4. Detailed Information Table ──
              _buildBiodataTable(
                boldFont: boldFont,
                regularFont: regularFont,
                rows: [
                  _BiodataRow('Full Name', name),
                  _BiodataRow('Designation / Category', designation),
                  _BiodataRow('CNIC / Identification No', cnic),
                  _BiodataRow('Contact Phone Number', phone),
                  _BiodataRow('Residential Address', address),
                  _BiodataRow('Date of Joining', joiningDate),
                ],
              ),

              pw.Spacer(),

              // ── 5. Signatures Row ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureLine(
                    label: 'Employee Signature',
                    boldFont: boldFont,
                    regularFont: regularFont,
                  ),
                  _signatureLine(
                    label: 'Administration / HR',
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

              pw.SizedBox(height: 14),

              // ── 6. Standard Footer ──
              ReportTheme.buildStandardFooter(context, branchName: branchName),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static pw.Widget _buildBiodataTable({
    required pw.Font boldFont,
    required pw.Font regularFont,
    required List<_BiodataRow> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: ReportTheme.borderRuleColor,
        width: 0.6,
      ),
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(4)},
      children: rows.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final isEven = idx.isEven;

        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : ReportTheme.tableRowAltBg,
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: pw.Text(
                item.label,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: ReportTheme.secondaryColor,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: pw.Text(
                item.value.isEmpty ? '-' : item.value,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 10,
                  color: PdfColors.black,
                ),
              ),
            ),
          ],
        );
      }).toList(),
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
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 9)),
        pw.Text(
          'Date & Stamp',
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 8,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }
}

class _BiodataRow {
  final String label;
  final String value;
  const _BiodataRow(this.label, this.value);
}
