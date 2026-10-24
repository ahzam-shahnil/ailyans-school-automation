import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bank_account_row.dart';
import '../../models/class_fee_summary.dart';
import '../../models/fee_parameter_row.dart';
import '../db/database.dart';

/// Immutable state for Screen 12 (Tab 1: Class Fee Structure).
@immutable
class FeeParameterState {
  final int selectedTab;
  final String selectedFeeYr;
  final List<ClassFeeSummary> classSummaries;
  final int? selectedClassId;
  final List<FeeParameterRow> currentClassRows;
  final List<Map<String, dynamic>> availableFeeParams;
  final bool isLoading;
  final String? toast;
  final String? errorMessage;

  const FeeParameterState({
    this.selectedTab = 0,
    this.selectedFeeYr = '2017-2018',
    this.classSummaries = const [],
    this.selectedClassId,
    this.currentClassRows = const [],
    this.availableFeeParams = const [],
    this.isLoading = false,
    this.toast,
    this.errorMessage,
  });

  FeeParameterState copyWith({
    int? selectedTab,
    String? selectedFeeYr,
    List<ClassFeeSummary>? classSummaries,
    int? selectedClassId,
    List<FeeParameterRow>? currentClassRows,
    List<Map<String, dynamic>>? availableFeeParams,
    bool? isLoading,
    String? toast,
    String? errorMessage,
    bool clearToast = false,
    bool clearErrorMessage = false,
  }) {
    return FeeParameterState(
      selectedTab: selectedTab ?? this.selectedTab,
      selectedFeeYr: selectedFeeYr ?? this.selectedFeeYr,
      classSummaries: classSummaries ?? this.classSummaries,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      currentClassRows: currentClassRows ?? this.currentClassRows,
      availableFeeParams: availableFeeParams ?? this.availableFeeParams,
      isLoading: isLoading ?? this.isLoading,
      toast: clearToast ? null : (toast ?? this.toast),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

/// StateNotifier managing class fee structure definitions (§S15 SCHfrmFeeParameter).
class FeeParameterNotifier extends StateNotifier<FeeParameterState> {
  FeeParameterNotifier() : super(const FeeParameterState());

  void clearToast() => state = state.copyWith(clearToast: true);
  void clearErrorMessage() => state = state.copyWith(clearErrorMessage: true);

  void setSelectedTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }

  Future<void> setSelectedFeeYr(String feeYr) async {
    state = state.copyWith(selectedFeeYr: feeYr, isLoading: true);
    await loadClassSummaries();
    if (!mounted) return;
    if (state.selectedClassId != null) {
      await loadFeeParametersForClass(state.selectedClassId!);
    }
    if (mounted) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setSelectedClassId(int classId) async {
    state = state.copyWith(selectedClassId: classId, isLoading: true);
    await loadFeeParametersForClass(classId);
    if (mounted) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadInitial({int? initialClassId}) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearToast: true,
    );
    try {
      await loadAvailableFeeParams();
      if (!mounted) return;
      await loadClassSummaries();
      if (!mounted) return;
      final targetClassId = initialClassId ?? 13;
      state = state.copyWith(selectedClassId: targetClassId);
      await loadFeeParametersForClass(targetClassId);
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> loadClassSummaries() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.ClassID, c.CName, COUNT(cpf.FeeParamID) AS headCount, COALESCE(SUM(cpf.Fee), 0) AS totalFee
      FROM Class c
      LEFT JOIN Cls_Param_Fee cpf ON cpf.ClassID = c.ClassID AND cpf.FeeYr = ?
      GROUP BY c.ClassID, c.CName
      ORDER BY c.ClassID ASC
      ''',
      [state.selectedFeeYr],
    );
    if (!mounted) return;
    final summaries = rows.map(ClassFeeSummary.fromMap).toList();
    state = state.copyWith(classSummaries: summaries);
  }

  Future<void> loadFeeParametersForClass(int classId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT cpf.Cls_Param_Fee_ID, cpf.ClassID, cpf.FeeParamID, fp.ParamDesciption, cpf.Fee, cpf.FeeYr
      FROM Cls_Param_Fee cpf
      JOIN FeeParameters fp ON fp.FeeParamID = cpf.FeeParamID
      WHERE cpf.ClassID = ? AND cpf.FeeYr = ?
      ORDER BY cpf.FeeParamID ASC
      ''',
      [classId, state.selectedFeeYr],
    );
    if (!mounted) return;
    final feeRows = rows.map(FeeParameterRow.fromMap).toList();
    state = state.copyWith(currentClassRows: feeRows);
  }

  Future<void> loadAvailableFeeParams() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT FeeParamID, ParamDesciption FROM FeeParameters ORDER BY FeeParamID ASC',
    );
    if (!mounted) return;
    state = state.copyWith(availableFeeParams: rows);
  }

