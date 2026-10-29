import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/clock_provider.dart';
import '../../core/providers/dashboard_metrics_provider.dart';
import '../../core/providers/fee_collection_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/defaulter_list_pdf_generator.dart';

/// Central Executive Dashboard Cockpit for School Administration.
///
/// Implements Phase D, Step 4B specifications and pixel-faithful layout
/// derived from `05-ui-ux-spec.md` Screen 5 and `dashboard-v2-loaded.png`.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(dashboardMetricsProvider);
    ref.invalidate(shellMetadataProvider);
  }

  String _formatTime(String rawDate) {
    final dt = DateTime.tryParse(rawDate);
    if (dt != null) {
      return DateFormat('hh:mm a').format(dt);
    }
    if (rawDate.contains(' ')) {
      final parts = rawDate.split(' ');
      if (parts.length > 1 && parts[1].length >= 5) {
        return parts[1].substring(0, 5);
      }
    }
    return rawDate;
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final shellMeta = ref.watch(shellMetadataProvider).value;
    final currencyFormatter = NumberFormat('#,##0');
    final todayFormatted = DateFormat('EEEE, d MMMM y')
        .format(ref.watch(clockProvider)());

    final metrics = metricsAsync.value;
    final isLoading = metricsAsync.isLoading && metrics == null;
    if (isLoading && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isLoading && _pulseController.isAnimating) {
      _pulseController.stop();
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            context.go('/students/new'),
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error Banner (if query failed)
                if (metricsAsync.hasError) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusErrorBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.statusErrorBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 20,
                          color: AppColors.statusErrorText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Failed to load dashboard metrics: ${metricsAsync.error}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.statusErrorText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _refresh,
                          child: Text(
                            'Retry',
                            style: AppTypography.label.copyWith(
                              color: AppColors.statusErrorText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── HEADER ROW ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Operational Overview — $todayFormatted',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          child: Text(
                            '[ Academic Session: ${shellMeta?.sessionYear ?? '2017-2018'} ]',
                            style: AppTypography.monospace.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'Refresh Dashboard (Ctrl+R)',
                          onPressed: _refresh,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── 4 KPI CARDS ROW ──
                LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = metricsAsync.value;
                    final isLoading = metricsAsync.isLoading && metrics == null;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card 1: Today's Attendance
                          Expanded(
                            child: _buildKpiCard(
                              label: "TODAY'S ATTENDANCE",
                              icon: Icons.fact_check_outlined,
                              iconColor: AppColors.chartBlue,
                              isLoading: isLoading,
                              onTap: () => context.go('/attendance'),
                              mainWidget: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${metrics?.attendancePercent.toStringAsFixed(1) ?? '0.0'}%',
                                    style: AppTypography.display.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              footerText: isLoading
                                  ? 'Loading attendance...'
                                  : '${metrics?.presentCount ?? 0} / ${metrics?.totalStudents ?? 0} Present',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),

                          // Card 2: Monthly Fee Collection
                          Expanded(
                            child: _buildKpiCard(
                              label: 'MONTHLY FEE COLLECTION',
                              icon: Icons.payments_outlined,
                              iconColor: AppColors.chartTeal,
                              isLoading: isLoading,
                              onTap: () => context.go('/fees/ledger'),
                              mainWidget: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: AppSpacing.xs,
                                children: [
                                  Text(
                                    'Rs. ${currencyFormatter.format(metrics?.monthlyCollected ?? 0)}',
                                    style: AppTypography.display.copyWith(
                                      fontFamily:
                                          AppTypography.monospace.fontFamily,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 26,
                                    ),
                                  ),
                                  if (metrics != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: metrics.collectionPace >= 70
                                            ? AppColors.statusSuccessBg
                                            : AppColors.statusWarningBg,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.full,
                                        ),
                                        border: Border.all(
                                          color: metrics.collectionPace >= 70
                                              ? AppColors.statusSuccessBorder
                                              : AppColors.statusWarningBorder,
                                        ),
                                      ),
                                      child: Text(
                                        '${metrics.collectionPace}% Pace',
                                        style: AppTypography.label.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: metrics.collectionPace >= 70
                                              ? AppColors.statusSuccessText
                                              : AppColors.statusWarningText,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              footerText: isLoading
                                  ? 'Calculating collection...'
                                  : 'Exp: Rs. ${currencyFormatter.format(metrics?.monthlyExpected ?? 0)}',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),

                          // Card 3: Active Enrollment
                          Expanded(
                            child: _buildKpiCard(
                              label: 'ACTIVE ENROLLMENT',
                              icon: Icons.school_outlined,
                              iconColor: AppColors.chartAmber,
                              isLoading: isLoading,
                              onTap: () => context.go('/students'),
                              mainWidget: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${metrics?.activeEnrollment ?? 0}',
                                    style: AppTypography.display.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'Students',
                                    style: AppTypography.h3.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              footerText: isLoading
                                  ? 'Querying enrollment...'
                                  : '${metrics?.classCount ?? 0} Classes, ${metrics?.sectionCount ?? 0} Sections',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),

                          // Card 4: Pending Vouchers
                          Expanded(
                            child: _buildKpiCard(
                              label: 'PENDING VOUCHERS',
                              icon: Icons.receipt_long_outlined,
                              iconColor: AppColors.chartRose,
                              isLoading: isLoading,
                              onTap: () =>
                                  context.go('/fees/ledger?status=Unpaid'),
                              mainWidget: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: AppSpacing.xs,
                                children: [
                                  Text(
                                    '${metrics?.pendingVouchers ?? 0}',
                                    style: AppTypography.display.copyWith(
                                      color: (metrics?.pendingVouchers ?? 0) > 0
                                          ? AppColors.statusErrorText
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Defaulters',
                                    style: AppTypography.h3.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if ((metrics?.pendingVouchers ?? 0) > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.statusErrorBg,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        border: Border.all(
                                          color: AppColors.statusErrorBorder,
                                        ),
                                      ),
                                      child: Text(
                                        'Action Req',
                                        style: AppTypography.label.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.statusErrorText,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              footerText: isLoading
                                  ? 'Auditing deficits...'
                                  : 'Total Overdue: Rs. ${currencyFormatter.format(metrics?.outstandingAmount ?? 0)}',
                              footerWidget: isLoading
                                  ? null
                                  : Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        Text(
                                          'Total Overdue: Rs. ${currencyFormatter.format(metrics?.outstandingAmount ?? 0)}',
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: AppColors.textMuted,
                                              ),
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            final buildData = await ref
                                                .read(
                                                  feeCollectionProvider
                                                      .notifier,
                                                )
                                                .buildDefaulterList();
                                            if (!context.mounted) return;
                                            final meta = ref
                                                .read(shellMetadataProvider)
                                                .value;
                                            await showDefaulterListPrintPreviewDialog(
                                              context,
                                              initialGroups: buildData.groups,
                                              initialSummary: buildData.summary,
                                              branchName: meta?.branchName ?? "Ailyans's Higher Secondary School Mianwali",
                                              branchAddress:
                                                  meta?.branchAddress ??
                                                  'Muslim Bazar Mianwali',
                                              branchPhone: meta?.branchPhone,
                                              branchPrincipal:
                                                  meta?.branchPrincipal,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.print_outlined,
                                                  size: 14,
                                                  color: AppColors.brandPrimary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Print Defaulters',
                                                  style: AppTypography.label
                                                      .copyWith(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .brandPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── QUICK ACTIONS BAR ──
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.borderDefault),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUICK ACTIONS',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.go('/students/new'),
                              icon: const Icon(
                                Icons.person_add_alt_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                '+ New Admission (Ctrl+N)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: AppColors.textOnPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(0, 44),
                                elevation: AppElevation.flat,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  context.go('/fees/receipts?from=dashboard'),
                              icon: const Icon(
                                Icons.payments_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Collect Fee',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: AppColors.textOnPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(0, 44),
                                elevation: AppElevation.flat,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/attendance'),
                              icon: const Icon(
                                Icons.check_circle_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Mark Roll Call',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(0, 44),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/fees/vouchers'),
                              icon: const Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Batch Voucher',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(0, 44),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── TWO-COLUMN LOWER WORKSPACE ──
                LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = metricsAsync.value;
                    final isLoading = metricsAsync.isLoading && metrics == null;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Card (flex 60): Recent Fee Payments Feed
                        Expanded(
                          flex: 6,
                          child: _buildRecentPaymentsCard(
                            metrics: metrics,
                            isLoading: isLoading,
                            currencyFormatter: currencyFormatter,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Right Card (flex 40): Class Strength & Fee Defaulters Summary
                        Expanded(
                          flex: 4,
                          child: _buildClassStrengthCard(
                            metrics: metrics,
                            isLoading: isLoading,
                            currencyFormatter: currencyFormatter,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a uniform KPI metric summary card.
  Widget _buildKpiCard({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isLoading,
    required Widget mainWidget,
    required String footerText,
    Widget? footerWidget,
    VoidCallback? onTap,
  }) {
    final Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: onTap != null
            ? AppColors.brandPrimary.withValues(alpha: 0.04)
            : null,
        mouseCursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.borderDefault),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(icon, size: 20, color: iconColor),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (isLoading)
                    _buildSkeletonBox(width: 120, height: 38)
                  else
                    mainWidget,
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: isLoading
                    ? _buildSkeletonBox(width: 150, height: 14)
                    : (footerWidget ??
                          Text(
                            footerText,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          )),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return card;
    return Tooltip(
      message: 'Click to view details',
      waitDuration: const Duration(milliseconds: 500),
      child: card,
    );
  }

  /// Builds the left-column Recent Fee Payments Feed card.
  Widget _buildRecentPaymentsCard({
    required DashboardMetrics? metrics,
    required bool isLoading,
    required NumberFormat currencyFormatter,
  }) {
    final payments = metrics?.recentPayments ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.chartBlue,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'RECENT FEE PAYMENTS FEED',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/fees/ledger'),
                  child: Text(
                    'Open Fee Ledger →',
                    style: AppTypography.label.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderDefault),

          // Content
          if (isLoading)
            _buildTableLoadingSkeleton(rows: 6)
          else if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_outlined,
                    size: 40,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No fee transactions recorded today',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2), // TIME
                1: FlexColumnWidth(1.1), // REG ID
                2: FlexColumnWidth(2.3), // STUDENT
                3: FlexColumnWidth(1.5), // AMOUNT
                4: FlexColumnWidth(1.5), // VOUCHER
              },
              children: [
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderDefault),
                    ),
                  ),
                  children: [
                    _buildTableHeaderCell('TIME'),
                    _buildTableHeaderCell('REG ID'),
                    _buildTableHeaderCell('STUDENT'),
                    _buildTableHeaderCell('AMOUNT'),
                    _buildTableHeaderCell('VOUCHER'),
                  ],
                ),
                // Data Rows
                for (final item in payments)
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                    ),
                    children: [
                      _buildTableCell(
                        _formatTime(item.submissionDate),
                        style: AppTypography.monospace.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      _buildTableCell(
                        '#${item.stuRegId}',
                        style: AppTypography.monospace.copyWith(
                          fontSize: 12,
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildTableCell(
                        item.studentName,
                        style: AppTypography.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      _buildTableCell(
                        'Rs. ${currencyFormatter.format(item.paidAmount)}',
                        style: AppTypography.monospace.copyWith(
                          fontSize: 12,
                          color: AppColors.statusSuccessText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildTableCell(
                        item.voucherNo,
                        style: AppTypography.monospace.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

          const Divider(height: 1, color: AppColors.borderDefault),
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${payments.length} transactions logged today',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/fees/receipts?from=dashboard'),
                  child: Text(
                    'View All Payments →',
                    style: AppTypography.label.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the right-column Class Strength & Fee Defaulters summary card.
  Widget _buildClassStrengthCard({
    required DashboardMetrics? metrics,
    required bool isLoading,
    required NumberFormat currencyFormatter,
  }) {
    final classes = metrics?.classStrength ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.class_outlined,
                  size: 20,
                  color: AppColors.chartAmber,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'CLASS STRENGTH & DEFAULTERS',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/fees/ledger'),
                  child: Text(
                    'View Fee Analytics →',
                    style: AppTypography.label.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderDefault),

          // Content
          if (isLoading)
            _buildTableLoadingSkeleton(rows: 3)
          else if (classes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 40,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No active class enrollment data',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.6), // CLASS
                1: FlexColumnWidth(1.1), // ENROLLED
                2: FlexColumnWidth(1.1), // UNPAID
                3: FlexColumnWidth(1.6), // OUTSTANDING
              },
              children: [
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderDefault),
                    ),
                  ),
                  children: [
                    _buildTableHeaderCell('CLASS'),
                    _buildTableHeaderCell('ENROLLED'),
                    _buildTableHeaderCell('UNPAID'),
                    _buildTableHeaderCell('OUTSTANDING'),
                  ],
                ),
                // Data Rows
                for (final item in classes)
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                    ),
                    children: [
                      _buildTableCell(
                        item.className,
                        style: AppTypography.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      _buildTableCell(
                        '${item.enrolled}',
                        style: AppTypography.monospace.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      _buildTableCell(
                        '${item.unpaid}',
                        style: AppTypography.monospace.copyWith(
                          fontSize: 12,
                          color: item.unpaid > 0
                              ? AppColors.statusErrorText
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildTableCell(
                        'Rs. ${currencyFormatter.format(item.outstanding)}',
                        style: AppTypography.monospace.copyWith(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

          const Divider(height: 1, color: AppColors.borderDefault),
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Overdue: Rs. ${currencyFormatter.format(metrics?.outstandingAmount ?? 0)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/students'),
                  child: Text(
                    'Class Rosters →',
                    style: AppTypography.label.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {required TextStyle style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      child: Text(text, style: style),
    );
  }

  Widget _buildSkeletonBox({required double width, required double height}) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableLoadingSkeleton({required int rows}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          for (int i = 0; i < rows; i++) ...[
            _buildSkeletonBox(width: double.infinity, height: 28),
            if (i < rows - 1) const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
