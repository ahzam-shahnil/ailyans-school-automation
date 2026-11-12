/// Model representation for a row in the faculty & staff directory.
/// Maps to the `Teachers` table per §S25 (`frmTeachers` at `0x00431fec`, `ObjID: 14`).
class TeacherRow {
  final int teacherId;
  final String tName;
  final String tfName;
  final String tCnic;
  final String tContactNo1;
  final String tSubject;
  final String tCat;
  final String tIsPresent;
  final String tQualification;
  final String doJoing; // [Sic: 'Joing' from legacy schema]

  const TeacherRow({
    required this.teacherId,
    required this.tName,
    this.tfName = '',
    required this.tCnic,
    required this.tContactNo1,
    this.tSubject = '',
    this.tCat = '',
    this.tIsPresent = 'Y',
    this.tQualification = '',
    this.doJoing = '',
  });

  /// Computes a 1- or 2-letter uppercase initials avatar string from [tName].
  /// Example: "Ahzam Shahnil" -> "NA", "Rehana" -> "R", "Syed Wazahat Raza Zaidi" -> "SZ".
  String get initials {
    final trimmed = tName.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final firstChar = parts.first.substring(0, 1).toUpperCase();
    final lastChar = parts.last.substring(0, 1).toUpperCase();
    return '$firstChar$lastChar';
  }

  /// Whether employee is currently active on-duty (`TIsPresent == 'Y'`).
  bool get isActive => tIsPresent.toUpperCase() == 'Y';

  /// Clean category label fallback.
  String get categoryLabel {
    if (tCat.trim().isEmpty) return 'Staff';
    return tCat.trim();
  }

  factory TeacherRow.fromMap(Map<String, dynamic> map) {
    return TeacherRow(
      teacherId: (map['TeacherID'] as num?)?.toInt() ?? 0,
      tName: (map['TName'] as String?)?.trim() ?? '',
      tfName: (map['TFName'] as String?)?.trim() ?? '',
      tCnic: (map['TCNIC'] as String?)?.trim() ?? '',
      tContactNo1: (map['TContactNo1'] as String?)?.trim() ?? '',
      tSubject: (map['TSubject'] as String?)?.trim() ?? '',
      tCat: (map['TCat'] as String?)?.trim() ?? '',
      tIsPresent: (map['TIsPresent'] as String?)?.trim().toUpperCase() ?? 'Y',
      tQualification: (map['TQualification'] as String?)?.trim() ?? '',
      doJoing: (map['DOJoing'] as String?)?.trim() ?? '',
    );
  }

  TeacherRow copyWith({
    int? teacherId,
    String? tName,
    String? tfName,
    String? tCnic,
    String? tContactNo1,
    String? tSubject,
    String? tCat,
    String? tIsPresent,
    String? tQualification,
    String? doJoing,
  }) {
    return TeacherRow(
      teacherId: teacherId ?? this.teacherId,
      tName: tName ?? this.tName,
      tfName: tfName ?? this.tfName,
      tCnic: tCnic ?? this.tCnic,
      tContactNo1: tContactNo1 ?? this.tContactNo1,
      tSubject: tSubject ?? this.tSubject,
      tCat: tCat ?? this.tCat,
      tIsPresent: tIsPresent ?? this.tIsPresent,
      tQualification: tQualification ?? this.tQualification,
      doJoing: doJoing ?? this.doJoing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherRow &&
          runtimeType == other.runtimeType &&
          teacherId == other.teacherId &&
          tName == other.tName &&
          tCnic == other.tCnic &&
          tCat == other.tCat &&
          tIsPresent == other.tIsPresent;

  @override
  int get hashCode =>
      teacherId.hashCode ^
      tName.hashCode ^
      tCnic.hashCode ^
      tCat.hashCode ^
      tIsPresent.hashCode;
}
