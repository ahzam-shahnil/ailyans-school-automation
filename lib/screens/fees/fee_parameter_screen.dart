import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/fee_parameter_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/voucher_generation_provider.dart'
    show voucherClassTariffsProvider;
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/fee_head_display.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/bank_account_row.dart';
import '../../models/class_fee_summary.dart';
import '../../models/fee_parameter_row.dart';
import '../../widgets/mobile/mobile_status_pill.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

/// Screen 12 - FeeParameterScreen at /fees/parameters.
/// Consolidates legacy SCHfrmFeeParameter (§S15) and SCHfrmBankInfo (§S16).
class FeeParameterScreen extends ConsumerStatefulWidget {
  const FeeParameterScreen({super.key});

  @override
  ConsumerState<FeeParameterScreen> createState() => _FeeParameterScreenState();
}

class _FeeParameterScreenState extends ConsumerState<FeeParameterScreen> {
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(feeParameterProvider.notifier).loadInitial();

      final metaAsync = ref.read(shellMetadataProvider);
      if (!metaAsync.hasValue) return;
      final meta = metaAsync.valueOrNull;
      if (meta == null) return;
      final current = ref.read(feeParameterProvider).selectedFeeYr;
      if (current != meta.sessionYear) {
        ref
            .read(feeParameterProvider.notifier)
            .setSelectedFeeYr(meta.sessionYear);
      }
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _showAddFeeParamModal(
    BuildContext context,
    String className,
    int classId,
    String feeYr,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddFeeParamDialog(
        className: className,
        classId: classId,
        feeYr: feeYr,
      ),
    );
  }

  void _showEditFeeParamModal(
    BuildContext context,
    FeeParameterRow row,
    String className,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditFeeParamDialog(row: row, className: className),
    );
  }

  void _showDeleteFeeParamModal(
    BuildContext context,
    FeeParameterRow row,
    String className,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteFeeParamDialog(row: row, className: className),
    );
  }

  void _showBankModal(BuildContext context, [BankAccountRow? bank]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BankEditorDialog(bank: bank),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feeParamState = ref.watch(feeParameterProvider);
    final feeParamNotifier = ref.read(feeParameterProvider.notifier);
    final bankState = ref.watch(bankAccountProvider);
    final bankNotifier = ref.read(bankAccountProvider.notifier);

    // Listen to toasts and error messages from feeParameterProvider
    ref.listen<FeeParameterState>(feeParameterProvider, (prev, next) {
      if (next.toast != null && next.toast != prev?.toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            backgroundColor: AppColors.statusSuccessText,
            duration: const Duration(seconds: 3),
          ),
        );
        feeParamNotifier.clearToast();
      }
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.statusErrorText,
            duration: const Duration(seconds: 4),
          ),
        );
        feeParamNotifier.clearErrorMessage();
      }
    });

    // Listen to toasts and error messages from bankAccountProvider
    ref.listen<BankAccountState>(bankAccountProvider, (prev, next) {
      if (next.toast != null && next.toast != prev?.toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            backgroundColor: AppColors.statusSuccessText,
            duration: const Duration(seconds: 3),
          ),
        );
        bankNotifier.clearToast();
      }
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.statusErrorText,
            duration: const Duration(seconds: 4),
          ),
        );
        bankNotifier.clearErrorMessage();
      }
    });

    // Phase G-9 Shot 1b — mobile guard (< 600px). Desktop layout untouched.
    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileLayout(context, feeParamState, feeParamNotifier);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          if (feeParamState.selectedTab == 0 &&
              feeParamState.selectedClassId != null) {
            final summary = feeParamState.classSummaries.firstWhere(
              (c) => c.classId == feeParamState.selectedClassId,
              orElse: () => const ClassFeeSummary(
                classId: 0,
                cName: '',
                headCount: 0,
                totalFee: 0,
              ),
            );
            _showAddFeeParamModal(
              context,
              summary.cName,
              summary.classId,
              feeParamState.selectedFeeYr,
            );
          }
        },
      },
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                // Header Row (Height: 56px)
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  color: AppColors.surfaceRaised,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        tooltip: 'Back to Fee Vouchers',
                        onPressed: () => context.go('/fees/vouchers'),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fee Structure & Bank Setup',
                        style: AppTypography.h2.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.borderDefault,
                ),

                // Horizontal Tabs (Height: 40px)
                _buildTabSwitcher(feeParamState.selectedTab, feeParamNotifier),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.borderDefault,
                ),

                // Main Workspace
                Expanded(
                  child: feeParamState.selectedTab == 0
                      ? _buildFeeStructureTab(
                          context,
                          feeParamState,
                          feeParamNotifier,
                        )
                      : _buildBankAccountsTab(context, bankState),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // MOBILE LAYOUT (< 600px) — Phase G-9 Shot 1b
  // ==========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    FeeParameterState state,
    FeeParameterNotifier notifier,
  ) {
    final selectedClass = state.classSummaries.firstWhere(
      (c) => c.classId == state.selectedClassId,
      orElse: () => const ClassFeeSummary(
        classId: 0,
        cName: 'Class',
        headCount: 0,
        totalFee: 0,
      ),
    );
    final bankState = ref.watch(bankAccountProvider);
    final isBanksTab = state.selectedTab == 1;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header strip: back button + title
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    tooltip: 'Back to Fee Vouchers',
                    onPressed: () => context.go('/fees/vouchers'),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fee Structure & Bank Setup',
                      style: AppTypography.h2.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderDefault,
            ),

            // Horizontal tab switcher (horizontal scroll on narrow screens)
            _buildMobileTabSwitcher(state.selectedTab),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderDefault,
            ),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isBanksTab) ...[
                      // Tab 2: Institutional Bank Accounts
                      Text(
                        'INSTITUTIONAL BANK ACCOUNTS (${bankState.banks.length})',
                        style: _mobileSectionLabelStyle,
                      ),
                      const SizedBox(height: 8),
                      if (bankState.banks.isEmpty)
                        _buildMobileAccentCard(
                          accentColor: AppColors.textMuted,
                          child: Text(
                            'No bank accounts registered yet. Use the add button below to create one.',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        for (final bank in bankState.banks)
                          _buildMobileBankCard(bank),
                    ] else ...[
                      // Tab 1: Class Fee Structure
                      _buildMobileSessionSelector(state, notifier),
                      const SizedBox(height: 12),
                      const Text('CLASSES', style: _mobileSectionLabelStyle),
                      const SizedBox(height: 8),
                      for (final c in state.classSummaries)
                        _buildMobileClassCard(c, state, notifier),

                      // Selected Class Fee Schedule
                      if (state.selectedClassId != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'FEE SCHEDULE: ${selectedClass.cName}',
                          style: _mobileSectionLabelStyle,
                        ),
                        const SizedBox(height: 8),
                        if (state.currentClassRows.isEmpty)
                          _buildMobileAccentCard(
                            accentColor: AppColors.textMuted,
                            child: Text(
                              'No fee parameters defined for ${selectedClass.cName} in session ${state.selectedFeeYr}.',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else ...[
                          for (final r in state.currentClassRows)
                            _buildMobileFeeParamCard(r, selectedClass),
                          const SizedBox(height: 12),
                          _buildMobileTotalStrip(state),
                        ],
                      ],
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Sticky Action Bar
            _buildMobileStickyBar(context, state, notifier, selectedClass),
          ],
        ),
      ),
    );
  }

  static const TextStyle _mobileSectionLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
  );

  /// Safe left-strip accent card: clip + uniform border + 3.5px strip Row.
  /// Never combines a non-uniform Border with borderRadius on one BoxDecoration.
  Widget _buildMobileAccentCard({
    required Color accentColor,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 8),
    Color? backgroundColor,
    VoidCallback? onTap,
  }) {
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3.5, color: accentColor),
          Expanded(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: row),
            )
          : row,
    );
  }

  Widget _buildMobileTabSwitcher(int selectedTab) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMobileTabButton(
            label: '1. Class Fee Structure',
            isSelected: selectedTab == 0,
            onTap: () =>
                ref.read(feeParameterProvider.notifier).setSelectedTab(0),
          ),
          _buildMobileTabButton(
            label: '2. Institutional Bank Accounts',
            isSelected: selectedTab == 1,
            onTap: () {
              ref.read(feeParameterProvider.notifier).setSelectedTab(1);
              ref.read(bankAccountProvider.notifier).loadBanks();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.accentFees : Colors.transparent,
              width: 3.0,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.accentFees : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 44px-high outlined session dropdown.
  Widget _buildMobileSessionSelector(
    FeeParameterState state,
    FeeParameterNotifier notifier,
  ) {
    final sessionYearsAsync = ref.watch(availableSessionsProvider);
    final sessionYears = sessionYearsAsync.valueOrNull ?? const <String>[];
    final effectiveSessions = <String>{
      if (state.selectedFeeYr.isNotEmpty) state.selectedFeeYr,
      ...sessionYears,
      '2017-2018',
    }.toList()..sort((a, b) => b.compareTo(a));
    final currentValue = effectiveSessions.contains(state.selectedFeeYr)
        ? state.selectedFeeYr
        : (effectiveSessions.isNotEmpty
              ? effectiveSessions.first
              : '2017-2018');

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: DropdownButton<String>(
        value: currentValue,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        dropdownColor: AppColors.surface,
        items: effectiveSessions.map((s) {
          return DropdownMenuItem(
            value: s,
            child: Text(
              s,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null && val != state.selectedFeeYr) {
            notifier.setSelectedFeeYr(val);
          }
        },
      ),
    );
  }

  Widget _buildMobileClassCard(
    ClassFeeSummary c,
    FeeParameterState state,
    FeeParameterNotifier notifier,
  ) {
    final isSelected = c.classId == state.selectedClassId;
    return _buildMobileAccentCard(
      accentColor: AppColors.accentFees,
      backgroundColor: isSelected ? AppColors.accentFeesSoftBg : null,
      onTap: () => notifier.setSelectedClassId(c.classId),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.cName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (c.headCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Rs. ${NumberFormat('#,##0.00').format(c.totalFee)} total',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          MobileStatusPill(
            label: '${c.headCount} Heads',
            variant: c.headCount > 0
                ? MobileStatusVariant.success
                : MobileStatusVariant.neutral,
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: isSelected ? AppColors.accentFees : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFeeParamCard(FeeParameterRow row, ClassFeeSummary selectedClass) {
    return _buildMobileAccentCard(
      accentColor: AppColors.accentFees,
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            row.formatAmount(),
            style: AppTypography.monospace.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.accentFees,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit Tariff',
            onPressed: () =>
                _showEditFeeParamModal(context, row, selectedClass.cName),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.statusErrorText,
            ),
            tooltip: 'Remove Tariff',
            onPressed: () =>
                _showDeleteFeeParamModal(context, row, selectedClass.cName),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTotalStrip(FeeParameterState state) {
    final total = state.currentClassRows.fold<double>(
      0.0,
      (sum, r) => sum + r.fee,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentFeesSoftBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentFees.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total Class Package',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rs. ${NumberFormat('#,##0.00').format(total)}',
            style: AppTypography.monospace.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.accentFees,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBankCard(BankAccountRow bank) {
    return _buildMobileAccentCard(
      accentColor: AppColors.accentFees,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank.bankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bank.branch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  bank.acctNo,
                  style: AppTypography.monospace.copyWith(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MobileStatusPill(
            label: bank.isActive ? 'Active' : 'Inactive',
            variant: bank.isActive
                ? MobileStatusVariant.success
                : MobileStatusVariant.error,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit Bank Account',
            onPressed: () => _showBankModal(context, bank),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStickyBar(
    BuildContext context,
    FeeParameterState state,
    FeeParameterNotifier notifier,
    ClassFeeSummary selectedClass,
  ) {
    final isBanksTab = state.selectedTab == 1;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isBanksTab
              ? () => _showBankModal(context)
              : () => _handleMobileAddAction(state, notifier, selectedClass),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            isBanksTab ? 'Add Bank Account' : 'Add Fee Parameter (Ctrl+N)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentFees,
            foregroundColor: AppColors.textOnPrimary,
            iconColor: AppColors.textOnPrimary,
          ),
        ),
      ),
    );
  }

  void _handleMobileAddAction(
    FeeParameterState state,
    FeeParameterNotifier notifier,
    ClassFeeSummary selectedClass,
  ) {
    if (state.selectedClassId == null || selectedClass.classId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a class first to add a fee parameter.'),
          backgroundColor: AppColors.statusErrorText,
        ),
      );
      return;
    }
    _showAddFeeParamModal(
      context,
      selectedClass.cName,
      selectedClass.classId,
      state.selectedFeeYr,
    );
  }

  // ==========================================================================
  // TAB SWITCHER
  // ==========================================================================
  Widget _buildTabSwitcher(int selectedTab, FeeParameterNotifier notifier) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surfaceRaised,
      child: Row(
        children: [
          _buildTabButton(
            label: '1. Class Fee Structure',
            isSelected: selectedTab == 0,
            onTap: () => notifier.setSelectedTab(0),
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildTabButton(
            label: '2. Institutional Bank Accounts',
            isSelected: selectedTab == 1,
            onTap: () {
              notifier.setSelectedTab(1);
              ref.read(bankAccountProvider.notifier).loadBanks();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.brandPrimary : Colors.transparent,
              width: 3.0,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 1: CLASS FEE STRUCTURE (MASTER-DETAIL)
  // ==========================================================================
  Widget _buildFeeStructureTab(
    BuildContext context,
    FeeParameterState state,
    FeeParameterNotifier notifier,
  ) {
    final selectedClass = state.classSummaries.firstWhere(
      (c) => c.classId == state.selectedClassId,
      orElse: () => const ClassFeeSummary(
        classId: 0,
        cName: 'Class',
        headCount: 0,
        totalFee: 0,
      ),
    );

    final sessionYearsAsync = ref.watch(availableSessionsProvider);
    final sessionYears = sessionYearsAsync.valueOrNull ?? const <String>[];
    final effectiveSessions = <String>{
      if (state.selectedFeeYr.isNotEmpty) state.selectedFeeYr,
      ...sessionYears,
      '2017-2018',
    }.toList()..sort((a, b) => b.compareTo(a));

    return Row(
      children: [
        // Left Pane: Classes List (300px)
        SizedBox(
          width: 300,
          child: Column(
            children: [
              // Session Filter Header
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 8,
                ),
                color: AppColors.surfaceRaised,
                child: SizedBox(
                  height: 40,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        effectiveSessions.contains(state.selectedFeeYr)
                        ? state.selectedFeeYr
                        : (effectiveSessions.isNotEmpty
                              ? effectiveSessions.first
                              : '2017-2018'),
                    isExpanded: true,
                    menuMaxHeight: 400,
                    decoration: const InputDecoration(
                      labelText: 'Session',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: effectiveSessions.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setSelectedFeeYr(val);
                    },
                  ),
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // Class List
              Expanded(
                child: ListView.builder(
                  itemCount: state.classSummaries.length,
                  itemBuilder: (context, index) {
                    final item = state.classSummaries[index];
                    final isSelected = item.classId == state.selectedClassId;
                    return InkWell(
                      onTap: () => notifier.setSelectedClassId(item.classId),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brandPrimary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : Colors.transparent,
                              width: 3.0,
                            ),
                            bottom: const BorderSide(
                              color: AppColors.borderSubtle,
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isSelected)
                              const Icon(
                                Icons.arrow_right,
                                size: 16,
                                color: AppColors.brandPrimary,
                              ),
                            Expanded(
                              child: Text(
                                item.cName,
                                style: AppTypography.body.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppColors.brandPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.headCount > 0
                                    ? AppColors.brandPrimary.withValues(
                                        alpha: 0.08,
                                      )
                                    : AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Text(
                                '(${item.headCount} Heads)',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: item.headCount > 0
                                      ? AppColors.brandPrimary
                                      : AppColors.textMuted,
                                ),
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
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppColors.borderDefault,
        ),

        // Right Pane: Active Fee Schedule (Expanded)
        Expanded(
          child: Column(
            children: [
              // Header & Actions Strip
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: AppColors.surfaceRaised,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'FEE STRUCTURE: ${selectedClass.cName} (Session: ${state.selectedFeeYr})',
                        style: AppTypography.h3.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: () => _showAddFeeParamModal(
                        context,
                        selectedClass.cName,
                        selectedClass.classId,
                        state.selectedFeeYr,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Fee Parameter (Ctrl+N)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textOnPrimary,
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () {
                        final meta = ref
                            .read(shellMetadataProvider)
                            .valueOrNull;
                        final feeRows = state.currentClassRows
                            .map(
                              (r) => <String, dynamic>{
                                'displayName': r.displayName,
                                'fee': r.fee,
                              },
                            )
                            .toList();
                        ReportPreviewModal.show(
                          context,
                          request: ReportRequest(
                            type: ReportType.feeSchedule,
                            id: '${selectedClass.classId}_${state.selectedFeeYr}',
                            extraParams: {
                              'feeRows': feeRows,
                              'sessionYear': state.selectedFeeYr,
                              'className': selectedClass.cName,
                              'branchName': meta?.branchName ?? '',
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print Fee Schedule'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderDefault),
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // Data Table Header
              Container(
                height: 40,
                color: AppColors.surfaceSubtle,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'ID',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Parameter Name',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Amount (Rs.)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Session',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Actions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // Table Body or Empty State
              Expanded(
                child: state.currentClassRows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: AppColors.textDisabled,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No fee parameters defined for ${selectedClass.cName} in session ${state.selectedFeeYr}.',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ElevatedButton.icon(
                              onPressed: () => _showAddFeeParamModal(
                                context,
                                selectedClass.cName,
                                selectedClass.classId,
                                state.selectedFeeYr,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('+ Add Fee Parameter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: AppColors.textOnPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.currentClassRows.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.borderSubtle,
                        ),
                        itemBuilder: (context, index) {
                          final row = state.currentClassRows[index];
                          final isAlternate = index.isOdd;
                          return Container(
                            height: 48,
                            color: isAlternate
                                ? AppColors.surfaceSubtle.withValues(alpha: 0.5)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '${row.feeParamId}',
                                    style: AppTypography.bodySmall,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    row.displayName,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      row.formatAmount(),
                                      style: AppTypography.body.copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      row.feeYr,
                                      style: AppTypography.bodySmall,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 96,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                        ),
                                        tooltip: 'Edit Tariff',
                                        onPressed: () => _showEditFeeParamModal(
                                          context,
                                          row,
                                          selectedClass.cName,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                          color: AppColors.statusErrorText,
                                        ),
                                        tooltip: 'Remove Tariff',
                                        onPressed: () =>
                                            _showDeleteFeeParamModal(
                                              context,
                                              row,
                                              selectedClass.cName,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // Pinned Footer Strip
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: AppColors.surfaceRaised,
                child: Row(
                  children: [
                    Text(
                      '${state.currentClassRows.length} Fee Parameter(s) Configured',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total Class Package: Rs. ${NumberFormat('#,##0.00').format(state.currentClassRows.fold<double>(0.0, (sum, r) => sum + r.fee))}',
                      style: AppTypography.body.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TAB 2: INSTITUTIONAL BANK ACCOUNTS
  // ==========================================================================
  Widget _buildBankAccountsTab(BuildContext context, BankAccountState state) {
    return Column(
      children: [
        // Header & Actions
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: AppColors.surfaceRaised,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'INSTITUTIONAL BANK ACCOUNTS (${state.banks.length})',
                  style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => _showBankModal(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ Add Bank Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.textOnPrimary,
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Table Header
        Container(
          height: 40,
          color: AppColors.surfaceSubtle,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: const Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  'ID',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Bank Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Branch',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Address',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Acct No',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Acct Title',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Default',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Table Body
        Expanded(
          child: ListView.separated(
            itemCount: state.banks.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle,
            ),
            itemBuilder: (context, index) {
              final bank = state.banks[index];
              return Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    SizedBox(width: 50, child: Text('${bank.bankInfoId}')),
                    Expanded(
                      flex: 3,
                      child: Text(
                        bank.bankName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(flex: 2, child: Text(bank.branch)),
                    Expanded(
                      flex: 3,
                      child: Text(
                        bank.address,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        bank.acctNo,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    Expanded(flex: 2, child: Text(bank.acctTitle)),
                    SizedBox(width: 70, child: Text(bank.acctType)),
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: bank.isActive
                                ? AppColors.statusSuccessBg
                                : AppColors.statusErrorBg,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            bank.isActive ? 'Active' : 'Inactive',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: bank.isActive
                                  ? AppColors.statusSuccessText
                                  : AppColors.statusErrorText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.center,
                        child: bank.isDefault
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.statusWarningBg,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Text(
                                  'Default',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.statusWarningText,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Align(
                        alignment: Alignment.center,
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Edit Bank Account',
                          onPressed: () => _showBankModal(context, bank),
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
    );
  }
}

// ============================================================================
// MODAL 1: ADD FEE PARAMETER DIALOG (520px)
// ============================================================================
class _AddFeeParamDialog extends ConsumerStatefulWidget {
  final String className;
  final int classId;
  final String feeYr;

  const _AddFeeParamDialog({
    required this.className,
    required this.classId,
    required this.feeYr,
  });

  @override
  ConsumerState<_AddFeeParamDialog> createState() => _AddFeeParamDialogState();
}

class _AddFeeParamDialogState extends ConsumerState<_AddFeeParamDialog> {
  int? _selectedParamId;
  final TextEditingController _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feeParameterProvider);
    final userLevel = ref.watch(sessionProvider)?.user.userLevel ?? 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Fee Parameter - ${widget.className}',
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),

              // Fee Parameter Dropdown (CombParam)
              DropdownButtonFormField<int>(
                key: const ValueKey('add_comb_param'),
                initialValue: _selectedParamId,
                hint: const Text('Select Fee Parameter'),
                isExpanded: true,
                menuMaxHeight: 400,
                decoration: const InputDecoration(
                  labelText: 'Fee Parameter',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                items: state.availableFeeParams.map((p) {
                  final id = p['FeeParamID'] as int;
                  final rawDesc = p['ParamDesciption'] as String? ?? '';
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(FeeHeadDisplay.of(rawDesc)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedParamId = val);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Currency Input (txtFee)
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Fee Amount',
                  prefixText: 'Rs. ',
                  hintText: 'Enter fee amount',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Read-only Session Year
              TextFormField(
                initialValue: widget.feeYr,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Session Year',
                  border: OutlineInputBorder(),
                  filled: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(_amountCtrl.text.trim());
                      final success = await ref
                          .read(feeParameterProvider.notifier)
                          .addFeeParameter(
                            classId: widget.classId,
                            feeParamId: _selectedParamId,
                            fee: amount,
                            feeYr: widget.feeYr,
                            userLevel: userLevel,
                          );
                      if (context.mounted && success) {
                        ref.invalidate(voucherClassTariffsProvider);
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODAL 2: EDIT FEE PARAMETER DIALOG (520px)
// ============================================================================
class _EditFeeParamDialog extends ConsumerStatefulWidget {
  final FeeParameterRow row;
  final String className;

  const _EditFeeParamDialog({required this.row, required this.className});

  @override
  ConsumerState<_EditFeeParamDialog> createState() =>
      _EditFeeParamDialogState();
}

class _EditFeeParamDialogState extends ConsumerState<_EditFeeParamDialog> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.row.fee.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userLevel = ref.watch(sessionProvider)?.user.userLevel ?? 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Fee Parameter - ${widget.className}',
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),

              // Read-only Parameter Name
              TextFormField(
                initialValue: widget.row.displayName,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fee Parameter',
                  border: OutlineInputBorder(),
                  filled: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Editable Amount
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Fee Amount',
                  prefixText: 'Rs. ',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Read-only Session Year
              TextFormField(
                initialValue: widget.row.feeYr,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Session Year',
                  border: OutlineInputBorder(),
                  filled: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () async {
                      final newFee = double.tryParse(_amountCtrl.text.trim());
                      final success = await ref
                          .read(feeParameterProvider.notifier)
                          .updateFeeParameter(
                            classId: widget.row.classId,
                            feeParamId: widget.row.feeParamId,
                            feeYr: widget.row.feeYr,
                            newFee: newFee,
                            userLevel: userLevel,
                          );
                      if (context.mounted && success) {
                        ref.invalidate(voucherClassTariffsProvider);
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODAL 3: DELETE CONFIRMATION DIALOG (520px)
// ============================================================================
class _DeleteFeeParamDialog extends ConsumerWidget {
  final FeeParameterRow row;
  final String className;

  const _DeleteFeeParamDialog({required this.row, required this.className});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userLevel = ref.watch(sessionProvider)?.user.userLevel ?? 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verbatim S15 title
              Text(
                'Removing a Parameter from Class',
                style: AppTypography.h3.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusErrorText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Verbatim S15 prompt template
              Text(
                'Are you sure want to Remove ${FeeHeadDisplay.of(row.paramDescription)} from Class $className',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () async {
                      final success = await ref
                          .read(feeParameterProvider.notifier)
                          .deleteFeeParameter(
                            classId: row.classId,
                            feeParamId: row.feeParamId,
                            feeYr: row.feeYr,
                            userLevel: userLevel,
                          );
                      if (context.mounted && success) {
                        ref.invalidate(voucherClassTariffsProvider);
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusErrorText,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODAL 4: ADD/EDIT BANK DIALOG (520px)
// ============================================================================
class _BankEditorDialog extends ConsumerStatefulWidget {
  final BankAccountRow? bank;

  const _BankEditorDialog({this.bank});

  @override
  ConsumerState<_BankEditorDialog> createState() => _BankEditorDialogState();
}

class _BankEditorDialogState extends ConsumerState<_BankEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _branchCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _acctNoCtrl;
  late final TextEditingController _acctTitleCtrl;
  late String _acctType;
  late bool _acctStatus;
  late bool _bankDefault;

  @override
  void initState() {
    super.initState();
    final b = widget.bank;
    _nameCtrl = TextEditingController(text: b?.bankName ?? '');
    _branchCtrl = TextEditingController(text: b?.branch ?? '');
    _addrCtrl = TextEditingController(text: b?.address ?? '');
    _acctNoCtrl = TextEditingController(text: b?.acctNo ?? '');
    _acctTitleCtrl = TextEditingController(text: b?.acctTitle ?? '');
    _acctType = (b?.acctType.isNotEmpty == true) ? b!.acctType : 'Current';
    _acctStatus = b?.isActive ?? true;
    _bankDefault = b?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _branchCtrl.dispose();
    _addrCtrl.dispose();
    _acctNoCtrl.dispose();
    _acctTitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userLevel = ref.watch(sessionProvider)?.user.userLevel ?? 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bank == null
                      ? 'Add Bank Account'
                      : 'Edit Bank Account',
                  style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                TextFormField(
                  controller: _branchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                TextFormField(
                  controller: _addrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                TextFormField(
                  controller: _acctNoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Number *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                TextFormField(
                  controller: _acctTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Title',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                DropdownButtonFormField<String>(
                  initialValue: _acctType,
                  decoration: const InputDecoration(
                    labelText: 'Account Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Current', child: Text('Current')),
                    DropdownMenuItem(value: 'Savings', child: Text('Savings')),
                    DropdownMenuItem(value: 'PLS', child: Text('PLS')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _acctType = val);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    Switch(
                      value: _acctStatus,
                      onChanged: (val) => setState(() => _acctStatus = val),
                    ),
                    const Text('Active Status'),
                    const Spacer(),
                    Switch(
                      value: _bankDefault,
                      onChanged: (val) => setState(() => _bankDefault = val),
                    ),
                    const Text('Default Bank'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderDefault),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: () async {
                        final success = await ref
                            .read(bankAccountProvider.notifier)
                            .saveBank(
                              bankInfoId: widget.bank?.bankInfoId,
                              bankName: _nameCtrl.text,
                              branch: _branchCtrl.text,
                              address: _addrCtrl.text,
                              acctNo: _acctNoCtrl.text,
                              acctTitle: _acctTitleCtrl.text,
                              acctType: _acctType,
                              acctStatus: _acctStatus ? 1 : 0,
                              bankDefault: _bankDefault ? 'Y' : 'N',
                              userLevel: userLevel,
                            );
                        if (context.mounted && success) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textOnPrimary,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
