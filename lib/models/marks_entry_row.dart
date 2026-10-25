import 'package:flutter/foundation.dart';

/// Single student row in the MarksEntryScreen grading grid.
@immutable
class MarksEntryRow {
  final int stuRegId;
  final int rollNo;
  final String nameFirst;
  final String? nameMiddle;
  final String nameLast;
  final String? fatherName;

  final double? theoryObtained;
  final double? practicalObtained;
  final int theoryMax;
  final int practicalMax;

  final bool isAbsent;
  final bool isSelected;

  final int? examMasId;
  final int? exDetId;
  final double? persistedTheory;
  final double? persistedPractical;

  const MarksEntryRow({
    required this.stuRegId,
    required this.rollNo,
    required this.nameFirst,
    this.nameMiddle,
    required this.nameLast,
    this.fatherName,
    this.theoryObtained,
    this.practicalObtained,
    this.theoryMax = 100,
    this.practicalMax = 0,
    this.isAbsent = false,
    this.isSelected = true,
    this.examMasId,
    this.exDetId,
    this.persistedTheory,
    this.persistedPractical,
  });

  /// Computed full name of student
  String get studentName => [
    nameFirst,
    nameMiddle,
    nameLast,
  ].where((s) => s != null && s.trim().isNotEmpty).join(' ');

  /// Computed total marks obtained
  double get totalObtained =>
      isAbsent ? 0.0 : (theoryObtained ?? 0.0) + (practicalObtained ?? 0.0);

  /// Computed total maximum marks
  int get totalMax => theoryMax + practicalMax;

  /// Computed percentage of total marks
  double get percentage =>
      totalMax > 0 ? (totalObtained / totalMax) * 100.0 : 0.0;

  /// Evaluates grade against loaded ExGrade scale or statutory fallback
  String computeGrade(List<Map<String, dynamic>> exGradeRows) {
    if (isAbsent) return 'ABS';
    if (exGradeRows.isEmpty) {
      return percentage < 33.0 ? 'F' : 'PASS'; // statutory fallback
    }

    final pct = percentage.round();
    for (final row in exGradeRows) {
      final min = (row['GradMinMarks'] as num).toInt();
      final max = (row['GradMaxMarks'] as num).toInt();
      if (pct >= min && pct <= max) {
        return row['Grad'] as String;
      }
    }
    return 'F';
  }

  MarksEntryRow copyWith({
    int? stuRegId,
    int? rollNo,
    String? nameFirst,
    String? nameMiddle,
    String? nameLast,
    String? fatherName,
    double? theoryObtained,
    bool clearTheoryObtained = false,
    double? practicalObtained,
    bool clearPracticalObtained = false,
    int? theoryMax,
    int? practicalMax,
    bool? isAbsent,
    bool? isSelected,
    int? examMasId,
    int? exDetId,
    double? persistedTheory,
    double? persistedPractical,
  }) {
    return MarksEntryRow(
      stuRegId: stuRegId ?? this.stuRegId,
      rollNo: rollNo ?? this.rollNo,
      nameFirst: nameFirst ?? this.nameFirst,
      nameMiddle: nameMiddle ?? this.nameMiddle,
      nameLast: nameLast ?? this.nameLast,
      fatherName: fatherName ?? this.fatherName,
      theoryObtained: clearTheoryObtained
          ? null
          : (theoryObtained ?? this.theoryObtained),
      practicalObtained: clearPracticalObtained
          ? null
          : (practicalObtained ?? this.practicalObtained),
      theoryMax: theoryMax ?? this.theoryMax,
      practicalMax: practicalMax ?? this.practicalMax,
      isAbsent: isAbsent ?? this.isAbsent,
      isSelected: isSelected ?? this.isSelected,
      examMasId: examMasId ?? this.examMasId,
      exDetId: exDetId ?? this.exDetId,
      persistedTheory: persistedTheory ?? this.persistedTheory,
      persistedPractical: persistedPractical ?? this.persistedPractical,
    );
  }
}
