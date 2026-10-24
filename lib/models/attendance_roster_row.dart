import 'package:flutter/foundation.dart';

/// Represents a single student's row in the classroom attendance roster.
@immutable
class AttendanceRosterRow {
  final int stuRegId;
  final int rollNo;
  final String nameFirst;
  final String nameMiddle;
  final String nameLast;
  final String fatherName;
  final String currentStatus; // 'Present' | 'Absent' | 'Leave' | 'Late'
  final String? inTime;
  final String? outTime;
  final String? attRemarks;

  // Leave application fields (mapped from / to AttDet)
  final String? leaveRequestedBy;
  final String? lFrom;
  final String? lTill;
  final String? reason;
  final String? attAppcation; // verbatim historical typo
  final String? isApproved; // stored as 'true' / 'false' / null (TEXT)

  const AttendanceRosterRow({
    required this.stuRegId,
    required this.rollNo,
    required this.nameFirst,
    this.nameMiddle = '',
    required this.nameLast,
    required this.fatherName,
    this.currentStatus = 'Present',
    this.inTime,
    this.outTime,
    this.attRemarks,
    this.leaveRequestedBy,
    this.lFrom,
    this.lTill,
    this.reason,
    this.attAppcation,
    this.isApproved,
  });

  /// Returns "First Last" skipping middle if empty.
  String getNameDisplay() {
    final first = nameFirst.trim();
    final middle = nameMiddle.trim();
    final last = nameLast.trim();

    if (middle.isNotEmpty) {
      return '$first $middle $last'.trim();
    }
    if (last.isNotEmpty) {
      return '$first $last'.trim();
    }
    return first;
  }

  AttendanceRosterRow copyWith({
    int? stuRegId,
    int? rollNo,
    String? nameFirst,
    String? nameMiddle,
    String? nameLast,
    String? fatherName,
    String? currentStatus,
    String? inTime,
    String? outTime,
    String? attRemarks,
    String? leaveRequestedBy,
    String? lFrom,
    String? lTill,
    String? reason,
    String? attAppcation,
    String? isApproved,
  }) {
    return AttendanceRosterRow(
      stuRegId: stuRegId ?? this.stuRegId,
      rollNo: rollNo ?? this.rollNo,
      nameFirst: nameFirst ?? this.nameFirst,
      nameMiddle: nameMiddle ?? this.nameMiddle,
      nameLast: nameLast ?? this.nameLast,
      fatherName: fatherName ?? this.fatherName,
      currentStatus: currentStatus ?? this.currentStatus,
      inTime: inTime ?? this.inTime,
      outTime: outTime ?? this.outTime,
      attRemarks: attRemarks ?? this.attRemarks,
      leaveRequestedBy: leaveRequestedBy ?? this.leaveRequestedBy,
      lFrom: lFrom ?? this.lFrom,
      lTill: lTill ?? this.lTill,
      reason: reason ?? this.reason,
      attAppcation: attAppcation ?? this.attAppcation,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRosterRow &&
          runtimeType == other.runtimeType &&
          stuRegId == other.stuRegId &&
          rollNo == other.rollNo &&
          nameFirst == other.nameFirst &&
          nameMiddle == other.nameMiddle &&
          nameLast == other.nameLast &&
          fatherName == other.fatherName &&
          currentStatus == other.currentStatus &&
          inTime == other.inTime &&
          outTime == other.outTime &&
          attRemarks == other.attRemarks &&
          leaveRequestedBy == other.leaveRequestedBy &&
          lFrom == other.lFrom &&
          lTill == other.lTill &&
          reason == other.reason &&
          attAppcation == other.attAppcation &&
          isApproved == other.isApproved;

  @override
  int get hashCode =>
      stuRegId.hashCode ^
      rollNo.hashCode ^
      nameFirst.hashCode ^
      nameMiddle.hashCode ^
      nameLast.hashCode ^
      fatherName.hashCode ^
      currentStatus.hashCode ^
      inTime.hashCode ^
      outTime.hashCode ^
      attRemarks.hashCode ^
      leaveRequestedBy.hashCode ^
      lFrom.hashCode ^
      lTill.hashCode ^
      reason.hashCode ^
      attAppcation.hashCode ^
      isApproved.hashCode;
}
