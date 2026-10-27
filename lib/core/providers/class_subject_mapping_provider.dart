import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/subject_mapping_row.dart';
import '../db/database.dart';

/// State representation for Screen 17 - ClassSubjectMappingScreen (`/exams/subjects`).
/// Implements §S21 (`frmExamClasSubj` at `0x004136c0`, `ObjID: 23`).
class ClassSubjectMappingState {
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> allTeachers;
  final List<Map<String, dynamic>> availableTeachers; // TCat = 'Teacher'
  final int? selectedClassId;
  final List<SubjectMappingRow> mappings;
  final SubjectMappingRow? editingMapping; // null = CREATE mode
  final Map<String, dynamic>?
  nonTeacherCurrent; // For Principal/Staff faculty warning

  // Form inputs
  final int? formSubjId;
  final int? formTeacherId;
  final String formTheoryMarks;
  final String formPracticalMarks;

  final bool isLoading;
  final String? toast;
  final String? errorMessage;

  const ClassSubjectMappingState({
    this.classes = const [],
    this.subjects = const [],
    this.allTeachers = const [],
    this.availableTeachers = const [],
    this.selectedClassId,
    this.mappings = const [],
    this.editingMapping,
    this.nonTeacherCurrent,
    this.formSubjId,
    this.formTeacherId,
    this.formTheoryMarks = '',
    this.formPracticalMarks = '0',
    this.isLoading = false,
    this.toast,
    this.errorMessage,
  });

  bool get isEditMode => editingMapping != null;

  int get totalClassMarks =>
      mappings.fold<int>(0, (sum, m) => sum + m.combinedMarks);

  Map<String, dynamic>? get selectedClass {
    if (selectedClassId == null) return null;
    for (final c in classes) {
      if ((c['ClassID'] as num).toInt() == selectedClassId) {
        return c;
      }
    }
    return null;
  }

  String get selectedClassName {
    final cls = selectedClass;
    if (cls != null && cls['CName'] != null) {
      return cls['CName'] as String;
    }
    return selectedClassId != null ? 'Class $selectedClassId' : 'Class';
  }

