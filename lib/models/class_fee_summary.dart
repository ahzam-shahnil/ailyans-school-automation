/// Represents the fee structure summary for an academic class in a session.
/// Aggregated from Class LEFT JOIN Cls_Param_Fee.
class ClassFeeSummary {
  final int classId;
  final String cName;
  final int headCount;
  final double totalFee;

  const ClassFeeSummary({
    required this.classId,
    required this.cName,
    required this.headCount,
    required this.totalFee,
  });

  factory ClassFeeSummary.fromMap(Map<String, dynamic> map) {
    return ClassFeeSummary(
      classId: map['ClassID'] as int,
      cName: map['CName'] as String? ?? '',
      headCount: (map['headCount'] as num?)?.toInt() ?? 0,
      totalFee: (map['totalFee'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
