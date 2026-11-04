import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/fee_receipt_view.dart';
import '../db/database.dart';
import 'package:school_automation/core/sync/node_id_allocator.dart';
import 'clock_provider.dart';
import 'shell_metadata_provider.dart';
import '../../core/utils/fee_head_display.dart';
import '../utils/receipt_pdf_generator.dart'
    as rcp
    show FeeReceiptPrintData, FeeReceiptLineItem;
import '../utils/defaulter_list_pdf_generator.dart';

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
  final Ref? _ref;

  FeeCollectionNotifier([FeeCollectionState? initialState, Ref? ref])
    : _ref = ref,
      super(initialState ?? const FeeCollectionState()) {
    // Auto-load unpaid directory on mount so screen is immediately useful.
    Future.microtask(() => lookupVoucherByFilter('unpaid'));
  }

  DateTime _now() => _ref?.read(clockProvider)() ?? DateTime.now();

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
      newAmount = value
          ? receipt.remainingAfterAdvance
          : receipt.remainingBalance;
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
               COALESCE(c_pres.CName, c_sess.CName, c_vm.CName, c_any.CName) AS CName,
               COALESCE(c_pres.CName, c_sess.CName, c_vm.CName, c_any.CName) AS className,
               COALESCE(cs_pres.SecName, cs_sess.SecName, cs_any.SecName, 'A') AS SecName,
               COALESCE(cs_pres.SecName, cs_sess.SecName, cs_any.SecName, 'A') AS classSecName,
               COALESCE(sc_pres.ClassRollNo, sc_sess.ClassRollNo, sc_any.ClassRollNo) AS ClassRollNo,
               COALESCE(sc_pres.ClassRollNo, sc_sess.ClassRollNo, sc_any.ClassRollNo) AS rollNo,
               COALESCE(sc_pres.SessionYr, sc_sess.SessionYr, sc_any.SessionYr) AS SessionYr
        FROM Stu_Reg sr
        LEFT JOIN Student_Class sc_sess ON sc_sess.Stu_RegID = sr.Stu_RegID AND sc_sess.SessionYr = ?
        LEFT JOIN Class c_sess ON c_sess.ClassID = sc_sess.ClassID
        LEFT JOIN ClassSec cs_sess ON cs_sess.ClassSecID = sc_sess.ClassSecID
        LEFT JOIN Student_Class sc_pres ON sc_pres.Stu_RegID = sr.Stu_RegID AND sc_pres.Present = 1
        LEFT JOIN Class c_pres ON c_pres.ClassID = sc_pres.ClassID
        LEFT JOIN ClassSec cs_pres ON cs_pres.ClassSecID = sc_pres.ClassSecID
        LEFT JOIN Class c_vm ON c_vm.ClassID = ?
        LEFT JOIN Student_Class sc_any ON sc_any.Stu_RegID = sr.Stu_RegID
        LEFT JOIN Class c_any ON c_any.ClassID = sc_any.ClassID
        LEFT JOIN ClassSec cs_any ON cs_any.ClassSecID = sc_any.ClassSecID
        WHERE sr.Stu_RegID = ?
        ORDER BY sc_sess.SessionYr DESC, sc_any.SessionYr DESC
        LIMIT 1
        ''',
        [voucherRow['SessionYr'], voucherRow['ClassID'], stuRegId],
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
      var lineItems = itemRows
          .map((r) => FeeReceiptLineItem.fromMap(r))
          .toList();

      // Fallback line item when VoucharDet is empty for a historical voucher
      final subtotal = (voucherRow['SubTotal'] as num?)?.toInt() ?? 0;
      final discount = (voucherRow['Discount'] as num?)?.toInt() ?? 0;
      final forMonth = (voucherRow['ForMonth'] as String?)?.trim() ?? '';
      if (lineItems.isEmpty && subtotal > 0) {
        lineItems = [
          FeeReceiptLineItem(
            feeParamId: 1,
            headName: 'Consolidated Voucher Fee ($forMonth)',
            amount: subtotal,
            discount: discount,
          ),
        ];
      }

      // 5. Query advance balance from StuAdv
      final advRows = await db.rawQuery(
        'SELECT COALESCE(SUM(AdvAmount), 0) AS AdvBalance FROM StuAdv WHERE StuRegID = ?',
        [stuRegId],
      );
      final advanceBalance =
          (advRows.first['AdvBalance'] as num?)?.toInt() ?? 0;

      // 6. Query payment installment history from FeeTransaction
      final transRows = await db.rawQuery(
        '''
        SELECT ft.FeeTransID, ft.BankID, ft.SubmissionDate,
               ft.TotalAmount, ft.PaidAmount, ft.Detail,
               bi.BankName
        FROM FeeTransaction ft
        LEFT JOIN BankInfo bi ON ft.BankID = bi.BankInfoID
        WHERE ft.VoucharNo = ?
        ORDER BY ft.FeeTransID ASC
        ''',
        [voucherMasId],
      );
      final paymentHistory = transRows
          .map((r) => VoucherPaymentInstallment.fromMap(r))
          .toList();

      // Assemble receipt view
      final receipt = FeeReceiptView.fromJoinedMap(
        voucherRow: voucherRow,
        studentRow: studentRow,
        items: lineItems,
        advanceBalance: advanceBalance,
        paymentHistory: paymentHistory,
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
          : receipt.remainingBalance;

      state = state.copyWith(
        isLoadingLookup: false,
        lookupError: () => null,
        currentReceipt: () => receipt,
        paymentDate: receipt.paidDate ?? _now(),
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
        SELECT vm.VoucherMasID, vm.Student_Class_StuRegID,
               sr.NameFirst, sr.NameLast, sr.F_Name,
               c.CName AS class_name, cs.SecName AS section_name,
               sc.ClassRollNo, vm.ForMonth, vm.SubTotal, vm.Discount,
               vm.PaidAmt, vm.IsPaid, vm.DueDate
        FROM VoucharMas vm
        JOIN Stu_Reg sr ON vm.Student_Class_StuRegID = sr.Stu_RegID
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
        final first = (r['NameFirst'] as String?)?.trim() ?? '';
        final last = (r['NameLast'] as String?)?.trim() ?? '';
        final studentName = [first, last].where((s) => s.isNotEmpty).join(' ');
        final subtotal = (r['SubTotal'] as num?)?.toInt() ?? 0;
        final discount = (r['Discount'] as num?)?.toInt() ?? 0;
        final paidAmt = (r['PaidAmt'] as num?)?.toInt() ?? 0;
        final dueDateRaw = r['DueDate'];
        DateTime? dueDate;
        if (dueDateRaw != null) {
          dueDate = DateTime.tryParse(dueDateRaw.toString());
        }
        return FeeReceiptSummaryRow(
          voucherMasId: (r['VoucherMasID'] as String?) ?? '',
          stuRegId: (r['Student_Class_StuRegID'] as num?)?.toInt() ?? 0,
          studentName: studentName.isNotEmpty ? studentName : 'Unknown Student',
          fatherName: (r['F_Name'] as String?)?.trim(),
          className: (r['class_name'] as String?)?.trim() ?? '',
          sectionName: (r['section_name'] as String?)?.trim() ?? '',
          rollNo: (r['ClassRollNo'] as num?)?.toInt(),
          forMonth: (r['ForMonth'] as String?)?.trim() ?? '',
          netPayable: subtotal - discount,
          paidAmt: paidAmt,
          isPaid: (r['IsPaid'] as String?)?.trim() ?? 'N',
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

  /// Loads all data needed to print a 3-copy payment receipt for a given voucher.
  ///
  /// Tries FeeTransaction first (preferred — has official FeeTransID).
  /// Falls back to constructing from VoucharMas row for pre-seeded paid vouchers
  /// that have IsPaid='Y' but no matching FeeTransaction row.
  ///
  /// Returns null if the voucher cannot be found or is not paid.
  Future<rcp.FeeReceiptPrintData?> loadReceiptPrintData(
    String voucherMasId, {
    String paymentMode = 'Cash',
  }) async {
    try {
      final db = await DatabaseService.instance.database;

      // 1. Load VoucharMas row with student + class info
      final masRows = await db.rawQuery(
        '''
        SELECT vm.VoucherMasID, vm.Student_Class_StuRegID, vm.SubTotal,
               vm.ForMonth, vm.Discount, vm.IsPaid, vm.PaidAmt, vm.PaidDate,
               vm.BankID, vm.SessionYr,
               sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name,
               COALESCE(c_pres.CName, c_sess.CName, c_vm.CName, c_any.CName) AS class_name,
               COALESCE(c_pres.CName, c_sess.CName, c_vm.CName, c_any.CName) AS className,
               COALESCE(cs_pres.SecName, cs_sess.SecName, cs_any.SecName, 'A') AS section_name,
               COALESCE(cs_pres.SecName, cs_sess.SecName, cs_any.SecName, 'A') AS classSecName,
               COALESCE(sc_pres.ClassRollNo, sc_sess.ClassRollNo, sc_any.ClassRollNo) AS rollNo,
               COALESCE(sc_pres.ClassRollNo, sc_sess.ClassRollNo, sc_any.ClassRollNo) AS ClassRollNo,
               COALESCE(sc_pres.SessionYr, sc_sess.SessionYr, vm.SessionYr) AS sc_session
        FROM VoucharMas vm
        LEFT JOIN Stu_Reg sr ON vm.Student_Class_StuRegID = sr.Stu_RegID
        LEFT JOIN Student_Class sc_sess ON sc_sess.Stu_RegID = sr.Stu_RegID AND sc_sess.SessionYr = vm.SessionYr
        LEFT JOIN Class c_sess ON c_sess.ClassID = sc_sess.ClassID
        LEFT JOIN ClassSec cs_sess ON cs_sess.ClassSecID = sc_sess.ClassSecID
        LEFT JOIN Student_Class sc_pres ON sc_pres.Stu_RegID = sr.Stu_RegID AND sc_pres.Present = 1
        LEFT JOIN Class c_pres ON c_pres.ClassID = sc_pres.ClassID
        LEFT JOIN ClassSec cs_pres ON cs_pres.ClassSecID = sc_pres.ClassSecID
        LEFT JOIN Class c_vm ON c_vm.ClassID = vm.ClassID
        LEFT JOIN Student_Class sc_any ON sc_any.Stu_RegID = sr.Stu_RegID
        LEFT JOIN Class c_any ON c_any.ClassID = sc_any.ClassID
        LEFT JOIN ClassSec cs_any ON cs_any.ClassSecID = sc_any.ClassSecID
        WHERE vm.VoucherMasID = ?
        ORDER BY sc_sess.SessionYr DESC, sc_any.SessionYr DESC
        LIMIT 1
        ''',
        [voucherMasId],
      );
      if (masRows.isEmpty) return null;
      final mas = masRows.first;

      final stuRegId = (mas['Student_Class_StuRegID'] as num?)?.toInt() ?? 0;
      final subtotal = (mas['SubTotal'] as num?)?.toInt() ?? 0;
      final discount = (mas['Discount'] as num?)?.toInt() ?? 0;
      final masNetPayable = subtotal - discount;
      final forMonth = (mas['ForMonth'] as String?)?.trim() ?? '';
      final sessionYr =
          (mas['sc_session'] as String?)?.trim() ??
          (mas['SessionYr'] as String?)?.trim();
      final className = (mas['className'] ?? mas['class_name']) as String?;
      final sectionName =
          (mas['classSecName'] ?? mas['section_name']) as String?;
      final rollNo = ((mas['rollNo'] ?? mas['ClassRollNo']) as num?)?.toInt();

      // Assemble student name
      final nameFirst = (mas['NameFirst'] as String?)?.trim() ?? '';
      final nameMid = (mas['NameMiddle'] as String?)?.trim() ?? '';
      final nameLast = (mas['NameLast'] as String?)?.trim() ?? '';
      final parts = [
        nameFirst,
        nameMid,
        nameLast,
      ].where((p) => p.isNotEmpty).toList();
      final studentName = parts.isNotEmpty
          ? parts.join(' ')
          : 'Unknown Student';
      final fatherName = (mas['F_Name'] as String?)?.trim();

      // 2. Load line items from VoucharDet joined to FeeParameters
      final detRows = await db.rawQuery(
        '''
        SELECT vd.feeParameterID, fp.ParamDesciption, vd.Amount, vd.Discount
        FROM VoucharDet vd
        LEFT JOIN FeeParameters fp ON vd.feeParameterID = fp.FeeParamID
        WHERE vd.VoucharMasID = ?
        ORDER BY vd.feeParameterID ASC
        ''',
        [voucherMasId],
      );
      var lineItems = detRows.map((r) {
        return rcp.FeeReceiptLineItem(
          feeParamId: (r['feeParameterID'] as num?)?.toInt() ?? 0,
          headName: FeeHeadDisplay.of(r['ParamDesciption'] as String?),
          amount: (r['Amount'] as num?)?.toInt() ?? 0,
          discount: (r['Discount'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      if (lineItems.isEmpty && subtotal > 0) {
        lineItems = [
          rcp.FeeReceiptLineItem(
            feeParamId: 1,
            headName: 'Consolidated Voucher Fee ($forMonth)',
            amount: subtotal,
            discount: discount,
          ),
        ];
      }

      // 3. Load all FeeTransaction rows for this voucher (ordered chronologically)
      final transRows = await db.rawQuery(
        '''
        SELECT ft.FeeTransID, ft.BankID, ft.SubmissionDate,
               ft.TotalAmount, ft.PaidAmount, ft.Detail,
               bi.BankName
        FROM FeeTransaction ft
        LEFT JOIN BankInfo bi ON ft.BankID = bi.BankInfoID
        WHERE ft.VoucharNo = ?
        ORDER BY ft.FeeTransID ASC
        ''',
        [voucherMasId],
      );
      final allInstallments = transRows
          .map((r) => VoucherPaymentInstallment.fromMap(r))
          .toList();

      final totalPaidAmount = (mas['PaidAmt'] as num?)?.toInt() ?? 0;
      final netPayable = masNetPayable;
      final remainingBalance = max(0, netPayable - totalPaidAmount);

      int feeTransId;
      DateTime submissionDate;
      int latestInstallmentAmount;
      int bankIdForReceipt;

      if (transRows.isNotEmpty) {
        final latest = transRows.last;
        feeTransId = (latest['FeeTransID'] as num?)?.toInt() ?? 0;
        final dateStr = (latest['SubmissionDate'] as String?)?.trim() ?? '';
        submissionDate = DateTime.tryParse(dateStr) ?? _now();
        latestInstallmentAmount =
            (latest['PaidAmount'] as num?)?.toInt() ?? totalPaidAmount;
        bankIdForReceipt = (latest['BankID'] as num?)?.toInt() ?? 1;
      } else {
        feeTransId = 0;
        final paidDateStr = (mas['PaidDate'] as String?)?.trim() ?? '';
        submissionDate = DateTime.tryParse(paidDateStr) ?? _now();
        latestInstallmentAmount = totalPaidAmount > 0
            ? totalPaidAmount
            : masNetPayable;
        bankIdForReceipt = (mas['BankID'] as num?)?.toInt() ?? 1;
      }

      final previousPaidAmount = max(
        0,
        totalPaidAmount - latestInstallmentAmount,
      );

      // Separate prior installments from current payment to avoid duplication
      final previousInstallments = allInstallments
          .where((tx) => tx.feeTransId != feeTransId)
          .toList();

      // 4. Load bank info
      final bankRows = await db.rawQuery(
        'SELECT BankName, Branch, AcctNo FROM BankInfo WHERE BankInfoID = ? LIMIT 1',
        [bankIdForReceipt],
      );
      final bankName = bankRows.isNotEmpty
          ? (bankRows.first['BankName'] as String?)?.trim() ?? 'Askari Bank'
          : 'Askari Bank';
      final bankBranch = bankRows.isNotEmpty
          ? (bankRows.first['Branch'] as String?)?.trim()
          : null;
      final bankAcctNo = bankRows.isNotEmpty
          ? (bankRows.first['AcctNo'] as String?)?.trim()
          : null;

      return rcp.FeeReceiptPrintData(
        feeTransId: feeTransId,
        voucherMasId: voucherMasId,
        stuRegId: stuRegId,
        studentName: studentName,
        fatherName: fatherName,
        className: className,
        sectionName: sectionName,
        classSecName: sectionName,
        rollNo: rollNo,
        sessionYr: sessionYr,
        forMonth: forMonth,
        submissionDate: submissionDate,
        subtotal: subtotal,
        discount: discount,
        totalAmount: masNetPayable,
        paidAmount: latestInstallmentAmount,
        totalPaidToDate: totalPaidAmount,
        previousPaidAmount: previousPaidAmount,
        remainingBalance: remainingBalance,
        paymentHistory: previousInstallments,
        paymentMode: paymentMode,
        bankName: bankName,
        bankBranch: bankBranch,
        bankAcctNo: bankAcctNo,
        lineItems: lineItems,
      );
    } catch (_) {
      return null;
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
        ? min(receipt.advanceBalance, receipt.remainingBalance)
        : 0;
    final paidAmountNow = cashReceived + advanceApplied;
    if (paidAmountNow <= 0) return false;

    state = state.copyWith(isPosting: true, postError: () => null);

    try {
      final db = await DatabaseService.instance.database;
      final submissionDateStr = DateFormat('yyyy-MM-dd')
          .format(state.paymentDate ?? _now());

      await db.transaction((txn) async {
        // Query current SubTotal, Discount, and PaidAmt directly from VoucharMas
        final currentRows = await txn.rawQuery(
          '''
          SELECT SubTotal, COALESCE(Discount, 0) AS Discount, COALESCE(PaidAmt, 0) AS PrevPaid
          FROM VoucharMas
          WHERE VoucherMasID = ?
          LIMIT 1
          ''',
          [receipt.voucherMasId],
        );
        if (currentRows.isEmpty) {
          throw StateError(
            'Voucher ${receipt.voucherMasId} not found in database',
          );
        }

        // 1. UPDATE VoucharMas — PaidDate and BankID (reconciler sets PaidAmt and IsPaid)
        await txn.rawUpdate(
          '''
          UPDATE VoucharMas
          SET PaidDate = ?,
              BankID = ?
          WHERE VoucherMasID = ?
          ''',
          [
            submissionDateStr,
            state.selectedBankId,
            receipt.voucherMasId,
          ],
        );

        // 2. Fetch next FeeTransID via allocator
        final nextTransId = await NodeIdAllocator.allocateInTransaction(
          txn,
          tableName: 'FeeTransaction',
          pkColumn: 'FeeTransID',
        );

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
          final nextAdvId = await NodeIdAllocator.allocateInTransaction(
            txn,
            tableName: 'StuAdv',
            pkColumn: 'StuAdvID',
          );
          await txn.insert('StuAdv', {
            'StuAdvID': nextAdvId,
            'StuRegID': receipt.stuRegId,
            'AdvAmount': -advanceApplied,
            'MOP': 'Advance Deduction',
            'Date': submissionDateStr,
            'DepositedBy': 'System',
            'Detail': 'Fee offset for voucher ${receipt.voucherMasId}',
            'VoucherMasID': receipt.voucherMasId,
          });
        }

        // 5. Reconcile voucher ledger to compute PaidAmt and IsPaid from transactions
        await LedgerReconciler.reconcileVoucher(txn, receipt.voucherMasId);
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

  /// Builds the fee defaulters list grouped by class & section with executive summary.
  /// Used by FeeCollectionScreen to render the institutional defaulter roster PDF.
  Future<
    ({List<DefaulterClassGroup> groups, DefaulterListFilterSummary summary})
  >
  buildDefaulterList({
    String? classFilter,
    String? monthFilter,
    String? sessionYr,
  }) async {
    final db = await DatabaseService.instance.database;

    String effectiveSessionYr = sessionYr?.trim() ?? '';
    if (effectiveSessionYr.isEmpty) {
      final meta = _ref?.read(shellMetadataProvider).value;
      if (meta != null && meta.sessionYear.trim().isNotEmpty) {
        effectiveSessionYr = meta.sessionYear.trim();
      } else {
        final confRows = await db.rawQuery(
          "SELECT config_value FROM app_config WHERE config_key = 'default_session_yr' LIMIT 1",
        );
        if (confRows.isNotEmpty && confRows.first['config_value'] != null) {
          effectiveSessionYr = (confRows.first['config_value'] as String)
              .trim();
        } else {
          effectiveSessionYr = '2026-27';
        }
      }
    }

    final whereConditions = <String>[
      "vm.IsPaid = 'N'",
      "(vm.SubTotal - COALESCE(vm.Discount, 0) - COALESCE(vm.PaidAmt, 0)) > 0",
    ];
    final whereArgs = <dynamic>[];

    if (effectiveSessionYr != 'All Sessions' &&
        effectiveSessionYr != '2026-27') {
      whereConditions.insert(0, 'vm.SessionYr = ?');
      whereArgs.insert(0, effectiveSessionYr);
    }

    if (classFilter != null &&
        classFilter.trim().isNotEmpty &&
        classFilter != 'All Classes') {
      whereConditions.add('c.CName = ?');
      whereArgs.add(classFilter.trim());
    }

    if (monthFilter != null &&
        monthFilter.trim().isNotEmpty &&
        monthFilter != 'All Months') {
      whereConditions.add('vm.ForMonth = ?');
      whereArgs.add(monthFilter.trim());
    }

    final whereClause = whereConditions.join(' AND ');

    final rows = await db.rawQuery('''
      SELECT vm.VoucherMasID, vm.Student_Class_StuRegID,
             sr.NameFirst, sr.NameLast, sr.F_Name, sr.Mobile1,
             c.CName AS class_name, cs.SecName AS section_name,
             sc.ClassRollNo, vm.ForMonth, vm.SubTotal, vm.Discount,
             vm.PaidAmt, vm.IsPaid, vm.DueDate, vm.SessionYr,
             (vm.SubTotal - COALESCE(vm.Discount, 0) - COALESCE(vm.PaidAmt, 0)) AS balance
      FROM VoucharMas vm
      JOIN Stu_Reg sr ON vm.Student_Class_StuRegID = sr.Stu_RegID
      LEFT JOIN Student_Class sc
        ON sr.Stu_RegID = sc.Stu_RegID AND sc.SessionYr = vm.SessionYr
      LEFT JOIN Class c ON (sc.ClassID = c.ClassID OR (sc.ClassID IS NULL AND vm.ClassID = c.ClassID))
      LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
      WHERE $whereClause
      ORDER BY c.ClassID ASC, cs.ClassSecID ASC, sc.ClassRollNo ASC, vm.VoucherMasID DESC
    ''', whereArgs);

    final now = _now();
    final allRows = <DefaulterListRow>[];

    for (final r in rows) {
      final first = (r['NameFirst'] as String?)?.trim() ?? '';
      final last = (r['NameLast'] as String?)?.trim() ?? '';
      final studentName = [first, last].where((s) => s.isNotEmpty).join(' ');
      final subtotal = (r['SubTotal'] as num?)?.toInt() ?? 0;
      final discount = (r['Discount'] as num?)?.toInt() ?? 0;
      final paidAmt = (r['PaidAmt'] as num?)?.toInt() ?? 0;
      final balance =
          (r['balance'] as num?)?.toInt() ?? (subtotal - discount - paidAmt);
      final netPayable = balance;

      DateTime? dueDate;
      final dueDateRaw = r['DueDate'];
      if (dueDateRaw != null) {
        dueDate = DateTime.tryParse(dueDateRaw.toString());
      }

      int daysOverdue = 0;
      if (dueDate != null && now.isAfter(dueDate)) {
        daysOverdue = now.difference(dueDate).inDays;
      }

      allRows.add(
        DefaulterListRow(
          voucherMasId: (r['VoucherMasID'] as String?) ?? '',
          stuRegId: (r['Student_Class_StuRegID'] as num?)?.toInt() ?? 0,
          studentName: studentName.isNotEmpty ? studentName : 'Unknown Student',
          fatherName: (r['F_Name'] as String?)?.trim(),
          mobile1: (r['Mobile1'] as String?)?.trim(),
          className: (r['class_name'] as String?)?.trim() ?? 'Unknown Class',
          sectionName: (r['section_name'] as String?)?.trim() ?? '',
          rollNo: (r['ClassRollNo'] as num?)?.toInt(),
          forMonth: (r['ForMonth'] as String?)?.trim() ?? '',
          subtotal: subtotal,
          discount: discount,
          paidAmt: paidAmt,
          netPayable: netPayable,
          balance: balance,
          isPaid: (r['IsPaid'] as String?)?.trim() ?? 'N',
          dueDate: dueDate,
          daysOverdue: daysOverdue,
        ),
      );
    }

    // Group rows by class & section
    final groupMap = <String, List<DefaulterListRow>>{};
    for (final r in allRows) {
      final label = r.sectionName.isNotEmpty
          ? '${r.className} - Section ${r.sectionName}'
          : r.className;
      groupMap.putIfAbsent(label, () => []).add(r);
    }

    final groups = <DefaulterClassGroup>[];
    for (final entry in groupMap.entries) {
      final groupRows = entry.value;
      final groupSubtotal = groupRows.fold<int>(0, (sum, r) => sum + r.balance);
      groups.add(
        DefaulterClassGroup(
          classLabel: entry.key,
          rows: groupRows,
          subtotal: groupSubtotal,
        ),
      );
    }

    final resolvedSessionYr = rows.isNotEmpty
        ? ((rows.first['SessionYr'] as String?) ?? effectiveSessionYr)
        : effectiveSessionYr;
    final reportMonth = (monthFilter == null || monthFilter == 'All Months')
        ? 'All Billing Months'
        : monthFilter;
    final totalDefaulters = allRows.length;
    final uniqueStudents = allRows.map((r) => r.stuRegId).toSet().length;
    final totalOutstanding = allRows.fold<int>(0, (sum, r) => sum + r.balance);

    final summary = DefaulterListFilterSummary(
      sessionYr: (sessionYr != null && sessionYr.trim().isNotEmpty)
          ? sessionYr.trim()
          : resolvedSessionYr,
      classFilter: (classFilter == null || classFilter == 'All Classes')
          ? null
          : classFilter,
      totalDefaulters: totalDefaulters,
      uniqueStudents: uniqueStudents,
      totalOutstanding: totalOutstanding,
      reportMonth: reportMonth,
      generatedAt: now,
    );

    return (groups: groups, summary: summary);
  }
}

final feeCollectionProvider =
    StateNotifierProvider<FeeCollectionNotifier, FeeCollectionState>((ref) {
      return FeeCollectionNotifier(null, ref);
    });
