import 'package:intl/intl.dart';

/// Formats the full 3-part student name from `Stu_Reg`:
/// `NameFirst` + `NameMiddle` + `NameLast`, skipping null/blank parts so a
/// missing middle name yields 'First Last' with no double spaces.
///
/// Shared helper — every display surface (directory rows, sibling cards,
/// dialogs, certificates) must build names through this instead of
/// concatenating `NameFirst` and `NameLast` manually.
String formatStudentFullName(String? first, String? middle, String? last) =>
    [first, middle, last]
        .map((s) => (s ?? '').trim())
        .where((s) => s.isNotEmpty)
        .join(' ');

/// Full domain model representing a student in `Stu_Reg` (32 typed columns).
class Student {
  final int stuRegId;
  final String nameFirst;
  final String? nameMiddle; // OPTIONAL per Phase 2 divergence
  final String? nameLast;
  final DateTime? dob;
  final String? bFormNo;
  final String? fName; // Father name
  final String? cnicNo; // Father CNIC
  final String? occupation;
  final String? pAddress;
  final String? tAddress;
  final String? phoneOffice;
  final String? phoneRes;
  final String? mobile1;
  final String? mobile2;
  final String? religion;
  final String? pSchool;
  final String? slCertificate;
  final String? pClass;
  final int? admInClass;
  final int? admClass;
  final DateTime? doAdmission;
  final String? docsDetail;
  final double? discount;
  final String? emerContName;
  final String? emerContMobile;
  final String? officeFile;
  final String? remarls; // sic — legacy typo in DB column
  final int? vmDiscount;
  final int fullDiscount; // 0 or 1
  final String? nationality;
  final String? sex; // "Male" / "Female"
  final String? photoPath;

  const Student({
    required this.stuRegId,
    required this.nameFirst,
    this.nameMiddle,
    this.nameLast,
    this.dob,
    this.bFormNo,
    this.fName,
    this.cnicNo,
    this.occupation,
    this.pAddress,
    this.tAddress,
    this.phoneOffice,
    this.phoneRes,
    this.mobile1,
    this.mobile2,
    this.religion,
    this.pSchool,
    this.slCertificate,
    this.pClass,
    this.admInClass,
    this.admClass,
    this.doAdmission,
    this.docsDetail,
    this.discount,
    this.emerContName,
    this.emerContMobile,
    this.officeFile,
    this.remarls,
    this.vmDiscount,
    this.fullDiscount = 0,
    this.nationality,
    this.sex,
    this.photoPath,
  });

  /// Full concatenated student name (First + Middle + Last).
  String get fullName => formatStudentFullName(nameFirst, nameMiddle, nameLast);

