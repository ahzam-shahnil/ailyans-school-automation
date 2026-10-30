import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/teacher_profile.dart';
import '../../models/teacher_salary_slip.dart';
import '../../models/teacher_subject_assignment.dart';
import '../db/database.dart';

/// State representation for Screen 21 - TeacherProfileScreen (`/staff/teachers/:id` and `/staff/teachers/new`).
/// Implements §S25 (`frmTeachers` at `0x00431fec`, `ObjID: 14`) in edit/detail mode.
class TeacherProfileState {
  final int? teacherId;
  final bool isNew;
  final TeacherProfile? loadedTeacher; // Snapshot baseline for dirty comparison
  final TeacherProfile? draft; // Working edit draft
  final bool isLoading;
  final bool isSaving;
  final bool isEditMode;
  final int activeTab; // 0: Biodata, 1: Subjects, 2: Payroll, 3: Qualifications
  final List<TeacherSubjectAssignment> subjectAssignments;
  final List<TeacherSalarySlip> salarySlips;
  final String? errorMessage;
  final String? toast;
  final Map<String, String> fieldErrors;
  final bool hasAttemptedSave;

  const TeacherProfileState({
    this.teacherId,
    this.isNew = false,
    this.loadedTeacher,
    this.draft,
    this.isLoading = false,
    this.isSaving = false,
    this.isEditMode = false,
    this.activeTab = 0,
    this.subjectAssignments = const [],
    this.salarySlips = const [],
    this.errorMessage,
    this.toast,
    this.fieldErrors = const {},
    this.hasAttemptedSave = false,
  });

  /// Deep comparison: dirty if draft differs from loaded baseline.
  bool get isDirty {
    if (isNew) {
      if (draft == null) return false;
      return draft!.tName.trim().isNotEmpty ||
          draft!.tCnic.trim().isNotEmpty ||
          draft!.tContactNo1.trim().isNotEmpty ||
          (draft!.tFName?.trim().isNotEmpty ?? false) ||
          (draft!.tSubject?.trim().isNotEmpty ?? false) ||
          (draft!.tAddress?.trim().isNotEmpty ?? false) ||
          (draft!.detail?.trim().isNotEmpty ?? false);
    }
    return draft != loadedTeacher;
  }

  /// In create mode: enabled if any required input has text.
  /// In edit mode: enabled strictly when dirty.
  bool get canSave {
    if (isNew) {
      if (draft == null) return false;
      return draft!.tName.trim().isNotEmpty ||
          draft!.tCnic.trim().isNotEmpty ||
          draft!.tContactNo1.trim().isNotEmpty;
    }
    return isEditMode && isDirty;
  }

  /// Current active record to display.
  TeacherProfile? get currentTeacher => isEditMode ? draft : loadedTeacher;

  TeacherProfileState copyWith({
    int? teacherId,
    bool? isNew,
    TeacherProfile? loadedTeacher,
    TeacherProfile? draft,
    bool? isLoading,
    bool? isSaving,
    bool? isEditMode,
    int? activeTab,
    List<TeacherSubjectAssignment>? subjectAssignments,
    List<TeacherSalarySlip>? salarySlips,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? toast,
    bool clearToast = false,
    Map<String, String>? fieldErrors,
    bool? hasAttemptedSave,
  }) {
    return TeacherProfileState(
      teacherId: teacherId ?? this.teacherId,
      isNew: isNew ?? this.isNew,
      loadedTeacher: loadedTeacher ?? this.loadedTeacher,
      draft: draft ?? this.draft,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isEditMode: isEditMode ?? this.isEditMode,
      activeTab: activeTab ?? this.activeTab,
      subjectAssignments: subjectAssignments ?? this.subjectAssignments,
      salarySlips: salarySlips ?? this.salarySlips,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      toast: clearToast ? null : (toast ?? this.toast),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      hasAttemptedSave: hasAttemptedSave ?? this.hasAttemptedSave,
    );
  }
}

/// Notifier managing single employee profile and credential state per §S25.
class TeacherProfileNotifier extends StateNotifier<TeacherProfileState> {
  TeacherProfileNotifier() : super(const TeacherProfileState());

  Future<Database> _getDb() async {
    return DatabaseService.instance.database;
  }

