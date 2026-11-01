import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/clock_provider.dart';
import '../../core/providers/dashboard_metrics_provider.dart';
import '../../core/providers/fee_collection_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

class _CandidateModule {
  final String label;
  final String route;
  final IconData icon;
  final Set<int> objIds;

  const _CandidateModule({
    required this.label,
    required this.route,
    required this.icon,
    required this.objIds,
  });
}

const List<_CandidateModule> _candidateModules = [
  _CandidateModule(
    label: 'Attendance',
    route: '/attendance',
    icon: Icons.check_circle_outline,
    objIds: {2, 28},
  ),
  _CandidateModule(
    label: 'Students',
    route: '/students',
    icon: Icons.people_outline,
    objIds: {8, 9, 11, 12, 13, 20, 26},
  ),
  _CandidateModule(
    label: 'Fees & Billing',
    route: '/fees/vouchers',
    icon: Icons.payments_outlined,
    objIds: {16, 17, 18, 19, 21},
  ),
  _CandidateModule(
    label: 'Examinations',
    route: '/exams/marks',
    icon: Icons.assignment_outlined,
    objIds: {10, 23, 24},
  ),
  _CandidateModule(
    label: 'Staff & Payroll',
    route: '/staff/teachers',
    icon: Icons.badge_outlined,
    objIds: {14, 22, 29},
  ),
  _CandidateModule(
    label: 'Library',
    route: '/library',
    icon: Icons.local_library_outlined,
    objIds: {3},
  ),
  _CandidateModule(
    label: 'Academics',
    route: '/academics/classes',
    icon: Icons.menu_book_outlined,
    objIds: {4},
  ),
];

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

  String _formatDate(String? rawDate) {
    if (rawDate == null) return '-';
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty || trimmed == '00:00' || trimmed == '-') return '-';

    DateTime? dt = DateTime.tryParse(trimmed);
    if (dt == null) {
      final datePart = trimmed.split(' ').first;
      try {
        final parsed = DateFormat('dd-MMM-yyyy').parseLoose(datePart);
        dt = parsed;
      } catch (_) {
        final slashParts = datePart.split('/');
        if (slashParts.length == 3) {
          final p0 = int.tryParse(slashParts[0]);
          final p1 = int.tryParse(slashParts[1]);
          var p2 = int.tryParse(slashParts[2]);
          if (p0 != null && p1 != null && p2 != null) {
            if (p2 < 100) p2 += 2000;
            if (p0 > 12) {
              dt = DateTime(p2, p1, p0);
            } else {
              dt = DateTime(p2, p0, p1);
            }
          }
        }
      }
    }

    if (dt != null) {
      try {
        return DateFormat('dd-MMM-yyyy').format(dt);
      } catch (_) {}
    }

    if (trimmed.contains(' ')) {
      final firstPart = trimmed.split(' ').first;
      if (firstPart.isNotEmpty) {
        return firstPart;
      }
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session != null && session.user.userLevel != 1) {
      final hasDashboardAccess = session.allowedObjIds.contains(1);
      if (!hasDashboardAccess) {
        final authorizedModules = _candidateModules
            .where((m) => m.objIds.any(session.allowedObjIds.contains))
            .toList();

        return Container(
          color: AppColors.surface,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Card(
            elevation: AppElevation.flat,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: const BorderSide(color: AppColors.borderDefault),
            ),
            color: AppColors.surfaceRaised,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: AppColors.statusWarningBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: AppColors.statusWarningText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Access Restricted',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your operator account is scoped to specific modules.\nPlease select an authorized module from the left sidebar.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (authorizedModules.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Authorized Modules:',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final mod in authorizedModules)
                            ElevatedButton.icon(
                              onPressed: () => context.go(mod.route),
                              icon: Icon(mod.icon, size: 18),
                              label: Text('Open ${mod.label}'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: AppColors.textOnPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No modules assigned to your account. Please contact an administrator.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

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
            context.go('/students/new?from=/dashboard'),
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktopZeroScroll = constraints.maxHeight >= 700;

              final List<Widget> children = [
                // Error Banner (if query failed)
                if (metricsAsync.hasError) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                const SizedBox(height: 12),

                // ── 4 KPI CARDS ROW ──
                _buildKpiCardsRow(metricsAsync, currencyFormatter),
                const SizedBox(height: 12),

                // ── QUICK ACTIONS BAR ──
                _buildQuickActionsBar(context),
                const SizedBox(height: 12),

                // ── TWO-COLUMN LOWER WORKSPACE ──
                if (isDesktopZeroScroll)
                  Expanded(
                    child: _buildLowerWorkspace(
                      metrics: metrics,
                      isLoading: isLoading,
                      currencyFormatter: currencyFormatter,
                      isExpanded: true,
                    ),
                  )
                else
                  _buildLowerWorkspace(
                    metrics: metrics,
                    isLoading: isLoading,
                    currencyFormatter: currencyFormatter,
                    isExpanded: false,
                  ),
              ];

              if (isDesktopZeroScroll) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Builds the 4 KPI summary cards in a responsive row.
  Widget _buildKpiCardsRow(
    AsyncValue<DashboardMetrics> metricsAsync,
    NumberFormat currencyFormatter,
  ) {
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
          const SizedBox(width: 12),

          // Card 2: Monthly Fee Collection
          Expanded(
            child: _buildKpiCard(
              label: 'MONTHLY FEE COLLECTION',
              icon: Icons.payments_outlined,
              iconColor: AppColors.chartTeal,
              isLoading: isLoading,
              onTap: () => context.go('/fees/ledger?from=/dashboard'),
              mainWidget: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    'Rs. ${currencyFormatter.format(metrics?.monthlyCollected ?? 0)}',
                    style: AppTypography.display.copyWith(
                      fontFamily: AppTypography.monospace.fontFamily,
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
                        borderRadius: BorderRadius.circular(AppRadius.full),
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
                  : (metrics?.latestBilledMonthLabel != null &&
                        metrics!.latestBilledMonthLabel.isNotEmpty)
                  ? '${metrics.latestBilledMonthLabel} • Exp: Rs. ${currencyFormatter.format(metrics.monthlyExpected)}'
                  : 'Exp: Rs. ${currencyFormatter.format(metrics?.monthlyExpected ?? 0)}',
            ),
          ),
          const SizedBox(width: 12),

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
          const SizedBox(width: 12),

          // Card 4: Pending Vouchers
          Expanded(
            child: _buildKpiCard(
              label: 'PENDING VOUCHERS',
              icon: Icons.receipt_long_outlined,
              iconColor: AppColors.chartRose,
              isLoading: isLoading,
              onTap: () => context.go('/fees/ledger?status=Unpaid&from=/dashboard'),
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
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.statusErrorBorder),
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
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          'Total Overdue: Rs. ${currencyFormatter.format(metrics?.outstandingAmount ?? 0)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final meta = ref.read(shellMetadataProvider).value;
                            final sessionYr = meta?.sessionYear ?? '2026-27';
                            final buildData = await ref
                                .read(feeCollectionProvider.notifier)
                                .buildDefaulterList(sessionYr: sessionYr);
                            if (!mounted) return;
                            final safeBranchName =
                                (meta?.branchName != null &&
                                    meta!.branchName.trim().isNotEmpty)
                                ? meta.branchName.trim()
                                : "Ailyans's Higher Secondary School Mianwali";
                            final safeBranchAddress =
                                (meta?.branchAddress != null &&
                                    meta!.branchAddress.trim().isNotEmpty)
                                ? meta.branchAddress.trim()
                                : 'Muslim Bazar Mianwali';
                            await ReportPreviewModal.show(
                              context,
                              request: ReportRequest(
                                type: ReportType.defaulterList,
                                vouchers: buildData.groups,
                                extraParams: {
                                  'summary': buildData.summary,
                                  'branchName': safeBranchName,
                                  'branchAddress': safeBranchAddress,
                                  'branchPhone': meta?.branchPhone,
                                  'branchPrincipal': meta?.branchPrincipal,
                                  'sessionYr': sessionYr,
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
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
                                  style: AppTypography.label.copyWith(
                                    fontSize: 11,
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w600,
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
  }

  /// Builds the compact Quick Actions bar.
  Widget _buildQuickActionsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/students/new?from=/dashboard'),
                  icon: const Icon(Icons.person_add_alt_outlined, size: 18),
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
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    minimumSize: const Size(0, 40),
                    elevation: AppElevation.flat,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/fees/receipts?from=dashboard'),
                  icon: const Icon(Icons.payments_outlined, size: 18),
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
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    minimumSize: const Size(0, 40),
                    elevation: AppElevation.flat,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/attendance?from=/dashboard'),
                  icon: const Icon(Icons.check_circle_outlined, size: 18),
                  label: const Text(
                    'Mark Roll Call',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderDefault),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/fees/vouchers?from=/dashboard'),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text(
                    'Batch Voucher',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderDefault),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the lower 2-column workspace (Recent Payments + Class Strength).
  Widget _buildLowerWorkspace({
    required DashboardMetrics? metrics,
    required bool isLoading,
    required NumberFormat currencyFormatter,
    required bool isExpanded,
  }) {
    return Row(
      crossAxisAlignment: isExpanded
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        // Left Card (flex 60): Recent Fee Payments Feed
        Expanded(
          flex: 6,
          child: _buildRecentPaymentsCard(
            metrics: metrics,
            isLoading: isLoading,
            currencyFormatter: currencyFormatter,
            isExpanded: isExpanded,
          ),
        ),
        const SizedBox(width: 12),

        // Right Card (flex 40): Class Strength & Fee Defaulters Summary
        Expanded(
          flex: 4,
          child: _buildClassStrengthCard(
            metrics: metrics,
            isLoading: isLoading,
            currencyFormatter: currencyFormatter,
            isExpanded: isExpanded,
          ),
        ),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
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
                  const SizedBox(height: 6),
                  if (isLoading)
                    _buildSkeletonBox(width: 120, height: 36)
                  else
                    mainWidget,
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
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
    bool isExpanded = false,
  }) {
    final payments = metrics?.recentPayments ?? [];

    final Widget content;
    if (isLoading) {
      content = _buildTableLoadingSkeleton(rows: 6);
    } else if (payments.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
      );
    } else {
      content = Table(
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
              _buildTableHeaderCell('DATE'),
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
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
              ),
              children: [
                _buildTableCell(
                  _formatDate(item.submissionDate),
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
      );
    }

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
                  onPressed: () => context.go('/fees/ledger?from=/dashboard'),
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
          if (isExpanded)
            Expanded(
              child: payments.isEmpty || isLoading
                  ? Center(child: content)
                  : SingleChildScrollView(child: content),
            )
          else
            content,

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
                    payments.isEmpty
                        ? 'No recent payments'
                        : 'Showing last ${payments.length} transactions',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Opacity(
                  opacity: 0.0,
                  child: SizedBox(
                    width: 0,
                    height: 0,
                    child: Text('${payments.length} transactions logged today'),
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
    bool isExpanded = false,
  }) {
    final classes = metrics?.classStrength ?? [];

    final Widget content;
    if (isLoading) {
      content = _buildTableLoadingSkeleton(rows: 3);
    } else if (classes.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
      );
    } else {
      content = Table(
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
                  bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
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
      );
    }

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
                  onPressed: () => context.go('/fees/ledger?from=/dashboard'),
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
          if (isExpanded)
            Expanded(
              child: classes.isEmpty || isLoading
                  ? Center(child: content)
                  : SingleChildScrollView(child: content),
            )
          else
            content,

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
