import 'package:flutter/foundation.dart';

import 'student.dart';

/// Represents a single student's enrollment record in a class/section
/// within the Bulk Class Enrollment screen (SCHfrmStu_Class / ObjID: 20).
@immutable
class EnrollmentRow {
  final int stuRegId;
  final int classRollNo;
  final String firstName;
  final String? middleName;
  final String? lastName;
  final String? fatherName;
  final bool present;
  final String? className;
  final String? sectionName;
  final String? sessionYr;

  const EnrollmentRow({
    required this.stuRegId,
    required this.classRollNo,
    required this.firstName,
    this.middleName,
    this.lastName,
    this.fatherName,
    this.present = true,
    this.className,
    this.sectionName,
    this.sessionYr,
  });

  String get fullName =>
      formatStudentFullName(firstName, middleName, lastName);

  factory EnrollmentRow.fromMap(Map<String, dynamic> map) {
    final rawPresent = map['Present'] ?? map['present'];
    final bool isPresent = rawPresent is bool
        ? rawPresent
        : (rawPresent is num ? rawPresent != 0 : true);

    return EnrollmentRow(
      stuRegId: (map['Stu_RegID'] ?? map['stuRegId'] ?? 0) as int,
      classRollNo: (map['ClassRollNo'] ?? map['classRollNo'] ?? 0) as int,
      firstName: (map['NameFirst'] ?? map['firstName'] ?? '') as String,
      middleName: (map['NameMiddle'] ?? map['middleName']) as String?,
      lastName: (map['NameLast'] ?? map['lastName']) as String?,
      fatherName: (map['F_Name'] ?? map['fatherName']) as String?,
      present: isPresent,
      className: (map['class_name'] ?? map['className']) as String?,
      sectionName: (map['section_name'] ?? map['sectionName']) as String?,
      sessionYr: (map['SessionYr'] ?? map['sessionYr']) as String?,
    );
  }

  EnrollmentRow copyWith({
    int? stuRegId,
    int? classRollNo,
    String? firstName,
    String? middleName,
    String? lastName,
    String? fatherName,
    bool? present,
    String? className,
    String? sectionName,
    String? sessionYr,
  }) {
    return EnrollmentRow(
      stuRegId: stuRegId ?? this.stuRegId,
      classRollNo: classRollNo ?? this.classRollNo,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      fatherName: fatherName ?? this.fatherName,
      present: present ?? this.present,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      sessionYr: sessionYr ?? this.sessionYr,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnrollmentRow &&
          runtimeType == other.runtimeType &&
          stuRegId == other.stuRegId &&
          classRollNo == other.classRollNo &&
          firstName == other.firstName &&
          middleName == other.middleName &&
          lastName == other.lastName &&
          fatherName == other.fatherName &&
          present == other.present &&
          className == other.className &&
          sectionName == other.sectionName &&
          sessionYr == other.sessionYr;

  @override
  int get hashCode =>
      stuRegId.hashCode ^
      classRollNo.hashCode ^
      firstName.hashCode ^
      middleName.hashCode ^
      lastName.hashCode ^
      fatherName.hashCode ^
      present.hashCode ^
      className.hashCode ^
      sectionName.hashCode ^
      sessionYr.hashCode;
}
