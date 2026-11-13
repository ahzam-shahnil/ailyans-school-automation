import 'dart:typed_data';

import 'package:flutter/material.dart' show Icons, IconData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/student.dart';
import '../db/database.dart';
import '../utils/vb6_table_report_pdf.dart';
import 'voucher_generation_provider.dart' show normalizeBillingMonthForStorage;

// ---------------------------------------------------------------------------
// Filter state (VB6 top filter bar)
// ---------------------------------------------------------------------------

/// Top filter bar state for the VB6 Reports Hub: Session Year, Billing Month,
/// Date, Class and Section.
class ReportsHubFilters {
  final String sessionYr;
  final String billingMonth;
  final DateTime? date;
  final int? classId;
  final int? sectionId;

  const ReportsHubFilters({
    this.sessionYr = '2017-2018',
    this.billingMonth = 'October 2017',
    this.date,
    this.classId,
    this.sectionId,
  });

  ReportsHubFilters copyWith({
    String? sessionYr,
    String? billingMonth,
    DateTime? date,
    bool clearDate = false,
    int? classId,
    bool clearClassId = false,
    int? sectionId,
    bool clearSectionId = false,
  }) {
    return ReportsHubFilters(
      sessionYr: sessionYr ?? this.sessionYr,
      billingMonth: billingMonth ?? this.billingMonth,
      date: clearDate ? null : (date ?? this.date),
      classId: clearClassId ? null : (classId ?? this.classId),
      sectionId: clearSectionId ? null : (sectionId ?? this.sectionId),
    );
  }
}

class ReportsHubFiltersNotifier extends StateNotifier<ReportsHubFilters> {
  ReportsHubFiltersNotifier() : super(const ReportsHubFilters());

  void setSessionYr(String sessionYr) =>
      state = state.copyWith(sessionYr: sessionYr);

  void setBillingMonth(String billingMonth) =>
      state = state.copyWith(billingMonth: billingMonth);

  void setDate(DateTime date) => state = state.copyWith(date: date);

  void setClassId(int? classId) => state = state.copyWith(
        classId: classId,
        clearClassId: classId == null,
        clearSectionId: true,
      );

  void setSectionId(int? sectionId) => state = state.copyWith(
        sectionId: sectionId,
        clearSectionId: sectionId == null,
      );
}

final reportsHubFiltersProvider =
    StateNotifierProvider<ReportsHubFiltersNotifier, ReportsHubFilters>((ref) {
      return ReportsHubFiltersNotifier();
    });

// ---------------------------------------------------------------------------
// Report definitions (the 14 one-click VB6 launcher cards)
// ---------------------------------------------------------------------------

class Vb6ReportDef {
  /// Stable report id, used for SQL dispatch and the PDF file name.
  final String id;

  /// Exact VB6 launcher label.
  final String title;

  /// Widget key suffix: `report_btn_<key>`.
  final String key;

  /// Category header shown above the grid section.
  final String category;

  final IconData icon;

  const Vb6ReportDef({
    required this.id,
    required this.title,
    required this.key,
    required this.category,
    required this.icon,
  });
}

const String kReportsCategoryStudents = 'Student Reports';
const String kReportsCategoryPayments = 'Payment Analysis';
const String kReportsCategoryDefaulters = 'Defaulters';

