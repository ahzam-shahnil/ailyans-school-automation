/// Model representing a row in the monthly staff payroll register (left canvas).
class SalarySlipRow {
  final String? tSalMasId;
  final int teacherId;
  final String teacherName;
  final String? fatherName;
  final String? teacherCnic;
  final String? teacherCat;
  final String salMonth;
  final String? disbursDate;
  final int? paidAmt;
  final int? tDeductions;
  final String? detail;
  final String? isPaid;
  final String? paidDate;
  final int grossFromDet;

  const SalarySlipRow({
    this.tSalMasId,
    required this.teacherId,
    required this.teacherName,
    this.fatherName,
    this.teacherCnic,
    this.teacherCat,
    required this.salMonth,
    this.disbursDate,
    this.paidAmt,
    this.tDeductions,
    this.detail,
    this.isPaid,
    this.paidDate,
    required this.grossFromDet,
  });

  int get netAmount => (paidAmt ?? 0) - (tDeductions ?? 0);

  bool get isPending => isPaid != 'Y' || tSalMasId == null;

  String? get yyMM => tSalMasId != null && tSalMasId!.length >= 4
      ? tSalMasId!.substring(0, 4)
      : null;

  factory SalarySlipRow.fromMap(
    Map<String, dynamic> map,
    String selectedMonth,
  ) {
    return SalarySlipRow(
      tSalMasId: map['TSalMasID']?.toString(),
      teacherId: (map['TeacherID'] as num).toInt(),
      teacherName: (map['TName'] as String?) ?? '',
      fatherName: map['TFName'] as String?,
      teacherCnic: map['TCNIC'] as String?,
      teacherCat: map['TCat'] as String?,
      salMonth: (map['SalMonth'] as String?) ?? selectedMonth,
      disbursDate: map['DisbursDate']?.toString(),
      paidAmt: (map['PaidAmt'] as num?)?.toInt(),
      tDeductions: (map['TDeductions'] as num?)?.toInt(),
      detail: map['Detail'] as String?,
      isPaid: map['IsPaid']?.toString(),
      paidDate: map['PaidDate']?.toString(),
      grossFromDet: (map['grossFromDet'] as num?)?.toInt() ?? 0,
    );
  }

  SalarySlipRow copyWith({
    String? tSalMasId,
    int? teacherId,
    String? teacherName,
    String? fatherName,
    String? teacherCnic,
    String? teacherCat,
    String? salMonth,
    String? disbursDate,
    int? paidAmt,
    int? tDeductions,
    String? detail,
    String? isPaid,
    String? paidDate,
    int? grossFromDet,
  }) {
    return SalarySlipRow(
      tSalMasId: tSalMasId ?? this.tSalMasId,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      fatherName: fatherName ?? this.fatherName,
      teacherCnic: teacherCnic ?? this.teacherCnic,
      teacherCat: teacherCat ?? this.teacherCat,
      salMonth: salMonth ?? this.salMonth,
      disbursDate: disbursDate ?? this.disbursDate,
      paidAmt: paidAmt ?? this.paidAmt,
      tDeductions: tDeductions ?? this.tDeductions,
      detail: detail ?? this.detail,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      grossFromDet: grossFromDet ?? this.grossFromDet,
    );
  }
}
