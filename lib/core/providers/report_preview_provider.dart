import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        return _generateFeeVoucher();
      case ReportType.feeReceipt:
        throw UnimplementedError(
          '${request.type.displayName} preview will be wired in a later run.',
        );
      case ReportType.biodata:
        throw UnimplementedError(
          '${request.type.displayName} preview will be wired in a later run.',
        );
      case ReportType.defaulterList:
        throw UnimplementedError(
          '${request.type.displayName} preview will be wired in a later run.',
        );
      case ReportType.attendanceRegister:
        throw UnimplementedError(
          '${request.type.displayName} preview will be wired in a later run.',
        );
    }
  }

  Future<Uint8List> _generateFeeVoucher() async {
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

    return ThreeCopyVouchersPdf.generate(
      vouchers: voucherList.cast<FeeReceiptView>(),
      branchName: request.extraParams['branchName'] as String,
      branchAddress: request.extraParams['branchAddress'] as String,
      bankName: request.extraParams['bankName'] as String,
      bankBranch: request.extraParams['bankBranch'] as String,
      bankAcctNo: request.extraParams['bankAcctNo'] as String,
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
