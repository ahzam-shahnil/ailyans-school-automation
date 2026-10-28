import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db/database.dart';

/// Immutable state representation for Screen 25 - ClassSectionScreen (`/academics/classes`).
/// Implements §S6 (`frmClass` at `0x00415b24`, `ObjID: 4`).
class ClassSectionState {
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> teacherOptions;
  final List<Map<String, dynamic>> allTeachers;
  final int? selectedClassId;
  final String selectedClassName;
  final bool isNewClassMode;
  final bool isClassEditMode;
  final List<Map<String, dynamic>> sections;
  final int? editingSectionId;
  final String editingSecName;
  final int? editingSecTeacherId;
  final int? editingSecProctorId;
  final String editingRoomNo;
  final String editingSecRemarks;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? toast;
  final bool readOnly;

  const ClassSectionState({
    this.classes = const [],
    this.teacherOptions = const [],
    this.allTeachers = const [],
    this.selectedClassId,
    this.selectedClassName = '',
    this.isNewClassMode = false,
    this.isClassEditMode = false,
    this.sections = const [],
    this.editingSectionId,
    this.editingSecName = '',
    this.editingSecTeacherId,
    this.editingSecProctorId,
    this.editingRoomNo = '',
    this.editingSecRemarks = '',
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.toast,
    this.readOnly = false,
  });

  ClassSectionState copyWith({
    List<Map<String, dynamic>>? classes,
    List<Map<String, dynamic>>? teacherOptions,
    List<Map<String, dynamic>>? allTeachers,
    int? selectedClassId,
    bool clearSelectedClass = false,
    String? selectedClassName,
    bool? isNewClassMode,
    bool? isClassEditMode,
    List<Map<String, dynamic>>? sections,
    int? editingSectionId,
    bool clearEditingSectionId = false,
    String? editingSecName,
    int? editingSecTeacherId,
    bool clearEditingSecTeacherId = false,
    int? editingSecProctorId,
    bool clearEditingSecProctorId = false,
    String? editingRoomNo,
    String? editingSecRemarks,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? toast,
    bool clearToast = false,
    bool? readOnly,
  }) {
    return ClassSectionState(
      classes: classes ?? this.classes,
      teacherOptions: teacherOptions ?? this.teacherOptions,
      allTeachers: allTeachers ?? this.allTeachers,
      selectedClassId: clearSelectedClass
          ? null
          : (selectedClassId ?? this.selectedClassId),
      selectedClassName: selectedClassName ?? this.selectedClassName,
      isNewClassMode: isNewClassMode ?? this.isNewClassMode,
      isClassEditMode: isClassEditMode ?? this.isClassEditMode,
      sections: sections ?? this.sections,
      editingSectionId: clearEditingSectionId
          ? null
          : (editingSectionId ?? this.editingSectionId),
      editingSecName: editingSecName ?? this.editingSecName,
      editingSecTeacherId: clearEditingSecTeacherId
          ? null
          : (editingSecTeacherId ?? this.editingSecTeacherId),
      editingSecProctorId: clearEditingSecProctorId
          ? null
          : (editingSecProctorId ?? this.editingSecProctorId),
      editingRoomNo: editingRoomNo ?? this.editingRoomNo,
      editingSecRemarks: editingSecRemarks ?? this.editingSecRemarks,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      toast: clearToast ? null : (toast ?? this.toast),
      readOnly: readOnly ?? this.readOnly,
    );
  }
}

/// StateNotifier handling master-detail Class and Section authoring per §S6.
class ClassSectionNotifier extends StateNotifier<ClassSectionState> {
  ClassSectionNotifier() : super(const ClassSectionState());

  Future<Database> _getDb() async {
    return DatabaseService.instance.database;
  }

  /// Initial load: fetches classes, teachers, selects first class, and loads its sections.
  Future<void> loadInitialData() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final db = await _getDb();

      // 1. Fetch Class master list with real-time section count
      final classRows = await db.rawQuery('''
        SELECT c.ClassID, c.CName,
               (SELECT COUNT(*) FROM ClassSec cs WHERE cs.ClassID = c.ClassID) AS SectionCount
        FROM Class c
        ORDER BY c.ClassID ASC
      ''');

      // 2. Fetch Teachers where TCat = 'Teacher'
      final teacherRows = await db.rawQuery(
        "SELECT TeacherID, TName FROM Teachers WHERE TCat = 'Teacher' ORDER BY TName ASC",
      );

      // 3. Fetch all Teachers for Proctor dropdown
      final allTeacherRows = await db.rawQuery(
        'SELECT TeacherID, TName, TCat FROM Teachers ORDER BY TName ASC',
      );

      int? targetClassId = state.selectedClassId;
      String targetClassName = state.selectedClassName;

