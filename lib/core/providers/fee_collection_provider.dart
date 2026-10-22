import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/fee_receipt_view.dart';
import '../db/database.dart';

/// Bank record retrieved from BankInfo table.
class BankRow {
  final int bankInfoId;
  final String bankName;
  final String branch;
  final String acctNo;
  final bool isDefault;

  const BankRow({
    required this.bankInfoId,
    required this.bankName,
    required this.branch,
    required this.acctNo,
    required this.isDefault,
  });

  String get displayName => '$bankName — $branch';
}

/// Provider for bank account options from BankInfo table.
final bankListProvider = FutureProvider<List<BankRow>>((ref) async {
  final db = await DatabaseService.instance.database;
  final rows = await db.query(
    'BankInfo',
    columns: ['BankInfoID', 'BankName', 'Branch', 'AcctNo', 'BankDefault'],
    orderBy: 'BankInfoID ASC',
  );

  return rows.map((r) {
    return BankRow(
      bankInfoId: r['BankInfoID'] as int,
      bankName: (r['BankName'] as String?) ?? '',
      branch: (r['Branch'] as String?) ?? '',
      acctNo: (r['AcctNo'] as String?) ?? '',
      isDefault: (r['BankDefault'] as String?) == 'Y',
    );
  }).toList();
});

/// Result of supervisory revocation attempt.
enum RevokeResult { success, wrongPassword, error }

/// Immutable state for FeeCollectionScreen.
class FeeCollectionState {
  final FeeReceiptView? currentReceipt;
  final bool isLoadingLookup;
  final String? lookupError; // 'Voucher not found' etc.
  final DateTime? paymentDate;
  final int? selectedBankId;
  final int amountTendered; // editable, defaults to remainingAfterAdvance
  final String paymentMode; // 'Cash' | 'Bank Slip' | 'Cheque'
  final String remarks;
  final bool useAdvanceCredit; // checkbox
  final bool sendSms; // checkbox, default true
  final bool isPosting;
  final String? postError;
  // Directory grid state
  final List<FeeReceiptSummaryRow> directoryRows;
  final String? activeDirectoryFilter; // 'unpaid' | 'paid' | null
  final String directorySearch;

  const FeeCollectionState({
    this.currentReceipt,
    this.isLoadingLookup = false,
    this.lookupError,
    this.paymentDate,
    this.selectedBankId,
    this.amountTendered = 0,
    this.paymentMode = 'Cash',
    this.remarks = '',
    this.useAdvanceCredit = false,
    this.sendSms = true,
    this.isPosting = false,
    this.postError,
    this.directoryRows = const [],
    this.activeDirectoryFilter,
    this.directorySearch = '',
  });

  FeeCollectionState copyWith({
    FeeReceiptView? Function()? currentReceipt,
    bool? isLoadingLookup,
    String? Function()? lookupError,
    DateTime? paymentDate,
    int? selectedBankId,
    int? amountTendered,
    String? paymentMode,
    String? remarks,
    bool? useAdvanceCredit,
    bool? sendSms,
    bool? isPosting,
    String? Function()? postError,
    List<FeeReceiptSummaryRow>? directoryRows,
    String? Function()? activeDirectoryFilter,
    String? directorySearch,
  }) {
    return FeeCollectionState(
      currentReceipt: currentReceipt != null
          ? currentReceipt()
          : this.currentReceipt,
      isLoadingLookup: isLoadingLookup ?? this.isLoadingLookup,
      lookupError: lookupError != null ? lookupError() : this.lookupError,
      paymentDate: paymentDate ?? this.paymentDate,
      selectedBankId: selectedBankId ?? this.selectedBankId,
      amountTendered: amountTendered ?? this.amountTendered,
      paymentMode: paymentMode ?? this.paymentMode,
      remarks: remarks ?? this.remarks,
      useAdvanceCredit: useAdvanceCredit ?? this.useAdvanceCredit,
      sendSms: sendSms ?? this.sendSms,
      isPosting: isPosting ?? this.isPosting,
      postError: postError != null ? postError() : this.postError,
      directoryRows: directoryRows ?? this.directoryRows,
      activeDirectoryFilter: activeDirectoryFilter != null
          ? activeDirectoryFilter()
          : this.activeDirectoryFilter,
      directorySearch: directorySearch ?? this.directorySearch,
    );
  }
}

