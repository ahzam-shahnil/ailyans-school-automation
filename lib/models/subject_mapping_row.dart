/// Model representing a single class-to-subject curriculum allocation row in `Subj_Class`.
/// Composite PK: (`SubjID`, `ClassID`). Surrogate key: `Subj_ClsID`.
class SubjectMappingRow {
  final int subjClsId;
  final int subjId;
  final String subjName;
  final int classId;
  final String className;
  final int teacherId;
  final String teacherName;
  final String teacherCategory;
  final int totalMarks;
  final int totalPracticalMarks;

  const SubjectMappingRow({
    required this.subjClsId,
    required this.subjId,
    required this.subjName,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.teacherCategory,
    required this.totalMarks,
    required this.totalPracticalMarks,
  });

  /// Total allocated marks for this subject (Theory + Practical).
  int get combinedMarks => totalMarks + totalPracticalMarks;

  /// True if assigned faculty is not categorized as certified Teacher.
  bool get hasNonTeacher => teacherCategory != 'Teacher';

  SubjectMappingRow copyWith({
    int? subjClsId,
    int? subjId,
    String? subjName,
    int? classId,
    String? className,
    int? teacherId,
    String? teacherName,
    String? teacherCategory,
    int? totalMarks,
    int? totalPracticalMarks,
  }) {
    return SubjectMappingRow(
      subjClsId: subjClsId ?? this.subjClsId,
      subjId: subjId ?? this.subjId,
      subjName: subjName ?? this.subjName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherCategory: teacherCategory ?? this.teacherCategory,
      totalMarks: totalMarks ?? this.totalMarks,
      totalPracticalMarks: totalPracticalMarks ?? this.totalPracticalMarks,
    );
  }

  factory SubjectMappingRow.fromMap(Map<String, dynamic> map) {
    return SubjectMappingRow(
      subjClsId: (map['Subj_ClsID'] as num).toInt(),
      subjId: (map['SubjID'] as num).toInt(),
      subjName: map['SubjName'] as String? ?? 'Subject ${map['SubjID']}',
      classId: (map['ClassID'] as num).toInt(),
      className: map['CName'] as String? ?? 'Class ${map['ClassID']}',
      teacherId: (map['TeacherID'] as num).toInt(),
      teacherName: map['TName'] as String? ?? 'Teacher ${map['TeacherID']}',
      teacherCategory: map['TeacherCategory'] as String? ?? 'Teacher',
      totalMarks: (map['TotalMarks'] as num?)?.toInt() ?? 0,
      totalPracticalMarks: (map['TotalPracticalMarks'] as num?)?.toInt() ?? 0,
    );
  }
}
