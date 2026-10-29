import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_automation/core/utils/attendance_pdf_generator.dart';
import 'package:school_automation/core/utils/biodata_pdf_generator.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';
import 'package:school_automation/core/utils/receipt_pdf_generator.dart';
import 'package:school_automation/core/utils/voucher_pdf_generator.dart';
import 'package:school_automation/models/fee_receipt_view.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ReportPreviewState {
  final bool isLoading;
  final Uint8List? bytes;
  final String? error;

  const ReportPreviewState({
    this.isLoading = false,
    this.bytes,
    this.error,
  });

  ReportPreviewState copyWith({
    bool? isLoading,
    Uint8List? bytes,
    String? error,
    bool clearBytes = false,
    bool clearError = false,
  }) {
    return ReportPreviewState(
      isLoading: isLoading ?? this.isLoading,
      bytes: clearBytes ? null : (bytes ?? this.bytes),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ReportPreviewNotifier extends StateNotifier<ReportPreviewState> {
  final ReportRequest request;

  // Tracks the selected voucher mode: 0 = Three-Copy Slips, 1 = Cohort Ledger.
  // Only meaningful when request.type == ReportType.feeVoucher.
  int _feeVoucherMode = 0;

  ReportPreviewNotifier(this.request)
      : super(const ReportPreviewState(isLoading: true)) {
    generate();
  }

  Future<void> generate() async {
    state = const ReportPreviewState(isLoading: true);
    try {
      final Uint8List bytes;

      if (request.customBytesBuilder != null) {
        bytes = await request.customBytesBuilder!();
      } else {
        bytes = await _generateByType();
      }

      if (mounted) {
        state = ReportPreviewState(bytes: bytes);
      }
    } catch (e, st) {
      if (mounted) {
        state = ReportPreviewState(
          error: 'Failed to generate PDF: $e\n$st',
        );
      }
    }
  }

  Future<Uint8List> _generateByType() async {
    switch (request.type) {
      case ReportType.feeVoucher:
        return _generateFeeVoucher(_feeVoucherMode);
      case ReportType.feeReceipt:
        return _generateFeeReceipt();
      case ReportType.biodata:
        return _generateBiodata();
      case ReportType.defaulterList:
        return _generateDefaulterList();
      case ReportType.attendanceRegister:
        return _generateAttendanceRegister();
    }
  }

  /// Switches the voucher layout mode and re-generates the PDF.
  /// mode 0 = Three-Copy Slips, mode 1 = Cohort Ledger.
  /// No-op for non-feeVoucher request types.
  Future<void> regenerateWithMode(int mode) async {
    if (mode != 0 && mode != 1) return;
    _feeVoucherMode = mode;
    if (!mounted) return;
    state = const ReportPreviewState(isLoading: true);
    try {
      final bytes = await _generateFeeVoucher(mode);
      if (mounted) {
        state = ReportPreviewState(bytes: bytes);
      }
    } catch (e, st) {
      if (mounted) {
        state = ReportPreviewState(
          error: 'Failed to generate PDF: $e\n$st',
        );
      }
    }
  }

  Future<Uint8List> _generateFeeVoucher(int mode) async {
    const requiredKeys = [
      'branchName',
      'branchAddress',
      'bankName',
      'bankBranch',
      'bankAcctNo',
    ];

    for (final key in requiredKeys) {
      if (!request.extraParams.containsKey(key) ||
          (request.extraParams[key] as String?)?.isEmpty != false) {
        throw ArgumentError('Missing required extraParam for feeVoucher: $key');
      }
    }

    final voucherList = request.vouchers;
    if (voucherList == null || voucherList.isEmpty) {
      throw ArgumentError('feeVoucher requires a non-empty vouchers list.');
    }

    final vouchers = voucherList.cast<FeeReceiptView>();
    final extra = request.extraParams;

    if (mode == 0) {
      // Three-Copy Slips (one page per student, 3 columns: Student/School/Bank)
      return ThreeCopyVouchersPdf.generate(
        vouchers: vouchers,
        branchName: extra['branchName'] as String,
        branchAddress: extra['branchAddress'] as String,
        bankName: extra['bankName'] as String,
        bankBranch: extra['bankBranch'] as String,
        bankAcctNo: extra['bankAcctNo'] as String,
      );
    } else {
      // Cohort Ledger — summary table of all vouchers
      return FeeLedgerVoucherGenerator(
        institutionName: extra['branchName'] as String,
        ledgerPeriodTitle:
            'Cohort Ledger - ${vouchers.isNotEmpty ? vouchers.first.forMonth : ""}',
        transactions: vouchers
            .map(
              (v) => FeeVoucherTransactionRecord.fromFeeReceipt(
                v,
                className: v.className ?? '',
              ),
            )
            .toList(),
      ).generatePdf();
    }
  }

  Future<Uint8List> _generateFeeReceipt() async {
    const requiredKeys = ['branchName', 'branchAddress'];
    final missing = requiredKeys
        .where(
          (k) =>
              !request.extraParams.containsKey(k) ||
              request.extraParams[k] == null ||
              request.extraParams[k].toString().trim().isEmpty,
        )
        .toList();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing required params for feeReceipt: ${missing.join(", ")}',
      );
    }

    final receiptList = request.vouchers;
    if (receiptList == null || receiptList.isEmpty) {
      throw ArgumentError('feeReceipt requires a non-empty vouchers list.');
    }

    return ReceiptPdfGenerator.generateThreeCopyReceipts(
      receipts: receiptList.cast<FeeReceiptPrintData>(),
      branchName: request.extraParams['branchName'] as String,
      branchAddress: request.extraParams['branchAddress'] as String,
    );
  }

  Future<Uint8List> _generateBiodata() async {
    if (request.vouchers == null || request.vouchers!.isEmpty) {
      throw StateError('No student data provided for biodata preview.');
    }
    const requiredKeys = ['branchName', 'branchAddress'];
    final missing = requiredKeys
        .where(
          (k) =>
              !request.extraParams.containsKey(k) ||
              request.extraParams[k] == null ||
              request.extraParams[k].toString().trim().isEmpty,
        )
        .toList();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing required params for biodata: ${missing.join(", ")}',
      );
    }
    final data = request.vouchers!.first as StudentBiodataPrintData;
    return BiodataPdfGenerator.generateStudentBiodata(
      data: data,
      branchName: request.extraParams['branchName'] as String,
      branchAddress: request.extraParams['branchAddress'] as String,
      branchPhone: request.extraParams['branchPhone'] as String?,
      branchPrincipal: request.extraParams['branchPrincipal'] as String?,
    );
  }

  Future<Uint8List> _generateAttendanceRegister() async {
    final data = request.extraParams['attendanceData'] as AttendancePdfData?;
    if (data == null) {
      throw StateError('Missing attendanceData in extraParams.');
    }
    return buildAttendancePdf(data);
  }

  Future<Uint8List> _generateDefaulterList() async {
    if (request.vouchers == null || request.vouchers!.isEmpty) {
      throw StateError('No defaulter groups provided for preview.');
    }
    const requiredKeys = ['branchName', 'branchAddress'];
    final missing = requiredKeys
        .where(
          (k) =>
              !request.extraParams.containsKey(k) ||
              request.extraParams[k] == null ||
              request.extraParams[k].toString().trim().isEmpty,
        )
        .toList();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing required params for defaulterList: ${missing.join(", ")}',
      );
    }
    final groups = request.vouchers!.cast<DefaulterClassGroup>();
    final summary =
        request.extraParams['summary'] as DefaulterListFilterSummary?;
    if (summary == null) {
      throw StateError('Missing summary in extraParams for defaulterList.');
    }
    return DefaulterListPdfGenerator.generate(
      groups: groups,
      summary: summary,
      branchName: request.extraParams['branchName'] as String,
      branchAddress: request.extraParams['branchAddress'] as String,
      branchPhone: request.extraParams['branchPhone'] as String?,
      branchPrincipal: request.extraParams['branchPrincipal'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final reportPreviewProvider = StateNotifierProvider.autoDispose
    .family<ReportPreviewNotifier, ReportPreviewState, ReportRequest>(
  (ref, request) => ReportPreviewNotifier(request),
);