/// State notifier driving fee receipt search, payment posting, and supervisory revocation.
class FeeCollectionNotifier extends StateNotifier<FeeCollectionState> {
  FeeCollectionNotifier([FeeCollectionState? initialState])
    : super(initialState ?? const FeeCollectionState()) {
    // Auto-load unpaid directory on mount so screen is immediately useful.
    Future.microtask(() => lookupVoucherByFilter('unpaid'));
  }

  void setPaymentDate(DateTime date) {
    state = state.copyWith(paymentDate: date);
  }

  void setBankId(int bankId) {
    state = state.copyWith(selectedBankId: bankId);
  }

  void setPaymentMode(String mode) {
    state = state.copyWith(paymentMode: mode);
  }

  void setAmountTendered(int amount) {
    state = state.copyWith(amountTendered: amount);
  }

  void setRemarks(String remarks) {
    state = state.copyWith(remarks: remarks);
  }

  void toggleUseAdvance(bool value) {
    final receipt = state.currentReceipt;
    final int newAmount;
    if (receipt != null) {
      newAmount = value ? receipt.remainingAfterAdvance : receipt.netPayable;
    } else {
      newAmount = 0;
    }
    state = state.copyWith(useAdvanceCredit: value, amountTendered: newAmount);
  }

  void toggleSms(bool value) {
    state = state.copyWith(sendSms: value);
  }

  void clearReceipt() {
    state = const FeeCollectionState();
  }

  /// Clear only the current voucher; preserve directory rows and filter.
  void clearCurrentReceiptOnly() {
    state = state.copyWith(currentReceipt: () => null, lookupError: () => null);
  }

  /// Update the directory search filter text.
  void setDirectorySearch(String query) {
    state = state.copyWith(directorySearch: query);
  }

  /// Clear directory grid and filter.
  void clearDirectory() {
    state = state.copyWith(
      directoryRows: const [],
      activeDirectoryFilter: () => null,
      directorySearch: '',
    );
  }

  /// Load a voucher from the directory grid without clearing the directory.
  Future<void> selectFromDirectory(String voucherMasId) async {
    await lookupVoucher(voucherMasId);
    // lookupVoucher sets currentReceipt; directoryRows are preserved via
    // copyWith in lookupVoucher (directoryRows field is not touched there).
  }

