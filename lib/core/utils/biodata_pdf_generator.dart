// ignore_for_file: public_member_api_docs
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'voucher_pdf_generator.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

class StudentEnrollmentHistoryRow {
  final String sessionYr;
  final String className;
  final String sectionName;
  final int classRollNo;
  final bool isPresent;

  const StudentEnrollmentHistoryRow({
    required this.sessionYr,
    required this.className,
    required this.sectionName,
    required this.classRollNo,
    required this.isPresent,
  });
}

class StudentBiodataPrintData {
  final int stuRegId;
  final String studentName;
  final String? nameMiddle;
  final DateTime? dob;
  final String? sex;
  final String? religion;
  final String? nationality;
  final String? bFormNo;
  final String? photoPath;
  final String? fatherName;
  final String? cnicNo;
  final String? occupation;
  final String? mobile1;
  final String? mobile2;
  final String? phoneOffice;
  final String? phoneRes;
  final String? emerContName;
  final String? emerContMobile;
  final String? pAddress;
  final String? tAddress;
  final String? pSchool;
  final String? pClass;
  final String? slCertificate;
  final int? admInClass;
  final String? admClassName;
  final DateTime? doAdmission;
  final double? discount;
  final int? vmDiscount;
  final int fullDiscount;
  final String? officeFile;
  final String? remarks;
  final List<StudentEnrollmentHistoryRow> enrollmentHistory;
  final int feeTotalBilled;
  final int feeTotalPaid;
  final int feeBalance;
  final String currentClassSection;

  const StudentBiodataPrintData({
    required this.stuRegId,
    required this.studentName,
    this.nameMiddle,
    this.dob,
    this.sex,
    this.religion,
    this.nationality,
    this.bFormNo,
    this.photoPath,
    this.fatherName,
    this.cnicNo,
    this.occupation,
    this.mobile1,
    this.mobile2,
    this.phoneOffice,
    this.phoneRes,
    this.emerContName,
    this.emerContMobile,
    this.pAddress,
    this.tAddress,
    this.pSchool,
    this.pClass,
    this.slCertificate,
    this.admInClass,
    this.admClassName,
    this.doAdmission,
    this.discount,
    this.vmDiscount,
    required this.fullDiscount,
    this.officeFile,
    this.remarks,
    required this.enrollmentHistory,
    required this.feeTotalBilled,
    required this.feeTotalPaid,
    required this.feeBalance,
    required this.currentClassSection,
  });
}

// ============================================================================
// PDF GENERATOR
// ============================================================================

class BiodataPdfGenerator {
  static const PdfColor _navy = PdfColor.fromInt(0xFF1E3A8A);
  static const PdfColor _lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor _green800 = PdfColor.fromInt(0xFF166534);
  static const PdfColor _red800 = PdfColor.fromInt(0xFF991B1B);
  static const PdfColor _avatarBg = PdfColor.fromInt(0xFFE2E8F0);

  static Future<Uint8List> generateStudentBiodata({
    required StudentBiodataPrintData data,
    required String branchName,
    required String branchAddress,
    String? branchPhone,
    String? branchPrincipal,
  }) async {
    final doc = pw.Document();

    Uint8List? photoBytes;
    if (data.photoPath != null && data.photoPath!.trim().isNotEmpty) {
      try {
        final file = File(data.photoPath!);
        if (file.existsSync() && file.lengthSync() < 500 * 1024) {
          photoBytes = file.readAsBytesSync();
        }
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        footer: (context) =>
            ReportTheme.buildStandardFooter(context, branchName: branchName),
        build: (context) => [
          // Top Institutional Header
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 2)),
            ),
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 28,
                        height: 28,
                        decoration: const pw.BoxDecoration(
                          color: _navy,
                          borderRadius: pw.BorderRadius.all(
                            pw.Radius.circular(2),
                          ),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'AH',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            branchName,
                            style: const pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: _navy,
                            ),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            branchAddress,
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Phone: ${branchPhone ?? "-"}  |  Principal: ${branchPrincipal ?? "-"}',
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 150,
                  decoration: pw.BoxDecoration(
                    color: _lightBg,
                    border: pw.Border.all(color: _borderColor, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(2),
                    ),
                  ),
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OFFICIAL STUDENT DOSSIER',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: _navy,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Reg ID: #${data.stuRegId}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Class: ${data.currentClassSection}',
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Standing: ${data.currentClassSection == "Not Enrolled" ? "INACTIVE" : "ACTIVE"}',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: data.currentClassSection == "Not Enrolled"
                              ? PdfColors.grey600
                              : _green800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Title
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'STUDENT BIODATA DOSSIER',
              style: const pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 2, bottom: 4),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Registration ID: #${data.stuRegId}',
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Container(
            height: 1,
            color: _navy,
            margin: const pw.EdgeInsets.only(bottom: 6),
          ),

