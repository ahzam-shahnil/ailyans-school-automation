import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db/database.dart';

/// State representation for Screen 26 - SubjectCatalogScreen (`/academics/subjects`).
/// Rebuild-only administrative catalog screen for foundational `Subject` table.
class SubjectCatalogState {
  final List<Map<String, dynamic>>
  subjects; // SubjID, SubjName, SubjDetail, AssignedClasses
  final bool isLoading;
  final bool isSaving;
  final bool isAddingNew;
  final int? editingSubjectId;
  final String editingSubjName;
  final String editingSubjDetail;
  final String originalSubjName; // for dirty tracking
  final String originalSubjDetail;
  final int? nextSubjId;
  final String? errorMessage;
  final String? toast;
  final bool readOnly;

  const SubjectCatalogState({
    this.subjects = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.isAddingNew = false,
    this.editingSubjectId,
    this.editingSubjName = '',
    this.editingSubjDetail = '',
    this.originalSubjName = '',
    this.originalSubjDetail = '',
    this.nextSubjId,
    this.errorMessage,
    this.toast,
    this.readOnly = false,
  });

  bool get isDrawerOpen => isAddingNew || editingSubjectId != null;

  bool get isDrawerDirty =>
      isDrawerOpen &&
      (editingSubjName.trim() != originalSubjName.trim() ||
          editingSubjDetail.trim() != originalSubjDetail.trim());

  int get subjectCount => subjects.length;

  int get totalMappedClasses => subjects.fold(
    0,
    (sum, s) => sum + ((s['AssignedClasses'] as num?)?.toInt() ?? 0),
  );

  SubjectCatalogState copyWith({
    List<Map<String, dynamic>>? subjects,
    bool? isLoading,
    bool? isSaving,
    bool? isAddingNew,
    int? editingSubjectId,
    bool clearEditingSubjectId = false,
    String? editingSubjName,
    String? editingSubjDetail,
    String? originalSubjName,
    String? originalSubjDetail,
    int? nextSubjId,
    bool clearNextSubjId = false,
    String? errorMessage,
    bool clearError = false,
    String? toast,
    bool clearToast = false,
    bool? readOnly,
  }) {
    return SubjectCatalogState(
      subjects: subjects ?? this.subjects,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isAddingNew: isAddingNew ?? this.isAddingNew,
      editingSubjectId: clearEditingSubjectId
          ? null
          : (editingSubjectId ?? this.editingSubjectId),
      editingSubjName: editingSubjName ?? this.editingSubjName,
      editingSubjDetail: editingSubjDetail ?? this.editingSubjDetail,
      originalSubjName: originalSubjName ?? this.originalSubjName,
      originalSubjDetail: originalSubjDetail ?? this.originalSubjDetail,
      nextSubjId: clearNextSubjId ? null : (nextSubjId ?? this.nextSubjId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      toast: clearToast ? null : (toast ?? this.toast),
      readOnly: readOnly ?? this.readOnly,
    );
  }
}

class SubjectCatalogNotifier extends StateNotifier<SubjectCatalogState> {
  SubjectCatalogNotifier() : super(const SubjectCatalogState());

  Future<Database> _getDb() async {
    return DatabaseService.instance.database;
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = await _getDb();
      final rows = await db.rawQuery('''
        SELECT s.SubjID, s.SubjName, s.SubjDetail,
               COUNT(sc.ClassID) AS AssignedClasses
        FROM Subject s
        LEFT JOIN Subj_Class sc ON s.SubjID = sc.SubjID
        GROUP BY s.SubjID, s.SubjName, s.SubjDetail
        ORDER BY s.SubjID ASC
      ''');

      if (!mounted) return;
      state = state.copyWith(subjects: rows, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load subjects: $e',
      );
    }
  }

  Future<void> enterAddNewMode({int? currentUserLvl}) async {
    if ((currentUserLvl ?? 1) == 3 || state.readOnly) {
      setError("You don't have enough rights for purpose");
      return;
    }

    final nextId =
        state.subjects.fold<int>(
          0,
          (max, s) => ((s['SubjID'] as num?)?.toInt() ?? 0) > max
              ? ((s['SubjID'] as num?)?.toInt() ?? 0)
              : max,
        ) +
        1;

    state = state.copyWith(
      isAddingNew: true,
      clearEditingSubjectId: true,
      editingSubjName: '',
      editingSubjDetail: '',
      originalSubjName: '',
      originalSubjDetail: '',
      nextSubjId: nextId,
      clearError: true,
    );
  }

  void enterEditMode(int subjId, {int? currentUserLvl}) {
    if ((currentUserLvl ?? 1) == 3 || state.readOnly) {
      setError("You don't have enough rights for purpose");
      return;
    }

    final match = state.subjects.where((s) => s['SubjID'] == subjId);
    if (match.isEmpty) {
      setError('Subject #$subjId not found');
      return;
    }
    final row = match.first;

    state = state.copyWith(
      isAddingNew: false,
      editingSubjectId: subjId,
      editingSubjName: (row['SubjName'] as String?) ?? '',
      editingSubjDetail: (row['SubjDetail'] as String?) ?? '',
      originalSubjName: (row['SubjName'] as String?) ?? '',
      originalSubjDetail: (row['SubjDetail'] as String?) ?? '',
      clearError: true,
    );
  }

  void setEditingSubjName(String v) {
    state = state.copyWith(editingSubjName: v);
  }

  void setEditingSubjDetail(String v) {
    state = state.copyWith(editingSubjDetail: v);
  }

