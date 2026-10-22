/// Status of a student's voucher row in the cohort generation preview.
enum VoucherPreviewStatus {
  ready,
  alreadyGenerated,
  fullWaiver,
  arrearsRollover,
}

/// In-memory preview row for the voucher generation preview table.
/// Does NOT touch DB directly; computed dynamically prior to generation commit.
class VoucherPreviewRow {
  final int stuRegId;
  final String studentName; // NameFirst + ' ' + NameLast
  final int subtotal; // sum of class tariffs
  final int arrears; // rollover from prior unpaid vouchers
  final int discount; // from fullDiscount rule
  final int netPayable; // subtotal + arrears - discount (computed)
  final VoucherPreviewStatus status;
  final String? skipReason; // e.g. "Already generated"
  final String voucherId; // formatted as "yyMM-stuRegId", e.g. "1710-4411"

  const VoucherPreviewRow({
    required this.stuRegId,
    required this.studentName,
    required this.subtotal,
    required this.arrears,
    required this.discount,
    required this.netPayable,
    required this.status,
    this.skipReason,
    this.voucherId = '',
  });

  /// VB6 legacy stub required by behavioral specification.
  /// Preview rows compute voucher key string formatted as '${yyMM}-${stuRegId}'.
  int get voucherKey => throw UnimplementedError(
    'voucherKey is an in-memory preview string "$voucherId", not an integer key.',
  );

  VoucherPreviewRow copyWith({
    int? stuRegId,
    String? studentName,
    int? subtotal,
    int? arrears,
    int? discount,
    int? netPayable,
    VoucherPreviewStatus? status,
    String? skipReason,
    String? voucherId,
  }) {
    return VoucherPreviewRow(
      stuRegId: stuRegId ?? this.stuRegId,
      studentName: studentName ?? this.studentName,
      subtotal: subtotal ?? this.subtotal,
      arrears: arrears ?? this.arrears,
      discount: discount ?? this.discount,
      netPayable: netPayable ?? this.netPayable,
      status: status ?? this.status,
      skipReason: skipReason ?? this.skipReason,
      voucherId: voucherId ?? this.voucherId,
    );
  }

  @override
  String toString() {
    return 'VoucherPreviewRow(id: $voucherId, stuRegId: $stuRegId, name: $studentName, '
        'subtotal: $subtotal, arrears: $arrears, discount: $discount, '
        'net: $netPayable, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoucherPreviewRow &&
        other.stuRegId == stuRegId &&
        other.studentName == studentName &&
        other.subtotal == subtotal &&
        other.arrears == arrears &&
        other.discount == discount &&
        other.netPayable == netPayable &&
        other.status == status &&
        other.skipReason == skipReason &&
        other.voucherId == voucherId;
  }

  @override
  int get hashCode {
    return Object.hash(
      stuRegId,
      studentName,
      subtotal,
      arrears,
      discount,
      netPayable,
      status,
      skipReason,
      voucherId,
    );
  }
}
