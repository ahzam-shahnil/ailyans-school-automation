import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/providers/clock_provider.dart';
import '../../core/providers/dashboard_metrics_provider.dart';
import '../../core/providers/fee_collection_provider.dart';
import '../../core/providers/fee_ledger_provider.dart';
import '../../core/providers/school_leaving_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/defaulter_list_pdf_generator.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/fee_receipt_view.dart';
import '../../widgets/mobile/mobile_status_pill.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

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
  String? _customBackRoute;

  /// G-9 Shot 9: collapses the mobile lookup card into a compact bar while a
  /// voucher is loaded for settlement (auto-collapsed when a voucher loads).
  bool _isMobileSearchExpanded = true;

  String _formatInstallmentDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return '—';
    try {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return _dateFormat.format(parsed);
      }
      final datePart = trimmed.split(' ').first;
      final parsedDatePart = DateTime.tryParse(datePart);
      if (parsedDatePart != null) {
        return _dateFormat.format(parsedDatePart);
      }
    } catch (_) {}
    return trimmed;
  }

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
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(feeLedgerProvider);
      ref.invalidate(shellMetadataProvider);
      ref.invalidate(schoolLeavingProvider);

      if (_originScreen == 'leaving') {
        final backRoute = _customBackRoute ?? '/students/leaving';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Payment posted. Return to School Leaving to issue SLC.',
            ),
            backgroundColor: AppColors.statusSuccessBg,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Back to School Leaving',
              textColor: AppColors.textPrimary,
              onPressed: () => context.go(backRoute),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Posted Successfully'),
            backgroundColor: AppColors.statusSuccessBg,
          ),
        );
      }
      _lookupController.clear();
      _amountController.clear();
      _remarksController.clear();
      _lookupFocusNode.requestFocus();

      // Auto-open receipt preview for the just-settled voucher (skip in leaving flow to preserve back action)
      if (settledVoucherId != null && _originScreen != 'leaving') {
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
        (meta?.branchName != null && meta!.branchName.trim().isNotEmpty)
        ? meta.branchName.trim()
        : '-';
    final branchAddress =
        (meta?.branchAddress != null && meta!.branchAddress.trim().isNotEmpty)
        ? meta.branchAddress.trim()
        : '-';

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

    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.feeReceipt,
        vouchers: [printData],
        extraParams: {'branchName': branchName, 'branchAddress': branchAddress},
      ),
    );
  }

  String? _lastParsedUri;

  void _parseRouteParams() {
    try {
      final uri = GoRouterState.of(context).uri;
      final uriStr = uri.toString();
      if (_lastParsedUri == uriStr) return;
      _lastParsedUri = uriStr;

      final voucherId = uri.queryParameters['voucherId'];
      final studentId = uri.queryParameters['studentId'];
      final from = uri.queryParameters['from'];

      if (from != null && from.isNotEmpty) {
        if (from.startsWith('/students/leaving') || from == 'leaving') {
          _originScreen = 'leaving';
          _customBackRoute = from.startsWith('/') ? from : '/students/leaving';
        } else if (_originConfig.containsKey(from)) {
          _originScreen = from;
          _customBackRoute = null;
        } else if (from.startsWith('/students/') || from.startsWith('/')) {
          _originScreen = 'students';
          _customBackRoute = from;
        } else {
          _originScreen = from;
          _customBackRoute = null;
        }
      }

      if (voucherId != null && voucherId.isNotEmpty) {
        if (_lookupController.text != voucherId) {
          _lookupController.text = voucherId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onLookup();
          });
        }
      } else if (studentId != null && studentId.isNotEmpty) {
        if (_lookupController.text != studentId) {
          _lookupController.text = studentId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onLookup();
          });
        }
      }
    } catch (_) {
      // Ignored when FeeCollectionScreen is rendered without GoRouter (e.g. in isolated component tests)
    }
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parseRouteParams();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(feeCollectionProvider.select((s) => s.amountTendered), (
      prev,
      next,
    ) {
      final currentVal = int.tryParse(_amountController.text.trim());
      if (currentVal != next) {
        _amountController.text = next.toString();
      }
    });
    ref.listen<String?>(
      feeCollectionProvider.select((s) => s.currentReceipt?.voucherMasId),
      (prev, next) {
        if (next != null) {
          final amt = ref.read(feeCollectionProvider).amountTendered;
          _amountController.text = amt.toString();
          // G-9 Shot 9: auto-collapse the lookup card once a voucher loads so
          // the receipt dossier gets the whole viewport.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isMobileSearchExpanded = false);
          });
        } else if (prev != null) {
          // Back to directory mode: restore the full lookup card.
          _isMobileSearchExpanded = true;
        }
      },
    );

    final state = ref.watch(feeCollectionProvider);
    final bankListAsync = ref.watch(bankListProvider);
    final receipt = state.currentReceipt;

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileScaffold(state, bankListAsync, receipt);
    }

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
          if (receipt != null &&
              (receipt.isFullyPaid || receipt.paidAmount > 0)) {
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
          // Shot 1e: on short viewports (< 820px height) the entire screen
          // scrolls as one page instead of locking the workspace into a
          // fixed-height Expanded.
          child: _fixedWorkspace(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _desktopWorkspaceChildren(
                    state,
                    bankListAsync,
                    receipt,
                    fixed: true,
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _desktopWorkspaceChildren(
                      state,
                      bankListAsync,
                      receipt,
                      fixed: false,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// Shot 1e: shared children for the fixed desktop workspace and the
  /// single-page scrolling layout (< 820px tall viewports).
  List<Widget> _desktopWorkspaceChildren(
    FeeCollectionState state,
    AsyncValue<List<BankRow>> bankListAsync,
    FeeReceiptView? receipt, {
    required bool fixed,
  }) {
    return [
      // Origin back affordance (context-aware back button)
      if (_originScreen != null &&
          _originConfig.containsKey(_originScreen!)) ...[
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go(
                _customBackRoute ?? _originConfig[_originScreen!]!.route,
              ),
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

      // 55 / 45 Workspace Row: Expanded (fixed) or natural height (scroll).
      if (fixed)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Pane (55% - Voucher Dossier)
              Expanded(flex: 55, child: _buildLeftPane(receipt, state)),
              const SizedBox(width: AppSpacing.md),
              // Right Pane (45% - Payment Terminal)
              Expanded(
                flex: 45,
                child: _buildRightPane(receipt, state, bankListAsync),
              ),
            ],
          ),
        )
      else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 55, child: _buildLeftPane(receipt, state)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 45,
              child: _buildRightPane(receipt, state, bankListAsync),
            ),
          ],
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------------

  /// Shot 1e: fixed 55/45 workspace only on wide AND tall desktop viewports
  /// (>= 1000px wide, >= 820px tall). Below either threshold the whole page
  /// scrolls as a single surface — no inner scroll-lock anywhere.
  bool _fixedWorkspace(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= 1000 && size.height >= 820;
  }

  Widget _buildSearchBar(FeeCollectionState state) {
    // Shot 1e: the scan field gets the institutional 1.5px #94A3B8 resting /
    // 2.0px #2563EB focused border (focus-driven via the lookup FocusNode).
    return AnimatedBuilder(
      animation: _lookupFocusNode,
      builder: (innerContext, _) {
        final focused = _lookupFocusNode.hasFocus;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: focused
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8),
              width: focused ? 2.0 : 1.5,
            ),
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
                child: const Text(
                  'Load All Paid',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () async {
                  final notifier = ref.read(feeCollectionProvider.notifier);
                  final buildData = await notifier.buildDefaulterList();
                  final meta = ref.read(shellMetadataProvider).value;
                  final branchName =
                      (meta?.branchName != null &&
                          meta!.branchName.trim().isNotEmpty)
                      ? meta.branchName.trim()
                      : '-';
                  final branchAddress =
                      (meta?.branchAddress != null &&
                          meta!.branchAddress.trim().isNotEmpty)
                      ? meta.branchAddress.trim()
                      : '-';
                  final branchPhone = meta?.branchPhone ?? '03334449993';
                  final branchPrincipal = meta?.branchPrincipal ?? '-';

                  if (!mounted) return;
                  await ReportPreviewModal.show(
                    context,
                    request: ReportRequest(
                      type: ReportType.defaulterList,
                      vouchers: buildData.groups,
                      extraParams: {
                        'summary': buildData.summary,
                        'branchName': branchName,
                        'branchAddress': branchAddress,
                        'branchPhone': branchPhone,
                        'branchPrincipal': branchPrincipal,
                      },
                    ),
                    headerControls: DefaulterFilterControls(
                      initialClassId: null,
                      initialMonth: null,
                      onFiltersChanged: ({int? classId, String? month}) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Close preview and change filters on the screen to update the PDF.',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                icon: const Icon(
                  Icons.assignment_late_outlined,
                  size: 16,
                  color: AppColors.statusErrorText,
                ),
                label: const Text(
                  'Defaulter Report',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.statusErrorText,
                  ),
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
                label: const Text(
                  'Load Voucher',
                  style: TextStyle(fontSize: 13),
                ),
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
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE SCAFFOLD & COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildMobileLeftPane(
    FeeReceiptView? receipt,
    FeeCollectionState state,
  ) {
    if (receipt != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: _buildReceiptDossierMobile(receipt, state),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Scan a voucher to load details',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(
    FeeCollectionState state,
    AsyncValue<List<BankRow>> bankListAsync,
    FeeReceiptView? receipt,
  ) {
    final notifier = ref.read(feeCollectionProvider.notifier);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (receipt != null && !receipt.isFullyPaid) _onPostPayment();
        },
        const SingleActivator(
          LogicalKeyboardKey.keyR,
          control: true,
          shift: true,
        ): () {
          if (receipt != null &&
              (receipt.isFullyPaid || receipt.paidAmount > 0)) {
            _openRevokeModal(context, receipt);
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): _onClear,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.surfaceCanvas,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // G-9 Shot 9: one unified whole-page scroll — no fixed top
                // chrome and no inner scroll trap. Every section scrolls away.
                // A generous scroll cache pre-builds slivers beyond the fold
                // so the settlement form is hot the moment a voucher loads.
                Expanded(
                  child: CustomScrollView(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(2048),
                    slivers: [
                      if (_originScreen != null &&
                          _originConfig.containsKey(_originScreen!))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                              0,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => context.go(
                                  _customBackRoute ??
                                      _originConfig[_originScreen!]!.route,
                                ),
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: Text(
                                  _originConfig[_originScreen!]!.label,
                                ),
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: _buildMobileSearchBar(state, receipt),
                        ),
                      ),
                      if (state.lookupError != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              state.lookupError!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.statusErrorText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      // Directory mode: header + lazily virtualized voucher
                      // cards directly inside the page scroll view.
                      if (receipt == null &&
                          state.directoryRows.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.xs,
                            ),
                            child: _buildMobileDirectoryHeader(state, notifier),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          sliver: SliverList.builder(
                            itemCount: _filteredMobileDirectoryRows(state)
                                .length,
                            itemBuilder: (context, index) =>
                                _buildMobileDirectoryCard(
                                  _filteredMobileDirectoryRows(state)[index],
                                  notifier,
                                ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: _buildMobileRightPane(
                              receipt,
                              state,
                              bankListAsync,
                            ),
                          ),
                        ),
                      ],
                      // Loaded voucher mode: dossier + settlement form in a
                      // single adapter so both build while the section is in
                      // view; they scroll away together as one whole page.
                      if (receipt != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildMobileLeftPane(receipt, state),
                                const SizedBox(height: AppSpacing.md),
                                _buildMobileRightPane(
                                  receipt,
                                  state,
                                  bankListAsync,
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Idle mode: scan prompt + waiting card.
                      if (receipt == null && state.directoryRows.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildMobileLeftPane(receipt, state),
                                const SizedBox(height: AppSpacing.md),
                                _buildMobileRightPane(
                                  receipt,
                                  state,
                                  bankListAsync,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Pinned bottom teller action bar while a voucher is open.
                if (receipt != null && !receipt.isFullyPaid)
                  _buildMobileTellerBar(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// G-9 Shot 9: pinned settlement action bar so the post-payment CTA never
  /// requires scrolling to reach, even at the bottom of the dossier.
  Widget _buildMobileTellerBar(FeeCollectionState state) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: ElevatedButton.icon(
        onPressed: state.isPosting ? null : _onPostPayment,
        icon: state.isPosting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnPrimary,
                ),
              )
            : const Icon(Icons.receipt_long, size: 18),
        label: Text(
          state.isPosting ? 'Posting...' : 'Post Payment (Ctrl+Enter)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentFees,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  Future<void> _openDefaulterReport() async {
    final notifier = ref.read(feeCollectionProvider.notifier);
    final buildData = await notifier.buildDefaulterList();
    final meta = ref.read(shellMetadataProvider).value;
    final branchName =
        (meta?.branchName != null && meta!.branchName.trim().isNotEmpty)
        ? meta.branchName.trim()
        : '-';
    final branchAddress =
        (meta?.branchAddress != null && meta!.branchAddress.trim().isNotEmpty)
        ? meta.branchAddress.trim()
        : '-';
    final branchPhone = meta?.branchPhone ?? '03334449993';
    final branchPrincipal = meta?.branchPrincipal ?? '-';

    if (!mounted) return;
    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.defaulterList,
        vouchers: buildData.groups,
        extraParams: {
          'summary': buildData.summary,
          'branchName': branchName,
          'branchAddress': branchAddress,
          'branchPhone': branchPhone,
          'branchPrincipal': branchPrincipal,
        },
      ),
      headerControls: DefaulterFilterControls(
        initialClassId: null,
        initialMonth: null,
        onFiltersChanged: ({int? classId, String? month}) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Close preview and change filters on the screen to update the PDF.',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileSearchBar(
    FeeCollectionState state,
    FeeReceiptView? receipt,
  ) {
    // G-9 Shot 9: while a voucher is loaded, collapse the lookup card into a
    // compact bar so the receipt owns the screen; `[Search / Switch]` expands.
    if (receipt != null && !_isMobileSearchExpanded) {
      return _buildMobileCollapsedLookupBar(receipt);
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                    hintText: 'Scan barcode or enter Voucher ID / Reg ID',
                    hintStyle: AppTypography.monospace.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _onLookup(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                onPressed: () => _onFilter('unpaid'),
                child: const Text(
                  'Load All Unpaid',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton(
                onPressed: () => _onFilter('paid'),
                child: const Text(
                  'Load All Paid',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openDefaulterReport,
                icon: const Icon(
                  Icons.assignment_late_outlined,
                  size: 16,
                  color: AppColors.statusErrorText,
                ),
                label: const Text(
                  'Defaulter Report',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.statusErrorText,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/fees/ledger'),
                icon: const Icon(Icons.assessment_outlined, size: 16),
                label: const Text(
                  'View Ledger',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: state.isLoadingLookup ? null : _onLookup,
              icon: state.isLoadingLookup
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 16),
              label: const Text('Load Voucher'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// G-9 Shot 9: compact 48px collapsed lookup bar shown while a voucher is
  /// open for settlement; tapping [Search / Switch] re-expands the full card.
  Widget _buildMobileCollapsedLookupBar(FeeReceiptView receipt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_scanner,
            size: 18,
            color: AppColors.accentFees,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Voucher #${receipt.voucherMasId}',
              style: AppTypography.monospace.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isMobileSearchExpanded = true),
            icon: const Icon(Icons.search, size: 16),
            label: const Text(
              'Search / Switch',
              style: TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
            ),
          ),
        ],
      ),
    );
  }

  List<FeeReceiptSummaryRow> _filteredMobileDirectoryRows(
    FeeCollectionState state,
  ) {
    final q = state.directorySearch.toLowerCase();
    if (q.isEmpty) return state.directoryRows;
    return state.directoryRows.where((r) {
      return r.studentName.toLowerCase().contains(q) ||
          r.stuRegId.toString().contains(q) ||
          r.voucherMasId.toLowerCase().contains(q);
    }).toList();
  }

  /// G-9 Shot 9: directory header (count + full-width filter field). The
  /// voucher cards render in a `SliverList.builder` directly in the page.
  Widget _buildMobileDirectoryHeader(
    FeeCollectionState state,
    FeeCollectionNotifier notifier,
  ) {
    final filtered = _filteredMobileDirectoryRows(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${filtered.length} ${state.activeDirectoryFilter == 'paid' ? 'Paid' : 'Unpaid'} Vouchers',
                style: AppTypography.h2,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 16),
              hintText: 'Filter name / Reg ID...',
            ),
            onChanged: notifier.setDirectorySearch,
            style: AppTypography.body.copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              state.activeDirectoryFilter == 'paid'
                  ? 'No Paid Vouchar' // VERBATIM [Sic]
                  : 'No unpaid vouchers found',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  MobileStatusVariant _mapFeeStatusVariant(String status) {
    final upper = status.toUpperCase();
    if (upper.contains('PAID') && !upper.contains('UNPAID')) {
      return MobileStatusVariant.success;
    } else if (upper.contains('OVERDUE')) {
      return MobileStatusVariant.error;
    } else if (upper.contains('UNPAID') || upper.contains('PARTIAL')) {
      return MobileStatusVariant.warning;
    }
    return MobileStatusVariant.neutral;
  }

  Widget _buildMobileDirectoryCard(
    FeeReceiptSummaryRow r,
    FeeCollectionNotifier notifier,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: InkWell(
        onTap: () => notifier.selectFromDirectory(r.voucherMasId),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm + 4,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.voucherMasId,
                          style: AppTypography.monospace.copyWith(
                            fontSize: 12,
                            color: AppColors.accentFees,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      MobileStatusPill(
                        label: r.statusLabel,
                        variant: _mapFeeStatusVariant(r.statusLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.studentName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reg ${r.stuRegId} · ${r.classSecDisplay} · ${r.forMonth}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Net Due:',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Rs. ${_currencyFormat.format(r.netPayable)}',
                        style: AppTypography.monospace.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3.5,
              child: Container(color: AppColors.accentFees),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptDossierMobile(
    FeeReceiptView receipt,
    FeeCollectionState state,
  ) {
    final notifier = ref.read(feeCollectionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // G-9 Shot 9: compact 1-row action strip (back to list + print).
        Row(
          children: [
            if (state.directoryRows.isNotEmpty) ...[
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: notifier.clearCurrentReceiptOnly,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text(
                      'All ${state.activeDirectoryFilter == 'paid' ? 'Paid' : 'Unpaid'} '
                      'Vouchers (${state.directoryRows.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _openReceiptPrint,
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
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
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                'Billing Month: ${receipt.forMonth}',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildStatusBadge(receipt),
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

        // Partially Paid settlement strip
        if (receipt.isPartiallyPaid) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.statusWarningBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timelapse,
                  size: 16,
                  color: AppColors.statusWarningText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PARTIALLY PAID (Paid: Rs. ${_currencyFormat.format(receipt.paidAmount)} | Due: Rs. ${_currencyFormat.format(receipt.remainingBalance)})',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusWarningText,
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

        // Voucher metadata well (G-9 Shot 9: 2-row layout, zero truncation)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Voucher #${receipt.voucherMasId}',
                      style: AppTypography.monospace.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentFees,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'For Month: ${receipt.forMonth}',
                      maxLines: 1,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Issue: ${receipt.issueDate != null ? _dateFormat.format(receipt.issueDate!) : "N/A"}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: 'Due: ',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: receipt.dueDate != null
                                ? _dateFormat.format(receipt.dueDate!)
                                : "N/A",
                            style: TextStyle(
                              fontSize: 12,
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
                                fontSize: 12,
                                color: AppColors.statusErrorText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Line items list (mobile unrolled, no vertical Expanded)
        _buildMobileLineItemsList(receipt.lineItems),

        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.borderDefault),
        const SizedBox(height: AppSpacing.sm),

        // Totals pinned at bottom
        _buildMobileTotals(receipt),

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

  Widget _buildMobileLineItemsList(List<FeeReceiptLineItem> lineItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            'Line Items (${lineItems.length})',
            style: AppTypography.h3,
          ),
        ),
        ...lineItems.map(_buildMobileLineItemRow),
      ],
    );
  }

  Widget _buildMobileLineItemRow(FeeReceiptLineItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '#${item.feeParamId}',
                style: AppTypography.monospace.copyWith(
                  fontSize: 11,
                  color: AppColors.accentFees,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  item.headName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ),
              Text(
                'Rs. ${_currencyFormat.format(item.net)}',
                style: AppTypography.monospace.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Gross: ${_currencyFormat.format(item.amount)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Disc: ${_currencyFormat.format(item.discount)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTotals(FeeReceiptView receipt) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('SubTotal', style: AppTypography.bodySmall),
            ),
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
            const Expanded(
              child: Text(
                'Total Concession / Discount',
                style: AppTypography.bodySmall,
              ),
            ),
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
            const Expanded(child: Text('Net Payable', style: AppTypography.h3)),
            Text(
              'Rs. ${_currencyFormat.format(receipt.netPayable)}',
              style: AppTypography.monospace.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (receipt.paidAmount > 0) ...[
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Amount Paid So Far',
                  style: AppTypography.bodySmall,
                ),
              ),
              Text(
                'Rs. ${_currencyFormat.format(receipt.paidAmount)}',
                style: AppTypography.monospace.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusSuccessText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Remaining Balance Due',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Rs. ${_currencyFormat.format(receipt.remainingBalance)}',
                style: AppTypography.monospace.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: receipt.remainingBalance > 0
                      ? AppColors.statusWarningText
                      : AppColors.statusSuccessText,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMobileRightPane(
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
                const Text('Payment Settlement', style: AppTypography.h2),
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
                  _buildMobilePaymentForm(receipt, state, bankListAsync),
                ],

                // Summary & Revoke for Paid voucher
                if (receipt.isFullyPaid) ...[_buildPaidSummary(receipt)],
              ],
            ),
    );
  }

  Widget _buildMobilePaymentForm(
    FeeReceiptView receipt,
    FeeCollectionState state,
    AsyncValue<List<BankRow>> bankListAsync,
  ) {
    final effectivePayable = state.useAdvanceCredit
        ? receipt.remainingAfterAdvance
        : receipt.remainingBalance;
    final remainingBalance = (effectivePayable - state.amountTendered).clamp(
      0,
      effectivePayable,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Net Due Stitch Summary Banner
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accentFeesSoftBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.accentFees.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Due:',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentFees,
                ),
              ),
              Text(
                'Rs. ${_currencyFormat.format(effectivePayable)}',
                style: AppTypography.monospace.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentFees,
                ),
              ),
            ],
          ),
        ),
        // Partially Paid banner inside form
        if (receipt.isPartiallyPaid) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.statusWarningBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.timelapse,
                      size: 16,
                      color: AppColors.statusWarningText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PARTIALLY PAID (Paid: Rs. ${_currencyFormat.format(receipt.paidAmount)} | Due: Rs. ${_currencyFormat.format(receipt.remainingBalance)})',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.statusWarningText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Remaining Balance Due: Rs. ${_currencyFormat.format(receipt.remainingBalance)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.statusWarningText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openRevokeModal(context, receipt),
                  icon: const Icon(
                    Icons.undo,
                    color: AppColors.statusErrorText,
                    size: 14,
                  ),
                  label: const Text(
                    'Revoke Paid Status',
                    style: TextStyle(
                      color: AppColors.statusErrorText,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.statusErrorBorder),
                    minimumSize: const Size.fromHeight(34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 1. Payment Date selector
        Text(
          'Payment Date *',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final now = ref.read(clockProvider)();
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
                Expanded(
                  child: Text(
                    _dateFormat.format(
                      state.paymentDate ?? ref.read(clockProvider)(),
                    ),
                    style: AppTypography.bodySmall,
                  ),
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
          receipt.isPartiallyPaid
              ? 'Pre-filled with remaining balance due: Rs. ${_currencyFormat.format(receipt.remainingBalance)}'
              : 'Pre-filled with net payable${state.useAdvanceCredit ? " minus advance credit" : ""}',
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
              Expanded(
                child: Text(
                  'Balance After This Payment: Rs. ${_currencyFormat.format(remainingBalance)}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: remainingBalance == 0
                        ? AppColors.statusSuccessText
                        : AppColors.textSecondary,
                  ),
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
            const Expanded(
              child: Text(
                'Send SMS payment confirmation',
                style: AppTypography.bodySmall,
              ),
            ),
          ],
        ),
        // G-9 Shot 9: Post Payment CTA moved to the pinned bottom teller bar.
      ],
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

    // View mode 2: Voucher dossier (receipt loaded) — 38px Oxford Blue
    // institutional band (Shot 1e) with the body scrolling inside the card.
    if (receipt != null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderDefault),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVoucherDossierBand(),
            if (_fixedWorkspace(context))
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildReceiptDossier(receipt, state),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _buildReceiptDossier(receipt, state),
              ),
          ],
        ),
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

  /// Shot 1e: 38px Oxford Blue header band for the voucher dossier card.
  /// Shot 2b: confirmation dialog + permanent voucher deletion (payments,
  /// details, master) directly from the Voucher Dossier header.
  Future<void> _confirmDeleteVoucher(FeeReceiptView receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Voucher #${receipt.voucherMasId}?'),
        content: const Text(
          'This will permanently remove the voucher and any recorded fee transactions for it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusErrorText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Voucher'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = await DatabaseService.instance.database;
    try {
      await db.transaction((txn) async {
        // 1. Recorded payments for this voucher.
        await txn.delete(
          'FeeTransaction',
          where: 'VoucharNo = ?',
          whereArgs: [receipt.voucherMasId],
        );
        // 2. Fee line items.
        await txn.delete(
          'VoucharDet',
          where: 'VoucharMasID = ?',
          whereArgs: [receipt.voucherMasId],
        );
        // 3. Voucher master. AFTER DELETE triggers (Migration 009) capture
        //    sync tombstones automatically.
        await txn.delete(
          'VoucharMas',
          where: 'VoucherMasID = ?',
          whereArgs: [receipt.voucherMasId],
        );
      });
    } catch (e) {
      debugPrint('Delete voucher failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete voucher: $e'),
          backgroundColor: AppColors.statusErrorBg,
        ),
      );
      return;
    }
    if (!mounted) return;

    ref.invalidate(dashboardMetricsProvider);
    final notifier = ref.read(feeCollectionProvider.notifier);
    await notifier.lookupVoucherByFilter(
      ref.read(feeCollectionProvider).activeDirectoryFilter ?? 'unpaid',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voucher #${receipt.voucherMasId} deleted.'),
        backgroundColor: AppColors.statusSuccessBg,
      ),
    );
  }

  Widget _buildVoucherDossierBand() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E3A8A), width: 2.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 16,
            color: Color(0xFF1E3A8A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'VOUCHER DOSSIER',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
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
    final fixed = _fixedWorkspace(context);

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
          // Row list — Expanded inside the fixed workspace; natural height
          // (page scroll) on short viewports (Shot 1e).
          if (fixed)
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
                  : _dirRowList(filtered, notifier),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  state.activeDirectoryFilter == 'paid'
                      ? 'No Paid Vouchar' // Verbatim [Sic]
                      : 'No unpaid vouchers found',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else
            _dirRowList(filtered, notifier),
        ],
      ),
    );
  }

  /// Shot 1e: directory rows sized naturally when the page scrolls as a
  /// single surface (short viewports).
  Widget _dirRowList(
    List<FeeReceiptSummaryRow> filtered,
    FeeCollectionNotifier notifier,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemExtent: 40,
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final r = filtered[i];
        return InkWell(
          onTap: () => notifier.selectFromDirectory(r.voucherMasId),
          child: Container(
            color: i.isEven ? AppColors.surfaceRaised : AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                    style: AppTypography.monospace.copyWith(fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    r.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    r.classSecDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    r.forMonth,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(fontSize: 12),
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
                  child: Center(child: _buildSmallStatusBadge(r.statusLabel)),
                ),
              ],
            ),
          ),
        );
      },
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
                // Shot 2b: crimson outlined Delete Voucher action with a
                // confirmation dialog, right next to Print.
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: 'Delete Voucher',
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteVoucher(receipt),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusErrorText,
                      side: const BorderSide(
                        color: AppColors.statusErrorBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
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

        // Partially Paid settlement strip
        if (receipt.isPartiallyPaid) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.statusWarningBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timelapse,
                  size: 16,
                  color: AppColors.statusWarningText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PARTIALLY PAID (Paid: Rs. ${_currencyFormat.format(receipt.paidAmount)} | Due: Rs. ${_currencyFormat.format(receipt.remainingBalance)})',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusWarningText,
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

        // Line items table — sized naturally on desktop (Shot 1e removes
        // the 180px dead void below short fee-head lists); scrollable inside
        // Expanded only on the mobile stacked layout.
        if (ResponsiveBreakpoints.isMobile(context))
          Expanded(child: _buildLineItemsTable(receipt.lineItems))
        else
          _buildLineItemsTable(receipt.lineItems),

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
    } else if (receipt.isPartiallyPaid) {
      label = '• PARTIALLY PAID';
      bg = AppColors.statusWarningBg;
      fg = AppColors.statusWarningText;
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
    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileLineItemsList(lineItems);
    }
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

          // Shot 1e: size the fee-head rows naturally on desktop so
          // SubTotal / Net Payable / installment history sit directly below
          // them (kills the dead void under short lists).
          ListView.builder(
            shrinkWrap: !ResponsiveBreakpoints.isMobile(context),
            physics: ResponsiveBreakpoints.isMobile(context)
                ? null
                : const NeverScrollableScrollPhysics(),
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
            const Text('SubTotal', style: AppTypography.bodySmall),
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
            const Text(
              'Total Concession / Discount',
              style: AppTypography.bodySmall,
            ),
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
            const Text('Net Payable', style: AppTypography.h3),
            Text(
              'Rs. ${_currencyFormat.format(receipt.netPayable)}',
              style: AppTypography.monospace.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (receipt.paidAmount > 0) ...[
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Amount Paid So Far', style: AppTypography.bodySmall),
              Text(
                'Rs. ${_currencyFormat.format(receipt.paidAmount)}',
                style: AppTypography.monospace.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusSuccessText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining Balance Due',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Rs. ${_currencyFormat.format(receipt.remainingBalance)}',
                style: AppTypography.monospace.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: receipt.remainingBalance > 0
                      ? AppColors.statusWarningText
                      : AppColors.statusSuccessText,
                ),
              ),
            ],
          ),
        ],
        if (receipt.paymentHistory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    'PAYMENT INSTALLMENT HISTORY (${receipt.paymentHistory.length})',
                    style: AppTypography.label.copyWith(fontSize: 10),
                  ),
                ),
                ...receipt.paymentHistory.map((inst) {
                  final bankPart =
                      (inst.bankName != null && inst.bankName!.isNotEmpty)
                      ? ' - ${inst.bankName}'
                      : '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Receipt #${inst.feeTransId} (${_formatInstallmentDate(inst.submissionDate)})$bankPart',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Rs. ${_currencyFormat.format(inst.paidAmount)}',
                          style: AppTypography.monospace.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
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
    final fixed = _fixedWorkspace(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
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
                // Shot 1e: 38px Forest Emerald institutional band.
                _buildSettlementBand(),
                if (fixed)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
              ],
            ),
    );
  }

  /// Shot 1e: 38px Forest Emerald header band with the numbered settlement
  /// badge for the Payment Terminal card.
  Widget _buildSettlementBand() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFECFDF5),
        border: Border(
          bottom: BorderSide(color: Color(0xFF047857), width: 2.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF047857),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '2',
              style: AppTypography.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Payment Settlement',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF064E3B),
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
        : receipt.remainingBalance;
    final remainingBalance = (effectivePayable - state.amountTendered).clamp(
      0,
      effectivePayable,
    );
    final fixed = _fixedWorkspace(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Partially Paid banner inside form
        if (receipt.isPartiallyPaid) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.statusWarningBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.timelapse,
                      size: 16,
                      color: AppColors.statusWarningText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PARTIALLY PAID (Paid: Rs. ${_currencyFormat.format(receipt.paidAmount)} | Due: Rs. ${_currencyFormat.format(receipt.remainingBalance)})',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.statusWarningText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Remaining Balance Due: Rs. ${_currencyFormat.format(receipt.remainingBalance)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.statusWarningText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openRevokeModal(context, receipt),
                  icon: const Icon(
                    Icons.undo,
                    color: AppColors.statusErrorText,
                    size: 14,
                  ),
                  label: const Text(
                    'Revoke Paid Status',
                    style: TextStyle(
                      color: AppColors.statusErrorText,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.statusErrorBorder),
                    minimumSize: const Size.fromHeight(34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 1 + 2. Payment Date & Receiving Bank — side-by-side on desktop
        // (Shot 1e), stacked on tablet/mobile.
        if (fixed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPaymentDateSelector(state)),
              const SizedBox(width: 12),
              Expanded(child: _buildBankSelector(state, bankListAsync)),
            ],
          )
        else ...[
          _buildPaymentDateSelector(state),
          const SizedBox(height: AppSpacing.sm),
          _buildBankSelector(state, bankListAsync),
          const SizedBox(height: AppSpacing.sm),
        ],

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
        SizedBox(height: fixed ? 10.0 : AppSpacing.sm),

        // 4. Amount Tendered + live balance badge — side-by-side on desktop.
        if (fixed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: _buildAmountTenderedSection(receipt, state),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildBalanceCallout(remainingBalance)),
            ],
          )
        else ...[
          _buildAmountTenderedSection(receipt, state),
          const SizedBox(height: AppSpacing.xs),
          _buildBalanceCallout(remainingBalance),
          const SizedBox(height: AppSpacing.sm),
        ],

        // 5 + 6. Remarks with the SMS confirmation toggle inline on desktop.
        if (fixed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildRemarksField()),
              const SizedBox(width: 10),
              SizedBox(width: 210, child: _buildSmsToggle(state)),
            ],
          )
        else ...[
          _buildRemarksField(),
          const SizedBox(height: AppSpacing.sm),
          _buildSmsToggle(state),
          const SizedBox(height: AppSpacing.md),
        ],

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

  // Shot 1e: 1.5px #94A3B8 resting / 2.0px #2563EB focused input borders,
  // scoped to this screen's fields (global InputDecorationTheme untouched).
  static const Color _fcInputBorderRest = Color(0xFF94A3B8);
  static const Color _fcInputBorderFocus = Color(0xFF2563EB);

  OutlineInputBorder _fcOutlineBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  InputDecoration _fcFieldDecoration({
    String? hintText,
    TextStyle? hintStyle,
    String? suffixText,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: hintText,
      hintStyle: hintStyle,
      suffixText: suffixText,
      contentPadding: contentPadding,
      border: _fcOutlineBorder(_fcInputBorderRest, 1.5),
      enabledBorder: _fcOutlineBorder(_fcInputBorderRest, 1.5),
      focusedBorder: _fcOutlineBorder(_fcInputBorderFocus, 2.0),
    );
  }

  /// 1. Payment Date selector (label + field).
  Widget _buildPaymentDateSelector(FeeCollectionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Date *',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final now = ref.read(clockProvider)();
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
              border: Border.all(color: _fcInputBorderRest, width: 1.5),
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
                  _dateFormat.format(
                    state.paymentDate ?? ref.read(clockProvider)(),
                  ),
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Receiving Bank dropdown (label + field).
  Widget _buildBankSelector(
    FeeCollectionState state,
    AsyncValue<List<BankRow>> bankListAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              decoration:
                  _fcFieldDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ).copyWith(
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
      ],
    );
  }

  /// 4. Amount Tendered field (label + field + pre-fill hint).
  Widget _buildAmountTenderedSection(
    FeeReceiptView receipt,
    FeeCollectionState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          decoration: _fcFieldDecoration(
            suffixText: 'PKR',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: (val) {
            final parsed = int.tryParse(val) ?? 0;
            ref.read(feeCollectionProvider.notifier).setAmountTendered(parsed);
          },
        ),
        const SizedBox(height: 4),
        Text(
          receipt.isPartiallyPaid
              ? 'Pre-filled with remaining balance due: Rs. ${_currencyFormat.format(receipt.remainingBalance)}'
              : 'Pre-filled with net payable${state.useAdvanceCredit ? " minus advance credit" : ""}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// Live settlement-state callout (also used inline beside the amount on
  /// desktop).
  Widget _buildBalanceCallout(int remainingBalance) {
    return Container(
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
          Flexible(
            child: Text(
              'Balance After This Payment: Rs. ${_currencyFormat.format(remainingBalance)}',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: remainingBalance == 0
                    ? AppColors.statusSuccessText
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Remarks field (label + field).
  Widget _buildRemarksField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Remarks',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _remarksController,
          maxLines: 2,
          style: AppTypography.bodySmall,
          decoration: _fcFieldDecoration(
            hintText: 'Teller settlement remarks or transaction note...',
            contentPadding: const EdgeInsets.all(10),
          ),
          onChanged: (val) {
            ref.read(feeCollectionProvider.notifier).setRemarks(val);
          },
        ),
      ],
    );
  }

  /// 6. SMS confirmation toggle.
  Widget _buildSmsToggle(FeeCollectionState state) {
    return Row(
      children: [
        Checkbox(
          value: state.sendSms,
          onChanged: (v) {
            ref.read(feeCollectionProvider.notifier).toggleSms(v ?? true);
          },
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Text(
            'Send SMS payment confirmation',
            style: AppTypography.bodySmall,
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
                                const Text(
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
                                      ref.invalidate(dashboardMetricsProvider);
                                      ref.invalidate(feeLedgerProvider);
                                      ref.invalidate(shellMetadataProvider);
                                      ref.invalidate(schoolLeavingProvider);

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
