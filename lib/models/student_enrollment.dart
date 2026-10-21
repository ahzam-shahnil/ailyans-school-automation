import 'package:intl/intl.dart';

/// Domain model representing an academic session enrollment (`Student_Class`).
class StudentEnrollment {
  final int stuRegId;
  final int classId;
  final int classSecId;
  final int classRollNo;
  final String sessionYr;
  final int present; // 0 or 1
  final String vGen; // 'Y' or 'N'
  final String className; // joined from Class
  final String sectionName; // joined from ClassSec
  final DateTime? promotionDate;

  const StudentEnrollment({
    required this.stuRegId,
    required this.classId,
    required this.classSecId,
    required this.classRollNo,
    required this.sessionYr,
    required this.present,
    required this.vGen,
    required this.className,
    required this.sectionName,
    this.promotionDate,
  });

  /// Formatted promotion date.
  String get formattedPromotionDate {
    if (promotionDate == null) return '—';
    return DateFormat('dd-MMM-yyyy').format(promotionDate!);
  }

  /// Whether student is actively enrolled.
  bool get isActive => present == 1;

  factory StudentEnrollment.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      final str = val.toString().trim();
      if (str.isEmpty) return null;
      try {
        return DateTime.parse(str);
      } catch (_) {
        return null;
      }
    }

    return StudentEnrollment(
      stuRegId: map['Stu_RegID'] as int,
      classId: map['ClassID'] as int,
      classSecId: (map['ClassSecID'] as int?) ?? 0,
      classRollNo: (map['ClassRollNo'] as int?) ?? 0,
      sessionYr: (map['SessionYr'] as String?)?.trim() ?? '',
      present: (map['Present'] as int?) ?? 1,
      vGen: (map['VGen'] as String?)?.trim() ?? 'Y',
      className: (map['CName'] as String?)?.trim() ?? 'Class ${map['ClassID']}',
      sectionName: (map['SecName'] as String?)?.trim() ?? 'A',
      promotionDate: parseDate(map['PromotionDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Stu_RegID': stuRegId,
      'ClassID': classId,
      'ClassSecID': classSecId,
      'ClassRollNo': classRollNo,
      'SessionYr': sessionYr,
      'Present': present,
      'VGen': vGen,
      'PromotionDate': promotionDate?.toIso8601String(),
    };
  }

  StudentEnrollment copyWith({
    int? stuRegId,
    int? classId,
    int? classSecId,
    int? classRollNo,
    String? sessionYr,
    int? present,
    String? vGen,
    String? className,
    String? sectionName,
    DateTime? promotionDate,
  }) {
    return StudentEnrollment(
      stuRegId: stuRegId ?? this.stuRegId,
      classId: classId ?? this.classId,
      classSecId: classSecId ?? this.classSecId,
      classRollNo: classRollNo ?? this.classRollNo,
      sessionYr: sessionYr ?? this.sessionYr,
      present: present ?? this.present,
      vGen: vGen ?? this.vGen,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      promotionDate: promotionDate ?? this.promotionDate,
    );
  }
}
