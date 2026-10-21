/// Represents an academic Class record from the SQLite `Class` table.
class SchoolClass {
  final int classId;
  final String cName;

  const SchoolClass({required this.classId, required this.cName});

  factory SchoolClass.fromMap(Map<String, Object?> map) {
    return SchoolClass(
      classId: (map['ClassID'] as int?) ?? 0,
      cName: (map['CName'] as String?) ?? '',
    );
  }
}

/// Represents an academic Class Section from the SQLite `ClassSec` table.
class ClassSec {
  final int classSecId;
  final int classId;
  final String secName;

  const ClassSec({
    required this.classSecId,
    required this.classId,
    required this.secName,
  });

  factory ClassSec.fromMap(Map<String, Object?> map) {
    return ClassSec(
      classSecId: (map['ClassSecID'] as int?) ?? 0,
      classId: (map['ClassID'] as int?) ?? 0,
      secName: (map['SecName'] as String?) ?? '',
    );
  }
}
