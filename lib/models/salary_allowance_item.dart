/// Model representing an individual allowance head line item in `TSalDet`.
class SalaryAllowanceItem {
  final int ser;
  final String detail;
  final int amount;
  final String? remarks;

  const SalaryAllowanceItem({
    required this.ser,
    required this.detail,
    required this.amount,
    this.remarks,
  });

  SalaryAllowanceItem copyWith({
    int? ser,
    String? detail,
    int? amount,
    String? remarks,
  }) {
    return SalaryAllowanceItem(
      ser: ser ?? this.ser,
      detail: detail ?? this.detail,
      amount: amount ?? this.amount,
      remarks: remarks ?? this.remarks,
    );
  }

  factory SalaryAllowanceItem.fromMap(Map<String, dynamic> map) {
    return SalaryAllowanceItem(
      ser: (map['TSalDetSer'] as num?)?.toInt() ?? 1,
      detail: (map['Detail'] as String?) ?? '',
      amount: (map['Amount'] as num?)?.toInt() ?? 0,
      remarks: map['Remarks'] as String?,
    );
  }

  Map<String, dynamic> toMap(String tSalMasId) {
    return {
      'TSalDetSer': ser,
      'TSalMasID': tSalMasId,
      'Detail': detail,
      'Amount': amount,
      'Remarks': remarks,
    };
  }
}