  /// Adds a fee parameter tariff to a class following sequential §S15 validation gates.
  Future<bool> addFeeParameter({
    required int? classId,
    required int? feeParamId,
    required double? fee,
    required String feeYr,
    int userLevel = 1,
  }) async {
    // Gate 1: Role gate (userLevel 3 = read-only guest)
    if (userLevel == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return false;
    }
    // Gate 2: Class gate
    if (classId == null) {
      state = state.copyWith(errorMessage: 'Select Class Please');
      return false;
    }
    // Gate 3: Parameter gate (verbatim trailing space)
    if (feeParamId == null) {
      state = state.copyWith(errorMessage: 'Select Fee Parameter Please ');
      return false;
    }
    // Gate 4: Fee amount gate
    if (fee == null || fee <= 0) {
      state = state.copyWith(errorMessage: 'Enter Fee Please');
      return false;
    }

    final db = await DatabaseService.instance.database;

    // Gate 5: Duplicate check (verbatim leading and trailing spaces)
    final existing = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM Cls_Param_Fee WHERE ClassID = ? AND FeeParamID = ? AND FeeYr = ?',
      [classId, feeParamId, feeYr],
    );
    final count = (existing.first['cnt'] as num?)?.toInt() ?? 0;
    if (count > 0) {
      state = state.copyWith(errorMessage: ' Fee already entered for Class ');
      return false;
    }

    // Insert with surrogate MAX+1
    final maxRes = await db.rawQuery(
      'SELECT COALESCE(MAX(Cls_Param_Fee_ID), 0) + 1 AS nextId FROM Cls_Param_Fee',
    );
    final nextId = (maxRes.first['nextId'] as num).toInt();

    // Column order MUST be (Fee, FeeYr) matching values (fee, feeYr)
    await db.rawInsert(
      'INSERT INTO Cls_Param_Fee (Cls_Param_Fee_ID, ClassID, FeeParamID, Fee, FeeYr) VALUES (?, ?, ?, ?, ?)',
      [nextId, classId, feeParamId, fee, feeYr],
    );

    await loadClassSummaries();
    await loadFeeParametersForClass(classId);
    state = state.copyWith(
      toast: 'Fee Parameter Saved Successfully',
      clearErrorMessage: true,
    );
    return true;
  }

  /// Updates fee amount for an existing class tariff using composite PK.
  Future<bool> updateFeeParameter({
    required int classId,
    required int feeParamId,
    required String feeYr,
    required double? newFee,
    int userLevel = 1,
  }) async {
    if (userLevel == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return false;
    }
    if (newFee == null || newFee <= 0) {
      state = state.copyWith(errorMessage: 'Enter Fee Please');
      return false;
    }

    final db = await DatabaseService.instance.database;
    await db.rawUpdate(
      'UPDATE Cls_Param_Fee SET Fee = ? WHERE ClassID = ? AND FeeParamID = ? AND FeeYr = ?',
      [newFee, classId, feeParamId, feeYr],
    );

    await loadClassSummaries();
    await loadFeeParametersForClass(classId);
    state = state.copyWith(
      toast: 'Fee Parameter Saved Successfully',
      clearErrorMessage: true,
    );
    return true;
  }

  /// Deletes a class fee tariff using composite PK.
  Future<bool> deleteFeeParameter({
    required int classId,
    required int feeParamId,
    required String feeYr,
    int userLevel = 1,
  }) async {
    if (userLevel == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return false;
    }

    final db = await DatabaseService.instance.database;
    await db.rawDelete(
      'DELETE FROM Cls_Param_Fee WHERE ClassID = ? AND FeeParamID = ? AND FeeYr = ?',
      [classId, feeParamId, feeYr],
    );

    await loadClassSummaries();
    await loadFeeParametersForClass(classId);
    state = state.copyWith(
      toast: 'Fee parameter removed',
      clearErrorMessage: true,
    );
    return true;
  }
}

