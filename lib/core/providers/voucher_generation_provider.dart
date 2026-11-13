import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/student.dart';
import '../../models/voucher_preview_row.dart';
import '../db/database.dart';
import '../sync/sync_provider.dart';

/// Default offset between issue date and due date, in days.
/// Preserves the pre-G-7 behavior of issueDate=day 1 -> dueDate=day 10.
const int kDefaultDueOffsetDays = 9;

/// Filter state for cohort voucher generation.
class VoucherGenFilters {
  final String sessionYr;
  final String billingMonth;
  final int? classId;
  final int? classSecId;
  final DateTime issueDate;
  final DateTime dueDate;
  final int bankId;
  final bool includeArrears;
  final int lateFineAmount;
  final Set<int> excludedFeeParamIds;
  final String mode;
  final int? selectedStuRegId;

  VoucherGenFilters({
    this.sessionYr = '2017-2018',
    this.billingMonth = 'October 2017',
    this.classId = 13, // Default Class 10
    this.classSecId,
    DateTime? issueDate,
    DateTime? dueDate,
    this.bankId = 1,
    this.includeArrears = true,
    this.lateFineAmount = 100,
    this.excludedFeeParamIds = const {},
    this.mode = 'batch',
    this.selectedStuRegId,
  }) : issueDate = issueDate ?? DateTime(2017, 10, 1),
       dueDate = dueDate ?? DateTime(2017, 10, 10);

  VoucherGenFilters copyWith({
    String? sessionYr,
    String? billingMonth,
    int? classId,
    bool clearClassId = false,
    int? classSecId,
    bool clearClassSecId = false,
    DateTime? issueDate,
    DateTime? dueDate,
    int? bankId,
    bool? includeArrears,
    int? lateFineAmount,
    Set<int>? excludedFeeParamIds,
    String? mode,
    int? selectedStuRegId,
    bool clearSelectedStudent = false,
  }) {
    return VoucherGenFilters(
      sessionYr: sessionYr ?? this.sessionYr,
      billingMonth: billingMonth ?? this.billingMonth,
      classId: clearClassId ? null : (classId ?? this.classId),
      classSecId: clearClassSecId ? null : (classSecId ?? this.classSecId),
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      bankId: bankId ?? this.bankId,
      includeArrears: includeArrears ?? this.includeArrears,
      lateFineAmount: lateFineAmount ?? this.lateFineAmount,
      excludedFeeParamIds: excludedFeeParamIds ?? this.excludedFeeParamIds,
      mode: mode ?? this.mode,
      selectedStuRegId: clearSelectedStudent
          ? null
          : (selectedStuRegId ?? this.selectedStuRegId),
    );
  }
}

/// Represents a tariff head configured in Cls_Param_Fee.
class FeeHeadSummary {
  final int feeParamId;
  final String description;
  final double fee;

  const FeeHeadSummary({
    required this.feeParamId,
    required this.description,
    required this.fee,
  });
}

/// Bank option retrieved from BankInfo table.
class BankOption {
  final int bankInfoId;
  final String bankName;
  final String branch;
  final String acctNo;
  final bool isDefault;

  const BankOption({
    required this.bankInfoId,
    required this.bankName,
    required this.branch,
    required this.acctNo,
    required this.isDefault,
  });

  String get displayName => '$bankName - $branch';
}

/// Helper method to compute a 4-char yyMM prefix for the selected billing month.
String _yyMmPrefix(String monthName) {
  return billingMonthToYyMm(monthName);
}

/// Helper to normalize full month names (e.g., "October 2026") to 3-letter format ("Oct-2026").
String normalizeBillingMonthForStorage(String monthStr) {
  final parts = monthStr.trim().split(RegExp(r'[\s\-/]+'));
  if (parts.length >= 2) {
    int? year = int.tryParse(parts[1]);
    String monthPart = parts[0];
    if (year == null) {
      year = int.tryParse(parts[0]);
      monthPart = parts[1];
    }
    if (year != null && year >= 2020) {
      const monthMap = {
        'jan': 'Jan',
        'january': 'Jan',
        'feb': 'Feb',
        'february': 'Feb',
        'mar': 'Mar',
        'march': 'Mar',
        'apr': 'Apr',
        'april': 'Apr',
        'may': 'May',
        'jun': 'Jun',
        'june': 'Jun',
        'jul': 'Jul',
        'july': 'Jul',
        'aug': 'Aug',
        'august': 'Aug',
        'sep': 'Sep',
        'september': 'Sep',
        'oct': 'Oct',
        'october': 'Oct',
        'nov': 'Nov',
        'november': 'Nov',
        'dec': 'Dec',
        'december': 'Dec',
      };
      final m = monthMap[monthPart.toLowerCase()];
      if (m != null) {
        return '$m-$year';
      }
    }
  }
  return monthStr;
}

/// Execution summary displayed in the Batch Complete Dialog.
class BatchGenerationSummary {
  final int generatedCount;
  final int skippedCount;
  final int totalBilled;
  final int arrearsRolledOver;
  final int concessionsApplied;
  final List<String> skippedReasons;

  const BatchGenerationSummary({
    required this.generatedCount,
    required this.skippedCount,
    required this.totalBilled,
    required this.arrearsRolledOver,
    required this.concessionsApplied,
    required this.skippedReasons,
  });
}

/// Helper to convert "Month YYYY" (e.g. "October 2017") or "MMM-yyyy" (e.g. "Oct-2026") to "yyMM" (e.g. "1710", "2610").
String billingMonthToYyMm(String billingMonth) {
  final parts = billingMonth.trim().split(RegExp(r'[\s\-/]+'));
  if (parts.length >= 2) {
    int? year = int.tryParse(parts[1]);
    String monthName = parts[0].toLowerCase();
    if (year == null) {
      year = int.tryParse(parts[0]) ?? 2017;
      monthName = parts[1].toLowerCase();
    }
    final yy = (year % 100).toString().padLeft(2, '0');
    const monthMap = {
      'jan': '01',
      'january': '01',
      'feb': '02',
      'february': '02',
      'mar': '03',
      'march': '03',
      'apr': '04',
      'april': '04',
      'may': '05',
      'jun': '06',
      'june': '06',
      'jul': '07',
      'july': '07',
      'aug': '08',
      'august': '08',
      'sep': '09',
      'september': '09',
      'oct': '10',
      'october': '10',
      'nov': '11',
      'november': '11',
      'dec': '12',
      'december': '12',
    };
    final mm = monthMap[monthName] ?? '10';
    return '$yy$mm';
  }
  return '1710';
}

/// Filter Notifier for voucher generation.
class VoucherGenFiltersNotifier extends StateNotifier<VoucherGenFilters> {
  VoucherGenFiltersNotifier() : super(VoucherGenFilters());

  void setMode(String mode) {
    if (mode != 'batch' && mode != 'single') return;
    state = state.copyWith(mode: mode, clearSelectedStudent: mode == 'batch');
  }

  void setSelectedStuRegId(int? stuRegId) {
    state = state.copyWith(
      selectedStuRegId: stuRegId,
      clearSelectedStudent: stuRegId == null,
    );
  }

  void setSessionYr(String sessionYr) {
    state = state.copyWith(sessionYr: sessionYr, clearSelectedStudent: true);
  }

  void setClassId(int? classId) {
    state = state.copyWith(
      classId: classId,
      clearClassId: classId == null,
      clearClassSecId: true,
      excludedFeeParamIds: const {},
      clearSelectedStudent: true,
    );
  }

  void clearFilters() {
    state = state.copyWith(
      clearClassId: true,
      clearClassSecId: true,
      clearSelectedStudent: true,
      excludedFeeParamIds: const {},
    );
  }

  void toggleFeeHead(int feeParamId) {
    final next = Set<int>.from(state.excludedFeeParamIds);
    if (next.contains(feeParamId)) {
      next.remove(feeParamId);
    } else {
      next.add(feeParamId);
    }
    state = state.copyWith(excludedFeeParamIds: next);
  }

  /// Replaces the excluded-fee set wholesale (used by the unified fee
  /// structure table so the class-level preview and the global whole-school /
  /// single-voucher selection always agree after a user interaction).
  void setExcludedFeeParamIds(Set<int> ids) {
    state = state.copyWith(excludedFeeParamIds: Set<int>.from(ids));
  }

