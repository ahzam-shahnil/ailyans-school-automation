import 'package:flutter/foundation.dart';

import 'student.dart';

/// Data model representing a single master voucher row in the institutional fee ledger.
@immutable
class FeeLedgerRow {
  final String voucherMasId;
  final int stuRegId;
  final String studentName;
  final String? fatherName;
  final String? mobile1;
  final String className;
  final String sectionName;
  final int? rollNo;
  final int gross;
  final int discount;
  final int paidAmt;
  final int netDue;
  final String isPaid; // 'Y', 'N', 'O'
  final DateTime? dueDate;
  final DateTime? paidDate;
  final String forMonth;
  final String sessionYr;
  final int? bankId;

  const FeeLedgerRow({
    required this.voucherMasId,
    required this.stuRegId,
    required this.studentName,
    this.fatherName,
    this.mobile1,
    required this.className,
    required this.sectionName,
    this.rollNo,
    required this.gross,
    required this.discount,
    required this.paidAmt,
    required this.netDue,
    required this.isPaid,
    this.dueDate,
    this.paidDate,
    required this.forMonth,
    required this.sessionYr,
    this.bankId,
  });

  bool get isPaidStatus => isPaid == 'Y' || netDue <= 0;
  bool get isOverdueStatus =>
      isPaid == 'O' ||
      (!isPaidStatus && dueDate != null && DateTime.now().isAfter(dueDate!));

  factory FeeLedgerRow.fromMap(Map<String, dynamic> map) {
    final first = (map['NameFirst'] as String?)?.trim() ?? '';
    final middle = (map['NameMiddle'] as String?)?.trim() ?? '';
    final last = (map['NameLast'] as String?)?.trim() ?? '';
    final fullName = formatStudentFullName(first, middle, last);

    DateTime? due;
    final dueRaw = map['DueDate'];
    if (dueRaw != null) {
      due = DateTime.tryParse(dueRaw.toString());
    }

    DateTime? paid;
    final paidRaw = map['PaidDate'];
    if (paidRaw != null) {
      paid = DateTime.tryParse(paidRaw.toString());
    }

    final grossVal = (map['SubTotal'] as num?)?.toInt() ?? 0;
    final discVal = (map['Discount'] as num?)?.toInt() ?? 0;
    final paidVal = (map['PaidAmt'] as num?)?.toInt() ?? 0;
    final computedNetDue =
        (map['netDue'] as num?)?.toInt() ?? (grossVal - discVal - paidVal);

    return FeeLedgerRow(
      voucherMasId: (map['VoucherMasID'] as String?)?.trim() ?? '',
      stuRegId: (map['Student_Class_StuRegID'] as num?)?.toInt() ?? 0,
      studentName: fullName.isNotEmpty ? fullName : 'Unknown Student',
      fatherName: (map['F_Name'] as String?)?.trim(),
      mobile1: (map['Mobile1'] as String?)?.trim(),
      className: (map['class_name'] as String?)?.trim() ?? 'Unknown Class',
      sectionName: (map['section_name'] as String?)?.trim() ?? '',
      rollNo: (map['ClassRollNo'] as num?)?.toInt(),
      gross: grossVal,
      discount: discVal,
      paidAmt: paidVal,
      netDue: computedNetDue,
      isPaid: (map['IsPaid'] as String?)?.trim().toUpperCase() ?? 'N',
      dueDate: due,
      paidDate: paid,
      forMonth: (map['ForMonth'] as String?)?.trim() ?? '',
      sessionYr: (map['SessionYr'] as String?)?.trim() ?? '',
      bankId: (map['BankID'] as num?)?.toInt(),
    );
  }

  FeeLedgerRow copyWith({
    String? voucherMasId,
    int? stuRegId,
    String? studentName,
    String? fatherName,
    String? mobile1,
    String? className,
    String? sectionName,
    int? rollNo,
    int? gross,
    int? discount,
    int? paidAmt,
    int? netDue,
    String? isPaid,
    DateTime? dueDate,
    DateTime? paidDate,
    String? forMonth,
    String? sessionYr,
    int? bankId,
  }) {
    return FeeLedgerRow(
      voucherMasId: voucherMasId ?? this.voucherMasId,
      stuRegId: stuRegId ?? this.stuRegId,
      studentName: studentName ?? this.studentName,
      fatherName: fatherName ?? this.fatherName,
      mobile1: mobile1 ?? this.mobile1,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      rollNo: rollNo ?? this.rollNo,
      gross: gross ?? this.gross,
      discount: discount ?? this.discount,
      paidAmt: paidAmt ?? this.paidAmt,
      netDue: netDue ?? this.netDue,
      isPaid: isPaid ?? this.isPaid,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      forMonth: forMonth ?? this.forMonth,
      sessionYr: sessionYr ?? this.sessionYr,
      bankId: bankId ?? this.bankId,
    );
  }
}

/// Detailed fee head line item for the voucher breakdown dialog.
@immutable
class FeeLedgerDetailItem {
  final int feeParamId;
  final String paramDescription;
  final int amount;
  final int discount;

  const FeeLedgerDetailItem({
    required this.feeParamId,
    required this.paramDescription,
    required this.amount,
    required this.discount,
  });

  int get net => amount - discount;
}
