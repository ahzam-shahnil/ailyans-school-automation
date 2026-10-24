import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/attendance_roster_row.dart';
import '../db/database.dart';
import 'session_provider.dart';
import 'shell_metadata_provider.dart';

/// Immutable state for the daily attendance workflow.
@immutable
class AttendanceState {
  final int? selectedClassId;
  final int? selectedClassSecId;
  final DateTime selectedDate;
  final int? selectedTeacherId;
  final String sessionYear;
  final List<AttendanceRosterRow> roster;
  final bool isLoading;
  final bool isEditMode;
  final int? existingAttMasId;
  final String? toast;
  final String? errorMessage;
  final Map<String, int> summaryCounts;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> teachers;

  const AttendanceState({
    this.selectedClassId,
    this.selectedClassSecId,
    required this.selectedDate,
    this.selectedTeacherId,
    required this.sessionYear,
    this.roster = const [],
    this.isLoading = false,
    this.isEditMode = false,
    this.existingAttMasId,
    this.toast,
    this.errorMessage,
    this.summaryCounts = const {
      'Present': 0,
      'Absent': 0,
      'Leave': 0,
      'Late': 0,
    },
    this.classes = const [],
    this.sections = const [],
    this.teachers = const [],
  });

  factory AttendanceState.initial({
    List<Map<String, dynamic>> classes = const [],
    List<Map<String, dynamic>> sections = const [],
    List<Map<String, dynamic>> teachers = const [],
    String sessionYear = '2017-2018',
  }) {
    return AttendanceState(
      selectedDate: DateTime.now(),
      sessionYear: sessionYear,
      classes: classes,
      sections: sections,
      teachers: teachers,
    );
  }

  AttendanceState copyWith({
    int? selectedClassId,
    int? selectedClassSecId,
    DateTime? selectedDate,
    int? selectedTeacherId,
    String? sessionYear,
    List<AttendanceRosterRow>? roster,
    bool? isLoading,
    bool? isEditMode,
    int? existingAttMasId,
    String? toast,
    String? errorMessage,
    Map<String, int>? summaryCounts,
    List<Map<String, dynamic>>? classes,
    List<Map<String, dynamic>>? sections,
    List<Map<String, dynamic>>? teachers,
    bool clearToast = false,
    bool clearErrorMessage = false,
    bool clearTeacher = false,
    bool clearSection = false,
  }) {
    return AttendanceState(
      selectedClassId: selectedClassId ?? this.selectedClassId,
      selectedClassSecId: clearSection
          ? null
          : (selectedClassSecId ?? this.selectedClassSecId),
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTeacherId: clearTeacher
          ? null
          : (selectedTeacherId ?? this.selectedTeacherId),
      sessionYear: sessionYear ?? this.sessionYear,
      roster: roster ?? this.roster,
      isLoading: isLoading ?? this.isLoading,
      isEditMode: isEditMode ?? this.isEditMode,
      existingAttMasId: existingAttMasId ?? this.existingAttMasId,
      toast: clearToast ? null : (toast ?? this.toast),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      summaryCounts: summaryCounts ?? this.summaryCounts,
      classes: classes ?? this.classes,
      sections: sections ?? this.sections,
      teachers: teachers ?? this.teachers,
    );
  }
}

