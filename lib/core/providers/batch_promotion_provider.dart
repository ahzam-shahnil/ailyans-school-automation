import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/promotion_candidate_row.dart';
import '../db/database.dart';

@immutable
class BatchPromotionState {
  final String? sourceSessionYr;
  final int? sourceClassId;
  final int? sourceClassSecId;

  final String? targetSessionYr;
  final int? targetClassId;
  final int? targetClassSecId;

  final DateTime promotionDate;
  final double defaultPassingMarks;

  final List<PromotionCandidateRow> candidates;
  final bool loadedRoster;
  final bool loading;
  final bool committing;
  final int commitProgress;
  final int commitTotal;

  final String? errorMessage;
  final String? toast;

  final List<String> availableSessions;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> sourceSections;
  final List<Map<String, dynamic>> targetSections;

  const BatchPromotionState({
    this.sourceSessionYr,
    this.sourceClassId,
    this.sourceClassSecId,
    this.targetSessionYr,
    this.targetClassId,
    this.targetClassSecId,
    required this.promotionDate,
    this.defaultPassingMarks = 40.0,
    this.candidates = const [],
    this.loadedRoster = false,
    this.loading = false,
    this.committing = false,
    this.commitProgress = 0,
    this.commitTotal = 0,
    this.errorMessage,
    this.toast,
    this.availableSessions = const [],
    this.classes = const [],
    this.sourceSections = const [],
    this.targetSections = const [],
  });

  bool get isGraduationMode => sourceClassId == 13;

  int get selectedCount =>
      candidates.where((c) => c.isSelected && !c.isFailed).length;

  BatchPromotionState copyWith({
    String? Function()? sourceSessionYr,
    int? Function()? sourceClassId,
    int? Function()? sourceClassSecId,
    String? Function()? targetSessionYr,
    int? Function()? targetClassId,
    int? Function()? targetClassSecId,
    DateTime? promotionDate,
    double? defaultPassingMarks,
    List<PromotionCandidateRow>? candidates,
    bool? loadedRoster,
    bool? loading,
    bool? committing,
    int? commitProgress,
    int? commitTotal,
    String? Function()? errorMessage,
    String? Function()? toast,
    List<String>? availableSessions,
    List<Map<String, dynamic>>? classes,
    List<Map<String, dynamic>>? sourceSections,
    List<Map<String, dynamic>>? targetSections,
  }) {
    return BatchPromotionState(
      sourceSessionYr: sourceSessionYr != null
          ? sourceSessionYr()
          : this.sourceSessionYr,
      sourceClassId: sourceClassId != null
          ? sourceClassId()
          : this.sourceClassId,
      sourceClassSecId: sourceClassSecId != null
          ? sourceClassSecId()
          : this.sourceClassSecId,
      targetSessionYr: targetSessionYr != null
          ? targetSessionYr()
          : this.targetSessionYr,
      targetClassId: targetClassId != null
          ? targetClassId()
          : this.targetClassId,
      targetClassSecId: targetClassSecId != null
          ? targetClassSecId()
          : this.targetClassSecId,
      promotionDate: promotionDate ?? this.promotionDate,
      defaultPassingMarks: defaultPassingMarks ?? this.defaultPassingMarks,
      candidates: candidates ?? this.candidates,
      loadedRoster: loadedRoster ?? this.loadedRoster,
      loading: loading ?? this.loading,
      committing: committing ?? this.committing,
      commitProgress: commitProgress ?? this.commitProgress,
      commitTotal: commitTotal ?? this.commitTotal,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      toast: toast != null ? toast() : this.toast,
      availableSessions: availableSessions ?? this.availableSessions,
      classes: classes ?? this.classes,
      sourceSections: sourceSections ?? this.sourceSections,
      targetSections: targetSections ?? this.targetSections,
    );
  }
}

class BatchPromotionNotifier extends StateNotifier<BatchPromotionState> {
  BatchPromotionNotifier()
    : super(BatchPromotionState(promotionDate: DateTime.now())) {
    loadInitialData();
  }

