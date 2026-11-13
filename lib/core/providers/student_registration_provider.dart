import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../repositories/photo_repository.dart';
import '../db/database.dart';
import 'package:school_automation/core/sync/node_id_allocator.dart';
import '../../models/student.dart';
import 'clock_provider.dart';

/// Data draft holding all in-progress student admission form state.
class WizardDraft {
  // Step 1: Personal
  String nameFirst;
  String nameMiddle;
  String nameLast;
  DateTime? dob;
  String? gender; // 'Male' / 'Female'
  String? bloodGroup; // 'A+'..'O-'
  String? nationality; // default 'Pakistani'
  String? religion; // default 'Islam'
  String? photoPath; // local file path while editing
  String? bFormNo; // Child Form-B / CRC No

  // Step 2: Guardian
  String fName;
  String cnicNo;
  String? occupation;
  String? pSchool;
  String? pClass;
  String? slCertificate;

  // Step 3: Contact
  String mobile1;
  String? mobile2;
  String? emerContName;
  String? emerContMobile;
  String? pAddress;
  String? tAddress;

  // Aliases for spec adherence
  String? get permanentAddress => pAddress;
  set permanentAddress(String? val) => pAddress = val;
  String? get presentAddress => tAddress;
  set presentAddress(String? val) => tAddress = val;
  String? get fatherOccupation => occupation;
  set fatherOccupation(String? val) => occupation = val;

  /// Copies family addresses and contacts from sibling, prioritizing highest Stu_RegID.
  /// Only populates empty/whitespace fields; does not overwrite existing user input.
  void copyFamilyFromSibling(SiblingInfo sibling) {
    if (pAddress == null || pAddress!.trim().isEmpty) {
      if (sibling.pAddress != null && sibling.pAddress!.trim().isNotEmpty) {
        pAddress = sibling.pAddress;
      }
    }
    if (tAddress == null || tAddress!.trim().isEmpty) {
      if (sibling.tAddress != null && sibling.tAddress!.trim().isNotEmpty) {
        tAddress = sibling.tAddress;
      }
    }
    if (occupation == null || occupation!.trim().isEmpty) {
      if (sibling.occupation != null && sibling.occupation!.trim().isNotEmpty) {
        occupation = sibling.occupation;
      }
    }
    if (mobile1.trim().isEmpty) {
      if (sibling.mobile1 != null && sibling.mobile1!.trim().isNotEmpty) {
        mobile1 = sibling.mobile1!;
      }
    }
    if (emerContName == null || emerContName!.trim().isEmpty) {
      if (sibling.emerContName != null &&
          sibling.emerContName!.trim().isNotEmpty) {
        emerContName = sibling.emerContName;
      }
    }
    if (emerContMobile == null || emerContMobile!.trim().isEmpty) {
      if (sibling.emerContMobile != null &&
          sibling.emerContMobile!.trim().isNotEmpty) {
        emerContMobile = sibling.emerContMobile;
      }
    }
  }

  // Step 4: Academic
  int? admInClass;
  int? admClass; // defaults to admInClass
  int? classSecId; // Section for initial enrollment
  DateTime doAdmission;
  double discount;
  int vmDiscount;
  bool fullDiscount;
  String? remarks;
  int? currentStuRegId;
  List<int> pendingSiblingIds;

  // Phase H Shot 2 — Reg ID bar (VB6 all-in-one admission):
  /// Explicitly chosen Registration ID (sequential default, manual edit, or
  /// gap pick). Null falls back to NodeIdAllocator (offline node block).
  int? customRegId;
  /// Whether the Reg ID TextField is unlocked via [Edit Reg ID].
  bool isRegIdEditable;
  /// True after [GO] loads an existing student for editing (save = UPDATE).
  bool isEditingExisting;

  WizardDraft({
    this.nameFirst = '',
    this.nameMiddle = '',
    this.nameLast = '',
    this.dob,
    this.gender = 'Male',
    this.bloodGroup,
    this.nationality = 'Pakistani',
    this.religion = 'Islam',
    this.photoPath,
    this.bFormNo,
    this.fName = '',
    this.cnicNo = '',
    this.occupation,
    this.pSchool,
    this.pClass,
    this.slCertificate,
    this.mobile1 = '',
    this.mobile2,
    this.emerContName,
    this.emerContMobile,
    this.pAddress,
    this.tAddress,
    this.admInClass,
    this.admClass,
    this.classSecId,
    DateTime? doAdmission,
    this.discount = 0.0,
    this.vmDiscount = 0,
    this.fullDiscount = false,
    this.remarks,
    this.currentStuRegId,
    this.pendingSiblingIds = const [],
    this.customRegId,
    this.isRegIdEditable = false,
    this.isEditingExisting = false,
  }) : doAdmission = doAdmission ?? DateTime.now();

