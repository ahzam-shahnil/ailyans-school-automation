import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/exam_session_row.dart';
import '../../models/exam_term_row.dart';
import '../db/database.dart';
import 'clock_provider.dart';

/// State object for ExamTermScreen.
class ExamTermState {
  final List<ExamTermRow> terms;
  final int? selectedTermId;
  final List<ExamSessionRow> currentSessions;
  final List<Map<String, dynamic>> allTeachers;
  final List<Map<String, dynamic>> availableTeachers; // TCat = 'Teacher'
  final ExamSessionRow? editingSession; // null = Create mode
  final Map<String, dynamic>?
  nonTeacherSupervisor; // for Principal/Staff supervisor warning
  final List<String> sessionYears;

  // Form fields
  final int? formExTermId;
  final String? formSessionYr;
  final int? formExamSupervisorId;
  final DateTime? formStartDate;
  final DateTime? formEndDate;
  final DateTime? formResultDate;
  final String formLocation;
  final String formDetail;

  final bool isFormDirty;
  final bool isLoading;
  final String? toast;
  final String? errorMessage;
  final String sessionSearchId;

  const ExamTermState({
    this.terms = const [],
    this.selectedTermId,
    this.currentSessions = const [],
    this.allTeachers = const [],
    this.availableTeachers = const [],
    this.editingSession,
    this.nonTeacherSupervisor,
    this.sessionYears = const [],
    this.formExTermId,
    this.formSessionYr,
    this.formExamSupervisorId,
    this.formStartDate,
    this.formEndDate,
    this.formResultDate,
    this.formLocation = '',
    this.formDetail = '',
    this.isFormDirty = false,
    this.isLoading = false,
    this.toast,
    this.errorMessage,
    this.sessionSearchId = '',
  });

  bool get isEditMode => editingSession != null;

  ExamTermRow? get selectedTerm {
    if (selectedTermId == null) return null;
    for (final t in terms) {
      if (t.exTermId == selectedTermId) return t;
    }
    return null;
  }

  ExamTermState copyWith({
    List<ExamTermRow>? terms,
    int? selectedTermId,
    bool clearSelectedTermId = false,
    List<ExamSessionRow>? currentSessions,
    List<Map<String, dynamic>>? allTeachers,
    List<Map<String, dynamic>>? availableTeachers,
    ExamSessionRow? editingSession,
    bool clearEditingSession = false,
    Map<String, dynamic>? nonTeacherSupervisor,
    bool clearNonTeacherSupervisor = false,
    List<String>? sessionYears,
    int? formExTermId,
    bool clearFormExTermId = false,
    String? formSessionYr,
    bool clearFormSessionYr = false,
    int? formExamSupervisorId,
    bool clearFormExamSupervisorId = false,
    DateTime? formStartDate,
    bool clearFormStartDate = false,
    DateTime? formEndDate,
    bool clearFormEndDate = false,
    DateTime? formResultDate,
    bool clearFormResultDate = false,
    String? formLocation,
    String? formDetail,
    bool? isFormDirty,
    bool? isLoading,
    String? toast,
    bool clearToast = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? sessionSearchId,
  }) {
    return ExamTermState(
      terms: terms ?? this.terms,
      selectedTermId: clearSelectedTermId
          ? null
          : (selectedTermId ?? this.selectedTermId),
      currentSessions: currentSessions ?? this.currentSessions,
      allTeachers: allTeachers ?? this.allTeachers,
      availableTeachers: availableTeachers ?? this.availableTeachers,
      editingSession: clearEditingSession
          ? null
          : (editingSession ?? this.editingSession),
      nonTeacherSupervisor: clearNonTeacherSupervisor
          ? null
          : (nonTeacherSupervisor ?? this.nonTeacherSupervisor),
      sessionYears: sessionYears ?? this.sessionYears,
      formExTermId: clearFormExTermId
          ? null
          : (formExTermId ?? this.formExTermId),
      formSessionYr: clearFormSessionYr
          ? null
          : (formSessionYr ?? this.formSessionYr),
      formExamSupervisorId: clearFormExamSupervisorId
          ? null
          : (formExamSupervisorId ?? this.formExamSupervisorId),
      formStartDate: clearFormStartDate
          ? null
          : (formStartDate ?? this.formStartDate),
      formEndDate: clearFormEndDate ? null : (formEndDate ?? this.formEndDate),
      formResultDate: clearFormResultDate
          ? null
          : (formResultDate ?? this.formResultDate),
      formLocation: formLocation ?? this.formLocation,
      formDetail: formDetail ?? this.formDetail,
      isFormDirty: isFormDirty ?? this.isFormDirty,
      isLoading: isLoading ?? this.isLoading,
      toast: clearToast ? null : (toast ?? this.toast),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      sessionSearchId: sessionSearchId ?? this.sessionSearchId,
    );
  }
}

