import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/leaving_student_row.dart';
import '../db/database.dart';
import 'clock_provider.dart';

@immutable
class SchoolLeavingState {
  final List<LeavingStudentRow> students;
  final LeavingStudentRow? selectedStudent;
  final double outstandingDues;
  final int overdueMonths;
  final bool duesComputed;
  final DateTime leavingDate;
  final String? reason;
  final String? conduct;
  final String remarks;
  final bool loading;
  final bool committing;
  final String? errorMessage;
  final String? toast;
  final Map<String, dynamic>? committedSlc;
  /// Shot 3d: admin Edit SLC mode — unlocks the leaving setters for an
  /// existing SchLeaving record (the screen drives this via setEditingSlc).
  final bool editingSlc;
  /// Shot 3d: DB-enriched certificate particulars for the selected student
  /// (dob, address, admittedClass, leftClass, duesPaidUpTo) — the source the
  /// screen uses to pre-populate its editable certificate controllers.
  final Map<String, String> certificateFields;

  const SchoolLeavingState({
    this.students = const [],
    this.selectedStudent,
    this.outstandingDues = 0.0,
    this.overdueMonths = 0,
    this.duesComputed = false,
    required this.leavingDate,
    this.reason = 'Leaving',
    this.conduct = 'Good ',
    this.remarks = '',
    this.loading = false,
    this.committing = false,
    this.errorMessage,
    this.toast,
    this.committedSlc,
    this.editingSlc = false,
    this.certificateFields = const {},
  });

  bool get hasExistingSlc => selectedStudent?.hasExistingSlc ?? false;
  bool get hasDues => outstandingDues > 0;
  bool get isFormEditable =>
      selectedStudent != null &&
      !hasExistingSlc &&
      committedSlc == null &&
      !hasDues;

  /// Shot 3d: normalize legacy SchLeaving.Charactor values
  /// case-insensitively ('satisfactory' -> 'Satisfactory', 'bad' -> 'Bad');
  /// empty or unrecognized values default to 'Good'. The raw state value
  /// (e.g. the DB's 'Good ') is preserved — this is only for radio matching
  /// and display.
  static String normalizeConduct(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'satisfactory':
        return 'Satisfactory';
      case 'bad':
        return 'Bad';
      default:
        return 'Good';
    }
  }

  SchoolLeavingState copyWith({
    List<LeavingStudentRow>? students,
    LeavingStudentRow? Function()? selectedStudent,
    double? outstandingDues,
    int? overdueMonths,
    bool? duesComputed,
    DateTime? leavingDate,
    String? Function()? reason,
    String? Function()? conduct,
    String? remarks,
    bool? loading,
    bool? committing,
    String? Function()? errorMessage,
    String? Function()? toast,
    Map<String, dynamic>? Function()? committedSlc,
    bool? editingSlc,
    Map<String, String>? certificateFields,
  }) {
    return SchoolLeavingState(
      students: students ?? this.students,
      selectedStudent: selectedStudent != null
          ? selectedStudent()
          : this.selectedStudent,
      outstandingDues: outstandingDues ?? this.outstandingDues,
      overdueMonths: overdueMonths ?? this.overdueMonths,
      duesComputed: duesComputed ?? this.duesComputed,
      leavingDate: leavingDate ?? this.leavingDate,
      reason: reason != null ? reason() : this.reason,
      conduct: conduct != null ? conduct() : this.conduct,
      remarks: remarks ?? this.remarks,
      loading: loading ?? this.loading,
      committing: committing ?? this.committing,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      toast: toast != null ? toast() : this.toast,
      committedSlc: committedSlc != null ? committedSlc() : this.committedSlc,
      editingSlc: editingSlc ?? this.editingSlc,
      certificateFields: certificateFields ?? this.certificateFields,
    );
  }
}

class SchoolLeavingNotifier extends StateNotifier<SchoolLeavingState> {
  final Ref? _ref;

  Future<void>? _loadingFuture;

