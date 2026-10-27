/// Model representing a full teacher/employee profile matching all 26 columns
/// of the legacy `Teachers` table per §S25 (`frmTeachers` at `0x00431fec`).
class TeacherProfile {
  final int? teacherId;
  final String tName;
  final String? tFName;
  final String tCnic;
  final String? dob;
  final String tContactNo1;
  final String? tContactNo2;
  final String? tAddress;
  final String? domicile;
  final String? tSubject;
  final String? doJoing; // Legacy spelling: DOJoing
  final String? detail;
  final String tIsPresent; // 'Y' or 'N'
  final String? tEmergencyContactName;
  final String? tEmergencyContactNo;
  final String? tDoLeft;
  final String? tQualification;
  final String? tProfessional;
  final String? tCertificate;
  final String? tFiledOfExperty; // Legacy spelling: TFiledOfExperty
  final String? tExperience;
  final String? tAnySpeciality;
  final String? officeFile;
  final String tCat;
  final double? tBioSer;
  final String? attSmsCont;

  const TeacherProfile({
    this.teacherId,
    required this.tName,
    this.tFName,
    required this.tCnic,
    this.dob,
    required this.tContactNo1,
    this.tContactNo2,
    this.tAddress,
    this.domicile,
    this.tSubject,
    this.doJoing,
    this.detail,
    this.tIsPresent = 'Y',
    this.tEmergencyContactName,
    this.tEmergencyContactNo,
    this.tDoLeft,
    this.tQualification,
    this.tProfessional,
    this.tCertificate,
    this.tFiledOfExperty,
    this.tExperience,
    this.tAnySpeciality,
    this.officeFile,
    this.tCat = 'Teacher',
    this.tBioSer,
    this.attSmsCont,
  });

  /// Factory creating an empty/default record for create mode (/staff/teachers/new).
  factory TeacherProfile.empty() {
    return const TeacherProfile(
      tName: '',
      tCnic: '',
      tContactNo1: '',
      tCat: 'Teacher',
      tIsPresent: 'Y',
    );
  }

  /// Whether the teacher is currently active on duty.
  bool get isActive => tIsPresent == 'Y';

