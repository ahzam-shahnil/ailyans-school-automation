import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marks_entry_row.dart';
import '../db/database.dart';

/// Immutable UI state for MarksEntryScreen.
@immutable
class MarksEntryState {
  final String selectedSessionYr;
  final int? selectedExTermId;
  final int? selectedExamInfoId;
  final int? selectedClassId;
  final int? selectedClassSecId;
  final int? selectedSubjId;

  final int theoryMax;
  final int practicalMax;
  final String? subjectTeacher;

  final List<MarksEntryRow> roster;
  final List<Map<String, dynamic>> exGradeRows;

  final List<String> sessionYears;
  final List<Map<String, dynamic>> terms;
  final List<Map<String, dynamic>> examInfos;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> subjects;

  final bool isLoading;
  final bool isSaving;
  final String? toast;
  final String? errorMessage;

  const MarksEntryState({
    this.selectedSessionYr = '2017-2018',
    this.selectedExTermId,
    this.selectedExamInfoId,
    this.selectedClassId,
    this.selectedClassSecId,
    this.selectedSubjId,
    this.theoryMax = 100,
    this.practicalMax = 0,
    this.subjectTeacher,
    this.roster = const [],
    this.exGradeRows = const [],
    this.sessionYears = const [],
    this.terms = const [],
    this.examInfos = const [],
    this.classes = const [],
    this.sections = const [],
    this.subjects = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.toast,
    this.errorMessage,
  });

