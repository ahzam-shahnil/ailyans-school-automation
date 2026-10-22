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

  String get displayName => '$bankName — $branch';
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

/// Helper to convert "Month YYYY" (e.g. "October 2017") to "yyMM" (e.g. "1710").
String billingMonthToYyMm(String billingMonth) {
  final parts = billingMonth.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    final monthName = parts[0].toLowerCase();
    final year = int.tryParse(parts[1]) ?? 2017;
    final yy = (year % 100).toString().padLeft(2, '0');
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
    final mm = monthMap[monthName] ?? '10';
    return '$yy$mm';
  }
  return '1710';
}

/// Filter Notifier for voucher generation.
class VoucherGenFiltersNotifier extends StateNotifier<VoucherGenFilters> {
  VoucherGenFiltersNotifier() : super(VoucherGenFilters());

  void setSessionYr(String sessionYr) {
    state = state.copyWith(sessionYr: sessionYr);
  }

  void setClassId(int? classId) {
    state = state.copyWith(
      classId: classId,
      clearClassId: classId == null,
      clearClassSecId: true,
    );
  }

  void setClassSecId(int? secId) {
    state = state.copyWith(classSecId: secId, clearClassSecId: secId == null);
  }

  void setBillingMonth(String billingMonth) {
    // Also sync issueDate and dueDate to the selected month
    final parts = billingMonth.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final monthName = parts[0].toLowerCase();
      final year = int.tryParse(parts[1]) ?? 2017;
      const monthMap = {
        'january': 1,
        'february': 2,
        'march': 3,
        'april': 4,
        'may': 5,
        'june': 6,
        'july': 7,
        'august': 8,
        'september': 9,
        'october': 10,
        'november': 11,
        'december': 12,
      };
      final m = monthMap[monthName] ?? 10;
      final newIssue = DateTime(year, m, 1);
      final newDue = DateTime(year, m, 10);
      state = state.copyWith(
        billingMonth: billingMonth,
        issueDate: newIssue,
        dueDate: newDue,
      );
      return;
    }
    state = state.copyWith(billingMonth: billingMonth);
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

  final candidates = await db.rawQuery('''
    SELECT sc.Stu_RegID, sr.NameFirst, sr.NameLast, sc.ClassID, sc.ClassSecID, sr.FullDiscount
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

    final subtotal = tariffs.fold<int>(
      0,
      (sum, t) => sum + ((t['Fee'] as num?)?.toInt() ?? 0),
    );

    // 3. Compute arrears if includeArrears is true
    int arrears = 0;
    if (filters.includeArrears) {
      final overdueRows = await db.rawQuery(
        '''
        SELECT vm.VoucherMasID, vm.SubTotal, vm.Discount,
               (SELECT COALESCE(SUM(PaidAmount), 0) FROM FeeTransaction WHERE VoucharNo = vm.VoucherMasID) AS PaidAmt
        FROM VoucharMas vm
        WHERE vm.Student_Class_StuRegID = ?
          AND vm.IsPaid IN ('N', 'O')
          AND vm.ForMonth != ?
      ''',
        [stuRegId, filters.billingMonth],
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

    // 4. Full Discount Rule (VA 0x005ec16c)
    // Tuition fee line-item (FeeParamID=2) discount = Amount
    int discount = 0;
    VoucherPreviewStatus status;

    if (fullDiscount) {
      final tuitionTariff = tariffs.firstWhere(
        (t) => (t['FeeParamID'] as int) == 2,
        orElse: () => {'Fee': 0},
      );
      discount = (tuitionTariff['Fee'] as num?)?.toInt() ?? 0;
      status = VoucherPreviewStatus.fullWaiver;
    } else {
      discount = 0;
      status = arrears > 0
          ? VoucherPreviewStatus.arrearsRollover
          : VoucherPreviewStatus.ready;
    }

    final netPayable = subtotal + arrears - discount;

    // 5. Duplicate Check
    final existing = await db.rawQuery(
      'SELECT VoucherMasID FROM VoucharMas WHERE VoucherMasID = ? LIMIT 1',
      [voucherId],
    );

    String? skipReason;
    if (existing.isNotEmpty) {
      status = VoucherPreviewStatus.alreadyGenerated;
      skipReason = 'Already generated';
    }

    previewRows.add(
      VoucherPreviewRow(
        stuRegId: stuRegId,
        studentName: studentName,
        subtotal: subtotal,
        arrears: arrears,
        discount: discount,
        netPayable: netPayable,
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

      final isFullWaiver = (row.status == VoucherPreviewStatus.fullWaiver);

      await db.transaction((txn) async {
        // 1. Arrears rollover: mark prior unpaid as 'O' (excluding current billing month)
        await txn.rawUpdate(
          "UPDATE VoucharMas SET IsPaid = 'O' "
          "WHERE Student_Class_StuRegID = ? AND IsPaid = 'N' AND ForMonth != ?",
          [row.stuRegId, filters.billingMonth],
        );

        // 2. Insert VoucharMas
        await txn.insert('VoucharMas', {
          'VoucherMasID': row.voucherId,
          'VDate': vDateStr,
          'Student_Class_StuRegID': row.stuRegId,
          'SubTotal': row.subtotal + row.arrears,
          'ForMonth': filters.billingMonth,
          'ClassID': studentClassId,
          'Remarks': null,
          'Discount': isFullWaiver ? (row.subtotal + row.arrears) : 0,
          'DueDate': dueDateStr,
          'IsPaid': 'N',
          'SessionYr': filters.sessionYr,
        });

        // 3. Insert VoucharDet for class tariffs
        for (final t in tariffs) {
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

        // 4. If arrears > 0: inject FeeParamID = 4 ("Arears")
        if (row.arrears > 0) {
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

        // 5. Full Discount rule adjustments
        if (isFullWaiver) {
          await txn.rawUpdate(
            'UPDATE VoucharDet SET Discount = Amount '
            'WHERE VoucharMasID = ? AND feeParameterID = 2',
            [row.voucherId],
          );
          await txn.rawUpdate(
            'UPDATE VoucharMas SET Discount = (SELECT SUM(Amount) FROM VoucharDet WHERE VoucharMasID = ?) '
            'WHERE VoucherMasID = ?',
            [row.voucherId, row.voucherId],
          );
        }

        // 6. UPDATE VoucharMas SET SubTotal = (SELECT SUM(Amount) FROM VoucharDet WHERE VoucherMasID=?)
        await txn.rawUpdate(
          'UPDATE VoucharMas SET SubTotal = (SELECT SUM(Amount) FROM VoucharDet WHERE VoucherMasID = ?) '
          'WHERE VoucherMasID = ?',
          [row.voucherId, row.voucherId],
        );
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
}

final voucherGenExecutionProvider =
    StateNotifierProvider<VoucherGenExecutionNotifier, VoucherGenState>((ref) {
      return VoucherGenExecutionNotifier(ref);
    });
