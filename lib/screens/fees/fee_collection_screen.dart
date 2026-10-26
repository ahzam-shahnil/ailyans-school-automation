import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/fee_collection_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/receipt_pdf_generator.dart' as rcp;
import '../../core/utils/defaulter_list_pdf_generator.dart';
import '../../models/fee_receipt_view.dart';

/// Production FeeCollectionScreen hosted within AppShell at route `/fees/receipts`.
/// Matches Behavior Spec §S19 (frmVoucharRecipt @ 0x0041c754) and locked design references:
/// - fees-receipts-v1-unpaid-loaded.png
/// - fees-receipts-v1-paid.png
/// - fees-receipts-v1-revoke-modal.png
class FeeCollectionScreen extends ConsumerStatefulWidget {
  const FeeCollectionScreen({super.key});

  @override
  ConsumerState<FeeCollectionScreen> createState() =>
      _FeeCollectionScreenState();
}

class _FeeCollectionScreenState extends ConsumerState<FeeCollectionScreen> {
  final TextEditingController _lookupController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final FocusNode _lookupFocusNode = FocusNode();

  final NumberFormat _currencyFormat = NumberFormat('#,##0');
  final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');

  static const Map<String, ({String label, String route})> _originConfig = {
    'leaving': (label: 'Back to School Leaving', route: '/students/leaving'),
    'ledger': (label: 'Back to Fee Ledger', route: '/fees/ledger'),
    'dashboard': (label: 'Back to Dashboard', route: '/dashboard'),
    'students': (label: 'Back to Students', route: '/students'),
    'vouchers': (label: 'Back to Voucher Generation', route: '/fees/vouchers'),
    'parameters': (label: 'Back to Fee Parameters', route: '/fees/parameters'),
  };

  String? _originScreen; // valid key from _originConfig | null

