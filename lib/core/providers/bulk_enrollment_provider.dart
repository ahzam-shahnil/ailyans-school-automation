import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enrollment_row.dart';
import '../db/database.dart';

@immutable
class BulkEnrollmentState {
  final int? selectedClassId;
  final int? selectedSecId;
  final String selectedSessionYr;
  final List<String> availableSessions;
  final List<EnrollmentRow> roster;
  final bool isRosterLoaded;
  final bool isLoading;
  final String? errorMessage;

  const BulkEnrollmentState({
    this.selectedClassId,
    this.selectedSecId,
    this.selectedSessionYr = '2017-2018',
    this.availableSessions = const ['2026-27', '2025-26', '2017-2018'],
    this.roster = const [],
    this.isRosterLoaded = false,
    this.isLoading = false,
    this.errorMessage,
  });

  BulkEnrollmentState copyWith({
    int? Function()? selectedClassId,
    int? Function()? selectedSecId,
    String? selectedSessionYr,
    List<String>? availableSessions,
    List<EnrollmentRow>? roster,
    bool? isRosterLoaded,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return BulkEnrollmentState(
      selectedClassId: selectedClassId != null
          ? selectedClassId()
          : this.selectedClassId,
      selectedSecId: selectedSecId != null
          ? selectedSecId()
          : this.selectedSecId,
      selectedSessionYr: selectedSessionYr ?? this.selectedSessionYr,
      availableSessions: availableSessions ?? this.availableSessions,
      roster: roster ?? this.roster,
      isRosterLoaded: isRosterLoaded ?? this.isRosterLoaded,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class BulkEnrollmentNotifier extends StateNotifier<BulkEnrollmentState> {
  BulkEnrollmentNotifier() : super(const BulkEnrollmentState());

  void setClassId(int? classId) {
    if (state.selectedClassId == classId) return;
    state = state.copyWith(
      selectedClassId: () => classId,
      selectedSecId: () => null,
      isRosterLoaded: false,
      roster: const [],
      errorMessage: () => null,
    );
  }

  void setSecId(int? secId) {
    if (state.selectedSecId == secId) return;
    state = state.copyWith(
      selectedSecId: () => secId,
      isRosterLoaded: false,
      roster: const [],
      errorMessage: () => null,
    );
  }

  void setSessionYr(String sessionYr) {
    if (state.selectedSessionYr == sessionYr) return;
    state = state.copyWith(
      selectedSessionYr: sessionYr,
      isRosterLoaded: false,
      roster: const [],
      errorMessage: () => null,
    );
  }

  Future<(bool, String)> loadRoster() async {
    if (state.selectedClassId == null) {
      return (false, ' Select Class please');
    }
    if (state.selectedSecId == null) {
      return (false, 'Slect class Sec please');
    }
    if (state.selectedSessionYr.trim().isEmpty) {
      return (false, 'Select Session ');
    }

    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT
          sc.Stu_RegID,
          sc.ClassRollNo,
          sr.NameFirst,
          sr.NameLast,
          sr.F_Name,
          sc.Present,
          c.CName as class_name,
          cs.SecName as section_name,
          sc.SessionYr
        FROM Student_Class sc
        JOIN Stu_Reg sr ON sc.Stu_RegID = sr.Stu_RegID
        JOIN Class c ON sc.ClassID = c.ClassID
        LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
        WHERE sc.ClassID = ? AND sc.ClassSecID = ? AND sc.SessionYr = ?
        ORDER BY sc.ClassRollNo ASC, sc.Stu_RegID ASC
        ''',
        [state.selectedClassId, state.selectedSecId, state.selectedSessionYr],
      );

      final rosterList = rows.map(EnrollmentRow.fromMap).toList();
      state = state.copyWith(
        roster: rosterList,
        isRosterLoaded: true,
        isLoading: false,
      );
      return (true, 'Roster loaded');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString(),
      );
      return (false, 'Failed to load roster: $e');
    }
  }

  Future<(bool, String)> enrollStudent({
    required String regIdText,
    required String rollNoText,
  }) async {
    // 1. Sequential validation chain strictly matching S7 / 0x00426bf8
    if (state.selectedClassId == null) {
      return (false, ' Select Class please');
    }
    if (state.selectedSecId == null) {
      return (false, 'Slect class Sec please');
    }
    if (regIdText.trim().isEmpty) {
      return (false, 'Enter Student Registration ID');
    }
    if (state.selectedSessionYr.trim().isEmpty) {
      return (false, 'Select Session ');
    }
    if (rollNoText.trim().isEmpty) {
      return (false, 'Enter Student Class Roll No');
    }

    final regId = int.tryParse(regIdText.trim());
    if (regId == null || regId <= 0) {
      return (false, 'Registration ID not found');
    }

    final rollNo = int.tryParse(rollNoText.trim());
    if (rollNo == null || rollNo <= 0) {
      return (false, 'Enter Student Class Roll No');
    }

    try {
      final db = await DatabaseService.instance.database;

      // Check if student is already enrolled in this session
      final duplicateCheck = await db.rawQuery(
        'SELECT 1 FROM Student_Class WHERE Stu_RegID = ? AND SessionYr = ? LIMIT 1',
        [regId, state.selectedSessionYr],
      );

      if (duplicateCheck.isNotEmpty) {
        return (false, 'Student already added in Class Sec');
      }

      // Check if student exists in registration master
      final regCheck = await db.rawQuery(
        'SELECT 1 FROM Stu_Reg WHERE Stu_RegID = ? LIMIT 1',
        [regId],
      );

      if (regCheck.isEmpty) {
        return (false, 'Registration ID not found');
      }

      // Insert enrollment
      await db.rawInsert(
        '''
        INSERT INTO Student_Class (
          Stu_RegID, ClassID, ClassSecID, ClassRollNo, SessionYr, Present, VGen
        ) VALUES (?, ?, ?, ?, ?, 1, 'N')
        ''',
        [
          regId,
          state.selectedClassId,
          state.selectedSecId,
          rollNo,
          state.selectedSessionYr,
        ],
      );

      // Refresh roster
      await loadRoster();

      return (true, 'Student Enrolled Successfully');
    } catch (e) {
      return (false, 'Enrollment failed: $e');
    }
  }

  Future<void> togglePresent(int stuRegId, bool isPresent) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.rawUpdate(
        '''
        UPDATE Student_Class
        SET Present = ?
        WHERE Stu_RegID = ? AND ClassID = ? AND ClassSecID = ? AND SessionYr = ?
        ''',
        [
          isPresent ? 1 : 0,
          stuRegId,
          state.selectedClassId,
          state.selectedSecId,
          state.selectedSessionYr,
        ],
      );

      // Local optimistic update
      final updatedRoster = state.roster.map((row) {
        if (row.stuRegId == stuRegId) {
          return row.copyWith(present: isPresent);
        }
        return row;
      }).toList();

      state = state.copyWith(roster: updatedRoster);
    } catch (_) {
      // Revert / reload on error
      await loadRoster();
    }
  }

  Future<(bool, String)> removeStudent(EnrollmentRow student) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.rawDelete(
        '''
        DELETE FROM Student_Class
        WHERE Stu_RegID = ? AND ClassID = ? AND ClassSecID = ? AND SessionYr = ?
        ''',
        [
          student.stuRegId,
          state.selectedClassId,
          state.selectedSecId,
          state.selectedSessionYr,
        ],
      );

      await loadRoster();
      return (true, '${student.fullName} Removed');
    } catch (e) {
      return (false, 'Failed to remove student: $e');
    }
  }

  Future<(bool, String)> autoReRollNumbers() async {
    if (!state.isRosterLoaded || state.roster.isEmpty) {
      return (false, 'No Student for Re-Roll-Numbering');
    }

    try {
      final db = await DatabaseService.instance.database;

      final rows = await db.rawQuery(
        '''
        SELECT Stu_RegID
        FROM Student_Class
        WHERE ClassSecID = ? AND SessionYr = ?
        ORDER BY Stu_RegID ASC
        ''',
        [state.selectedSecId, state.selectedSessionYr],
      );

      if (rows.isEmpty) {
        return (false, 'No Student for Re-Roll-Numbering');
      }

      await db.transaction((txn) async {
        for (int i = 0; i < rows.length; i++) {
          final regId = rows[i]['Stu_RegID'] as int;
          final newRollNo = i + 1;
          await txn.rawUpdate(
            '''
            UPDATE Student_Class
            SET ClassRollNo = ?
            WHERE Stu_RegID = ? AND ClassSecID = ? AND SessionYr = ?
            ''',
            [newRollNo, regId, state.selectedSecId, state.selectedSessionYr],
          );
        }
      });

      final className = state.roster.first.className ?? 'Class';
      final secName = state.roster.first.sectionName ?? 'Sec';

      await loadRoster();

      return (
        true,
        'New Roll Numbers Assigned to ${rows.length} Students of Class $className Section $secName',
      );
    } catch (e) {
      return (false, 'Auto Re-Roll failed: $e');
    }
  }

  Future<(List<Map<String, dynamic>>, String?)> fetchMissingStudents() async {
    if (state.selectedClassId == null || state.selectedSessionYr.isEmpty) {
      return (const <Map<String, dynamic>>[], 'Select Class and Session first');
    }

    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT sc.Stu_RegID, c.CName, sr.NameFirst, sr.NameLast
        FROM Student_Class sc
        INNER JOIN Stu_Reg sr ON sc.Stu_RegID = sr.Stu_RegID
        INNER JOIN Class c ON sc.ClassID = c.ClassID
        LEFT JOIN SchLeaving sl ON sl.StuRegID = sc.Stu_RegID
        WHERE sc.ClassID = ? AND sc.SessionYr = ? AND sc.Present = 0 AND sl.StuRegID IS NULL
        ORDER BY sr.NameFirst, sr.NameLast
        ''',
        [state.selectedClassId, state.selectedSessionYr],
      );

      if (rows.isEmpty) {
        return (const <Map<String, dynamic>>[], 'No Missing Students');
      }

      return (rows, null);
    } catch (e) {
      return (
        const <Map<String, dynamic>>[],
        'Error fetching missing students: $e',
      );
    }
  }
}

final bulkEnrollmentProvider =
    StateNotifierProvider<BulkEnrollmentNotifier, BulkEnrollmentState>((ref) {
      return BulkEnrollmentNotifier();
    });