  void setIncludeArrears(bool value) {
    state = state.copyWith(includeArrears: value);
  }

  void setClassSecId(int? secId) {
    state = state.copyWith(
      classSecId: secId,
      clearClassSecId: secId == null,
      clearSelectedStudent: true,
    );
  }

  void setBillingMonth(String billingMonth) {
    // Also sync issueDate and dueDate to the selected month
    final normalized = normalizeBillingMonthForStorage(billingMonth);
    final parts = normalized.trim().split(RegExp(r'[\s\-/]+'));
    if (parts.length >= 2) {
      int? year = int.tryParse(parts[1]);
      String monthName = parts[0].toLowerCase();
      if (year == null) {
        year = int.tryParse(parts[0]) ?? 2017;
        monthName = parts[1].toLowerCase();
      }
      const monthMap = {
        'jan': 1,
        'january': 1,
        'feb': 2,
        'february': 2,
        'mar': 3,
        'march': 3,
        'apr': 4,
        'april': 4,
        'may': 5,
        'jun': 6,
        'june': 6,
        'jul': 7,
        'july': 7,
        'aug': 8,
        'august': 8,
        'sep': 9,
        'september': 9,
        'oct': 10,
        'october': 10,
        'nov': 11,
        'november': 11,
        'dec': 12,
        'december': 12,
      };
      final m = monthMap[monthName] ?? 10;
      final newIssue = DateTime(year, m, 1);
      final newDue = newIssue.add(const Duration(days: kDefaultDueOffsetDays));
      state = state.copyWith(
        billingMonth: normalized,
        issueDate: newIssue,
        dueDate: newDue,
      );
      return;
    }
    state = state.copyWith(billingMonth: normalized);
  }

  void setIssueDate(DateTime date) {
    final newDueDate = state.dueDate.isBefore(date)
        ? date.add(const Duration(days: kDefaultDueOffsetDays))
        : state.dueDate;
    state = state.copyWith(issueDate: date, dueDate: newDueDate);
  }

  void setDueDate(DateTime date) {
    // Validation error text is surfaced at the widget layer
    // (VoucherParameterCard, G-7.1). This provider method silently
    // rejects invalid dates and leaves state unchanged.
    if (date.isBefore(state.issueDate)) return;
    state = state.copyWith(dueDate: date);
  }

  void setBankId(int bankId) {
    state = state.copyWith(bankId: bankId);
  }

  void setLateFineAmount(int fine) {
    state = state.copyWith(lateFineAmount: fine);
  }
}

final voucherGenFiltersProvider =
    StateNotifierProvider<VoucherGenFiltersNotifier, VoucherGenFilters>((ref) {
      return VoucherGenFiltersNotifier();
    });

/// Provider for bank account options from BankInfo table.
final voucherBankListProvider = FutureProvider<List<BankOption>>((ref) async {
  final db = await DatabaseService.instance.database;
  final rows = await db.query(
    'BankInfo',
    columns: ['BankInfoID', 'BankName', 'Branch', 'AcctNo', 'BankDefault'],
    orderBy: 'BankInfoID ASC',
  );

  return rows.map((r) {
    return BankOption(
      bankInfoId: r['BankInfoID'] as int,
      bankName: (r['BankName'] as String? ?? '').trim(),
      branch: (r['Branch'] as String? ?? '').trim(),
      acctNo: (r['AcctNo'] as String? ?? '').trim(),
      isDefault: (r['BankDefault'] as String? ?? 'N') == 'Y',
    );
  }).toList();
});

