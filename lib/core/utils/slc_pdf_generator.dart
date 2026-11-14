import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates the A4 School Leaving Certificate (SLC) PDF.
///
/// Shot 3a (Ailyans): the certificate is fully framed and centered on the
/// A4 sheet — an institutional double-border frame (outer 2pt Oxford Blue
/// + inner 0.8pt slate) with 24pt page margin and 24pt inner padding, a
/// vertically distributed layout (centered header, striped particulars
/// table, centered certification statement, signature block) so the
/// content fills and centers the whole page instead of hugging the top.
class SlcPdfGenerator {
  SlcPdfGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates the SLC PDF document.
  ///
  /// [slcData] keys (all optional, alternate DB column keys supported):
  ///   - admissionNo   (Stu_RegID)
  ///   - studentName (String)
  ///   - fatherName  (String)
  ///   - dob         (String)
  ///   - address     (P_Address or T_Address)
  ///   - admissionDate (String)
  ///   - admittedClass (Class.CName for AdmInClass/AdmClass)
  ///   - className / leftClass (Class at the time of leaving)
  ///   - leavingDate   (String)
  ///   - duesPaidUpTo  (latest paid VoucharMas.ForMonth)
  ///   - conduct       (String, defaults to 'Good')
  ///   - reason        (String, e.g. "On Parent's Request")
  ///   - remarks       (String)
  ///
  /// [branchName] and [branchAddress] are accepted for call-site
  /// compatibility but intentionally NOT printed — the pre-printed
  /// stationery already carries the school letterhead.
  static Future<Uint8List> generate({
    required Map<String, dynamic> slcData,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();
    final italicFont = pw.Font.helveticaOblique();

    String pick(List<dynamic> keys) {
      for (final k in keys) {
        final v = slcData[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    final admissionNo = pick(['admissionNo', 'Stu_RegID', 'stuRegId']);
    final studentName = pick(
      ['studentName', 'name', 'stuName', 'Stu_Name'],
    );
    final fatherName = pick(['fatherName', 'father', 'fName', 'F_Name']);
    final dob = pick(['dob', 'dateOfBirth', 'DOB']);
    final address = pick(['address', 'pAddress', 'P_Address']);
    final admissionDate = pick([
      'admissionDate',
      'admDate',
      'admission_date',
      'DOAdmission',
    ]);
    final admittedClass = pick(['admittedClass', 'admInClassCName']);
    final className = pick([
      'className',
      'classLeft',
      'leftClass',
      'LeftClass',
      'cName',
      'CName',
    ]);
    final leavingDate = pick([
      'leavingDate',
      'leftDate',
      'LeftDate',
      'dateLeft',
    ]);
    final duesPaidUpTo = pick(['duesPaidUpTo', 'duesPaid']);
    final conduct = pick([
      'conduct',
      'charactor',
      'Charactor',
      'character',
    ]);
    final reasonRaw = pick([
      'reason',
      'termOfLeaving',
      'TermOfLeavign',
      'term',
    ]);
    // Shot 3a: normalize the legacy 'Compeletd Studies' typo.
    final reason = _normalizeReason(reasonRaw);
    final remarks = pick(['remarks', 'slRemarks', 'Remarks']);

    // Shot 3a: blank legacy fields print an em dash, never a blank line.
    final sName = studentName.isEmpty ? '—' : studentName;
    final fName = fatherName.isEmpty ? '—' : fatherName;
    final addressOut = address.isEmpty ? '—' : address;

    // 12 pre-printed stationery rows (label -> dotted-line value).
    final rows = <(String, String)>[
      ('Admission No:', admissionNo),
      ('Student Name:', sName),
      ('Father Name:', fName),
      ('Date of Birth:', _formatDate(dob)),
      ('Address:', addressOut),
      ('Admission Date:', _formatDate(admissionDate)),
      ('Class Admitted:', admittedClass.isNotEmpty ? admittedClass : className),
      ('Class At the Time of Leaving:', className),
      ('Conduct:', conduct.isEmpty ? 'Good' : conduct),
      ('Reason for Leaving', reason),
      ('Dues Paid up to:', duesPaidUpTo.isNotEmpty ? duesPaidUpTo : _formatDate(leavingDate)),
      ('Remarks:', remarks),
    ];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // Shot 3a: 24pt page margin all around.
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            // Institutional double-border frame: outer 2pt Oxford Blue.
            width: double.infinity,
            height: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue800, width: 2),
            ),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Container(
              // Inner 0.8pt slate rule with 24pt breathing room.
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.blueGrey300,
                  width: 0.8,
                ),
              ),
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                // Vertically distribute the certificate across the full A4
                // sheet and center every block horizontally.
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // ── Centered header block ──
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'SCHOOL LEAVING CERTIFICATE',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                          decoration: pw.TextDecoration.underline,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Recognized and affiliated with BISE Sargodha, AKU Karachi',
                        style: pw.TextStyle(font: boldFont, fontSize: 11),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        width: 120,
                        height: 1.2,
                        color: PdfColors.blue800,
                      ),
                    ],
                  ),

                  // ── Bordered / striped particulars table ──
                  pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.blueGrey300,
                        width: 0.8,
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        for (int i = 0; i < rows.length; i++)
                          _buildTableRow(
                            label: rows[i].$1,
                            value: rows[i].$2,
                            striped: i.isOdd,
                            regularFont: regularFont,
                            boldFont: boldFont,
                          ),
                      ],
                    ),
                  ),

                  // ── Centered certification statement ──
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 60,
                        height: 1.2,
                        color: PdfColors.blue800,
                        margin: const pw.EdgeInsets.only(bottom: 10),
                      ),
                      pw.Text(
                        'Certified that the above information is in accordance with school record.',
                        style: pw.TextStyle(
                          font: italicFont,
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey800,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),

                  // ── Bottom signature block ──
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 140,
                            height: 0.8,
                            color: PdfColors.grey600,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Class Teacher',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 140,
                            height: 0.8,
                            color: PdfColors.grey600,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Principal',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ],
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

  /// One striped particulars-table row: label on the left, bold value on
  /// the right, alternating background stripes and a hairline separator.
  static pw.Widget _buildTableRow({
    required String label,
    required String value,
    required bool striped,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      color: striped ? PdfColors.grey50 : null,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 10.5,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value.isEmpty ? '—' : value,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10.5,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Shot 3a: normalize the legacy 'Compeletd Studies' typo stored in
  /// SchLeaving.TermOfLeavign by the MS Access migration.
  static String _normalizeReason(String raw) {
    final r = raw.trim();
    final lower = r.toLowerCase();
    if (lower.contains('compeletd') ||
        lower.contains('compeleted') ||
        lower.contains('compleated')) {
      return 'Completed Studies';
    }
    return r;
  }
}