  /// Lookup voucher by VoucherMasID or numeric Stu_RegID.
  Future<void> lookupVoucher(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    state = state.copyWith(
      isLoadingLookup: true,
      lookupError: () => null,
      postError: () => null,
    );

    try {
      final db = await DatabaseService.instance.database;

      // 1. Try exact VoucherMasID
      List<Map<String, dynamic>> voucherRows = await db.rawQuery(
        'SELECT * FROM VoucharMas WHERE VoucherMasID = ? LIMIT 1',
        [cleanQuery],
      );

      // 2. If not found and query is numeric, fallback to most recent unpaid by Stu_RegID
      if (voucherRows.isEmpty && int.tryParse(cleanQuery) != null) {
        final stuRegId = int.parse(cleanQuery);
        voucherRows = await db.rawQuery(
          '''
          SELECT * FROM VoucharMas
          WHERE Student_Class_StuRegID = ? AND IsPaid IN ('N', 'O')
          ORDER BY VoucherMasID DESC LIMIT 1
          ''',
          [stuRegId],
        );

        // Fallback: if no unpaid voucher, load most recent voucher regardless of status
        if (voucherRows.isEmpty) {
          voucherRows = await db.rawQuery(
            '''
            SELECT * FROM VoucharMas
            WHERE Student_Class_StuRegID = ?
            ORDER BY VoucherMasID DESC LIMIT 1
            ''',
            [stuRegId],
          );
        }
      }

      if (voucherRows.isEmpty) {
        state = state.copyWith(
          isLoadingLookup: false,
          lookupError: () => 'Voucher not found',
          currentReceipt: () => null,
        );
        return;
      }

      final voucherRow = voucherRows.first;
      final stuRegId =
          (voucherRow['Student_Class_StuRegID'] as num?)?.toInt() ?? 0;
      final voucherMasId = voucherRow['VoucherMasID'] as String;

      // 3. Query student demographic metadata
      final studentRows = await db.rawQuery(
        '''
        SELECT sr.Stu_RegID, sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name, sr.photo_path,
               c.CName, cs.SecName, sc.ClassRollNo, sc.SessionYr
        FROM Stu_Reg sr
        LEFT JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID
        LEFT JOIN Class c ON sc.ClassID = c.ClassID
        LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
        WHERE sr.Stu_RegID = ?
        ORDER BY sc.SessionYr DESC
        LIMIT 1
        ''',
        [stuRegId],
      );
      final studentRow = studentRows.isNotEmpty
          ? studentRows.first
          : <String, dynamic>{};

      // 4. Query line items from VoucharDet joined to FeeParameters
      final itemRows = await db.rawQuery(
        '''
        SELECT vd.feeParameterID, fp.ParamDesciption, vd.Amount, vd.Discount
        FROM VoucharDet vd
        LEFT JOIN FeeParameters fp ON vd.feeParameterID = fp.FeeParamID
        WHERE vd.VoucharMasID = ?
        ORDER BY vd.feeParameterID ASC
        ''',
        [voucherMasId],
      );
      final lineItems = itemRows
          .map((r) => FeeReceiptLineItem.fromMap(r))
          .toList();

      // 5. Query advance balance from StuAdv
      final advRows = await db.rawQuery(
        'SELECT COALESCE(SUM(AdvAmount), 0) AS AdvBalance FROM StuAdv WHERE StuRegID = ?',
        [stuRegId],
      );
      final advanceBalance =
          (advRows.first['AdvBalance'] as num?)?.toInt() ?? 0;

      // Assemble receipt view
      final receipt = FeeReceiptView.fromJoinedMap(
        voucherRow: voucherRow,
        studentRow: studentRow,
        items: lineItems,
        advanceBalance: advanceBalance,
      );

      // Determine default bank if not already assigned
      int defaultBankId = 1;
      final defaultBankRows = await db.rawQuery(
        'SELECT BankInfoID FROM BankInfo WHERE BankDefault = ? LIMIT 1',
        ['Y'],
      );
      if (defaultBankRows.isNotEmpty) {
        defaultBankId =
            (defaultBankRows.first['BankInfoID'] as num?)?.toInt() ?? 1;
      }

      final bankId = receipt.bankId ?? defaultBankId;
      final useAdv = advanceBalance > 0;
      final initialTendered = useAdv
          ? receipt.remainingAfterAdvance
          : receipt.netPayable;

      state = state.copyWith(
        isLoadingLookup: false,
        lookupError: () => null,
        currentReceipt: () => receipt,
        paymentDate: receipt.paidDate ?? DateTime.now(),
        selectedBankId: bankId,
        amountTendered: initialTendered,
        paymentMode: 'Cash',
        remarks: '',
        useAdvanceCredit: useAdv,
        sendSms: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingLookup: false,
        lookupError: () => 'Voucher not found',
        currentReceipt: () => null,
      );
    }
  }

