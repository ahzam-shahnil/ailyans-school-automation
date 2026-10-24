import 'package:flutter/foundation.dart';

/// Represents the header record for daily class attendance (maps to AttMas).
@immutable
class AttendanceHeader {
  final int? attMasId;
  final int? teacherId;
  final int classId;
  final int classSecId;
  final DateTime attDate;
  final String studySessionYr;
  final String? remarks;

  const AttendanceHeader({
    this.attMasId,
    this.teacherId,
    required this.classId,
    required this.classSecId,
    required this.attDate,
    required this.studySessionYr,
    this.remarks,
  });

  AttendanceHeader copyWith({
    int? attMasId,
    int? teacherId,
    int? classId,
    int? classSecId,
    DateTime? attDate,
    String? studySessionYr,
    String? remarks,
  }) {
    return AttendanceHeader(
      attMasId: attMasId ?? this.attMasId,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      classSecId: classSecId ?? this.classSecId,
      attDate: attDate ?? this.attDate,
      studySessionYr: studySessionYr ?? this.studySessionYr,
      remarks: remarks ?? this.remarks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceHeader &&
          runtimeType == other.runtimeType &&
          attMasId == other.attMasId &&
          teacherId == other.teacherId &&
          classId == other.classId &&
          classSecId == other.classSecId &&
          attDate == other.attDate &&
          studySessionYr == other.studySessionYr &&
          remarks == other.remarks;

  @override
  int get hashCode =>
      attMasId.hashCode ^
      teacherId.hashCode ^
      classId.hashCode ^
      classSecId.hashCode ^
      attDate.hashCode ^
      studySessionYr.hashCode ^
      remarks.hashCode;
}