  /// Shot 3g fix 2: certificate particulars the admin edited via
  /// Edit SLC -> Update SLC Record, kept per Stu_RegID so
  /// loadInitialData / computeCertificateFields ALWAYS honor the edited
  /// values during the session (even where the schema cannot store them).
  final Map<int, Map<String, String>> _savedCertOverrides = {};

  SchoolLeavingNotifier([Ref? ref])
    : _ref = ref,
      super(
        SchoolLeavingState(
          leavingDate: ref?.read(clockProvider)() ?? DateTime.now(),
        ),
      ) {
    loadInitialData();
  }

  DateTime _now() => _ref?.read(clockProvider)() ?? DateTime.now();

  Future<void> loadInitialData() {
    if (_loadingFuture != null) return _loadingFuture!;
    final future = _loadInitialDataInternal();
    _loadingFuture = future;
    return future;
  }

  Future<void> _loadInitialDataInternal() async {
    if (!mounted) return;
    state = state.copyWith(loading: true, errorMessage: () => null);

    try {
      final db = await DatabaseService.instance.database;

      final rows = await db.rawQuery('''
        SELECT sr.Stu_RegID, sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name, sr.DOAdmission,
               sc.ClassID, sc.ClassSecID, sc.SessionYr, sc.Present,
               COALESCE(sl.LeftClass, sc.ClassID) AS EffectiveClassID,
               COALESCE(
                 cLeft.CName,
                 c.CName,
                 (SELECT c2.CName FROM Student_Class sc2 JOIN Class c2 ON c2.ClassID = sc2.ClassID WHERE sc2.Stu_RegID = sr.Stu_RegID AND c2.CName IS NOT NULL ORDER BY sc2.Present DESC, sc2.SessionYr DESC LIMIT 1)
               ) AS CName,
               cs.SecName,
               sl.SLID, sl.LeftDate, sl.Charactor, sl.TermOfLeavign, sl.Remarks AS slRemarks
        FROM Stu_Reg sr
        LEFT JOIN Student_Class sc ON sc.Stu_RegID = sr.Stu_RegID
        LEFT JOIN Class c ON c.ClassID = sc.ClassID
        LEFT JOIN ClassSec cs ON cs.ClassSecID = sc.ClassSecID
        LEFT JOIN SchLeaving sl ON sl.StuRegID = sr.Stu_RegID
        LEFT JOIN Class cLeft ON cLeft.ClassID = sl.LeftClass
        ORDER BY sr.Stu_RegID ASC, sc.Present DESC, sc.SessionYr DESC
        ''');

      final seenStuRegIds = <int>{};
      final list = <LeavingStudentRow>[];

      for (final r in rows) {
        final regId = r['Stu_RegID'] as int;
        if (seenStuRegIds.contains(regId)) continue;
        seenStuRegIds.add(regId);

        final slid = (r['SLID'] as num?)?.toInt();
        final hasSlc = slid != null;

        list.add(
          LeavingStudentRow(
            stuRegId: regId,
            nameFirst: (r['NameFirst'] as String?)?.trim() ?? '',
            nameMiddle: (r['NameMiddle'] as String?)?.trim(),
            nameLast: (r['NameLast'] as String?)?.trim(),
            fatherName: (r['F_Name'] as String?)?.trim(),
            className: _effectiveClassName(
              (r['CName'] as String?)?.trim(),
              (r['slRemarks'] as String?)?.trim(),
              regId,
            ),
            sectionName: (r['SecName'] as String?)?.trim(),
            classId: (r['EffectiveClassID'] as num?)?.toInt(),
            classSecId: (r['ClassSecID'] as num?)?.toInt(),
            sessionYr: (r['SessionYr'] as String?)?.trim(),
            admissionDate: (r['DOAdmission'] as String?)?.trim(),
            present: (r['Present'] as num?)?.toInt() ?? 0,
            hasExistingSlc: hasSlc,
            existingSlcDate: (r['LeftDate'] as String?)?.trim(),
            existingSlcTerm: (r['TermOfLeavign'] as String?)?.trim(),
            existingSlcConduct: (r['Charactor'] as String?),
            existingSlcRemarks: (r['slRemarks'] as String?)?.trim(),
            existingSlcSlid: slid,
          ),
        );
      }

      if (!mounted) return;
      state = state.copyWith(students: list, loading: false);

      // Re-synchronize selected student if any
      if (state.selectedStudent != null) {
        final updatedSelected = list.firstWhere(
          (s) => s.stuRegId == state.selectedStudent!.stuRegId,
          orElse: () => state.selectedStudent!,
        );
        state = state.copyWith(selectedStudent: () => updatedSelected);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: () => 'Failed to load students: $e',
      );
    } finally {
      _loadingFuture = null;
    }
  }

