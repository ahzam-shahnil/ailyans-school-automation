import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/fee_ledger_row.dart';
import '../db/database.dart';
import '../utils/fee_head_display.dart';

/// Immutable state for FeeLedgerScreen.
@immutable
class FeeLedgerState {
  final String selectedSessionYr;
  final String? selectedMonth; // null represents "All Months"
  final int? selectedClassId;
  final int? selectedClassSecId;
  final String selectedStatus; // 'All', 'Paid', 'Unpaid', 'Overdue'
  final String? activePreset; // null | 'thisMonth' | 'today'
  final bool todayOnly; // true when [Today] preset is active
  final String searchQuery;
  final String sortColumn;
  final bool sortAscending;
  final int page;
  final int pageSize;

  // KPI Aggregates
  final int grossReceivable;
  final int totalConcessions;
  final int cashCollected;
  final int outstandingDues;
  final int totalBilledCount;
  final int fullWaiversCount;
  final int paidCount;
  final int defaultersCount;

  // Ledger Rows
  final List<FeeLedgerRow> rows;
  final int totalRowCount;

  // Dropdown Metadata
  final List<String> sessionYears;
  final List<String> months;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> sections;

  final bool isLoading;
  final String? errorMessage;
  final String? toast;

  const FeeLedgerState({
    this.selectedSessionYr = '2017-2018',
    this.selectedMonth,
    this.selectedClassId,
    this.selectedClassSecId,
    this.selectedStatus = 'All',
    this.activePreset,
    this.todayOnly = false,
    this.searchQuery = '',
    this.sortColumn = 'voucher_id',
    this.sortAscending = false,
    this.page = 1,
    this.pageSize = 25,
    this.grossReceivable = 0,
    this.totalConcessions = 0,
    this.cashCollected = 0,
    this.outstandingDues = 0,
    this.totalBilledCount = 0,
    this.fullWaiversCount = 0,
    this.paidCount = 0,
    this.defaultersCount = 0,
    this.rows = const [],
    this.totalRowCount = 0,
    this.sessionYears = const [],
    this.months = const [],
    this.classes = const [],
    this.sections = const [],
    this.isLoading = false,
    this.errorMessage,
    this.toast,
  });

  FeeLedgerState copyWith({
    String? selectedSessionYr,
    String? selectedMonth,
    bool clearMonth = false,
    int? selectedClassId,
    bool clearClassId = false,
    int? selectedClassSecId,
    bool clearClassSecId = false,
    String? selectedStatus,
    String? activePreset,
    bool clearActivePreset = false,
    bool? todayOnly,
    String? searchQuery,
    String? sortColumn,
    bool? sortAscending,
    int? page,
    int? pageSize,
    int? grossReceivable,
    int? totalConcessions,
    int? cashCollected,
    int? outstandingDues,
    int? totalBilledCount,
    int? fullWaiversCount,
    int? paidCount,
    int? defaultersCount,
    List<FeeLedgerRow>? rows,
    int? totalRowCount,
    List<String>? sessionYears,
    List<String>? months,
    List<Map<String, dynamic>>? classes,
    List<Map<String, dynamic>>? sections,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? toast,
    bool clearToast = false,
  }) {
    return FeeLedgerState(
      selectedSessionYr: selectedSessionYr ?? this.selectedSessionYr,
      selectedMonth: clearMonth ? null : (selectedMonth ?? this.selectedMonth),
      selectedClassId: clearClassId
          ? null
          : (selectedClassId ?? this.selectedClassId),
      selectedClassSecId: clearClassSecId
          ? null
          : (selectedClassSecId ?? this.selectedClassSecId),
      selectedStatus: selectedStatus ?? this.selectedStatus,
      activePreset: clearActivePreset
          ? null
          : (activePreset ?? this.activePreset),
      todayOnly: todayOnly ?? this.todayOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      grossReceivable: grossReceivable ?? this.grossReceivable,
      totalConcessions: totalConcessions ?? this.totalConcessions,
      cashCollected: cashCollected ?? this.cashCollected,
      outstandingDues: outstandingDues ?? this.outstandingDues,
      totalBilledCount: totalBilledCount ?? this.totalBilledCount,
      fullWaiversCount: fullWaiversCount ?? this.fullWaiversCount,
      paidCount: paidCount ?? this.paidCount,
      defaultersCount: defaultersCount ?? this.defaultersCount,
      rows: rows ?? this.rows,
      totalRowCount: totalRowCount ?? this.totalRowCount,
      sessionYears: sessionYears ?? this.sessionYears,
      months: months ?? this.months,
      classes: classes ?? this.classes,
      sections: sections ?? this.sections,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      toast: clearToast ? null : (toast ?? this.toast),
    );
  }
}

