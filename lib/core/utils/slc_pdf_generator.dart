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

  /// Width (pt) of the left-hand row label column. Shot 3d: widened to
  /// 190pt so 'Class At the Time of Leaving:' renders on ONE line.
  static const double kLabelWidth = 190;

  /// Shot 3d: tokens preserved verbatim by [formatValue] (built-in PDF
  /// Helvetica fonts have no Unicode support — only ASCII is safe).
  static const Set<String> _formatValueAcronyms = {
    'bise',
    'aku',
    'cnic',
    'slc',
    'fbise',
    'ibcc',
  };

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
    final studentNameRaw = pick(
      ['studentName', 'name', 'stuName', 'Stu_Name'],
    );
    final fatherNameRaw = pick(['fatherName', 'father', 'fName', 'F_Name']);
    final dobRaw = pick(['dob', 'dateOfBirth', 'DOB']);
    final addressRaw = pick(['address', 'pAddress', 'P_Address']);
    final admissionDateRaw = pick([
      'admissionDate',
      'admDate',
      'admission_date',
      'DOAdmission',
    ]);
    final admittedClassRaw = pick(['admittedClass', 'admInClassCName']);
    final classNameRaw = pick([
      'className',
      'classLeft',
      'leftClass',
      'LeftClass',
      'cName',
      'CName',
    ]);
    final leavingDateRaw = pick([
      'leavingDate',
      'leftDate',
      'LeftDate',
      'dateLeft',
    ]);
    final duesPaidUpToRaw = pick(['duesPaidUpTo', 'duesPaid']);
    final conductRaw = pick([
      'conduct',
      'charactor',
      'Charactor',
      'character',
    ]);
    final reason = normalizeReason(pick([
      'reason',
      'termOfLeaving',
      'TermOfLeavign',
      'term',
    ]));
    final remarksRaw = pick(['remarks', 'slRemarks', 'Remarks']);

    // Shot 3d: every printed value passes through formatValue so names,
    // classes and addresses come out cleanly Title-Cased.
    final sName = studentNameRaw.isEmpty
        ? '__________________'
        : formatValue(studentNameRaw);
    final fName = fatherNameRaw.isEmpty
        ? '__________________'
        : formatValue(fatherNameRaw);

    // 12 pre-printed stationery rows (label -> dotted-line value).
    final rows = <(String, String)>[
      ('Admission No:', admissionNo.isEmpty ? '-' : admissionNo),
      ('Student Name:', sName),
      ('Father Name:', fName),
      ('Date of Birth:', formatValue(_formatDate(dobRaw))),
      ('Address:', addressRaw.isEmpty ? '-' : formatValue(addressRaw)),
      ('Admission Date:', formatValue(_formatDate(admissionDateRaw))),
      (
        'Class Admitted:',
        admittedClassRaw.isNotEmpty
            ? formatValue(admittedClassRaw)
            : formatValue(classNameRaw),
      ),
      (
        'Class At the Time of Leaving:',
        classNameRaw.isEmpty ? '-' : formatValue(classNameRaw),
      ),
      ('Conduct:', normalizeConduct(conductRaw)),
      ('Reason for Leaving:', reason),
      (
        'Dues Paid up to:',
        duesPaidUpToRaw.isNotEmpty
            ? formatValue(duesPaidUpToRaw)
            : _formatDate(leavingDateRaw),
      ),
      ('Remarks:', remarksRaw.isEmpty ? '-' : formatValue(remarksRaw)),
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

              // ── Centered title with a crisp double underline ──
              // Shot 3d: 1.5pt rule + 1.5pt gap + 0.5pt rule, and
              // letterSpacing 1.4 on the title / 0.3 on the subtitle.
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'SCHOOL LEAVING CERTIFICATE',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(height: 1.5, width: 310, color: PdfColors.black),
                    pw.SizedBox(height: 1.5),
                    pw.Container(height: 0.5, width: 310, color: PdfColors.black),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // ── Affiliation subtitle ──
              pw.Center(
                child: pw.Text(
                  'Recognized and affiliated with BISE Sargodha, AKU Karachi',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
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

  /// Shot 3a: normalize the legacy 'Compeletd Studies' typo stored in
  /// SchLeaving.TermOfLeavign by the MS Access migration.
  static String normalizeReason(String? raw) {
    final r = (raw ?? '').trim();
    final lower = r.toLowerCase();
    if (lower.contains('compeletd') ||
        lower.contains('compeleted') ||
        lower.contains('compleated')) {
      return 'Completed Studies';
    }
    return r;
  }

  /// Shot 3d: normalize legacy Charactor values case-insensitively
  /// ('satisfactory' -> 'Satisfactory', 'bad' -> 'Bad'); empty or
  /// unrecognized values default to 'Good'.
  static String normalizeConduct(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'satisfactory':
        return 'Satisfactory';
      case 'bad':
        return 'Bad';
      default:
        return 'Good';
    }
  }

  /// Shot 3d: production typography for every printed certificate value —
  /// trims, collapses runs of spaces, Title-Cases each word (including
  /// sub-words after '-', '/', '('), and preserves acronym tokens (BISE,
  /// AKU, CNIC, SLC, ...) plus formatted dates like '05-Sep-2010'.
  /// Empty input renders the ASCII '-' placeholder (built-in Helvetica
  /// fonts have NO Unicode support — never emit an em-dash here).
  static String formatValue(String? raw) {
    if (raw == null) return '-';
    final s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty || s == '-') return '-';

    // Preserve already-formatted dates (05-Sep-2010, 04/02/24, 2017-10-01).
    if (RegExp(r'^\d{1,4}[-/.][0-9A-Za-z]{2,9}[-/.]\d{2,4}$').hasMatch(s)) {
      return s;
    }

    return s
        .splitMapJoin(
          RegExp(r'[-/()]'),
          onMatch: (m) => m[0]!,
          onNonMatch: _formatValueSubToken,
        );
  }

  /// Title-Cases one sub-token (a run of characters with no '-', '/' or
  /// '(' inside). Acronym tokens and Roman numerals (Class XI) survive
  /// verbatim; everything else becomes 'Word'.
  static String _formatValueSubToken(String sub) {
    if (sub.isEmpty) return sub;
    if (_formatValueAcronyms.contains(sub.toLowerCase())) return sub;
    if (RegExp(r'^[IVXLC]+$').hasMatch(sub)) return sub;
    return sub[0].toUpperCase() + sub.substring(1).toLowerCase();
  }

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
  /// print both align to the pre-printed dotted line). Shot 3a follow-up:
  /// the value text is horizontally centered within the full dotted-line
  /// area, with no rightward optical shift. Shot 3d: the value container
  /// gains 3pt bottom padding so descenders (g, y, p, q) float cleanly
  /// above the dots, and both styles gain letter spacing.
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
            width: kLabelWidth,
            child: pw.Text(
              label,
              maxLines: 1,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Center(
                    child: pw.Text(
                      value.isEmpty ? '-' : value,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
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
