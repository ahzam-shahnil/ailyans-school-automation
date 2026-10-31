library fee_receipt_view;

import 'dart:math';

import 'package:school_automation/core/utils/fee_head_display.dart';

/// Production Fee Receipt Model for FeeCollectionScreen (/fees/receipts).
/// Matches Behavior Spec §S19 (frmVoucharRecipt @ 0x0041c754).

class FeeReceiptLineItem {
  final int feeParamId;
  final String headName; // FeeParameters.ParamDesciption (preserved verbatim)
  final int amount; // VoucharDet.Amount
  final int discount; // VoucharDet.Discount

  const FeeReceiptLineItem({
    required this.feeParamId,
    required this.headName,
    required this.amount,
    this.discount = 0,
  });

  int get net => amount - discount;

  factory FeeReceiptLineItem.fromMap(Map<String, dynamic> map) {
    return FeeReceiptLineItem(
      feeParamId: (map['feeParameterID'] as num?)?.toInt() ?? 0,
      headName: FeeHeadDisplay.of(map['ParamDesciption'] as String?),
      amount: (map['Amount'] as num?)?.toInt() ?? 0,
      discount: (map['Discount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Lightweight model representing an individual payment installment transaction.
class VoucherPaymentInstallment {
  final int feeTransId;
  final String submissionDate;
  final int paidAmount;
  final int? bankId;
  final String? bankName;
  final String? detail;

  const VoucherPaymentInstallment({
    required this.feeTransId,
    required this.submissionDate,
    required this.paidAmount,
    this.bankId,
    this.bankName,
    this.detail,
  });

  factory VoucherPaymentInstallment.fromMap(Map<String, dynamic> map) {
    return VoucherPaymentInstallment(
      feeTransId: (map['FeeTransID'] as num?)?.toInt() ?? 0,
      submissionDate: (map['SubmissionDate'] as String?)?.trim() ?? '',
      paidAmount: (map['PaidAmount'] as num?)?.toInt() ?? 0,
      bankId: (map['BankID'] as num?)?.toInt(),
      bankName: (map['BankName'] as String?)?.trim(),
      detail: (map['Detail'] as String?)?.trim(),
    );
  }
}

class FeeReceiptView {
  final String voucherMasId;
  final int stuRegId;
  final String studentName; // NameFirst + NameLast
  final String fatherName; // F_Name
  final String? className; // Class.CName
  final String? sectionName; // ClassSec.SecName
  final int? rollNo; // Student_Class.ClassRollNo
  final String? sessionYr; // Student_Class.SessionYr
  final String? photoPath; // Stu_Reg.photo_path
  final String forMonth; // VoucharMas.ForMonth
  final DateTime? issueDate; // VoucharMas.VDate
  final DateTime? dueDate; // VoucharMas.DueDate
  final int subtotal; // VoucharMas.SubTotal
  final int discount; // VoucharMas.Discount
  final int paidAmount; // VoucharMas.PaidAmt
  final DateTime? paidDate; // VoucharMas.PaidDate
  final int? bankId; // VoucharMas.BankID
  final String isPaid; // 'Y' | 'N' | 'O'
  final List<FeeReceiptLineItem> lineItems;
  final int advanceBalance; // SUM(StuAdv.AdvAmount) for this student
  final List<VoucherPaymentInstallment> paymentHistory;

  const FeeReceiptView({
    required this.voucherMasId,
    required this.stuRegId,
    required this.studentName,
    required this.fatherName,
    this.className,
    this.sectionName,
    this.rollNo,
    this.sessionYr,
    this.photoPath,
    required this.forMonth,
    this.issueDate,
    this.dueDate,
    required this.subtotal,
    required this.discount,
    this.paidAmount = 0,
    this.paidDate,
    this.bankId,
    required this.isPaid,
    required this.lineItems,
    this.advanceBalance = 0,
    this.paymentHistory = const [],
  });

  int get netPayable => subtotal - discount;
  int get paidAmt => paidAmount;
  int get remainingBalance => max(0, (subtotal - discount) - paidAmount);
  int get remainingAfterAdvance =>
      max(0, remainingBalance - advanceBalance);
  bool get isFullyPaid => isPaid == 'Y' && remainingBalance == 0;
  bool get isPartiallyPaid => paidAmount > 0 && remainingBalance > 0;
  bool get isOverdue =>
      isPaid == 'O' ||
      (dueDate != null && DateTime.now().isAfter(dueDate!) && !isFullyPaid);
  String get status {
    if (isFullyPaid) return 'Paid';
    if (isPartiallyPaid) return 'Partially Paid';
    if (isOverdue) return 'Overdue';
    return 'Unpaid';
  }

  FeeReceiptView copyWith({
    String? voucherMasId,
    int? stuRegId,
    String? studentName,
    String? fatherName,
    String? className,
    String? sectionName,
    int? rollNo,
    String? sessionYr,
    String? photoPath,
    String? forMonth,
    DateTime? issueDate,
    DateTime? dueDate,
    int? subtotal,
    int? discount,
    int? paidAmount,
    DateTime? Function()? paidDate,
    int? Function()? bankId,
    String? isPaid,
    List<FeeReceiptLineItem>? lineItems,
    int? advanceBalance,
    List<VoucherPaymentInstallment>? paymentHistory,
  }) {
    return FeeReceiptView(
      voucherMasId: voucherMasId ?? this.voucherMasId,
      stuRegId: stuRegId ?? this.stuRegId,
      studentName: studentName ?? this.studentName,
      fatherName: fatherName ?? this.fatherName,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      rollNo: rollNo ?? this.rollNo,
      sessionYr: sessionYr ?? this.sessionYr,
      photoPath: photoPath ?? this.photoPath,
      forMonth: forMonth ?? this.forMonth,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      paidAmount: paidAmount ?? this.paidAmount,
      paidDate: paidDate != null ? paidDate() : this.paidDate,
      bankId: bankId != null ? bankId() : this.bankId,
      isPaid: isPaid ?? this.isPaid,
      lineItems: lineItems ?? this.lineItems,
      advanceBalance: advanceBalance ?? this.advanceBalance,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }

  /// Convenience factory that accepts a flat joined row (VoucharMas+Stu_Reg+etc.)
  /// plus separately-fetched line-item maps. Used by _loadGeneratedVouchers().
  factory FeeReceiptView.fromFlatMap(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> lineItems,
    List<VoucherPaymentInstallment> paymentHistory = const [],
  }) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      final str = val.toString().trim();
      if (str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    final first = (row['NameFirst'] as String?)?.trim() ?? '';
    final last = (row['NameLast'] as String?)?.trim() ?? '';
    final studentName = [first, last].where((s) => s.isNotEmpty).join(' ');

    return FeeReceiptView(
      voucherMasId: row['VoucherMasID'] as String,
      stuRegId:
          ((row['Student_Class_StuRegID'] ??
                      row['student_class_StuRegId'] ??
                      row['Stu_RegID'])
                  as num?)
              ?.toInt() ??
          0,
      studentName: studentName.isNotEmpty ? studentName : 'Unknown Student',
      fatherName: (row['F_Name'] as String?)?.trim() ?? '',
      className: row['class_name'] as String?,
      sectionName: row['section_name'] as String?,
      rollNo: (row['ClassRollNo'] as num?)?.toInt(),
      sessionYr: row['SessionYr'] as String?,
      photoPath: row['photo_path'] as String?,
      forMonth: (row['ForMonth'] as String?) ?? '',
      issueDate: parseDate(row['VDate']),
      dueDate: parseDate(row['DueDate']),
      subtotal: (row['SubTotal'] as num?)?.toInt() ?? 0,
      discount: (row['Discount'] as num?)?.toInt() ?? 0,
      paidAmount: (row['PaidAmt'] as num?)?.toInt() ?? 0,
      paidDate: parseDate(row['PaidDate']),
      bankId: (row['BankID'] as num?)?.toInt(),
      isPaid: (row['IsPaid'] as String?) ?? 'N',
      lineItems: lineItems.map((m) => FeeReceiptLineItem.fromMap(m)).toList(),
      advanceBalance: 0,
      paymentHistory: paymentHistory,
    );
  }

  factory FeeReceiptView.fromJoinedMap({
    required Map<String, dynamic> voucherRow,
    required Map<String, dynamic> studentRow,
    required List<FeeReceiptLineItem> items,
    int advanceBalance = 0,
    List<VoucherPaymentInstallment> paymentHistory = const [],
  }) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      final str = val.toString().trim();
      if (str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    final first = (studentRow['NameFirst'] as String?)?.trim() ?? '';
    final last = (studentRow['NameLast'] as String?)?.trim() ?? '';
    final studentName = [first, last].where((s) => s.isNotEmpty).join(' ');

    return FeeReceiptView(
      voucherMasId: voucherRow['VoucherMasID'] as String,
      stuRegId: (voucherRow['Student_Class_StuRegID'] as num).toInt(),
      studentName: studentName.isNotEmpty ? studentName : 'Unknown Student',
      fatherName: (studentRow['F_Name'] as String?)?.trim() ?? '',
      className: studentRow['CName'] as String?,
      sectionName: studentRow['SecName'] as String?,
      rollNo: (studentRow['ClassRollNo'] as num?)?.toInt(),
      sessionYr: studentRow['SessionYr'] as String?,
      photoPath: studentRow['photo_path'] as String?,
      forMonth: (voucherRow['ForMonth'] as String?) ?? '',
      issueDate: parseDate(voucherRow['VDate']),
      dueDate: parseDate(voucherRow['DueDate']),
      subtotal: (voucherRow['SubTotal'] as num?)?.toInt() ?? 0,
      discount: (voucherRow['Discount'] as num?)?.toInt() ?? 0,
      paidAmount: (voucherRow['PaidAmt'] as num?)?.toInt() ?? 0,
      paidDate: parseDate(voucherRow['PaidDate']),
      bankId: (voucherRow['BankID'] as num?)?.toInt(),
      isPaid: (voucherRow['IsPaid'] as String?) ?? 'N',
      lineItems: items,
      advanceBalance: advanceBalance,
      paymentHistory: paymentHistory,
    );
  }
}

/// Lightweight summary row used in FeeCollectionScreen directory grid.
/// Populated by FeeCollectionNotifier.lookupVoucherByFilter().
class FeeReceiptSummaryRow {
  final String voucherMasId;
  final int stuRegId;
  final String studentName;
  final String? fatherName;
  final String className;
  final String sectionName;
  final int? rollNo;
  final String forMonth;
  final int netPayable;
  final int paidAmt;
  final String isPaid;
  final DateTime? dueDate;

  const FeeReceiptSummaryRow({
    required this.voucherMasId,
    required this.stuRegId,
    required this.studentName,
    this.fatherName,
    required this.className,
    required this.sectionName,
    this.rollNo,
    required this.forMonth,
    required this.netPayable,
    this.paidAmt = 0,
    required this.isPaid,
    this.dueDate,
  });

  /// e.g. "Class 10-A" or "Class 10" if no section
  String get classSecDisplay =>
      sectionName.isEmpty ? className : '$className-$sectionName';

  int get remainingBalance => max(0, netPayable - paidAmt);

  String get statusLabel {
    if (isPaid == 'Y' && remainingBalance == 0) return 'PAID';
    if (paidAmt > 0 && remainingBalance > 0) return 'PARTIALLY PAID';
    if (isPaid == 'O') return 'OVERDUE';
    if (dueDate != null && DateTime.now().isAfter(dueDate!)) return 'OVERDUE';
    return 'UNPAID';
  }
}