  static int parseStartYear(String? session) {
    if (session == null) return 0;
    final match = RegExp(r'^(\d{4})').firstMatch(session.trim());
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Future<void> loadInitialData() async {
    if (!mounted) return;
    state = state.copyWith(loading: true, errorMessage: () => null);
    try {
      final db = await DatabaseService.instance.database;

      // 1. Query distinct sessions from Student_Class
      final sessionRows = await db.rawQuery(
        "SELECT DISTINCT SessionYr FROM Student_Class WHERE SessionYr IS NOT NULL AND SessionYr != ''",
      );

      final sessionSet = <String>{};
      for (final row in sessionRows) {
        final yr = (row['SessionYr'] as String?)?.trim();
        if (yr != null && yr.isNotEmpty) {
          sessionSet.add(yr);
          // Parse start and end year to generate next academic year
          final match = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(yr);
          if (match != null) {
            final start = int.tryParse(match.group(1)!);
            final end = int.tryParse(match.group(2)!);
            if (start != null && end != null) {
              sessionSet.add('${start + 1}-${end + 1}');
            }
          }
        }
      }

      if (sessionSet.isEmpty) {
        sessionSet.addAll(['2018-2019', '2017-2018']);
      } else if (!sessionSet.contains('2018-2019')) {
        sessionSet.add('2018-2019');
      }

      final availableSessions = sessionSet.toList()
        ..sort((a, b) => b.compareTo(a)); // Descending order

      // 2. Query classes
      final classRows = await db.rawQuery(
        'SELECT ClassID, CName FROM Class ORDER BY ClassID ASC',
      );

      // Default source to 2017-2018 if present, else oldest
      final defaultSource = availableSessions.contains('2017-2018')
          ? '2017-2018'
          : availableSessions.last;
      // Default target to newest (2018-2019)
      final defaultTarget = availableSessions.first;

      if (!mounted) return;
      state = state.copyWith(
        availableSessions: availableSessions,
        classes: classRows,
        sourceSessionYr: () => defaultSource,
        targetSessionYr: () => defaultTarget,
        promotionDate: DateTime.now(),
        loading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: () => 'Failed to initialize promotion data: $e',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: () => null, toast: () => null);
  }

  Future<void> setSourceClassId(int? newSourceId) async {
    if (state.sourceClassId == newSourceId) return;

    if (newSourceId == null) {
      state = state.copyWith(
        sourceClassId: () => null,
        sourceClassSecId: () => null,
        sourceSections: const [],
        loadedRoster: false,
        candidates: const [],
        errorMessage: () => null,
      );
      return;
    }

    try {
      final db = await DatabaseService.instance.database;
      final sourceSecRows = await db.rawQuery(
        'SELECT ClassSecID, SecName FROM ClassSec WHERE ClassID = ? ORDER BY ClassSecID ASC',
        [newSourceId],
      );

      int? newTargetClassId = state.targetClassId;
      List<Map<String, dynamic>> targetSecRows = state.targetSections;
      int? newTargetSecId = state.targetClassSecId;

      if (newSourceId < 13) {
        newTargetClassId = newSourceId + 1;
        targetSecRows = await db.rawQuery(
          'SELECT ClassSecID, SecName FROM ClassSec WHERE ClassID = ? ORDER BY ClassSecID ASC',
          [newTargetClassId],
        );
        newTargetSecId = targetSecRows.isNotEmpty
            ? targetSecRows.first['ClassSecID'] as int
            : null;
      } else if (newSourceId == 13) {
        // Terminal class 10 graduation
        newTargetClassId = null;
        targetSecRows = const [];
        newTargetSecId = null;
      }

      if (!mounted) return;
      state = state.copyWith(
        sourceClassId: () => newSourceId,
        sourceClassSecId: () => null,
        sourceSections: sourceSecRows,
        targetClassId: () => newTargetClassId,
        targetSections: targetSecRows,
        targetClassSecId: () => newTargetSecId,
        loadedRoster: false,
        candidates: const [],
        errorMessage: () => null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: () => 'Error loading sections: $e');
    }
  }

  void setSourceClassSecId(int? secId) {
    state = state.copyWith(
      sourceClassSecId: () => secId,
      loadedRoster: false,
      candidates: const [],
      errorMessage: () => null,
    );
  }

  void setSourceSessionYr(String? sessionYr) {
    state = state.copyWith(
      sourceSessionYr: () => sessionYr,
      loadedRoster: false,
      candidates: const [],
      errorMessage: () => null,
    );
  }

  Future<void> setTargetClassId(int? newTargetId) async {
    if (state.targetClassId == newTargetId) return;

    if (newTargetId == null) {
      state = state.copyWith(
        targetClassId: () => null,
        targetClassSecId: () => null,
        targetSections: const [],
        errorMessage: () => null,
      );
      return;
    }

    try {
      final db = await DatabaseService.instance.database;
      final targetSecRows = await db.rawQuery(
        'SELECT ClassSecID, SecName FROM ClassSec WHERE ClassID = ? ORDER BY ClassSecID ASC',
        [newTargetId],
      );

      final newTargetSecId = targetSecRows.isNotEmpty
          ? targetSecRows.first['ClassSecID'] as int
          : null;

      if (!mounted) return;
      state = state.copyWith(
        targetClassId: () => newTargetId,
        targetSections: targetSecRows,
        targetClassSecId: () => newTargetSecId,
        errorMessage: () => null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: () => 'Error loading target sections: $e',
      );
    }
  }

  void setTargetClassSecId(int? secId) {
    state = state.copyWith(
      targetClassSecId: () => secId,
      errorMessage: () => null,
    );
  }

  void setTargetSessionYr(String? sessionYr) {
    state = state.copyWith(
      targetSessionYr: () => sessionYr,
      errorMessage: () => null,
    );
  }

  void setPromotionDate(DateTime date) {
    state = state.copyWith(promotionDate: date);
  }

  void setDefaultPassingMarks(double newDefault) {
    final updated = state.candidates.map((c) {
      final marks = c.isManuallyEdited ? c.currentPassingMarks : newDefault;
      final isFailed = marks != null && marks < newDefault;
      return c.copyWith(
        defaultPassingMarks: newDefault,
        currentPassingMarks: () => marks,
        isSelected: isFailed ? false : c.isSelected,
      );
    }).toList();

    state = state.copyWith(
      defaultPassingMarks: newDefault,
      candidates: updated,
    );
  }

  void updateRowPassingMarks(int stuRegId, double? marks) {
    final updated = state.candidates.map((c) {
      if (c.stuRegId == stuRegId) {
        final isFailed = marks != null && marks < state.defaultPassingMarks;
        return c.copyWith(
          currentPassingMarks: () => marks,
          isManuallyEdited: true,
          isSelected: isFailed ? false : true,
        );
      }
      return c;
    }).toList();

    state = state.copyWith(candidates: updated);
  }

  void toggleSelectAll() {
    final eligibleCandidates = state.candidates.where((c) => !c.isFailed);
    final allEligibleSelected =
        eligibleCandidates.isNotEmpty &&
        eligibleCandidates.every((c) => c.isSelected);

    final updated = state.candidates.map((c) {
      if (c.isFailed) {
        return c.copyWith(isSelected: false);
      }
      return c.copyWith(isSelected: !allEligibleSelected);
    }).toList();

    state = state.copyWith(candidates: updated);
  }

  void toggleRowSelected(int stuRegId) {
    final updated = state.candidates.map((c) {
      if (c.stuRegId == stuRegId) {
        if (c.isFailed) {
          return c.copyWith(isSelected: false);
        }
        return c.copyWith(isSelected: !c.isSelected);
      }
      return c;
    }).toList();

    state = state.copyWith(candidates: updated);
  }

  Future<(bool, String)> loadCandidates() async {
    if (state.sourceClassId == null) {
      const msg = 'Select Class Want To Promote';
      state = state.copyWith(errorMessage: () => msg);
      return (false, msg);
    }
    if (state.sourceClassSecId == null) {
      const msg = 'Slect class Sec please';
      state = state.copyWith(errorMessage: () => msg);
      return (false, msg);
    }
    if (state.sourceSessionYr == null ||
        state.sourceSessionYr!.trim().isEmpty) {
      const msg = 'Select Session ';
      state = state.copyWith(errorMessage: () => msg);
      return (false, msg);
    }

    state = state.copyWith(loading: true, errorMessage: () => null);

    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT sc.Stu_RegID, sc.ClassID, sc.ClassSecID, sc.ClassRollNo, sc.PassingMarks,
               sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name
        FROM Student_Class sc
        JOIN Stu_Reg sr ON sc.Stu_RegID = sr.Stu_RegID
        WHERE sc.ClassID = ? AND sc.ClassSecID = ? AND sc.SessionYr = ? AND sc.Present = 1
        ORDER BY sc.ClassRollNo ASC, sc.Stu_RegID ASC
        ''',
        [state.sourceClassId, state.sourceClassSecId, state.sourceSessionYr],
      );

      if (rows.isEmpty) {
        const msg = 'No Student to Promote';
        state = state.copyWith(
          loading: false,
          loadedRoster: true,
          candidates: const [],
          errorMessage: () => msg,
        );
        return (false, msg);
      }

      final candidates = rows.map((r) {
        final existingMarks = (r['PassingMarks'] as num?)?.toDouble();
        final effectiveMarks = existingMarks ?? state.defaultPassingMarks;
        final isFailed = effectiveMarks < state.defaultPassingMarks;

        return PromotionCandidateRow(
          stuRegId: r['Stu_RegID'] as int,
          rollNo: (r['ClassRollNo'] as num?)?.toInt() ?? 0,
          nameFirst: (r['NameFirst'] as String?)?.trim() ?? '',
          nameMiddle: (r['NameMiddle'] as String?)?.trim(),
          nameLast: (r['NameLast'] as String?)?.trim(),
          fatherName: (r['F_Name'] as String?)?.trim(),
          currentPassingMarks: effectiveMarks,
          defaultPassingMarks: state.defaultPassingMarks,
          isSelected: !isFailed,
          isManuallyEdited: false,
        );
      }).toList();

      if (!mounted) return (true, 'Cohort loaded');
      state = state.copyWith(
        loading: false,
        loadedRoster: true,
        candidates: candidates,
        errorMessage: () => null,
      );
      return (true, 'Cohort loaded');
    } catch (e) {
      if (!mounted) return (false, e.toString());
      state = state.copyWith(
        loading: false,
        errorMessage: () => 'Failed to load candidates: $e',
      );
      return (false, e.toString());
    }
  }

  (bool, String?) validateBeforePromote() {
    if (state.sourceClassId == null) {
      return (false, 'Select Class Want To Promote');
    }

    if (!state.isGraduationMode) {
      if (state.targetClassSecId == null) {
        return (false, 'Select - TO Section ');
      }
      if (state.targetClassId == null) {
        return (false, 'Select - Target Class Please');
      }
      if (state.targetSessionYr == null ||
          state.targetSessionYr!.trim().isEmpty) {
        return (false, 'Select - Target Session Please');
      }

      final srcYr = parseStartYear(state.sourceSessionYr);
      final tgtYr = parseStartYear(state.targetSessionYr);
      if (tgtYr <= srcYr) {
        return (false, 'Target session must be later than source session.');
      }
      if (state.targetClassId! < state.sourceClassId!) {
        return (
          false,
          'Target class is lower than source class. Choose the same or a higher class.',
        );
      }
    }

    if (!state.loadedRoster || state.candidates.isEmpty) {
      return (false, 'No Student to Promote');
    }

    final selected = state.candidates
        .where((c) => c.isSelected && !c.isFailed)
        .toList();
    if (selected.isEmpty) {
      return (false, 'No Student Selected');
    }

    return (true, null);
  }

  Future<(bool, String)> promoteSelectedStudents() async {
    final (valid, error) = validateBeforePromote();
    if (!valid) {
      state = state.copyWith(errorMessage: () => error);
      return (false, error ?? 'Validation error');
    }

    final selected = state.candidates
        .where((c) => c.isSelected && !c.isFailed)
        .toList();

    state = state.copyWith(
      committing: true,
      commitTotal: selected.length,
      commitProgress: 0,
      errorMessage: () => null,
    );

    try {
      final db = await DatabaseService.instance.database;

      final sourceClassName =
          state.classes.firstWhere(
                (c) => c['ClassID'] == state.sourceClassId,
                orElse: () => {'CName': 'Class ${state.sourceClassId}'},
              )['CName']
              as String;

      final sourceSecName =
          state.sourceSections.firstWhere(
                (s) => s['ClassSecID'] == state.sourceClassSecId,
                orElse: () => {'SecName': '-'},
              )['SecName']
              as String;

      String targetClassName = '-';
      String targetSecName = '-';
      if (!state.isGraduationMode) {
        targetClassName =
            state.classes.firstWhere(
                  (c) => c['ClassID'] == state.targetClassId,
                  orElse: () => {'CName': 'Class ${state.targetClassId}'},
                )['CName']
                as String;

        targetSecName =
            state.targetSections.firstWhere(
                  (s) => s['ClassSecID'] == state.targetClassSecId,
                  orElse: () => {'SecName': '-'},
                )['SecName']
                as String;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(state.promotionDate);
      int promotedCount = 0;

      await db.transaction((txn) async {
        for (int i = 0; i < selected.length; i++) {
          final row = selected[i];
          final marks = row.currentPassingMarks ?? state.defaultPassingMarks;

          if (state.isGraduationMode) {
            // 1. Deactivate source enrollment
            await txn.rawUpdate(
              '''
              UPDATE Student_Class
              SET Present = 0, PromotionDate = ?, PassingMarks = ?
              WHERE Stu_RegID = ? AND ClassID = ? AND ClassSecID = ? AND SessionYr = ?
              ''',
              [
                dateStr,
                marks,
                row.stuRegId,
                state.sourceClassId,
                state.sourceClassSecId,
                state.sourceSessionYr,
              ],
            );

            // 2. Check if already in SchLeaving
            final existingSl = await txn.rawQuery(
              'SELECT 1 FROM SchLeaving WHERE StuRegID = ? LIMIT 1',
              [row.stuRegId],
            );

            if (existingSl.isEmpty) {
              final nextSlid =
                  ((await txn.rawQuery(
                            'SELECT COALESCE(MAX(SLID),0)+1 AS nextId FROM SchLeaving',
                          )).first['nextId']
                          as num?)
                      ?.toInt() ??
                  1;

              await txn.rawInsert(
                '''
                INSERT INTO SchLeaving (SLID, StuRegID, LeftDate, LeftClass, Charactor, TermOfLeavign, SLCertificate, Remarks)
                VALUES (?, ?, ?, ?, 'Good ', 'Completed Studies', 0, ?)
                ''',
                [
                  nextSlid,
                  row.stuRegId,
                  dateStr,
                  state.sourceClassId,
                  'Passing out from Class 10 with ${marks.toInt()} Marks',
                ],
              );
            }
            promotedCount++;
          } else {
            // Regular mode
            // 1. Duplicate check in target class
            final dup = await txn.rawQuery(
              'SELECT 1 FROM Student_Class WHERE Stu_RegID = ? AND ClassID = ? AND SessionYr = ? LIMIT 1',
              [row.stuRegId, state.targetClassId, state.targetSessionYr],
            );
            if (dup.isNotEmpty) {
              continue; // Skip duplicate
            }

            // 2. Deactivate source enrollment
            await txn.rawUpdate(
              '''
              UPDATE Student_Class
              SET Present = 0, PromotionDate = ?, PassingMarks = ?
              WHERE Stu_RegID = ? AND ClassID = ? AND ClassSecID = ? AND SessionYr = ?
              ''',
              [
                dateStr,
                marks,
                row.stuRegId,
                state.sourceClassId,
                state.sourceClassSecId,
                state.sourceSessionYr,
              ],
            );

            // 3. Insert target enrollment
            await txn.rawInsert(
              '''
              INSERT INTO Student_Class (Stu_RegID, ClassID, ClassSecID, ClassRollNo, SessionYr, Present, VGen)
              VALUES (?, ?, ?, 0, ?, 1, 'N')
              ''',
              [
                row.stuRegId,
                state.targetClassId,
                state.targetClassSecId,
                state.targetSessionYr,
              ],
            );
            promotedCount++;
          }

          state = state.copyWith(commitProgress: i + 1);
        }

        // Auto re-roll target cohort if regular promotion
        if (!state.isGraduationMode) {
          final targetCohort = await txn.rawQuery(
            '''
            SELECT Stu_RegID FROM Student_Class
            WHERE ClassID = ? AND ClassSecID = ? AND SessionYr = ? AND Present = 1
            ORDER BY Stu_RegID ASC
            ''',
            [
              state.targetClassId,
              state.targetClassSecId,
              state.targetSessionYr,
            ],
          );

          for (int r = 0; r < targetCohort.length; r++) {
            final regId = targetCohort[r]['Stu_RegID'] as int;
            await txn.rawUpdate(
              '''
              UPDATE Student_Class
              SET ClassRollNo = ?
              WHERE Stu_RegID = ? AND ClassID = ? AND ClassSecID = ? AND SessionYr = ?
              ''',
              [
                r + 1,
                regId,
                state.targetClassId,
                state.targetClassSecId,
                state.targetSessionYr,
              ],
            );
          }
        }

        // Insert TempPromoHistory audit log
        final nextHistId =
            ((await txn.rawQuery(
                      'SELECT COALESCE(MAX(ID),0)+1 AS nextId FROM TempPromoHistory',
                    )).first['nextId']
                    as num?)
                ?.toInt() ??
            1;

        await txn.rawInsert(
          '''
          INSERT INTO TempPromoHistory (ID, FromSessionYr, FromClass, FromSection, ToSessionYr, ToClass, ToSection, Strenght)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            nextHistId,
            state.sourceSessionYr,
            sourceClassName,
            sourceSecName,
            state.isGraduationMode
                ? state.sourceSessionYr
                : state.targetSessionYr,
            state.isGraduationMode ? 'Graduated' : targetClassName,
            state.isGraduationMode ? '-' : targetSecName,
            promotedCount,
          ],
        );
      });

      final toastMsg = state.isGraduationMode
          ? '$promotedCount Students Graduated and Recorded in School Leaving'
          : '$promotedCount Students Promoted to Next Class';

      if (!mounted) return (true, toastMsg);
      state = state.copyWith(
        committing: false,
        commitProgress: 0,
        commitTotal: 0,
        toast: () => toastMsg,
        loadedRoster: false,
        candidates: const [],
      );

      return (true, toastMsg);
    } catch (e) {
      if (!mounted) return (false, 'Promotion failed: $e');
      state = state.copyWith(
        committing: false,
        commitProgress: 0,
        commitTotal: 0,
        errorMessage: () => 'Promotion failed. No changes were saved.',
      );
      return (false, 'Promotion failed: $e');
    }
  }

  Future<(bool, String)> autoReRollTargetCohort() async {
    if (state.isGraduationMode) {
      const msg = 'No target cohort in graduation mode';
      state = state.copyWith(errorMessage: () => msg);
      return (false, msg);
    }
    if (state.targetClassId == null) {
      const msg = 'Which Class Want to Re-Roll';
      state = state.copyWith(errorMessage: () => msg);
      return (false, msg);
    }
    if (state.targetClassSecId == null ||
        state.targetSessionYr == null ||
        state.targetSessionYr!.trim().isEmpty) {
      const msg = ' No Class selected to Re-Roll';
      state = state.copyWith(errorMessage: () => msg);
      return (false, msg);
    }

    try {
      final db = await DatabaseService.instance.database;
      final targetCohort = await db.rawQuery(
        '''
        SELECT Stu_RegID FROM Student_Class
        WHERE ClassID = ? AND ClassSecID = ? AND SessionYr = ? AND Present = 1
        ORDER BY Stu_RegID ASC
        ''',
        [state.targetClassId, state.targetClassSecId, state.targetSessionYr],
      );

      if (targetCohort.isEmpty) {
        const msg = ' No Class selected to Re-Roll';
        if (!mounted) return (false, msg);
        state = state.copyWith(errorMessage: () => msg);
        return (false, msg);
      }

      await db.transaction((txn) async {
        for (int i = 0; i < targetCohort.length; i++) {
          final regId = targetCohort[i]['Stu_RegID'] as int;
          await txn.rawUpdate(
            '''
            UPDATE Student_Class
            SET ClassRollNo = ?
            WHERE Stu_RegID = ? AND ClassID = ? AND ClassSecID = ? AND SessionYr = ?
            ''',
            [
              i + 1,
              regId,
              state.targetClassId,
              state.targetClassSecId,
              state.targetSessionYr,
            ],
          );
        }
      });

      final toastMsg = '${targetCohort.length} Students Re-Roll Numbered.';
      if (!mounted) return (true, toastMsg);
      state = state.copyWith(toast: () => toastMsg);
      return (true, toastMsg);
    } catch (e) {
      final err = 'Re-Roll failed: $e';
      if (!mounted) return (false, err);
      state = state.copyWith(errorMessage: () => err);
      return (false, err);
    }
  }

  Future<(bool, String)> clearStagingHistory() async {
    try {
      final db = await DatabaseService.instance.database;
      await db.rawDelete('DELETE FROM TempPromoHistory');
      const toastMsg = 'Temporary history Cleared';
      if (!mounted) return (true, toastMsg);
      state = state.copyWith(toast: () => toastMsg);
      return (true, toastMsg);
    } catch (e) {
      final err = 'Failed to clear history: $e';
      if (!mounted) return (false, err);
      state = state.copyWith(errorMessage: () => err);
      return (false, err);
    }
  }
}

final batchPromotionProvider =
    StateNotifierProvider<BatchPromotionNotifier, BatchPromotionState>((ref) {
      return BatchPromotionNotifier();
    });