      if (targetClassId == null && classRows.isNotEmpty) {
        targetClassId = (classRows.first['ClassID'] as num).toInt();
        targetClassName = classRows.first['CName'] as String? ?? '';
      }

      state = state.copyWith(
        classes: classRows,
        teacherOptions: teacherRows,
        allTeachers: allTeacherRows,
        selectedClassId: targetClassId,
        selectedClassName: targetClassName,
        isLoading: false,
      );

      if (targetClassId != null) {
        await loadSectionsForClass(targetClassId);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load classes: $e',
        );
      }
    }
  }

  /// Loads sections for a specific class cohort.
  Future<void> loadSectionsForClass(int? classId) async {
    if (classId == null) {
      state = state.copyWith(sections: const []);
      return;
    }

    try {
      final db = await _getDb();
      final secRows = await db.rawQuery(
        '''
        SELECT cs.ClassSecID, cs.ClassID, cs.SecName, cs.SecTeacher, cs.SecProctor, cs.RoomNo, cs.Remarks,
               t1.TName AS TeacherName, t2.TName AS ProctorName,
               (SELECT COUNT(*) FROM Student_Class sc WHERE sc.ClassSecID = cs.ClassSecID AND sc.Present = 1) AS EnrolledCount
        FROM ClassSec cs
        LEFT JOIN Teachers t1 ON cs.SecTeacher = t1.TeacherID
        LEFT JOIN Teachers t2 ON cs.SecProctor = t2.TeacherID
        WHERE cs.ClassID = ?
        ORDER BY cs.SecName ASC
      ''',
        [classId],
      );

      if (mounted) {
        state = state.copyWith(sections: secRows);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Failed to load sections: $e');
      }
    }
  }

  /// Selects active class from left list.
  Future<void> selectClass(int classId) async {
    final matching = state.classes.firstWhere(
      (c) => (c['ClassID'] as num).toInt() == classId,
      orElse: () => <String, dynamic>{},
    );
    final name = matching['CName'] as String? ?? '';

    state = state.copyWith(
      selectedClassId: classId,
      selectedClassName: name,
      isClassEditMode: false,
      isNewClassMode: false,
      clearErrorMessage: true,
    );

    await loadSectionsForClass(classId);
  }

  // ===========================================================================
  // CLASS ACTIONS
  // ===========================================================================

  void enterNewClassMode() {
    if (state.readOnly) {
      setError("You don't have enough rights for purpose");
      return;
    }
    state = state.copyWith(
      isNewClassMode: true,
      isClassEditMode: true,
      clearSelectedClass: true,
      selectedClassName: '',
      sections: const [],
      clearErrorMessage: true,
    );
  }

  void enterEditClassMode() {
    if (state.readOnly) {
      setError("You don't have enough rights for purpose");
      return;
    }
    if (state.selectedClassId == null) {
      setError('Select a class first');
      return;
    }
    state = state.copyWith(isClassEditMode: true, clearErrorMessage: true);
  }

  void cancelClassEdit() {
    state = state.copyWith(
      isClassEditMode: false,
      isNewClassMode: false,
      clearErrorMessage: true,
    );
    if (state.classes.isNotEmpty && state.selectedClassId == null) {
      selectClass((state.classes.first['ClassID'] as num).toInt());
    }
  }

  Future<bool> saveClass({
    required String className,
    int? currentUserLvl,
  }) async {
    // Gate 1: Permission gate
    final effectiveLvl = currentUserLvl ?? (state.readOnly ? 3 : 1);
    if (effectiveLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
        clearToast: true,
      );
      return false;
    }

    // Gate 2: Empty class name gate (trailing space preserved per S6)
    if (className.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter Class Name Please ',
        clearToast: true,
      );
      return false;
    }

    // Gate 3: Case-insensitive duplicate name check
    try {
      final db = await _getDb();
      final dupQuery = (state.isNewClassMode || state.selectedClassId == null)
          ? 'SELECT COUNT(*) AS cnt FROM Class WHERE LOWER(TRIM(CName)) = LOWER(TRIM(?))'
          : 'SELECT COUNT(*) AS cnt FROM Class WHERE LOWER(TRIM(CName)) = LOWER(TRIM(?)) AND ClassID != ?';
      final dupArgs = (state.isNewClassMode || state.selectedClassId == null)
          ? [className.trim()]
          : [className.trim(), state.selectedClassId];
      final dupResult = await db.rawQuery(dupQuery, dupArgs);
      final dupCount = (dupResult.first['cnt'] as num?)?.toInt() ?? 0;

      if (dupCount > 0) {
        state = state.copyWith(
          errorMessage: 'Class with this name already exists',
          clearToast: true,
        );
        return false;
      }

      if (state.isNewClassMode || state.selectedClassId == null) {
        final maxRes = await db.rawQuery(
          'SELECT COALESCE(MAX(ClassID), 0) + 1 AS nextId FROM Class',
        );
        final nextId = (maxRes.first['nextId'] as num).toInt();

        await db.rawInsert('INSERT INTO Class (ClassID, CName) VALUES (?, ?)', [
          nextId,
          className.trim(),
        ]);

        final classRows = await db.rawQuery('''
          SELECT c.ClassID, c.CName,
                 (SELECT COUNT(*) FROM ClassSec cs WHERE cs.ClassID = c.ClassID) AS SectionCount
          FROM Class c
          ORDER BY c.ClassID ASC
        ''');

        state = state.copyWith(
          classes: classRows,
          selectedClassId: nextId,
          selectedClassName: className.trim(),
          sections: const [],
          isNewClassMode: false,
          isClassEditMode: false,
          clearErrorMessage: true,
          toast: 'Class Updated/Added Successfully',
        );
        return true;
      } else {
        await db.rawUpdate('UPDATE Class SET CName = ? WHERE ClassID = ?', [
          className.trim(),
          state.selectedClassId,
        ]);

        final classRows = await db.rawQuery('''
          SELECT c.ClassID, c.CName,
                 (SELECT COUNT(*) FROM ClassSec cs WHERE cs.ClassID = c.ClassID) AS SectionCount
          FROM Class c
          ORDER BY c.ClassID ASC
        ''');

        state = state.copyWith(
          classes: classRows,
          selectedClassName: className.trim(),
          isClassEditMode: false,
          clearErrorMessage: true,
          toast: 'Class Updated/Added Successfully',
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Database error saving class: $e',
        clearToast: true,
      );
      return false;
    }
  }

  // ===========================================================================
  // SECTION ACTIONS
  // ===========================================================================

  void enterNewSectionMode() {
    if (state.readOnly) {
      setError("You don't have enough rights for purpose");
      return;
    }
    if (state.selectedClassId == null) {
      setError('Choose Class to add Section please');
      return;
    }
    state = state.copyWith(
      clearEditingSectionId: true,
      editingSecName: '',
      clearEditingSecTeacherId: true,
      clearEditingSecProctorId: true,
      editingRoomNo: '',
      editingSecRemarks: '',
      clearErrorMessage: true,
    );
  }

  void enterEditSectionMode(int classSecId) {
    if (state.readOnly) {
      setError("You don't have enough rights for purpose");
      return;
    }
    final row = state.sections.firstWhere(
      (s) => (s['ClassSecID'] as num).toInt() == classSecId,
      orElse: () => <String, dynamic>{},
    );
    if (row.isEmpty) return;

    state = state.copyWith(
      editingSectionId: classSecId,
      editingSecName: row['SecName'] as String? ?? '',
      editingSecTeacherId: row['SecTeacher'] as int?,
      editingSecProctorId: row['SecProctor'] as int?,
      editingRoomNo: row['RoomNo'] as String? ?? '',
      editingSecRemarks: row['Remarks'] as String? ?? '',
      clearErrorMessage: true,
    );
  }

  void setEditingSecName(String v) => state = state.copyWith(editingSecName: v);
  void setEditingSecTeacher(int? v) =>
      state = state.copyWith(editingSecTeacherId: v);
  void setEditingSecProctor(int? v) =>
      state = state.copyWith(editingSecProctorId: v);
  void setEditingRoomNo(String v) => state = state.copyWith(editingRoomNo: v);
  void setEditingSecRemarks(String v) =>
      state = state.copyWith(editingSecRemarks: v);

  void cancelSectionEdit() {
    state = state.copyWith(
      clearEditingSectionId: true,
      editingSecName: '',
      clearEditingSecTeacherId: true,
      clearEditingSecProctorId: true,
      editingRoomNo: '',
      editingSecRemarks: '',
      clearErrorMessage: true,
    );
  }

  Future<bool> saveSection({int? currentUserLvl}) async {
    // Gate 1: Permission gate
    final effectiveLvl = currentUserLvl ?? (state.readOnly ? 3 : 1);
    if (effectiveLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
        clearToast: true,
      );
      return false;
    }

    // Gate 2: Parent class selected
    if (state.selectedClassId == null) {
      state = state.copyWith(
        errorMessage: 'Choose Class to add Section please',
        clearToast: true,
      );
      return false;
    }

    // Gate 3: Section name required
    if (state.editingSecName.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter Section Name Please',
        clearToast: true,
      );
      return false;
    }

    // Gate 4: Duplicate section name check (case-insensitive per class)
    try {
      final db = await _getDb();
      final dupQuery = state.editingSectionId == null
          ? 'SELECT COUNT(*) AS cnt FROM ClassSec WHERE LOWER(TRIM(SecName)) = LOWER(TRIM(?)) AND ClassID = ?'
          : 'SELECT COUNT(*) AS cnt FROM ClassSec WHERE LOWER(TRIM(SecName)) = LOWER(TRIM(?)) AND ClassID = ? AND ClassSecID != ?';
      final dupArgs = state.editingSectionId == null
          ? [state.editingSecName.trim(), state.selectedClassId]
          : [
              state.editingSecName.trim(),
              state.selectedClassId,
              state.editingSectionId,
            ];
      final dupResult = await db.rawQuery(dupQuery, dupArgs);
      final dupCount = (dupResult.first['cnt'] as num?)?.toInt() ?? 0;

      if (dupCount > 0) {
        state = state.copyWith(
          errorMessage: 'Section with this name already exists in this Class',
          clearToast: true,
        );
        return false;
      }

      final room = state.editingRoomNo.trim().isEmpty
          ? null
          : state.editingRoomNo.trim();
      final remarks = state.editingSecRemarks.trim().isEmpty
          ? null
          : state.editingSecRemarks.trim();

      if (state.editingSectionId == null) {
        final maxRes = await db.rawQuery(
          'SELECT COALESCE(MAX(ClassSecID), 0) + 1 AS nextId FROM ClassSec',
        );
        final nextId = (maxRes.first['nextId'] as num).toInt();

        await db.rawInsert(
          'INSERT INTO ClassSec (ClassSecID, ClassID, SecName, SecTeacher, SecProctor, RoomNo, Remarks) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            nextId,
            state.selectedClassId,
            state.editingSecName.trim(),
            state.editingSecTeacherId,
            state.editingSecProctorId,
            room,
            remarks,
          ],
        );
      } else {
        await db.rawUpdate(
          'UPDATE ClassSec SET SecName = ?, SecTeacher = ?, SecProctor = ?, RoomNo = ?, Remarks = ? WHERE ClassSecID = ?',
          [
            state.editingSecName.trim(),
            state.editingSecTeacherId,
            state.editingSecProctorId,
            room,
            remarks,
            state.editingSectionId,
          ],
        );
      }

      // Reload classes so LEFT panel {N} Sec badge updates immediately
      final classRows = await db.rawQuery('''
        SELECT c.ClassID, c.CName,
               (SELECT COUNT(*) FROM ClassSec cs WHERE cs.ClassID = c.ClassID) AS SectionCount
        FROM Class c
        ORDER BY c.ClassID ASC
      ''');

      state = state.copyWith(
        classes: classRows,
        clearEditingSectionId: true,
        editingSecName: '',
        clearEditingSecTeacherId: true,
        clearEditingSecProctorId: true,
        editingRoomNo: '',
        editingSecRemarks: '',
        clearErrorMessage: true,
        toast: 'Section Saved Successfully',
      );

      await loadSectionsForClass(state.selectedClassId);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Database error saving section: $e',
        clearToast: true,
      );
      return false;
    }
  }

  Future<bool> deleteSection(int classSecId, {int? currentUserLvl}) async {
    // Gate 1: Permission gate
    final effectiveLvl = currentUserLvl ?? (state.readOnly ? 3 : 1);
    if (effectiveLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
        clearToast: true,
      );
      return false;
    }

    try {
      final db = await _getDb();

      // Gate 2: Enrollment guard (Decision X)
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM Student_Class WHERE ClassSecID = ? AND Present = 1',
        [classSecId],
      );
      final enrolled = (countResult.first['cnt'] as num?)?.toInt() ?? 0;
      if (enrolled > 0) {
        state = state.copyWith(
          errorMessage:
              'Cannot delete section: $enrolled students currently enrolled',
          clearToast: true,
        );
        return false;
      }

      await db.rawDelete('DELETE FROM ClassSec WHERE ClassSecID = ?', [
        classSecId,
      ]);

      // Reload classes so LEFT panel {N} Sec badge decrements
      final classRows = await db.rawQuery('''
        SELECT c.ClassID, c.CName,
               (SELECT COUNT(*) FROM ClassSec cs WHERE cs.ClassID = c.ClassID) AS SectionCount
        FROM Class c
        ORDER BY c.ClassID ASC
      ''');

      state = state.copyWith(
        classes: classRows,
        clearErrorMessage: true,
        toast: 'Section Removed Successfully',
      );

      await loadSectionsForClass(state.selectedClassId);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Database error deleting section: $e',
        clearToast: true,
      );
      return false;
    }
  }

  void setReadOnly(bool val) => state = state.copyWith(readOnly: val);
  void setError(String message) =>
      state = state.copyWith(errorMessage: message, clearToast: true);
  void clearError() => state = state.copyWith(clearErrorMessage: true);
  void clearToast() => state = state.copyWith(clearToast: true);
}

/// Global provider for master-detail class and section management.
final classSectionProvider =
    StateNotifierProvider<ClassSectionNotifier, ClassSectionState>(
      (ref) => ClassSectionNotifier(),
    );
