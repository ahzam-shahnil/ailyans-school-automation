import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/school_class.dart';
import '../../models/student_list_row.dart';
import '../db/database.dart';
import 'shell_metadata_provider.dart';

/// Available sortable columns in the Student Directory table.
enum StudentSortColumn { defaultOrder, regId, studentName, rollNo }

/// Sort directions.
enum SortDirection { ascending, descending }

/// Filter and search state for the Student Directory.
class StudentListFilters {
  final String search;
  final int? classId;
  final int? classSecId;
  final String status; // "Active", "Left", "All"
  final String sessionYr;
  final StudentSortColumn sortColumn;
  final SortDirection sortDirection;
  final int page;
  final int pageSize;

  const StudentListFilters({
    this.search = '',
    this.classId,
    this.classSecId,
    this.status = 'Active',
    this.sessionYr = '2017-2018',
    this.sortColumn = StudentSortColumn.defaultOrder,
    this.sortDirection = SortDirection.ascending,
    this.page = 1,
    this.pageSize = 50,
  });

  StudentListFilters copyWith({
    String? search,
    int? Function()? classId,
    int? Function()? classSecId,
    String? status,
    String? sessionYr,
    StudentSortColumn? sortColumn,
    SortDirection? sortDirection,
    int? page,
    int? pageSize,
  }) {
    return StudentListFilters(
      search: search ?? this.search,
      classId: classId != null ? classId() : this.classId,
      classSecId: classSecId != null ? classSecId() : this.classSecId,
      status: status ?? this.status,
      sessionYr: sessionYr ?? this.sessionYr,
      sortColumn: sortColumn ?? this.sortColumn,
      sortDirection: sortDirection ?? this.sortDirection,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// StateNotifier managing student directory filters, search, and pagination.
class StudentListFiltersNotifier extends StateNotifier<StudentListFilters> {
  final Ref? ref;

  /// Set when a session is chosen explicitly (user filter tap or a save from
  /// SystemSettings). The config bootstrap fallback must never override an
  /// explicit selection.
  bool _explicitSessionSelected = false;

  StudentListFiltersNotifier([this.ref, String? initialSessionYr])
      : super(
          StudentListFilters(
            sessionYr: initialSessionYr ?? '2017-2018',
          ),
        ) {
    if (ref != null) {
      final initialMeta = ref!.read(shellMetadataProvider).valueOrNull;
      if (initialMeta != null && initialMeta.sessionYear.isNotEmpty) {
        syncSession(initialMeta.sessionYear);
      }

      // Phase G-9.7a: authoritative session bootstrap straight from SQLite
      // (app_config.default_session_yr) with a populated-session fallback,
      // so the directory never waits on (or races) shellMetadataProvider.
      unawaited(_bootstrapSessionFromConfig());
    }
  }

  /// Reads `default_session_yr` directly from app_config and applies a
  /// populated-session fallback:
  ///
  /// - If `Student_Class` has rows for `default_session_yr`, select it.
  /// - If it has none (e.g. a freshly bumped default with no enrollments yet),
  ///   fall back to the latest populated `SessionYr` (Present = 1) so the
  ///   directory shows students immediately. `default_session_yr` itself and
  ///   all DB sessions remain available via availableSessionsProvider.
  ///
  /// Never overrides an explicit selection (setSessionYr) or a session changed
  /// by anyone else while the bootstrap was in flight.
  Future<void> _bootstrapSessionFromConfig() async {
    try {
      // Test environments keep the shell-metadata sync path (fixtures assert
      // against it, and sqflite's async timers leave fake-async test zones
      // with pending timers). Same guard as SessionNotifier/AppShell.
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;

      final baseline = state.sessionYr;
      final db = await DatabaseService.instance.database;

      final configRows = await db.rawQuery(
        "SELECT config_value FROM app_config "
        "WHERE config_key = 'default_session_yr' LIMIT 1",
      );
      final defaultYr = configRows.isEmpty
          ? null
          : (configRows.first['config_value'] as String?)?.trim();
      // Unconfigured database (fresh test fixtures): keep the shell-metadata
      // synced session untouched.
      if (defaultYr == null || defaultYr.isEmpty) return;
      if (_explicitSessionSelected) return;

      var target = defaultYr;
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM Student_Class WHERE SessionYr = ?',
        [defaultYr],
      );
      final count = (countRows.first['cnt'] as num?)?.toInt() ?? 0;
      if (count == 0) {
        final populatedRows = await db.rawQuery(
          'SELECT SessionYr FROM Student_Class WHERE Present = 1 '
          'GROUP BY SessionYr ORDER BY SessionYr DESC LIMIT 1',
        );
        final latestPopulated = populatedRows.isEmpty
            ? null
            : (populatedRows.first['SessionYr'] as String?)?.trim();
        if (latestPopulated != null && latestPopulated.isNotEmpty) {
          target = latestPopulated;
        }
      }

      // Re-check after the awaits: an explicit selection or another sync that
      // landed while we were reading always wins.
      if (_explicitSessionSelected) return;
      if (state.sessionYr != baseline) return;
      syncSession(target);
    } catch (_) {
      // Database unavailable (e.g. no DB bound yet): keep current session.
    }
  }

  // On first read or init, sync sessionYr from shell metadata
  void syncSession(String sessionYr) {
    if (sessionYr.isNotEmpty && state.sessionYr != sessionYr) {
      state = state.copyWith(sessionYr: sessionYr, page: 1);
    }
  }

  void setSearch(String query) {
    state = state.copyWith(search: query.trim(), page: 1);
  }

  void setClassId(int? classId) {
    if (state.classId == classId) return;
    state = state.copyWith(
      classId: () => classId,
      classSecId: () => null, // Reset section when class changes
      page: 1,
    );
  }

  void setClassSecId(int? secId) {
    state = state.copyWith(classSecId: () => secId, page: 1);
  }

  void setStatus(String status) {
    state = state.copyWith(status: status, page: 1);
  }

  /// Syncs the active session year from the app shell (app_config.default_session_yr).
  /// Called by StudentListScreen on mount to avoid filtering on the constructor default.
  void setSessionYr(String sessionYr) {
    _explicitSessionSelected = true;
    syncSession(sessionYr);
  }

  void toggleSort(StudentSortColumn column) {
    if (state.sortColumn == column) {
      final newDir = state.sortDirection == SortDirection.ascending
          ? SortDirection.descending
          : SortDirection.ascending;
      state = state.copyWith(sortDirection: newDir);
    } else {
      state = state.copyWith(
        sortColumn: column,
        sortDirection: SortDirection.ascending,
      );
    }
  }

  void setPage(int page) {
    if (page < 1) return;
    state = state.copyWith(page: page);
  }

  void setPageSize(int pageSize) {
    state = state.copyWith(pageSize: pageSize, page: 1);
  }

  void reset({String? sessionYr}) {
    final activeSession = sessionYr ?? state.sessionYr;
    state = StudentListFilters(
      sessionYr: activeSession,
      pageSize: state.pageSize,
    );
  }
}

/// Global provider for student list filter controls.
final studentListFiltersProvider =
    StateNotifierProvider<StudentListFiltersNotifier, StudentListFilters>((
      ref,
    ) {
      final initialMeta = ref.read(shellMetadataProvider).valueOrNull;
      final initialSession =
          (initialMeta != null && initialMeta.sessionYear.isNotEmpty)
              ? initialMeta.sessionYear
              : '2017-2018';
      final notifier = StudentListFiltersNotifier(ref, initialSession);

      // Sync when shell metadata resolves
      ref.listen<AsyncValue<ShellMetadata>>(shellMetadataProvider, (prev, next) {
        next.whenData((meta) => notifier.syncSession(meta.sessionYear));
      });

      return notifier;
    });

/// Fetches all academic grades / classes for filtering.
final classesProvider = FutureProvider<List<SchoolClass>>((ref) async {
  final db = await DatabaseService.instance.database;
  final rows = await db.rawQuery(
    'SELECT ClassID, CName FROM Class ORDER BY ClassID ASC',
  );
  return rows.map(SchoolClass.fromMap).toList();
});

/// Fetches all sections across classes for filtering.
final sectionsProvider = FutureProvider<List<ClassSec>>((ref) async {
  final db = await DatabaseService.instance.database;
  final rows = await db.rawQuery(
    'SELECT ClassSecID, ClassID, SecName FROM ClassSec ORDER BY ClassID ASC, SecName ASC',
  );
  return rows.map(ClassSec.fromMap).toList();
});

/// Queries SQLite for filtered and sorted students matching directory parameters.
final studentListProvider = FutureProvider<List<StudentListRow>>((ref) async {
  final filters = ref.watch(studentListFiltersProvider);
  final db = await DatabaseService.instance.database;

  var sessionYr = filters.sessionYr.trim();
  if (sessionYr.isEmpty) {
    final meta = ref.read(shellMetadataProvider).valueOrNull;
    sessionYr = (meta != null && meta.sessionYear.isNotEmpty)
        ? meta.sessionYear
        : '2017-2018';
  }

  // Build sorting clause
  String orderClause;
  final dir = filters.sortDirection == SortDirection.ascending ? 'ASC' : 'DESC';

  switch (filters.sortColumn) {
    case StudentSortColumn.regId:
      orderClause = 'sr.Stu_RegID $dir';
      break;
    case StudentSortColumn.studentName:
      orderClause =
          'LOWER(sr.NameFirst) $dir, LOWER(COALESCE(sr.NameLast, "")) $dir';
      break;
    case StudentSortColumn.rollNo:
      orderClause = 'sc.ClassRollNo $dir';
      break;
    case StudentSortColumn.defaultOrder:
      orderClause = 'c.ClassID ASC, cs.SecName ASC, sc.ClassRollNo ASC';
      break;
  }

  final query =
      '''
    SELECT
      sr.Stu_RegID,
      sr.NameFirst,
      sr.NameLast,
      sr.F_Name,
      sr.photo_path,
      c.CName as class_name,
      cs.SecName as section_name,
      sc.ClassRollNo,
      sc.SessionYr,
      CASE
        WHEN sc.Present = 1 THEN 'Active'
        WHEN sc.Present = 0 OR sl.StuRegID IS NOT NULL THEN 'Left'
        ELSE 'Active'
      END as status,
      (SELECT COUNT(*) FROM Sibling_Links
       WHERE Stu1_RegID = sc.Stu_RegID OR Stu2_RegID = sc.Stu_RegID) AS siblingCount
    FROM Stu_Reg sr
    JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID
    JOIN Class c ON sc.ClassID = c.ClassID
    LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
    LEFT JOIN SchLeaving sl ON sr.Stu_RegID = sl.StuRegID
    WHERE sc.SessionYr = ?
      AND (? IS NULL OR sc.ClassID = ?)
      AND (? IS NULL OR sc.ClassSecID = ?)
      AND (? = 'All' OR (CASE WHEN sc.Present = 1 THEN 'Active' WHEN sc.Present = 0 OR sl.StuRegID IS NOT NULL THEN 'Left' ELSE 'Active' END) = ?)
      AND (? = '' OR LOWER(sr.NameFirst || ' ' || COALESCE(sr.NameLast, '')) LIKE LOWER('%' || ? || '%')
           OR CAST(sr.Stu_RegID AS TEXT) LIKE '%' || ? || '%'
           OR LOWER(COALESCE(sr.F_Name, '')) LIKE LOWER('%' || ? || '%')
           OR LOWER(COALESCE(sr.CNIC_No, '')) LIKE LOWER('%' || ? || '%'))
    ORDER BY $orderClause
  ''';

  final params = [
    sessionYr,
    filters.classId,
    filters.classId,
    filters.classSecId,
    filters.classSecId,
    filters.status,
    filters.status,
    filters.search,
    filters.search,
    filters.search,
    filters.search,
    filters.search,
  ];

  final rows = await db.rawQuery(query, params);
  debugPrint('[studentList] sessionYr=$sessionYr, rows=${rows.length}');
  return rows.map(StudentListRow.fromMap).toList();
});