/// The 14 VB6 reports, in launcher order.
const List<Vb6ReportDef> kVb6Reports = [
  Vb6ReportDef(
    id: 'student_class_sec_wise',
    title: 'All Student Class/Sec wise',
    key: 'student_class_sec_wise',
    category: kReportsCategoryStudents,
    icon: Icons.class_outlined,
  ),
  Vb6ReportDef(
    id: 'student_blank_sheet',
    title: 'All Student - Blank',
    key: 'student_blank_sheet',
    category: kReportsCategoryStudents,
    icon: Icons.grid_on_outlined,
  ),
  Vb6ReportDef(
    id: 'school_leaving_all',
    title: 'School Leaving All Students',
    key: 'school_leaving_all',
    category: kReportsCategoryStudents,
    icon: Icons.exit_to_app_outlined,
  ),
  Vb6ReportDef(
    id: 'classwise_payments',
    title: 'Classwise Payments',
    key: 'classwise_payments',
    category: kReportsCategoryPayments,
    icon: Icons.payments_outlined,
  ),
  Vb6ReportDef(
    id: 'datewise_vouchers',
    title: 'Datewise Submitted Vouchers',
    key: 'datewise_vouchers',
    category: kReportsCategoryPayments,
    icon: Icons.event_available_outlined,
  ),
  Vb6ReportDef(
    id: 'payment_summary',
    title: 'Payment Summary',
    key: 'payment_summary',
    category: kReportsCategoryPayments,
    icon: Icons.summarize_outlined,
  ),
  Vb6ReportDef(
    id: 'classwise_paid_detail',
    title: 'Classwise Paid Detail',
    key: 'classwise_paid_detail',
    category: kReportsCategoryPayments,
    icon: Icons.fact_check_outlined,
  ),
  Vb6ReportDef(
    id: 'classwise_paid_summary',
    title: 'Classwise Paid Summary',
    key: 'classwise_paid_summary',
    category: kReportsCategoryPayments,
    icon: Icons.checklist_outlined,
  ),
  Vb6ReportDef(
    id: 'vouchers_with_discount',
    title: 'All Vouchers With Discount',
    key: 'vouchers_with_discount',
    category: kReportsCategoryPayments,
    icon: Icons.percent_outlined,
  ),
  Vb6ReportDef(
    id: 'bank_tally',
    title: 'Submitted Vouchers Tally With Bank',
    key: 'bank_tally',
    category: kReportsCategoryPayments,
    icon: Icons.account_balance_outlined,
  ),
  Vb6ReportDef(
    id: 'all_months_summary',
    title: 'All Months Summary',
    key: 'all_months_summary',
    category: kReportsCategoryPayments,
    icon: Icons.calendar_month_outlined,
  ),
  Vb6ReportDef(
    id: 'classwise_defaulters',
    title: 'Classwise Defaulters List',
    key: 'classwise_defaulters',
    category: kReportsCategoryDefaulters,
    icon: Icons.warning_amber_outlined,
  ),
  Vb6ReportDef(
    id: 'defaulter_summary',
    title: 'Defaulter List Summary',
    key: 'defaulter_summary',
    category: kReportsCategoryDefaulters,
    icon: Icons.trending_down_outlined,
  ),
  Vb6ReportDef(
    id: 'defaulter_detail',
    title: 'Defaulter List Detail',
    key: 'defaulter_detail',
    category: kReportsCategoryDefaulters,
    icon: Icons.person_search_outlined,
  ),
];

/// Categories in launcher display order.
const List<String> kVb6ReportCategories = [
  kReportsCategoryStudents,
  kReportsCategoryPayments,
  kReportsCategoryDefaulters,
];

// ---------------------------------------------------------------------------
// Data queries + PDF assembly
// ---------------------------------------------------------------------------

/// The result of a report query: headers, flat rows, and optional band groups.
class Vb6ReportData {
  final List<String> headers;
  final List<List<String>> rows;
  final List<Vb6ReportGroup>? groups;
  final List<Vb6ColumnAlign> columnAligns;
  final bool landscape;

  const Vb6ReportData({
    required this.headers,
    required this.rows,
    this.groups,
    this.columnAligns = const [],
    this.landscape = false,
  });
}

String _fmtDate(dynamic raw) {
  if (raw == null) return '';
  final s = raw.toString().trim();
  if (s.isEmpty) return '';
  final dt = DateTime.tryParse(s);
  if (dt != null) return DateFormat('dd-MMM-yyyy').format(dt);
  return s;
}