  /// Generates a 1- or 2-letter uppercase initials token for avatar display.
  String get initials {
    final clean = tName.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory TeacherProfile.fromMap(Map<String, dynamic> map) {
    return TeacherProfile(
      teacherId: (map['TeacherID'] as num?)?.toInt(),
      tName: (map['TName'] as String?)?.trim() ?? '',
      tFName: (map['TFName'] as String?)?.trim(),
      tCnic: (map['TCNIC'] as String?)?.trim() ?? '',
      dob: (map['DOB'] as String?)?.trim(),
      tContactNo1: (map['TContactNo1'] as String?)?.trim() ?? '',
      tContactNo2: (map['TContactNo2'] as String?)?.trim(),
      tAddress: (map['TAddress'] as String?)?.trim(),
      domicile: (map['Domicile'] as String?)?.trim(),
      tSubject: (map['TSubject'] as String?)?.trim(),
      doJoing: (map['DOJoing'] as String?)?.trim(),
      detail: (map['Detail'] as String?)?.trim(),
      tIsPresent: (map['TIsPresent'] as String?)?.trim() ?? 'Y',
      tEmergencyContactName: (map['TEmergencyContactName'] as String?)?.trim(),
      tEmergencyContactNo: (map['TEmergencyContactNo'] as String?)?.trim(),
      tDoLeft: (map['TDoLeft'] as String?)?.trim(),
      tQualification: (map['TQualification'] as String?)?.trim(),
      tProfessional: (map['TProfessional'] as String?)?.trim(),
      tCertificate: (map['TCertificate'] as String?)?.trim(),
      tFiledOfExperty: (map['TFiledOfExperty'] as String?)?.trim(),
      tExperience: (map['TExperience'] as String?)?.trim(),
      tAnySpeciality: (map['TAnySpeciality'] as String?)?.trim(),
      officeFile: (map['OfficeFile'] as String?)?.trim(),
      tCat: (map['TCat'] as String?)?.trim() ?? 'Teacher',
      tBioSer: (map['TBioSer'] as num?)?.toDouble(),
      attSmsCont: (map['AttSMSCont'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (teacherId != null) 'TeacherID': teacherId,
      'TName': tName,
      'TFName': tFName,
      'TCNIC': tCnic,
      'DOB': dob,
      'TContactNo1': tContactNo1,
      'TContactNo2': tContactNo2,
      'TAddress': tAddress,
      'Domicile': domicile,
      'TSubject': tSubject,
      'DOJoing': doJoing,
      'Detail': detail,
      'TIsPresent': tIsPresent,
      'TEmergencyContactName': tEmergencyContactName,
      'TEmergencyContactNo': tEmergencyContactNo,
      'TDoLeft': tDoLeft,
      'TQualification': tQualification,
      'TProfessional': tProfessional,
      'TCertificate': tCertificate,
      'TFiledOfExperty': tFiledOfExperty,
      'TExperience': tExperience,
      'TAnySpeciality': tAnySpeciality,
      'OfficeFile': officeFile,
      'TCat': tCat,
      'TBioSer': tBioSer,
      'AttSMSCont': attSmsCont,
    };
  }

  TeacherProfile copyWith({
    int? teacherId,
    String? tName,
    String? tFName,
    String? tCnic,
    String? dob,
    String? tContactNo1,
    String? tContactNo2,
    String? tAddress,
    String? domicile,
    String? tSubject,
    String? doJoing,
    String? detail,
    String? tIsPresent,
    String? tEmergencyContactName,
    String? tEmergencyContactNo,
    String? tDoLeft,
    String? tQualification,
    String? tProfessional,
    String? tCertificate,
    String? tFiledOfExperty,
    String? tExperience,
    String? tAnySpeciality,
    String? officeFile,
    String? tCat,
    double? tBioSer,
    String? attSmsCont,
  }) {
    return TeacherProfile(
      teacherId: teacherId ?? this.teacherId,
      tName: tName ?? this.tName,
      tFName: tFName ?? this.tFName,
      tCnic: tCnic ?? this.tCnic,
      dob: dob ?? this.dob,
      tContactNo1: tContactNo1 ?? this.tContactNo1,
      tContactNo2: tContactNo2 ?? this.tContactNo2,
      tAddress: tAddress ?? this.tAddress,
      domicile: domicile ?? this.domicile,
      tSubject: tSubject ?? this.tSubject,
      doJoing: doJoing ?? this.doJoing,
      detail: detail ?? this.detail,
      tIsPresent: tIsPresent ?? this.tIsPresent,
      tEmergencyContactName:
          tEmergencyContactName ?? this.tEmergencyContactName,
      tEmergencyContactNo: tEmergencyContactNo ?? this.tEmergencyContactNo,
      tDoLeft: tDoLeft ?? this.tDoLeft,
      tQualification: tQualification ?? this.tQualification,
      tProfessional: tProfessional ?? this.tProfessional,
      tCertificate: tCertificate ?? this.tCertificate,
      tFiledOfExperty: tFiledOfExperty ?? this.tFiledOfExperty,
      tExperience: tExperience ?? this.tExperience,
      tAnySpeciality: tAnySpeciality ?? this.tAnySpeciality,
      officeFile: officeFile ?? this.officeFile,
      tCat: tCat ?? this.tCat,
      tBioSer: tBioSer ?? this.tBioSer,
      attSmsCont: attSmsCont ?? this.attSmsCont,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeacherProfile &&
        other.teacherId == teacherId &&
        other.tName == tName &&
        other.tFName == tFName &&
        other.tCnic == tCnic &&
        other.dob == dob &&
        other.tContactNo1 == tContactNo1 &&
        other.tContactNo2 == tContactNo2 &&
        other.tAddress == tAddress &&
        other.domicile == domicile &&
        other.tSubject == tSubject &&
        other.doJoing == doJoing &&
        other.detail == detail &&
        other.tIsPresent == tIsPresent &&
        other.tEmergencyContactName == tEmergencyContactName &&
        other.tEmergencyContactNo == tEmergencyContactNo &&
        other.tDoLeft == tDoLeft &&
        other.tQualification == tQualification &&
        other.tProfessional == tProfessional &&
        other.tCertificate == tCertificate &&
        other.tFiledOfExperty == tFiledOfExperty &&
        other.tExperience == tExperience &&
        other.tAnySpeciality == tAnySpeciality &&
        other.officeFile == officeFile &&
        other.tCat == tCat &&
        other.tBioSer == tBioSer &&
        other.attSmsCont == attSmsCont;
  }

  @override
  int get hashCode => Object.hashAll([
    teacherId,
    tName,
    tFName,
    tCnic,
    dob,
    tContactNo1,
    tContactNo2,
    tAddress,
    domicile,
    tSubject,
    doJoing,
    detail,
    tIsPresent,
    tEmergencyContactName,
    tEmergencyContactNo,
    tDoLeft,
    tQualification,
    tProfessional,
    tCertificate,
    tFiledOfExperty,
  ]);
}
