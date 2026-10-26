import 'package:flutter/foundation.dart';

/// Represents a student row for the School Leaving workflow.
@immutable
class LeavingStudentRow {
  final int stuRegId;
  final String nameFirst;
  final String? nameMiddle;
  final String? nameLast;
  final String? fatherName;
  final String? className;
  final String? sectionName;
  final int? classId;
  final int? classSecId;
  final String? sessionYr;
  final String? admissionDate;
  final int present;
  final bool hasExistingSlc;
  final String? existingSlcDate;
  final String? existingSlcTerm;
  final String? existingSlcConduct;
  final String? existingSlcRemarks;
  final int? existingSlcSlid;

  const LeavingStudentRow({
    required this.stuRegId,
    required this.nameFirst,
    this.nameMiddle,
    this.nameLast,
    this.fatherName,
    this.className,
    this.sectionName,
    this.classId,
    this.classSecId,
    this.sessionYr,
    this.admissionDate,
    this.present = 1,
    this.hasExistingSlc = false,
    this.existingSlcDate,
    this.existingSlcTerm,
    this.existingSlcConduct,
    this.existingSlcRemarks,
    this.existingSlcSlid,
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

  String get classSecDisplay {
    final c = className ?? 'Unassigned';
    final s = (sectionName != null && sectionName!.trim().isNotEmpty)
        ? '-${sectionName!.trim()}'
        : '';
    return '$c$s';
  }

  bool get hasSLC => hasExistingSlc;

  LeavingStudentRow copyWith({
    int? stuRegId,
    String? nameFirst,
    String? nameMiddle,
    String? nameLast,
    String? fatherName,
    String? className,
    String? sectionName,
    int? classId,
    int? classSecId,
    String? sessionYr,
    String? admissionDate,
    int? present,
    bool? hasExistingSlc,
    String? existingSlcDate,
    String? existingSlcTerm,
    String? existingSlcConduct,
    String? existingSlcRemarks,
    int? existingSlcSlid,
  }) {
    return LeavingStudentRow(
      stuRegId: stuRegId ?? this.stuRegId,
      nameFirst: nameFirst ?? this.nameFirst,
      nameMiddle: nameMiddle ?? this.nameMiddle,
      nameLast: nameLast ?? this.nameLast,
      fatherName: fatherName ?? this.fatherName,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      classId: classId ?? this.classId,
      classSecId: classSecId ?? this.classSecId,
      sessionYr: sessionYr ?? this.sessionYr,
      admissionDate: admissionDate ?? this.admissionDate,
      present: present ?? this.present,
      hasExistingSlc: hasExistingSlc ?? this.hasExistingSlc,
      existingSlcDate: existingSlcDate ?? this.existingSlcDate,
      existingSlcTerm: existingSlcTerm ?? this.existingSlcTerm,
      existingSlcConduct: existingSlcConduct ?? this.existingSlcConduct,
      existingSlcRemarks: existingSlcRemarks ?? this.existingSlcRemarks,
      existingSlcSlid: existingSlcSlid ?? this.existingSlcSlid,
    );
  }
}