  void closeDrawer() {
    state = state.copyWith(
      isAddingNew: false,
      clearEditingSubjectId: true,
      editingSubjName: '',
      editingSubjDetail: '',
      originalSubjName: '',
      originalSubjDetail: '',
      clearError: true,
    );
  }

  Future<({int bookCount, int classMapCount, int examDetCount, int total})>
  checkDeleteEligibility(int subjId) async {
    final db = await _getDb();
    final depResult = await db.rawQuery(
      'SELECT '
      '(SELECT COUNT(*) FROM Books WHERE BookCatSubj = ?) AS BookCount, '
      '(SELECT COUNT(*) FROM Subj_Class WHERE SubjID = ?) AS ClassMapCount, '
      '(SELECT COUNT(*) FROM ExamDet WHERE SubjID = ?) AS ExamDetCount',
      [subjId, subjId, subjId],
    );
    final bookCount = (depResult.first['BookCount'] as num?)?.toInt() ?? 0;
    final classMapCount =
        (depResult.first['ClassMapCount'] as num?)?.toInt() ?? 0;
    final examDetCount =
        (depResult.first['ExamDetCount'] as num?)?.toInt() ?? 0;
    return (
      bookCount: bookCount,
      classMapCount: classMapCount,
      examDetCount: examDetCount,
      total: bookCount + classMapCount + examDetCount,
    );
  }

  Future<bool> saveSubject({int? currentUserLvl}) async {
    // Gate 1: permission
    if ((currentUserLvl ?? 1) == 3 || state.readOnly) {
      setError("You don't have enough rights for purpose");
      return false;
    }

    // Gate 2: title required
    if (state.editingSubjName.trim().isEmpty) {
      setError('Subject Name is required');
      return false;
    }

    // Gate 3: duplicate name check (case-insensitive)
    final dupQuery = state.isAddingNew
        ? 'SELECT COUNT(*) AS cnt FROM Subject WHERE LOWER(TRIM(SubjName)) = LOWER(TRIM(?))'
        : 'SELECT COUNT(*) AS cnt FROM Subject WHERE LOWER(TRIM(SubjName)) = LOWER(TRIM(?)) AND SubjID != ?';
    final dupArgs = state.isAddingNew
        ? [state.editingSubjName.trim()]
        : [state.editingSubjName.trim(), state.editingSubjectId];

    final db = await _getDb();
    final dupResult = await db.rawQuery(dupQuery, dupArgs);
    final dupCount = (dupResult.first['cnt'] as num?)?.toInt() ?? 0;
    if (dupCount > 0) {
      setError('Subject with this name already exists');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      if (state.isAddingNew) {
        final maxRes = await db.rawQuery(
          'SELECT COALESCE(MAX(SubjID), 0) + 1 AS nextId FROM Subject',
        );
        final nextId = (maxRes.first['nextId'] as num?)?.toInt() ?? 1;

        await db.rawInsert(
          'INSERT INTO Subject (SubjID, SubjName, SubjDetail) VALUES (?, ?, ?)',
          [
            nextId,
            state.editingSubjName.trim(),
            state.editingSubjDetail.trim().isEmpty
                ? null
                : state.editingSubjDetail.trim(),
          ],
        );
      } else {
        await db.rawUpdate(
          'UPDATE Subject SET SubjName = ?, SubjDetail = ? WHERE SubjID = ?',
          [
            state.editingSubjName.trim(),
            state.editingSubjDetail.trim().isEmpty
                ? null
                : state.editingSubjDetail.trim(),
            state.editingSubjectId,
          ],
        );
      }

      await loadInitialData();
      closeDrawer();
      if (!mounted) return true;
      state = state.copyWith(
        isSaving: false,
        toast: 'Subject Saved Successfully',
        clearError: true,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save subject: $e',
      );
      return false;
    }
  }

  Future<bool> deleteSubject(int subjId, {int? currentUserLvl}) async {
    // Gate 1: permission
    if ((currentUserLvl ?? 1) == 3 || state.readOnly) {
      setError("You don't have enough rights for purpose");
      return false;
    }

    // Gate 2: defensive FK re-check
    final deps = await checkDeleteEligibility(subjId);
    if (deps.total > 0) {
      final parts = <String>[];
      if (deps.classMapCount > 0) parts.add('${deps.classMapCount} classes');
      if (deps.examDetCount > 0) parts.add('${deps.examDetCount} exam records');
      if (deps.bookCount > 0) parts.add('${deps.bookCount} library books');
      setError(
        'Cannot delete subject: Currently mapped to classes, exams, or library books (${parts.join(", ")})',
      );
      return false;
    }

    try {
      final db = await _getDb();
      await db.rawDelete('DELETE FROM Subject WHERE SubjID = ?', [subjId]);
      if (state.editingSubjectId == subjId) {
        closeDrawer();
      }
      await loadInitialData();
      if (!mounted) return true;
      state = state.copyWith(toast: 'Subject removed', clearError: true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setError('Failed to delete subject: $e');
      return false;
    }
  }

  void setReadOnly(bool ro) {
    state = state.copyWith(readOnly: ro);
  }

  void setError(String msg) {
    state = state.copyWith(errorMessage: msg, clearToast: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearToast() {
    state = state.copyWith(clearToast: true);
  }
}

final subjectCatalogProvider =
    StateNotifierProvider<SubjectCatalogNotifier, SubjectCatalogState>(
      (ref) => SubjectCatalogNotifier(),
    );