  /// Validates requirement for specific step (0-indexed).
  bool isValidForStep(int step) {
    switch (step) {
      case 0:
        return nameFirst.trim().isNotEmpty && dob != null;
      case 1:
        return fName.trim().isNotEmpty && cnicNo.trim().isNotEmpty;
      case 2:
        return mobile1.trim().isNotEmpty;
      case 3:
        return admInClass != null;
      default:
        return false;
    }
  }

  /// True if all 4 steps satisfy their respective requirements.
  bool get isFullyValid =>
      isValidForStep(0) &&
      isValidForStep(1) &&
      isValidForStep(2) &&
      isValidForStep(3);

  /// True if any field contains user-entered modifications.
  bool get isDirty {
    return nameFirst.trim().isNotEmpty ||
        nameMiddle.trim().isNotEmpty ||
        nameLast.trim().isNotEmpty ||
        dob != null ||
        (photoPath != null && photoPath!.isNotEmpty) ||
        (bFormNo != null && bFormNo!.trim().isNotEmpty) ||
        fName.trim().isNotEmpty ||
        cnicNo.trim().isNotEmpty ||
        (occupation != null && occupation!.trim().isNotEmpty) ||
        (pSchool != null && pSchool!.trim().isNotEmpty) ||
        (pClass != null && pClass!.trim().isNotEmpty) ||
        (slCertificate != null && slCertificate!.trim().isNotEmpty) ||
        mobile1.trim().isNotEmpty ||
        (mobile2 != null && mobile2!.trim().isNotEmpty) ||
        (emerContName != null && emerContName!.trim().isNotEmpty) ||
        (emerContMobile != null && emerContMobile!.trim().isNotEmpty) ||
        (pAddress != null && pAddress!.trim().isNotEmpty) ||
        (tAddress != null && tAddress!.trim().isNotEmpty) ||
        admInClass != null ||
        classSecId != null ||
        discount > 0 ||
        vmDiscount > 0 ||
        fullDiscount ||
        (remarks != null && remarks!.trim().isNotEmpty);
  }

  WizardDraft copyWith({
    String? nameFirst,
    String? nameMiddle,
    String? nameLast,
    DateTime? dob,
    String? gender,
    String? bloodGroup,
    String? nationality,
    String? religion,
    String? photoPath,
    String? bFormNo,
    String? fName,
    String? cnicNo,
    String? occupation,
    String? pSchool,
    String? pClass,
    String? slCertificate,
    String? mobile1,
    String? mobile2,
    String? emerContName,
    String? emerContMobile,
    String? pAddress,
    String? tAddress,
    int? admInClass,
    int? admClass,
    int? classSecId,
    DateTime? doAdmission,
    double? discount,
    int? vmDiscount,
    bool? fullDiscount,
    String? remarks,
    int? currentStuRegId,
    List<int>? pendingSiblingIds,
    int? customRegId,
    bool? isRegIdEditable,
    bool? isEditingExisting,
  }) {
    return WizardDraft(
      nameFirst: nameFirst ?? this.nameFirst,
      nameMiddle: nameMiddle ?? this.nameMiddle,
      nameLast: nameLast ?? this.nameLast,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      nationality: nationality ?? this.nationality,
      religion: religion ?? this.religion,
      photoPath: photoPath ?? this.photoPath,
      bFormNo: bFormNo ?? this.bFormNo,
      fName: fName ?? this.fName,
      cnicNo: cnicNo ?? this.cnicNo,
      occupation: occupation ?? this.occupation,
      pSchool: pSchool ?? this.pSchool,
      pClass: pClass ?? this.pClass,
      slCertificate: slCertificate ?? this.slCertificate,
      mobile1: mobile1 ?? this.mobile1,
      mobile2: mobile2 ?? this.mobile2,
      emerContName: emerContName ?? this.emerContName,
      emerContMobile: emerContMobile ?? this.emerContMobile,
      pAddress: pAddress ?? this.pAddress,
      tAddress: tAddress ?? this.tAddress,
      admInClass: admInClass ?? this.admInClass,
      admClass: admClass ?? this.admClass ?? (admInClass ?? this.admInClass),
      classSecId: classSecId ?? this.classSecId,
      doAdmission: doAdmission ?? this.doAdmission,
      discount: discount ?? this.discount,
      vmDiscount: vmDiscount ?? this.vmDiscount,
      fullDiscount: fullDiscount ?? this.fullDiscount,
      remarks: remarks ?? this.remarks,
      currentStuRegId: currentStuRegId ?? this.currentStuRegId,
      pendingSiblingIds: pendingSiblingIds ?? List.from(this.pendingSiblingIds),
      customRegId: customRegId ?? this.customRegId,
      isRegIdEditable: isRegIdEditable ?? this.isRegIdEditable,
      isEditingExisting: isEditingExisting ?? this.isEditingExisting,
    );
  }
}