  Future<void> selectStudent(int? stuRegId) async {
    if (!mounted) return;
    if (stuRegId == null) {
      state = state.copyWith(
        selectedStudent: () => null,
        outstandingDues: 0.0,
        overdueMonths: 0,
        duesComputed: false,
        reason: () => 'Leaving',
        conduct: () => 'Good ',
        remarks: '',
        committedSlc: () => null,
      );
      return;
    }

    if (state.students.isEmpty) {
      await loadInitialData();
      if (!mounted) return;
    }

    final student = state.students.firstWhere(
      (s) => s.stuRegId == stuRegId,
      orElse: () =>
          LeavingStudentRow(stuRegId: stuRegId, nameFirst: 'Student $stuRegId'),
    );

    DateTime initialDate = _now();
    String? initialReason = 'Leaving';
    String? initialConduct = 'Good ';
    String initialRemarks = '';

    if (student.hasExistingSlc) {
      if (student.existingSlcDate != null) {
        final parsed = DateTime.tryParse(student.existingSlcDate!);
        if (parsed != null) initialDate = parsed;
      }
      initialReason = student.existingSlcTerm ?? 'Leaving';
      initialConduct = student.existingSlcConduct ?? 'Good ';
      initialRemarks = student.existingSlcRemarks ?? '';
    }

    if (!mounted) return;
    state = state.copyWith(
      selectedStudent: () => student,
      leavingDate: initialDate,
      reason: () => initialReason,
      conduct: () => initialConduct,
      remarks: initialRemarks,
      committedSlc: () => null,
      certificateFields: const {},
    );

    await computeDues(stuRegId);
    // Shot 3d: also enrich the editable certificate particulars (DOB,
    // address, admitted/leaving class, dues-paid month) for the screen.
    if (!mounted) return;
    await computeCertificateFields(stuRegId);
  }

  Future<void> refreshSelectedStudent() async {
    final id = state.selectedStudent?.stuRegId;
    if (id == null) return;
    _loadingFuture = null;
    await loadInitialData();
    if (!mounted) return;
    await computeDues(id);
  }

