/// Model representing an academic class subject taught by the teacher
/// joined from `Subj_Class`, `Class`, and `Subject` for Tab 2.
class TeacherSubjectAssignment {
  final int subjClsId;
  final int classId;
  final String className;
  final int subjId;
  final String subjName;
  final double totalMarks;
  final double totalPracticalMarks;

  const TeacherSubjectAssignment({
    required this.subjClsId,
    required this.classId,
    required this.className,
    required this.subjId,
    required this.subjName,
    required this.totalMarks,
    required this.totalPracticalMarks,
  });

  /// Combined theory and practical marks.
  double get combinedMarks => totalMarks + totalPracticalMarks;

  factory TeacherSubjectAssignment.fromMap(Map<String, dynamic> map) {
    return TeacherSubjectAssignment(
      subjClsId: (map['Subj_ClsID'] as num?)?.toInt() ?? 0,
      classId: (map['ClassID'] as num?)?.toInt() ?? 0,
      className: (map['CName'] as String?)?.trim() ?? '',
      subjId: (map['SubjID'] as num?)?.toInt() ?? 0,
      subjName: (map['SubjName'] as String?)?.trim() ?? '',
      totalMarks: (map['TotalMarks'] as num?)?.toDouble() ?? 0.0,
      totalPracticalMarks:
          (map['TotalPracticalMarks'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