  /// Filter-based full-list directory load ('unpaid' or 'paid').
  /// Populates directoryRows and clears currentReceipt.
  /// Verbatim empty-state strings preserved from §S19 error catalog.
  Future<void> lookupVoucherByFilter(String filter) async {
    try {
      final db = await DatabaseService.instance.database;
      final where = filter == 'paid'
          ? "vm.IsPaid = 'Y'"
          : "vm.IsPaid IN ('N','O')";
      final orderBy = filter == 'paid'
          ? 'vm.PaidDate DESC, vm.VoucherMasID DESC'
          : 'sc.ClassRollNo ASC, vm.VoucherMasID DESC';

      final rows = await db.rawQuery('''
        SELECT vm.VoucherMasID, vm.student_class_StuRegId,
               sr.NameFirst || ' ' || COALESCE(sr.NameLast,'') AS student_name,
               sr.F_Name AS father_name,
               c.CName AS class_name, cs.SecName AS section_name,
               sc.ClassRollNo, vm.ForMonth,
               vm.SubTotal, vm.Discount, vm.IsPaid, vm.DueDate
        FROM VoucharMas vm
        JOIN Stu_Reg sr ON vm.student_class_StuRegId = sr.Stu_RegID
        LEFT JOIN Student_Class sc
          ON sr.Stu_RegID = sc.Stu_RegID AND sc.SessionYr = vm.SessionYr
        LEFT JOIN Class c ON sc.ClassID = c.ClassID
        LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
        WHERE $where
        ORDER BY $orderBy
      ''');

      if (rows.isEmpty) {
        state = state.copyWith(
          directoryRows: const [],
          activeDirectoryFilter: () => filter,
          lookupError: filter == 'paid' ? () => 'No Paid Vouchar' : () => null,
          currentReceipt: () => null,
        );
        return;
      }

      final summaries = rows.map((r) {
        final subtotal = (r['SubTotal'] as num?)?.toInt() ?? 0;
        final discount = (r['Discount'] as num?)?.toInt() ?? 0;
        final dueDateRaw = r['DueDate'];
        DateTime? dueDate;
        if (dueDateRaw != null) {
          dueDate = DateTime.tryParse(dueDateRaw.toString());
        }
        return FeeReceiptSummaryRow(
          voucherMasId: r['VoucherMasID'] as String,
          stuRegId: (r['student_class_StuRegId'] as num).toInt(),
          studentName: ((r['student_name'] as String?) ?? '').trim(),
          fatherName: (r['father_name'] as String?)?.trim(),
          className: ((r['class_name'] as String?) ?? '').trim(),
          sectionName: ((r['section_name'] as String?) ?? '').trim(),
          rollNo: (r['ClassRollNo'] as num?)?.toInt(),
          forMonth: ((r['ForMonth'] as String?) ?? '').trim(),
          netPayable: subtotal - discount,
          isPaid: ((r['IsPaid'] as String?) ?? 'N').trim(),
          dueDate: dueDate,
        );
      }).toList();

      state = state.copyWith(
        directoryRows: summaries,
        activeDirectoryFilter: () => filter,
        lookupError: () => null,
        currentReceipt: () => null,
      );
    } catch (e) {
      // Swallow silently on mount — DB may not be ready yet
    }
  }