/// Provider for fee heads configured in Cls_Param_Fee for the selected class.
/// Watches [dbDataVersionProvider] so edits made in Fee Structure & Bank Setup
/// reflect here immediately.
final voucherClassTariffsProvider =
    FutureProvider.family<List<FeeHeadSummary>, int?>((ref, classId) async {
      ref.watch(dbDataVersionProvider);
      if (classId == null) return [];
      final filters = ref.watch(voucherGenFiltersProvider);
      final db = await DatabaseService.instance.database;

      final rows = await db.rawQuery(
        '''
    SELECT cpf.FeeParamID, cpf.Fee, fp.ParamDesciption
    FROM Cls_Param_Fee cpf
    LEFT JOIN FeeParameters fp ON cpf.FeeParamID = fp.FeeParamID
    WHERE cpf.ClassID = ? AND cpf.FeeYr = ?
    ORDER BY cpf.FeeParamID ASC
  ''',
        [classId, filters.sessionYr],
      );

      return rows.map((r) {
        return FeeHeadSummary(
          feeParamId: r['FeeParamID'] as int,
          description: (r['ParamDesciption'] as String? ?? 'Fee').trim(),
          fee: (r['Fee'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    });

/// Provider that fetches active students enrolled in the currently filtered cohort.
final voucherCohortStudentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final filters = ref.watch(voucherGenFiltersProvider);
      final db = await DatabaseService.instance.database;

      final whereClauses = <String>['sc.Present = 1', 'sc.SessionYr = ?'];
      final whereArgs = <dynamic>[filters.sessionYr];

      if (filters.classId != null) {
        whereClauses.add('sc.ClassID = ?');
        whereArgs.add(filters.classId);
      }

      if (filters.classSecId != null) {
        whereClauses.add('sc.ClassSecID = ?');
        whereArgs.add(filters.classSecId);
      }

      return db.rawQuery('''
    SELECT sc.Stu_RegID, sc.ClassRollNo, sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name
    FROM Student_Class sc
    JOIN Stu_Reg sr ON sc.Stu_RegID = sr.Stu_RegID
    WHERE ${whereClauses.join(' AND ')}
    ORDER BY sc.ClassID ASC, sc.ClassRollNo ASC, sc.Stu_RegID ASC
  ''', whereArgs);
    });

/// Provider that calculates in-memory preview rows for the cohort.
final voucherGenPreviewProvider = FutureProvider<List<VoucherPreviewRow>>((
  ref,
) async {
  final filters = ref.watch(voucherGenFiltersProvider);
  final db = await DatabaseService.instance.database;

  // 1. Candidate selection: Present=1, SessionYr=?, VGen='Y'
  final whereClauses = <String>[
    'sc.Present = 1',
    'sc.SessionYr = ?',
    "sc.VGen = 'Y'",
  ];
  final whereArgs = <dynamic>[filters.sessionYr];

  if (filters.classId != null) {
    whereClauses.add('sc.ClassID = ?');
    whereArgs.add(filters.classId);
  }

  if (filters.classSecId != null) {
    whereClauses.add('sc.ClassSecID = ?');
    whereArgs.add(filters.classSecId);
  }

  if (filters.mode == 'single') {
    if (filters.selectedStuRegId == null) {
      return const <VoucherPreviewRow>[];
    }
    whereClauses.add('sc.Stu_RegID = ?');
    whereArgs.add(filters.selectedStuRegId);
  }

  final candidates = await db.rawQuery('''
    SELECT sc.Stu_RegID, sr.NameFirst, sr.NameMiddle, sr.NameLast, sc.ClassID, sc.ClassSecID,
           sr.FullDiscount,
           COALESCE(NULLIF(sr.VMDiscount, 0), sr.Discount, 0) AS StudentDiscount
    FROM Student_Class sc
    JOIN Stu_Reg sr ON sc.Stu_RegID = sr.Stu_RegID
    WHERE ${whereClauses.join(' AND ')}
    ORDER BY sc.Stu_RegID ASC
  ''', whereArgs);

  if (candidates.isEmpty) return [];

  final yyMm = billingMonthToYyMm(filters.billingMonth);
  final previewRows = <VoucherPreviewRow>[];

  // Cache tariffs by classId for performance
  final tariffCache = <int, List<Map<String, dynamic>>>{};

  for (final student in candidates) {
    final stuRegId = student['Stu_RegID'] as int;
    final classId = student['ClassID'] as int;
    final fullDiscount = (student['FullDiscount'] as int? ?? 0) == 1;
    final studentConcession =
        ((student['StudentDiscount'] as num?)?.toDouble() ?? 0.0).round();

    final studentName = formatStudentFullName(
      student['NameFirst'] as String?,
      student['NameMiddle'] as String?,
      student['NameLast'] as String?,
    );

    final voucherId = '$yyMm-$stuRegId';

    // 2. Load tariffs for class
    List<Map<String, dynamic>> tariffs;
    if (tariffCache.containsKey(classId)) {
      tariffs = tariffCache[classId]!;
    } else {
      tariffs = await db.rawQuery(
        '''
        SELECT FeeParamID, Fee FROM Cls_Param_Fee
        WHERE ClassID = ? AND FeeYr = ?
      ''',
        [classId, filters.sessionYr],
      );
      tariffCache[classId] = tariffs;
    }

    final activeTariffs = tariffs
        .where(
          (t) => !filters.excludedFeeParamIds.contains(t['FeeParamID'] as int),
        )
        .toList();

    final subtotal = activeTariffs.fold<int>(
      0,
      (sum, t) => sum + ((t['Fee'] as num?)?.toInt() ?? 0),
    );

    // 3. Compute arrears if includeArrears is true
    int arrears = 0;
    if (filters.includeArrears) {
      final billingMonthPrefix = _yyMmPrefix(filters.billingMonth);
      final overdueRows = await db.rawQuery(
        '''
        SELECT vm.VoucherMasID, vm.SubTotal, vm.Discount,
               (SELECT COALESCE(SUM(PaidAmount), 0) FROM FeeTransaction WHERE VoucharNo = vm.VoucherMasID) AS PaidAmt
        FROM VoucharMas vm
        WHERE vm.Student_Class_StuRegID = ?
          AND vm.IsPaid IN ('N', 'O')
          AND SUBSTR(vm.VoucherMasID, 1, 4) < ?
      ''',
        [stuRegId, billingMonthPrefix],
      );

      for (final ov in overdueRows) {
        final sub = (ov['SubTotal'] as num?)?.toInt() ?? 0;
        final disc = (ov['Discount'] as num?)?.toInt() ?? 0;
        final paid = (ov['PaidAmt'] as num?)?.toInt() ?? 0;
        final balance = sub - disc - paid;
        if (balance > 0) {
          arrears += balance;
        }
      }
    }

    // 4. Discount Rule: Full Waiver or Student Concession (Stu_Reg.Discount)
    int discount = 0;
    VoucherPreviewStatus status;

    if (fullDiscount) {
      final tuitionTariff = activeTariffs.firstWhere(
        (t) => (t['FeeParamID'] as int) == 2,
        orElse: () => {'Fee': 0},
      );
      discount = (tuitionTariff['Fee'] as num?)?.toInt() ?? 0;
      status = VoucherPreviewStatus.fullWaiver;
    } else if (studentConcession > 0) {
      discount = studentConcession.clamp(0, subtotal);
      status = arrears > 0
          ? VoucherPreviewStatus.arrearsRollover
          : VoucherPreviewStatus.ready;
    } else {
      discount = 0;
      status = arrears > 0
          ? VoucherPreviewStatus.arrearsRollover
          : VoucherPreviewStatus.ready;
    }

    final netPayable = subtotal + arrears - discount;

    // 5. Duplicate Check & Persisted Values
    final existing = await db.rawQuery(
      'SELECT VoucherMasID, SubTotal, Discount FROM VoucharMas WHERE VoucherMasID = ? LIMIT 1',
      [voucherId],
    );

    int rowSubtotal = subtotal;
    int rowDiscount = discount;
    int rowNetPayable = netPayable;
    String? skipReason;

    if (existing.isNotEmpty) {
      status = VoucherPreviewStatus.alreadyGenerated;
      skipReason = 'Already generated';
      final persistedSubTotal =
          (existing.first['SubTotal'] as num?)?.toInt() ?? subtotal;
      final persistedDiscount =
          (existing.first['Discount'] as num?)?.toInt() ?? discount;
      rowSubtotal = persistedSubTotal;
      rowDiscount = persistedDiscount;
      rowNetPayable = persistedSubTotal - persistedDiscount;
    }

    previewRows.add(
      VoucherPreviewRow(
        stuRegId: stuRegId,
        studentName: studentName,
        subtotal: rowSubtotal,
        arrears: arrears,
        discount: rowDiscount,
        netPayable: rowNetPayable,
        status: status,
        skipReason: skipReason,
        voucherId: voucherId,
      ),
    );
  }

  return previewRows;
});

/// Batch execution state.
class VoucherGenState {
  final bool isGenerating;
  final int generatedCount;
  final int skippedCount;
  final int totalToGenerate;
  final String? currentProgressText;
  final String? error;
  final BatchGenerationSummary? completionSummary;

  const VoucherGenState({
    this.isGenerating = false,
    this.generatedCount = 0,
    this.skippedCount = 0,
    this.totalToGenerate = 0,
    this.currentProgressText,
    this.error,
    this.completionSummary,
  });

  VoucherGenState copyWith({
    bool? isGenerating,
    int? generatedCount,
    int? skippedCount,
    int? totalToGenerate,
    String? currentProgressText,
    String? error,
    bool clearError = false,
    BatchGenerationSummary? completionSummary,
    bool clearSummary = false,
  }) {
    return VoucherGenState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatedCount: generatedCount ?? this.generatedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      totalToGenerate: totalToGenerate ?? this.totalToGenerate,
      currentProgressText: currentProgressText ?? this.currentProgressText,
      error: clearError ? null : (error ?? this.error),
      completionSummary: clearSummary
          ? null
          : (completionSummary ?? this.completionSummary),
    );
  }
}

/// Notifier executing batch generation and batch maintenance routines.
class VoucherGenExecutionNotifier extends StateNotifier<VoucherGenState> {
  final Ref ref;
  bool _cancelRequested = false;

  VoucherGenExecutionNotifier(this.ref) : super(const VoucherGenState());

  void clearSummary() {
    state = state.copyWith(clearSummary: true, clearError: true);
  }

  /// Signals cooperative cancellation of an in-progress batch generation.
  void cancelGeneration() {
    _cancelRequested = true;
  }

  /// Executes batch cohort voucher generation.
  ///
  /// G-10 Shot 11a-1: the pipeline is wrapped in try/catch/finally so that
  /// `isGenerating` is guaranteed to reset. Previously, any exception raised
  /// inside the per-row sqflite transaction (Android-specific failures that
  /// do not occur on desktop FFI, where the lock model differs) escaped this
  /// method and left the UI spinning on "Generating..." forever.
  Future<BatchGenerationSummary?> generateVouchers({
    bool overwriteExisting = false,
  }) async {
    final previewRows = ref.read(voucherGenPreviewProvider).valueOrNull;
    if (previewRows == null || previewRows.isEmpty) {
      state = state.copyWith(error: 'No eligible students for this cohort');
      return null;
    }

    try {
      return await _generateVouchersBatch(
        overwriteExisting: overwriteExisting,
      );
    } catch (e, st) {
      debugPrint('generateVouchers error: $e\n$st');
      state = state.copyWith(error: 'Voucher generation failed: $e');
      return null;
    } finally {
      // Guarantee the "Generating..." state exits even on failure.
      if (state.isGenerating) {
        state = state.copyWith(isGenerating: false);
      }
    }
  }

  /// Generation pipeline proper. Every SQL call inside the per-row
  /// `db.transaction` block MUST go through `txn` — using the outer `db`
  /// handle while a transaction is open deadlocks sqflite on Android
  /// (the operation queues behind the transaction that is waiting on it).
  Future<BatchGenerationSummary?> _generateVouchersBatch({
    bool overwriteExisting = false,
  }) async {
    final filters = ref.read(voucherGenFiltersProvider);
    final previewRows = ref.read(voucherGenPreviewProvider).valueOrNull;
    if (previewRows == null || previewRows.isEmpty) {
      return null;
    }

    final db = await DatabaseService.instance.database;

    // Filter validation
    if (filters.classId != null) {
      final tariffs = await db.rawQuery(
        'SELECT FeeParamID FROM Cls_Param_Fee WHERE ClassID = ? AND FeeYr = ?',
        [filters.classId, filters.sessionYr],
      );
      if (tariffs.isEmpty) {
        state = state.copyWith(
          error: 'No Fee defined for Class ID Code ${filters.classId}',
        );
        return null;
      }
    }

    final totalCount = previewRows.length;
    state = state.copyWith(
      isGenerating: true,
      generatedCount: 0,
      skippedCount: 0,
      totalToGenerate: totalCount,
      clearError: true,
      clearSummary: true,
    );

    int generated = 0;
    int skipped = 0;
    int totalBilled = 0;
    int arrearsRolled = 0;
    int concessions = 0;
    final skippedReasons = <String>[];
    _cancelRequested = false;

    final vDateStr = DateFormat('yyyy-MM-dd').format(filters.issueDate);
    final dueDateStr = DateFormat('yyyy-MM-dd').format(filters.dueDate);

    for (int i = 0; i < previewRows.length; i++) {
      if (_cancelRequested) {
        _cancelRequested = false;
        skippedReasons.add(
          'Batch cancelled by user after $generated vouchers.',
        );
        break;
      }
      final row = previewRows[i];

      state = state.copyWith(
        currentProgressText:
            'Generating voucher ${i + 1} of $totalCount (${row.studentName})...',
      );

      // Check if already generated. With [overwriteExisting] the row is
      // regenerated as long as the existing voucher is still UNPAID — paid
      // vouchers are never touched.
      String? existingPaidFlag;
      if (row.status == VoucherPreviewStatus.alreadyGenerated &&
          !overwriteExisting) {
        skipped++;
        skippedReasons.add(
          'Duplicate voucher record skipped: ${row.studentName} (${row.voucherId}).',
        );
        state = state.copyWith(skippedCount: skipped);
        continue;
      }

      // Double check in DB to avoid race conditions
      final existing = await db.rawQuery(
        'SELECT VoucherMasID, IsPaid FROM VoucharMas WHERE VoucherMasID = ? LIMIT 1',
        [row.voucherId],
      );
      if (existing.isNotEmpty) {
        existingPaidFlag = (existing.first['IsPaid'] as String?) ?? 'N';
        if (!overwriteExisting || existingPaidFlag == 'Y') {
          skipped++;
          skippedReasons.add(
            'Duplicate voucher record skipped: ${row.studentName} (${row.voucherId}).',
          );
          state = state.copyWith(skippedCount: skipped);
          continue;
        }
      }

      // Query student ClassID
      final classRows = await db.rawQuery(
        'SELECT ClassID FROM Student_Class WHERE Stu_RegID = ? AND SessionYr = ? LIMIT 1',
        [row.stuRegId, filters.sessionYr],
      );
      final studentClassId = classRows.isNotEmpty
          ? (classRows.first['ClassID'] as int)
          : (filters.classId ?? 13);

      // Load tariffs for this student's class
      final tariffs = await db.rawQuery(
        'SELECT FeeParamID, Fee FROM Cls_Param_Fee WHERE ClassID = ? AND FeeYr = ?',
        [studentClassId, filters.sessionYr],
      );

      final activeTariffs = tariffs
          .where(
            (t) =>
                !filters.excludedFeeParamIds.contains(t['FeeParamID'] as int),
          )
          .toList();

      final isFullWaiver = (row.status == VoucherPreviewStatus.fullWaiver);

      await db.transaction((txn) async {
        try {
          final billingMonthPrefix = _yyMmPrefix(filters.billingMonth);

          // 0. Overwrite mode: drop the student's existing UNPAID voucher for
          //    this month/session (master + details) before re-inserting.
          if (overwriteExisting && existingPaidFlag != null) {
            await txn.rawDelete(
              "DELETE FROM VoucharDet WHERE VoucharMasID = ?",
              [row.voucherId],
            );
            await txn.rawDelete(
              "DELETE FROM VoucharMas WHERE VoucherMasID = ? AND COALESCE(IsPaid, 'N') != 'Y'",
              [row.voucherId],
            );
          }

          // 1. Arrears rollover: mark prior unpaid as 'O' (strictly prior billing months)
          if (filters.includeArrears) {
            await txn.rawUpdate(
              "UPDATE VoucharMas SET IsPaid = 'O' "
              "WHERE Student_Class_StuRegID = ? AND IsPaid = 'N' AND SUBSTR(VoucherMasID, 1, 4) < ?",
              [row.stuRegId, billingMonthPrefix],
            );
          }

          // 2. Insert VoucharMas with placeholder SubTotal: 0
          await txn.insert('VoucharMas', {
            'VoucherMasID': row.voucherId,
            'VDate': vDateStr,
            'Student_Class_StuRegID': row.stuRegId,
            'SubTotal': 0,
            'ForMonth': normalizeBillingMonthForStorage(filters.billingMonth),
            'ClassID': studentClassId,
            'Remarks': null,
            'Discount': 0,
            'DueDate': dueDateStr,
            'IsPaid': 'N',
            'SessionYr': filters.sessionYr,
          });

          // 3. Insert VoucharDet for active class tariffs
          for (final t in activeTariffs) {
            final feeParamId = t['FeeParamID'] as int;
            final fee = (t['Fee'] as num?)?.toDouble() ?? 0.0;
            final isTuition = (feeParamId == 2);
            final detDiscount = (isFullWaiver && isTuition) ? fee : 0.0;

            final detIdRows = await txn.rawQuery(
              'SELECT COALESCE(MAX(VoucharDetID), 0) + 1 AS nextId FROM VoucharDet',
            );
            final nextDetId = (detIdRows.first['nextId'] as num).toInt();

            await txn.insert('VoucharDet', {
              'VoucharDetID': nextDetId,
              'VoucharMasID': row.voucherId,
              'feeParameterID': feeParamId,
              'Amount': fee,
              'Discount': detDiscount,
            });
          }

          // 4. If includeArrears and arrears > 0: inject FeeParamID = 4 ("Arears")
          if (filters.includeArrears && row.arrears > 0) {
            final detIdRows = await txn.rawQuery(
              'SELECT COALESCE(MAX(VoucharDetID), 0) + 1 AS nextId FROM VoucharDet',
            );
            final nextDetId = (detIdRows.first['nextId'] as num).toInt();

            await txn.insert('VoucharDet', {
              'VoucharDetID': nextDetId,
              'VoucharMasID': row.voucherId,
              'feeParameterID': 4, // Head 4: "Arears"
              'Amount': row.arrears.toDouble(),
              'Discount': 0.0,
            });
          }

          // 5. Discount adjustments (Full Waiver or Student Concession)
          if (isFullWaiver) {
            await txn.rawUpdate(
              'UPDATE VoucharDet SET Discount = Amount '
              'WHERE VoucharMasID = ? AND feeParameterID = 2',
              [row.voucherId],
            );
            await txn.rawUpdate(
              'UPDATE VoucharMas SET Discount = (SELECT COALESCE(SUM(Discount), 0) FROM VoucharDet WHERE VoucharMasID = ?) '
              'WHERE VoucherMasID = ?',
              [row.voucherId, row.voucherId],
            );
          } else if (row.discount > 0) {
            final hasTuition = activeTariffs.any(
              (t) => (t['FeeParamID'] as int) == 2,
            );
            if (hasTuition) {
              await txn.rawUpdate(
                'UPDATE VoucharDet SET Discount = ? '
                'WHERE VoucharMasID = ? AND feeParameterID = 2',
                [row.discount.toDouble(), row.voucherId],
              );
              await txn.rawUpdate(
                'UPDATE VoucharMas SET Discount = (SELECT COALESCE(SUM(Discount), 0) FROM VoucharDet WHERE VoucharMasID = ?) '
                'WHERE VoucherMasID = ?',
                [row.voucherId, row.voucherId],
              );
            } else {
              await txn.rawUpdate(
                'UPDATE VoucharMas SET Discount = ? WHERE VoucherMasID = ?',
                [row.discount, row.voucherId],
              );
            }
          }

          // 6. Final reconcile UPDATE (single source of truth):
          await txn.rawUpdate(
            'UPDATE VoucharMas SET SubTotal = (SELECT COALESCE(SUM(Amount), 0) FROM VoucharDet WHERE VoucharMasID = ?) '
            'WHERE VoucherMasID = ?',
            [row.voucherId, row.voucherId],
          );
        } catch (e) {
          // ignore: avoid_print
          print(
            'Voucher generation transaction failed for ${row.voucherId}: $e',
          );
          rethrow;
        }
      });

      generated++;
      totalBilled += row.netPayable;
      arrearsRolled += row.arrears;
      concessions += row.discount;

      state = state.copyWith(generatedCount: generated);

      // Yield briefly to ensure smooth UI updates
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    final summary = BatchGenerationSummary(
      generatedCount: generated,
      skippedCount: skipped,
      totalBilled: totalBilled,
      arrearsRolledOver: arrearsRolled,
      concessionsApplied: concessions,
      skippedReasons: skippedReasons,
    );

    state = state.copyWith(
      isGenerating: false,
      currentProgressText: null,
      completionSummary: summary,
    );

    // Invalidate preview provider so that table updates
    ref.invalidate(voucherGenPreviewProvider);

    return summary;
  }

  /// Delete every voucher (master + details) for the given students in one
  /// billing month/session. Runs in one transaction, bumps
  /// [dbDataVersionProvider] and invalidates the preview providers.
  Future<int> deleteVouchersByStudentIds({
    required Set<int> stuRegIds,
    required String forMonth,
    required String sessionYr,
  }) async {
    if (stuRegIds.isEmpty) return 0;
    final db = await DatabaseService.instance.database;
    final month = normalizeBillingMonthForStorage(forMonth);
    final ids = stuRegIds.toList();
    final idPlaceholders = List.filled(ids.length, '?').join(',');
    int deleted = 0;
    await db.transaction((txn) async {
      final masRows = await txn.rawQuery(
        'SELECT VoucherMasID FROM VoucharMas '
        'WHERE Student_Class_StuRegID IN ($idPlaceholders) '
        'AND ForMonth = ? AND SessionYr = ?',
        [...ids, month, sessionYr],
      );
      final voucherIds = masRows
          .map((r) => r['VoucherMasID'] as String)
          .toList(growable: false);
      if (voucherIds.isEmpty) return;
      deleted = await _deleteVoucherRows(txn, voucherIds);
    });
    _bumpDataVersion();
    ref.invalidate(voucherGenPreviewProvider);
    return deleted;
  }

  /// Delete vouchers (master + details) by their VoucharMasIDs. Runs in one
  /// transaction, bumps [dbDataVersionProvider] and invalidates the preview.
  Future<int> deleteVouchersByIds(Set<String> voucherMasIds) async {
    if (voucherMasIds.isEmpty) return 0;
    final db = await DatabaseService.instance.database;
    final ids = voucherMasIds.toList(growable: false);
    int deleted = 0;
    await db.transaction((txn) async {
      deleted = await _deleteVoucherRows(txn, ids);
    });
    _bumpDataVersion();
    ref.invalidate(voucherGenPreviewProvider);
    return deleted;
  }

  /// Shared delete helper: removes VoucharDet + VoucharMas rows for the given
  /// master IDs inside an open transaction. Returns the master row count.
  Future<int> _deleteVoucherRows(
    dynamic txn,
    List<String> voucherIds,
  ) async {
    final placeholders = List.filled(voucherIds.length, '?').join(',');
    await txn.rawDelete(
      'DELETE FROM VoucharDet WHERE VoucharMasID IN ($placeholders)',
      voucherIds,
    );
    return txn.rawDelete(
      'DELETE FROM VoucharMas WHERE VoucherMasID IN ($placeholders)',
      voucherIds,
    );
  }

  /// Apply late fine to cohort vouchers (cmdSetFine VA 0x005f2400).
  Future<int> applyLateFineToCohort({
    required String billingMonth,
    required int feeParamId,
    required int fineAmount,
  }) async {
    final db = await DatabaseService.instance.database;
    // Find unpaid vouchers for the billing month
    final vouchers = await db.rawQuery(
      "SELECT VoucherMasID FROM VoucharMas WHERE ForMonth = ? AND IsPaid = 'N'",
      [billingMonth],
    );
    if (vouchers.isEmpty) return 0;

    int count = 0;
    await db.transaction((txn) async {
      for (final v in vouchers) {
        final id = v['VoucherMasID'] as String;
        // Delete existing late-fine line item, then insert new one
        await txn.rawDelete(
          'DELETE FROM VoucharDet WHERE VoucharMasID = ? AND feeParameterID = ?',
          [id, feeParamId],
        );
        final maxDetRows = await txn.rawQuery(
          'SELECT COALESCE(MAX(VoucharDetID), 0) + 1 AS nextId FROM VoucharDet',
        );
        final nextDetId = ((maxDetRows.first['nextId'] as num?)?.toInt()) ?? 1;
        await txn.insert('VoucharDet', {
          'VoucharDetID': nextDetId,
          'VoucharMasID': id,
          'feeParameterID': feeParamId,
          'Amount': fineAmount,
          'Discount': 0,
        });
        // Recompute SubTotal from detail rows
        await txn.rawUpdate(
          'UPDATE VoucharMas SET SubTotal = (SELECT SUM(Amount) FROM VoucharDet WHERE VoucharMasID = ?) WHERE VoucherMasID = ?',
          [id, id],
        );
        count++;
      }
    });
    return count;
  }

  /// Sync due date for cohort vouchers (cmdSetDueDteForAll VA 0x005eec00).
  Future<int> syncDueDateForCohort({
    required String billingMonth,
    required DateTime newDueDate,
  }) async {
    final db = await DatabaseService.instance.database;
    final formatted = DateFormat('yyyy-MM-dd').format(newDueDate);
    final count = await db.rawUpdate(
      "UPDATE VoucharMas SET DueDate = ? WHERE ForMonth = ? AND IsPaid = 'N'",
      [formatted, billingMonth],
    );
    return count;
  }

  /// Batch update due dates for the month (Section S17 VA 0x005eec00).
  Future<int> batchUpdateDueDate(DateTime newDueDate) async {
    final filters = ref.read(voucherGenFiltersProvider);
    return syncDueDateForCohort(
      billingMonth: filters.billingMonth,
      newDueDate: newDueDate,
    );
  }

  /// Batch late fee injection (Section S17 VA 0x005f2400).
  Future<int> batchApplyLateFine(int fineAmount) async {
    final filters = ref.read(voucherGenFiltersProvider);
    return applyLateFineToCohort(
      billingMonth: filters.billingMonth,
      feeParamId: 8,
      fineAmount: fineAmount,
    );
  }

  /// Regenerate unpaid cohort vouchers.
  Future<BatchGenerationSummary?> regenerateUnpaidCohortVouchers() async {
    final filters = ref.read(voucherGenFiltersProvider);
    if (filters.classId == null) {
      state = state.copyWith(error: 'No eligible students for this cohort');
      return null;
    }

    final db = await DatabaseService.instance.database;
    final sectionFilter = filters.classSecId;
    final billingMonthPrefix = _yyMmPrefix(filters.billingMonth);
    final isSingle =
        filters.mode == 'single' && filters.selectedStuRegId != null;
    final singleStudentFilter = isSingle ? filters.selectedStuRegId : null;

    // 1. Block if any paid voucher exists in cohort
    final paidCheck = await db.rawQuery(
      '''
      SELECT COUNT(*) AS paidCount
      FROM VoucharMas vm
      WHERE vm.ClassID = ?
        AND vm.ForMonth = ?
        AND vm.SessionYr = ?
        AND vm.IsPaid = 'Y'
        AND (? IS NULL OR vm.Student_Class_StuRegID = ?)
        AND (? IS NULL OR vm.Student_Class_StuRegID IN (
          SELECT Stu_RegID FROM Student_Class
          WHERE ClassID = ? AND ClassSecID = ? AND SessionYr = ?
        ))
      ''',
      [
        filters.classId,
        filters.billingMonth,
        filters.sessionYr,
        singleStudentFilter,
        singleStudentFilter,
        sectionFilter,
        filters.classId,
        sectionFilter ?? 0,
        filters.sessionYr,
      ],
    );
    final paidCount = (paidCheck.first['paidCount'] as num?)?.toInt() ?? 0;
    if (paidCount > 0) {
      state = state.copyWith(
        error:
            'Cannot regenerate: $paidCount paid voucher(s) exist in this cohort. Revoke payments first.',
      );
      return null;
    }

    // 2. Delete unpaid vouchers, revert orphaned 'O' rollovers, all in one transaction
    await db.transaction((txn) async {
      // Revert orphaned prior-month 'O' vouchers back to 'N' for students in this cohort
      await txn.rawUpdate(
        '''
        UPDATE VoucharMas
        SET IsPaid = 'N'
        WHERE IsPaid = 'O'
          AND SUBSTR(VoucherMasID, 1, 4) < ?
          AND (? IS NULL OR Student_Class_StuRegID = ?)
          AND Student_Class_StuRegID IN (
            SELECT Student_Class_StuRegID FROM VoucharMas
            WHERE ClassID = ? AND ForMonth = ? AND SessionYr = ?
              AND IsPaid IN ('N', 'O')
              AND (? IS NULL OR Student_Class_StuRegID = ?)
              AND (? IS NULL OR Student_Class_StuRegID IN (
                SELECT Stu_RegID FROM Student_Class
                WHERE ClassID = ? AND ClassSecID = ? AND SessionYr = ?
              ))
          )
        ''',
        [
          billingMonthPrefix,
          singleStudentFilter,
          singleStudentFilter,
          filters.classId,
          filters.billingMonth,
          filters.sessionYr,
          singleStudentFilter,
          singleStudentFilter,
          sectionFilter,
          filters.classId,
          sectionFilter ?? 0,
          filters.sessionYr,
        ],
      );

      // Delete VoucharDet first (FK-safe)
      await txn.rawDelete(
        '''
        DELETE FROM VoucharDet
        WHERE VoucharMasID IN (
          SELECT VoucherMasID FROM VoucharMas
          WHERE ClassID = ? AND ForMonth = ? AND SessionYr = ?
            AND IsPaid IN ('N', 'O')
            AND (? IS NULL OR Student_Class_StuRegID = ?)
            AND (? IS NULL OR Student_Class_StuRegID IN (
              SELECT Stu_RegID FROM Student_Class
              WHERE ClassID = ? AND ClassSecID = ? AND SessionYr = ?
            ))
        )
        ''',
        [
          filters.classId,
          filters.billingMonth,
          filters.sessionYr,
          singleStudentFilter,
          singleStudentFilter,
          sectionFilter,
          filters.classId,
          sectionFilter ?? 0,
          filters.sessionYr,
        ],
      );

      // Delete VoucharMas
      await txn.rawDelete(
        '''
        DELETE FROM VoucharMas
        WHERE ClassID = ? AND ForMonth = ? AND SessionYr = ?
          AND IsPaid IN ('N', 'O')
          AND (? IS NULL OR Student_Class_StuRegID = ?)
          AND (? IS NULL OR Student_Class_StuRegID IN (
            SELECT Stu_RegID FROM Student_Class
            WHERE ClassID = ? AND ClassSecID = ? AND SessionYr = ?
          ))
        ''',
        [
          filters.classId,
          filters.billingMonth,
          filters.sessionYr,
          singleStudentFilter,
          singleStudentFilter,
          sectionFilter,
          filters.classId,
          sectionFilter ?? 0,
          filters.sessionYr,
        ],
      );
    });

    // 3. Invalidate and deterministically await fresh preview (NO Future.delayed)
    ref.invalidate(voucherGenPreviewProvider);
    try {
      await ref.read(voucherGenPreviewProvider.future);
    } catch (_) {
      // Preview rebuild may throw if no students; treat as empty cohort
    }

    // 4. Regenerate with current config through the SAME generation method
    return generateVouchers();
  }

  /// Loads every FeeParameters ID; degrades to an empty set when the provider
  /// cannot load (e.g. widget tests without a database), so the fast actions
  /// simply keep every class tariff head active.
  Future<Set<int>> _loadAllFeeParamIds() async {
    try {
      final all = await ref.read(allFeeParametersProvider.future);
      return all.map((f) => f.feeParamId).toSet();
    } catch (_) {
      return const <int>{};
    }
  }

  /// Invalidates and awaits a fresh preview; degrades to an empty list when
  /// the preview provider cannot load.
  Future<List<VoucherPreviewRow>> _refreshPreview() async {
    ref.invalidate(voucherGenPreviewProvider);
    try {
      return await ref.read(voucherGenPreviewProvider.future);
    } catch (_) {
      return const <VoucherPreviewRow>[];
    }
  }

  /// Post-generation refresh: bumps the shared DB data version so every
  /// listening screen re-queries SQLite immediately (this also triggers the
  /// silent preview reload wired in [voucherGenExecutionProvider]).
  void _bumpDataVersion() {
    try {
      ref.read(dbDataVersionProvider.notifier).state++;
    } catch (_) {
      // Bumping the data version must never fail the flow.
    }
  }

  /// 1-click whole-school batch: iterates every class that still has eligible
  /// candidates and REUSES the existing [_generateVouchersBatch] pipeline via
  /// the preview provider (filter-mutation loop — no parallel insert path).
  /// The global fee-head checklist is applied per class as
  /// excludedFeeParamIds = allFeeParameters - selectedGlobalFeeParameters.
  Future<BatchGenerationSummary?> generateAllSchoolVouchers({
    bool overwriteExisting = true,
  }) async {
    if (state.isGenerating) return null;
    final filters = ref.read(voucherGenFiltersProvider);
    final selectedGlobal = ref.read(globalSelectedFeeParamIdsProvider);
    final originalFilters = filters;
    final filtersNotifier = ref.read(voucherGenFiltersProvider.notifier);

    try {
      final allFeeIds = await _loadAllFeeParamIds();
      final exclusions = allFeeIds.difference(selectedGlobal);
      final classIds = await listSchoolVoucherCandidateClasses(
        sessionYr: filters.sessionYr,
        billingMonth: filters.billingMonth,
      );
      if (classIds.isEmpty) {
        state = state.copyWith(
          error: 'No eligible students for whole-school generation',
        );
        return null;
      }

      state = state.copyWith(
        isGenerating: true,
        generatedCount: 0,
        skippedCount: 0,
        totalToGenerate: 0,
        clearError: true,
        clearSummary: true,
      );

      int generated = 0;
      int skipped = 0;
      int billed = 0;
      int arrears = 0;
      int concessions = 0;
      final reasons = <String>[];

      for (final classId in classIds) {
        if (_cancelRequested) {
          _cancelRequested = false;
          reasons.add('Batch cancelled by user.');
          break;
        }

        filtersNotifier.state = originalFilters.copyWith(
          classId: classId,
          clearClassSecId: true,
          excludedFeeParamIds: exclusions,
          mode: 'batch',
          clearSelectedStudent: true,
        );

        final rows = await _refreshPreview();
        final hasGeneratable = overwriteExisting
            ? rows.isNotEmpty
            : rows.any(
                (r) => r.status != VoucherPreviewStatus.alreadyGenerated,
              );
        if (!hasGeneratable) continue;

        final classSummary = await generateVouchers(
          overwriteExisting: overwriteExisting,
        );
        if (classSummary != null) {
          generated += classSummary.generatedCount;
          skipped += classSummary.skippedCount;
          billed += classSummary.totalBilled;
          arrears += classSummary.arrearsRolledOver;
          concessions += classSummary.concessionsApplied;
          reasons.addAll(classSummary.skippedReasons);
          state = state.copyWith(
            generatedCount: generated,
            skippedCount: skipped,
            totalToGenerate: generated + skipped,
          );
        }
      }

      final summary = BatchGenerationSummary(
        generatedCount: generated,
        skippedCount: skipped,
        totalBilled: billed,
        arrearsRolledOver: arrears,
        concessionsApplied: concessions,
        skippedReasons: reasons,
      );

      state = state.copyWith(isGenerating: false, completionSummary: summary);
      _bumpDataVersion();
      return summary;
    } catch (e, st) {
      debugPrint('generateAllSchoolVouchers error: $e\n$st');
      state = state.copyWith(error: 'Whole-school generation failed: $e');
      return null;
    } finally {
      filtersNotifier.state = originalFilters;
      ref.invalidate(voucherGenPreviewProvider);
      if (state.isGenerating) {
        state = state.copyWith(isGenerating: false);
      }
    }
  }

  /// Generates vouchers for the 1..N students checked in the Generate Single
  /// Voucher modal, reusing the existing single-mode pipeline via the preview
  /// provider (filter-mutation loop — no parallel insert path). Applies the
  /// global fee-head checklist the same way as [generateAllSchoolVouchers].
  Future<BatchGenerationSummary?> generateForSelectedStudents(
    Set<int> stuRegIds, {
    bool overwriteExisting = true,
  }) async {
    if (stuRegIds.isEmpty) return null;
    if (state.isGenerating) return null;
    final filters = ref.read(voucherGenFiltersProvider);
    final selectedGlobal = ref.read(globalSelectedFeeParamIdsProvider);
    final originalFilters = filters;
    final filtersNotifier = ref.read(voucherGenFiltersProvider.notifier);
    final db = await DatabaseService.instance.database;

    try {
      final allFeeIds = await _loadAllFeeParamIds();
      final exclusions = allFeeIds.difference(selectedGlobal);

      state = state.copyWith(
        isGenerating: true,
        generatedCount: 0,
        skippedCount: 0,
        totalToGenerate: stuRegIds.length,
        clearError: true,
        clearSummary: true,
      );

      int generated = 0;
      int skipped = 0;
      int billed = 0;
      int arrears = 0;
      int concessions = 0;
      final reasons = <String>[];

      for (final regId in stuRegIds) {
        if (_cancelRequested) {
          _cancelRequested = false;
          reasons.add('Batch cancelled by user.');
          break;
        }

        // Resolve the student's class so tariff validation and preview
        // filtering match the actual cohort row.
        final classRows = await db.rawQuery(
          'SELECT ClassID FROM Student_Class WHERE Stu_RegID = ? AND SessionYr = ? LIMIT 1',
          [regId, filters.sessionYr],
        );
        if (classRows.isEmpty) {
          skipped++;
          reasons.add('No active enrollment found for Reg ID $regId.');
          state = state.copyWith(skippedCount: skipped);
          continue;
        }
        final classId = classRows.first['ClassID'] as int;

        filtersNotifier.state = originalFilters.copyWith(
          classId: classId,
          clearClassSecId: true,
          excludedFeeParamIds: exclusions,
          mode: 'single',
          selectedStuRegId: regId,
        );

        final rows = await _refreshPreview();
        final hasGeneratable = overwriteExisting
            ? rows.isNotEmpty
            : rows.any(
                (r) => r.status != VoucherPreviewStatus.alreadyGenerated,
              );
        if (!hasGeneratable) {
          skipped++;
          reasons.add('No active cohort found for Reg ID $regId.');
          state = state.copyWith(skippedCount: skipped);
          continue;
        }

        final studentSummary = await generateVouchers(
          overwriteExisting: overwriteExisting,
        );
        if (studentSummary != null) {
          generated += studentSummary.generatedCount;
          skipped += studentSummary.skippedCount;
          billed += studentSummary.totalBilled;
          arrears += studentSummary.arrearsRolledOver;
          concessions += studentSummary.concessionsApplied;
          reasons.addAll(studentSummary.skippedReasons);
          state = state.copyWith(
            generatedCount: generated,
            skippedCount: skipped,
            totalToGenerate: generated + skipped,
          );
        }
      }

      final summary = BatchGenerationSummary(
        generatedCount: generated,
        skippedCount: skipped,
        totalBilled: billed,
        arrearsRolledOver: arrears,
        concessionsApplied: concessions,
        skippedReasons: reasons,
      );

      state = state.copyWith(isGenerating: false, completionSummary: summary);
      _bumpDataVersion();
      return summary;
    } catch (e, st) {
      debugPrint('generateForSelectedStudents error: $e\n$st');
      state = state.copyWith(error: 'Voucher generation failed: $e');
      return null;
    } finally {
      filtersNotifier.state = originalFilters;
      ref.invalidate(voucherGenPreviewProvider);
      if (state.isGenerating) {
        state = state.copyWith(isGenerating: false);
      }
    }
  }

  /// G-10 Shot 12b: silent, non-destructive preview refresh, triggered from
  /// the provider factory on [dbDataVersionProvider] changes (a cloud pull
  /// completed). Invalidates the preview-side FutureProviders so they re-query
  /// SQLite: a watched FutureProvider keeps showing its previous data while
  /// rebuilding, so there is no spinner flicker. The filter state
  /// ([voucherGenFiltersProvider]) is untouched, so the preview rebuilds with
  /// exactly the currently selected cohort filters.
  Future<void> reloadPreviewPreservingFilters() async {
    if (state.isGenerating) return;
    try {
      ref.invalidate(voucherGenPreviewProvider);
      ref.invalidate(voucherCohortStudentsProvider);
      ref.invalidate(voucherClassTariffsProvider);
      ref.invalidate(voucherBankListProvider);
    } catch (_) {
      // Silent reload must never surface an error into the UI.
    }
  }
}

final voucherGenExecutionProvider =
    StateNotifierProvider<VoucherGenExecutionNotifier, VoucherGenState>((ref) {
      final notifier = VoucherGenExecutionNotifier(ref);
      // G-10 Shot 12b: silent non-destructive preview reload after every
      // cloud pull (dbDataVersionProvider is bumped in onPullComplete).
      ref.listen<int>(dbDataVersionProvider, (prev, next) {
        if (prev != next) notifier.reloadPreviewPreservingFilters();
      });
      return notifier;
    });

// ---------------------------------------------------------------------------
// H-Shot 3: VB6-style fast actions — global fee-head checklist, 1-click
// whole-school batch, and the Single / Selected Student voucher modal.
// ---------------------------------------------------------------------------

/// A school-wide fee head row from the FeeParameters table, shown in the
/// always-visible checklist (`ID | Fee | Check`).
class FeeParamOption {
  final int feeParamId;
  final String description;

  const FeeParamOption({required this.feeParamId, required this.description});
}

/// Fee heads that are actually CONFIGURED for billing in the CURRENT
/// SESSION: only FeeParameters rows that have a `Cls_Param_Fee` row with
/// `Fee > 0` and `FeeYr = <selected session>` (across all classes — the
/// per-class intersection happens in [voucherFeeStructureProvider]).
/// Powers the unified fee-head checklist, the whole-school/single-voucher
/// exclusion math, and the single-voucher dialog's checked-heads summary.
/// Watches [dbDataVersionProvider] so edits made in Fee Structure & Bank
/// Setup reflect here immediately.
final allFeeParametersProvider =
    FutureProvider<List<FeeParamOption>>((ref) async {
      ref.watch(dbDataVersionProvider);
      final sessionYr = ref.watch(
        voucherGenFiltersProvider.select((f) => f.sessionYr),
      );
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
      SELECT DISTINCT fp.FeeParamID, COALESCE(fp.ParamDesciption, '') AS ParamDesciption
      FROM FeeParameters fp
      WHERE EXISTS (
        SELECT 1 FROM Cls_Param_Fee cpf
        WHERE cpf.FeeParamID = fp.FeeParamID AND cpf.Fee > 0 AND cpf.FeeYr = ?
      )
      ORDER BY fp.FeeParamID ASC
    ''',
        [sessionYr],
      );
      return rows
          .map(
            (r) => FeeParamOption(
              feeParamId: r['FeeParamID'] as int,
              description: (r['ParamDesciption'] as String? ?? '').trim(),
            ),
          )
          .toList();
    });

/// Global (school-wide) fee-head selection used by the whole-school batch and
/// the single/multi-student modal. Defaults to Tuition Fee (head 2), matching
/// the VB6 reference. Kept separate from
/// [VoucherGenFilters.excludedFeeParamIds] so the existing per-class
/// batch/single flow is untouched.
class GlobalFeeParamSelectionNotifier extends StateNotifier<Set<int>> {
  GlobalFeeParamSelectionNotifier() : super(const <int>{2});

  void toggle(int feeParamId) {
    final next = Set<int>.from(state);
    if (next.contains(feeParamId)) {
      next.remove(feeParamId);
    } else {
      next.add(feeParamId);
    }
    state = next;
  }

  /// Replaces the whole selection (used by the unified fee structure table's
  /// toggle so the global whole-school / single-voucher selection mirrors the
  /// visible check state exactly).
  void replaceAll(Set<int> ids) {
    state = Set<int>.from(ids);
  }
}

final globalSelectedFeeParamIdsProvider =
    StateNotifierProvider<GlobalFeeParamSelectionNotifier, Set<int>>((ref) {
      return GlobalFeeParamSelectionNotifier();
    });

/// Distinct fee-parameter IDs that have a configured `Cls_Param_Fee` row with
/// `Fee > 0` for ANY class in the current session. Watches
/// [dbDataVersionProvider] so fee-setup edits reflect immediately.
final configuredFeeParamIdsProvider = FutureProvider<Set<int>>((ref) async {
  final options = await ref.watch(allFeeParametersProvider.future);
  return {for (final o in options) o.feeParamId};
});

/// One row of the unified VB6 fee structure table: every FeeParameters row
/// joined with the selected class's live `Cls_Param_Fee` tariff ([classTariff]
/// is null when the class has no tariff row for that head).
class Vb6FeeStructureRow {
  final int feeParamId;
  final String description;
  final double? classTariff;

  const Vb6FeeStructureRow({
    required this.feeParamId,
    required this.description,
    this.classTariff,
  });
}

/// The configured fee-head rows for the unified `ID | Fee Head | Class
/// Tariff | Check` table — ONLY heads that have a `Cls_Param_Fee` row with
/// `Fee > 0` (for the selected class/session, or across all classes when no
/// class is selected), so unconfigured FeeParameters rows never appear.
/// Reactive to the selected class ([voucherGenFiltersProvider.classId]), the
/// session year, and [dbDataVersionProvider] (fee-setup edits show up here
/// immediately).
final voucherFeeStructureProvider =
    Provider<List<Vb6FeeStructureRow>>((ref) {
      final options =
          ref.watch(allFeeParametersProvider).valueOrNull ??
          const <FeeParamOption>[];
      final filters = ref.watch(voucherGenFiltersProvider);
      final configured =
          ref.watch(configuredFeeParamIdsProvider).valueOrNull;
      if (configured == null) return const <Vb6FeeStructureRow>[];

      if (filters.classId != null) {
        final tariffs =
            ref
                .watch(voucherClassTariffsProvider(filters.classId))
                .valueOrNull ??
            const <FeeHeadSummary>[];
        final tariffById = <int, double>{
          for (final t in tariffs)
            if (t.fee > 0) t.feeParamId: t.fee,
        };
        return [
          for (final option in options)
            if (tariffById.containsKey(option.feeParamId))
              Vb6FeeStructureRow(
                feeParamId: option.feeParamId,
                description: option.description,
                classTariff: tariffById[option.feeParamId],
              ),
        ];
      }

      // No class selected: show every head configured for any class.
      return [
        for (final option in options)
          if (configured.contains(option.feeParamId))
            Vb6FeeStructureRow(
              feeParamId: option.feeParamId,
              description: option.description,
            ),
      ];
    });

/// A row in the "Generate Single Voucher" modal's checkable student table.
class SingleVoucherStudentRow {
  final int stuRegId;
  final String fullName;
  final String? fatherName;
  final int classId;
  final String? className;
  final bool hasVoucherThisMonth;

  const SingleVoucherStudentRow({
    required this.stuRegId,
    required this.fullName,
    this.fatherName,
    required this.classId,
    this.className,
    required this.hasVoucherThisMonth,
  });
}

/// Counts whole-school candidates: active, enrolled in [sessionYr], flagged
/// VGen='Y', not school-left, and without a voucher for the target month.
/// The duplicate guard uses NOT EXISTS (never NOT IN) because
/// Student_Class_StuRegID is nullable.
Future<int> countSchoolVoucherCandidates({
  required String sessionYr,
  required String billingMonth,
}) async {
  final db = await DatabaseService.instance.database;
  final forMonth = normalizeBillingMonthForStorage(billingMonth);
  final rows = await db.rawQuery('''
    SELECT COUNT(*) AS cnt
    FROM Student_Class sc
    JOIN Stu_Reg sr ON sc.Stu_RegID = sr.Stu_RegID
    WHERE sc.Present = 1
      AND sc.SessionYr = ?
      AND sc.VGen = 'Y'
      AND NOT EXISTS (SELECT 1 FROM SchLeaving sl WHERE sl.StuRegID = sc.Stu_RegID)
      AND NOT EXISTS (
        SELECT 1 FROM VoucharMas vm
        WHERE vm.Student_Class_StuRegID = sc.Stu_RegID
          AND vm.ForMonth = ? AND vm.SessionYr = ?
          AND COALESCE(vm.IsPaid, 'N') = 'Y'
      )
  ''', [sessionYr, forMonth, sessionYr]);
  return (rows.first['cnt'] as num?)?.toInt() ?? 0;
}

/// Distinct classes that still have whole-school candidates (same filters as
/// [countSchoolVoucherCandidates]). Drives the per-class reuse loop so the
/// existing [_generateVouchersBatch] pipeline can be reused verbatim.
Future<List<int>> listSchoolVoucherCandidateClasses({
  required String sessionYr,
  required String billingMonth,
}) async {
  final db = await DatabaseService.instance.database;
  final forMonth = normalizeBillingMonthForStorage(billingMonth);
  final rows = await db.rawQuery('''
    SELECT DISTINCT sc.ClassID
    FROM Student_Class sc
    JOIN Stu_Reg sr ON sc.Stu_RegID = sr.Stu_RegID
    WHERE sc.Present = 1
      AND sc.SessionYr = ?
      AND sc.VGen = 'Y'
      AND NOT EXISTS (SELECT 1 FROM SchLeaving sl WHERE sl.StuRegID = sc.Stu_RegID)
      AND NOT EXISTS (
        SELECT 1 FROM VoucharMas vm
        WHERE vm.Student_Class_StuRegID = sc.Stu_RegID
          AND vm.ForMonth = ? AND vm.SessionYr = ?
          AND COALESCE(vm.IsPaid, 'N') = 'Y'
      )
    ORDER BY sc.ClassID ASC
  ''', [sessionYr, forMonth, sessionYr]);
  return rows.map((r) => r['ClassID'] as int).toList();
}

/// Student search for the Generate Single Voucher modal: active students in
/// [sessionYr] flagged VGen='Y', not school-left, optionally filtered by
/// class, with an EXISTS flag for vouchers already generated for the target
/// month. Name filtering happens Dart-side via [formatStudentFullName] so a
/// missing NameMiddle never produces double spaces in the match string.
Future<List<SingleVoucherStudentRow>> searchStudentsForSingleVoucher({
  required String sessionYr,
  required String billingMonth,
  int? classId,
  String query = '',
}) async {
  final db = await DatabaseService.instance.database;
  final forMonth = normalizeBillingMonthForStorage(billingMonth);
  final rows = await db.rawQuery('''
    SELECT sc.Stu_RegID, sc.ClassID, c.CName AS ClassName,
           sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name,
           EXISTS (
             SELECT 1 FROM VoucharMas vm
             WHERE vm.Student_Class_StuRegID = sc.Stu_RegID
               AND vm.ForMonth = ? AND vm.SessionYr = ?
           ) AS HasVoucher
    FROM Student_Class sc
    JOIN Stu_Reg sr ON sc.Stu_RegID = sr.Stu_RegID
    LEFT JOIN Class c ON c.ClassID = sc.ClassID
    WHERE sc.Present = 1
      AND sc.SessionYr = ?
      AND sc.VGen = 'Y'
      AND NOT EXISTS (SELECT 1 FROM SchLeaving sl WHERE sl.StuRegID = sc.Stu_RegID)
      AND (? IS NULL OR sc.ClassID = ?)
    ORDER BY sc.ClassID ASC, sc.ClassRollNo ASC, sc.Stu_RegID ASC
    LIMIT 200
  ''', [forMonth, sessionYr, sessionYr, classId, classId]);

  final all = rows
      .map(
        (r) => SingleVoucherStudentRow(
          stuRegId: r['Stu_RegID'] as int,
          fullName: formatStudentFullName(
            r['NameFirst'] as String?,
            r['NameMiddle'] as String?,
            r['NameLast'] as String?,
          ),
          fatherName: (r['F_Name'] as String?)?.trim(),
          classId: r['ClassID'] as int,
          className: (r['ClassName'] as String?)?.trim(),
          hasVoucherThisMonth: (r['HasVoucher'] as int? ?? 0) == 1,
        ),
      )
      .toList();

  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where(
        (s) =>
            s.stuRegId.toString().contains(q) ||
            s.fullName.toLowerCase().contains(q) ||
            (s.fatherName?.toLowerCase().contains(q) ?? false),
      )
      .toList(growable: false);
}