  /// Initializes the provider for either edit (:id) or create (/new) mode.
  Future<void> init(int? teacherId, {int? userLvl}) async {
    if (teacherId != null &&
        state.teacherId == teacherId &&
        state.loadedTeacher != null &&
        !state.isLoading) {
      // Reset to default View mode and Tab 1 on screen entry/re-entry (Bug 5)
      state = state.copyWith(
        isEditMode: false,
        activeTab: 0,
        draft: state.loadedTeacher?.copyWith(),
        fieldErrors: {},
        hasAttemptedSave: false,
      );
      return;
    }
    if (teacherId == null && state.isNew && state.draft != null) {
      return;
    }

    if (teacherId == null) {
      initNewTeacher(userLvl: userLvl);
    } else {
      await loadTeacher(teacherId);
    }
  }

  /// Loads full teacher record, subjects taught, and payroll slips.
  Future<void> loadTeacher(int teacherId) async {
    state = state.copyWith(
      teacherId: teacherId,
      isNew: false,
      isLoading: true,
      clearErrorMessage: true,
      clearToast: true,
    );

    try {
      final db = await _getDb();

      // 1. Fetch teacher record
      final teacherRows = await db.rawQuery(
        'SELECT * FROM Teachers WHERE TeacherID = ?',
        [teacherId],
      );

      if (teacherRows.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Teacher ID #$teacherId not found',
        );
        return;
      }

      final profile = TeacherProfile.fromMap(teacherRows.first);

      // 2. Fetch assigned class subjects (Subj_Class joined with Class and Subject)
      final subjRows = await db.rawQuery(
        '''
        SELECT sc.Subj_ClsID, sc.ClassID, c.CName, sc.SubjID, s.SubjName, sc.TotalMarks, sc.TotalPracticalMarks
        FROM Subj_Class sc
        INNER JOIN Class c ON sc.ClassID = c.ClassID
        INNER JOIN Subject s ON sc.SubjID = s.SubjID
        WHERE sc.TeacherID = ?
        ORDER BY sc.ClassID ASC
      ''',
        [teacherId],
      );
      final assignments = subjRows
          .map((r) => TeacherSubjectAssignment.fromMap(r))
          .toList();

      // 3. Fetch salary slips (TSalMas, pending first, then newest disbursed first)
      final salRows = await db.rawQuery(
        '''
        SELECT TSalMasID, TeacherID, DisbursDate, SalMonth, PaidAmt, TDeductions, Detail, IsPaid, PaidDate
        FROM TSalMas
        WHERE TeacherID = ?
        ORDER BY SUBSTR(TSalMasID, 1, 4) DESC, TSalMasID DESC
      ''',
        [teacherId],
      );
      final slips = salRows.map((r) => TeacherSalarySlip.fromMap(r)).toList();

      state = state.copyWith(
        teacherId: teacherId,
        isNew: false,
        loadedTeacher: profile,
        draft: profile.copyWith(),
        isLoading: false,
        isEditMode: false,
        activeTab: 0,
        subjectAssignments: assignments,
        salarySlips: slips,
        fieldErrors: {},
        hasAttemptedSave: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load teacher dossier: $e',
      );
    }
  }

  /// Initializes create mode with defaults: TCat='Teacher', TIsPresent='Y'.
  void initNewTeacher({int? userLvl}) {
    if (userLvl == 3) {
      state = state.copyWith(
        isNew: true,
        isEditMode: true,
        errorMessage: "You don't have enough rights for purpose",
      );
      return;
    }

    final empty = TeacherProfile.empty();
    state = state.copyWith(
      teacherId: null,
      isNew: true,
      loadedTeacher: null,
      draft: empty,
      isLoading: false,
      isEditMode: true,
      activeTab: 0,
      subjectAssignments: const [],
      salarySlips: const [],
      fieldErrors: {},
      hasAttemptedSave: false,
      clearErrorMessage: true,
      clearToast: true,
    );
  }

  /// Toggles from view mode into edit mode.
  void enterEditMode({int? userLvl}) {
    if (userLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return;
    }
    if (state.loadedTeacher == null) return;
    state = state.copyWith(
      isEditMode: true,
      draft: state.loadedTeacher!.copyWith(),
      clearErrorMessage: true,
      clearToast: true,
      fieldErrors: {},
      hasAttemptedSave: false,
    );
  }

  /// Cancels edits and resets draft back to loaded snapshot.
  void cancelEdits() {
    if (state.isNew) {
      initNewTeacher();
      return;
    }
    state = state.copyWith(
      isEditMode: false,
      draft: state.loadedTeacher?.copyWith(),
      clearErrorMessage: true,
      clearToast: true,
      fieldErrors: {},
      hasAttemptedSave: false,
    );
  }

  /// Re-queries child tabs 2 and 3 when returning from cross-tab destinations.
  Future<void> refreshChildData() async {
    final tid = state.teacherId;
    if (tid == null) return;

    try {
      final db = await _getDb();
      final subjRows = await db.rawQuery(
        '''
        SELECT sc.Subj_ClsID, sc.ClassID, c.CName, sc.SubjID, s.SubjName, sc.TotalMarks, sc.TotalPracticalMarks
        FROM Subj_Class sc
        INNER JOIN Class c ON sc.ClassID = c.ClassID
        INNER JOIN Subject s ON sc.SubjID = s.SubjID
        WHERE sc.TeacherID = ?
        ORDER BY sc.ClassID ASC
      ''',
        [tid],
      );
      final assignments = subjRows
          .map((r) => TeacherSubjectAssignment.fromMap(r))
          .toList();

      final salRows = await db.rawQuery(
        '''
        SELECT TSalMasID, TeacherID, DisbursDate, SalMonth, PaidAmt, TDeductions, Detail, IsPaid, PaidDate
        FROM TSalMas
        WHERE TeacherID = ?
        ORDER BY SUBSTR(TSalMasID, 1, 4) DESC, TSalMasID DESC
      ''',
        [tid],
      );
      final slips = salRows.map((r) => TeacherSalarySlip.fromMap(r)).toList();

      state = state.copyWith(
        subjectAssignments: assignments,
        salarySlips: slips,
      );
    } catch (_) {}
  }

  /// Updates a field value in draft and live-clears errors after initial save attempt.
  void updateField(String field, dynamic value) {
    if (state.draft == null) return;

    var d = state.draft!;
    switch (field) {
      case 'TName':
        d = d.copyWith(tName: value as String);
        break;
      case 'TFName':
        d = d.copyWith(tFName: value as String?);
        break;
      case 'TCNIC':
        d = d.copyWith(tCnic: value as String);
        break;
      case 'DOB':
        d = d.copyWith(dob: value as String?);
        break;
      case 'TContactNo1':
        d = d.copyWith(tContactNo1: value as String);
        break;
      case 'TContactNo2':
        d = d.copyWith(tContactNo2: value as String?);
        break;
      case 'TAddress':
        d = d.copyWith(tAddress: value as String?);
        break;
      case 'Domicile':
        d = d.copyWith(domicile: value as String?);
        break;
      case 'TSubject':
        d = d.copyWith(tSubject: value as String?);
        break;
      case 'DOJoing':
        d = d.copyWith(doJoing: value as String?);
        break;
      case 'Detail':
        d = d.copyWith(detail: value as String?);
        break;
      case 'TIsPresent':
        d = d.copyWith(tIsPresent: value as String);
        break;
      case 'TEmergencyContactName':
        d = d.copyWith(tEmergencyContactName: value as String?);
        break;
      case 'TEmergencyContactNo':
        d = d.copyWith(tEmergencyContactNo: value as String?);
        break;
      case 'TDoLeft':
        d = d.copyWith(tDoLeft: value as String?);
        break;
      case 'TQualification':
        d = d.copyWith(tQualification: value as String?);
        break;
      case 'TProfessional':
        d = d.copyWith(tProfessional: value as String?);
        break;
      case 'TCertificate':
        d = d.copyWith(tCertificate: value as String?);
        break;
      case 'TFiledOfExperty':
        d = d.copyWith(tFiledOfExperty: value as String?);
        break;
      case 'TExperience':
        d = d.copyWith(tExperience: value as String?);
        break;
      case 'TAnySpeciality':
        d = d.copyWith(tAnySpeciality: value as String?);
        break;
      case 'OfficeFile':
        d = d.copyWith(officeFile: value as String?);
        break;
      case 'TCat':
        d = d.copyWith(tCat: value as String);
        break;
      case 'TBioSer':
        d = d.copyWith(tBioSer: value as double?);
        break;
      case 'AttSMSCont':
        d = d.copyWith(attSmsCont: value as String?);
        break;
    }

    final newErrors = Map<String, String>.from(state.fieldErrors);
    if (state.hasAttemptedSave) {
      if (field == 'TName' && d.tName.trim().isNotEmpty) {
        newErrors.remove('TName');
      }
      if (field == 'TCNIC' && d.tCnic.trim().isNotEmpty) {
        newErrors.remove('TCNIC');
      }
      if (field == 'TContactNo1' && d.tContactNo1.trim().isNotEmpty) {
        newErrors.remove('TContactNo1');
      }
    }

    state = state.copyWith(draft: d, fieldErrors: newErrors);
  }

  /// Switches the active workstation tab (0-3).
  void switchTab(int index) {
    if (index < 0 || index > 3) return;
    state = state.copyWith(activeTab: index);
  }

  /// Clears active error message.
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// Clears active toast message.
  void clearToast() {
    state = state.copyWith(clearToast: true);
  }

  /// Commits new or updated profile enforcing S25 4-gate validation sequence.
  /// Returns the saved TeacherID on success, or null on failure.
  Future<int?> save({int? userLvl}) async {
    // 1. Rights gate
    if (userLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return null;
    }

    state = state.copyWith(hasAttemptedSave: true);
    final draft = state.draft;
    if (draft == null) return null;

    final errors = <String, String>{};

    // 2. Name gate
    if (draft.tName.trim().isEmpty) {
      const msg = 'Must Enter Teacher Name Please ';
      errors['TName'] = msg;
      state = state.copyWith(
        errorMessage: msg,
        fieldErrors: errors,
        activeTab: 0,
      );
      return null;
    }

    // 3. CNIC gate
    if (draft.tCnic.trim().isEmpty) {
      const msg = 'Must Enter CNIC Please ';
      errors['TCNIC'] = msg;
      state = state.copyWith(
        errorMessage: msg,
        fieldErrors: errors,
        activeTab: 0,
      );
      return null;
    }

    // 4. Contact No 1 gate
    if (draft.tContactNo1.trim().isEmpty) {
      const msg = 'Must Enter Contact No 1 Please ';
      errors['TContactNo1'] = msg;
      state = state.copyWith(
        errorMessage: msg,
        fieldErrors: errors,
        activeTab: 0,
      );
      return null;
    }

    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final db = await _getDb();
      int resultId;

      if (state.isNew) {
        // Atomic MAX+1 surrogate key allocation
        final maxRow = await db.rawQuery(
          'SELECT COALESCE(MAX(TeacherID), 0) + 1 AS nextId FROM Teachers',
        );
        resultId = (maxRow.first['nextId'] as num).toInt();

        final map = draft.toMap();
        map['TeacherID'] = resultId;

        await db.insert(
          'Teachers',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Reload data into state
        await loadTeacher(resultId);

        state = state.copyWith(
          isSaving: false,
          isEditMode: false,
          toast: 'Teacher Profile Created Successfully',
        );
      } else {
        resultId = state.teacherId!;
        final map = draft.toMap();
        map.remove('TeacherID');

        await db.update(
          'Teachers',
          map,
          where: 'TeacherID = ?',
          whereArgs: [resultId],
        );

        // Reload data into state
        await loadTeacher(resultId);

        state = state.copyWith(
          isSaving: false,
          isEditMode: false,
          toast: 'Teacher Profile Updated Successfully',
        );
      }

      return resultId;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Database error while saving profile: $e',
      );
      return null;
    }
  }

  /// Deletes the teacher record from the Teachers table.
  Future<void> deleteTeacher(int teacherId) async {
    final db = await _getDb();
    await db.delete(
      'Teachers',
      where: 'TeacherID = ?',
      whereArgs: [teacherId],
    );
  }

  /// Directly updates and persists the active status (TIsPresent) for a teacher.
  Future<void> toggleActiveStatus(int teacherId, bool isActive) async {
    final db = await _getDb();
    final status = isActive ? 'Y' : 'N';
    await db.update(
      'Teachers',
      {'TIsPresent': status},
      where: 'TeacherID = ?',
      whereArgs: [teacherId],
    );
    if (state.teacherId == teacherId && state.loadedTeacher != null) {
      final updated = state.loadedTeacher!.copyWith(tIsPresent: status);
      state = state.copyWith(
        loadedTeacher: updated,
        draft: state.draft?.copyWith(tIsPresent: status) ?? updated,
      );
    }
  }
}

/// Family provider keyed by teacherId (null for /staff/teachers/new).
final teacherProfileProvider =
    StateNotifierProvider.family<
      TeacherProfileNotifier,
      TeacherProfileState,
      int?
    >((ref, teacherId) => TeacherProfileNotifier());
