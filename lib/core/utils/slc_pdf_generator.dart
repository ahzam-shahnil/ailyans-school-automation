import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates the A4 School Leaving Certificate (SLC) PDF.
///
/// Batch 1 (Ailyans): the layout matches the school's physical pre-printed
/// certificate stationery — a ~90pt blank spacer at the top so text prints
/// cleanly below the pre-printed school logo/header, followed by a centered
/// underlined title, an affiliation subtitle, 12 left-aligned label +
/// dotted-line value rows, and a solid bottom rule with the certification
/// footer. The document deliberately draws NO header/border of its own.
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
    final reason = pick([
      'reason',
      'termOfLeaving',
      'TermOfLeavign',
      'term',
    ]);
    final remarks = pick(['remarks', 'slRemarks', 'Remarks']);

    final sName = studentName.isEmpty ? '__________________' : studentName;
    final fName = fatherName.isEmpty ? '__________________' : fatherName;

    // 12 pre-printed stationery rows (label -> dotted-line value).
    final rows = <(String, String)>[
      ('Admission No:', admissionNo),
      ('Student Name:', sName),
      ('Father Name:', fName),
      ('Date of Birth:', _formatDate(dob)),
      ('Address:', address),
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
        margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Top blank letterhead spacer (~90pt) — the physical
              // pre-printed school logo/header occupies this area. ──
              pw.SizedBox(height: 90),

              // ── Centered underlined title ──
              pw.Center(
                child: pw.Text(
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
              ),
              pw.SizedBox(height: 6),

              // ── Affiliation subtitle ──
              pw.Center(
                child: pw.Text(
                  'Recognized and affiliated with BISE Sargodha, AKU Karachi',
                  style: pw.TextStyle(font: boldFont, fontSize: 11),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              pw.SizedBox(height: 24),

              // ── 12 Label + Dotted-Line Value Rows ──
              for (final (label, value) in rows)
                _buildFieldRow(
                  label: label,
                  value: value,
                  regularFont: regularFont,
                  boldFont: boldFont,
                ),

              // ── Bottom solid rule + centered italic footer ──
              pw.Spacer(),
              pw.Container(
                height: 1.2,
                color: PdfColors.black,
                margin: const pw.EdgeInsets.only(bottom: 8),
              ),
              pw.Center(
                child: pw.Text(
                  'Certified that the above information is in accordance with school record.',
                  style: pw.TextStyle(
                    font: italicFont,
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey800,
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

  /// One pre-printed stationery row: the [label] sits on the left, and the
  /// bold [value] sits above a dotted rule on the right (so handwriting and
  /// print both align to the pre-printed dotted line).
  static pw.Widget _buildFieldRow({
    required String label,
    required String value,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) {
    const dottedLine =
        '........................................................';

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: regularFont, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  value.isEmpty ? ' ' : value,
                  style: pw.TextStyle(font: boldFont, fontSize: 11),
                ),
                pw.Text(
                  dottedLine,
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
