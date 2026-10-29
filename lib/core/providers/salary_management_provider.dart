import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/salary_allowance_item.dart';
import '../../models/salary_slip_row.dart';
import '../db/database.dart';
import 'clock_provider.dart';

/// State object representing the Payroll & Salary Disbursement workstation.
@immutable
class SalaryManagementState {
  final String selectedMonth;
  final DateTime disbursementDate;
  final String categoryFilter;
  final List<SalarySlipRow> roster;
  final int? selectedTeacherId;
  final String? selectedSlipId;
  final List<SalaryAllowanceItem> draftAllowances;
  final double draftDeductions;
  final String draftRemarks;
  final bool isLoading;
  final bool isSaving;
  final bool isBatchDisbursing;
  final String? errorMessage;
  final String? toast;
  final List<Map<String, dynamic>> availableSalParams;
  final List<String> availableMonths;
  final bool isDirty;

  const SalaryManagementState({
    required this.selectedMonth,
    required this.disbursementDate,
    required this.categoryFilter,
    this.roster = const [],
    this.selectedTeacherId,
    this.selectedSlipId,
    this.draftAllowances = const [],
    this.draftDeductions = 0.0,
    this.draftRemarks = '',
    this.isLoading = false,
    this.isSaving = false,
    this.isBatchDisbursing = false,
    this.errorMessage,
    this.toast,
    this.availableSalParams = const [],
    this.availableMonths = const [],
    this.isDirty = false,
  });

  SalarySlipRow? get selectedTeacher {
    if (selectedTeacherId == null) return null;
    try {
      return roster.firstWhere((r) => r.teacherId == selectedTeacherId);
    } catch (_) {
      return null;
    }
  }

  int get grossEarnings =>
      draftAllowances.fold<int>(0, (sum, item) => sum + item.amount);

  int get netPayable => grossEarnings - draftDeductions.toInt();

  int get totalEligibleStaff => roster.length;

  int get grossPayroll => roster
      .where((r) => r.isPaid == 'Y')
      .fold<int>(0, (sum, r) => sum + (r.paidAmt ?? 0) + (r.tDeductions ?? 0));

  int get totalDeductions => roster
      .where((r) => r.isPaid == 'Y')
      .fold<int>(0, (sum, r) => sum + (r.tDeductions ?? 0));

  int get netDisbursed => roster
      .where((r) => r.isPaid == 'Y')
      .fold<int>(0, (sum, r) => sum + (r.paidAmt ?? 0));