/// StateNotifier to manage reactive updates to the WizardDraft state.
class WizardDraftNotifier extends StateNotifier<WizardDraft> {
  final Ref? _ref;

  WizardDraftNotifier([Ref? ref])
    : _ref = ref,
      super(
        WizardDraft(doAdmission: ref?.read(clockProvider)() ?? DateTime.now()),
      );

  DateTime _now() => _ref?.read(clockProvider)() ?? DateTime.now();

  void update(WizardDraft Function(WizardDraft current) updater) {
    state = updater(state);
  }

  void setNameFirst(String val) => state = state.copyWith(nameFirst: val);
  void setNameMiddle(String val) => state = state.copyWith(nameMiddle: val);
  void setNameLast(String val) => state = state.copyWith(nameLast: val);
  void setDob(DateTime? val) => state = state.copyWith(dob: val);
  void setGender(String? val) => state = state.copyWith(gender: val);
  void setBloodGroup(String? val) => state = state.copyWith(bloodGroup: val);
  void setNationality(String? val) => state = state.copyWith(nationality: val);
  void setReligion(String? val) => state = state.copyWith(religion: val);
  void setPhotoPath(String? val) => state = state.copyWith(photoPath: val);
  void setBFormNo(String? val) => state = state.copyWith(bFormNo: val);

  void setFName(String val) => state = state.copyWith(fName: val);
  void setCnicNo(String val) => state = state.copyWith(cnicNo: val);
  void setOccupation(String? val) => state = state.copyWith(occupation: val);
  void setPSchool(String? val) => state = state.copyWith(pSchool: val);
  void setPClass(String? val) => state = state.copyWith(pClass: val);
  void setSLCertificate(String? val) =>
      state = state.copyWith(slCertificate: val);

  void setMobile1(String val) => state = state.copyWith(mobile1: val);
  void setMobile2(String? val) => state = state.copyWith(mobile2: val);
  void setEmerContName(String? val) =>
      state = state.copyWith(emerContName: val);
  void setEmerContMobile(String? val) =>
      state = state.copyWith(emerContMobile: val);
  void setPAddress(String? val) => state = state.copyWith(pAddress: val);
  void setTAddress(String? val) => state = state.copyWith(tAddress: val);
  void setPermanentAddress(String val) => setPAddress(val);
  void setPresentAddress(String val) => setTAddress(val);
  void setFatherOccupation(String? val) => setOccupation(val);

  void copyFamilyFromSibling(SiblingInfo sibling) {
    final updated = state.copyWith();
    updated.copyFamilyFromSibling(sibling);
    state = updated;
  }

  void setPendingSiblingIds(List<int> ids) =>
      state = state.copyWith(pendingSiblingIds: ids);

  void setAdmInClass(int? val) =>
      state = state.copyWith(admInClass: val, admClass: val);
  void setClassSecId(int? val) => state = state.copyWith(classSecId: val);
  void setDoAdmission(DateTime val) => state = state.copyWith(doAdmission: val);
  void setDiscount(double val) => state = state.copyWith(discount: val);
  void setVmDiscount(int val) => state = state.copyWith(vmDiscount: val);
  void setFullDiscount(bool val) => state = state.copyWith(fullDiscount: val);
  void setRemarks(String? val) => state = state.copyWith(remarks: val);

  void reset() => state = WizardDraft(doAdmission: _now());

  // ───────────────────────────────────────────────────────────────
  // Phase H Shot 2 — Reg ID bar services (sequential / gaps / lookup)
  // ───────────────────────────────────────────────────────────────

  /// Explicitly chosen Registration ID (null = allocator fallback on save).
  void setCustomRegId(int? val) {
    final d = state.copyWith();
    d.customRegId = val;
    state = d;
  }

  /// [Edit Reg ID] toggle state.
  void setRegIdEditable(bool val) {
    final d = state.copyWith();
    d.isRegIdEditable = val;
    state = d;
  }