  MarksEntryState copyWith({
    String? selectedSessionYr,
    int? selectedExTermId,
    bool clearExTermId = false,
    int? selectedExamInfoId,
    bool clearExamInfoId = false,
    int? selectedClassId,
    bool clearClassId = false,
    int? selectedClassSecId,
    bool clearClassSecId = false,
    int? selectedSubjId,
    bool clearSubjId = false,
    int? theoryMax,
    int? practicalMax,
    String? subjectTeacher,
    bool clearSubjectTeacher = false,
    List<MarksEntryRow>? roster,
    List<Map<String, dynamic>>? exGradeRows,
    List<String>? sessionYears,
    List<Map<String, dynamic>>? terms,
    List<Map<String, dynamic>>? examInfos,
    List<Map<String, dynamic>>? classes,
    List<Map<String, dynamic>>? sections,
    List<Map<String, dynamic>>? subjects,
    bool? isLoading,
    bool? isSaving,
    String? toast,
    bool clearToast = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MarksEntryState(
      selectedSessionYr: selectedSessionYr ?? this.selectedSessionYr,
      selectedExTermId: clearExTermId
          ? null
          : (selectedExTermId ?? this.selectedExTermId),
      selectedExamInfoId: clearExamInfoId
          ? null
          : (selectedExamInfoId ?? this.selectedExamInfoId),
      selectedClassId: clearClassId
          ? null
          : (selectedClassId ?? this.selectedClassId),
      selectedClassSecId: clearClassSecId
          ? null
          : (selectedClassSecId ?? this.selectedClassSecId),
      selectedSubjId: clearSubjId
          ? null
          : (selectedSubjId ?? this.selectedSubjId),
      theoryMax: theoryMax ?? this.theoryMax,
      practicalMax: practicalMax ?? this.practicalMax,
      subjectTeacher: clearSubjectTeacher
          ? null
          : (subjectTeacher ?? this.subjectTeacher),
      roster: roster ?? this.roster,
      exGradeRows: exGradeRows ?? this.exGradeRows,
      sessionYears: sessionYears ?? this.sessionYears,
      terms: terms ?? this.terms,
      examInfos: examInfos ?? this.examInfos,
      classes: classes ?? this.classes,
      sections: sections ?? this.sections,
      subjects: subjects ?? this.subjects,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      toast: clearToast ? null : (toast ?? this.toast),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller for MarksEntryScreen managing database transactions,
/// validation gates, cohort loading, and inline marks adjustments.
class MarksEntryNotifier extends StateNotifier<MarksEntryState> {
  MarksEntryNotifier() : super(const MarksEntryState());

  void clearToast() {
    if (state.toast != null) {
      state = state.copyWith(clearToast: true);
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Initial load of dropdown metadata (sessions, terms, classes).
  Future<void> loadInitialData() async {
    state = state.copyWith(clearError: true);
    try {
      final db = await DatabaseService.instance.database;

      // 1. Session Years
      final yrRows = await db.rawQuery(
        'SELECT DISTINCT SessionYr FROM Student_Class ORDER BY SessionYr DESC',
      );
      final years = yrRows
          .map((r) => r['SessionYr'] as String?)
          .whereType<String>()
          .toList();
      final defaultYr = years.isNotEmpty
          ? years.first
          : (state.selectedSessionYr.isNotEmpty
                ? state.selectedSessionYr
                : '2017-2018');

      // 2. Exam Terms
      final termRows = await db.rawQuery(
        'SELECT ExTermID, TermName, TermRemarks FROM ExamTerm ORDER BY ExTermID ASC',
      );

      // 3. Classes
      final classRows = await db.rawQuery(
        'SELECT ClassID, CName FROM Class ORDER BY ClassID DESC',
      );

      if (!mounted) return;
      state = state.copyWith(
        sessionYears: years.isNotEmpty ? years : [defaultYr],
        selectedSessionYr: defaultYr,
        terms: termRows,
        classes: classRows,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load initial exam data: $e',
      );
    }
  }

  /// Changes the academic session year.
  Future<void> setSessionYr(String yr) async {
    state = state.copyWith(selectedSessionYr: yr, roster: [], clearError: true);
    if (state.selectedExTermId != null) {
      await _loadExamInfosForTerm(state.selectedExTermId!);
    }
  }

  /// Selects an examination term and loads associated ExamInfo entries.
  Future<void> setExTermId(int termId) async {
    state = state.copyWith(
      selectedExTermId: termId,
      clearExamInfoId: true,
      clearError: true,
    );
    await _loadExamInfosForTerm(termId);
  }

  Future<void> _loadExamInfosForTerm(int termId) async {
    try {
      final db = await DatabaseService.instance.database;
      final infos = await db.rawQuery(
        'SELECT ExamInfoID, ExTermID, SessionYR, StartDate, EndDate, ResultDate, Detail '
        'FROM ExamInfo WHERE ExTermID = ? ORDER BY ExamInfoID ASC',
        [termId],
      );

      int? autoSelectId;
      if (infos.isNotEmpty) {
        // Prefer matching SessionYR if available, else first
        final matching = infos.firstWhere(
          (r) => r['SessionYR'] == state.selectedSessionYr,
          orElse: () => infos.first,
        );
        autoSelectId = (matching['ExamInfoID'] as num?)?.toInt();
      }

      state = state.copyWith(
        examInfos: infos,
        selectedExamInfoId: autoSelectId,
        clearExamInfoId: autoSelectId == null,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to load ExamInfo records: $e',
      );
    }
  }

  /// Selects an ExamInfo ID.
  void setExamInfoId(int infoId) {
    state = state.copyWith(selectedExamInfoId: infoId, clearError: true);
  }

  /// Selects a target Class, loading sections, subjects, and grade scales.
  Future<void> setClassId(int classId) async {
    state = state.copyWith(
      selectedClassId: classId,
      clearClassSecId: true,
      clearSubjId: true,
      clearSubjectTeacher: true,
      roster: [],
      clearError: true,
    );

    try {
      final db = await DatabaseService.instance.database;

      // 1. Sections
      final sections = await db.rawQuery(
        'SELECT ClassSecID, ClassID, SecName FROM ClassSec WHERE ClassID = ? ORDER BY SecName ASC',
        [classId],
      );

      // 2. Grade scales (CalssID verbatim typo)
      final grades = await db.rawQuery(
        'SELECT ExGradID, CalssID, Grad, GradMinMarks, GradMaxMarks, Remarks '
        'FROM ExGrade WHERE CalssID = ? ORDER BY GradMinMarks DESC',
        [classId],
      );

      // 3. Subjects mapped for this class
      final subjects = await db.rawQuery(
        '''
        SELECT sc.SubjID, s.SubjName, sc.TotalMarks, sc.TotalPracticalMarks, sc.TeacherID, t.TName AS teacherName
        FROM Subj_Class sc
        JOIN Subject s ON s.SubjID = sc.SubjID
        LEFT JOIN Teachers t ON t.TeacherID = sc.TeacherID
        WHERE sc.ClassID = ?
        ORDER BY sc.SubjID ASC
        ''',
        [classId],
      );

      String? errorMsg;
      if (subjects.isEmpty) {
        final className = state.classes.firstWhere(
          (c) => c['ClassID'] == classId,
          orElse: () => {'CName': 'Class $classId'},
        )['CName'];
        errorMsg =
            'Subjects Not Defined for Class $className. Press - Shift + F1 - to define.';
      }

      state = state.copyWith(
        sections: sections,
        exGradeRows: grades,
        subjects: subjects,
        errorMessage: errorMsg,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to load class configuration: $e',
      );
    }
  }

  /// Selects a target Section.
  void setClassSecId(int? secId) {
    state = state.copyWith(
      selectedClassSecId: secId,
      roster: [],
      clearError: true,
    );
  }

  /// Selects an examination Subject and configures Theory and Practical limits.
  void setSubjId(int? subjId) {
    if (subjId == null) {
      state = state.copyWith(
        clearSubjId: true,
        theoryMax: 100,
        practicalMax: 0,
        clearSubjectTeacher: true,
        clearError: true,
      );
      return;
    }

    final match = state.subjects.firstWhere(
      (s) => s['SubjID'] == subjId,
      orElse: () => <String, dynamic>{},
    );

    final tMax = (match['TotalMarks'] as num?)?.toInt() ?? 100;
    final pMax = (match['TotalPracticalMarks'] as num?)?.toInt() ?? 0;
    final tTeacher = match['teacherName'] as String?;

    // Update roster row max values if roster is already loaded
    final updatedRoster = state.roster.map((r) {
      return r.copyWith(theoryMax: tMax, practicalMax: pMax);
    }).toList();

    state = state.copyWith(
      selectedSubjId: subjId,
      theoryMax: tMax,
      practicalMax: pMax,
      subjectTeacher: tTeacher,
      clearSubjectTeacher: tTeacher == null,
      roster: updatedRoster,
      clearError: true,
    );
  }

  /// Queries enrolled students matching selected Class, Section, and SessionYr.
  Future<void> loadEnrolledStudents() async {
    final classId = state.selectedClassId;
    final classSecId = state.selectedClassSecId;
    final sessionYr = state.selectedSessionYr;

    if (classId == null || classSecId == null || sessionYr.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please select Class, Section, and Session Year first.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT sc.Stu_RegID, sc.ClassRollNo, sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name
        FROM Student_Class sc
        JOIN Stu_Reg sr ON sr.Stu_RegID = sc.Stu_RegID
        WHERE sc.ClassID = ? AND sc.ClassSecID = ? AND sc.SessionYr = ? AND sc.Present = 1
        ORDER BY sc.ClassRollNo ASC
        ''',
        [classId, classSecId, sessionYr],
      );

      if (rows.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          roster: [],
          errorMessage: ' No of Students Found 0 ',
        );
        return;
      }

      final examInfoId = state.selectedExamInfoId;
      final newRoster = <MarksEntryRow>[];

      for (final r in rows) {
        final stuRegId = r['Stu_RegID'] as int;
        int? examMasId;

        if (examInfoId != null) {
          final masRows = await db.rawQuery(
            'SELECT ExamMasID FROM ExamMas WHERE ExamInfoID = ? AND Stu_RegID = ? LIMIT 1',
            [examInfoId, stuRegId],
          );
          if (masRows.isNotEmpty) {
            examMasId = (masRows.first['ExamMasID'] as num?)?.toInt();
          }
        }

        newRoster.add(
          MarksEntryRow(
            stuRegId: stuRegId,
            rollNo: (r['ClassRollNo'] as num?)?.toInt() ?? 0,
            nameFirst: (r['NameFirst'] as String? ?? '').trim(),
            nameMiddle: (r['NameMiddle'] as String?)?.trim(),
            nameLast: (r['NameLast'] as String? ?? '').trim(),
            fatherName: (r['F_Name'] as String?)?.trim(),
            theoryMax: state.theoryMax,
            practicalMax: state.practicalMax,
            isSelected: true,
            examMasId: examMasId,
          ),
        );
      }

      state = state.copyWith(isLoading: false, roster: newRoster);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load students: $e',
      );
    }
  }

  /// Creates ExamMas master records for loaded students if not present.
  Future<void> generateExamCohort() async {
    if (state.roster.isEmpty) {
      state = state.copyWith(toast: 'Load class students for Marks');
      return;
    }
    final examInfoId = state.selectedExamInfoId;
    if (examInfoId == null) {
      state = state.copyWith(toast: 'Select Valid Exam');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = await DatabaseService.instance.database;
      final termId = state.selectedExTermId ?? 1;
      final classId = state.selectedClassId ?? 0;
      final classSecId = state.selectedClassSecId ?? 0;
      final sessionYr = state.selectedSessionYr;

      int existingCnt = 0;
      int newCnt = 0;
      final updatedRoster = <MarksEntryRow>[];

      await db.transaction((txn) async {
        for (final row in state.roster) {
          final masCheck = await txn.rawQuery(
            'SELECT ExamMasID FROM ExamMas WHERE ExamInfoID = ? AND Stu_RegID = ? LIMIT 1',
            [examInfoId, row.stuRegId],
          );

          if (masCheck.isNotEmpty) {
            existingCnt++;
            final masId = (masCheck.first['ExamMasID'] as num).toInt();
            updatedRoster.add(row.copyWith(examMasId: masId));
          } else {
            final maxRow = await txn.rawQuery(
              'SELECT COALESCE(MAX(ExamMasID), 0) + 1 AS nextId FROM ExamMas',
            );
            final nextId = (maxRow.first['nextId'] as num).toInt();

            await txn.insert('ExamMas', {
              'ExamMasID': nextId,
              'ExamInfoID': examInfoId,
              'ExTermID': termId,
              'ClassID': classId,
              'ClassSecID': classSecId,
              'Stu_RegID': row.stuRegId,
              'TeacherID': 1,
              'Detail': '-',
              'SessionYr': sessionYr,
            });

            newCnt++;
            updatedRoster.add(row.copyWith(examMasId: nextId));
          }
        }
      });

      state = state.copyWith(
        isLoading: false,
        roster: updatedRoster,
        toast: 'Already exist = $existingCnt. New Students Added= $newCnt',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to generate exam cohort: $e',
      );
    }
  }

  /// Loads already recorded marks from ExamDet for the selected Subject.
  Future<void> loadExistingMarks() async {
    final examInfoId = state.selectedExamInfoId;
    final classId = state.selectedClassId;
    final classSecId = state.selectedClassSecId;
    final subjId = state.selectedSubjId;

    if (subjId == null) {
      state = state.copyWith(errorMessage: 'Choose Subject please');
      return;
    }
    if (examInfoId == null) {
      state = state.copyWith(errorMessage: 'Select Valid Exam');
      return;
    }
    if (classId == null || classSecId == null) {
      state = state.copyWith(
        errorMessage: 'Please select Class and Section first.',
      );
      return;
    }

    if (state.roster.isEmpty) {
      await loadEnrolledStudents();
    }
    if (state.roster.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = await DatabaseService.instance.database;
      final updatedRoster = <MarksEntryRow>[];

      for (final row in state.roster) {
        int? masId = row.examMasId;
        if (masId == null) {
          final masRows = await db.rawQuery(
            'SELECT ExamMasID FROM ExamMas WHERE ExamInfoID = ? AND Stu_RegID = ? LIMIT 1',
            [examInfoId, row.stuRegId],
          );
          if (masRows.isNotEmpty) {
            masId = (masRows.first['ExamMasID'] as num?)?.toInt();
          }
        }

        if (masId != null) {
          final detRows = await db.rawQuery(
            'SELECT ExDetID, ObtainedMarks, TotalMarks, ObtainedPracMarks, TotalPracticalMarks '
            'FROM ExamDet WHERE ExamMasID = ? AND SubjID = ? LIMIT 1',
            [masId, subjId],
          );

          if (detRows.isNotEmpty) {
            final det = detRows.first;
            final tObt = (det['ObtainedMarks'] as num?)?.toDouble();
            final pObt = (det['ObtainedPracMarks'] as num?)?.toDouble();
            final isAbs = (tObt == 0.0 && (pObt == null || pObt == 0.0));

            updatedRoster.add(
              row.copyWith(
                examMasId: masId,
                exDetId: (det['ExDetID'] as num?)?.toInt(),
                theoryObtained: tObt,
                practicalObtained: pObt,
                persistedTheory: tObt,
                persistedPractical: pObt,
                isAbsent: isAbs,
              ),
            );
            continue;
          }
        }

        updatedRoster.add(row.copyWith(examMasId: masId));
      }

      state = state.copyWith(isLoading: false, roster: updatedRoster);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load existing marks: $e',
      );
    }
  }

  /// Updates theory marks for a student.
  void updateTheory(int stuRegId, double? value) {
    final updated = state.roster.map((r) {
      if (r.stuRegId == stuRegId) {
        return r.copyWith(
          theoryObtained: value,
          clearTheoryObtained: value == null,
          isAbsent: false,
        );
      }
      return r;
    }).toList();
    state = state.copyWith(roster: updated);
  }

  /// Updates practical marks for a student.
  void updatePractical(int stuRegId, double? value) {
    final updated = state.roster.map((r) {
      if (r.stuRegId == stuRegId) {
        return r.copyWith(
          practicalObtained: value,
          clearPracticalObtained: value == null,
          isAbsent: false,
        );
      }
      return r;
    }).toList();
    state = state.copyWith(roster: updated);
  }

  /// Toggles absent status; zeroes marks when absent.
  void toggleAbsent(int stuRegId) {
    final updated = state.roster.map((r) {
      if (r.stuRegId == stuRegId) {
        final willBeAbsent = !r.isAbsent;
        return r.copyWith(
          isAbsent: willBeAbsent,
          theoryObtained: willBeAbsent ? 0.0 : r.theoryObtained,
          practicalObtained: willBeAbsent ? 0.0 : r.practicalObtained,
        );
      }
      return r;
    }).toList();
    state = state.copyWith(roster: updated);
  }

  /// Toggles select all rows.
  void toggleSelectAll() {
    final allSelected = state.roster.every((r) => r.isSelected);
    final updated = state.roster.map((r) {
      return r.copyWith(isSelected: !allSelected);
    }).toList();
    state = state.copyWith(roster: updated);
  }

  /// Toggles selection of a single row.
  void toggleRowSelect(int stuRegId) {
    final updated = state.roster.map((r) {
      if (r.stuRegId == stuRegId) {
        return r.copyWith(isSelected: !r.isSelected);
      }
      return r;
    }).toList();
    state = state.copyWith(roster: updated);
  }

  /// Checks if marks already exist for this cohort and subject in ExamDet.
  Future<bool> hasExistingMarks() async {
    final examInfoId = state.selectedExamInfoId;
    final classId = state.selectedClassId;
    final classSecId = state.selectedClassSecId;
    final subjId = state.selectedSubjId;

    if (examInfoId == null ||
        classId == null ||
        classSecId == null ||
        subjId == null) {
      return false;
    }

    try {
      final db = await DatabaseService.instance.database;
      final existing = await db.rawQuery(
        '''
        SELECT 1 FROM ExamMas em
        JOIN ExamDet ed ON em.ExamMasID = ed.ExamMasID
        WHERE em.ExamInfoID = ? AND em.ClassID = ? AND em.ClassSecID = ? AND ed.SubjID = ?
        LIMIT 1
        ''',
        [examInfoId, classId, classSecId, subjId],
      );
      return existing.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Saves entered marks to ExamDet for all selected students.
  Future<bool> saveAllMarks({bool overwriteConfirmed = false}) async {
    // Gate 1: Subject must be chosen
    if (state.selectedSubjId == null) {
      state = state.copyWith(errorMessage: 'Choose Subject please');
      return false;
    }

    // Gate 2: Exam must be valid
    final examInfoId = state.selectedExamInfoId;
    if (examInfoId == null) {
      state = state.copyWith(errorMessage: 'Select Valid Exam');
      return false;
    }

    // Gate 3: Roster must not be empty
    if (state.roster.isEmpty) {
      state = state.copyWith(errorMessage: 'Load class students for Marks');
      return false;
    }

    // Gate 4: At least one student selected
    final selectedRows = state.roster.where((r) => r.isSelected).toList();
    if (selectedRows.isEmpty) {
      state = state.copyWith(errorMessage: ' No Student Selected for Marks.');
      return false;
    }

    // Gate 5: Marks boundary checks
    for (final row in selectedRows) {
      if (!row.isAbsent) {
        if (row.theoryObtained != null &&
            (row.theoryObtained! < 0 ||
                row.theoryObtained! > state.theoryMax)) {
          state = state.copyWith(
            errorMessage:
                'Obtained marks for ${row.studentName} cannot exceed total marks (${state.theoryMax})',
          );
          return false;
        }
        if (row.practicalObtained != null &&
            (row.practicalObtained! < 0 ||
                row.practicalObtained! > state.practicalMax)) {
          state = state.copyWith(
            errorMessage:
                'Practical marks for ${row.studentName} cannot exceed total practical marks (${state.practicalMax})',
          );
          return false;
        }
      }
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final db = await DatabaseService.instance.database;
      final termId = state.selectedExTermId ?? 1;
      final classId = state.selectedClassId ?? 0;
      final classSecId = state.selectedClassSecId ?? 0;
      final sessionYr = state.selectedSessionYr;
      final subjId = state.selectedSubjId!;

      int enteredCnt = 0;
      int updatedCnt = 0;
      int absentCnt = 0;

      final updatedRosterMap = <int, MarksEntryRow>{};

      await db.transaction((txn) async {
        for (final row in selectedRows) {
          // 1. Ensure ExamMas exists for student
          int masId;
          if (row.examMasId != null) {
            masId = row.examMasId!;
          } else {
            final masRows = await txn.rawQuery(
              'SELECT ExamMasID FROM ExamMas WHERE ExamInfoID = ? AND Stu_RegID = ? LIMIT 1',
              [examInfoId, row.stuRegId],
            );
            if (masRows.isNotEmpty) {
              masId = (masRows.first['ExamMasID'] as num).toInt();
            } else {
              final maxMas = await txn.rawQuery(
                'SELECT COALESCE(MAX(ExamMasID), 0) + 1 AS nextId FROM ExamMas',
              );
              masId = (maxMas.first['nextId'] as num).toInt();
              await txn.insert('ExamMas', {
                'ExamMasID': masId,
                'ExamInfoID': examInfoId,
                'ExTermID': termId,
                'ClassID': classId,
                'ClassSecID': classSecId,
                'Stu_RegID': row.stuRegId,
                'TeacherID': 1,
                'Detail': '-',
                'SessionYr': sessionYr,
              });
            }
          }

          final theoryVal = row.isAbsent ? 0.0 : (row.theoryObtained ?? 0.0);
          final pracVal = row.isAbsent ? 0.0 : (row.practicalObtained ?? 0.0);

          // 2. Check if ExamDet exists
          final detCheck = await txn.rawQuery(
            'SELECT ExDetID FROM ExamDet WHERE ExamMasID = ? AND SubjID = ? LIMIT 1',
            [masId, subjId],
          );

          int detId;
          if (detCheck.isNotEmpty) {
            detId = (detCheck.first['ExDetID'] as num).toInt();
            await txn.update(
              'ExamDet',
              {
                'ObtainedMarks': theoryVal,
                'TotalMarks': state.theoryMax,
                'ObtainedPracMarks': pracVal,
                'TotalPracticalMarks': state.practicalMax,
              },
              where: 'ExamMasID = ? AND SubjID = ?',
              whereArgs: [masId, subjId],
            );

            if (theoryVal != row.persistedTheory ||
                pracVal != row.persistedPractical) {
              updatedCnt++;
            }
          } else {
            final maxDet = await txn.rawQuery(
              'SELECT COALESCE(MAX(ExDetID), 0) + 1 AS nextId FROM ExamDet',
            );
            detId = (maxDet.first['nextId'] as num).toInt();

            await txn.insert('ExamDet', {
              'ExDetID': detId,
              'ExamInfoID': examInfoId,
              'ExamMasID': masId,
              'SubjID': subjId,
              'ObtainedMarks': theoryVal,
              'TotalMarks': state.theoryMax,
              'ObtainedPracMarks': pracVal,
              'TotalPracticalMarks': state.practicalMax,
            });
            enteredCnt++;
          }

          if (row.isAbsent) {
            absentCnt++;
          }

          updatedRosterMap[row.stuRegId] = row.copyWith(
            examMasId: masId,
            exDetId: detId,
            theoryObtained: theoryVal,
            practicalObtained: pracVal,
            persistedTheory: theoryVal,
            persistedPractical: pracVal,
          );
        }
      });

      // Update in-memory roster
      final newRoster = state.roster.map((r) {
        return updatedRosterMap[r.stuRegId] ?? r;
      }).toList();

      state = state.copyWith(
        isSaving: false,
        roster: newRoster,
        toast:
            'You Selected ${selectedRows.length} Students. Marks Entered for $enteredCnt Students and Marks Changed for $updatedCnt Students not appeared are $absentCnt',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save marks: $e',
      );
      return false;
    }
  }
}

final marksEntryProvider =
    StateNotifierProvider<MarksEntryNotifier, MarksEntryState>((ref) {
      return MarksEntryNotifier();
    });