  Future<void> computeDues(int stuRegId) async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(vm.SubTotal - vm.Discount - COALESCE(vm.PaidAmt, 0)), 0) AS totalDues,
               COUNT(DISTINCT CASE WHEN (vm.SubTotal - vm.Discount - COALESCE(vm.PaidAmt, 0)) > 0 THEN vm.ForMonth END) AS overdueMonths
        FROM VoucharMas vm
        WHERE vm.Student_Class_StuRegID = ?
          AND vm.IsPaid = 'N'
        ''',
        [stuRegId],
      );

      double dues = 0.0;
      int months = 0;

      if (rows.isNotEmpty) {
        dues = (rows.first['totalDues'] as num?)?.toDouble() ?? 0.0;
        months = (rows.first['overdueMonths'] as num?)?.toInt() ?? 0;
      }

      if (!mounted) return;
      state = state.copyWith(
        outstandingDues: dues,
        overdueMonths: months,
        duesComputed: true,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        outstandingDues: 0.0,
        overdueMonths: 0,
        duesComputed: true,
        errorMessage: () => 'Failed to calculate dues: $e',
      );
    }
  }

  /// Shot 3d: best-effort DB enrichment for the editable certificate
  /// particulars (DOB, address, admitted class, class at leaving, latest
  /// paid voucher month for 'Dues Paid up to'). Failures never block the
  /// workflow — the certificate prints with what is available.
  Future<void> computeCertificateFields(int stuRegId) async {
    try {
      final db = await DatabaseService.instance.database;

      String dob = '';
      String address = '';
      String admittedClassName = '';
      String leftClassName = '';
      String duesPaidUpTo = '';
      String admissionDate = '';

      final stuRows = await db.rawQuery(
        '''
        SELECT sr.DOB, sr.P_Address, sr.T_Address, sr.AdmInClass, sr.AdmClass, sr.DOAdmission,
               cIn.CName AS admittedCName
        FROM Stu_Reg sr
        LEFT JOIN Class cIn ON cIn.ClassID = COALESCE(sr.AdmInClass, sr.AdmClass)
        WHERE sr.Stu_RegID = ?
        ''',
        [stuRegId],
      );
      if (stuRows.isNotEmpty) {
        final row = stuRows.first;
        dob = (row['DOB'] as String?)?.trim() ?? '';
        admissionDate = (row['DOAdmission'] as String?)?.trim() ?? '';
        final pAddress = (row['P_Address'] as String?)?.trim() ?? '';
        final tAddress = (row['T_Address'] as String?)?.trim() ?? '';
        address = pAddress.isNotEmpty ? pAddress : tAddress;
        admittedClassName = (row['admittedCName'] as String?)?.trim() ?? '';
      }

      final classId = state.selectedStudent?.stuRegId == stuRegId
          ? state.selectedStudent?.classId
          : null;

      // Shot 3h: SchLeaving.LeftClass is the source of truth for any student
      // with an existing SLC record — read it first, before the enrollment
      // (Student_Class) and remarks fallbacks.
      final slcLeftRows = await db.rawQuery(
        '''
        SELECT cLeft.CName AS leftCName
        FROM SchLeaving sl
        LEFT JOIN Class cLeft ON cLeft.ClassID = sl.LeftClass
        WHERE sl.StuRegID = ?
        LIMIT 1
        ''',
        [stuRegId],
      );
      if (slcLeftRows.isNotEmpty) {
        final slcLeft = (slcLeftRows.first['leftCName'] as String?)?.trim() ?? '';
        if (slcLeft.isNotEmpty) leftClassName = slcLeft;
      }

      if (leftClassName.isEmpty && classId != null) {
        final leftRows = await db.rawQuery(
          'SELECT CName FROM Class WHERE ClassID = ? LIMIT 1',
          [classId],
        );
        if (leftRows.isNotEmpty) {
          leftClassName = (leftRows.first['CName'] as String?)?.trim() ?? '';
        }
      }

      // Shot 3g fix 1: alumni whose Student_Class rows carry no Class name
      // still get a leaving class inferred from the SLC remarks.
      if (leftClassName.isEmpty &&
          state.selectedStudent?.stuRegId == stuRegId) {
        leftClassName =
            inferClassFromRemarks(state.selectedStudent?.existingSlcRemarks) ??
            '';
      }

      final paidRows = await db.rawQuery(
        '''
        SELECT ForMonth FROM VoucharMas
        WHERE Student_Class_StuRegID = ? AND IsPaid = 'Y'
        ORDER BY VoucherMasID DESC
        LIMIT 1
        ''',
        [stuRegId],
      );
      if (paidRows.isNotEmpty) {
        duesPaidUpTo = (paidRows.first['ForMonth'] as String?)?.trim() ?? '';
      }

      if (!mounted) return;
      if (state.selectedStudent?.stuRegId != stuRegId) return;

      // Shot 3g fix 2: the admin's saved edits always win over the DB values.
      final overrides = _savedCertOverrides[stuRegId] ??
          const <String, String>{};
      String pick(String dbValue, String key) {
        final o = (overrides[key] ?? '').trim();
        return o.isNotEmpty ? o : dbValue;
      }

      state = state.copyWith(
        certificateFields: {
          'dob': pick(dob, 'dob'),
          'admissionDate': pick(admissionDate, 'admissionDate'),
          'address': pick(address, 'address'),
          'admittedClass': pick(admittedClassName, 'admittedClass'),
          'leftClass': pick(leftClassName, 'leftClass'),
          'duesPaidUpTo': pick(duesPaidUpTo, 'duesPaidUpTo'),
        },
      );
    } catch (_) {
      // Enrichment is best-effort — keep whatever the screen already has.
    }
  }

  /// Shot 3g fix 1: resolve the class shown for a student. When the
  /// active-session enrollment has no Class name (alumni like 3545 show
  /// 'Class: Unassigned'), fall back to the historical Student_Class class
  /// (via the SQL subquery), then to the SLC remarks ('Passing out from
  /// 8 class ...'), and finally to the admin's saved override.
  String? _effectiveClassName(
    String? dbClassName,
    String? slcRemarks,
    int stuRegId,
  ) {
    var name = (dbClassName ?? '').trim();
    if (name.isEmpty || name.toLowerCase() == 'unassigned') {
      name = inferClassFromRemarks(slcRemarks) ?? '';
    }
    final override = (_savedCertOverrides[stuRegId]?['leftClass'] ?? '').trim();
    if (override.isNotEmpty) return override;
    return name.isEmpty ? null : name;
  }

  static const Map<String, String> _numberWordByDigit = {
    '1': 'One',
    '2': 'Two',
    '3': 'Three',
    '4': 'Four',
    '5': 'Five',
    '6': 'Six',
    '7': 'Seven',
    '8': 'Eight',
    '9': 'Nine',
    '10': 'Ten',
  };

  static const Map<String, String> _digitByNumberWord = {
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
  };

  /// Shot 3g fix 1: infer the class a student was in when they left from
  /// free-text SLC remarks like 'Passing out from 8 class . 718.5 / 850'.
  /// Recognizes 'from 8 class', '8 class', 'class 8', '8th class', word
  /// forms ('eight class') and the early-years names. Returns the class
  /// word ('Eight') or null when nothing can be inferred.
  static String? inferClassFromRemarks(String? remarks) {
    final raw = (remarks ?? '').trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();

    if (lower.contains('play group') || lower.contains('playgroup')) {
      return 'Play Group';
    }
    if (lower.contains('nursery')) return 'Nursery';
    if (lower.contains('prep')) return 'Prep';

    final digitMatch =
        RegExp(r'(\d{1,2})\s*(?:st|nd|rd|th)?\s*class').firstMatch(lower) ??
        RegExp(r'class\s*(\d{1,2})\s*(?:st|nd|rd|th)?').firstMatch(lower);
    if (digitMatch != null) {
      final n = int.tryParse(digitMatch.group(1)!);
      if (n != null && n >= 1 && n <= 10) return _numberWordByDigit['$n'];
    }

    for (final entry in _digitByNumberWord.entries) {
      if (RegExp('${entry.key}\\s*class|class\\s*${entry.key}')
          .hasMatch(lower)) {
        return _numberWordByDigit[entry.value];
      }
    }
    return null;
  }

  /// Shot 3g fix 2: resolve a free-text class label ('Class 8', '8',
  /// '8th', 'Eight') onto a Class row ClassID, or null when nothing matches.
  Future<int?> _lookupClassId(dynamic db, String label) async {
    final raw = label.trim();
    if (raw.isEmpty) return null;
    var bare = raw.toLowerCase();
    if (bare.startsWith('class ')) bare = bare.substring(6).trim();
    bare = bare.replaceFirst(RegExp(r'(st|nd|rd|th)$'), '').trim();

    final candidates = <String>{raw, bare};
    final digit = _digitByNumberWord[bare] ?? int.tryParse(bare)?.toString();
    if (digit != null) {
      candidates
        ..add('Class $digit')
        ..add(_numberWordByDigit[digit] ?? digit);
    } else if (bare.isNotEmpty) {
      candidates.add(bare[0].toUpperCase() + bare.substring(1));
    }

    for (final candidate in candidates) {
      final rows = await db.rawQuery(
        'SELECT ClassID FROM Class WHERE LOWER(TRIM(CName)) = LOWER(?) LIMIT 1',
        [candidate],
      );
      if (rows.isNotEmpty) {
        return (rows.first['ClassID'] as num?)?.toInt();
      }
    }
    return null;
  }

  /// Shot 3g fix 2: normalize an on-screen date ('05-Sep-2010', ISO strings)
  /// to the DB's yyyy-MM-dd form; null when empty/unparseable.
  static String? _toDbDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t == '-') return null;
    final dt = DateFormat('dd-MMM-yyyy').tryParseLoose(t) ?? DateTime.tryParse(t);
    if (dt != null) return DateFormat('yyyy-MM-dd').format(dt);
    return t;
  }

  /// Shot 3g fix 2: persist every edited certificate particular for an
  /// existing SLC record (Edit SLC -> Update SLC Record). Identity fields go
  /// to Stu_Reg, the leaving fields to the SchLeaving row, and the Class at
  /// Leaving is written back onto the student's most recent Student_Class
  /// row when a matching Class exists. All edited values are also kept
  /// in-memory so loadInitialData / computeCertificateFields keep honoring
  /// them during the session even when the schema cannot represent them.
  Future<(bool, String)> updateSlcRecord({
    required int stuRegId,
    String? studentName,
    String? fatherName,
    String? address,
    String? dob,
    String? admissionDate,
    String? classAdmitted,
    String? classAtLeaving,
    String? duesPaidUpTo,
  }) async {
    try {
      final db = await DatabaseService.instance.database;

      final name = (studentName ?? '').trim();
      final father = (fatherName ?? '').trim();
      final addr = (address ?? '').trim();
      final dobRaw = (dob ?? '').trim();
      final admRaw = (admissionDate ?? '').trim();
      final admitted = (classAdmitted ?? '').trim();
      final leaving = (classAtLeaving ?? '').trim();
      final dues = (duesPaidUpTo ?? '').trim();

      // 1. Stu_Reg identity + particulars.
      final stuUpdate = <String, dynamic>{};
      if (name.isNotEmpty) {
        final parts = name.split(RegExp(r'\s+'));
        stuUpdate['NameFirst'] = parts.first;
        stuUpdate['NameMiddle'] = parts.length > 2
            ? parts.sublist(1, parts.length - 1).join(' ')
            : null;
        stuUpdate['NameLast'] = parts.length > 1 ? parts.last : null;
      }
      if (father.isNotEmpty) stuUpdate['F_Name'] = father;
      if (addr.isNotEmpty) {
        stuUpdate['P_Address'] = addr;
        stuUpdate['T_Address'] = addr;
      }
      final dobDb = _toDbDate(dobRaw);
      if (dobDb != null) stuUpdate['DOB'] = dobDb;
      final admDb = _toDbDate(admRaw);
      if (admDb != null) stuUpdate['DOAdmission'] = admDb;
      if (admitted.isNotEmpty) {
        final admittedId = await _lookupClassId(db, admitted);
        if (admittedId != null) stuUpdate['AdmInClass'] = admittedId;
      }
      if (stuUpdate.isNotEmpty) {
        await db.update(
          'Stu_Reg',
          stuUpdate,
          where: 'Stu_RegID = ?',
          whereArgs: [stuRegId],
        );
      }

      // 2. Class at Leaving -> resolve to a ClassID. Shot 3h: persist it to
      // SchLeaving.LeftClass (the source of truth for alumni) and also onto
      // the student's most recent Student_Class row.
      int? resolvedLeftClassId;
      if (leaving.isNotEmpty) {
        resolvedLeftClassId = await _lookupClassId(db, leaving);
        if (resolvedLeftClassId != null) {
          await db.rawUpdate(
            '''
            UPDATE Student_Class
            SET ClassID = ?
            WHERE rowid IN (
              SELECT rowid FROM Student_Class
              WHERE Stu_RegID = ?
              ORDER BY Present DESC, SessionYr DESC
              LIMIT 1
            )
            ''',
            [resolvedLeftClassId, stuRegId],
          );
        }
      }

      // 3. Leaving fields onto the existing SchLeaving row (if any). Shot 3h:
      // the edited Class at Leaving persists permanently in
      // SchLeaving.LeftClass.
      await db.update(
        'SchLeaving',
        {
          'LeftDate': DateFormat('yyyy-MM-dd').format(state.leavingDate),
          'Charactor': (state.conduct ?? 'Good ').trim().isEmpty
              ? 'Good'
              : state.conduct!.trim(),
          'TermOfLeavign': (state.reason ?? '').trim(),
          'Remarks': state.remarks.trim().isEmpty ? null : state.remarks.trim(),
          if (resolvedLeftClassId != null) 'LeftClass': resolvedLeftClassId,
        },
        where: 'StuRegID = ?',
        whereArgs: [stuRegId],
      );

      // 4. Remember the admin's edits for the rest of the session.
      final overrides = <String, String>{
        if (name.isNotEmpty) 'studentName': name,
        if (father.isNotEmpty) 'fatherName': father,
        if (addr.isNotEmpty) 'address': addr,
        if (dobRaw.isNotEmpty) 'dob': dobRaw,
        if (admRaw.isNotEmpty) 'admissionDate': admRaw,
        if (admitted.isNotEmpty) 'admittedClass': admitted,
        if (leaving.isNotEmpty) 'leftClass': leaving,
        if (dues.isNotEmpty) 'duesPaidUpTo': dues,
      };
      if (overrides.isNotEmpty) {
        _savedCertOverrides[stuRegId] = {
          ...?_savedCertOverrides[stuRegId],
          ...overrides,
        };
      }

      // 5. Reload and re-apply so the screen never reverts the edited values
      // (e.g. 'Class at Leaving' back to 'Unassigned').
      _loadingFuture = null;
      await loadInitialData();
      if (!mounted) return (true, 'SLC record updated.');
      await computeDues(stuRegId);
      if (!mounted) return (true, 'SLC record updated.');
      await computeCertificateFields(stuRegId);
      if (!mounted) return (true, 'SLC record updated.');

      if (leaving.isNotEmpty) {
        final selected = state.selectedStudent;
        if (selected != null && selected.stuRegId == stuRegId) {
          state = state.copyWith(
            selectedStudent: () => selected.copyWith(
              className: leaving,
              classId: resolvedLeftClassId ?? selected.classId,
            ),
          );
        }
      }
      return (true, 'SLC record updated for $stuRegId.');
    } catch (e) {
      final msg = 'Failed to update SLC record: $e';
      if (!mounted) return (false, msg);
      state = state.copyWith(errorMessage: () => msg);
      return (false, msg);
    }
  }

  void setEditingSlc(bool editing) {
    state = state.copyWith(editingSlc: editing);
  }

  void setLeavingDate(DateTime date) {
    if (!_canEditLeavingFields) return;
    state = state.copyWith(leavingDate: date);
  }

  void setTodayDate() {
    if (!_canEditLeavingFields) return;
    state = state.copyWith(leavingDate: _now());
  }

  void setReason(String? reason) {
    if (!_canEditLeavingFields) return;
    state = state.copyWith(reason: () => reason);
  }

  void setConduct(String? conduct) {
    if (!_canEditLeavingFields) return;
    state = state.copyWith(conduct: () => conduct);
  }

  void setRemarks(String remarks) {
    if (!_canEditLeavingFields) return;
    state = state.copyWith(remarks: remarks);
  }

  /// Shot 3d: leaving fields are editable for a NEW SLC or while the admin
  /// Edit SLC mode is active. Previously the setters silently no-op'd for
  /// existing SLC records even when the screen's Edit SLC toggle was on —
  /// which is why Character & Conduct taps never updated state.
  bool get _canEditLeavingFields =>
      state.isFormEditable || state.editingSlc;

  void clearMessages() {
    state = state.copyWith(errorMessage: () => null, toast: () => null);
  }

  (bool, String?) canCommit() {
    if (state.selectedStudent == null) {
      return (false, 'Select Student First');
    }
    if (state.hasExistingSlc) {
      return (false, 'A leaving record already exists for this student.');
    }
    if (state.outstandingDues > 0) {
      final duesStr = state.outstandingDues.toStringAsFixed(0);
      return (
        false,
        'Student has out standing dues Rs. $duesStr for ${state.overdueMonths} Months. Must pay before left',
      );
    }
    return (true, null);
  }

  Future<(bool, String)> commitLeaving() async {
    final (valid, err) = canCommit();
    if (!valid) {
      final msg = err ?? 'Validation failed';
      state = state.copyWith(errorMessage: () => msg);
      return (false, msg);
    }

    final student = state.selectedStudent!;
    state = state.copyWith(committing: true, errorMessage: () => null);

    try {
      final db = await DatabaseService.instance.database;
      final dateStr = DateFormat('yyyy-MM-dd').format(state.leavingDate);
      int createdSlid = 1;

      await db.transaction((txn) async {
        // 1. Deactivate student enrollment
        await txn.rawUpdate(
          '''
          UPDATE Student_Class
          SET Present = 0
          WHERE Stu_RegID = ?
          ''',
          [student.stuRegId],
        );

        // 2. Insert into SchLeaving
        final nextSlid =
            ((await txn.rawQuery(
                      'SELECT COALESCE(MAX(SLID), 0) + 1 AS nextId FROM SchLeaving',
                    )).first['nextId']
                    as num?)
                ?.toInt() ??
            1;
        createdSlid = nextSlid;

        await txn.rawInsert(
          '''
          INSERT INTO SchLeaving (
            SLID, StuRegID, LeftDate, LeftClass, Charactor, TermOfLeavign, SLCertificate, Remarks
          ) VALUES (?, ?, ?, ?, ?, ?, 1, ?)
          ''',
          [
            nextSlid,
            student.stuRegId,
            dateStr,
            student.classId ?? 0,
            state.conduct ?? 'Good ',
            state.reason ?? 'Leaving',
            state.remarks.trim().isEmpty ? null : state.remarks.trim(),
          ],
        );
      });

      final committedMap = {
        'SLID': createdSlid,
        'LeftDate': dateStr,
        'TermOfLeavign': state.reason,
        'Charactor': state.conduct,
        'Remarks': state.remarks,
      };

      final toastMsg =
          'School leaving recorded for ${student.stuRegId} - ${student.studentName}. Enrollment deactivated.';

      if (!mounted) return (true, toastMsg);
      state = state.copyWith(
        committing: false,
        toast: () => toastMsg,
        committedSlc: () => committedMap,
      );

      // Reload students list to update flags
      await loadInitialData();

      return (true, toastMsg);
    } catch (e) {
      if (!mounted) return (false, 'Failed to commit school leaving: $e');
      final errorMsg = 'Failed to commit school leaving: $e';
      state = state.copyWith(committing: false, errorMessage: () => errorMsg);
      return (false, errorMsg);
    }
  }
}

final schoolLeavingProvider =
    StateNotifierProvider<SchoolLeavingNotifier, SchoolLeavingState>((ref) {
      return SchoolLeavingNotifier(ref);
    });