          // Section 01: Student Identity & Guardian Particulars
          ReportTheme.fullWidthSectionHeader(
            'SEC-01',
            '1. STUDENT IDENTITY & GUARDIAN PARTICULARS',
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 82,
                child: ReportTheme.borderedTable(
                  flexColumnWidths: [1, 1, 1],
                  children: [
                    pw.TableRow(
                      children: [
                        ReportTheme.gridCell(
                          'FULL LEGAL NAME',
                          data.studentName,
                          isBold: true,
                        ),
                        ReportTheme.gridCell('MIDDLE NAME', data.nameMiddle),
                        ReportTheme.gridCell(
                          'DATE OF BIRTH',
                          ReportTheme.formatDate(data.dob),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        ReportTheme.gridCell('GENDER', data.sex),
                        ReportTheme.gridCell(
                          'RELIGION',
                          data.religion ?? 'Islam',
                        ),
                        ReportTheme.gridCell(
                          'NATIONALITY',
                          data.nationality ?? 'Pakistani',
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        ReportTheme.gridCell(
                          'NADRA B-FORM / CRC',
                          data.bFormNo,
                        ),
                        ReportTheme.gridCell(
                          'FATHER / GUARDIAN NAME',
                          data.fatherName,
                          isBold: true,
                        ),
                        ReportTheme.gridCell(
                          'FATHER CNIC',
                          data.cnicNo,
                          isBold: true,
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        ReportTheme.gridCell(
                          'GUARDIAN OCCUPATION',
                          data.occupation,
                        ),
                        ReportTheme.gridCell(
                          'PRIMARY MOBILE (SMS)',
                          data.mobile1,
                          isBold: true,
                        ),
                        ReportTheme.gridCell('SECONDARY MOBILE', data.mobile2),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Container(
                width: 86,
                height: 108,
                decoration: pw.BoxDecoration(
                  color: _lightBg,
                  border: pw.Border.all(color: _borderColor, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(2),
                  ),
                ),
                padding: const pw.EdgeInsets.all(4),
                child: photoBytes != null
                    ? pw.Image(
                        pw.MemoryImage(photoBytes),
                        width: 78,
                        height: 98,
                        fit: pw.BoxFit.cover,
                      )
                    : pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 50,
                            height: 50,
                            decoration: const pw.BoxDecoration(
                              color: _avatarBg,
                              shape: pw.BoxShape.circle,
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              _getInitials(data.studentName),
                              style: const pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'PASSPORT PHOTO',
                            style: const pw.TextStyle(
                              fontSize: 6,
                              color: PdfColors.grey600,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.Text(
                            'NOT ATTACHED',
                            style: const pw.TextStyle(
                              fontSize: 5.5,
                              color: PdfColors.grey500,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ],
          ),

          // Section 02: Contact Telephones & Domicile Address
          ReportTheme.fullWidthSectionHeader(
            'SEC-02',
            '2. CONTACT TELEPHONES & DOMICILE ADDRESS',
          ),
          ReportTheme.borderedTable(
            flexColumnWidths: [1, 1, 1, 1],
            children: [
              pw.TableRow(
                children: [
                  ReportTheme.gridCell('OFFICE TELEPHONE', data.phoneOffice),
                  ReportTheme.gridCell('RESIDENCE PHONE', data.phoneRes),
                  ReportTheme.gridCell(
                    'EMERGENCY CONTACT PERSON',
                    data.emerContName,
                  ),
                  ReportTheme.gridCell(
                    'EMERGENCY CONTACT MOBILE',
                    data.emerContMobile,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          ReportTheme.borderedTable(
            flexColumnWidths: [1, 1],
            children: [
              pw.TableRow(
                children: [
                  ReportTheme.gridCell(
                    'PERMANENT RESIDENTIAL ADDRESS',
                    data.pAddress,
                  ),
                  ReportTheme.gridCell(
                    'PRESENT MAILING ADDRESS',
                    data.tAddress,
                  ),
                ],
              ),
            ],
          ),

          // Section 03: Academic Placement & Prior Schooling
          ReportTheme.fullWidthSectionHeader(
            'SEC-03',
            '3. ACADEMIC PLACEMENT & PRIOR SCHOOLING',
          ),
          ReportTheme.borderedTable(
            flexColumnWidths: [1, 1, 1],
            children: [
              pw.TableRow(
                children: [
                  ReportTheme.gridCell(
                    'CURRENT CLASS & SECTION',
                    data.currentClassSection,
                    isBold: true,
                    valueColor: _navy,
                  ),
                  ReportTheme.gridCell(
                    'DATE OF INITIAL ADMISSION',
                    ReportTheme.formatDate(data.doAdmission),
                  ),
                  ReportTheme.gridCell(
                    'ADMITTED IN CLASS',
                    data.admClassName ?? data.admInClass?.toString(),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  ReportTheme.gridCell(
                    'PREVIOUS SCHOOL ATTENDED',
                    data.pSchool,
                  ),
                  ReportTheme.gridCell('PREVIOUS CLASS PASSED', data.pClass),
                  ReportTheme.gridCell(
                    'PREVIOUS SLC SERIAL NO',
                    data.slCertificate,
                  ),
                ],
              ),
            ],
          ),

          // Section 04: Tuition Concessions & Fee Ledger Summary
          ReportTheme.fullWidthSectionHeader(
            'SEC-04',
            '4. TUITION CONCESSIONS & FEE LEDGER SUMMARY',
          ),
          ReportTheme.borderedTable(
            flexColumnWidths: [1, 1, 1, 1, 1, 1, 1],
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _navy),
                children: [
                  for (final label in [
                    'MONTHLY CONC',
                    'VOUCHER ADJ',
                    '100% WAIVER',
                    'FILE NO',
                    'TOTAL BILLED',
                    'TOTAL PAID',
                    'BALANCE',
                  ])
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      alignment: label.startsWith('TOTAL') || label == 'BALANCE'
                          ? pw.Alignment.centerRight
                          : pw.Alignment.centerLeft,
                      child: pw.Text(
                        label,
                        style: const pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                ],
              ),
              // Data row
              pw.TableRow(
                children: [
                  ReportTheme.gridCell(
                    '',
                    'Rs. ${ReportTheme.formatCurrency(data.discount ?? 0)}',
                  ),
                  ReportTheme.gridCell('', 'Rs. ${data.vmDiscount ?? 0}'),
                  ReportTheme.gridCell(
                    '',
                    data.fullDiscount == 1 ? 'YES' : 'NO',
                  ),
                  ReportTheme.gridCell('', data.officeFile),
                  ReportTheme.gridCell(
                    '',
                    'Rs. ${ReportTheme.formatCurrency(data.feeTotalBilled)}',
                    isBold: true,
                    alignment: pw.Alignment.topRight,
                  ),
                  ReportTheme.gridCell(
                    '',
                    'Rs. ${ReportTheme.formatCurrency(data.feeTotalPaid)}',
                    isBold: true,
                    valueColor: _green800,
                    alignment: pw.Alignment.topRight,
                  ),
                  ReportTheme.gridCell(
                    '',
                    'Rs. ${ReportTheme.formatCurrency(data.feeBalance)}',
                    isBold: true,
                    valueColor: data.feeBalance > 0 ? _red800 : _green800,
                    alignment: pw.Alignment.topRight,
                  ),
                ],
              ),
            ],
          ),

          // Section 05: Enrollment History
          ReportTheme.fullWidthSectionHeader(
            'SEC-05',
            '5. ACADEMIC SESSION ENROLLMENT HISTORY',
          ),
          ReportTheme.borderedTable(
            flexColumnWidths: [2, 2, 2, 2],
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _navy),
                children: [
                  for (final label in [
                    'SESSION',
                    'CLASS & SECTION',
                    'ROLL NO',
                    'STANDING',
                  ])
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      alignment: label == 'ROLL NO'
                          ? pw.Alignment.center
                          : pw.Alignment.centerLeft,
                      child: pw.Text(
                        label,
                        style: const pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                ],
              ),
              // Data rows
              if (data.enrollmentHistory.isEmpty)
                pw.TableRow(
                  children: [
                    ReportTheme.gridCell('', '-'),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'No enrollment history recorded',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ),
                    ReportTheme.gridCell(
                      '',
                      '-',
                      alignment: pw.Alignment.topCenter,
                    ),
                    ReportTheme.gridCell('', '-'),
                  ],
                )
              else
                for (int i = 0; i < data.enrollmentHistory.length; i++)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : _lightBg,
                    ),
                    children: [
                      ReportTheme.gridCell(
                        '',
                        data.enrollmentHistory[i].sessionYr,
                      ),
                      ReportTheme.gridCell(
                        '',
                        '${data.enrollmentHistory[i].className}-${data.enrollmentHistory[i].sectionName}',
                      ),
                      ReportTheme.gridCell(
                        '',
                        data.enrollmentHistory[i].classRollNo
                            .toString()
                            .padLeft(2, '0'),
                        alignment: pw.Alignment.topCenter,
                      ),
                      ReportTheme.gridCell(
                        '',
                        data.enrollmentHistory[i].isPresent ? 'Active' : 'Past',
                        valueColor: data.enrollmentHistory[i].isPresent
                            ? _green800
                            : PdfColors.grey600,
                      ),
                    ],
                  ),
            ],
          ),

          // Section 06: Administrative Remarks (conditional)
          if (data.remarks != null && data.remarks!.trim().isNotEmpty) ...[
            ReportTheme.fullWidthSectionHeader(
              'SEC-06',
              '6. ADMINISTRATIVE REMARKS',
            ),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Text(
                data.remarks!.trim(),
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ],

          // Signature footer
          pw.SizedBox(height: 12),
          ReportTheme.signatureFooter(
            leftLabel: 'Prepared By (Registrar)',
            rightLabel: 'Checked By (Accountant)',
            thirdLabel: 'Principal Signature & Stamp',
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