/// StateNotifier managing class attendance roll call, validation, and persistence.
class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final Ref ref;

  AttendanceNotifier(this.ref) : super(AttendanceState.initial()) {
    final metaSession =
        ref.read(shellMetadataProvider).value?.sessionYear ?? '2017-2018';
    state = state.copyWith(sessionYear: metaSession);
  }

  /// Injects a specific calendar date for testing edit-mode against historical AttMas records.
  @visibleForTesting
  void debugSelectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    if (state.selectedClassId != null && state.selectedClassSecId != null) {
      loadRoster();
    }
  }

  void setTeacher(int? teacherId) {
    state = state.copyWith(
      selectedTeacherId: teacherId,
      clearTeacher: teacherId == null,
    );
  }

  void clearToast() {
    state = state.copyWith(clearToast: true);
  }

  /// Discards unsaved edits and clears the roster back to the state
  /// derived from the last saved AttMas (if any) or to empty (if none).
  /// Does NOT clear class/section/date selection — the user is cancelling
  /// their in-progress edits, not their filter choices.
  void discardEdits() {
    if (state.selectedClassId == null || state.selectedClassSecId == null) {
      return;
    }
    loadRoster(
      classId: state.selectedClassId!,
      classSecId: state.selectedClassSecId!,
      date: state.selectedDate,
      teacherId: state.selectedTeacherId,
    );
  }

  /// Full clear — used when nothing is loaded and user clicks Cancel.
  void clearSelection() {
    state = AttendanceState.initial(
      classes: state.classes,
      sections: state.sections,
      teachers: state.teachers,
      sessionYear: state.sessionYear,
    );
  }

  /// Loads available academic classes ordered by ClassID DESC.
  Future<List<Map<String, dynamic>>> loadClasses() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT ClassID, CName FROM Class ORDER BY ClassID DESC',
    );
    if (mounted) {
      state = state.copyWith(classes: rows);
    }
    return rows;
  }

  /// Loads sections for a specific class.
  Future<List<Map<String, dynamic>>> loadSectionsForClass(int classId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT ClassSecID, ClassID, SecName, SecTeacher FROM ClassSec WHERE ClassID = ? ORDER BY SecName',
      [classId],
    );
    if (mounted) {
      state = state.copyWith(
        selectedClassId: classId,
        sections: rows,
        clearSection: true,
        clearTeacher: true,
        roster: [],
        isEditMode: false,
        existingAttMasId: null,
        summaryCounts: const {'Present': 0, 'Absent': 0, 'Leave': 0, 'Late': 0},
      );
    }
    return rows;
  }

  /// Returns the SecTeacher defined on the section or null if unassigned.
  Future<int?> loadDefaultTeacherForSection(int classSecId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT SecTeacher FROM ClassSec WHERE ClassSecID = ? LIMIT 1',
      [classSecId],
    );
    if (rows.isNotEmpty) {
      final t = rows.first['SecTeacher'] as int?;
      if (t != null && t > 0) return t;
    }
    return null;
  }

  /// Loads all teachers for the teacher dropdown.
  Future<List<Map<String, dynamic>>> loadTeachers() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT TeacherID, TName FROM Teachers ORDER BY TName ASC',
    );
    if (mounted) {
      state = state.copyWith(teachers: rows);
    }
    return rows;
  }

  /// Sequentially loads initial dropdown data to prevent concurrent SQLite lock timeouts.
  Future<void> loadInitialData() async {
    await loadClasses();
    await loadTeachers();
  }

  /// Sets the selected section, auto-resolves incharge teacher, and loads roster.
  Future<void> selectSection(int classSecId) async {
    final defaultTeacher = await loadDefaultTeacherForSection(classSecId);
    state = state.copyWith(
      selectedClassSecId: classSecId,
      selectedTeacherId: defaultTeacher,
      clearTeacher: defaultTeacher == null,
    );
    await loadRoster();
  }

  /// Loads attendance roster. Checks composite PK (ClassID, ClassSecID, DATE(AttDate)).
  Future<void> loadRoster({
    int? classId,
    int? classSecId,
    DateTime? date,
    int? teacherId,
  }) async {
    final targetClassId = classId ?? state.selectedClassId;
    final targetSecId = classSecId ?? state.selectedClassSecId;
    final targetDate = date ?? state.selectedDate;

    if (targetClassId == null || targetSecId == null) {
      return;
    }

    state = state.copyWith(isLoading: true, clearToast: true);

    try {
      final db = await DatabaseService.instance.database;
      final dateStr =
          '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      // 1. Check if attendance already recorded today for this cohort
      final existingHeader = await db.rawQuery(
        'SELECT AttMasID, TeacherID, Remarks, StudySessionYr FROM AttMas WHERE ClassID = ? AND ClassSecID = ? AND DATE(AttDate) = ? LIMIT 1',
        [targetClassId, targetSecId, dateStr],
      );

      final List<AttendanceRosterRow> loadedRoster = [];

      if (existingHeader.isNotEmpty) {
        // Edit Mode: record already exists
        final masId = existingHeader.first['AttMasID'] as int;
        final headerTeacher = existingHeader.first['TeacherID'] as int?;

        final detailRows = await db.rawQuery(
          '''
          SELECT sc.Stu_RegID, sc.ClassRollNo, s.NameFirst, s.NameMiddle, s.NameLast, s.F_Name,
                 ad.AttStatus, ad.InTime, ad.OutTime, ad.AttAppcation, ad.LeaveRequestedBy,
                 ad.LFrom, ad.LTill, ad.Reason, ad.IsApproved, ad.AttRemarks
          FROM Student_Class sc
          JOIN Stu_Reg s ON s.Stu_RegID = sc.Stu_RegID
          LEFT JOIN AttDet ad ON ad.Stu_RegID = sc.Stu_RegID AND ad.AttMasID = ?
          WHERE sc.ClassID = ? AND sc.ClassSecID = ? AND sc.Present = 1
          ORDER BY sc.ClassRollNo ASC
          ''',
          [masId, targetClassId, targetSecId],
        );

        for (final row in detailRows) {
          loadedRoster.add(
            AttendanceRosterRow(
              stuRegId: row['Stu_RegID'] as int,
              rollNo: (row['ClassRollNo'] as int?) ?? 0,
              nameFirst: (row['NameFirst'] as String?) ?? '',
              nameMiddle: (row['NameMiddle'] as String?) ?? '',
              nameLast: (row['NameLast'] as String?) ?? '',
              fatherName: (row['F_Name'] as String?) ?? '',
              currentStatus: (row['AttStatus'] as String?)?.isNotEmpty == true
                  ? row['AttStatus'] as String
                  : 'Present',
              inTime: row['InTime'] as String?,
              outTime: row['OutTime'] as String?,
              attRemarks: row['AttRemarks'] as String?,
              leaveRequestedBy: row['LeaveRequestedBy'] as String?,
              lFrom: row['LFrom'] as String?,
              lTill: row['LTill'] as String?,
              reason: row['Reason'] as String?,
              attAppcation: row['AttAppcation'] as String?,
              isApproved: row['IsApproved'] as String?,
            ),
          );
        }

        state = state.copyWith(
          isLoading: false,
          isEditMode: true,
          existingAttMasId: masId,
          selectedTeacherId: headerTeacher ?? state.selectedTeacherId,
          roster: loadedRoster,
          summaryCounts: _computeSummaryCounts(loadedRoster),
        );
      } else {
        // New Attendance Entry: load enrolled active students
        final rosterRows = await db.rawQuery(
          '''
          SELECT sc.Stu_RegID, sc.ClassRollNo, s.NameFirst, s.NameMiddle, s.NameLast, s.F_Name
          FROM Student_Class sc
          JOIN Stu_Reg s ON s.Stu_RegID = sc.Stu_RegID
          WHERE sc.ClassID = ? AND sc.ClassSecID = ? AND sc.Present = 1
          ORDER BY sc.ClassRollNo ASC
          ''',
          [targetClassId, targetSecId],
        );

        for (final row in rosterRows) {
          loadedRoster.add(
            AttendanceRosterRow(
              stuRegId: row['Stu_RegID'] as int,
              rollNo: (row['ClassRollNo'] as int?) ?? 0,
              nameFirst: (row['NameFirst'] as String?) ?? '',
              nameMiddle: (row['NameMiddle'] as String?) ?? '',
              nameLast: (row['NameLast'] as String?) ?? '',
              fatherName: (row['F_Name'] as String?) ?? '',
              currentStatus: 'Present',
            ),
          );
        }

        state = state.copyWith(
          isLoading: false,
          isEditMode: false,
          existingAttMasId: null,
          roster: loadedRoster,
          summaryCounts: _computeSummaryCounts(loadedRoster),
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load attendance roster: $e',
      );
    }
  }

  /// Updates status for a single student row.
  void updateStudentStatus(int stuRegId, String newStatus) {
    final updated = state.roster.map((row) {
      if (row.stuRegId == stuRegId) {
        return row.copyWith(
          currentStatus: newStatus,
          // If status changes to Present or Late and inTime is blank, default to '08:00 AM'
          inTime: (newStatus == 'Present' || newStatus == 'Late')
              ? (row.inTime ?? '08:00 AM')
              : null,
          outTime: (newStatus == 'Present' || newStatus == 'Late')
              ? row.outTime
              : null,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(
      roster: updated,
      summaryCounts: _computeSummaryCounts(updated),
    );
  }

  /// Updates inline arrival / departure times for a student.
  void updateStudentTimes(int stuRegId, {String? inTime, String? outTime}) {
    final updated = state.roster.map((row) {
      if (row.stuRegId == stuRegId) {
        return row.copyWith(
          inTime: inTime ?? row.inTime,
          outTime: outTime ?? row.outTime,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(roster: updated);
  }

  /// Updates inline remarks for a student row.
  void updateStudentRemarks(int stuRegId, String remarks) {
    final updated = state.roster.map((row) {
      if (row.stuRegId == stuRegId) {
        return row.copyWith(attRemarks: remarks);
      }
      return row;
    }).toList();

    state = state.copyWith(roster: updated);
  }

  /// Updates detailed leave application fields for a student row.
  void updateStudentLeave({
    required int stuRegId,
    String? leaveRequestedBy,
    String? lFrom,
    String? lTill,
    String? reason,
    String? attAppcation,
    String? isApproved,
  }) {
    final updated = state.roster.map((row) {
      if (row.stuRegId == stuRegId) {
        return row.copyWith(
          leaveRequestedBy: leaveRequestedBy ?? row.leaveRequestedBy,
          lFrom: lFrom ?? row.lFrom,
          lTill: lTill ?? row.lTill,
          reason: reason ?? row.reason,
          attAppcation: attAppcation ?? row.attAppcation,
          isApproved: isApproved ?? row.isApproved,
        );
      }
      return row;
    }).toList();

    state = state.copyWith(roster: updated);
  }

  /// Bulk sets every student to the specified status.
  void markAllAs(String status) {
    final updated = state.roster.map((row) {
      return row.copyWith(
        currentStatus: status,
        inTime: (status == 'Present' || status == 'Late')
            ? (row.inTime ?? '08:00 AM')
            : null,
      );
    }).toList();

    state = state.copyWith(
      roster: updated,
      summaryCounts: _computeSummaryCounts(updated),
    );
  }

  /// Validates selection fields according to legacy VB6 specifications.
  String? validateSelection() {
    if (state.selectedClassId == null) {
      return 'Select Class';
    }
    if (state.selectedClassSecId == null) {
      return 'Select Section';
    }
    if (state.sessionYear.trim().isEmpty) {
      return 'Enter Studying Session Year';
    }
    return null;
  }

  /// Validates default section teacher according to legacy VB6 specifications.
  String? validateTeacher() {
    if (state.selectedClassSecId == null) return null;
    final section = state.sections.firstWhere(
      (s) => s['ClassSecID'] == state.selectedClassSecId,
      orElse: () => <String, dynamic>{},
    );
    final secTeacher = section['SecTeacher'] as int?;
    if ((secTeacher == null || secTeacher == 0) &&
        state.selectedTeacherId == null) {
      return 'No Default Teacher for Section, Select Other Section Teacher.';
    }
    return null;
  }

  /// Submits initial daily attendance (insert into AttMas and AttDet).
  Future<bool> submitAttendance() async {
    // 1. Role-level permission guard
    final userSession = ref.read(sessionProvider);
    if (userSession?.user.userLevel == 3) {
      state = state.copyWith(toast: "You don't have enough rights for purpose");
      return false;
    }

    // 2. Duplicate guard
    if (state.isEditMode) {
      state = state.copyWith(toast: 'Attandance Already done');
      return false;
    }

    // 3. Selection validation
    final selectionErr = validateSelection();
    if (selectionErr != null) {
      state = state.copyWith(toast: selectionErr);
      return false;
    }

    // 4. Teacher validation
    final teacherErr = validateTeacher();
    if (teacherErr != null) {
      state = state.copyWith(toast: teacherErr);
      return false;
    }

    // 5. Roster check
    if (state.roster.isEmpty) {
      state = state.copyWith(toast: 'No students enrolled in this section');
      return false;
    }

    state = state.copyWith(isLoading: true, clearToast: true);

    try {
      final db = await DatabaseService.instance.database;

      // Duplicate check against database directly
      final targetDate = state.selectedDate;
      final dateStr =
          '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      final existing = await db.rawQuery(
        'SELECT AttMasID FROM AttMas WHERE ClassID = ? AND ClassSecID = ? AND DATE(AttDate) = ? LIMIT 1',
        [state.selectedClassId, state.selectedClassSecId, dateStr],
      );

      if (existing.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          isEditMode: true,
          existingAttMasId: existing.first['AttMasID'] as int,
          toast: 'Attandance Already done',
        );
        return false;
      }

      // Next surrogate AttMasID
      final maxMasRow = await db.rawQuery(
        'SELECT COALESCE(MAX(AttMasID), 0) + 1 AS nextId FROM AttMas',
      );
      final nextMasId = maxMasRow.first['nextId'] as int;

      final now = DateTime.now();
      final attDateStr =
          '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      await db.transaction((txn) async {
        // Insert AttMas header
        await txn.insert('AttMas', {
          'AttMasID': nextMasId,
          'TeacherID': state.selectedTeacherId,
          'ClassID': state.selectedClassId,
          'ClassSecID': state.selectedClassSecId,
          'AttDate': attDateStr,
          'StudySessionYr': state.sessionYear,
          'Remarks': '',
        });

        // Insert AttDet rows
        final maxDetRow = await txn.rawQuery(
          'SELECT COALESCE(MAX(AttDetID), 0) + 1 AS nextId FROM AttDet',
        );
        var detId = maxDetRow.first['nextId'] as int;

        for (final row in state.roster) {
          await txn.insert('AttDet', {
            'AttDetID': detId++,
            'AttMasID': nextMasId,
            'Stu_RegID': row.stuRegId,
            'AttStatus': row.currentStatus,
            'InTime': row.inTime,
            'OutTime': row.outTime,
            'AttAppcation': row.attAppcation,
            'LeaveRequestedBy': row.leaveRequestedBy,
            'LFrom': row.lFrom,
            'LTill': row.lTill,
            'Reason': row.reason,
            'IsApproved': row.isApproved, // 'true' / 'false' / null (TEXT)
            'AttRemarks': row.attRemarks,
          });
        }
      });

      state = state.copyWith(
        isLoading: false,
        isEditMode: true,
        existingAttMasId: nextMasId,
        toast: 'Class Attandance Done',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to submit attendance: $e',
      );
      return false;
    }
  }

  /// Updates existing daily attendance (purges details and rewrites).
  Future<bool> updateAttendance() async {
    // 1. Role-level permission guard
    final userSession = ref.read(sessionProvider);
    if (userSession?.user.userLevel == 3) {
      state = state.copyWith(toast: "You don't have enough rights for purpose");
      return false;
    }

    if (!state.isEditMode || state.existingAttMasId == null) {
      state = state.copyWith(toast: 'No existing attendance record to update');
      return false;
    }

    // 2. Teacher validation
    final teacherErr = validateTeacher();
    if (teacherErr != null) {
      state = state.copyWith(toast: teacherErr);
      return false;
    }

    state = state.copyWith(isLoading: true, clearToast: true);

    try {
      final db = await DatabaseService.instance.database;
      final masId = state.existingAttMasId!;

      final targetDate = state.selectedDate;
      final now = DateTime.now();
      final attDateStr =
          '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      await db.transaction((txn) async {
        // Purge old detail rows
        await txn.delete('AttDet', where: 'AttMasID = ?', whereArgs: [masId]);

        // Update AttMas header timestamp and teacher
        await txn.update(
          'AttMas',
          {
            'TeacherID': state.selectedTeacherId,
            'AttDate': attDateStr,
            'StudySessionYr': state.sessionYear,
            'Remarks': '',
          },
          where: 'AttMasID = ?',
          whereArgs: [masId],
        );

        // Re-insert AttDet detail rows
        final maxDetRow = await txn.rawQuery(
          'SELECT COALESCE(MAX(AttDetID), 0) + 1 AS nextId FROM AttDet',
        );
        var detId = maxDetRow.first['nextId'] as int;

        for (final row in state.roster) {
          await txn.insert('AttDet', {
            'AttDetID': detId++,
            'AttMasID': masId,
            'Stu_RegID': row.stuRegId,
            'AttStatus': row.currentStatus,
            'InTime': row.inTime,
            'OutTime': row.outTime,
            'AttAppcation': row.attAppcation,
            'LeaveRequestedBy': row.leaveRequestedBy,
            'LFrom': row.lFrom,
            'LTill': row.lTill,
            'Reason': row.reason,
            'IsApproved': row.isApproved, // 'true' / 'false' / null (TEXT)
            'AttRemarks': row.attRemarks,
          });
        }
      });

      state = state.copyWith(
        isLoading: false,
        toast: 'Attandance Record Updated',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update attendance: $e',
      );
      return false;
    }
  }

  static Map<String, int> _computeSummaryCounts(
    List<AttendanceRosterRow> roster,
  ) {
    int present = 0;
    int absent = 0;
    int leave = 0;
    int late = 0;
    for (final r in roster) {
      switch (r.currentStatus) {
        case 'Present':
          present++;
          break;
        case 'Absent':
          absent++;
          break;
        case 'Leave':
          leave++;
          break;
        case 'Late':
          late++;
          break;
      }
    }
    return {'Present': present, 'Absent': absent, 'Leave': leave, 'Late': late};
  }
}

/// Global StateNotifierProvider for attendance workflow.
final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      return AttendanceNotifier(ref);
    });
