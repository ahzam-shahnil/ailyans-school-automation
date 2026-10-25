import 'package:flutter/foundation.dart';

/// Represents a student row in the batch promotion candidate grid.
@immutable
class PromotionCandidateRow {
  final int stuRegId;
  final int rollNo;
  final String nameFirst;
  final String? nameMiddle;
  final String? nameLast;
  final String? fatherName;
  final double? currentPassingMarks;
  final double defaultPassingMarks;
  final bool isSelected;
  final bool isManuallyEdited;

  const PromotionCandidateRow({
    required this.stuRegId,
    required this.rollNo,
    required this.nameFirst,
    this.nameMiddle,
    this.nameLast,
    this.fatherName,
    this.currentPassingMarks,
    this.defaultPassingMarks = 40.0,
    this.isSelected = true,
    this.isManuallyEdited = false,
  });

  String get studentName {
    final parts = <String>[
      nameFirst,
      if (nameMiddle != null && nameMiddle!.trim().isNotEmpty)
        nameMiddle!.trim(),
      if (nameLast != null && nameLast!.trim().isNotEmpty) nameLast!.trim(),
    ];
    return parts.join(' ').trim();
  }

  bool get isFailed {
    if (currentPassingMarks == null) return false;
    return currentPassingMarks! < defaultPassingMarks;
  }

  bool isFailedAt(double threshold) {
    if (currentPassingMarks == null) return false;
    return currentPassingMarks! < threshold;
  }

  bool get isValidMarks {
    if (currentPassingMarks == null) return false;
    return currentPassingMarks! >= 0;
  }

  PromotionCandidateRow copyWith({
    int? stuRegId,
    int? rollNo,
    String? nameFirst,
    String? nameMiddle,
    String? nameLast,
    String? fatherName,
    double? Function()? currentPassingMarks,
    double? defaultPassingMarks,
    bool? isSelected,
    bool? isManuallyEdited,
  }) {
    return PromotionCandidateRow(
      stuRegId: stuRegId ?? this.stuRegId,
      rollNo: rollNo ?? this.rollNo,
      nameFirst: nameFirst ?? this.nameFirst,
      nameMiddle: nameMiddle ?? this.nameMiddle,
      nameLast: nameLast ?? this.nameLast,
      fatherName: fatherName ?? this.fatherName,
      currentPassingMarks: currentPassingMarks != null
          ? currentPassingMarks()
          : this.currentPassingMarks,
      defaultPassingMarks: defaultPassingMarks ?? this.defaultPassingMarks,
      isSelected: isSelected ?? this.isSelected,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
    );
  }
}