  SalaryManagementState copyWith({
    String? selectedMonth,
    DateTime? disbursementDate,
    String? categoryFilter,
    List<SalarySlipRow>? roster,
    int? selectedTeacherId,
    bool clearSelectedTeacher = false,
    String? selectedSlipId,
    bool clearSelectedSlip = false,
    List<SalaryAllowanceItem>? draftAllowances,
    double? draftDeductions,
    String? draftRemarks,
    bool? isLoading,
    bool? isSaving,
    bool? isBatchDisbursing,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? toast,
    bool clearToast = false,
    List<Map<String, dynamic>>? availableSalParams,
    List<String>? availableMonths,
    bool? isDirty,
  }) {
    return SalaryManagementState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      disbursementDate: disbursementDate ?? this.disbursementDate,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      roster: roster ?? this.roster,
      selectedTeacherId: clearSelectedTeacher
          ? null
          : (selectedTeacherId ?? this.selectedTeacherId),
      selectedSlipId: clearSelectedSlip
          ? null
          : (selectedSlipId ?? this.selectedSlipId),
      draftAllowances: draftAllowances ?? this.draftAllowances,
      draftDeductions: draftDeductions ?? this.draftDeductions,
      draftRemarks: draftRemarks ?? this.draftRemarks,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isBatchDisbursing: isBatchDisbursing ?? this.isBatchDisbursing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      toast: clearToast ? null : (toast ?? this.toast),
      availableSalParams: availableSalParams ?? this.availableSalParams,
      availableMonths: availableMonths ?? this.availableMonths,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

/// Provider orchestrating Screen 22 SalaryManagementScreen logic.
class SalaryManagementNotifier extends StateNotifier<SalaryManagementState> {
  final Ref? _ref;

  SalaryManagementNotifier([Ref? ref])
    : _ref = ref,
      super(
        SalaryManagementState(
          selectedMonth: formatMonthYear(
            ref?.read(clockProvider)() ?? DateTime.now(),
          ),
          disbursementDate: ref?.read(clockProvider)() ?? DateTime.now(),
          categoryFilter: 'All',
        ),
      );

  DateTime _now() => _ref?.read(clockProvider)() ?? DateTime.now();

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String formatMonthYear(DateTime dt) {
    return '${_monthNames[dt.month - 1]} ${dt.year}';
  }

  static String deriveYyMM(String salMonth) {
    const monthMap = {
      'january': '01',
      'february': '02',
      'march': '03',
      'april': '04',
      'may': '05',
      'june': '06',
      'july': '07',
      'august': '08',
      'september': '09',
      'october': '10',
      'november': '11',
      'december': '12',
    };
    final parts = salMonth.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final mStr = parts[0].toLowerCase();
      final yStr = parts[1];
      final mm = monthMap[mStr] ?? '01';
      final yy = yStr.length >= 2 ? yStr.substring(yStr.length - 2) : '17';
      return '$yy$mm';
    }
    return '1712';
  }

  /// Initial load on screen mount.
  Future<void> loadInitialData({int? autoSelectTeacherId}) async {
    final now = _now();
    final defaultMonth = formatMonthYear(now);

    // Build comprehensive list of available months (2017-2018 range + current year)
    final months = <String>[];
    for (var y = 2017; y <= 2018; y++) {
      for (var m = 1; m <= 12; m++) {
        months.add('${_monthNames[m - 1]} $y');
      }
    }
    if (now.year != 2017 && now.year != 2018) {
      for (var m = 1; m <= 12; m++) {
        months.add('${_monthNames[m - 1]} ${now.year}');
      }
    }

    try {
      final db = await DatabaseService.instance.database;
      final paramRows = await db.rawQuery(
        'SELECT SalParamID, SalParam FROM TSalParam ORDER BY SalParamID ASC',
      );

      state = state.copyWith(
        selectedMonth: defaultMonth,
        disbursementDate: now,
        categoryFilter: 'All',
        availableMonths: months,
        availableSalParams: paramRows,
        clearErrorMessage: true,
        clearToast: true,
      );

      await loadPayrollCohort();

      if (autoSelectTeacherId != null) {
        await selectEmployee(autoSelectTeacherId);
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to initialize salary parameters: $e',
      );
    }
  }

  /// Loads payroll cohort for currently selected month and category.
  Future<void> loadPayrollCohort() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT t.TeacherID, t.TName, t.TFName, t.TCNIC, t.TCat, t.TIsPresent,
               tm.TSalMasID, tm.PaidAmt, tm.TDeductions, tm.IsPaid, tm.DisbursDate,
               (SELECT COALESCE(SUM(Amount),0) FROM TSalDet WHERE TSalMasID = tm.TSalMasID) AS grossFromDet
        FROM Teachers t
        LEFT JOIN TSalMas tm ON t.TeacherID = tm.TeacherID AND tm.SalMonth = ?
        WHERE t.TIsPresent = 'Y' AND (? = 'All' OR t.TCat = ?)
        ORDER BY t.TeacherID ASC
      ''',
        [state.selectedMonth, state.categoryFilter, state.categoryFilter],
      );

      final roster = rows
          .map((r) => SalarySlipRow.fromMap(r, state.selectedMonth))
          .toList();

      state = state.copyWith(roster: roster, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load payroll cohort: $e',
      );
    }
  }

  /// Selects an employee row from the register and populates the right slip drawer.
  Future<void> selectEmployee(int teacherId) async {
    state = state.copyWith(clearErrorMessage: true);
    try {
      final db = await DatabaseService.instance.database;

      // 1. Check if TSalMas row exists for (teacherId, selectedMonth)
      final masRows = await db.rawQuery(
        '''
        SELECT TSalMasID, TeacherID, DisbursDate, SalMonth, PaidAmt, TDeductions, Detail, IsPaid, PaidDate
        FROM TSalMas
        WHERE TeacherID = ? AND SalMonth = ?
        LIMIT 1
      ''',
        [teacherId, state.selectedMonth],
      );

      if (masRows.isNotEmpty) {
        final mas = masRows.first;
        final tsalmasId = mas['TSalMasID']?.toString();
        final deductions = (mas['TDeductions'] as num?)?.toDouble() ?? 0.0;
        final remarks = mas['Detail']?.toString() ?? '';

        // Query TSalDet line items
        final detRows = await db.rawQuery(
          '''
          SELECT TSalDetSer, TSalMasID, Detail, Amount, Remarks
          FROM TSalDet
          WHERE TSalMasID = ?
          ORDER BY TSalDetSer ASC
        ''',
          [tsalmasId],
        );

        if (detRows.isNotEmpty) {
          final items = detRows
              .map((r) => SalaryAllowanceItem.fromMap(r))
              .toList();
          state = state.copyWith(
            selectedTeacherId: teacherId,
            selectedSlipId: tsalmasId,
            draftAllowances: items,
            draftDeductions: deductions,
            draftRemarks: remarks,
            isDirty: false,
          );
          return;
        }

        // TSalDet has 0 rows for this slip (e.g. legacy seed data): auto-derive from level
        final derived = await _deriveAllowancesForTeacher(db, teacherId);
        state = state.copyWith(
          selectedTeacherId: teacherId,
          selectedSlipId: tsalmasId,
          draftAllowances: derived,
          draftDeductions: deductions,
          draftRemarks: remarks,
          isDirty: false,
        );
        return;
      }

      // No slip exists for this month yet -> auto-derive allowances from TEmp_Lvl & TSalLvlAmount
      final derived = await _deriveAllowancesForTeacher(db, teacherId);
      state = state.copyWith(
        selectedTeacherId: teacherId,
        clearSelectedSlip: true,
        draftAllowances: derived,
        draftDeductions: 0.0,
        draftRemarks: '',
        isDirty: false,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to inspect employee salary details: $e',
      );
    }
  }

  /// Helper to auto-derive allowance items from TEmp_Lvl and TSalLvlAmount.
  Future<List<SalaryAllowanceItem>> _deriveAllowancesForTeacher(
    dynamic db,
    int teacherId,
  ) async {
    // a) Query TEmp_Lvl.TSalLvlID -> salLvl (fallback 3 if no row)
    final empLvlRows = await db.rawQuery(
      'SELECT TSalLvlID FROM TEmp_Lvl WHERE TeacherID = ? LIMIT 1',
      [teacherId],
    );
    final salLvl = empLvlRows.isNotEmpty
        ? (empLvlRows.first['TSalLvlID'] as num).toInt()
        : 3;

    // b) Query TSalLvlAmount JOIN TSalParam
    final tariffRows = await db.rawQuery(
      '''
      SELECT tla.T_SalTD, tla.SalLvl, tla.SalParamID, tla.Amount, tla.Remarks, p.SalParam
      FROM TSalLvlAmount tla
      INNER JOIN TSalParam p ON tla.SalParamID = p.SalParamID
      WHERE tla.SalLvl = ? AND tla.SalYear = '2017-2018'
      ORDER BY tla.SalParamID ASC
    ''',
      [salLvl],
    );

    if (tariffRows.isNotEmpty) {
      final items = <SalaryAllowanceItem>[];
      for (var i = 0; i < tariffRows.length; i++) {
        final r = tariffRows[i];
        items.add(
          SalaryAllowanceItem(
            ser: i + 1,
            detail: (r['SalParam'] as String?) ?? 'Allowance',
            amount: (r['Amount'] as num?)?.toInt() ?? 0,
            remarks: r['Remarks'] as String?,
          ),
        );
      }
      return items;
    }

    // Fallback if no tariffs configured
    return [
      const SalaryAllowanceItem(
        ser: 1,
        detail: 'Basic Salary',
        amount: 6500,
        remarks: 'Standard Base',
      ),
    ];
  }

  void setMonth(String month) {
    if (state.selectedMonth != month) {
      state = state.copyWith(
        selectedMonth: month,
        clearSelectedTeacher: true,
        clearSelectedSlip: true,
        draftAllowances: const [],
        draftDeductions: 0.0,
        draftRemarks: '',
        isDirty: false,
      );
      loadPayrollCohort();
    }
  }

  void setCategoryFilter(String category) {
    if (state.categoryFilter != category) {
      state = state.copyWith(
        categoryFilter: category,
        clearSelectedTeacher: true,
        clearSelectedSlip: true,
        draftAllowances: const [],
        draftDeductions: 0.0,
        draftRemarks: '',
        isDirty: false,
      );
      loadPayrollCohort();
    }
  }

  void setDisbursementDate(DateTime date) {
    state = state.copyWith(disbursementDate: date, isDirty: true);
  }

  void updateDeductions(double amount) {
    state = state.copyWith(
      draftDeductions: amount < 0 ? 0.0 : amount,
      isDirty: true,
    );
  }

  void updateRemarks(String remarks) {
    state = state.copyWith(draftRemarks: remarks, isDirty: true);
  }

  void addAllowanceHead(int salParamId, double amount) {
    String headTitle = 'Allowance';
    for (final p in state.availableSalParams) {
      if ((p['SalParamID'] as num?)?.toInt() == salParamId) {
        headTitle = p['SalParam']?.toString() ?? 'Allowance';
        break;
      }
    }

    final newItems = List<SalaryAllowanceItem>.from(state.draftAllowances);
    newItems.add(
      SalaryAllowanceItem(
        ser: newItems.length + 1,
        detail: headTitle,
        amount: amount.toInt(),
      ),
    );

    state = state.copyWith(draftAllowances: newItems, isDirty: true);
  }

  void removeAllowanceHead(int ser) {
    final remaining = state.draftAllowances
        .where((item) => item.ser != ser)
        .toList();
    final renumbered = <SalaryAllowanceItem>[];
    for (var i = 0; i < remaining.length; i++) {
      renumbered.add(remaining[i].copyWith(ser: i + 1));
    }
    state = state.copyWith(draftAllowances: renumbered, isDirty: true);
  }

  void discardSlip() {
    state = state.copyWith(
      clearSelectedTeacher: true,
      clearSelectedSlip: true,
      draftAllowances: const [],
      draftDeductions: 0.0,
      draftRemarks: '',
      isDirty: false,
      clearErrorMessage: true,
    );
  }

  /// Commits single salary slip to TSalMas and TSalDet atomically.
  Future<bool> commitSlip({int? userLvl = 1}) async {
    // 1. Rights check
    if (userLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return false;
    }

    // 2. Employee check
    final teacherId = state.selectedTeacherId;
    if (teacherId == null) {
      state = state.copyWith(errorMessage: 'Select Employee First');
      return false;
    }

    // 3. Month check
    if (state.selectedMonth.isEmpty) {
      state = state.copyWith(errorMessage: 'Select Payroll Month');
      return false;
    }

    // 4. Gross earnings check
    final gross = state.grossEarnings;
    if (state.draftDeductions > gross) {
      state = state.copyWith(
        errorMessage: 'Deductions cannot exceed total gross earnings',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final db = await DatabaseService.instance.database;
      final yyMM = deriveYyMM(state.selectedMonth);
      final tsalmasId = '$yyMM-$teacherId';
      final net = gross - state.draftDeductions.toInt();
      final paidDate = DateFormat('yyyy-MM-dd').format(state.disbursementDate);
      final disbursDateStr = DateFormat('yyyy-MM-dd')
          .format(state.disbursementDate);

      await db.transaction((txn) async {
        // Explicit pre-check UPSERT pattern
        final existing = await txn.rawQuery(
          'SELECT TSalMasID FROM TSalMas WHERE TeacherID = ? AND SalMonth = ? LIMIT 1',
          [teacherId, state.selectedMonth],
        );

        if (existing.isNotEmpty) {
          await txn.rawUpdate(
            '''
            UPDATE TSalMas
            SET TSalMasID = ?, DisbursDate = ?, PaidAmt = ?, TDeductions = ?, Detail = ?, IsPaid = ?, PaidDate = ?
            WHERE TeacherID = ? AND SalMonth = ?
          ''',
            [
              tsalmasId,
              disbursDateStr,
              net,
              state.draftDeductions.toInt(),
              state.draftRemarks,
              'Y',
              paidDate,
              teacherId,
              state.selectedMonth,
            ],
          );
        } else {
          await txn.rawInsert(
            '''
            INSERT INTO TSalMas (TSalMasID, TeacherID, DisbursDate, SalMonth, PaidAmt, TDeductions, Detail, IsPaid, PaidDate)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
            [
              tsalmasId,
              teacherId,
              disbursDateStr,
              state.selectedMonth,
              net,
              state.draftDeductions.toInt(),
              state.draftRemarks,
              'Y',
              paidDate,
            ],
          );
        }

        // TSalDet: Delete-then-Insert
        await txn.rawDelete('DELETE FROM TSalDet WHERE TSalMasID = ?', [
          tsalmasId,
        ]);

        for (var i = 0; i < state.draftAllowances.length; i++) {
          final item = state.draftAllowances[i];
          await txn.rawInsert(
            '''
            INSERT INTO TSalDet (TSalDetSer, TSalMasID, Detail, Amount, Remarks)
            VALUES (?, ?, ?, ?, ?)
          ''',
            [i + 1, tsalmasId, item.detail, item.amount, item.remarks ?? ''],
          );
        }
      });

      // Reload cohort and refresh right pane state
      await loadPayrollCohort();
      await selectEmployee(teacherId);

      state = state.copyWith(
        isSaving: false,
        isDirty: false,
        toast: 'Salary Slip Committed & Disbursed Successfully',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Database error committing salary slip: $e',
      );
      return false;
    }
  }

  /// Disburses all pending salary slips in cohort loop.
  Future<bool> batchDisbursePending({int? userLvl = 1}) async {
    if (userLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return false;
    }

    final pendingRows = state.roster.where((r) => r.isPending).toList();
    if (pendingRows.isEmpty) {
      state = state.copyWith(toast: 'No pending salary slips to disburse.');
      return true;
    }

    state = state.copyWith(isBatchDisbursing: true, clearErrorMessage: true);

    try {
      final db = await DatabaseService.instance.database;
      final yyMM = deriveYyMM(state.selectedMonth);
      final paidDate = DateFormat('yyyy-MM-dd').format(state.disbursementDate);
      final disbursDateStr = DateFormat('yyyy-MM-dd')
          .format(state.disbursementDate);

      for (final row in pendingRows) {
        final teacherId = row.teacherId;
        final tsalmasId = '$yyMM-$teacherId';

        // Derive allowances for this teacher
        final allowances = await _deriveAllowancesForTeacher(db, teacherId);
        final gross = allowances.fold<int>(0, (sum, i) => sum + i.amount);
        final deductions = row.tDeductions ?? 0;
        final net = gross - deductions;

        await db.transaction((txn) async {
          final existing = await txn.rawQuery(
            'SELECT TSalMasID FROM TSalMas WHERE TeacherID = ? AND SalMonth = ? LIMIT 1',
            [teacherId, state.selectedMonth],
          );

          if (existing.isNotEmpty) {
            await txn.rawUpdate(
              '''
              UPDATE TSalMas
              SET TSalMasID = ?, DisbursDate = ?, PaidAmt = ?, TDeductions = ?, Detail = ?, IsPaid = ?, PaidDate = ?
              WHERE TeacherID = ? AND SalMonth = ?
            ''',
              [
                tsalmasId,
                disbursDateStr,
                net,
                deductions,
                row.detail ?? '',
                'Y',
                paidDate,
                teacherId,
                state.selectedMonth,
              ],
            );
          } else {
            await txn.rawInsert(
              '''
              INSERT INTO TSalMas (TSalMasID, TeacherID, DisbursDate, SalMonth, PaidAmt, TDeductions, Detail, IsPaid, PaidDate)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
              [
                tsalmasId,
                teacherId,
                disbursDateStr,
                state.selectedMonth,
                net,
                deductions,
                row.detail ?? '',
                'Y',
                paidDate,
              ],
            );
          }

          await txn.rawDelete('DELETE FROM TSalDet WHERE TSalMasID = ?', [
            tsalmasId,
          ]);

          for (var i = 0; i < allowances.length; i++) {
            final item = allowances[i];
            await txn.rawInsert(
              '''
              INSERT INTO TSalDet (TSalDetSer, TSalMasID, Detail, Amount, Remarks)
              VALUES (?, ?, ?, ?, ?)
            ''',
              [i + 1, tsalmasId, item.detail, item.amount, item.remarks ?? ''],
            );
          }
        });
      }

      await loadPayrollCohort();

      state = state.copyWith(
        isBatchDisbursing: false,
        toast: 'Salary Slip Committed & Disbursed Successfully',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isBatchDisbursing: false,
        errorMessage: 'Error during batch disbursement: $e',
      );
      return false;
    }
  }

  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  void clearToast() {
    state = state.copyWith(clearToast: true);
  }
}

/// Riverpod provider for SalaryManagementScreen.
final salaryManagementProvider =
    StateNotifierProvider<SalaryManagementNotifier, SalaryManagementState>(
      (ref) => SalaryManagementNotifier(ref),
    );
