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
  });

  bool get hasExistingSlc => selectedStudent?.hasExistingSlc ?? false;
  bool get hasDues => outstandingDues > 0;
  bool get isFormEditable =>
      selectedStudent != null &&
      !hasExistingSlc &&
      committedSlc == null &&
      !hasDues;

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
    );
  }
}

class SchoolLeavingNotifier extends StateNotifier<SchoolLeavingState> {
  final Ref? _ref;

  Future<void>? _loadingFuture;

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
               c.CName, cs.SecName,
               sl.SLID, sl.LeftDate, sl.Charactor, sl.TermOfLeavign, sl.Remarks AS slRemarks
        FROM Stu_Reg sr
        LEFT JOIN Student_Class sc ON sc.Stu_RegID = sr.Stu_RegID
        LEFT JOIN Class c ON c.ClassID = sc.ClassID
        LEFT JOIN ClassSec cs ON cs.ClassSecID = sc.ClassSecID
        LEFT JOIN SchLeaving sl ON sl.StuRegID = sr.Stu_RegID
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
            className: (r['CName'] as String?)?.trim(),
            sectionName: (r['SecName'] as String?)?.trim(),
            classId: (r['ClassID'] as num?)?.toInt(),
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
    );

    await computeDues(stuRegId);
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

  void setLeavingDate(DateTime date) {
    if (!state.isFormEditable) return;
    state = state.copyWith(leavingDate: date);
  }

  void setTodayDate() {
    if (!state.isFormEditable) return;
    state = state.copyWith(leavingDate: _now());
  }

  void setReason(String? reason) {
    if (!state.isFormEditable) return;
    state = state.copyWith(reason: () => reason);
  }

  void setConduct(String? conduct) {
    if (!state.isFormEditable) return;
    state = state.copyWith(conduct: () => conduct);
  }

  void setRemarks(String remarks) {
    if (!state.isFormEditable) return;
    state = state.copyWith(remarks: remarks);
  }

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