  /// Posts payment transaction atomically to VoucharMas and FeeTransaction.
  /// B5: PaidAmt = cashReceived + advanceApplied (full settlement amount).
  /// FeeTransaction.PaidAmount = cashReceived only (cash trail).
  /// StuAdv deduction row inserted when advance credit used.
  Future<bool> postPayment() async {
    final receipt = state.currentReceipt;
    if (receipt == null || receipt.isFullyPaid) return false;
    if (state.selectedBankId == null) return false;

    // Compute advance deduction
    final cashReceived = state.amountTendered;
    final advanceApplied = state.useAdvanceCredit
        ? min(receipt.advanceBalance, receipt.netPayable)
        : 0;
    final totalPaidAmt = cashReceived + advanceApplied;

    state = state.copyWith(isPosting: true, postError: () => null);

    try {
      final db = await DatabaseService.instance.database;
      final submissionDateStr = DateFormat('yyyy-MM-dd')
          .format(state.paymentDate ?? DateTime.now());

      await db.transaction((txn) async {
        // 1. UPDATE VoucharMas — PaidAmt = cash + advance (full settlement)
        await txn.rawUpdate(
          '''
          UPDATE VoucharMas
          SET IsPaid = 'Y',
              PaidAmt = ?,
              PaidDate = ?,
              BankID = ?
          WHERE VoucherMasID = ?
          ''',
          [
            totalPaidAmt,
            submissionDateStr,
            state.selectedBankId,
            receipt.voucherMasId,
          ],
        );

        // 2. Fetch next FeeTransID (MAX + 1)
        final maxTrans = await txn.rawQuery(
          'SELECT COALESCE(MAX(FeeTransID), 0) + 1 AS nextId FROM FeeTransaction',
        );
        final nextTransId = (maxTrans.first['nextId'] as num).toInt();

        // 3. INSERT INTO FeeTransaction (cash trail only — no advance in bank record)
        final detailStr = state.remarks.trim().isNotEmpty
            ? state.remarks.trim()
            : 'Cash received at teller counter';

        await txn.insert('FeeTransaction', {
          'FeeTransID': nextTransId,
          'BankID': state.selectedBankId,
          'SubmissionDate': submissionDateStr,
          'VoucharNo': receipt.voucherMasId,
          'TotalAmount': receipt.netPayable,
          'PaidAmount': cashReceived,
          'Detail': detailStr,
        });

        // 4. Deduct advance from StuAdv (negative AdvAmount row = deduction)
        if (advanceApplied > 0) {
          final maxAdv = await txn.rawQuery(
            'SELECT COALESCE(MAX(StuAdvID), 0) + 1 AS nextId FROM StuAdv',
          );
          final nextAdvId = (maxAdv.first['nextId'] as num).toInt();
          await txn.insert('StuAdv', {
            'StuAdvID': nextAdvId,
            'StuRegID': receipt.stuRegId,
            'AdvAmount': -advanceApplied,
            'MOP': 'Advance Deduction',
            'Date': submissionDateStr,
            'DepositedBy': 'System',
            'Detail': 'Fee offset for voucher ${receipt.voucherMasId}',
          });
        }
      });

      // Clear receipt state on successful post
      clearReceipt();
      return true;
    } catch (e) {
      state = state.copyWith(
        isPosting: false,
        postError: () => 'Failed to post payment: $e',
      );
      return false;
    }
  }

  /// Revokes paid status under supervisory password verification.
  /// Checks password against InstBranch.SecPd (where BrnachID = 1).
  Future<RevokeResult> revokePayment(String password) async {
    final receipt = state.currentReceipt;
    if (receipt == null) return RevokeResult.error;

    try {
      final db = await DatabaseService.instance.database;

      // 1. Verify supervisory password against InstBranch.SecPd
      final branchRows = await db.rawQuery(
        'SELECT SecPd FROM InstBranch WHERE BrnachID = 1 LIMIT 1',
      );
      if (branchRows.isEmpty) {
        return RevokeResult.wrongPassword;
      }

      final expectedSecPd = (branchRows.first['SecPd'] as String?) ?? '';
      // Case-sensitive exact check
      if (password != expectedSecPd) {
        return RevokeResult.wrongPassword;
      }

      // 2. Revert VoucharMas and purge FeeTransaction atomically
      await db.transaction((txn) async {
        await txn.rawUpdate(
          '''
          UPDATE VoucharMas
          SET IsPaid = 'N',
              PaidAmt = 0,
              PaidDate = NULL,
              BankID = NULL
          WHERE VoucherMasID = ?
          ''',
          [receipt.voucherMasId],
        );

        await txn.rawDelete('DELETE FROM FeeTransaction WHERE VoucharNo = ?', [
          receipt.voucherMasId,
        ]);
      });

      // 3. Update active receipt in state to reflect UNPAID status
      final updatedReceipt = receipt.copyWith(
        isPaid: 'N',
        paidAmount: 0,
        paidDate: () => null,
        bankId: () => null,
      );
      state = state.copyWith(
        currentReceipt: () => updatedReceipt,
        amountTendered: updatedReceipt.remainingAfterAdvance,
      );

      return RevokeResult.success;
    } catch (e) {
      return RevokeResult.error;
    }
  }
}

final feeCollectionProvider =
    StateNotifierProvider<FeeCollectionNotifier, FeeCollectionState>((ref) {
      return FeeCollectionNotifier();
    });