/// StateNotifier managing FeeLedger analytics queries, filter mutations, and row pagination.
class FeeLedgerNotifier extends StateNotifier<FeeLedgerState> {
  FeeLedgerNotifier() : super(const FeeLedgerState()) {
    init();
  }

  static const _sortMap = {
    'voucher_id': 'vm.VoucherMasID',
    'reg_id': 'vm.Student_Class_StuRegID',
    'name': 'sr.NameFirst',
    'class_sec': 'c.CName',
    'gross': 'vm.SubTotal',
    'discount': 'vm.Discount',
    'net_due': 'netDue',
    'status': 'vm.IsPaid',
    'due_date': 'vm.DueDate',
  };

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

  Future<void> init() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = await DatabaseService.instance.database;

      // 1. Load Sessions
      final sessionRows = await db.rawQuery(
        "SELECT DISTINCT SessionYr FROM Student_Class WHERE SessionYr IS NOT NULL AND SessionYr != '' ORDER BY SessionYr DESC",
      );
      final sessions = sessionRows
          .map((r) => (r['SessionYr'] as String).trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final defaultSession = sessions.contains('2017-2018')
          ? '2017-2018'
          : (sessions.isNotEmpty ? sessions.first : '2017-2018');

      // 2. Load Months
      final monthRows = await db.rawQuery(
        "SELECT DISTINCT ForMonth FROM VoucharMas WHERE ForMonth IS NOT NULL AND ForMonth != '' ORDER BY VoucherMasID DESC",
      );
      final months = monthRows
          .map((r) => (r['ForMonth'] as String).trim())
          .where((m) => m.isNotEmpty)
          .toList();
      final defaultMonth = months.isNotEmpty ? months.first : null;

      // 3. Load Classes
      final classRows = await db.rawQuery(
        'SELECT ClassID, CName FROM Class ORDER BY ClassID ASC',
      );

      // 4. Load Sections
      final secRows = await db.rawQuery(
        'SELECT ClassSecID, ClassID, SecName FROM ClassSec ORDER BY ClassSecID ASC',
      );

      if (!mounted) return;
      state = state.copyWith(
        sessionYears: sessions.isNotEmpty ? sessions : [defaultSession],
        selectedSessionYr: defaultSession,
        months: months,
        selectedMonth: defaultMonth,
        classes: classRows,
        sections: secRows,
      );

      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize fee ledger: $e',
      );
    }
  }

  void setSession(String sessionYr) {
    if (state.selectedSessionYr == sessionYr) return;
    state = state.copyWith(selectedSessionYr: sessionYr, page: 1);
    _fetchData();
  }

  void setMonth(String? month) {
    if (state.selectedMonth == month) return;
    state = state.copyWith(
      selectedMonth: month,
      clearMonth: month == null,
      page: 1,
    );
    _fetchData();
  }

  void setClass(int? classId) {
    if (state.selectedClassId == classId) return;
    state = state.copyWith(
      selectedClassId: classId,
      clearClassId: classId == null,
      clearClassSecId: true, // reset section when class changes
      page: 1,
    );
    _fetchData();
  }

  void setSection(int? secId) {
    if (state.selectedClassSecId == secId) return;
    state = state.copyWith(
      selectedClassSecId: secId,
      clearClassSecId: secId == null,
      page: 1,
    );
    _fetchData();
  }

  void setStatus(String status) {
    if (state.selectedStatus == status) return;
    state = state.copyWith(selectedStatus: status, page: 1);
    _fetchData();
  }

  void setSearch(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query, page: 1);
    _fetchData();
  }

  void setSort(String column) {
    final isSame = state.sortColumn == column;
    state = state.copyWith(
      sortColumn: column,
      sortAscending: isSame ? !state.sortAscending : false,
      page: 1,
    );
    _fetchData();
  }

  void setPage(int page) {
    if (state.page == page) return;
    state = state.copyWith(page: page);
    _fetchData();
  }

  void setPageSize(int size) {
    if (state.pageSize == size) return;
    state = state.copyWith(pageSize: size, page: 1);
    _fetchData();
  }

  /// Preset [This Month]: selects current calendar month if available or latest month.
  void applyThisMonth() {
    // Toggle: if already active, clear
    if (state.activePreset == 'thisMonth') {
      state = state.copyWith(
        clearActivePreset: true,
        todayOnly: false,
        page: 1,
      );
      _fetchData();
      return;
    }
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final match = state.months.firstWhere(
      (m) => m.toLowerCase() == monthName.toLowerCase(),
      orElse: () => state.months.isNotEmpty ? state.months.first : monthName,
    );
    state = state.copyWith(
      selectedMonth: match,
      activePreset: 'thisMonth',
      todayOnly: false,
      page: 1,
    );
    _fetchData();
  }

  /// Preset [Today]: sets query for cash collections made today.
  void applyToday() {
    // Toggle: if already active, clear
    if (state.activePreset == 'today') {
      state = state.copyWith(
        clearActivePreset: true,
        todayOnly: false,
        page: 1,
      );
      _fetchData();
      return;
    }
    state = state.copyWith(activePreset: 'today', todayOnly: true, page: 1);
    _fetchData();
  }

  void clearFilters() {
    final defaultMonth = state.months.isNotEmpty ? state.months.first : null;
    state = state.copyWith(
      clearMonth: defaultMonth == null,
      selectedMonth: defaultMonth,
      clearClassId: true,
      clearClassSecId: true,
      selectedStatus: 'All',
      searchQuery: '',
      clearActivePreset: true,
      todayOnly: false,
      page: 1,
    );
    _fetchData();
  }

  Future<void> refresh() => _fetchData();

  /// Query line items from VoucharDet joined to FeeParameters for a specific voucher.
  Future<List<FeeLedgerDetailItem>> loadVoucherDetails(
    String voucherMasId,
  ) async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT vd.feeParameterID, fp.ParamDesciption, vd.Amount, vd.Discount
        FROM VoucharDet vd
        LEFT JOIN FeeParameters fp ON vd.feeParameterID = fp.FeeParamID
        WHERE vd.VoucharMasID = ?
        ORDER BY vd.feeParameterID ASC
        ''',
        [voucherMasId],
      );

      return rows.map((r) {
        return FeeLedgerDetailItem(
          feeParamId: (r['feeParameterID'] as num?)?.toInt() ?? 0,
          paramDescription: FeeHeadDisplay.of(r['ParamDesciption'] as String?),
          amount: (r['Amount'] as num?)?.toInt() ?? 0,
          discount: (r['Discount'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to load voucher details: $e');
      return [];
    }
  }

  /// Compiles class collection summary grouped by class for the current billing month.
  Future<List<Map<String, dynamic>>> loadClassCollectionSummary() async {
    try {
      final db = await DatabaseService.instance.database;
      final whereClauses = <String>[];
      final args = <dynamic>[];

      if (state.selectedSessionYr.isNotEmpty) {
        whereClauses.add('vm.SessionYr = ?');
        args.add(state.selectedSessionYr);
      }
      if (state.selectedMonth != null && state.selectedMonth != 'All Months') {
        whereClauses.add('vm.ForMonth = ?');
        args.add(state.selectedMonth);
      }

      final whereSql = whereClauses.isNotEmpty
          ? 'WHERE ${whereClauses.join(" AND ")}'
          : '';

      final rows = await db.rawQuery('''
        SELECT
          c.ClassID,
          COALESCE(c.CName, 'Unassigned') AS className,
          COUNT(vm.VoucherMasID) AS totalBilled,
          COALESCE(SUM(vm.SubTotal), 0) AS grossReceivable,
          COALESCE(SUM(vm.Discount), 0) AS totalDiscounts,
          COALESCE(SUM(COALESCE(vm.PaidAmt, 0)), 0) AS cashCollected,
          COALESCE(SUM(vm.SubTotal - vm.Discount - COALESCE(vm.PaidAmt, 0)), 0) AS outstandingDues,
          SUM(CASE WHEN vm.IsPaid = 'Y' THEN 1 ELSE 0 END) AS paidVouchersCount
        FROM VoucharMas vm
        LEFT JOIN Class c ON vm.ClassID = c.ClassID
        $whereSql
        GROUP BY c.ClassID, c.CName
        ORDER BY c.ClassID ASC
        ''', args);
      return rows;
    } catch (e) {
      debugPrint('Error generating class collection summary: $e');
      return [];
    }
  }

  /// Internal data fetching executing synchronized KPI aggregate & row queries.
  Future<void> _fetchData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = await DatabaseService.instance.database;

      // Build unified WHERE conditions
      final whereConditions = <String>[];
      final whereArgs = <dynamic>[];

      if (state.selectedSessionYr.isNotEmpty) {
        whereConditions.add('vm.SessionYr = ?');
        whereArgs.add(state.selectedSessionYr);
      }

      if (state.selectedMonth != null &&
          state.selectedMonth != 'All Months' &&
          state.selectedMonth!.trim().isNotEmpty) {
        whereConditions.add('vm.ForMonth = ?');
        whereArgs.add(state.selectedMonth!.trim());
      }

      if (state.selectedClassId != null) {
        whereConditions.add('vm.ClassID = ?');
        whereArgs.add(state.selectedClassId);
      }

      if (state.selectedClassSecId != null) {
        whereConditions.add('sc.ClassSecID = ?');
        whereArgs.add(state.selectedClassSecId);
      }

      if (state.selectedStatus == 'Paid') {
        whereConditions.add("vm.IsPaid = 'Y'");
      } else if (state.selectedStatus == 'Unpaid') {
        whereConditions.add("vm.IsPaid = 'N'");
      } else if (state.selectedStatus == 'Overdue') {
        whereConditions.add("vm.IsPaid = 'O'");
      }

      if (state.todayOnly) {
        whereConditions.add(
          "(DATE(vm.PaidDate) = DATE('now') OR DATE(vm.VDate) = DATE('now'))",
        );
      }

      if (state.searchQuery.trim().isNotEmpty) {
        final term = '%${state.searchQuery.trim()}%';
        whereConditions.add(
          '(vm.VoucherMasID LIKE ? OR CAST(vm.Student_Class_StuRegID AS TEXT) LIKE ? OR sr.NameFirst LIKE ? OR sr.NameLast LIKE ?)',
        );
        whereArgs.addAll([term, term, term, term]);
      }

      final whereClause = whereConditions.isNotEmpty
          ? 'WHERE ${whereConditions.join(" AND ")}'
          : '';

      const fromClause = '''
        FROM VoucharMas vm
        INNER JOIN Stu_Reg sr ON vm.Student_Class_StuRegID = sr.Stu_RegID
        LEFT JOIN Class c ON vm.ClassID = c.ClassID
        LEFT JOIN Student_Class sc ON vm.Student_Class_StuRegID = sc.Stu_RegID AND vm.SessionYr = sc.SessionYr
        LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
      ''';

      // 1. KPI Aggregation Query
      final kpiSql =
          '''
        SELECT
          COUNT(*) AS totalBilledCount,
          COALESCE(SUM(vm.SubTotal), 0) AS grossReceivable,
          COALESCE(SUM(vm.Discount), 0) AS totalConcessions,
          COALESCE(SUM(COALESCE(vm.PaidAmt, 0)), 0) AS cashCollected,
          COALESCE(SUM(vm.SubTotal - vm.Discount - COALESCE(vm.PaidAmt, 0)), 0) AS outstandingDues,
          SUM(CASE WHEN vm.IsPaid = 'Y' OR (vm.SubTotal - vm.Discount - COALESCE(vm.PaidAmt, 0)) <= 0 THEN 1 ELSE 0 END) AS paidCount,
          SUM(CASE WHEN vm.IsPaid IN ('N', 'O') AND (vm.SubTotal - vm.Discount - COALESCE(vm.PaidAmt, 0)) > 0 THEN 1 ELSE 0 END) AS defaultersCount,
          SUM(CASE WHEN vm.Discount > 0 AND vm.Discount >= vm.SubTotal THEN 1 ELSE 0 END) AS fullWaiversCount
        $fromClause
        $whereClause
      ''';

      final kpiRows = await db.rawQuery(kpiSql, whereArgs);
      if (!mounted) return;
      final kpi = kpiRows.isNotEmpty ? kpiRows.first : <String, dynamic>{};

      final totalCount = (kpi['totalBilledCount'] as num?)?.toInt() ?? 0;
      final gross = (kpi['grossReceivable'] as num?)?.toInt() ?? 0;
      final concessions = (kpi['totalConcessions'] as num?)?.toInt() ?? 0;
      final collected = (kpi['cashCollected'] as num?)?.toInt() ?? 0;
      final dues = (kpi['outstandingDues'] as num?)?.toInt() ?? 0;
      final paid = (kpi['paidCount'] as num?)?.toInt() ?? 0;
      final defaulters = (kpi['defaultersCount'] as num?)?.toInt() ?? 0;
      final waivers = (kpi['fullWaiversCount'] as num?)?.toInt() ?? 0;

      // 2. Paginated Rows Query
      final orderCol = _sortMap[state.sortColumn] ?? 'vm.VoucherMasID';
      final orderDir = state.sortAscending ? 'ASC' : 'DESC';
      final offset = (state.page - 1) * state.pageSize;

      final rowsSql =
          '''
        SELECT
          vm.VoucherMasID,
          vm.Student_Class_StuRegID,
          sr.NameFirst,
          sr.NameLast,
          sr.F_Name,
          sr.Mobile1,
          c.CName AS class_name,
          cs.SecName AS section_name,
          sc.ClassRollNo,
          vm.SubTotal,
          vm.Discount,
          COALESCE(vm.PaidAmt, 0) AS PaidAmt,
          (vm.SubTotal - vm.Discount - COALESCE(vm.PaidAmt, 0)) AS netDue,
          vm.IsPaid,
          vm.DueDate,
          vm.PaidDate,
          vm.ForMonth,
          vm.SessionYr,
          vm.BankID
        $fromClause
        $whereClause
        ORDER BY $orderCol $orderDir
        LIMIT ? OFFSET ?
      ''';

      final rowQueryArgs = List<dynamic>.from(whereArgs)
        ..addAll([state.pageSize, offset]);
      final rawRows = await db.rawQuery(rowsSql, rowQueryArgs);
      if (!mounted) return;
      final ledgerRows = rawRows.map((r) => FeeLedgerRow.fromMap(r)).toList();

      state = state.copyWith(
        isLoading: false,
        totalRowCount: totalCount,
        grossReceivable: gross,
        totalConcessions: concessions,
        cashCollected: collected,
        outstandingDues: dues,
        totalBilledCount: totalCount,
        fullWaiversCount: waivers,
        paidCount: paid,
        defaultersCount: defaulters,
        rows: ledgerRows,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Database query failed: $e',
      );
    }
  }
}

/// Global provider for the FeeLedger state notifier.
final feeLedgerProvider =
    StateNotifierProvider<FeeLedgerNotifier, FeeLedgerState>((ref) {
      return FeeLedgerNotifier();
    });