/// Immutable state for Screen 12 (Tab 2: Institutional Bank Accounts).
@immutable
class BankAccountState {
  final List<BankAccountRow> banks;
  final bool isLoading;
  final String? toast;
  final String? errorMessage;

  const BankAccountState({
    this.banks = const [],
    this.isLoading = false,
    this.toast,
    this.errorMessage,
  });

  BankAccountState copyWith({
    List<BankAccountRow>? banks,
    bool? isLoading,
    String? toast,
    String? errorMessage,
    bool clearToast = false,
    bool clearErrorMessage = false,
  }) {
    return BankAccountState(
      banks: banks ?? this.banks,
      isLoading: isLoading ?? this.isLoading,
      toast: clearToast ? null : (toast ?? this.toast),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

/// StateNotifier managing institutional bank accounts (§S16 SCHfrmBankInfo).
class BankAccountNotifier extends StateNotifier<BankAccountState> {
  BankAccountNotifier() : super(const BankAccountState());

  void clearToast() => state = state.copyWith(clearToast: true);
  void clearErrorMessage() => state = state.copyWith(clearErrorMessage: true);

  Future<void> loadBanks() async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearToast: true,
    );
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        'SELECT * FROM BankInfo ORDER BY BankInfoID ASC',
      );
      if (!mounted) return;
      final banks = rows.map(BankAccountRow.fromMap).toList();
      state = state.copyWith(banks: banks);
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<bool> saveBank({
    int? bankInfoId,
    required String bankName,
    String? address,
    String? branch,
    required String acctNo,
    String? acctTitle,
    String? acctType,
    int acctStatus = 1,
    String bankDefault = 'N',
    int userLevel = 1,
  }) async {
    if (userLevel == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return false;
    }
    if (bankName.trim().isEmpty || acctNo.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Bank Name and Account No are required',
      );
      return false;
    }

    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      // If setting this bank as default, clear existing default flag on all others
      if (bankDefault == 'Y') {
        await txn.rawUpdate("UPDATE BankInfo SET BankDefault = 'N'");
      }

      if (bankInfoId == null) {
        // Insert with surrogate MAX+1
        final maxRes = await txn.rawQuery(
          'SELECT COALESCE(MAX(BankInfoID), 0) + 1 AS nextId FROM BankInfo',
        );
        final nextId = (maxRes.first['nextId'] as num).toInt();
        await txn.rawInsert(
          '''
          INSERT INTO BankInfo (BankInfoID, BankName, Address, Branch, AcctNo, AcctTitle, AcctType, AcctStatus, BankDefault)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            nextId,
            bankName.trim(),
            address?.trim() ?? '',
            branch?.trim() ?? '',
            acctNo.trim(),
            acctTitle?.trim() ?? '',
            acctType?.trim() ?? 'Current',
            acctStatus,
            bankDefault,
          ],
        );
      } else {
        // Update existing bank record
        await txn.rawUpdate(
          '''
          UPDATE BankInfo
          SET BankName = ?, Address = ?, Branch = ?, AcctNo = ?, AcctTitle = ?, AcctType = ?, AcctStatus = ?, BankDefault = ?
          WHERE BankInfoID = ?
          ''',
          [
            bankName.trim(),
            address?.trim() ?? '',
            branch?.trim() ?? '',
            acctNo.trim(),
            acctTitle?.trim() ?? '',
            acctType?.trim() ?? 'Current',
            acctStatus,
            bankDefault,
            bankInfoId,
          ],
        );
      }
    });

    await loadBanks();
    state = state.copyWith(
      toast: 'Bank account saved',
      clearErrorMessage: true,
    );
    return true;
  }

  /// Looks up a bank record by its ID, setting verbatim S16 warning on failure.
  Future<BankAccountRow?> lookupBankById(int bankId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT * FROM BankInfo WHERE BankInfoID = ?',
      [bankId],
    );
    if (rows.isEmpty) {
      // Verbatim S16 typo 'Exits' preserved
      state = state.copyWith(
        errorMessage: 'No Bank Exits with Bank ID $bankId',
      );
      return null;
    }
    return BankAccountRow.fromMap(rows.first);
  }
}

final feeParameterProvider =
    StateNotifierProvider<FeeParameterNotifier, FeeParameterState>(
      (ref) => FeeParameterNotifier(),
    );

final bankAccountProvider =
    StateNotifierProvider<BankAccountNotifier, BankAccountState>(
      (ref) => BankAccountNotifier(),
    );
