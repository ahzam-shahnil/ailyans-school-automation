import 'package:intl/intl.dart';

import '../core/utils/fee_head_display.dart';

/// Represents a configured fee tariff row for an academic class and session.
/// Mapped from Cls_Param_Fee JOIN FeeParameters.
class FeeParameterRow {
  final int clsParamFeeId;
  final int classId;
  final int feeParamId;
  final String paramDescription;
  final String displayName;
  final double fee;
  final String feeYr;

  const FeeParameterRow({
    required this.clsParamFeeId,
    required this.classId,
    required this.feeParamId,
    required this.paramDescription,
    required this.displayName,
    required this.fee,
    required this.feeYr,
  });

  factory FeeParameterRow.fromMap(Map<String, dynamic> map) {
    final rawDesc = map['ParamDesciption'] as String? ?? '';
    return FeeParameterRow(
      clsParamFeeId: map['Cls_Param_Fee_ID'] as int,
      classId: map['ClassID'] as int,
      feeParamId: map['FeeParamID'] as int,
      paramDescription: rawDesc,
      displayName: FeeHeadDisplay.of(rawDesc),
      fee: (map['Fee'] as num?)?.toDouble() ?? 0.0,
      feeYr: map['FeeYr'] as String? ?? '',
    );
  }

  /// Formats the fee amount in Pakistani Rupees with 2 decimal places.
  /// Example: 'Rs. 1,500.00'
  String formatAmount() {
    return 'Rs. ${NumberFormat('#,##0.00').format(fee)}';
  }
}