  ClassSubjectMappingState copyWith({
    List<Map<String, dynamic>>? classes,
    List<Map<String, dynamic>>? subjects,
    List<Map<String, dynamic>>? allTeachers,
    List<Map<String, dynamic>>? availableTeachers,
    int? selectedClassId,
    List<SubjectMappingRow>? mappings,
    SubjectMappingRow? editingMapping,
    bool clearEditingMapping = false,
    Map<String, dynamic>? nonTeacherCurrent,
    bool clearNonTeacherCurrent = false,
    int? formSubjId,
    bool clearFormSubjId = false,
    int? formTeacherId,
    bool clearFormTeacherId = false,
    String? formTheoryMarks,
    String? formPracticalMarks,
    bool? isLoading,
    String? toast,
    bool clearToast = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ClassSubjectMappingState(
      classes: classes ?? this.classes,
      subjects: subjects ?? this.subjects,
      allTeachers: allTeachers ?? this.allTeachers,
      availableTeachers: availableTeachers ?? this.availableTeachers,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      mappings: mappings ?? this.mappings,
      editingMapping: clearEditingMapping
          ? null
          : (editingMapping ?? this.editingMapping),
      nonTeacherCurrent: clearNonTeacherCurrent
          ? null
          : (nonTeacherCurrent ?? this.nonTeacherCurrent),
      formSubjId: clearFormSubjId ? null : (formSubjId ?? this.formSubjId),
      formTeacherId: clearFormTeacherId
          ? null
          : (formTeacherId ?? this.formTeacherId),
      formTheoryMarks: formTheoryMarks ?? this.formTheoryMarks,
      formPracticalMarks: formPracticalMarks ?? this.formPracticalMarks,
      isLoading: isLoading ?? this.isLoading,
      toast: clearToast ? null : (toast ?? this.toast),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Provider managing Class-to-Subject curriculum configuration.
class ClassSubjectMappingNotifier
    extends StateNotifier<ClassSubjectMappingState> {
  ClassSubjectMappingNotifier([ClassSubjectMappingState? initialState])
    : super(initialState ?? const ClassSubjectMappingState());

  Future<Database> _getDb() async {
    return DatabaseService.instance.database;
  }

  /// S21 Form_Load (0x00700860): loads catalogs, auto-selects first class with mappings,
  /// and fetches curriculum syllabus rows.
  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final db = await _getDb();

      // 1. Classes catalog
      final classRows = await db.rawQuery(
        'SELECT ClassID, CName FROM Class ORDER BY ClassID ASC',
      );
      final classes = List<Map<String, dynamic>>.from(classRows);

      // 2. Subjects catalog
      final subjectRows = await db.rawQuery(
        'SELECT SubjID, SubjName FROM Subject ORDER BY SubjName ASC',
      );
      final subjects = List<Map<String, dynamic>>.from(subjectRows);

      // 3. Teachers catalog
      final teacherRows = await db.rawQuery(
        'SELECT TeacherID, TName, TCat FROM Teachers ORDER BY TName ASC',
      );
      final allTeachers = List<Map<String, dynamic>>.from(teacherRows);
      final availableTeachers = allTeachers
          .where((t) => (t['TCat'] as String?) == 'Teacher')
          .toList();

      // 4. Auto-select class: find first class that HAS existing mappings
      final mappedClassRow = await db.rawQuery('''
        SELECT ClassID FROM Subj_Class
        GROUP BY ClassID
        HAVING COUNT(*) > 0
        ORDER BY ClassID ASC
        LIMIT 1
      ''');

      int? autoClassId;
      if (mappedClassRow.isNotEmpty) {
        autoClassId = (mappedClassRow.first['ClassID'] as num).toInt();
      } else if (classes.isNotEmpty) {
        autoClassId = (classes.first['ClassID'] as num).toInt();
      }

      if (!mounted) return;
      state = state.copyWith(
        classes: classes,
        subjects: subjects,
        allTeachers: allTeachers,
        availableTeachers: availableTeachers,
        selectedClassId: autoClassId,
        formPracticalMarks: '0',
        isLoading: false,
      );

      if (autoClassId != null) {
        await loadMappingsForClass(autoClassId);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize curriculum mapping: $e',
      );
    }
  }

  /// Select a class from the top selector strip.
  Future<void> setClassId(int classId) async {
    if (state.selectedClassId == classId) return;

    state = state.copyWith(
      selectedClassId: classId,
      clearEditingMapping: true,
      clearNonTeacherCurrent: true,
      clearFormSubjId: true,
      clearFormTeacherId: true,
      formTheoryMarks: '',
      formPracticalMarks: '0',
      clearErrorMessage: true,
    );

    await loadMappingsForClass(classId);
  }

  /// Queries all subjects assigned to [classId] in `Subj_Class`.
  Future<void> loadMappingsForClass(int classId) async {
    try {
      final db = await _getDb();
      final rows = await db.rawQuery(
        '''
        SELECT sc.Subj_ClsID, sc.SubjID, s.SubjName, sc.ClassID, c.CName, sc.TeacherID, t.TName, t.TCat AS TeacherCategory, sc.TotalMarks, sc.TotalPracticalMarks
        FROM Subj_Class sc
        LEFT JOIN Subject s ON s.SubjID = sc.SubjID
        LEFT JOIN Teachers t ON t.TeacherID = sc.TeacherID
        LEFT JOIN Class c ON c.ClassID = sc.ClassID
        WHERE sc.ClassID = ?
        ORDER BY sc.Subj_ClsID ASC
      ''',
        [classId],
      );

      final mappings = rows.map((r) => SubjectMappingRow.fromMap(r)).toList();
      if (!mounted) return;
      state = state.copyWith(mappings: mappings);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'Failed to load class syllabus: $e');
    }
  }

  /// Select an existing mapping row to edit.
  void selectMappingForEdit(int subjClsId) {
    SubjectMappingRow? target;
    for (final m in state.mappings) {
      if (m.subjClsId == subjClsId) {
        target = m;
        break;
      }
    }
    if (target == null) return;

    Map<String, dynamic>? nonTeacher;
    if (target.teacherCategory != 'Teacher') {
      for (final t in state.allTeachers) {
        if ((t['TeacherID'] as num).toInt() == target.teacherId) {
          nonTeacher = t;
          break;
        }
      }
    }

    state = state.copyWith(
      editingMapping: target,
      nonTeacherCurrent: nonTeacher,
      clearNonTeacherCurrent: nonTeacher == null,
      formSubjId: target.subjId,
      formTeacherId: target.teacherId,
      formTheoryMarks: target.totalMarks.toString(),
      formPracticalMarks: target.totalPracticalMarks.toString(),
      clearErrorMessage: true,
    );
  }

  /// Reset form fields back to CREATE mode.
  void resetForm() {
    state = state.copyWith(
      clearEditingMapping: true,
      clearNonTeacherCurrent: true,
      clearFormSubjId: true,
      clearFormTeacherId: true,
      formTheoryMarks: '',
      formPracticalMarks: '0',
      clearErrorMessage: true,
    );
  }

  void setFormSubjId(int? id) {
    state = state.copyWith(
      formSubjId: id,
      clearFormSubjId: id == null,
      clearErrorMessage: true,
    );
  }

  void setFormTeacherId(int? id) {
    state = state.copyWith(
      formTeacherId: id,
      clearFormTeacherId: id == null,
      clearErrorMessage: true,
    );
  }

  void setFormTheoryMarks(String marks) {
    state = state.copyWith(formTheoryMarks: marks, clearErrorMessage: true);
  }

  void setFormPracticalMarks(String marks) {
    state = state.copyWith(formPracticalMarks: marks, clearErrorMessage: true);
  }

  void clearToast() {
    state = state.copyWith(clearToast: true);
  }

  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  String _resolveSubjectName(int? subjId) {
    if (subjId == null) return 'Subject';
    for (final s in state.subjects) {
      if ((s['SubjID'] as num).toInt() == subjId) {
        return s['SubjName'] as String? ?? 'Subject $subjId';
      }
    }
    return 'Subject $subjId';
  }

  /// Commits INSERT or UPDATE into `Subj_Class` enforcing the 6 sequential gates of S21.
  Future<(bool, String)> saveMapping() async {
    // Gate 1: Class Selection Gate
    if (state.selectedClassId == null) {
      const err = ' Select Class ';
      state = state.copyWith(errorMessage: err);
      return (false, err);
    }

    // Gate 2: Subject Selection Gate
    if (state.formSubjId == null) {
      const err = 'Select Subject';
      state = state.copyWith(errorMessage: err);
      return (false, err);
    }

    // Gate 3: Teacher Selection Gate
    if (state.formTeacherId == null) {
      const err = 'Select Subject Teacher';
      state = state.copyWith(errorMessage: err);
      return (false, err);
    }

    final subjName = _resolveSubjectName(state.formSubjId);

    // Gate 4: Theory Marks Gate (positive non-empty integer)
    final theoryStr = state.formTheoryMarks.trim();
    final theoryVal = int.tryParse(theoryStr);
    if (theoryStr.isEmpty || theoryVal == null || theoryVal <= 0) {
      final err = 'Enter Total Theory Marks for $subjName';
      state = state.copyWith(errorMessage: err);
      return (false, err);
    }

    // Gate 5: Practical Marks Gate (non-negative non-empty integer)
    final pracStr = state.formPracticalMarks.trim();
    final pracVal = int.tryParse(pracStr);
    if (pracStr.isEmpty || pracVal == null || pracVal < 0) {
      final err = 'Enter Total Practical Marks for $subjName';
      state = state.copyWith(errorMessage: err);
      return (false, err);
    }

    final db = await _getDb();
    final classId = state.selectedClassId!;
    final subjId = state.formSubjId!;
    final teacherId = state.formTeacherId!;
    final currentSubjClsId = state.editingMapping?.subjClsId ?? -1;

    // Gate 6: Duplicate Prevention Check (composite PK SubjID + ClassID)
    final dupRows = await db.rawQuery(
      '''
      SELECT Subj_ClsID FROM Subj_Class
      WHERE SubjID = ? AND ClassID = ? AND Subj_ClsID != ?
      LIMIT 1
    ''',
      [subjId, classId, currentSubjClsId],
    );

    if (dupRows.isNotEmpty) {
      final className = state.selectedClassName;
      final err = '$subjName already entered for Class $className';
      state = state.copyWith(errorMessage: err);
      return (false, err);
    }

    try {
      if (state.isEditMode) {
        // UPDATE existing mapping
        await db.rawUpdate(
          '''
          UPDATE Subj_Class
          SET SubjID = ?, TeacherID = ?, TotalMarks = ?, TotalPracticalMarks = ?
          WHERE Subj_ClsID = ?
        ''',
          [subjId, teacherId, theoryVal, pracVal, currentSubjClsId],
        );
      } else {
        // INSERT new mapping with MAX+1 surrogate key
        final maxRow = await db.rawQuery(
          'SELECT MAX(Subj_ClsID) as maxId FROM Subj_Class',
        );
        final nextId = ((maxRow.first['maxId'] as num?)?.toInt() ?? 0) + 1;

        await db.rawInsert(
          '''
          INSERT INTO Subj_Class (Subj_ClsID, SubjID, ClassID, TeacherID, TotalMarks, TotalPracticalMarks)
          VALUES (?, ?, ?, ?, ?, ?)
        ''',
          [nextId, subjId, classId, teacherId, theoryVal, pracVal],
        );
      }

      await loadMappingsForClass(classId);
      if (!mounted) return (true, 'Subject Assigned Successfully');
      resetForm();

      const successMsg = 'Subject Assigned Successfully';
      state = state.copyWith(toast: successMsg, clearErrorMessage: true);
      return (true, successMsg);
    } catch (e) {
      final err = 'Database error saving subject mapping: $e';
      if (mounted) {
        state = state.copyWith(errorMessage: err);
      }
      return (false, err);
    }
  }

  /// Removes subject mapping from `Subj_Class` (cmdRemove at 0x006fba50).
  Future<(bool, String)> deleteMapping(int subjClsId) async {
    try {
      final db = await _getDb();
      await db.delete(
        'Subj_Class',
        where: 'Subj_ClsID = ?',
        whereArgs: [subjClsId],
      );

      if (state.selectedClassId != null) {
        await loadMappingsForClass(state.selectedClassId!);
      }

      if (!mounted) return (true, ' Removed Sucessfully');

      if (state.editingMapping?.subjClsId == subjClsId) {
        resetForm();
      }

      const successMsg = ' Removed Sucessfully';
      state = state.copyWith(toast: successMsg, clearErrorMessage: true);
      return (true, successMsg);
    } catch (e) {
      final err = 'Failed to remove subject mapping: $e';
      if (mounted) {
        state = state.copyWith(errorMessage: err);
      }
      return (false, err);
    }
  }
}

final classSubjectMappingProvider =
    StateNotifierProvider<
      ClassSubjectMappingNotifier,
      ClassSubjectMappingState
    >((ref) => ClassSubjectMappingNotifier());