  @override
  void dispose() {
    _lookupController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    _lookupFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onLookup() async {
    final query = _lookupController.text.trim();
    if (query.isEmpty) return;
    await ref.read(feeCollectionProvider.notifier).lookupVoucher(query);
    if (!mounted) return;
    final receipt = ref.read(feeCollectionProvider).currentReceipt;
    if (receipt != null) {
      _amountController.text = ref
          .read(feeCollectionProvider)
          .amountTendered
          .toString();
      _remarksController.clear();
    }
  }

  Future<void> _onFilter(String filter) async {
    await ref
        .read(feeCollectionProvider.notifier)
        .lookupVoucherByFilter(filter);
    if (!mounted) return;
    final warning = ref.read(feeCollectionProvider).lookupError;
    if (warning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
          backgroundColor: AppColors.statusWarningBg,
        ),
      );
    } else {
      final receipt = ref.read(feeCollectionProvider).currentReceipt;
      if (receipt != null) {
        _lookupController.text = receipt.voucherMasId;
        _amountController.text = ref
            .read(feeCollectionProvider)
            .amountTendered
            .toString();
        _remarksController.clear();
      }
    }
  }

  Future<void> _onPostPayment() async {
    // Capture voucherMasId BEFORE postPayment() clears the state
    final settledVoucherId = ref
        .read(feeCollectionProvider)
        .currentReceipt
        ?.voucherMasId;

    final success = await ref
        .read(feeCollectionProvider.notifier)
        .postPayment();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment Posted Successfully'),
          backgroundColor: AppColors.statusSuccessBg,
        ),
      );
      _lookupController.clear();
      _amountController.clear();
      _remarksController.clear();
      _lookupFocusNode.requestFocus();

      // Auto-open receipt preview for the just-settled voucher
      if (settledVoucherId != null) {
        await _openReceiptPrint(settledVoucherId);
      }
    } else {
      final error = ref.read(feeCollectionProvider).postError;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.statusErrorBg,
          ),
        );
      }
    }
  }

  void _onClear() {
    ref.read(feeCollectionProvider.notifier).clearReceipt();
    _lookupController.clear();
    _amountController.clear();
    _remarksController.clear();
    _lookupFocusNode.requestFocus();
  }

  /// Opens the official 3-copy payment receipt preview.
  ///
  /// [explicitVoucherId] allows opening for a just-settled voucher even after
  /// the provider state is cleared (post-payment auto-print).
  Future<void> _openReceiptPrint([String? explicitVoucherId]) async {
    final targetVoucherId =
        explicitVoucherId ??
        ref.read(feeCollectionProvider).currentReceipt?.voucherMasId;
    if (targetVoucherId == null) return;

    // If opening from the manual button, check that the voucher is paid
    if (explicitVoucherId == null) {
      final receipt = ref.read(feeCollectionProvider).currentReceipt;
      if (receipt != null && !receipt.isFullyPaid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot print payment receipt -- payment not yet posted for this voucher',
            ),
          ),
        );
        return;
      }
    }

    final meta = ref.read(shellMetadataProvider).value;
    final branchName =
        meta?.branchName ?? "Ailyans's Higher Secondary School Mianwali";
    final branchAddress = meta?.branchAddress ?? 'Muslim Bazar Mianwali';

    final paymentMode = ref.read(feeCollectionProvider).paymentMode;
    final printData = await ref
        .read(feeCollectionProvider.notifier)
        .loadReceiptPrintData(targetVoucherId, paymentMode: paymentMode);

    if (!mounted) return;

    if (printData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load receipt data. Is the voucher paid?'),
        ),
      );
      return;
    }

    await rcp.showReceiptPrintPreviewDialog(
      context,
      receipts: [printData],
      branchName: branchName,
      branchAddress: branchAddress,
    );
  }

  @override
  void initState() {
    super.initState();
    final initialReceipt = ref.read(feeCollectionProvider).currentReceipt;
    if (initialReceipt != null) {
      _amountController.text = ref
          .read(feeCollectionProvider)
          .amountTendered
          .toString();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final uri = GoRouterState.of(context).uri;
        final studentId = uri.queryParameters['studentId'];
        final from = uri.queryParameters['from'];

        if (from != null && _originConfig.containsKey(from)) {
          setState(() {
            _originScreen = from;
          });
        }

        if (studentId != null && studentId.isNotEmpty) {
          _lookupController.text = studentId;
          await _onLookup();
        }
      } catch (_) {
        // Ignored when FeeCollectionScreen is rendered without GoRouter (e.g. in isolated component tests)
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feeCollectionProvider);
    final bankListAsync = ref.watch(bankListProvider);
    final receipt = state.currentReceipt;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (receipt != null && !receipt.isFullyPaid) {
            _onPostPayment();
          }
        },
        const SingleActivator(
          LogicalKeyboardKey.keyR,
          control: true,
          shift: true,
        ): () {
          if (receipt != null && receipt.isFullyPaid) {
            _openRevokeModal(context, receipt);
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _onClear();
        },
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Origin back affordance (context-aware back button)
              if (_originScreen != null &&
                  _originConfig.containsKey(_originScreen!)) ...[
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.go(_originConfig[_originScreen!]!.route),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: Text(_originConfig[_originScreen!]!.label),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandPrimary,
                        side: const BorderSide(color: AppColors.borderDefault),
                        backgroundColor: AppColors.surfaceRaised,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Top Search Bar (always visible)
              _buildSearchBar(state),

              // Search error banner if any
              if (state.lookupError != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    state.lookupError!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusErrorText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // 55 / 45 Workspace Row inside Expanded (prevents page-level scroll)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Pane (55% — Voucher Dossier)
                    Expanded(flex: 55, child: _buildLeftPane(receipt, state)),

                    const SizedBox(width: AppSpacing.md),

                    // Right Pane (45% — Payment Terminal)
                    Expanded(
                      flex: 45,
                      child: _buildRightPane(receipt, state, bankListAsync),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(FeeCollectionState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_scanner_outlined,
            color: AppColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: _lookupController,
              focusNode: _lookupFocusNode,
              style: AppTypography.monospace.copyWith(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Scan barcode or enter Voucher ID / Reg ID (e.g. 1710-4411)',
                hintStyle: AppTypography.monospace.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (_) => _onLookup(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              '[ENTER]',
              style: AppTypography.monospace.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => _onFilter('unpaid'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Load All Unpaid',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => _onFilter('paid'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Load All Paid', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () async {
              final notifier = ref.read(feeCollectionProvider.notifier);
              final buildData = await notifier.buildDefaulterList();
              final meta = ref.read(shellMetadataProvider).value;
              final branchName =
                  meta?.branchName ??
                  "Ailyans's Higher Secondary School Mianwali";
              final branchAddress =
                  meta?.branchAddress ?? 'Muslim Bazar Mianwali';
              final branchPhone = meta?.branchPhone ?? '03334449993';
              final branchPrincipal = meta?.branchPrincipal ?? 'Nasir ali';

              if (!mounted) return;
              await showDefaulterListPrintPreviewDialog(
                context,
                initialGroups: buildData.groups,
                initialSummary: buildData.summary,
                branchName: branchName,
                branchAddress: branchAddress,
                branchPhone: branchPhone,
                branchPrincipal: branchPrincipal,
              );
            },
            icon: const Icon(
              Icons.assignment_late_outlined,
              size: 16,
              color: AppColors.statusErrorText,
            ),
            label: const Text(
              'Defaulter Report',
              style: TextStyle(fontSize: 13, color: AppColors.statusErrorText),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 40),
              side: const BorderSide(color: AppColors.statusErrorBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => context.go('/fees/ledger'),
            icon: const Icon(Icons.assessment_outlined, size: 16),
            label: const Text(
              'View Full Ledger',
              style: TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: state.isLoadingLookup ? null : _onLookup,
            icon: state.isLoadingLookup
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search, size: 16),
            label: const Text('Load Voucher', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT PANE (55% — Voucher Dossier)
  // ---------------------------------------------------------------------------

  Widget _buildLeftPane(FeeReceiptView? receipt, FeeCollectionState state) {
    final notifier = ref.read(feeCollectionProvider.notifier);

    // View mode 1: Directory grid (no receipt selected, but rows loaded)
    if (receipt == null && state.directoryRows.isNotEmpty) {
      return _buildDirectoryGrid(state, notifier);
    }

    // View mode 2: Voucher dossier (receipt loaded)
    if (receipt != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: _buildReceiptDossier(receipt, state),
      );
    }

    // View mode 3: Empty state
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Scan a voucher to load details',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryGrid(
    FeeCollectionState state,
    FeeCollectionNotifier notifier,
  ) {
    final q = state.directorySearch.toLowerCase();
    final filtered = state.directoryRows.where((r) {
      if (q.isEmpty) return true;
      return r.studentName.toLowerCase().contains(q) ||
          r.stuRegId.toString().contains(q) ||
          r.voucherMasId.toLowerCase().contains(q);
    }).toList();
    final filterLabel = state.activeDirectoryFilter == 'paid'
        ? 'Paid'
        : 'Unpaid';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  '${filtered.length} $filterLabel Vouchers',
                  style: AppTypography.h2,
                ),
                const Spacer(),
                SizedBox(
                  width: 220,
                  height: 36,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 14),
                      hintText: 'Filter name / Reg ID...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    onChanged: notifier.setDirectorySearch,
                    style: AppTypography.body.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Sticky header
          Container(
            height: 36,
            color: AppColors.surfaceSubtle,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                _dirHeaderCell('Voucher ID', flex: 2),
                _dirHeaderCell('Reg ID', flex: 1),
                _dirHeaderCell('Student Name', flex: 3),
                _dirHeaderCell('Class-Sec', flex: 2),
                _dirHeaderCell('Month', flex: 2),
                _dirHeaderCell('Net Due (Rs)', flex: 2, alignRight: true),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      'Status',
                      style: AppTypography.label.copyWith(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Row list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      state.activeDirectoryFilter == 'paid'
                          ? 'No Paid Vouchar' // Verbatim [Sic]
                          : 'No unpaid vouchers found',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemExtent: 40,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final r = filtered[i];
                      return InkWell(
                        onTap: () =>
                            notifier.selectFromDirectory(r.voucherMasId),
                        child: Container(
                          color: i.isEven
                              ? AppColors.surfaceRaised
                              : AppColors.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  r.voucherMasId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 11,
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${r.stuRegId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  r.studentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  r.classSecDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  r.forMonth,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _currencyFormat.format(r.netPayable),
                                    maxLines: 1,
                                    style: AppTypography.monospace.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Center(
                                  child: _buildSmallStatusBadge(r.statusLabel),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dirHeaderCell(
    String text, {
    required int flex,
    bool alignRight = false,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildSmallStatusBadge(String status) {
    final Color bg;
    final Color fg;
    switch (status) {
      case 'PAID':
        bg = AppColors.statusSuccessBg;
        fg = AppColors.statusSuccessText;
      case 'OVERDUE':
        bg = AppColors.statusWarningBg;
        fg = AppColors.statusWarningText;
      default:
        bg = AppColors.surfaceSubtle;
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildReceiptDossier(
    FeeReceiptView receipt,
    FeeCollectionState state,
  ) {
    final notifier = ref.read(feeCollectionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back-to-list button (only when directory is populated)
        if (state.directoryRows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: notifier.clearCurrentReceiptOnly,
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: Text(
                    'All ${state.activeDirectoryFilter == 'paid' ? 'Paid' : 'Unpaid'} '
                    'Vouchers (${state.directoryRows.length})',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _openReceiptPrint,
                  icon: const Icon(Icons.print_outlined, size: 14),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ),
        // Header strip
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(receipt),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          receipt.studentName,
                          style: AppTypography.h2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          'Reg #${receipt.stuRegId}',
                          style: AppTypography.monospace.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${receipt.className ?? "Class"} - Sec ${receipt.sectionName ?? "A"}  •  Roll #${receipt.rollNo ?? "N/A"}  •  Father: ${receipt.fatherName}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Billing Month: ${receipt.forMonth}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                _buildStatusBadge(receipt),
              ],
            ),
          ],
        ),

        // Paid settlement strip if settled
        if (receipt.isFullyPaid) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.statusSuccessBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.statusSuccessBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.statusSuccessText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Settled on ${receipt.paidDate != null ? _dateFormat.format(receipt.paidDate!) : "Recorded Date"}  •  Receipt #${receipt.voucherMasId}  •  Official Receipt Issued',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusSuccessText,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sm),

        // Voucher metadata bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Voucher ID: ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: receipt.voucherMasId,
                        style: AppTypography.monospace.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Issue Date: ${receipt.issueDate != null ? _dateFormat.format(receipt.issueDate!) : "N/A"}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Due Date: ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: receipt.dueDate != null
                            ? _dateFormat.format(receipt.dueDate!)
                            : "N/A",
                        style: TextStyle(
                          color: receipt.isOverdue
                              ? AppColors.statusErrorText
                              : AppColors.textPrimary,
                          fontWeight: receipt.isOverdue
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                      if (receipt.isOverdue)
                        const TextSpan(
                          text: ' (Overdue)',
                          style: TextStyle(
                            color: AppColors.statusErrorText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Line items table (scrollable inside Expanded)
        Expanded(child: _buildLineItemsTable(receipt.lineItems)),

        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.borderDefault),
        const SizedBox(height: AppSpacing.sm),

        // Totals pinned at bottom
        _buildTotals(receipt),

        // Advance credit callout if available
        if (receipt.advanceBalance > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.statusSuccessBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.statusSuccessBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.savings_outlined,
                  size: 20,
                  color: AppColors.statusSuccessText,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Advance: Rs. ${_currencyFormat.format(receipt.advanceBalance)}',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusSuccessText,
                        ),
                      ),
                      Text(
                        'Surplus advance payments recorded in previous billing cycles.',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: state.useAdvanceCredit,
                  onChanged: (val) {
                    ref
                        .read(feeCollectionProvider.notifier)
                        .toggleUseAdvance(val ?? false);
                    _amountController.text =
                        ((val == true)
                                ? receipt.remainingAfterAdvance
                                : receipt.netPayable)
                            .toString();
                  },
                ),
                const Text(
                  'Apply',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(FeeReceiptView receipt) {
    if (receipt.photoPath != null && receipt.photoPath!.isNotEmpty) {
      final file = File(receipt.photoPath!);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitials(receipt),
          ),
        );
      }
    }
    return _buildInitials(receipt);
  }

  Widget _buildInitials(FeeReceiptView receipt) {
    final parts = receipt.studentName.trim().split(RegExp(r'\s+'));
    String initials = '';
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      initials += parts.first[0].toUpperCase();
    }
    if (parts.length > 1 && parts.last.isNotEmpty) {
      initials += parts.last[0].toUpperCase();
    }
    if (initials.isEmpty) initials = 'S';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.3),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTypography.h3.copyWith(
          color: AppColors.brandPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(FeeReceiptView receipt) {
    final String label;
    final Color bg;
    final Color fg;

    if (receipt.isFullyPaid) {
      label = '• PAID';
      bg = AppColors.statusSuccessBg;
      fg = AppColors.statusSuccessText;
    } else if (receipt.isOverdue) {
      label = '• OVERDUE';
      bg = AppColors.statusErrorBg;
      fg = AppColors.statusErrorText;
    } else {
      label = '• UNPAID';
      bg = AppColors.statusWarningBg;
      fg = AppColors.statusWarningText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLineItemsTable(List<FeeReceiptLineItem> lineItems) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Sticky header (36px)
          Container(
            height: 36,
            color: AppColors.surfaceSubtle,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'HEAD ID',
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'DESCRIPTION',
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'GROSS (RS)',
                    textAlign: TextAlign.right,
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'DISCOUNT (RS)',
                    textAlign: TextAlign.right,
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'NET (RS)',
                    textAlign: TextAlign.right,
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderDefault),

          // Scrollable item rows
          Expanded(
            child: ListView.builder(
              itemExtent: 32,
              itemCount: lineItems.length,
              itemBuilder: (context, index) {
                final item = lineItems[index];
                return Container(
                  color: index.isEven
                      ? AppColors.surfaceRaised
                      : AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          '#${item.feeParamId}',
                          style: AppTypography.monospace.copyWith(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          item.headName, // Preserve 'Arears' typo verbatim
                          style: AppTypography.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(item.amount),
                          textAlign: TextAlign.right,
                          style: AppTypography.monospace.copyWith(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(item.discount),
                          textAlign: TextAlign.right,
                          style: AppTypography.monospace.copyWith(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(item.net),
                          textAlign: TextAlign.right,
                          style: AppTypography.monospace.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(FeeReceiptView receipt) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SubTotal', style: AppTypography.bodySmall),
            Text(
              'Rs. ${_currencyFormat.format(receipt.subtotal)}',
              style: AppTypography.monospace,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Concession / Discount', style: AppTypography.bodySmall),
            Text(
              'Rs. ${_currencyFormat.format(receipt.discount)}',
              style: AppTypography.monospace,
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: AppColors.borderSubtle),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Net Payable', style: AppTypography.h3),
            Text(
              'Rs. ${_currencyFormat.format(receipt.netPayable)}',
              style: AppTypography.monospace.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT PANE (45% — Payment Terminal)
  // ---------------------------------------------------------------------------

  Widget _buildRightPane(
    FeeReceiptView? receipt,
    FeeCollectionState state,
    AsyncValue<List<BankRow>> bankListAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: receipt == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.point_of_sale_outlined,
                    size: 48,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Waiting for voucher selection',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Payment Settlement', style: AppTypography.h2),
                        const SizedBox(height: 2),
                        Text(
                          receipt.isFullyPaid
                              ? 'Voucher settled. Payment inputs are locked.'
                              : 'Record teller collection and deposit account',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Form for Unpaid / Overdue voucher
                        if (!receipt.isFullyPaid) ...[
                          _buildUnpaidPaymentForm(
                            receipt,
                            state,
                            bankListAsync,
                          ),
                        ],

                        // Summary & Revoke for Paid voucher
                        if (receipt.isFullyPaid) ...[
                          _buildPaidSummary(receipt),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUnpaidPaymentForm(
    FeeReceiptView receipt,
    FeeCollectionState state,
    AsyncValue<List<BankRow>> bankListAsync,
  ) {
    final effectivePayable = state.useAdvanceCredit
        ? receipt.remainingAfterAdvance
        : receipt.netPayable;
    final remainingBalance = (effectivePayable - state.amountTendered).clamp(
      0,
      effectivePayable,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Payment Date selector
        Text(
          'Payment Date *',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: state.paymentDate ?? now,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              ref.read(feeCollectionProvider.notifier).setPaymentDate(picked);
            }
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  _dateFormat.format(state.paymentDate ?? DateTime.now()),
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 2. Receiving Bank Dropdown
        Text(
          'Receiving Bank *',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        bankListAsync.when(
          data: (banks) {
            final currentBankId =
                banks.any((b) => b.bankInfoId == state.selectedBankId)
                ? state.selectedBankId
                : (banks.isNotEmpty ? banks.first.bankInfoId : null);
            return DropdownButtonFormField<int>(
              key: ValueKey(currentBankId),
              initialValue: currentBankId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                prefixIcon: const Icon(Icons.account_balance, size: 18),
              ),
              items: banks.map((b) {
                return DropdownMenuItem<int>(
                  value: b.bankInfoId,
                  child: Text(
                    b.displayName,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(feeCollectionProvider.notifier).setBankId(val);
                }
              },
            );
          },
          loading: () => const SizedBox(
            height: 40,
            child: LinearProgressIndicator(value: 0.5),
          ),
          error: (_, __) => const Text('Error loading banks'),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 3. Payment Mode Segmented Buttons
        Text(
          'Payment Mode *',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: ['Cash', 'Bank Slip', 'Cheque'].map((mode) {
            final isSelected = state.paymentMode == mode;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    ref
                        .read(feeCollectionProvider.notifier)
                        .setPaymentMode(mode);
                  },
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPrimary.withValues(alpha: 0.1)
                          : AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.borderDefault,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      mode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 4. Amount Tendered TextField
        Text(
          'Amount Tendered (Rs.) *',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: AppTypography.monospace.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            suffixText: 'PKR',
          ),
          onChanged: (val) {
            final parsed = int.tryParse(val) ?? 0;
            ref.read(feeCollectionProvider.notifier).setAmountTendered(parsed);
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Pre-filled with net payable${state.useAdvanceCredit ? " minus advance credit" : ""}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Settlement State callout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: remainingBalance == 0
                ? AppColors.statusSuccessBg
                : AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: remainingBalance == 0
                  ? AppColors.statusSuccessBorder
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Icon(
                remainingBalance == 0
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                size: 14,
                color: remainingBalance == 0
                    ? AppColors.statusSuccessText
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Remaining Balance Due: Rs. ${_currencyFormat.format(remainingBalance)}',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: remainingBalance == 0
                      ? AppColors.statusSuccessText
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 5. Remarks Field
        Text(
          'Remarks',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _remarksController,
          maxLines: 2,
          style: AppTypography.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Teller settlement remarks or transaction note...',
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onChanged: (val) {
            ref.read(feeCollectionProvider.notifier).setRemarks(val);
          },
        ),
        const SizedBox(height: AppSpacing.sm),

        // 6. SMS Checkbox
        Row(
          children: [
            Checkbox(
              value: state.sendSms,
              onChanged: (v) {
                ref.read(feeCollectionProvider.notifier).toggleSms(v ?? true);
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Send SMS payment confirmation',
                style: AppTypography.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // 7. Post Payment Button (Ctrl+Enter)
        ElevatedButton.icon(
          onPressed: state.isPosting ? null : _onPostPayment,
          icon: state.isPosting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long, size: 18),
          label: Text(
            state.isPosting ? 'Posting...' : 'Post Payment (Ctrl+Enter)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaidSummary(FeeReceiptView receipt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Settled callout banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.statusWarningBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.statusWarningBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppColors.statusWarningText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This voucher was settled on ${receipt.paidDate != null ? _dateFormat.format(receipt.paidDate!) : "record"}. Payment inputs are locked.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.statusWarningText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Read-only payment details
        Text(
          'PAYMENT COLLECTION DATE',
          style: AppTypography.label.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Text(
                receipt.paidDate != null
                    ? _dateFormat.format(receipt.paidDate!)
                    : 'Recorded Date',
                style: AppTypography.bodySmall,
              ),
              const Spacer(),
              const Icon(Icons.lock, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        Text(
          'RECEIVING BANK ACCOUNT',
          style: AppTypography.label.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Row(
            children: [
              Text(
                'Askari Bank — Ballo Khel Road',
                style: TextStyle(fontSize: 13),
              ),
              Spacer(),
              Icon(Icons.lock, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        Text(
          'AMOUNT TENDERED RECEIVED',
          style: AppTypography.label.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            'Rs. ${_currencyFormat.format(receipt.paidAmount)}',
            style: AppTypography.monospace.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.statusSuccessBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            'Remaining Balance Due: Rs. 0   [Fully Paid]',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.statusSuccessText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Disabled button indicating settlement
        ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.lock_outline, size: 18),
          label: const Text('Payment Already Posted & Settled'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Supervisory Revocation Box
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.statusErrorBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.statusErrorBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisory Actions',
                style: AppTypography.label.copyWith(
                  color: AppColors.statusErrorText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Revoke Paid Status requires supervisory password',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _openRevokeModal(context, receipt),
                icon: const Icon(
                  Icons.undo,
                  color: AppColors.statusErrorText,
                  size: 16,
                ),
                label: const Text(
                  'Revoke Paid Status',
                  style: TextStyle(
                    color: AppColors.statusErrorText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusErrorBorder),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REVOKE MODAL
  // ---------------------------------------------------------------------------

  Future<void> _openRevokeModal(
    BuildContext context,
    FeeReceiptView receipt,
  ) async {
    final passwordController = TextEditingController();
    String? modalError;
    bool isRevoking = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AppColors.borderDefault),
              ),
              child: SizedBox(
                width: 440,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.statusErrorBg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.statusErrorBorder,
                              ),
                            ),
                            child: const Icon(
                              Icons.security,
                              color: AppColors.statusErrorText,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enter Password ?', // Verbatim [Sic]
                                  style: AppTypography.h2,
                                ),
                                Text(
                                  'Supervisory Authorization Required',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Text(
                        'Revoking receipt for Voucher #${receipt.voucherMasId} (${receipt.studentName}). '
                        'This action rolls the ledger status back to UNPAID and cancels the cash journal entry.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Inline Error Banner if wrong password
                      if (modalError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.statusErrorBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.statusErrorBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.statusErrorText,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.statusErrorText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      Text(
                        'Enter Secret Password', // Verbatim
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        autofocus: true,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(
                              color: modalError != null
                                  ? AppColors.statusErrorText
                                  : AppColors.borderDefault,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(
                              color: modalError != null
                                  ? AppColors.statusErrorText
                                  : AppColors.borderDefault,
                            ),
                          ),
                        ),
                        onSubmitted: (_) async {
                          // Submit action
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Contact your administrator if you don't have this password.",
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ElevatedButton.icon(
                            onPressed: isRevoking
                                ? null
                                : () async {
                                    setModalState(() {
                                      isRevoking = true;
                                      modalError = null;
                                    });
                                    final entered = passwordController.text;
                                    final result = await ref
                                        .read(feeCollectionProvider.notifier)
                                        .revokePayment(entered);
                                    if (result == RevokeResult.wrongPassword) {
                                      setModalState(() {
                                        isRevoking = false;
                                        modalError = 'Wrong Man. Try Agnain.'; // Verbatim [Sic]
                                      });
                                    } else if (result == RevokeResult.success) {
                                      if (context.mounted) {
                                        Navigator.of(dialogContext).pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  ' Voucher Removed from Paid Sucessfully', // Verbatim [Sic]
                                                ),
                                              ),
                                            );
                                      }
                                    } else {
                                      setModalState(() {
                                        isRevoking = false;
                                        modalError = 'An error occurred during revocation.';
                                      });
                                    }
                                  },
                            icon: isRevoking
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_open, size: 16),
                            label: const Text('Authorize Revocation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusErrorText,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
