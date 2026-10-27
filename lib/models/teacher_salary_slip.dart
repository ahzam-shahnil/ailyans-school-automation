/// Model representing an employee salary disbursement slip from `TSalMas`
/// displayed on Tab 3 of the Teacher Profile screen.
class TeacherSalarySlip {
  final String tSalMasId;
  final int teacherId;
  final String? disbursDate;
  final String salMonth;
  final double paidAmt;
  final double tDeductions;
  final String? detail;
  final String isPaid;
  final String? paidDate;

  const TeacherSalarySlip({
    required this.tSalMasId,
    required this.teacherId,
    this.disbursDate,
    required this.salMonth,
    required this.paidAmt,
    required this.tDeductions,
    this.detail,
    required this.isPaid,
    this.paidDate,
  });

  /// Gross pay amount (= PaidAmt in legacy schema).
  double get grossAmount => paidAmt;

  /// Net take-home pay after deductions.
  double get netAmount => paidAmt - tDeductions;

  /// Whether disbursement is still pending.
  bool get isPending => isPaid != 'Y';

  factory TeacherSalarySlip.fromMap(Map<String, dynamic> map) {
    return TeacherSalarySlip(
      tSalMasId: map['TSalMasID']?.toString() ?? '',
      teacherId: (map['TeacherID'] as num?)?.toInt() ?? 0,
      disbursDate: map['DisbursDate'] as String?,
      salMonth: map['SalMonth']?.toString() ?? '',
      paidAmt: (map['PaidAmt'] as num?)?.toDouble() ?? 0.0,
      tDeductions: (map['TDeductions'] as num?)?.toDouble() ?? 0.0,
      detail: map['Detail'] as String?,
      isPaid: map['IsPaid']?.toString() ?? 'N',
      paidDate: map['PaidDate'] as String?,
    );
  }
}