/// Riverpod StateNotifier driving Screen 16 ExamTermScreen.
class ExamTermNotifier extends StateNotifier<ExamTermState> {
  final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');
  final Ref? _ref;

  ExamTermNotifier([ExamTermState? initialState, Ref? ref])
    : _ref = ref,
      super(initialState ?? const ExamTermState());

  DateTime _now() => _ref?.read(clockProvider)() ?? DateTime.now();

  Future<Database> _getDb() async {
    return DatabaseService.instance.database;
  }

  /// S20 Form_Load (0x006a0280): initializes catalogs and loads latest session.
  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final db = await _getDb();

      // 1. Load teachers
      final teacherRows = await db.rawQuery(
        'SELECT TeacherID, TName, TCat FROM Teachers ORDER BY TName ASC',
      );
      final allTeachers = List<Map<String, dynamic>>.from(teacherRows);
      final availableTeachers = allTeachers
          .where((t) => (t['TCat'] as String?)?.trim() == 'Teacher')
          .toList();

      String? teacherError;
      if (availableTeachers.isEmpty) {
        teacherError = 'No Teachers Found';
      }

      // 2. Load session years
      final sessionRows = await db.rawQuery(
        "SELECT DISTINCT SessionYr FROM Student_Class WHERE SessionYr IS NOT NULL AND TRIM(SessionYr) != '' ORDER BY SessionYr DESC",
      );
      List<String> sessionYears = sessionRows
          .map((r) => (r['SessionYr'] as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      if (sessionYears.isEmpty) {
        sessionYears = ['2017-2018'];
      }

      // 3. Load terms & their session counts
      final countsRows = await db.rawQuery(
        'SELECT ExTermID, COUNT(*) as cnt FROM ExamInfo GROUP BY ExTermID',
      );
      final countsMap = <int, int>{};
      for (final r in countsRows) {
        countsMap[(r['ExTermID'] as num).toInt()] = (r['cnt'] as num).toInt();
      }

      final termRows = await db.rawQuery(
        'SELECT * FROM ExamTerm ORDER BY ExTermID ASC',
      );
      final terms = termRows.map((r) {
        final id = (r['ExTermID'] as num).toInt();
        return ExamTermRow.fromMap(r, sessionCount: countsMap[id] ?? 0);
      }).toList();

      int? initialTermId;
      List<ExamSessionRow> currentSessions = [];
      ExamSessionRow? initialSession;
      Map<String, dynamic>? nonTeacherSupervisor;

      if (terms.isNotEmpty) {
        final firstId = terms.first.exTermId;
        initialTermId = firstId;
        currentSessions = await _fetchSessionsForTerm(db, firstId);

        // Auto-load most recent session into EDIT mode per S20 Form_Load
        if (currentSessions.isNotEmpty) {
          initialSession = currentSessions.first;
          if (initialSession.supervisorCat != 'Teacher') {
            for (final t in allTeachers) {
              if ((t['TeacherID'] as num).toInt() ==
                  initialSession.examSupervisorId) {
                nonTeacherSupervisor = t;
                break;
              }
            }
          }
        }
      }

      if (!mounted) return;
      if (initialSession != null) {
        // Pre-fill form in EDIT mode
        state = state.copyWith(
          terms: terms,
          selectedTermId: initialTermId,
          currentSessions: currentSessions,
          allTeachers: allTeachers,
          availableTeachers: availableTeachers,
          sessionYears: sessionYears,
          editingSession: initialSession,
          nonTeacherSupervisor: nonTeacherSupervisor,
          formExTermId: initialSession.exTermId,
          formSessionYr: initialSession.sessionYr,
          formExamSupervisorId: initialSession.examSupervisorId,
          formStartDate: DateTime.tryParse(initialSession.startDate),
          formEndDate: DateTime.tryParse(initialSession.endDate),
          formResultDate: DateTime.tryParse(initialSession.resultDate),
          formLocation: initialSession.location,
          formDetail: initialSession.detail,
          isFormDirty: false,
          isLoading: false,
          errorMessage: teacherError,
        );
      } else {
        // Blank CREATE mode
        state = state.copyWith(
          terms: terms,
          selectedTermId: initialTermId,
          currentSessions: currentSessions,
          allTeachers: allTeachers,
          availableTeachers: availableTeachers,
          sessionYears: sessionYears,
          clearEditingSession: true,
          clearNonTeacherSupervisor: true,
          formExTermId: initialTermId,
          formSessionYr: sessionYears.first,
          formExamSupervisorId: availableTeachers.isNotEmpty
              ? (availableTeachers.first['TeacherID'] as num).toInt()
              : null,
          formStartDate: _now(),
          formEndDate: _now().add(const Duration(days: 14)),
          formResultDate: _now().add(const Duration(days: 28)),
          formLocation: '',
          formDetail: '',
          isFormDirty: false,
          isLoading: false,
          errorMessage: teacherError,
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load exam terms: $e',
      );
    }
  }

  Future<List<ExamSessionRow>> _fetchSessionsForTerm(
    Database db,
    int termId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT ExamInfo.*, ExamTerm.TermName, Teachers.TName, Teachers.TCat
      FROM ExamInfo
      LEFT JOIN ExamTerm ON ExamInfo.ExTermID = ExamTerm.ExTermID
      LEFT JOIN Teachers ON ExamInfo.ExamSupervisorID = Teachers.TeacherID
      WHERE ExamInfo.ExTermID = ?
      ORDER BY ExamInfo.ExamInfoID DESC
      ''',
      [termId],
    );
    return rows.map((r) => ExamSessionRow.fromMap(r)).toList();
  }

  /// Select a term from the left pane catalog.
  Future<void> selectTerm(int exTermId) async {
    if (state.selectedTermId == exTermId) return;
    try {
      final db = await _getDb();
      final sessions = await _fetchSessionsForTerm(db, exTermId);
      if (!mounted) return;

      if (sessions.isNotEmpty) {
        // Auto-load latest session for this term into edit mode
        final session = sessions.first;
        Map<String, dynamic>? nonTeacher;
        if (session.supervisorCat != 'Teacher') {
          for (final t in state.allTeachers) {
            if ((t['TeacherID'] as num).toInt() == session.examSupervisorId) {
              nonTeacher = t;
              break;
            }
          }
        }
        state = state.copyWith(
          selectedTermId: exTermId,
          currentSessions: sessions,
          editingSession: session,
          nonTeacherSupervisor: nonTeacher,
          clearNonTeacherSupervisor: nonTeacher == null,
          formExTermId: session.exTermId,
          formSessionYr: session.sessionYr,
          formExamSupervisorId: session.examSupervisorId,
          formStartDate: DateTime.tryParse(session.startDate),
          formEndDate: DateTime.tryParse(session.endDate),
          formResultDate: DateTime.tryParse(session.resultDate),
          formLocation: session.location,
          formDetail: session.detail,
          isFormDirty: false,
          clearErrorMessage: true,
        );
      } else {
        // Blank CREATE mode: warning banner clears
        state = state.copyWith(
          selectedTermId: exTermId,
          currentSessions: const [],
          clearEditingSession: true,
          clearNonTeacherSupervisor: true,
          formExTermId: exTermId,
          formSessionYr: state.sessionYears.isNotEmpty
              ? state.sessionYears.first
              : '2017-2018',
          formExamSupervisorId: state.availableTeachers.isNotEmpty
              ? (state.availableTeachers.first['TeacherID'] as num).toInt()
              : null,
          formStartDate: _now(),
          formEndDate: _now().add(const Duration(days: 14)),
          formResultDate: _now().add(const Duration(days: 28)),
          formLocation: '',
          formDetail: '',
          isFormDirty: false,
          clearErrorMessage: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'Failed to select term: $e');
    }
  }

  /// Select an existing session for editing from the history table.
  void selectSessionForEdit(int examInfoId) {
    ExamSessionRow? target;
    for (final s in state.currentSessions) {
      if (s.examInfoId == examInfoId) {
        target = s;
        break;
      }
    }
    if (target == null) return;

    Map<String, dynamic>? nonTeacher;
    if (target.supervisorCat != 'Teacher') {
      for (final t in state.allTeachers) {
        if ((t['TeacherID'] as num).toInt() == target.examSupervisorId) {
          nonTeacher = t;
          break;
        }
      }
    }

    state = state.copyWith(
      editingSession: target,
      nonTeacherSupervisor: nonTeacher,
      clearNonTeacherSupervisor: nonTeacher == null,
      formExTermId: target.exTermId,
      formSessionYr: target.sessionYr,
      formExamSupervisorId: target.examSupervisorId,
      formStartDate: DateTime.tryParse(target.startDate),
      formEndDate: DateTime.tryParse(target.endDate),
      formResultDate: DateTime.tryParse(target.resultDate),
      formLocation: target.location,
      formDetail: target.detail,
      isFormDirty: false,
      clearErrorMessage: true,
    );
  }

  /// Reset right canvas to clean CREATE mode for active term.
  void newSession() {
    state = state.copyWith(
      clearEditingSession: true,
      clearNonTeacherSupervisor: true,
      formExTermId: state.selectedTermId,
      formSessionYr: state.sessionYears.isNotEmpty
          ? state.sessionYears.first
          : '2017-2018',
      formExamSupervisorId: state.availableTeachers.isNotEmpty
          ? (state.availableTeachers.first['TeacherID'] as num).toInt()
          : null,
      formStartDate: _now(),
      formEndDate: _now().add(const Duration(days: 14)),
      formResultDate: _now().add(const Duration(days: 28)),
      formLocation: '',
      formDetail: '',
      isFormDirty: false,
      clearErrorMessage: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Form Field Setters
  // ---------------------------------------------------------------------------

  void setFormExTermId(int? id) {
    state = state.copyWith(
      formExTermId: id,
      clearFormExTermId: id == null,
      isFormDirty: true,
    );
  }

  void setFormSessionYr(String? yr) {
    state = state.copyWith(
      formSessionYr: yr,
      clearFormSessionYr: yr == null,
      isFormDirty: true,
    );
  }

  void setFormExamSupervisorId(int? id) {
    // If chosen supervisor is in availableTeachers (TCat='Teacher'), clear warning
    bool isTeacher = false;
    for (final t in state.availableTeachers) {
      if ((t['TeacherID'] as num).toInt() == id) {
        isTeacher = true;
        break;
      }
    }
    state = state.copyWith(
      formExamSupervisorId: id,
      clearFormExamSupervisorId: id == null,
      clearNonTeacherSupervisor: isTeacher,
      isFormDirty: true,
    );
  }

  void setFormStartDate(DateTime? d) {
    state = state.copyWith(
      formStartDate: d,
      clearFormStartDate: d == null,
      isFormDirty: true,
    );
  }

  void setFormEndDate(DateTime? d) {
    state = state.copyWith(
      formEndDate: d,
      clearFormEndDate: d == null,
      isFormDirty: true,
    );
  }

  void setFormResultDate(DateTime? d) {
    state = state.copyWith(
      formResultDate: d,
      clearFormResultDate: d == null,
      isFormDirty: true,
    );
  }

  void setFormLocation(String loc) {
    state = state.copyWith(formLocation: loc, isFormDirty: true);
  }

  void setFormDetail(String det) {
    state = state.copyWith(formDetail: det, isFormDirty: true);
  }

  void setSessionSearchId(String s) {
    state = state.copyWith(sessionSearchId: s);
  }

  void clearToast() {
    state = state.copyWith(clearToast: true);
  }

  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  // ---------------------------------------------------------------------------
  // Save Session (Sequential Validation Gates 1-9)
  // ---------------------------------------------------------------------------

  Future<(bool, String)> saveSession() async {
    // 1. Term Gate
    if (state.formExTermId == null) {
      state = state.copyWith(errorMessage: 'Select Term Name Please ');
      return (false, 'Select Term Name Please ');
    }

    // 2. Session Gate
    if (state.formSessionYr == null || state.formSessionYr!.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Choose Session Year ');
      return (false, 'Choose Session Year ');
    }

    // 3. Supervisor Gate
    if (state.formExamSupervisorId == null) {
      state = state.copyWith(errorMessage: 'Select Exam Supervisor Please ');
      return (false, 'Select Exam Supervisor Please ');
    }

    // 4. Start Date Gate
    if (state.formStartDate == null) {
      state = state.copyWith(
        errorMessage: 'Must Enter Examination Start Date Please ',
      );
      return (false, 'Must Enter Examination Start Date Please ');
    }

    // 5. End Date Gate
    if (state.formEndDate == null) {
      state = state.copyWith(
        errorMessage: 'Must Enter Examination End Date Please ',
      );
      return (false, 'Must Enter Examination End Date Please ');
    }

    // 6. Result Date Gate
    if (state.formResultDate == null) {
      state = state.copyWith(errorMessage: 'Must Enter Result Date Please ');
      return (false, 'Must Enter Result Date Please ');
    }

    // 7. Chronological Gate 1: End Date >= Start Date
    if (state.formEndDate!.isBefore(state.formStartDate!)) {
      state = state.copyWith(
        errorMessage: 'End date must be newer then start date',
      );
      return (false, 'End date must be newer then start date');
    }

    // 8. Chronological Gate 2: Result Date >= End Date
    if (state.formResultDate!.isBefore(state.formEndDate!)) {
      state = state.copyWith(
        errorMessage: 'Result must be Newer / Equal then End date',
      );
      return (false, 'Result must be Newer / Equal then End date');
    }

    final db = await _getDb();
    final termId = state.formExTermId!;
    final sessionYr = state.formSessionYr!.trim();
    final currentId = state.editingSession?.examInfoId ?? -1;

    // 9. Duplicate Prevention Check (BOTH create and edit modes, self-excluded)
    final dupRows = await db.rawQuery(
      'SELECT ExamInfoID FROM ExamInfo WHERE ExTermID = ? AND SessionYR = ? AND ExamInfoID != ? LIMIT 1',
      [termId, sessionYr, currentId],
    );

    if (dupRows.isNotEmpty) {
      // Resolve term name
      String termName = 'Term $termId';
      for (final t in state.terms) {
        if (t.exTermId == termId) {
          termName = t.termName;
          break;
        }
      }
      final msg = 'Already Entered $termName in session $sessionYr';
      state = state.copyWith(errorMessage: msg);
      return (false, msg);
    }

    final startStr = _isoFormat.format(state.formStartDate!);
    final endStr = _isoFormat.format(state.formEndDate!);
    final resultStr = _isoFormat.format(state.formResultDate!);
    final supId = state.formExamSupervisorId!;
    final location = state.formLocation.trim();
    final detail = state.formDetail.trim();

    if (state.isEditMode) {
      // UPDATE
      await db.rawUpdate(
        '''
        UPDATE ExamInfo
        SET ExTermID = ?, SessionYR = ?, StartDate = ?, EndDate = ?, ResultDate = ?, ExamSupervisorID = ?, Location = ?, Detail = ?
        WHERE ExamInfoID = ?
        ''',
        [
          termId,
          sessionYr,
          startStr,
          endStr,
          resultStr,
          supId,
          location,
          detail,
          currentId,
        ],
      );
    } else {
      // INSERT (MAX+1)
      final maxRow = await db.rawQuery(
        'SELECT MAX(ExamInfoID) as maxId FROM ExamInfo',
      );
      final nextId = (maxRow.first['maxId'] as num?)?.toInt() ?? 0;
      final newId = nextId + 1;

      await db.rawInsert(
        '''
        INSERT INTO ExamInfo (ExamInfoID, ExTermID, SessionYR, StartDate, EndDate, ResultDate, ExamSupervisorID, Location, Detail)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          newId,
          termId,
          sessionYr,
          startStr,
          endStr,
          resultStr,
          supId,
          location,
          detail,
        ],
      );
    }

    // Refresh sessions and term counts
    final updatedSessions = await _fetchSessionsForTerm(db, termId);
    final countsRows = await db.rawQuery(
      'SELECT ExTermID, COUNT(*) as cnt FROM ExamInfo GROUP BY ExTermID',
    );
    final countsMap = <int, int>{};
    for (final r in countsRows) {
      countsMap[(r['ExTermID'] as num).toInt()] = (r['cnt'] as num).toInt();
    }
    final updatedTerms = state.terms.map((t) {
      return t.copyWith(sessionCount: countsMap[t.exTermId] ?? 0);
    }).toList();

    // Select the saved session in edit mode
    final savedId = state.isEditMode
        ? currentId
        : (updatedSessions.isNotEmpty
              ? updatedSessions.first.examInfoId
              : null);
    ExamSessionRow? savedSession;
    if (savedId != null) {
      for (final s in updatedSessions) {
        if (s.examInfoId == savedId) {
          savedSession = s;
          break;
        }
      }
    }

    Map<String, dynamic>? nonTeacher;
    if (savedSession != null && savedSession.supervisorCat != 'Teacher') {
      for (final t in state.allTeachers) {
        if ((t['TeacherID'] as num).toInt() == savedSession.examSupervisorId) {
          nonTeacher = t;
          break;
        }
      }
    }

    const successMsg = 'New Exam Updated/Added Successfully';
    state = state.copyWith(
      terms: updatedTerms,
      currentSessions: updatedSessions,
      editingSession: savedSession,
      clearEditingSession: savedSession == null,
      nonTeacherSupervisor: nonTeacher,
      clearNonTeacherSupervisor: nonTeacher == null,
      isFormDirty: false,
      toast: successMsg,
      clearErrorMessage: true,
    );

    return (true, successMsg);
  }

  // ---------------------------------------------------------------------------
  // Session ID Lookup (cmdGoExID_Click VA 0x00699740)
  // ---------------------------------------------------------------------------

  Future<(bool, String)> lookupSessionById(int examInfoId) async {
    try {
      final db = await _getDb();
      final rows = await db.rawQuery(
        '''
        SELECT ExamInfo.*, ExamTerm.TermName, Teachers.TName, Teachers.TCat
        FROM ExamInfo
        LEFT JOIN ExamTerm ON ExamInfo.ExTermID = ExamTerm.ExTermID
        LEFT JOIN Teachers ON ExamInfo.ExamSupervisorID = Teachers.TeacherID
        WHERE ExamInfo.ExamInfoID = ?
        ''',
        [examInfoId],
      );

      if (rows.isEmpty) {
        const notFound = 'No Record Exit';
        state = state.copyWith(errorMessage: notFound);
        return (false, notFound);
      }

      final session = ExamSessionRow.fromMap(rows.first);
      final sessions = await _fetchSessionsForTerm(db, session.exTermId);

      Map<String, dynamic>? nonTeacher;
      if (session.supervisorCat != 'Teacher') {
        for (final t in state.allTeachers) {
          if ((t['TeacherID'] as num).toInt() == session.examSupervisorId) {
            nonTeacher = t;
            break;
          }
        }
      }

      state = state.copyWith(
        selectedTermId: session.exTermId,
        currentSessions: sessions,
        editingSession: session,
        nonTeacherSupervisor: nonTeacher,
        clearNonTeacherSupervisor: nonTeacher == null,
        formExTermId: session.exTermId,
        formSessionYr: session.sessionYr,
        formExamSupervisorId: session.examSupervisorId,
        formStartDate: DateTime.tryParse(session.startDate),
        formEndDate: DateTime.tryParse(session.endDate),
        formResultDate: DateTime.tryParse(session.resultDate),
        formLocation: session.location,
        formDetail: session.detail,
        isFormDirty: false,
        clearErrorMessage: true,
      );
      return (true, '');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Search failed: $e');
      return (false, 'Search failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Term Catalog CRUD (Add / Update / Delete)
  // ---------------------------------------------------------------------------

  Future<(bool, String)> addTerm(String name, String remarks) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      const err = 'Must Enter Exam Term Name Please.';
      state = state.copyWith(errorMessage: err);
      return (false, err);
    }

    try {
      final db = await _getDb();
      final maxRow = await db.rawQuery(
        'SELECT MAX(ExTermID) as maxId FROM ExamTerm',
      );
      final nextId = ((maxRow.first['maxId'] as num?)?.toInt() ?? 0) + 1;

      await db.rawInsert(
        'INSERT INTO ExamTerm (ExTermID, TermName, TermRemarks) VALUES (?, ?, ?)',
        [nextId, trimmedName, remarks.trim()],
      );

      // Reload terms
      final countsRows = await db.rawQuery(
        'SELECT ExTermID, COUNT(*) as cnt FROM ExamInfo GROUP BY ExTermID',
      );
      final countsMap = <int, int>{};
      for (final r in countsRows) {
        countsMap[(r['ExTermID'] as num).toInt()] = (r['cnt'] as num).toInt();
      }

      final termRows = await db.rawQuery(
        'SELECT * FROM ExamTerm ORDER BY ExTermID ASC',
      );
      final terms = termRows.map((r) {
        final id = (r['ExTermID'] as num).toInt();
        return ExamTermRow.fromMap(r, sessionCount: countsMap[id] ?? 0);
      }).toList();

      const msg = 'Exam Term Updated Successfully';
      // Auto-select newly added term
      await selectTerm(nextId);
      if (!mounted) return (true, msg);

      state = state.copyWith(terms: terms, toast: msg, clearErrorMessage: true);
      return (true, msg);
    } catch (e) {
      if (!mounted) return (false, 'Failed to add term: $e');
      state = state.copyWith(errorMessage: 'Failed to add term: $e');
      return (false, 'Failed to add term: $e');
    }
  }

  Future<(bool, String)> updateTerm(int id, String name, String remarks) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      const err = 'Must Enter Exam Term Name Please.';
      state = state.copyWith(errorMessage: err);
      return (false, err);
    }

    try {
      final db = await _getDb();
      await db.rawUpdate(
        'UPDATE ExamTerm SET TermName = ?, TermRemarks = ? WHERE ExTermID = ?',
        [trimmedName, remarks.trim(), id],
      );

      final countsRows = await db.rawQuery(
        'SELECT ExTermID, COUNT(*) as cnt FROM ExamInfo GROUP BY ExTermID',
      );
      final countsMap = <int, int>{};
      for (final r in countsRows) {
        countsMap[(r['ExTermID'] as num).toInt()] = (r['cnt'] as num).toInt();
      }

      final termRows = await db.rawQuery(
        'SELECT * FROM ExamTerm ORDER BY ExTermID ASC',
      );
      final terms = termRows.map((r) {
        final tid = (r['ExTermID'] as num).toInt();
        return ExamTermRow.fromMap(r, sessionCount: countsMap[tid] ?? 0);
      }).toList();

      if (!mounted) return (true, 'Exam Term Updated Successfully');
      const msg = 'Exam Term Updated Successfully';
      state = state.copyWith(terms: terms, toast: msg, clearErrorMessage: true);
      return (true, msg);
    } catch (e) {
      if (!mounted) return (false, 'Failed to update term: $e');
      state = state.copyWith(errorMessage: 'Failed to update term: $e');
      return (false, 'Failed to update term: $e');
    }
  }

  Future<(bool, String)> deleteTerm(int id) async {
    try {
      final db = await _getDb();

      // Check if sessions exist for this term
      final cntRow = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ExamInfo WHERE ExTermID = ?',
        [id],
      );
      final sessionCount = (cntRow.first['cnt'] as num?)?.toInt() ?? 0;

      String termName = 'Term $id';
      for (final t in state.terms) {
        if (t.exTermId == id) {
          termName = t.termName;
          break;
        }
      }

      if (sessionCount > 0) {
        final err =
            '"$termName" has $sessionCount scheduled session(s) and cannot be deleted. Remove its sessions first.';
        state = state.copyWith(errorMessage: err);
        return (false, err);
      }

      await db.rawDelete('DELETE FROM ExamTerm WHERE ExTermID = ?', [id]);

      // Reload terms
      final termRows = await db.rawQuery(
        'SELECT * FROM ExamTerm ORDER BY ExTermID ASC',
      );
      final countsRows = await db.rawQuery(
        'SELECT ExTermID, COUNT(*) as cnt FROM ExamInfo GROUP BY ExTermID',
      );
      final countsMap = <int, int>{};
      for (final r in countsRows) {
        countsMap[(r['ExTermID'] as num).toInt()] = (r['cnt'] as num).toInt();
      }
      final terms = termRows.map((r) {
        final tid = (r['ExTermID'] as num).toInt();
        return ExamTermRow.fromMap(r, sessionCount: countsMap[tid] ?? 0);
      }).toList();

      const msg = 'Exam term deleted.';
      if (terms.isNotEmpty) {
        await selectTerm(terms.first.exTermId);
      } else {
        if (!mounted) return (true, msg);
        state = state.copyWith(
          terms: const [],
          clearSelectedTermId: true,
          currentSessions: const [],
          clearEditingSession: true,
          clearNonTeacherSupervisor: true,
        );
      }

      if (!mounted) return (true, msg);
      state = state.copyWith(terms: terms, toast: msg, clearErrorMessage: true);
      return (true, msg);
    } catch (e) {
      if (!mounted) return (false, 'Failed to delete term: $e');
      state = state.copyWith(errorMessage: 'Failed to delete term: $e');
      return (false, 'Failed to delete term: $e');
    }
  }
}

/// Provider for ExamTermScreen.
final examTermProvider = StateNotifierProvider<ExamTermNotifier, ExamTermState>(
  (ref) {
    return ExamTermNotifier(null, ref);
  },
);
