import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import '../../repositories/logo_repository.dart';
import 'date_parse.dart';
import 'tenant_storage.dart';
import 'vb6_table_report_pdf.dart';

/// Represents a single student record in the class biodata report.
class ClassBiodataStudent {
  final int rollNo;
  final int regId;
  final String studentName;
  final String fatherName;
  final String? dob;
  final String? admissionDate;
  final String? contactNo;
  final String? address;

  const ClassBiodataStudent({
    required this.rollNo,
    required this.regId,
    required this.studentName,
    required this.fatherName,
    this.dob,
    this.admissionDate,
    this.contactNo,
    this.address,
  });
}

/// Generates the Class Biodata & Enrollment Roster PDF in A4 landscape.
///
/// Reuses [Vb6TableReportPdf.generate] to inherit canonical typography,
/// [LogoRepository] logo integration, [TenantStorage] dynamic branding,
/// and protected right margins.
class ClassBiodataPdfGenerator {
  static const double kMarginLeft = Vb6TableReportPdf.kMarginLeft;
  static const double kMarginRight = Vb6TableReportPdf.kMarginRight;
  static const double kMarginTop = Vb6TableReportPdf.kMarginTop;
  static const double kMarginBottom = Vb6TableReportPdf.kMarginBottom;

  static double printableWidth(PdfPageFormat format) =>
      format.width - kMarginLeft - kMarginRight;

  static const List<String> kHeaders = [
    'Roll #',
    'Reg ID',
    'Student Name',
    'Father Name',
    'DOB',
    'Admission Date',
    'Contact / Emergency No',
    'Address',
  ];

  static String _formatDate(dynamic val) {
    if (val == null) return '-';
    final s = '$val'.trim();
    if (s.isEmpty) return '-';
    final dt = parseFlexibleDate(s);
    if (dt != null) {
      return DateFormat('dd-MMM-yyyy').format(dt);
    }
    return s;
  }

  static Future<Uint8List> generate({
    required String className,
    required String sectionName,
    required String sessionYr,
    required List<ClassBiodataStudent> students,
    String? branchName,
    String? branchAddress,
    Uint8List? logoBytes,
    PdfPageFormat? pageFormat,
  }) async {
    final schoolName =
        TenantStorage.resolveSchoolName(branchName, fallback: 'School');
    final schoolAddress =
        TenantStorage.resolveSchoolAddress(branchAddress, fallback: '');
    logoBytes ??= await LogoRepository.loadLogoBytes();

    final rows = students.map((s) {
      final rollStr = s.rollNo > 0 ? '${s.rollNo}' : '-';
      final regStr = s.regId > 0 ? '${s.regId}' : '-';
      final nameStr =
          s.studentName.trim().isNotEmpty ? s.studentName.trim() : '-';
      final fatherStr =
          s.fatherName.trim().isNotEmpty ? s.fatherName.trim() : '-';
      final contactStr =
          (s.contactNo != null && s.contactNo!.trim().isNotEmpty)
              ? s.contactNo!.trim()
              : '-';
      final addressStr =
          (s.address != null && s.address!.trim().isNotEmpty)
              ? s.address!.trim()
              : '-';

      return [
        rollStr,
        regStr,
        nameStr,
        fatherStr,
        _formatDate(s.dob),
        _formatDate(s.admissionDate),
        contactStr,
        addressStr,
      ];
    }).toList();

    final group = Vb6ReportGroup(
      bandTitle:
          'Class: $className | Section: $sectionName | Enrolled Students: ${students.length}',
      rows: rows,
    );

    return Vb6TableReportPdf.generate(
      title: 'Class Biodata & Enrollment Roster',
      subtitle: 'Academic Session: $sessionYr',
      branchName: schoolName,
      branchAddress: schoolAddress,
      logoBytes: logoBytes,
      headers: kHeaders,
      rows: rows,
      groups: [group],
      columnAligns: const [
        Vb6ColumnAlign.center,
        Vb6ColumnAlign.center,
        Vb6ColumnAlign.left,
        Vb6ColumnAlign.left,
        Vb6ColumnAlign.center,
        Vb6ColumnAlign.center,
        Vb6ColumnAlign.left,
        Vb6ColumnAlign.left,
      ],
      landscape: true,
      pageFormat: pageFormat ?? PdfPageFormat.a4.landscape,
      optionalColumnIndices: const [6, 7],
    );
  }
}
