/// Representation of a single row in the Student Directory table.
///
/// Joins demographic records from `Stu_Reg`, enrollment from `Student_Class`,
/// grade from `Class`, section from `ClassSec`, and departure status from `SchLeaving`.
class StudentListRow {
  final int stuRegId;
  final String fullName; // NameFirst + ' ' + (NameLast ?? '')
  final String? fatherName; // F_Name
  final String? photoPath; // Stu_Reg.photo_path
  final String className; // Class.CName (e.g., "Class 10")
  final String sectionName; // ClassSec.SecName (e.g., "A")
  final int? rollNo; // Student_Class.ClassRollNo
  final String status; // "Active" or "Left"
  final String sessionYr; // Student_Class.SessionYr
  final int siblingCount;

  const StudentListRow({
    required this.stuRegId,
    required this.fullName,
    this.fatherName,
    this.photoPath,
    required this.className,
    required this.sectionName,
    this.rollNo,
    required this.status,
    required this.sessionYr,
    this.siblingCount = 0,
  });

  /// Formats the class and section badge string (e.g., "Class 10-A").
  String get classSecDisplay {
    if (sectionName.isEmpty) return className;
    return '$className-$sectionName';
  }

  factory StudentListRow.fromMap(Map<String, Object?> map) {
    final first = (map['NameFirst'] as String? ?? '').trim();
    final last = (map['NameLast'] as String? ?? '').trim();
    final fullName = last.isNotEmpty ? '$first $last' : first;

    return StudentListRow(
      stuRegId: (map['Stu_RegID'] as int?) ?? 0,
      fullName: fullName.isNotEmpty ? fullName : 'Student #${map['Stu_RegID']}',
      fatherName: (map['F_Name'] as String?)?.trim(),
      photoPath: map['photo_path'] as String?,
      className: (map['class_name'] as String? ?? '').trim(),
      sectionName: (map['section_name'] as String? ?? '').trim(),
      rollNo: map['ClassRollNo'] as int?,
      status: (map['status'] as String? ?? 'Active').trim(),
      sessionYr: (map['SessionYr'] as String? ?? '2017-2018').trim(),
      siblingCount: (map['siblingCount'] as num?)?.toInt() ?? 0,
    );
  }
}