  /// Sequential default: `MAX(Stu_RegID) + 1` restricted to the shared
  /// physical-register range (< 100000). Never proposes an offline node-block
  /// ID by default. Returns null when no database is reachable (tests).
  Future<int?> nextSequentialRegId() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        'SELECT COALESCE(MAX(Stu_RegID), 0) + 1 AS nextId '
        'FROM Stu_Reg WHERE Stu_RegID < 100000',
      );
      final id = (rows.first['nextId'] as num?)?.toInt();
      return (id != null && id >= 1) ? id : 1;
    } catch (_) {
      return null;
    }
  }

  /// Finds up to 50 missing (gap) Registration IDs below 100000,
  /// most-recent-first. Candidates inside the [LIMIT 200] window are each
  /// confirmed with `SELECT 1 FROM Stu_Reg WHERE Stu_RegID = ?`.
  Future<List<int>> findMissingRegIds() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        'SELECT Stu_RegID FROM Stu_Reg '
        'WHERE Stu_RegID > 0 AND Stu_RegID < 100000 '
        'ORDER BY Stu_RegID DESC LIMIT 200',
      );
      if (rows.isEmpty) return const [];
      final existing = rows
          .map((r) => (r['Stu_RegID'] as num).toInt())
          .toList()
        ..sort();
      final minId = existing.first;
      final maxId = existing.last;
      final present = existing.toSet();

      final gaps = <int>[];
      for (int candidate = maxId - 1;
          candidate > minId && gaps.length < 50;
          candidate--) {
        if (present.contains(candidate)) continue;
        // Confirm the candidate is genuinely missing (zero rows = missing).
        final dup = await db.rawQuery(
          'SELECT 1 FROM Stu_Reg WHERE Stu_RegID = ? LIMIT 1',
          [candidate],
        );
        if (dup.isEmpty) gaps.add(candidate);
      }
      return gaps;
    } catch (_) {
      return const [];
    }
  }

  /// [GO] lookup: loads an existing student (Stu_Reg + active Student_Class)
  /// into the draft and switches the form into edit mode. Returns false when
  /// no record exists for [regId].
  Future<bool> loadExistingStudentByRegId(int regId) async {
    if (regId <= 0) return false;
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        'SELECT * FROM Stu_Reg WHERE Stu_RegID = ? LIMIT 1',
        [regId],
      );
      if (rows.isEmpty) return false;
      final r = rows.first;

      DateTime? dob;
      final dobRaw = (r['DOB'] as String?)?.trim();
      if (dobRaw != null && dobRaw.isNotEmpty) {
        dob = DateTime.tryParse(dobRaw);
        if (dob == null) {
          final parts = dobRaw.split('/');
          if (parts.length == 3) {
            final d = int.tryParse(parts[1]);
            final m = int.tryParse(parts[0]);
            var y = int.tryParse(parts[2]);
            if (d != null && m != null && y != null) {
              if (y < 100) y += 2000;
              dob = DateTime(y, m, d);
            }
          }
        }
      }
      final doAdmRaw = (r['DOAdmission'] as String?)?.trim();
      final doAdmission = (doAdmRaw != null && doAdmRaw.isNotEmpty
              ? DateTime.tryParse(doAdmRaw)
              : null) ??
          _now();

      int? admInClass;
      int? admClass = (r['AdmClass'] as num?)?.toInt();
      int? classSecId;
      final enrollRows = await db.rawQuery(
        'SELECT ClassID, ClassSecID FROM Student_Class '
        'WHERE Stu_RegID = ? AND Present = 1 '
        'ORDER BY SessionYr DESC LIMIT 1',
        [regId],
      );
      if (enrollRows.isNotEmpty) {
        admInClass = (enrollRows.first['ClassID'] as num?)?.toInt();
        classSecId = (enrollRows.first['ClassSecID'] as num?)?.toInt();
      }
      admClass ??= admInClass;

      state = WizardDraft(
        nameFirst: (r['NameFirst'] as String?) ?? '',
        nameMiddle: (r['NameMiddle'] as String?) ?? '',
        nameLast: (r['NameLast'] as String?) ?? '',
        dob: dob,
        gender: (r['Sex'] as String?) ?? 'Male',
        bloodGroup: r['BloodGroup'] as String?,
        nationality: (r['Nationality'] as String?) ?? 'Pakistani',
        religion: (r['Religion'] as String?) ?? 'Islam',
        photoPath: r['photo_path'] as String?,
        bFormNo: r['B_Form_No'] as String?,
        fName: (r['F_Name'] as String?) ?? '',
        cnicNo: (r['CNIC_No'] as String?) ?? '',
        occupation: r['Occupation'] as String?,
        pSchool: r['P_School'] as String?,
        pClass: r['P_Class'] as String?,
        slCertificate: r['SLCertificate'] as String?,
        mobile1: (r['Mobile1'] as String?) ?? '',
        mobile2: r['Mobile2'] as String?,
        emerContName: r['EmerContName'] as String?,
        emerContMobile: r['EmerContMobile'] as String?,
        pAddress: r['P_Address'] as String?,
        tAddress: r['T_Address'] as String?,
        admInClass: admInClass,
        admClass: admClass,
        classSecId: classSecId,
        doAdmission: doAdmission,
        discount:
            ((r['Discount'] as num?)?.toDouble()) ?? 0.0,
        vmDiscount: (r['VMDiscount'] as num?)?.toInt() ?? 0,
        fullDiscount: (r['FullDiscount'] as num?)?.toInt() == 1,
        remarks: r['Remarls'] as String?,
        currentStuRegId: regId,
        customRegId: regId,
        isRegIdEditable: false,
        isEditingExisting: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Global provider for Wizard draft state.
final wizardDraftProvider =
    StateNotifierProvider<WizardDraftNotifier, WizardDraft>((ref) {
      return WizardDraftNotifier(ref);
    });

/// Global provider for active wizard step index (0..3).
final wizardStepProvider = StateProvider<int>((ref) => 0);

/// Data model representing sibling detected by Father CNIC.
class SiblingInfo {
  final int stuRegId;
  final String nameFirst;
  final String? nameMiddle;
  final String? nameLast;
  final String? fName;
  final String? cnicNo;
  final String? className;
  final String? sectionName;
  final int? classRollNo;
  final String? pAddress;
  final String? tAddress;
  final String? emerContName;
  final String? emerContMobile;
  final String? occupation;
  final String? mobile1;

  const SiblingInfo({
    required this.stuRegId,
    required this.nameFirst,
    this.nameMiddle,
    this.nameLast,
    this.fName,
    this.cnicNo,
    this.className,
    this.sectionName,
    this.classRollNo,
    this.pAddress,
    this.tAddress,
    this.emerContName,
    this.emerContMobile,
    this.occupation,
    this.mobile1,
  });

  String get fullName =>
      formatStudentFullName(nameFirst, nameMiddle, nameLast);

  String get initials {
    if (fullName.isEmpty) return 'ST';
    final parts = fullName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Query parameters for discovering siblings by Father CNIC or Father Name.
class SiblingQuery {
  final String cnicNo;
  final String fName;

  const SiblingQuery([this.cnicNo = '', this.fName = '']);

  const SiblingQuery.cnic(String cnic) : cnicNo = cnic, fName = '';

  const SiblingQuery.fatherName(String fatherName)
    : cnicNo = '',
      fName = fatherName;

  factory SiblingQuery.query({
    String cnicNo = '',
    String? cnic,
    String? fatherName,
    String fName = '',
  }) {
    return SiblingQuery(cnic ?? cnicNo, fatherName ?? fName);
  }

  factory SiblingQuery.from(Object? input) {
    if (input is SiblingQuery) return input;
    if (input is String) {
      final trimmed = input.trim();
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 8 || (!trimmed.contains(' ') && digits.isNotEmpty)) {
        return SiblingQuery.cnic(trimmed);
      }
      return SiblingQuery.fatherName(trimmed);
    }
    return const SiblingQuery();
  }

  String trim() => cnicNo.isNotEmpty ? cnicNo.trim() : fName.trim();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiblingQuery &&
          runtimeType == other.runtimeType &&
          cnicNo.trim() == other.cnicNo.trim() &&
          fName.trim().toLowerCase() == other.fName.trim().toLowerCase();

  @override
  int get hashCode =>
      cnicNo.trim().hashCode ^ fName.trim().toLowerCase().hashCode;
}

/// Discovers siblings under a Father CNIC (min 10 digits or 10-char prefix)
/// or Father Name fallback (min 5 chars).
final siblingDiscoveryProvider =
    FutureProvider.family<List<SiblingInfo>, SiblingQuery>((ref, query) async {
      final db = await DatabaseService.instance.database;
      return fetchSiblings(db, cnic: query.cnicNo, fatherName: query.fName);
    });

/// Queries SQLite for siblings matching CNIC or Father Name.
Future<List<SiblingInfo>> fetchSiblings(
  Database db, {
  String? cnic,
  String? fatherName,
}) async {
  final rawCnic = (cnic ?? '').trim();
  final rawFName = (fatherName ?? '').trim().toLowerCase();
  final digits = rawCnic.replaceAll(RegExp(r'[^0-9]'), '');

  final canMatchCnic =
      digits.length >= 10 || (digits.length >= 9 && rawCnic.length >= 10);
  final canMatchName = rawFName.length >= 5;
  if (!canMatchCnic && !canMatchName) return const [];

  final query = canMatchCnic
      ? '''
    SELECT
      sr.Stu_RegID,
      sr.NameFirst,
      sr.NameMiddle,
      sr.NameLast,
      sr.F_Name,
      sr.CNIC_No,
      sr.P_Address,
      sr.T_Address,
      sr.Occupation,
      sr.Mobile1,
      sr.EmerContName,
      sr.EmerContMobile,
      sc.ClassRollNo,
      c.CName as class_name,
      cs.SecName as section_name
    FROM Stu_Reg sr
    LEFT JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID AND sc.Present = 1
    LEFT JOIN Class c ON sc.ClassID = c.ClassID
    LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
    WHERE REPLACE(sr.CNIC_No, '-', '') LIKE ? || '%'
    GROUP BY sr.Stu_RegID
    ORDER BY sr.Stu_RegID ASC
  '''
      : '''
    SELECT
      sr.Stu_RegID,
      sr.NameFirst,
      sr.NameMiddle,
      sr.NameLast,
      sr.F_Name,
      sr.CNIC_No,
      sr.P_Address,
      sr.T_Address,
      sr.Occupation,
      sr.Mobile1,
      sr.EmerContName,
      sr.EmerContMobile,
      sc.ClassRollNo,
      c.CName as class_name,
      cs.SecName as section_name
    FROM Stu_Reg sr
    LEFT JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID AND sc.Present = 1
    LEFT JOIN Class c ON sc.ClassID = c.ClassID
    LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
    WHERE LOWER(sr.F_Name) = ?
    GROUP BY sr.Stu_RegID
    ORDER BY sr.Stu_RegID ASC
  ''';

  final args = canMatchCnic ? [digits] : [rawFName];
  final rows = await db.rawQuery(query, args);

  return rows
      .map(
        (r) => SiblingInfo(
          stuRegId: (r['Stu_RegID'] as int?) ?? 0,
          nameFirst: (r['NameFirst'] as String?) ?? '',
          nameMiddle: (r['NameMiddle'] as String?)?.trim(),
          nameLast: r['NameLast'] as String?,
          fName: r['F_Name'] as String?,
          cnicNo: r['CNIC_No'] as String?,
          className: r['class_name'] as String?,
          sectionName: r['section_name'] as String?,
          classRollNo: r['ClassRollNo'] as int?,
          pAddress: r['P_Address'] as String?,
          tAddress: r['T_Address'] as String?,
          emerContName: r['EmerContName'] as String?,
          emerContMobile: r['EmerContMobile'] as String?,
          occupation: r['Occupation'] as String?,
          mobile1: r['Mobile1'] as String?,
        ),
      )
      .toList();
}

/// Queries fee parameters for a given ClassID in the current session.
final feePreviewProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((
      ref,
      classId,
    ) async {
      final db = await DatabaseService.instance.database;

      final sessionRows = await db.rawQuery(
        "SELECT config_value FROM app_config WHERE config_key = 'default_session_yr' LIMIT 1",
      );
      final activeSession = sessionRows.isNotEmpty
          ? (sessionRows.first['config_value'] as String? ?? '2026-27')
          : '2026-27';

      // Query tariffs for active session first
      var rows = await db.rawQuery(
        'SELECT cpf.Fee, fp.ParamDesciption FROM Cls_Param_Fee cpf '
        'LEFT JOIN FeeParameters fp ON cpf.FeeParamID = fp.FeeParamID '
        'WHERE cpf.ClassID = ? AND cpf.FeeYr = ?',
        [classId, activeSession],
      );

      // Fallback: if no tariffs exist for active session, use the most recent
      // tariff year available for this class (prevents "Rs. 0" preview when
      // new session starts before tariffs are cloned)
      if (rows.isEmpty) {
        rows = await db.rawQuery(
          'SELECT cpf.Fee, fp.ParamDesciption FROM Cls_Param_Fee cpf '
          'LEFT JOIN FeeParameters fp ON cpf.FeeParamID = fp.FeeParamID '
          'WHERE cpf.ClassID = ? AND cpf.FeeYr = ('
          '  SELECT MAX(FeeYr) FROM Cls_Param_Fee WHERE ClassID = ?'
          ')',
          [classId, classId],
        );
      }
      return rows;
    });

/// Resolves the active session year:
///   1. Explicit param if provided
///   2. app_config.default_session_yr from DB
///   3. '2017-2018' as fallback when app_config is unconfigured (test DB fixtures)
Future<String> _resolveActiveSession(Database db, {String? override}) async {
  if (override != null && override.isNotEmpty) return override;
  try {
    final rows = await db.rawQuery(
      "SELECT config_value FROM app_config WHERE config_key = 'default_session_yr' LIMIT 1",
    );
    if (rows.isNotEmpty) {
      final value = (rows.first['config_value'] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
  } catch (_) {
    // app_config may not exist in bare test DBs — fall through
  }
  return '2017-2018';
}

/// Submits the admission transaction to SQLite and returns newly assigned Stu_RegID.
Future<int> submitStudentAdmission(
  WizardDraft draft, {
  String? sessionYr,
  Database? dbOverride,
}) async {
  final db = dbOverride ?? await DatabaseService.instance.database;
  final resolvedSession = await _resolveActiveSession(db, override: sessionYr);

  return await db.transaction<int>((txn) async {
    // 1. Resolve Stu_RegID.
    //    - draft.customRegId set → sequential/manual Reg ID from the VB6-style
    //      Reg ID bar (duplicate + cross-node-block guarded).
    //    - draft.customRegId null → NodeIdAllocator (offline node block) —
    //      preserved legacy/default allocation path.
    final bool editingExisting =
        draft.isEditingExisting &&
        draft.currentStuRegId != null &&
        draft.currentStuRegId == draft.customRegId;
    final int nextStuRegId;
    if (draft.customRegId != null) {
      final requested = draft.customRegId!;
      if (requested <= 0) {
        throw StateError('Registration ID must be a positive number.');
      }
      final dup = await txn.rawQuery(
        'SELECT 1 FROM Stu_Reg WHERE Stu_RegID = ? LIMIT 1',
        [requested],
      );
      if (dup.isNotEmpty && !editingExisting) {
        throw StateError(
          'Registration ID $requested is already in use by another student. '
          'Pick a different Registration ID or press GO to edit that student.',
        );
      }
      // Multi-device safety: manual IDs >= 100000 must stay inside this
      // device's allocated node block (LWW on out-of-block IDs destroys
      // another device's record on next sync).
      if (requested >= 100000 && !editingExisting) {
        final nodeRows = await txn.rawQuery(
          "SELECT node_block_start, node_block_end FROM _sync_state "
          "WHERE table_name = '__node__' LIMIT 1",
        );
        if (nodeRows.isNotEmpty) {
          final start =
              (nodeRows.first['node_block_start'] as num?)?.toInt() ?? 100000;
          final end =
              (nodeRows.first['node_block_end'] as num?)?.toInt() ?? 199999;
          if (requested < start || requested > end) {
            throw StateError(
              'Registration ID $requested lies outside this device\'s offline '
              'node block ($start-$end). Use an ID below 100000 (shared '
              'physical register) or within this device\'s own block — '
              'cross-block IDs corrupt multi-device sync.',
            );
          }
        }
      }
      nextStuRegId = requested;
    } else {
      nextStuRegId = await NodeIdAllocator.allocateInTransaction(
        txn,
        tableName: 'Stu_Reg',
        pkColumn: 'Stu_RegID',
      );
    }

    // 2. Compute nextRollNo for Class & Section in resolved session
    int nextRollNo = 1;
    if (draft.admInClass != null) {
      final secId = draft.classSecId ?? 25;
      final maxRollResult = await txn.rawQuery(
        '''
        SELECT COALESCE(MAX(ClassRollNo), 0) + 1 as nextRoll
        FROM Student_Class
        WHERE ClassID = ? AND ClassSecID = ? AND SessionYr = ?
      ''',
        [draft.admInClass, secId, resolvedSession],
      );
      nextRollNo = (maxRollResult.first['nextRoll'] as int?) ?? 1;
    }

    // 3. Handle photo copy if photoPath is provided
    String? finalPhotoPath;
    if (draft.photoPath != null && draft.photoPath!.isNotEmpty) {
      finalPhotoPath = await PhotoRepository().copyForStudent(
        nextStuRegId,
        draft.photoPath!,
      );
    }

    // 4. Format ISO dates
    final dobIso = draft.dob != null
        ? DateFormat('yyyy-MM-dd').format(draft.dob!)
        : null;
    final doAdmIso = DateFormat('yyyy-MM-dd').format(draft.doAdmission);

    // 5. Insert into Stu_Reg (32 columns, verbatim column Remarls preserved)
    //    or update the existing row when editing via [GO] lookup.
    final regRow = <String, dynamic>{
      'Stu_RegID': nextStuRegId,
      'NameFirst': draft.nameFirst.trim(),
      'NameMiddle': draft.nameMiddle.trim().isEmpty
          ? null
          : draft.nameMiddle.trim(),
      'NameLast': draft.nameLast.trim().isEmpty ? null : draft.nameLast.trim(),
      'DOB': dobIso,
      'B_Form_No': draft.bFormNo == null || draft.bFormNo!.trim().isEmpty
          ? null
          : draft.bFormNo!.trim(),
      'F_Name': draft.fName.trim(),
      'CNIC_No': draft.cnicNo.trim(),
      'Occupation': draft.occupation == null || draft.occupation!.trim().isEmpty
          ? null
          : draft.occupation!.trim(),
      'P_Address': draft.pAddress == null || draft.pAddress!.trim().isEmpty
          ? null
          : draft.pAddress!.trim(),
      'T_Address': draft.tAddress == null || draft.tAddress!.trim().isEmpty
          ? null
          : draft.tAddress!.trim(),
      'Phone_Office': null,
      'Phone_Res': null,
      'Mobile1': draft.mobile1.trim(),
      'Mobile2': draft.mobile2 == null || draft.mobile2!.trim().isEmpty
          ? null
          : draft.mobile2!.trim(),
      'Religion': draft.religion ?? 'Islam',
      'P_School': draft.pSchool == null || draft.pSchool!.trim().isEmpty
          ? null
          : draft.pSchool!.trim(),
      'SLCertificate':
          draft.slCertificate == null || draft.slCertificate!.trim().isEmpty
          ? null
          : draft.slCertificate!.trim(),
      'P_Class': draft.pClass == null || draft.pClass!.trim().isEmpty
          ? null
          : draft.pClass!.trim(),
      'AdmInClass': draft.admInClass,
      'AdmClass': draft.admClass ?? draft.admInClass,
      'DOAdmission': doAdmIso,
      'DocsDetail': null,
      'Discount': draft.discount,
      'EmerContName':
          draft.emerContName == null || draft.emerContName!.trim().isEmpty
          ? null
          : draft.emerContName!.trim(),
      'EmerContMobile':
          draft.emerContMobile == null || draft.emerContMobile!.trim().isEmpty
          ? null
          : draft.emerContMobile!.trim(),
      'OfficeFile': null,
      'Remarls': draft.remarks == null || draft.remarks!.trim().isEmpty
          ? null
          : draft.remarks!.trim(),
      'VMDiscount': draft.vmDiscount,
      'FullDiscount': draft.fullDiscount ? 1 : 0,
      'Nationality': draft.nationality ?? 'Pakistani',
      'Sex': draft.gender ?? 'Male',
      'photo_path': finalPhotoPath,
    };

    if (editingExisting) {
      // Preserve the existing photo when the edit did not choose a new one.
      if (finalPhotoPath == null) regRow.remove('photo_path');
      regRow.remove('Stu_RegID');
      await txn.update(
        'Stu_Reg',
        regRow,
        where: 'Stu_RegID = ?',
        whereArgs: [nextStuRegId],
      );
    } else {
      await txn.insert('Stu_Reg', regRow);
    }

    // 6. Insert into Student_Class (or update the active enrollment on edit)
    if (draft.admInClass != null) {
      if (editingExisting) {
        final activeEnroll = await txn.rawQuery(
          'SELECT 1 FROM Student_Class '
          "WHERE Stu_RegID = ? AND Present = 1 LIMIT 1",
          [nextStuRegId],
        );
        if (activeEnroll.isNotEmpty) {
          await txn.update(
            'Student_Class',
            {
              'ClassID': draft.admInClass,
              'ClassSecID': draft.classSecId ?? 25,
            },
            where: 'Stu_RegID = ? AND Present = 1',
            whereArgs: [nextStuRegId],
          );
        } else {
          await txn.insert('Student_Class', {
            'Stu_RegID': nextStuRegId,
            'ClassID': draft.admInClass,
            'ClassSecID': draft.classSecId ?? 25,
            'ClassRollNo': nextRollNo,
            'SessionYr': resolvedSession,
            'Present': 1,
            'PassingMarks': null,
            'PromotionDate': null,
            'VGen': 'Y',
          });
        }
      } else {
        await txn.insert('Student_Class', {
          'Stu_RegID': nextStuRegId,
          'ClassID': draft.admInClass,
          'ClassSecID': draft.classSecId ?? 25,
          'ClassRollNo': nextRollNo,
          'SessionYr': resolvedSession,
          'Present': 1,
          'PassingMarks': null,
          'PromotionDate': null,
          'VGen': 'Y',
        });
      }
    }

    // Persist deferred sibling links from the wizard
    for (final siblingId in draft.pendingSiblingIds) {
      if (nextStuRegId == siblingId) continue;
      final lo = nextStuRegId < siblingId ? nextStuRegId : siblingId;
      final hi = nextStuRegId < siblingId ? siblingId : nextStuRegId;
      final linkId = await NodeIdAllocator.allocateInTransaction(
        txn,
        tableName: 'Sibling_Links',
        pkColumn: 'LinkID',
      );
      await txn.rawInsert(
        'INSERT OR IGNORE INTO Sibling_Links '
        '(LinkID, Stu1_RegID, Stu2_RegID, Relation, LinkedBy, LinkedOn) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [linkId, lo, hi, 'sibling', null, DateTime.now().toIso8601String()],
      );
    }

    return nextStuRegId;
  });
}

/// Function signature for submitting student admission to SQLite.
typedef StudentAdmissionSubmitter = Future<int> Function(
  WizardDraft draft, {
  String? sessionYr,
});

/// Riverpod provider delivering the admission submission function.
final studentAdmissionSubmitterProvider = Provider<StudentAdmissionSubmitter>((
  ref,
) {
  return (draft, {String? sessionYr}) =>
      submitStudentAdmission(draft, sessionYr: sessionYr);
});