String _fmtAmount(dynamic raw) {
  final n = (raw as num?)?.toInt() ?? 0;
  return NumberFormat('#,##0').format(n);
}

/// Tolerant text read: SQLite dynamic typing can return numbers where TEXT is
/// expected (e.g. SLCertificate), so never cast with `as String?`.
String _str(dynamic v) {
  if (v == null) return '';
  return v.toString().trim();
}

String _studentName(Map<String, dynamic> r) => formatStudentFullName(
      r['NameFirst']?.toString(),
      r['NameMiddle']?.toString(),
      r['NameLast']?.toString(),
    );

/// Queries local SQLite for [reportId] with the current [filters] and returns
/// the table payload for the generic VB6 tabular PDF builder.
Future<Vb6ReportData> fetchVb6ReportRows(
  String reportId,
  ReportsHubFilters f,
) async {
  final db = await DatabaseService.instance.database;
  final forMonth = normalizeBillingMonthForStorage(f.billingMonth);
  final dateStr = f.date == null ? null : DateFormat('yyyy-MM-dd').format(f.date!);

  switch (reportId) {
    // 1. All Student Class/Sec wise — grouped roster.
    case 'student_class_sec_wise': {
      final raw = await db.rawQuery('''
        SELECT sc.Stu_RegID, sc.ClassRollNo, sc.ClassID, sc.ClassSecID,
               sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name,
               sr.DOB, sr.DOAdmission, sr.EmerContMobile, sr.P_Address,
               c.CName AS ClassName, cs.SecName
        FROM Student_Class sc
        JOIN Stu_Reg sr ON sr.Stu_RegID = sc.Stu_RegID
        LEFT JOIN Class c ON c.ClassID = sc.ClassID
        LEFT JOIN ClassSec cs ON cs.ClassSecID = sc.ClassSecID
        WHERE sc.Present = 1 AND sc.SessionYr = ?
          AND (? IS NULL OR sc.ClassID = ?)
          AND (? IS NULL OR sc.ClassSecID = ?)
        ORDER BY sc.ClassID ASC, sc.ClassSecID ASC, sc.ClassRollNo ASC, sc.Stu_RegID ASC
      ''', [f.sessionYr, f.classId, f.classId, f.sectionId, f.sectionId]);

      // Count students per Class/Sec band first, then build rows.
      final bandCounts = <String, int>{};
      final bandKeys = <String>[];
      for (final r in raw) {
        final cls = _str(r['ClassName']).isNotEmpty ? _str(r['ClassName']) : 'Class ${r['ClassID']}';
        final sec = _str(r['SecName']);
        final band = 'Class: $cls | Section: ${sec.isEmpty ? '-' : sec}';
        if (!bandCounts.containsKey(band)) {
          bandCounts[band] = 0;
          bandKeys.add(band);
        }
        bandCounts[band] = bandCounts[band]! + 1;
      }

      final groups = <Vb6ReportGroup>[];
      final rows = <List<String>>[];
      for (final r in raw) {
        rows.add([
          '${r['Stu_RegID']}',
          '${r['ClassRollNo'] ?? ''}',
          _studentName(r),
          _str(r['F_Name']),
          _fmtDate(r['DOB']),
          _fmtDate(r['DOAdmission']),
          _str(r['EmerContMobile']),
          _str(r['P_Address']),
        ]);
      }
      var cursor = 0;
      for (final band in bandKeys) {
        final n = bandCounts[band]!;
        groups.add(Vb6ReportGroup(
          bandTitle: '$band | No of students: $n',
          rows: rows.sublist(cursor, cursor + n),
        ));
        cursor += n;
      }

      return Vb6ReportData(
        headers: [
          'Reg ID',
          'Roll No',
          'Name',
          'Father Name',
          'DOB',
          'Date of Adm',
          'Emergency No',
          'Permanent Address',
        ],
        rows: rows,
        groups: groups,
        landscape: true,
      );
    }

    // 2. All Student - Blank — roll list + blank manual-entry columns.
    case 'student_blank_sheet': {
      final raw = await db.rawQuery('''
        SELECT sc.Stu_RegID, sc.ClassRollNo,
               sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name,
               c.CName AS ClassName
        FROM Student_Class sc
        JOIN Stu_Reg sr ON sr.Stu_RegID = sc.Stu_RegID
        LEFT JOIN Class c ON c.ClassID = sc.ClassID
        WHERE sc.Present = 1 AND sc.SessionYr = ?
          AND (? IS NULL OR sc.ClassID = ?)
          AND (? IS NULL OR sc.ClassSecID = ?)
        ORDER BY sc.ClassID ASC, sc.ClassRollNo ASC, sc.Stu_RegID ASC
      ''', [f.sessionYr, f.classId, f.classId, f.sectionId, f.sectionId]);

      final rows = raw.map((r) {
        return [
          '${r['Stu_RegID']}',
          '${r['ClassRollNo'] ?? ''}',
          _studentName(r),
          _str(r['F_Name']),
          '',
          '',
          '',
          '',
          '',
          '',
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Reg ID',
          'Roll No',
          'Name',
          'Father Name',
          ' ',
          ' ',
          ' ',
          ' ',
          ' ',
          ' ',
        ],
        rows: rows,
        landscape: true,
      );
    }

    // 3. School Leaving All Students — SchLeaving register.
    case 'school_leaving_all': {
      final raw = await db.rawQuery('''
        SELECT sl.StuRegID, sl.LeftDate, sl.LeftClass, sl.TermOfLeavign,
               sl.Charactor, sl.SLCertificate,
               sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name
        FROM SchLeaving sl
        JOIN Stu_Reg sr ON sr.Stu_RegID = sl.StuRegID
        ORDER BY sl.SLID ASC
      ''');

      final rows = raw.map((r) {
        return [
          '${r['StuRegID']}',
          _studentName(r),
          _str(r['F_Name']),
          _fmtDate(r['LeftDate']),
          '${r['LeftClass'] ?? ''}',
          _str(r['TermOfLeavign']),
          _str(r['Charactor']),
          _str(r['SLCertificate']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Reg ID',
          'Name',
          'Father Name',
          'Left Date',
          'Left Class',
          'Reason',
          'Conduct',
          'Certificate #',
        ],
        rows: rows,
        landscape: true,
      );
    }

    // 4. Classwise Payments — billed vs collected vs outstanding per class.
    case 'classwise_payments': {
      final raw = await db.rawQuery('''
        SELECT vm.ClassID, c.CName AS ClassName,
               COUNT(*) AS billedCount,
               COALESCE(SUM(vm.SubTotal), 0) AS gross,
               COALESCE(SUM(vm.Discount), 0) AS disc,
               COALESCE(SUM(CASE WHEN vm.IsPaid = 'Y' THEN vm.PaidAmt ELSE 0 END), 0) AS collected
        FROM VoucharMas vm
        LEFT JOIN Class c ON c.ClassID = vm.ClassID
        WHERE vm.ForMonth = ? AND vm.SessionYr = ?
          AND (? IS NULL OR vm.ClassID = ?)
        GROUP BY vm.ClassID
        ORDER BY vm.ClassID ASC
      ''', [forMonth, f.sessionYr, f.classId, f.classId]);

      final rows = raw.map((r) {
        final gross = (r['gross'] as num?)?.toInt() ?? 0;
        final disc = (r['disc'] as num?)?.toInt() ?? 0;
        final collected = (r['collected'] as num?)?.toInt() ?? 0;
        return [
          _str(r['ClassName']).isNotEmpty
              ? _str(r['ClassName'])
              : 'Class ${r['ClassID']}',
          '${r['billedCount']}',
          _fmtAmount(gross),
          _fmtAmount(disc),
          _fmtAmount(collected),
          _fmtAmount(gross - disc - collected),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Class',
          'Billed Vouchers',
          'Gross (Rs)',
          'Discounts (Rs)',
          'Collected (Rs)',
          'Outstanding (Rs)',
        ],
        rows: rows,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
        ],
      );
    }

    // 5. Datewise Submitted Vouchers — FeeTransaction rows.
    case 'datewise_vouchers': {
      final raw = await db.rawQuery('''
        SELECT ft.FeeTransID, ft.SubmissionDate, ft.VoucharNo, ft.PaidAmount,
               ft.TotalAmount, ft.Detail, b.BankName,
               vm.Student_Class_StuRegID AS RegID
        FROM FeeTransaction ft
        LEFT JOIN BankInfo b ON b.BankInfoID = ft.BankID
        LEFT JOIN VoucharMas vm ON vm.VoucherMasID = ft.VoucharNo
        WHERE (? IS NULL OR SUBSTR(ft.SubmissionDate, 1, 10) = ?)
        ORDER BY ft.SubmissionDate ASC, ft.FeeTransID ASC
      ''', [dateStr, dateStr]);

      final rows = raw.map((r) {
        return [
          _fmtDate(r['SubmissionDate']),
          '${r['VoucharNo'] ?? ''}',
          r['RegID'] == null ? '' : '${r['RegID']}',
          _fmtAmount(r['PaidAmount']),
          _str(r['BankName']),
          _str(r['Detail']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Date',
          'Voucher #',
          'Reg ID',
          'Paid Amount (Rs)',
          'Bank',
          'Detail',
        ],
        rows: rows,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
        ],
      );
    }

    // 6. Payment Summary — collection rollup by submission date.
    case 'payment_summary': {
      final raw = await db.rawQuery('''
        SELECT SUBSTR(ft.SubmissionDate, 1, 10) AS subDate,
               COUNT(*) AS txCount,
               COALESCE(SUM(ft.PaidAmount), 0) AS total
        FROM FeeTransaction ft
        WHERE (? IS NULL OR SUBSTR(ft.SubmissionDate, 1, 10) = ?)
        GROUP BY subDate
        ORDER BY subDate ASC
      ''', [dateStr, dateStr]);

      final rows = raw.map((r) {
        return [
          _fmtDate(r['subDate']),
          '${r['txCount']}',
          _fmtAmount(r['total']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const ['Date', 'Transactions', 'Total Collected (Rs)'],
        rows: rows,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
        ],
      );
    }

    // 7. Classwise Paid Detail — paid vouchers list.
    case 'classwise_paid_detail': {
      final raw = await db.rawQuery('''
        SELECT vm.VoucherMasID, vm.Student_Class_StuRegID,
               sr.NameFirst, sr.NameMiddle, sr.NameLast,
               c.CName AS ClassName, vm.ForMonth, vm.PaidAmt, vm.PaidDate,
               b.BankName
        FROM VoucharMas vm
        JOIN Stu_Reg sr ON sr.Stu_RegID = vm.Student_Class_StuRegID
        LEFT JOIN Class c ON c.ClassID = vm.ClassID
        LEFT JOIN BankInfo b ON b.BankInfoID = vm.BankID
        WHERE vm.IsPaid = 'Y' AND vm.SessionYr = ?
          AND (? IS NULL OR vm.ClassID = ?)
        ORDER BY vm.ClassID ASC, vm.PaidDate ASC, vm.VoucherMasID ASC
      ''', [f.sessionYr, f.classId, f.classId]);

      final rows = raw.map((r) {
        return [
          '${r['VoucherMasID']}',
          '${r['Student_Class_StuRegID']}',
          _studentName(r),
          _str(r['ClassName']),
          '${r['ForMonth'] ?? ''}',
          _fmtAmount(r['PaidAmt']),
          _fmtDate(r['PaidDate']),
          _str(r['BankName']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Voucher #',
          'Reg ID',
          'Name',
          'Class',
          'Month',
          'Paid Amount (Rs)',
          'Paid Date',
          'Bank',
        ],
        rows: rows,
        landscape: true,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
        ],
      );
    }

    // 8. Classwise Paid Summary — count + total per class.
    case 'classwise_paid_summary': {
      final raw = await db.rawQuery('''
        SELECT vm.ClassID, c.CName AS ClassName,
               COUNT(*) AS paidCount,
               COALESCE(SUM(vm.PaidAmt), 0) AS total
        FROM VoucharMas vm
        LEFT JOIN Class c ON c.ClassID = vm.ClassID
        WHERE vm.IsPaid = 'Y' AND vm.SessionYr = ?
          AND (? IS NULL OR vm.ClassID = ?)
        GROUP BY vm.ClassID
        ORDER BY vm.ClassID ASC
      ''', [f.sessionYr, f.classId, f.classId]);

      final rows = raw.map((r) {
        return [
          _str(r['ClassName']).isNotEmpty
              ? _str(r['ClassName'])
              : 'Class ${r['ClassID']}',
          '${r['paidCount']}',
          _fmtAmount(r['total']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const ['Class', 'Paid Vouchers', 'Total Collected (Rs)'],
        rows: rows,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
        ],
      );
    }

    // 9. All Vouchers With Discount — Discount/VMDiscount/FullDiscount.
    case 'vouchers_with_discount': {
      final raw = await db.rawQuery('''
        SELECT vm.VoucherMasID, vm.Student_Class_StuRegID,
               sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.VMDiscount, sr.FullDiscount,
               c.CName AS ClassName, vm.ForMonth, vm.SubTotal, vm.Discount
        FROM VoucharMas vm
        JOIN Stu_Reg sr ON sr.Stu_RegID = vm.Student_Class_StuRegID
        LEFT JOIN Class c ON c.ClassID = vm.ClassID
        WHERE vm.SessionYr = ?
          AND (vm.Discount > 0
               OR COALESCE(sr.VMDiscount, 0) > 0
               OR COALESCE(sr.FullDiscount, 0) = 1)
          AND (? IS NULL OR vm.ClassID = ?)
        ORDER BY vm.ClassID ASC, vm.VoucherMasID ASC
      ''', [f.sessionYr, f.classId, f.classId]);

      final rows = raw.map((r) {
        return [
          '${r['VoucherMasID']}',
          '${r['Student_Class_StuRegID']}',
          _studentName(r),
          _str(r['ClassName']),
          '${r['ForMonth'] ?? ''}',
          _fmtAmount(r['SubTotal']),
          _fmtAmount(r['Discount']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Voucher #',
          'Reg ID',
          'Name',
          'Class',
          'Month',
          'SubTotal (Rs)',
          'Discount (Rs)',
        ],
        rows: rows,
        landscape: true,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
        ],
      );
    }

    // 10. Submitted Vouchers Tally With Bank — grouped by BankInfo.
    case 'bank_tally': {
      final raw = await db.rawQuery('''
        SELECT b.BankInfoID, b.BankName, b.Branch, b.AcctNo,
               COUNT(*) AS voucherCount,
               COALESCE(SUM(ft.PaidAmount), 0) AS total
        FROM FeeTransaction ft
        JOIN BankInfo b ON b.BankInfoID = ft.BankID
        WHERE (? IS NULL OR SUBSTR(ft.SubmissionDate, 1, 10) = ?)
        GROUP BY b.BankInfoID
        ORDER BY b.BankName ASC
      ''', [dateStr, dateStr]);

      final rows = raw.map((r) {
        return [
          _str(r['BankName']),
          _str(r['Branch']),
          _str(r['AcctNo']),
          '${r['voucherCount']}',
          _fmtAmount(r['total']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Bank',
          'Branch',
          'Acct No',
          'Vouchers',
          'Total Paid (Rs)',
        ],
        rows: rows,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
        ],
      );
    }

    // 11. Classwise Defaulters List — unpaid vouchers with contact numbers.
    case 'classwise_defaulters': {
      final raw = await db.rawQuery('''
        SELECT vm.ClassID, c.CName AS ClassName, vm.Student_Class_StuRegID,
               sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name, sr.Mobile1,
               vm.ForMonth,
               (COALESCE(vm.SubTotal, 0) - COALESCE(vm.Discount, 0) - COALESCE(vm.PaidAmt, 0)) AS balance
        FROM VoucharMas vm
        JOIN Stu_Reg sr ON sr.Stu_RegID = vm.Student_Class_StuRegID
        LEFT JOIN Class c ON c.ClassID = vm.ClassID
        WHERE vm.IsPaid != 'Y' AND vm.SessionYr = ?
          AND (? IS NULL OR vm.ClassID = ?)
        ORDER BY vm.ClassID ASC, vm.Student_Class_StuRegID ASC
      ''', [f.sessionYr, f.classId, f.classId]);

      final rows = raw.map((r) {
        return [
          _str(r['ClassName']).isNotEmpty
              ? _str(r['ClassName'])
              : 'Class ${r['ClassID']}',
          '${r['Student_Class_StuRegID']}',
          _studentName(r),
          _str(r['F_Name']),
          _str(r['Mobile1']),
          '${r['ForMonth'] ?? ''}',
          _fmtAmount(r['balance']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Class',
          'Reg ID',
          'Name',
          'Father Name',
          'Mobile',
          'Month',
          'Balance (Rs)',
        ],
        rows: rows,
        landscape: true,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
        ],
      );
    }

    // 12. Defaulter List Summary — count + balance per class.
    case 'defaulter_summary': {
      final raw = await db.rawQuery('''
        SELECT vm.ClassID, c.CName AS ClassName,
               COUNT(*) AS defaulterCount,
               COALESCE(SUM(COALESCE(vm.SubTotal, 0) - COALESCE(vm.Discount, 0) - COALESCE(vm.PaidAmt, 0)), 0) AS balance
        FROM VoucharMas vm
        LEFT JOIN Class c ON c.ClassID = vm.ClassID
        WHERE vm.IsPaid != 'Y' AND vm.SessionYr = ?
          AND (? IS NULL OR vm.ClassID = ?)
        GROUP BY vm.ClassID
        ORDER BY vm.ClassID ASC
      ''', [f.sessionYr, f.classId, f.classId]);

      final rows = raw.map((r) {
        return [
          _str(r['ClassName']).isNotEmpty
              ? _str(r['ClassName'])
              : 'Class ${r['ClassID']}',
          '${r['defaulterCount']}',
          _fmtAmount(r['balance']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const ['Class', 'Defaulters', 'Total Unpaid (Rs)'],
        rows: rows,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
        ],
      );
    }

    // 13. Defaulter List Detail — per-student unpaid breakdown.
    case 'defaulter_detail': {
      final raw = await db.rawQuery('''
        SELECT vm.Student_Class_StuRegID,
               sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name, sr.Mobile1,
               c.CName AS ClassName,
               COUNT(*) AS voucherCount,
               COALESCE(SUM(COALESCE(vm.SubTotal, 0) - COALESCE(vm.Discount, 0) - COALESCE(vm.PaidAmt, 0)), 0) AS balance
        FROM VoucharMas vm
        JOIN Stu_Reg sr ON sr.Stu_RegID = vm.Student_Class_StuRegID
        LEFT JOIN Class c ON c.ClassID = vm.ClassID
        WHERE vm.IsPaid != 'Y' AND vm.SessionYr = ?
          AND (? IS NULL OR vm.ClassID = ?)
        GROUP BY vm.Student_Class_StuRegID
        ORDER BY balance DESC
      ''', [f.sessionYr, f.classId, f.classId]);

      final rows = raw.map((r) {
        return [
          '${r['Student_Class_StuRegID']}',
          _studentName(r),
          _str(r['F_Name']),
          _str(r['Mobile1']),
          _str(r['ClassName']),
          '${r['voucherCount']}',
          _fmtAmount(r['balance']),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Reg ID',
          'Name',
          'Father Name',
          'Mobile',
          'Class',
          'Unpaid Vouchers',
          'Balance (Rs)',
        ],
        rows: rows,
        landscape: true,
        columnAligns: const [
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
        ],
      );
    }

    // 14. All Months Summary — month-by-month billing vs collection.
    case 'all_months_summary': {
      final raw = await db.rawQuery('''
        SELECT vm.ForMonth,
               COUNT(*) AS billedCount,
               COALESCE(SUM(vm.SubTotal), 0) AS billed,
               COALESCE(SUM(CASE WHEN vm.IsPaid = 'Y' THEN vm.PaidAmt ELSE 0 END), 0) AS collected
        FROM VoucharMas vm
        WHERE vm.SessionYr = ?
          AND (? IS NULL OR vm.ClassID = ?)
        GROUP BY vm.ForMonth
      ''', [f.sessionYr, f.classId, f.classId]);

      int monthRank(String forMonth) {
        final parts = forMonth.split('-');
        if (parts.length != 2) return 9999 * 100 + 99;
        const months = [
          'jan', 'feb', 'mar', 'apr', 'may', 'jun',
          'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
        ];
        final y = int.tryParse(parts[1]) ?? 9999;
        final m = months.indexOf(parts[0].toLowerCase());
        return y * 100 + (m < 0 ? 99 : m + 1);
      }

      final sorted = raw.toList()
        ..sort((a, b) => monthRank('${a['ForMonth'] ?? ''}')
            .compareTo(monthRank('${b['ForMonth'] ?? ''}')));

      final rows = sorted.map((r) {
        final billed = (r['billed'] as num?)?.toInt() ?? 0;
        final collected = (r['collected'] as num?)?.toInt() ?? 0;
        return [
          '${r['ForMonth'] ?? ''}',
          '${r['billedCount']}',
          _fmtAmount(billed),
          _fmtAmount(collected),
          _fmtAmount(billed - collected),
        ];
      }).toList();

      return Vb6ReportData(
        headers: const [
          'Month',
          'Billed Vouchers',
          'Billed Amount (Rs)',
          'Collected (Rs)',
          'Outstanding (Rs)',
        ],
        rows: rows,
        columnAligns: const [
          Vb6ColumnAlign.left,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
          Vb6ColumnAlign.right,
        ],
      );
    }
  }

  throw StateError('Unknown VB6 report id: $reportId');
}

/// Builds the active-filter subtitle shown in the report banner.
String vb6ReportSubtitle(ReportsHubFilters f) {
  final month = normalizeBillingMonthForStorage(f.billingMonth);
  final parts = <String>[
    'Session: ${f.sessionYr}',
    'Month: $month',
    if (f.date != null) 'Date: ${DateFormat('yyyy-MM-dd').format(f.date!)}',
    'Class: ${f.classId ?? 'All'}',
    'Section: ${f.sectionId ?? 'All'}',
  ];
  return parts.join(' | ');
}

/// Fetches the rows for [reportId] and renders the generic VB6 tabular PDF.
Future<Uint8List> buildVb6ReportPdf({
  required String reportId,
  required String title,
  required ReportsHubFilters filters,
  required String branchName,
  required String branchAddress,
}) async {
  final data = await fetchVb6ReportRows(reportId, filters);
  return Vb6TableReportPdf.generate(
    title: title,
    subtitle: vb6ReportSubtitle(filters),
    branchName: branchName,
    branchAddress: branchAddress,
    headers: data.headers,
    rows: data.rows,
    groups: data.groups,
    columnAligns: data.columnAligns,
    landscape: data.landscape,
  );
}