  /// Initials (e.g., "MK" for Muhammad Ali Khan).
  String get initials {
    if (fullName.isEmpty) return 'ST';
    final parts = fullName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Formatted Date of Birth (e.g., "12-Apr-2002").
  String get formattedDob {
    if (dob == null) return '—';
    return DateFormat('dd-MMM-yyyy').format(dob!);
  }

  /// Formatted Date of Initial Admission (e.g., "15-Aug-2024").
  String get formattedDoAdmission {
    if (doAdmission == null) return '—';
    return DateFormat('dd-MMM-yyyy').format(doAdmission!);
  }

  /// Factory constructor to map from SQLite `Stu_Reg` row.
  factory Student.fromMap(Map<String, dynamic> map) {
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

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    return Student(
      stuRegId: map['Stu_RegID'] as int,
      nameFirst: (map['NameFirst'] as String?)?.trim() ?? '',
      nameMiddle: (map['NameMiddle'] as String?)?.trim(),
      nameLast: (map['NameLast'] as String?)?.trim(),
      dob: parseDate(map['DOB']),
      bFormNo: (map['B_Form_No'] as String?)?.trim(),
      fName: (map['F_Name'] as String?)?.trim(),
      cnicNo: (map['CNIC_No'] as String?)?.trim(),
      occupation: (map['Occupation'] as String?)?.trim(),
      pAddress: (map['P_Address'] as String?)?.trim(),
      tAddress: (map['T_Address'] as String?)?.trim(),
      phoneOffice: (map['Phone_Office'] as String?)?.trim(),
      phoneRes: (map['Phone_Res'] as String?)?.trim(),
      mobile1: (map['Mobile1'] as String?)?.trim(),
      mobile2: (map['Mobile2'] as String?)?.trim(),
      religion: (map['Religion'] as String?)?.trim(),
      pSchool: (map['P_School'] as String?)?.trim(),
      slCertificate: (map['SLCertificate'] as String?)?.trim(),
      pClass: (map['P_Class'] as String?)?.trim(),
      admInClass: parseInt(map['AdmInClass']),
      admClass: parseInt(map['AdmClass']),
      doAdmission: parseDate(map['DOAdmission']),
      docsDetail: (map['DocsDetail'] as String?)?.trim(),
      discount: parseDouble(map['Discount']),
      emerContName: (map['EmerContName'] as String?)?.trim(),
      emerContMobile: (map['EmerContMobile'] as String?)?.trim(),
      officeFile: (map['OfficeFile'] as String?)?.trim(),
      remarls: (map['Remarls'] as String?)?.trim(),
      vmDiscount: parseInt(map['VMDiscount']),
      fullDiscount: parseInt(map['FullDiscount']) ?? 0,
      nationality: (map['Nationality'] as String?)?.trim(),
      sex: (map['Sex'] as String?)?.trim(),
      photoPath: (map['photo_path'] as String?)?.trim(),
    );
  }

  /// Converts student entity to database row for `Stu_Reg`.
  Map<String, dynamic> toMap() {
    String? formatDate(DateTime? dt) {
      if (dt == null) return null;
      return DateFormat('yyyy-MM-dd').format(dt);
    }

    return {
      'Stu_RegID': stuRegId,
      'NameFirst': nameFirst,
      'NameMiddle': nameMiddle,
      'NameLast': nameLast,
      'DOB': formatDate(dob),
      'B_Form_No': bFormNo,
      'F_Name': fName,
      'CNIC_No': cnicNo,
      'Occupation': occupation,
      'P_Address': pAddress,
      'T_Address': tAddress,
      'Phone_Office': phoneOffice,
      'Phone_Res': phoneRes,
      'Mobile1': mobile1,
      'Mobile2': mobile2,
      'Religion': religion,
      'P_School': pSchool,
      'SLCertificate': slCertificate,
      'P_Class': pClass,
      'AdmInClass': admInClass,
      'AdmClass': admClass,
      'DOAdmission': formatDate(doAdmission),
      'DocsDetail': docsDetail,
      'Discount': discount,
      'EmerContName': emerContName,
      'EmerContMobile': emerContMobile,
      'OfficeFile': officeFile,
      'Remarls': remarls,
      'VMDiscount': vmDiscount,
      'FullDiscount': fullDiscount,
      'Nationality': nationality,
      'Sex': sex,
      'photo_path': photoPath,
    };
  }

  /// Creates a copy of [Student] with modified fields.
  Student copyWith({
    int? stuRegId,
    String? nameFirst,
    String? nameMiddle,
    String? nameLast,
    DateTime? dob,
    String? bFormNo,
    String? fName,
    String? cnicNo,
    String? occupation,
    String? pAddress,
    String? tAddress,
    String? phoneOffice,
    String? phoneRes,
    String? mobile1,
    String? mobile2,
    String? religion,
    String? pSchool,
    String? slCertificate,
    String? pClass,
    int? admInClass,
    int? admClass,
    DateTime? doAdmission,
    String? docsDetail,
    double? discount,
    String? emerContName,
    String? emerContMobile,
    String? officeFile,
    String? remarls,
    int? vmDiscount,
    int? fullDiscount,
    String? nationality,
    String? sex,
    String? photoPath,
  }) {
    return Student(
      stuRegId: stuRegId ?? this.stuRegId,
      nameFirst: nameFirst ?? this.nameFirst,
      nameMiddle: nameMiddle ?? this.nameMiddle,
      nameLast: nameLast ?? this.nameLast,
      dob: dob ?? this.dob,
      bFormNo: bFormNo ?? this.bFormNo,
      fName: fName ?? this.fName,
      cnicNo: cnicNo ?? this.cnicNo,
      occupation: occupation ?? this.occupation,
      pAddress: pAddress ?? this.pAddress,
      tAddress: tAddress ?? this.tAddress,
      phoneOffice: phoneOffice ?? this.phoneOffice,
      phoneRes: phoneRes ?? this.phoneRes,
      mobile1: mobile1 ?? this.mobile1,
      mobile2: mobile2 ?? this.mobile2,
      religion: religion ?? this.religion,
      pSchool: pSchool ?? this.pSchool,
      slCertificate: slCertificate ?? this.slCertificate,
      pClass: pClass ?? this.pClass,
      admInClass: admInClass ?? this.admInClass,
      admClass: admClass ?? this.admClass,
      doAdmission: doAdmission ?? this.doAdmission,
      docsDetail: docsDetail ?? this.docsDetail,
      discount: discount ?? this.discount,
      emerContName: emerContName ?? this.emerContName,
      emerContMobile: emerContMobile ?? this.emerContMobile,
      officeFile: officeFile ?? this.officeFile,
      remarls: remarls ?? this.remarls,
      vmDiscount: vmDiscount ?? this.vmDiscount,
      fullDiscount: fullDiscount ?? this.fullDiscount,
      nationality: nationality ?? this.nationality,
      sex: sex ?? this.sex,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}
