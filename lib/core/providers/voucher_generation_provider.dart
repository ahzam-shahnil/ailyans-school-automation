import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/voucher_preview_row.dart';
import '../db/database.dart';

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

  void toggleFeeHead(int feeParamId) {
    final next = Set<int>.from(state.excludedFeeParamIds);
    if (next.contains(feeParamId)) {
      next.remove(feeParamId);
    } else {
      next.add(feeParamId);
    }
    state = state.copyWith(excludedFeeParamIds: next);
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
      final newDue = DateTime(year, m, 10);
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
    state = state.copyWith(issueDate: date);
  }

  void setDueDate(DateTime date) {
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
final voucherClassTariffsProvider =
    FutureProvider.family<List<FeeHeadSummary>, int?>((ref, classId) async {
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
    SELECT sc.Stu_RegID, sr.NameFirst, sr.NameLast, sc.ClassID, sc.ClassSecID,
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

    final nameFirst = (student['NameFirst'] as String? ?? '').trim();
    final nameLast = (student['NameLast'] as String? ?? '').trim();
    final studentName = '$nameFirst $nameLast'.trim();

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

  VoucherGenExecutionNotifier(this.ref) : super(const VoucherGenState());

  void clearSummary() {
    state = state.copyWith(clearSummary: true, clearError: true);
  }

  /// Executes batch cohort voucher generation.
  Future<BatchGenerationSummary?> generateVouchers() async {
    final filters = ref.read(voucherGenFiltersProvider);
    final previewAsync = ref.read(voucherGenPreviewProvider);

    final previewRows = previewAsync.valueOrNull;
    if (previewRows == null || previewRows.isEmpty) {
      state = state.copyWith(error: 'No eligible students for this cohort');
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

    final vDateStr = DateFormat('yyyy-MM-dd').format(filters.issueDate);
    final dueDateStr = DateFormat('yyyy-MM-dd').format(filters.dueDate);

    for (int i = 0; i < previewRows.length; i++) {
      final row = previewRows[i];

      state = state.copyWith(
        currentProgressText:
            'Generating voucher ${i + 1} of $totalCount (${row.studentName})...',
      );

      // Check if already generated
      if (row.status == VoucherPreviewStatus.alreadyGenerated) {
        skipped++;
        skippedReasons.add(
          'Duplicate voucher record skipped: ${row.studentName} (${row.voucherId}).',
        );
        state = state.copyWith(skippedCount: skipped);
        continue;
      }

      // Double check in DB to avoid race conditions
      final existing = await db.rawQuery(
        'SELECT VoucherMasID FROM VoucharMas WHERE VoucherMasID = ? LIMIT 1',
        [row.voucherId],
      );
      if (existing.isNotEmpty) {
        skipped++;
        skippedReasons.add(
          'Duplicate voucher record skipped: ${row.studentName} (${row.voucherId}).',
        );
        state = state.copyWith(skippedCount: skipped);
        continue;
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
}

final voucherGenExecutionProvider =
    StateNotifierProvider<VoucherGenExecutionNotifier, VoucherGenState>((ref) {
      return VoucherGenExecutionNotifier(ref);
    });
