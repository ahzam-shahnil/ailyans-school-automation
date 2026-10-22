// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/fee_receipt_view.dart';

// ============================================================================
// CORE DESIGN SYSTEM & FORMATTING UTILITIES
// ============================================================================

class ReportTheme {
  static const PdfColor primaryColor = PdfColors.blue900;
  static const PdfColor secondaryColor = PdfColors.blueGrey800;
  static const PdfColor bannerBgColor = PdfColors.blue50;
  static const PdfColor tableHeaderBg = PdfColors.blue900;
  static const PdfColor tableRowAltBg = PdfColors.grey100;
  static const PdfColor borderRuleColor = PdfColors.grey300;
  static const PdfColor dangerTextColor = PdfColors.red800;
  static const PdfColor successTextColor = PdfColors.green800;

  static final NumberFormat currencyFormat = NumberFormat('#,##0.00', 'en_US');
  static final DateFormat dateFormat = DateFormat('dd-MMM-yyyy');

  static String formatCurrency(num? value) {
    if (value == null) return '0.00';
    return currencyFormat.format(value);
  }

  static String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return dateFormat.format(date);
  }

  static pw.TextStyle get titleStyle => const pw.TextStyle(
    fontSize: 16,
    fontWeight: pw.FontWeight.bold,
    color: primaryColor,
  );

  static pw.TextStyle get subtitleStyle => const pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.normal,
    color: secondaryColor,
  );

  static pw.TextStyle get sectionBannerStyle => const pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
    color: primaryColor,
  );

  static pw.TextStyle get tableHeaderStyle => const pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.white,
  );

  static pw.TextStyle get tableCellStyle =>
      const pw.TextStyle(fontSize: 8.5, color: PdfColors.black);

  static pw.TextStyle get tableFooterStyle => const pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: primaryColor,
  );

  static pw.Widget buildStandardFooter(
    pw.Context context, {
    String? branchName,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: borderRuleColor, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            branchName ??
                'Alams High School Mianwali - Automated School System',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Generated: ${formatDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DATA MODELS: 1. LIST OF CLASSES WITH SECTIONS
// ============================================================================

class StudentSectionRecord {
  final int stuRegId; // Stu_Reg.Stu_RegID / Student_Class.Stu_RegID
  final String classRollNo; // Student_Class.ClassRollNo
  final String nameFirst; // Stu_Reg.NameFirst
  final String nameMiddle; // Stu_Reg.NameMiddle
  final String nameLast; // Stu_Reg.NameLast
  final String fatherName; // Stu_Reg.F_Name
  final bool isPresent; // Student_Class.Present

  const StudentSectionRecord({
    required this.stuRegId,
    required this.classRollNo,
    required this.nameFirst,
    this.nameMiddle = '',
    this.nameLast = '',
    required this.fatherName,
    this.isPresent = true,
  });

  String get fullName => [
    nameFirst,
    nameMiddle,
    nameLast,
  ].where((part) => part.trim().isNotEmpty).join(' ');

  factory StudentSectionRecord.fromMap(Map<String, dynamic> map) {
    return StudentSectionRecord(
      stuRegId:
          int.tryParse(
            (map['Student_Class_StuRegID'] ?? map['Stu_RegID'] ?? '0')
                .toString(),
          ) ??
          0,
      classRollNo: (map['ClassRollNo'] ?? '').toString(),
      nameFirst: (map['NameFirst'] ?? '').toString(),
      nameMiddle: (map['NameMiddle'] ?? '').toString(),
      nameLast: (map['NameLast'] ?? '').toString(),
      fatherName: (map['F_Name'] ?? '').toString(),
      isPresent:
          map['Present'] == true ||
          map['Present']?.toString().toLowerCase() == 'yes' ||
          map['Present'] == 1,
    );
  }
}

class ClassSectionGroup {
  final int classId; // Class.ClassID
  final int classSecId; // ClassSec.ClassSecID
  final String className; // Class.CName
  final String sectionName; // ClassSec.SecName
  final String sectionTeacher; // Teachers.TName (via ClassSec.SecTeacher)
  final String sectionProctor; // ClassSec.SecProctor
  final String roomNo; // ClassSec.RoomNo
  final String remarks; // ClassSec.Remarks
  final String sessionYear; // Student_Class.SessionYr
  final List<StudentSectionRecord> students;

  const ClassSectionGroup({
    required this.classId,
    required this.classSecId,
    required this.className,
    required this.sectionName,
    required this.sectionTeacher,
    required this.sectionProctor,
    required this.roomNo,
    this.remarks = '',
    required this.sessionYear,
    required this.students,
  });

  factory ClassSectionGroup.fromMap(Map<String, dynamic> map) {
    final rawStudents = map['students'] as List<dynamic>? ?? [];
    return ClassSectionGroup(
      classId: int.tryParse((map['ClassID'] ?? '0').toString()) ?? 0,
      classSecId: int.tryParse((map['ClassSecID'] ?? '0').toString()) ?? 0,
      className: (map['CName'] ?? '').toString(),
      sectionName: (map['SecName'] ?? '').toString(),
      sectionTeacher: (map['SecTeacher'] ?? map['TName'] ?? 'Unassigned')
          .toString(),
      sectionProctor: (map['SecProctor'] ?? 'N/A').toString(),
      roomNo: (map['RoomNo'] ?? 'N/A').toString(),
      remarks: (map['Remarks'] ?? '').toString(),
      sessionYear: (map['SessionYr'] ?? '').toString(),
      students: rawStudents
          .map(
            (e) => e is StudentSectionRecord
                ? e
                : StudentSectionRecord.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
          )
          .toList(),
    );
  }
}

// ============================================================================
// GENERATOR 1: ClassSectionListGenerator
// ============================================================================

class ClassSectionListGenerator {
  final String institutionName;
  final String reportTitle;
  final List<ClassSectionGroup> sectionGroups;

  const ClassSectionListGenerator({
    this.institutionName = 'Alams High School Mianwali',
    this.reportTitle = 'Academic Class & Section Structural Roster',
    required this.sectionGroups,
  });

  Future<Uint8List> generatePdf({
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document(title: reportTitle, author: institutionName);

    final totalSections = sectionGroups.length;
    final totalStudents = sectionGroups.fold<int>(
      0,
      (sum, group) => sum + group.students.length,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(context),
        footer: (context) => ReportTheme.buildStandardFooter(
          context,
          branchName: institutionName,
        ),
        build: (context) => [
          ...sectionGroups.map(_buildSectionBlock),
          pw.SizedBox(height: 12),
          _buildGrandSummaryBanner(totalSections, totalStudents),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(pw.Context context) {
    final sessionLabel = sectionGroups.isNotEmpty
        ? sectionGroups.first.sessionYear
        : 'Current Session';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(institutionName, style: ReportTheme.titleStyle),
              pw.SizedBox(height: 2),
              pw.Text(reportTitle, style: ReportTheme.subtitleStyle),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: ReportTheme.bannerBgColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: ReportTheme.borderRuleColor),
            ),
            child: pw.Text(
              'Academic Session: $sessionLabel',
              style: const pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: ReportTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionBlock(ClassSectionGroup group) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: ReportTheme.bannerBgColor,
            border: pw.Border.all(color: ReportTheme.primaryColor, width: 0.6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Class: ${group.className} (ID: ${group.classId})  |  Section: ${group.sectionName} (SecID: ${group.classSecId})',
                    style: ReportTheme.sectionBannerStyle,
                  ),
                  pw.Text(
                    'Room No: ${group.roomNo}',
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: ReportTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Class Teacher: ${group.sectionTeacher}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Section Proctor: ${group.sectionProctor}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Enrolled Students: ${group.students.length}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (group.remarks.trim().isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'Remarks: ${group.remarks}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ],
          ),
        ),
        _buildStudentsTable(group.students),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildStudentsTable(List<StudentSectionRecord> students) {
    if (students.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: ReportTheme.borderRuleColor),
        ),
        child: pw.Text(
          'No students registered in this section.',
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: ReportTheme.borderRuleColor,
        width: 0.5,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(35), // S.No
        1: pw.FixedColumnWidth(65), // Reg ID
        2: pw.FixedColumnWidth(65), // Roll No
        3: pw.FlexColumnWidth(2.2), // Student Full Name
        4: pw.FlexColumnWidth(2.0), // Father Name
        5: pw.FixedColumnWidth(55), // Status
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: ReportTheme.tableHeaderBg),
          children: [
            _cell('S.No', isHeader: true, align: pw.Alignment.center),
            _cell('Reg ID', isHeader: true, align: pw.Alignment.center),
            _cell('Roll No', isHeader: true, align: pw.Alignment.center),
            _cell(
              'Student Full Name',
              isHeader: true,
              align: pw.Alignment.centerLeft,
            ),
            _cell(
              'Father / Guardian Name',
              isHeader: true,
              align: pw.Alignment.centerLeft,
            ),
            _cell('Status', isHeader: true, align: pw.Alignment.center),
          ],
        ),
        ...List.generate(students.length, (index) {
          final stu = students[index];
          final isEven = index.isEven;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : ReportTheme.tableRowAltBg,
            ),
            children: [
              _cell('${index + 1}', align: pw.Alignment.center),
              _cell('${stu.stuRegId}', align: pw.Alignment.center),
              _cell(stu.classRollNo, align: pw.Alignment.center),
              _cell(stu.fullName, align: pw.Alignment.centerLeft),
              _cell(stu.fatherName, align: pw.Alignment.centerLeft),
              _cell(
                stu.isPresent ? 'Active' : 'Inactive',
                align: pw.Alignment.center,
                textColor: stu.isPresent
                    ? ReportTheme.successTextColor
                    : ReportTheme.dangerTextColor,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildGrandSummaryBanner(int totalSections, int totalStudents) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: ReportTheme.primaryColor,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'GRAND ROSTER SUMMARY',
            style: const pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            'Total Sections: $totalSections   |   Total Enrolled Students: $totalStudents',
            style: const pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _cell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    PdfColor? textColor,
  }) {
    final baseStyle = isHeader
        ? ReportTheme.tableHeaderStyle
        : ReportTheme.tableCellStyle;
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: textColor != null
            ? baseStyle.copyWith(color: textColor)
            : baseStyle,
      ),
    );
  }
}

// ============================================================================
// DATA MODELS: 2. FEE TRANSACTION & MASTER LEDGER
// ============================================================================

class VoucherFeeDetailItem {
  final int feeParamId; // VoucharDet.FeeParamID / feeParameterID
  final String parameterTitle; // Fee parameter description
  final double amount; // VoucharDet.Amount

  const VoucherFeeDetailItem({
    required this.feeParamId,
    required this.parameterTitle,
    required this.amount,
  });

  factory VoucherFeeDetailItem.fromMap(Map<String, dynamic> map) {
    return VoucherFeeDetailItem(
      feeParamId:
          int.tryParse(
            (map['FeeParamID'] ?? map['feeParameterID'] ?? '0').toString(),
          ) ??
          0,
      parameterTitle: (map['ParamDescription'] ?? map['Detail'] ?? 'Fee Head')
          .toString(),
      amount: double.tryParse((map['Amount'] ?? '0').toString()) ?? 0.0,
    );
  }
}

class FeeVoucherTransactionRecord {
  final int voucherMasId; // VoucharMas.VoucherMasID
  final String voucharNo; // VoucharMas.VoucharNo / FeeTransaction.VoucharNo
  final int stuRegId; // Student_Class_StuRegID / Stu_Reg.Stu_RegID
  final String studentFullName; // NameFirst + NameMiddle + NameLast
  final String className; // Class.CName
  final String forMonth; // VoucharMas.ForMonth (e.g. "Jan-2017")
  final bool isPaid; // VoucharMas.IsPaid
  final DateTime? dueDate; // VoucharMas.DueDate
  final DateTime? submissionDate; // FeeTransaction.SubmissionDate
  final double subTotal; // VoucharMas.SubTotal
  final double discount; // VoucharMas.Discount / SumOfDiscount
  final double totalAmount; // FeeTransaction.TotalAmount
  final double paidAmount; // FeeTransaction.PaidAmount
  final List<VoucherFeeDetailItem> feeBreakdown;

  const FeeVoucherTransactionRecord({
    required this.voucherMasId,
    required this.voucharNo,
    required this.stuRegId,
    required this.studentFullName,
    required this.className,
    required this.forMonth,
    required this.isPaid,
    this.dueDate,
    this.submissionDate,
    required this.subTotal,
    required this.discount,
    required this.totalAmount,
    required this.paidAmount,
    this.feeBreakdown = const [],
  });

  /// Net payable computed directly if totalAmount is zero/unpopulated
  double get computedNetPayable =>
      totalAmount > 0 ? totalAmount : (subTotal - discount);

  /// Balance arrears per transaction
  double get balanceAmount => computedNetPayable - paidAmount;

  factory FeeVoucherTransactionRecord.fromMap(Map<String, dynamic> map) {
    final first = (map['NameFirst'] ?? '').toString().trim();
    final middle = (map['NameMiddle'] ?? '').toString().trim();
    final last = (map['NameLast'] ?? '').toString().trim();
    final combinedName = [
      first,
      middle,
      last,
    ].where((s) => s.isNotEmpty).join(' ');

    final rawBreakdown = map['feeBreakdown'] as List<dynamic>? ?? [];
    final parsedDetails = rawBreakdown
        .map(
          (e) => e is VoucherFeeDetailItem
              ? e
              : VoucherFeeDetailItem.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
        )
        .toList();

    final parsedSubTotal =
        double.tryParse(
          (map['SubTotal'] ?? map['SumOfAmount'] ?? '0').toString(),
        ) ??
        parsedDetails.fold<double>(0.0, (s, item) => s + item.amount);

    final parsedDiscount =
        double.tryParse(
          (map['Discount'] ?? map['SumOfDiscount'] ?? '0').toString(),
        ) ??
        0.0;

    final parsedTotal =
        double.tryParse((map['TotalAmount'] ?? '0').toString()) ??
        (parsedSubTotal - parsedDiscount);

    return FeeVoucherTransactionRecord(
      voucherMasId: int.tryParse((map['VoucherMasID'] ?? '0').toString()) ?? 0,
      voucharNo: (map['VoucharNo'] ?? map['VoucherMasID'] ?? '').toString(),
      stuRegId:
          int.tryParse(
            (map['Student_Class_StuRegID'] ?? map['Stu_RegID'] ?? '0')
                .toString(),
          ) ??
          0,
      studentFullName: combinedName.isNotEmpty
          ? combinedName
          : (map['StudentName'] ?? 'Unknown Student').toString(),
      className: (map['CName'] ?? 'N/A').toString(),
      forMonth: (map['ForMonth'] ?? 'N/A').toString(),
      isPaid:
          map['IsPaid'] == true ||
          map['IsPaid']?.toString().toUpperCase() == 'Y' ||
          map['IsPaid']?.toString().toLowerCase() == 'yes' ||
          map['IsPaid'] == 1,
      dueDate: map['DueDate'] is DateTime
          ? map['DueDate'] as DateTime
          : DateTime.tryParse((map['DueDate'] ?? '').toString()),
      submissionDate: map['SubmissionDate'] is DateTime
          ? map['SubmissionDate'] as DateTime
          : DateTime.tryParse((map['SubmissionDate'] ?? '').toString()),
      subTotal: parsedSubTotal,
      discount: parsedDiscount,
      totalAmount: parsedTotal,
      paidAmount: double.tryParse((map['PaidAmount'] ?? '0').toString()) ?? 0.0,
      feeBreakdown: parsedDetails,
    );
  }

  factory FeeVoucherTransactionRecord.fromFeeReceipt(
    FeeReceiptView receipt, {
    required String className,
  }) {
    final syntheticId =
        int.tryParse(
          '${receipt.voucherMasId.split("-").first}${receipt.stuRegId}',
        ) ??
        0;
    return FeeVoucherTransactionRecord(
      voucherMasId: syntheticId,
      voucharNo: receipt.voucherMasId,
      stuRegId: receipt.stuRegId,
      studentFullName: receipt.studentName,
      className: className,
      forMonth: receipt.forMonth,
      isPaid: receipt.isPaid == 'Y',
      dueDate: receipt.dueDate,
      submissionDate: receipt.paidDate,
      subTotal: receipt.subtotal.toDouble(),
      discount: receipt.discount.toDouble(),
      totalAmount: receipt.netPayable.toDouble(),
      paidAmount: receipt.paidAmount.toDouble(),
      feeBreakdown: receipt.lineItems
          .map(
            (li) => VoucherFeeDetailItem(
              feeParamId: li.feeParamId,
              parameterTitle: li.headName,
              amount: li.amount.toDouble(),
            ),
          )
          .toList(),
    );
  }
}

// ============================================================================
// GENERATOR 2: FeeLedgerVoucherGenerator
// ============================================================================

class FeeLedgerVoucherGenerator {
  final String institutionName;
  final String ledgerPeriodTitle;
  final List<FeeVoucherTransactionRecord> transactions;
  final bool includeParameterBreakdown;

  const FeeLedgerVoucherGenerator({
    this.institutionName = 'Alams High School Mianwali',
    this.ledgerPeriodTitle = 'Fee Transaction & Master Financial Ledger',
    required this.transactions,
    this.includeParameterBreakdown = true,
  });

  Future<Uint8List> generatePdf({
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document(title: ledgerPeriodTitle, author: institutionName);

    // Pre-calculate ledger totals
    double grandSubTotal = 0;
    double grandDiscount = 0;
    double grandNetTotal = 0;
    double grandPaidTotal = 0;
    double grandBalanceTotal = 0;
    int paidCount = 0;
    int unpaidCount = 0;

    for (final tx in transactions) {
      grandSubTotal += tx.subTotal;
      grandDiscount += tx.discount;
      grandNetTotal += tx.computedNetPayable;
      grandPaidTotal += tx.paidAmount;
      grandBalanceTotal += tx.balanceAmount;
      if (tx.isPaid) {
        paidCount++;
      } else {
        unpaidCount++;
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        header: (context) =>
            _buildLedgerHeader(paidCount: paidCount, unpaidCount: unpaidCount),
        footer: (context) => ReportTheme.buildStandardFooter(
          context,
          branchName: institutionName,
        ),
        build: (context) => [
          _buildMasterTransactionTable(
            grandSubTotal: grandSubTotal,
            grandDiscount: grandDiscount,
            grandNetTotal: grandNetTotal,
            grandPaidTotal: grandPaidTotal,
            grandBalanceTotal: grandBalanceTotal,
          ),
          if (includeParameterBreakdown &&
              transactions.any((t) => t.feeBreakdown.isNotEmpty)) ...[
            pw.SizedBox(height: 18),
            _buildFeeParameterSubLedger(),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildLedgerHeader({
    required int paidCount,
    required int unpaidCount,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(institutionName, style: ReportTheme.titleStyle),
              pw.SizedBox(height: 2),
              pw.Text(ledgerPeriodTitle, style: ReportTheme.subtitleStyle),
            ],
          ),
          pw.Row(
            children: [
              _buildBadge(
                'Paid Vouchers: $paidCount',
                ReportTheme.successTextColor,
              ),
              pw.SizedBox(width: 8),
              _buildBadge(
                'Unpaid Vouchers: $unpaidCount',
                ReportTheme.dangerTextColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBadge(String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _buildMasterTransactionTable({
    required double grandSubTotal,
    required double grandDiscount,
    required double grandNetTotal,
    required double grandPaidTotal,
    required double grandBalanceTotal,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: ReportTheme.borderRuleColor,
        width: 0.5,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(42), // VoucherNo
        1: pw.FixedColumnWidth(38), // RegID
        2: pw.FlexColumnWidth(2.2), // Student & Class
        3: pw.FixedColumnWidth(46), // ForMonth
        4: pw.FixedColumnWidth(52), // Due / Sub Date
        5: pw.FixedColumnWidth(54), // SubTotal
        6: pw.FixedColumnWidth(46), // Discount
        7: pw.FixedColumnWidth(54), // Net Total
        8: pw.FixedColumnWidth(54), // Paid
        9: pw.FixedColumnWidth(54), // Balance
      },
      children: [
        // Table Header
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: ReportTheme.tableHeaderBg),
          children: [
            _ledgerCell('V.No', isHeader: true, align: pw.Alignment.centerLeft),
            _ledgerCell(
              'RegID',
              isHeader: true,
              align: pw.Alignment.centerLeft,
            ),
            _ledgerCell(
              'Student Name (Class)',
              isHeader: true,
              align: pw.Alignment.centerLeft,
            ),
            _ledgerCell(
              'Month',
              isHeader: true,
              align: pw.Alignment.centerLeft,
            ),
            _ledgerCell(
              'Sub. Date',
              isHeader: true,
              align: pw.Alignment.centerLeft,
            ),
            _ledgerCell(
              'SubTotal',
              isHeader: true,
              align: pw.Alignment.centerRight,
            ),
            _ledgerCell(
              'Discount',
              isHeader: true,
              align: pw.Alignment.centerRight,
            ),
            _ledgerCell(
              'Net Amt',
              isHeader: true,
              align: pw.Alignment.centerRight,
            ),
            _ledgerCell(
              'Paid Amt',
              isHeader: true,
              align: pw.Alignment.centerRight,
            ),
            _ledgerCell(
              'Balance',
              isHeader: true,
              align: pw.Alignment.centerRight,
            ),
          ],
        ),
        // Data Rows
        ...List.generate(transactions.length, (index) {
          final tx = transactions[index];
          final isEven = index.isEven;
          final dateLabel = tx.submissionDate != null
              ? ReportTheme.formatDate(tx.submissionDate)
              : (tx.dueDate != null
                    ? 'Due: ${ReportTheme.formatDate(tx.dueDate)}'
                    : 'Unpaid');

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : ReportTheme.tableRowAltBg,
            ),
            children: [
              _ledgerCell(tx.voucharNo, align: pw.Alignment.centerLeft),
              _ledgerCell('${tx.stuRegId}', align: pw.Alignment.centerLeft),
              _ledgerCell(
                '${tx.studentFullName} (${tx.className})',
                align: pw.Alignment.centerLeft,
              ),
              _ledgerCell(tx.forMonth, align: pw.Alignment.centerLeft),
              _ledgerCell(dateLabel, align: pw.Alignment.centerLeft),
              _ledgerCell(
                ReportTheme.formatCurrency(tx.subTotal),
                align: pw.Alignment.centerRight,
              ),
              _ledgerCell(
                ReportTheme.formatCurrency(tx.discount),
                align: pw.Alignment.centerRight,
              ),
              _ledgerCell(
                ReportTheme.formatCurrency(tx.computedNetPayable),
                align: pw.Alignment.centerRight,
              ),
              _ledgerCell(
                ReportTheme.formatCurrency(tx.paidAmount),
                align: pw.Alignment.centerRight,
                textColor: tx.isPaid
                    ? ReportTheme.successTextColor
                    : ReportTheme.dangerTextColor,
              ),
              _ledgerCell(
                ReportTheme.formatCurrency(tx.balanceAmount),
                align: pw.Alignment.centerRight,
                textColor: tx.balanceAmount > 0.009
                    ? ReportTheme.dangerTextColor
                    : PdfColors.black,
              ),
            ],
          );
        }),
        // Auto-Calculated Summary Footer Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: ReportTheme.bannerBgColor),
          children: [
            _ledgerCell(
              'TOTAL',
              isFooter: true,
              align: pw.Alignment.centerLeft,
            ),
            _ledgerCell(
              '${transactions.length} Recs',
              isFooter: true,
              align: pw.Alignment.centerLeft,
            ),
            _ledgerCell(
              'Grand Financial Totals',
              isFooter: true,
              align: pw.Alignment.centerLeft,
            ),
            _ledgerCell('-', isFooter: true, align: pw.Alignment.centerLeft),
            _ledgerCell('-', isFooter: true, align: pw.Alignment.centerLeft),
            _ledgerCell(
              ReportTheme.formatCurrency(grandSubTotal),
              isFooter: true,
              align: pw.Alignment.centerRight,
            ),
            _ledgerCell(
              ReportTheme.formatCurrency(grandDiscount),
              isFooter: true,
              align: pw.Alignment.centerRight,
            ),
            _ledgerCell(
              ReportTheme.formatCurrency(grandNetTotal),
              isFooter: true,
              align: pw.Alignment.centerRight,
            ),
            _ledgerCell(
              ReportTheme.formatCurrency(grandPaidTotal),
              isFooter: true,
              align: pw.Alignment.centerRight,
            ),
            _ledgerCell(
              ReportTheme.formatCurrency(grandBalanceTotal),
              isFooter: true,
              align: pw.Alignment.centerRight,
            ),
          ],
        ),
      ],
    );
  }

  /// Aggregates VoucharDet fee parameters (FeeParamID / feeParameterID & Amount)
  pw.Widget _buildFeeParameterSubLedger() {
    final Map<int, String> paramNames = {};
    final Map<int, double> paramTotals = {};

    for (final tx in transactions) {
      for (final item in tx.feeBreakdown) {
        paramNames[item.feeParamId] = item.parameterTitle;
        paramTotals[item.feeParamId] =
            (paramTotals[item.feeParamId] ?? 0.0) + item.amount;
      }
    }

    final sortedParamIds = paramTotals.keys.toList()..sort();
    final double totalBreakdownSum = paramTotals.values.fold(
      0.0,
      (sum, val) => sum + val,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: ReportTheme.bannerBgColor,
            border: pw.Border(
              left: pw.BorderSide(color: ReportTheme.primaryColor, width: 3),
            ),
          ),
          child: pw.Text(
            'Voucher Detail Breakdown by Fee Parameter Head (VoucharDet)',
            style: ReportTheme.sectionBannerStyle,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(
            color: ReportTheme.borderRuleColor,
            width: 0.5,
          ),
          columnWidths: const {
            0: pw.FixedColumnWidth(80),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(110),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: ReportTheme.tableHeaderBg,
              ),
              children: [
                _ledgerCell(
                  'FeeParamID',
                  isHeader: true,
                  align: pw.Alignment.centerLeft,
                ),
                _ledgerCell(
                  'Fee Parameter Description',
                  isHeader: true,
                  align: pw.Alignment.centerLeft,
                ),
                _ledgerCell(
                  'Aggregated Amount',
                  isHeader: true,
                  align: pw.Alignment.centerRight,
                ),
              ],
            ),
            ...sortedParamIds.map((id) {
              return pw.TableRow(
                children: [
                  _ledgerCell('$id', align: pw.Alignment.centerLeft),
                  _ledgerCell(
                    paramNames[id] ?? 'Parameter #$id',
                    align: pw.Alignment.centerLeft,
                  ),
                  _ledgerCell(
                    ReportTheme.formatCurrency(paramTotals[id]),
                    align: pw.Alignment.centerRight,
                  ),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
              ),
              children: [
                _ledgerCell(
                  'NET HEADS',
                  isFooter: true,
                  align: pw.Alignment.centerLeft,
                ),
                _ledgerCell(
                  'Total Gross Parameter Allocation',
                  isFooter: true,
                  align: pw.Alignment.centerLeft,
                ),
                _ledgerCell(
                  ReportTheme.formatCurrency(totalBreakdownSum),
                  isFooter: true,
                  align: pw.Alignment.centerRight,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _ledgerCell(
    String text, {
    bool isHeader = false,
    bool isFooter = false,
    required pw.Alignment align,
    PdfColor? textColor,
  }) {
    pw.TextStyle style = ReportTheme.tableCellStyle;
    if (isHeader) {
      style = ReportTheme.tableHeaderStyle;
    } else if (isFooter) {
      style = ReportTheme.tableFooterStyle;
    }
    if (textColor != null) {
      style = style.copyWith(color: textColor);
    }

    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(text, style: style),
    );
  }
}

// ============================================================================
// DATA MODELS: 3. CLASS PARAMETER FEES & BRANCH CONFIGURATION
// ============================================================================

class InstitutionBranchProfile {
  final String branchName; // InstBranch.BranchName
  final String branchAddress; // InstBranch.BranchAddress
  final String brContactPerson; // InstBranch.BrContactPerson
  final String brPrincipal; // InstBranch.BrPrincipal
  final String brPhone; // InstBranch.BrPhone
  final String brEmailAddress; // InstBranch.BrEmailAddress

  const InstitutionBranchProfile({
    required this.branchName,
    required this.branchAddress,
    required this.brContactPerson,
    required this.brPrincipal,
    required this.brPhone,
    required this.brEmailAddress,
  });

  factory InstitutionBranchProfile.fromMap(Map<String, dynamic> map) {
    return InstitutionBranchProfile(
      branchName: (map['BranchName'] ?? 'Alams High School Mianwali')
          .toString(),
      branchAddress: (map['BranchAddress'] ?? 'Mianwali, Punjab').toString(),
      brContactPerson: (map['BrContactPerson'] ?? 'Admin').toString(),
      brPrincipal: (map['BrPrincipal'] ?? 'Principal').toString(),
      brPhone: (map['BrPhone'] ?? 'N/A').toString(),
      brEmailAddress: (map['BrEmailAddress'] ?? 'N/A').toString(),
    );
  }
}

class ClassFeeParamItem {
  final int clsParamFeeId; // Cls_Param_Fee.Cls_Param_Fee_ID
  final int classId; // Class.ClassID
  final String className; // Class.CName
  final String feeYr; // Cls_Param_Fee.FeeYr
  final String paramDescription; // Cls_Param_Fee.ParamDescription
  final double allocatedAmount; // Baseline fee amount

  const ClassFeeParamItem({
    required this.clsParamFeeId,
    required this.classId,
    required this.className,
    required this.feeYr,
    required this.paramDescription,
    required this.allocatedAmount,
  });

  factory ClassFeeParamItem.fromMap(Map<String, dynamic> map) {
    return ClassFeeParamItem(
      clsParamFeeId:
          int.tryParse((map['Cls_Param_Fee_ID'] ?? '0').toString()) ?? 0,
      classId: int.tryParse((map['ClassID'] ?? '0').toString()) ?? 0,
      className: (map['CName'] ?? 'Uncategorized Class').toString(),
      feeYr: (map['FeeYr'] ?? 'Current').toString(),
      paramDescription: (map['ParamDescription'] ?? '').toString(),
      allocatedAmount:
          double.tryParse(
            (map['Amount'] ?? map['FeeAmount'] ?? '0').toString(),
          ) ??
          0.0,
    );
  }
}

// ============================================================================
// GENERATOR 3: ClassFeeParamGenerator
// ============================================================================

class ClassFeeParamGenerator {
  final InstitutionBranchProfile branchProfile;
  final List<ClassFeeParamItem> feeParameters;

  const ClassFeeParamGenerator({
    required this.branchProfile,
    required this.feeParameters,
  });

  Future<Uint8List> generatePdf({
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document(
      title: 'Class Parameter Fees Matrix - ${branchProfile.branchName}',
      author: branchProfile.branchName,
    );

    // Group parameters by ClassName + FeeYr for clean structural sections
    final Map<String, List<ClassFeeParamItem>> groupedByClass = {};
    for (final item in feeParameters) {
      final key = '${item.className}  (Fee Year: ${item.feeYr})';
      groupedByClass.putIfAbsent(key, () => []).add(item);
    }

    final double grandBaselineTotal = feeParameters.fold<double>(
      0.0,
      (sum, item) => sum + item.allocatedAmount,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildBranchHeader(),
        footer: (context) => ReportTheme.buildStandardFooter(
          context,
          branchName: branchProfile.branchName,
        ),
        build: (context) => [
          ...groupedByClass.entries.map(
            (entry) => _buildClassFeeGroupSection(entry.key, entry.value),
          ),
          pw.SizedBox(height: 10),
          _buildGrandBaselineFooter(grandBaselineTotal),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildBranchHeader() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: ReportTheme.bannerBgColor,
        border: pw.Border.all(color: ReportTheme.primaryColor, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(branchProfile.branchName, style: ReportTheme.titleStyle),
              pw.Text(
                'CLASS PARAMETER FEES CONFIGURATION',
                style: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: ReportTheme.secondaryColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Address: ${branchProfile.branchAddress}',
            style: const pw.TextStyle(fontSize: 8.5),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: ReportTheme.borderRuleColor, height: 1),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Principal: ${branchProfile.brPrincipal}',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Contact Person: ${branchProfile.brContactPerson}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
              pw.Text(
                'Phone: ${branchProfile.brPhone}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
              pw.Text(
                'Email: ${branchProfile.brEmailAddress}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildClassFeeGroupSection(
    String groupTitle,
    List<ClassFeeParamItem> items,
  ) {
    final double classSubTotal = items.fold<double>(
      0.0,
      (sum, item) => sum + item.allocatedAmount,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(color: ReportTheme.primaryColor),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                groupTitle,
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                'Parameters: ${items.length}',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(
            color: ReportTheme.borderRuleColor,
            width: 0.5,
          ),
          columnWidths: const {
            0: pw.FixedColumnWidth(75), // Cls_Param_Fee_ID
            1: pw.FixedColumnWidth(70), // FeeYr
            2: pw.FlexColumnWidth(3), // ParamDescription
            3: pw.FixedColumnWidth(100), // Amount
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: ReportTheme.secondaryColor,
              ),
              children: [
                _paramCell(
                  'Param ID',
                  isHeader: true,
                  align: pw.Alignment.centerLeft,
                ),
                _paramCell(
                  'Fee Year',
                  isHeader: true,
                  align: pw.Alignment.centerLeft,
                ),
                _paramCell(
                  'Parameter Description',
                  isHeader: true,
                  align: pw.Alignment.centerLeft,
                ),
                _paramCell(
                  'Baseline Fee',
                  isHeader: true,
                  align: pw.Alignment.centerRight,
                ),
              ],
            ),
            ...List.generate(items.length, (idx) {
              final item = items[idx];
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: idx.isEven
                      ? PdfColors.white
                      : ReportTheme.tableRowAltBg,
                ),
                children: [
                  _paramCell(
                    '${item.clsParamFeeId}',
                    align: pw.Alignment.centerLeft,
                  ),
                  _paramCell(item.feeYr, align: pw.Alignment.centerLeft),
                  _paramCell(
                    item.paramDescription,
                    align: pw.Alignment.centerLeft,
                  ),
                  _paramCell(
                    ReportTheme.formatCurrency(item.allocatedAmount),
                    align: pw.Alignment.centerRight,
                  ),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
              ),
              children: [
                _paramCell(
                  'SUBTOTAL',
                  isFooter: true,
                  align: pw.Alignment.centerLeft,
                ),
                _paramCell('-', isFooter: true, align: pw.Alignment.centerLeft),
                _paramCell(
                  'Total Class Baseline Package',
                  isFooter: true,
                  align: pw.Alignment.centerLeft,
                ),
                _paramCell(
                  ReportTheme.formatCurrency(classSubTotal),
                  isFooter: true,
                  align: pw.Alignment.centerRight,
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _buildGrandBaselineFooter(double grandTotal) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: ReportTheme.bannerBgColor,
        border: pw.Border.all(color: ReportTheme.primaryColor, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'CUMULATIVE INSTITUTIONAL FEE MATRIX TOTAL (${feeParameters.length} Heads)',
            style: ReportTheme.tableFooterStyle,
          ),
          pw.Text(
            ReportTheme.formatCurrency(grandTotal),
            style: ReportTheme.tableFooterStyle.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  pw.Widget _paramCell(
    String text, {
    bool isHeader = false,
    bool isFooter = false,
    required pw.Alignment align,
  }) {
    pw.TextStyle style = ReportTheme.tableCellStyle;
    if (isHeader) {
      style = ReportTheme.tableHeaderStyle;
    } else if (isFooter) {
      style = ReportTheme.tableFooterStyle;
    }

    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text, style: style),
    );
  }
}

// ============================================================================
// GENERATOR 4: ThreeCopyVouchersPdf (SCHOOL | BANK | STUDENT)
// ============================================================================

class ThreeCopyVouchersPdf {
  static Future<Uint8List> generate({
    required List<FeeReceiptView> vouchers,
    required String branchName,
    required String branchAddress,
    required String bankName,
    required String bankBranch,
    required String bankAcctNo,
  }) async {
    final doc = pw.Document(
      title: 'Fee Vouchers — $branchName',
      author: branchName,
    );
    for (final v in vouchers) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(branchName, branchAddress),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Expanded(
                      child: _buildCopy(
                        v,
                        'SCHOOL COPY',
                        bankName,
                        bankBranch,
                        bankAcctNo,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: _buildCopy(
                        v,
                        'BANK COPY',
                        bankName,
                        bankBranch,
                        bankAcctNo,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: _buildCopy(
                        v,
                        'STUDENT COPY',
                        bankName,
                        bankBranch,
                        bankAcctNo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _buildHeader(String name, String address) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: ReportTheme.titleStyle),
          pw.SizedBox(height: 2),
          pw.Text(address, style: ReportTheme.subtitleStyle),
        ],
      ),
    );
  }

  static pw.Widget _buildCopy(
    FeeReceiptView v,
    String copyLabel,
    String bankName,
    String bankBranch,
    String bankAcctNo,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: ReportTheme.borderRuleColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Copy label badge
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            decoration: const pw.BoxDecoration(color: ReportTheme.primaryColor),
            child: pw.Text(
              copyLabel,
              style: const pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          // Bank info
          pw.Text(
            'Bank: $bankName — $bankBranch',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text('A/C: $bankAcctNo', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 6),
          // Metadata grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'No: ${v.voucherMasId}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: ReportTheme.primaryColor,
                ),
              ),
              pw.Text(
                'Month: ${v.forMonth}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Issue: ${ReportTheme.formatDate(v.issueDate)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Due: ${ReportTheme.formatDate(v.dueDate)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          // Student box
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: ReportTheme.bannerBgColor,
              border: pw.Border.all(
                color: ReportTheme.borderRuleColor,
                width: 0.5,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Student: ${v.studentName}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Father: ${v.fatherName.isEmpty ? "N/A" : v.fatherName}',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
                pw.Text(
                  'Reg: ${v.stuRegId} | '
                  '${v.className ?? "N/A"}-${v.sectionName ?? "N/A"}'
                  '${v.rollNo != null ? " | Roll: ${v.rollNo}" : ""}',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          // Line items
          pw.Expanded(
            child: pw.Table(
              border: pw.TableBorder.all(
                color: ReportTheme.borderRuleColor,
                width: 0.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: ReportTheme.tableHeaderBg,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        'Fee Head',
                        style: ReportTheme.tableHeaderStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        'Amount',
                        style: ReportTheme.tableHeaderStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                ...v.lineItems.map(
                  (li) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          li.headName,
                          style: ReportTheme.tableCellStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          ReportTheme.formatCurrency(li.amount),
                          style: ReportTheme.tableCellStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          // Totals
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SubTotal:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                ReportTheme.formatCurrency(v.subtotal),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Discount:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                ReportTheme.formatCurrency(v.discount),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.Divider(color: ReportTheme.primaryColor, height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'NET PAYABLE:',
                style: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: ReportTheme.primaryColor,
                ),
              ),
              pw.Text(
                'Rs. ${ReportTheme.formatCurrency(v.netPayable)}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: ReportTheme.primaryColor,
                ),
              ),
            ],
          ),
          if (v.isFullyPaid) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Paid on: ${ReportTheme.formatDate(v.paidDate)}',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.green800,
                  ),
                ),
                pw.Text(
                  'Paid: ${ReportTheme.formatCurrency(v.paidAmount)}',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.green800,
                  ),
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 4),
          // Signature lines
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Cashier: _______',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text('Bank: _______', style: const pw.TextStyle(fontSize: 7)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRINT PREVIEW HELPER
// ============================================================================

Future<void> showVoucherPrintPreviewDialog(
  BuildContext context, {
  required List<FeeReceiptView> vouchers,
  required String branchName,
  required String branchAddress,
  required String bankName,
  required String bankBranch,
  required String bankAcctNo,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      int mode = 0; // 0 = 3-copy slips, 1 = cohort ledger
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            child: SizedBox(
              width: 1000,
              height: 760,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Print Preview — ${vouchers.length} Voucher(s)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('3-Copy Slips'),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('Cohort Ledger'),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged: (s) =>
                              setState(() => mode = s.first),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PdfPreview(
                      build: (format) => mode == 0
                          ? ThreeCopyVouchersPdf.generate(
                              vouchers: vouchers,
                              branchName: branchName,
                              branchAddress: branchAddress,
                              bankName: bankName,
                              bankBranch: bankBranch,
                              bankAcctNo: bankAcctNo,
                            )
                          : FeeLedgerVoucherGenerator(
                              institutionName: branchName,
                              ledgerPeriodTitle:
                                  'Cohort Ledger — ${vouchers.isNotEmpty ? vouchers.first.forMonth : ""}',
                              transactions: vouchers
                                  .map(
                                    (v) =>
                                        FeeVoucherTransactionRecord.fromFeeReceipt(
                                          v,
                                          className: v.className ?? '',
                                        ),
                                  )
                                  .toList(),
                            ).generatePdf(),
                      canChangeOrientation: true,
                      canDebug: false,
                      pdfFileName:
                          'ailyans_vouchers_${DateTime.now().millisecondsSinceEpoch}.pdf',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
