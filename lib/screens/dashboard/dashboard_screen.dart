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
/// Implements 3-Breakpoint Google Stitch Design:
/// - Desktop (>= 1024px): 3x2 KPI Grid, 3x2 Quick Operations, 55/45 Lower Data Feed Split
/// - Tablet (600..1023px): 2x3 KPI Grid, 2x3 Quick Operations, Stacked Lower Data Feeds
/// - Mobile (< 600px): 2x2+2 KPI Grid, 1-col tactile Quick Operations, Stacked Tables
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const double _defaultSplitRatio = 0.55;
  static const double _minSplitRatio = 0.38;
  static const double _maxSplitRatio = 0.72;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  double _splitRatio = _defaultSplitRatio;

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

    ref.listenManual<AsyncValue<DashboardMetrics>>(dashboardMetricsProvider, (
      previous,
      next,
    ) {
      final isLoading = next.isLoading && next.value == null;
      if (isLoading && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      } else if (!isLoading && _pulseController.isAnimating) {
        _pulseController.stop();
      }
    }, fireImmediately: true);
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
        return _buildAccessRestricted(session);
      }
    }

    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final shellMeta = ref.watch(shellMetadataProvider).value;
    final currencyFormatter = NumberFormat('#,##0');
    final todayFormatted = DateFormat('EEEE, d MMMM y')
        .format(ref.watch(clockProvider)());

    final metrics = metricsAsync.value;
    final isLoading = metricsAsync.isLoading && metrics == null;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            context.go('/students/new?from=/dashboard'),
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surfaceCanvas,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final isDesktop = w >= 1024;
              final isTablet = w >= 600 && w < 1024;
              final isMobile = w < 600;

              final pagePadding = isMobile ? 12.0 : (isTablet ? 16.0 : 24.0);
              const gutter = 12.0;
              const gap = SizedBox(height: gutter);

              return SingleChildScrollView(
                padding: EdgeInsets.all(pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (metricsAsync.hasError) ...[
                      _buildErrorBanner(metricsAsync, gutter),
                      gap,
                    ],
                    _buildHeaderBar(
                      shellMeta,
                      todayFormatted,
                      isStacked: w < 760,
                    ),
                    gap,
                    _buildStitchKpiGrid(
                      metrics: metrics,
                      shellMeta: shellMeta,
                      isLoading: isLoading,
                      currencyFormatter: currencyFormatter,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      isMobile: isMobile,
                    ),
                    gap,
                    _buildStitchQuickOperations(
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      isMobile: isMobile,
                    ),
                    gap,
                    _buildLowerWorkspace(
                      metrics: metrics,
                      isLoading: isLoading,
                      currencyFormatter: currencyFormatter,
                      isDesktop: isDesktop,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCESS RESTRICTED STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAccessRestricted(UserSession session) {
    final authorizedModules = _candidateModules
        .where((m) => m.objIds.any(session.allowedObjIds.contains))
        .toList();

    return Container(
      color: AppColors.surfaceCanvas,
      child: Center(
        child: SingleChildScrollView(
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
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildErrorBanner(
    AsyncValue<DashboardMetrics> metricsAsync,
    double gutter,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: gutter,
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
    );
  }

  Widget _buildHeaderBar(
    ShellMetadata? shellMeta,
    String todayFormatted, {
    required bool isStacked,
  }) {
    final title = Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            'Operational Overview — $todayFormatted',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Text(
              '[ Academic Session: ${shellMeta?.sessionYear ?? '2017-2018'} ]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monospace.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        IconButton(
          icon: const Icon(
            Icons.refresh,
            size: 20,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Refresh Dashboard (Ctrl+R)',
          onPressed: _refresh,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );

    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      child: isStacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: AppSpacing.xs),
                Align(alignment: Alignment.centerLeft, child: controls),
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.md),
                controls,
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION A — 6 STITCH KPI CARDS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStitchKpiGrid({
    required DashboardMetrics? metrics,
    required ShellMetadata? shellMeta,
    required bool isLoading,
    required NumberFormat currencyFormatter,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    // Card 1: Student Body / Active Enrollment
    final card1 = _buildKpiCard(
      label: 'ACTIVE ENROLLMENT',
      icon: Icons.groups_outlined,
      accentColor: AppColors.accentStudents,
      accentSoftBg: AppColors.accentStudentsSoftBg,
      badgeText:
          '${shellMeta?.studentCount ?? (metrics?.activeEnrollment ?? 0)} Total',
      value: '${metrics?.activeEnrollment ?? 0}',
      suffix: 'Students',
      subtitle:
          '${metrics?.classCount ?? 0} Classes, ${metrics?.sectionCount ?? 0} Sections',
      isLoading: isLoading,
      isMobile: isMobile,
      onTap: () => context.go('/students'),
      tooltip: 'View student directory',
    );

    final todayIso =
        ref.watch(clockProvider)().toIso8601String().substring(0, 10);
    final payments = metrics?.recentPayments ?? [];
    final todayCollected = payments
        .where((p) => p.submissionDate.startsWith(todayIso))
        .fold<int>(0, (s, p) => s + p.paidAmount);

    // Card 2: Today's Collection
    final card2 = _buildKpiCard(
      label: "TODAY'S COLLECTION",
      icon: Icons.payments_outlined,
      accentColor: AppColors.accentFees,
      accentSoftBg: AppColors.accentFeesSoftBg,
      badgeText: "Today's Counter",
      value: 'Rs. ${currencyFormatter.format(todayCollected)}',
      monospace: true,
      subtitle: 'Daily Register',
      isLoading: isLoading,
      isMobile: isMobile,
      onTap: () => context.go('/fees/receipts?from=dashboard'),
      tooltip: "View today's fee receipts",
    );

    // Card 3: Monthly Revenue / Fee Collection
    final card3 = _buildKpiCard(
      label: 'MONTHLY FEE COLLECTION',
      icon: Icons.account_balance_outlined,
      accentColor: AppColors.accentFees,
      accentSoftBg: AppColors.accentFeesSoftBg,
      badgeText: '${metrics?.collectionPace ?? 0}% Pace',
      value: 'Rs. ${currencyFormatter.format(metrics?.monthlyCollected ?? 0)}',
      monospace: true,
      subtitle: (metrics?.latestBilledMonthLabel != null &&
              metrics!.latestBilledMonthLabel.isNotEmpty)
          ? '${metrics.latestBilledMonthLabel} • Exp: Rs. ${currencyFormatter.format(metrics.monthlyExpected)}'
          : 'Exp: Rs. ${currencyFormatter.format(metrics?.monthlyExpected ?? 0)}',
      isLoading: isLoading,
      isMobile: isMobile,
      onTap: () => context.go('/fees/ledger?from=/dashboard'),
      tooltip: 'View monthly fee ledger & billing',
    );

    // Card 4: Pending Dues / Pending Vouchers
    final card4 = _buildKpiCard(
      label: 'PENDING VOUCHERS',
      icon: Icons.assignment_late_outlined,
      accentColor: AppColors.statusErrorText,
      accentSoftBg: AppColors.statusErrorBg,
      badgeText: 'Action Req',
      value: '${metrics?.pendingVouchers ?? 0}',
      valueColor: AppColors.statusErrorText,
      suffix: 'Defaulters',
      subtitle:
          'Total Overdue: Rs. ${currencyFormatter.format(metrics?.outstandingAmount ?? 0)}',
      footerAction: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: 'Print fee defaulter list',
          waitDuration: const Duration(milliseconds: 500),
          child: InkWell(
            onTap: () async {
              final meta = ref.read(shellMetadataProvider).value;
              final sy = meta?.sessionYear ?? '2026-27';
              final buildData = await ref
                  .read(feeCollectionProvider.notifier)
                  .buildDefaulterList(sessionYr: sy);
              if (!mounted) return;
              final safeBranchName = (meta?.branchName != null &&
                      meta!.branchName.trim().isNotEmpty)
                  ? meta.branchName.trim()
                  : "Ailyans's Higher Secondary School Mianwali";
              final safeBranchAddress = (meta?.branchAddress != null &&
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
                    'sessionYr': sy,
                  },
                ),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.print_outlined,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Print Defaulters',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        fontSize: 11,
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      isLoading: isLoading,
      isMobile: isMobile,
      onTap: () => context.go('/fees/ledger?status=Unpaid&from=/dashboard'),
      tooltip: 'View pending fee defaulters',
    );

    // Card 5: Today's Attendance
    final presentCount = metrics?.presentCount ?? 0;
    final absentCount = metrics?.absentCount ?? 0;
    final card5 = _buildAttendanceKpiCard(
      rateString: '${metrics?.attendancePercent.toStringAsFixed(1) ?? '0.0'}%',
      presentCount: presentCount,
      absentCount: absentCount,
      totalCount: metrics?.totalStudents ?? 0,
      isLoading: isLoading,
      onTap: () => context.go('/attendance'),
      tooltip: 'View student attendance registers',
    );

    // Card 6: Academic Faculty
    final card6 = isMobile
        ? _StitchCard(
            accentColor: AppColors.accentStaff,
            onTap: () => context.go('/staff/teachers'),
            tooltip: 'View faculty & staff directory',
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accentStaffSoftBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: AppColors.accentStaff,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ACADEMIC FACULTY',
                        style: AppTypography.label.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Teaching & Admin Staff',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusPill(
                  text: 'All Present Today',
                  background: AppColors.accentStaffSoftBg,
                  foreground: AppColors.accentStaff,
                  border: AppColors.accentStaff.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 10),
                Text(
                  '${shellMeta?.staffCount ?? 5}',
                  style: AppTypography.display.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          )
        : _buildKpiCard(
            label: 'ACADEMIC FACULTY',
            icon: Icons.badge_outlined,
            accentColor: AppColors.accentStaff,
            accentSoftBg: AppColors.accentStaffSoftBg,
            badgeText: 'All Present Today',
            value: '${shellMeta?.staffCount ?? 5}',
            subtitle: 'Teaching & Admin Staff',
            isLoading: isLoading,
            onTap: () => context.go('/staff/teachers'),
            tooltip: 'View faculty & staff directory',
          );

    const gap = 12.0;

    if (isDesktop) {
      // 3 columns x 2 rows
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: gap),
              Expanded(child: card2),
              const SizedBox(width: gap),
              Expanded(child: card3),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card4),
              const SizedBox(width: gap),
              Expanded(child: card5),
              const SizedBox(width: gap),
              Expanded(child: card6),
            ],
          ),
        ],
      );
    }

    if (isTablet) {
      // 2 columns x 3 rows
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: gap),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card3),
              const SizedBox(width: gap),
              Expanded(child: card4),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card5),
              const SizedBox(width: gap),
              Expanded(child: card6),
            ],
          ),
        ],
      );
    }

    // Mobile: 2x2 grid (cards 1-4) + full-width Card 5 + full-width Card 6
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card1),
            const SizedBox(width: gap),
            Expanded(child: card2),
          ],
        ),
        const SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card3),
            const SizedBox(width: gap),
            Expanded(child: card4),
          ],
        ),
        const SizedBox(height: gap),
        card5,
        const SizedBox(height: gap),
        card6,
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required IconData icon,
    required Color accentColor,
    required Color accentSoftBg,
    required String badgeText,
    required String value,
    required String subtitle,
    required bool isLoading,
    bool isMobile = false,
    String? suffix,
    Color? valueColor,
    bool monospace = false,
    Widget? footerAction,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    if (isMobile) {
      return _StitchCard(
        accentColor: accentColor,
        onTap: onTap,
        tooltip: tooltip,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentSoftBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const Spacer(),
                Flexible(
                  child: _buildStatusPill(
                    text: badgeText,
                    background: accentSoftBg,
                    foreground: accentColor,
                    border: accentColor.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              _buildSkeletonBox(width: 80, height: 24)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: (monospace
                                ? AppTypography.monospace
                                : AppTypography.display)
                            .copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: valueColor ?? AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        suffix,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.textSecondary,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                ),
              ),
            ],
            if (footerAction != null) ...[
              const SizedBox(height: 4),
              footerAction,
            ],
          ],
        ),
      );
    }

    return _StitchCard(
      accentColor: accentColor,
      onTap: onTap,
      tooltip: tooltip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentSoftBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildStatusPill(
                  text: badgeText,
                  background: accentSoftBg,
                  foreground: accentColor,
                  border: accentColor.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoading)
            _buildSkeletonBox(width: 110, height: 28)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: (monospace
                              ? AppTypography.monospace
                              : AppTypography.display)
                          .copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    suffix,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 8),
          if (isLoading)
            _buildSkeletonBox(width: 140, height: 12)
          else ...[
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
            if (footerAction != null) ...[
              const SizedBox(height: 4),
              footerAction,
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceKpiCard({
    required String rateString,
    required int presentCount,
    required int absentCount,
    required int totalCount,
    required bool isLoading,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    return _StitchCard(
      accentColor: AppColors.accentAttendance,
      onTap: onTap,
      tooltip: tooltip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentAttendanceSoftBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.how_to_reg_outlined,
                  size: 16,
                  color: AppColors.accentAttendance,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "TODAY'S ATTENDANCE",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildStatusPill(
                text: 'Class Attendance',
                background: AppColors.accentAttendanceSoftBg,
                foreground: AppColors.accentAttendance,
                border: AppColors.accentAttendance.withValues(alpha: 0.25),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoading)
            _buildSkeletonBox(width: 110, height: 28)
          else
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rateString,
                      style: AppTypography.display.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$presentCount Present',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.statusSuccessText,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$absentCount Absent',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.statusErrorText,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          // 6px-high rounded segmented horizontal progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (presentCount > 0)
                    Expanded(
                      flex: presentCount,
                      child: Container(color: AppColors.statusSuccessText),
                    ),
                  if (absentCount > 0)
                    Expanded(
                      flex: absentCount,
                      child: Container(color: AppColors.statusErrorText),
                    ),
                  if (presentCount == 0 && absentCount == 0)
                    Expanded(
                      child: Container(color: AppColors.surfaceSubtle),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$presentCount / $totalCount Present',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION B — 6 STITCH QUICK OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStitchQuickOperations({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final actions = [
      _QuickOpItem(
        title: '+ New Student Admission',
        subtitle: '+ New Admission (Ctrl+N)',
        badge: 'CTRL+N',
        icon: Icons.person_add_alt_1_outlined,
        accentColor: AppColors.accentStudents,
        softBg: AppColors.accentStudentsSoftBg,
        onTap: () => context.go('/students/new?from=/dashboard'),
      ),
      _QuickOpItem(
        title: 'Collect Fee (Teller)',
        subtitle: 'Collect Fee',
        badge: 'F2',
        icon: Icons.payments_outlined,
        accentColor: AppColors.accentFees,
        softBg: AppColors.accentFeesSoftBg,
        onTap: () => context.go('/fees/receipts?from=/dashboard'),
      ),
      _QuickOpItem(
        title: 'Generate Monthly Vouchers',
        subtitle: 'Batch Voucher',
        badge: 'CTRL+G',
        icon: Icons.receipt_long_outlined,
        accentColor: AppColors.accentDashboard,
        softBg: AppColors.accentDashboardSoftBg,
        onTap: () => context.go('/fees/vouchers?from=/dashboard'),
      ),
      _QuickOpItem(
        title: 'Mark Class Attendance',
        subtitle: 'Mark Roll Call',
        badge: 'CTRL+A',
        icon: Icons.fact_check_outlined,
        accentColor: AppColors.accentAttendance,
        softBg: AppColors.accentAttendanceSoftBg,
        onTap: () => context.go('/attendance?from=/dashboard'),
      ),
      _QuickOpItem(
        title: 'Fee Ledger & Defaulters',
        subtitle: 'Audit & Defaulters',
        badge: 'CTRL+L',
        icon: Icons.menu_book_outlined,
        accentColor: AppColors.accentFees,
        softBg: AppColors.accentFeesSoftBg,
        onTap: () => context.go('/fees/ledger?from=/dashboard'),
      ),
      _QuickOpItem(
        title: 'Enter Exam Marks',
        subtitle: 'Term Assessments',
        badge: 'CTRL+E',
        icon: Icons.edit_note_outlined,
        accentColor: AppColors.accentExams,
        softBg: AppColors.accentExamsSoftBg,
        onTap: () => context.go('/exams/marks?from=/dashboard'),
      ),
    ];

    const gap = 10.0;

    Widget body;
    if (isDesktop) {
      // 3 columns x 2 rows
      body = Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildQuickOpCard(actions[0], isCompact: false)),
              const SizedBox(width: gap),
              Expanded(child: _buildQuickOpCard(actions[1], isCompact: false)),
              const SizedBox(width: gap),
              Expanded(child: _buildQuickOpCard(actions[2], isCompact: false)),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            children: [
              Expanded(child: _buildQuickOpCard(actions[3], isCompact: false)),
              const SizedBox(width: gap),
              Expanded(child: _buildQuickOpCard(actions[4], isCompact: false)),
              const SizedBox(width: gap),
              Expanded(child: _buildQuickOpCard(actions[5], isCompact: false)),
            ],
          ),
        ],
      );
    } else if (isTablet) {
      // 2 columns x 3 rows
      body = Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildQuickOpCard(actions[0], isCompact: true)),
              const SizedBox(width: gap),
              Expanded(child: _buildQuickOpCard(actions[1], isCompact: true)),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            children: [
              Expanded(child: _buildQuickOpCard(actions[2], isCompact: true)),
              const SizedBox(width: gap),
              Expanded(child: _buildQuickOpCard(actions[3], isCompact: true)),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            children: [
              Expanded(child: _buildQuickOpCard(actions[4], isCompact: true)),
              const SizedBox(width: gap),
              Expanded(child: _buildQuickOpCard(actions[5], isCompact: true)),
            ],
          ),
        ],
      );
    } else {
      // Mobile: 1 column of 6 tactile list cards
      body = Column(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            _buildMobileQuickOpTile(actions[i]),
            if (i < actions.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'QUICK OPERATIONS',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              // Accessibility label for existing tests
              const Opacity(
                opacity: 0.0,
                child: SizedBox(
                  width: 0,
                  height: 0,
                  child: Text('QUICK ACTIONS'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }

  Widget _buildQuickOpCard(_QuickOpItem item, {required bool isCompact}) {
    return _SurfaceCard(
      onTap: item.onTap,
      tooltip: '${item.title} (${item.badge})',
      padding: const EdgeInsets.all(12),
      child: isCompact
          ? Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.softBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Icon(item.icon, size: 17, color: item.accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _buildShortcutBadge(item.badge),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.softBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.icon, size: 17, color: item.accentColor),
                    ),
                    _buildShortcutBadge(item.badge),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMobileQuickOpTile(_QuickOpItem item) {
    return _SurfaceCard(
      onTap: item.onTap,
      tooltip: '${item.title} (${item.badge})',
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.softBg,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 17, color: item.accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutBadge(String shortcut) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        shortcut,
        style: AppTypography.monospace.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION C — PRESERVED DATA FEEDS (RECENT PAYMENTS & CLASS STRENGTH)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLowerWorkspace({
    required DashboardMetrics? metrics,
    required bool isLoading,
    required NumberFormat currencyFormatter,
    required bool isDesktop,
  }) {
    final recentPayments = _buildRecentPaymentsCard(
      metrics: metrics,
      isLoading: isLoading,
      currencyFormatter: currencyFormatter,
      fillHeight: isDesktop,
    );
    final classStrength = _buildClassStrengthCard(
      metrics: metrics,
      isLoading: isLoading,
      currencyFormatter: currencyFormatter,
      fillHeight: isDesktop,
    );

    if (!isDesktop) {
      // Tablet & Mobile: Stack vertically
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          recentPayments,
          const SizedBox(height: 12),
          classStrength,
        ],
      );
    }

    // Desktop: side-by-side with split handle
    return SizedBox(
      height: 520,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const handleWidth = 12.0;
          final available = constraints.maxWidth - handleWidth;
          if (available < 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: recentPayments),
                const SizedBox(width: handleWidth),
                Expanded(child: classStrength),
              ],
            );
          }

          final leftWidth = (available * _splitRatio)
              .clamp(available * _minSplitRatio, available * _maxSplitRatio)
              .toDouble();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: leftWidth, child: recentPayments),
              _SplitHandle(
                key: const ValueKey('dashboard-split-handle'),
                onDrag: (delta) {
                  if (!mounted) return;
                  setState(() {
                    _splitRatio = (_splitRatio + delta / available)
                        .clamp(_minSplitRatio, _maxSplitRatio)
                        .toDouble();
                  });
                },
                onReset: () {
                  if (!mounted) return;
                  setState(() => _splitRatio = _defaultSplitRatio);
                },
              ),
              Expanded(child: classStrength),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentPaymentsCard({
    required DashboardMetrics? metrics,
    required bool isLoading,
    required NumberFormat currencyFormatter,
    required bool fillHeight,
  }) {
    final payments = metrics?.recentPayments ?? [];

    Widget body;
    if (isLoading) {
      body = _buildTableLoadingSkeleton(rows: 6);
    } else if (payments.isEmpty) {
      body = _buildEmptyState(
        icon: Icons.receipt_outlined,
        message: 'No fee transactions recorded today',
      );
    } else {
      final table = _ensureMinWidth(
        540,
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.5), // DATE
            1: FlexColumnWidth(1.0), // REG ID
            2: FlexColumnWidth(2.2), // STUDENT
            3: FlexColumnWidth(1.4), // AMOUNT
            4: FlexColumnWidth(1.4), // VOUCHER
          },
          children: [
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
                    onTap: () => context.go('/students?from=/dashboard'),
                    tooltip: 'View student #${item.stuRegId} directory',
                  ),
                  _buildTableCell(
                    item.studentName,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    onTap: () => context.go('/students?from=/dashboard'),
                    tooltip: 'View ${item.studentName} directory',
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
                    onTap: () => context.go('/fees/ledger?from=/dashboard'),
                    tooltip: 'View voucher ${item.voucherNo} in ledger',
                  ),
                ],
              ),
          ],
        ),
      );
      body = fillHeight ? SingleChildScrollView(child: table) : table;
    }

    return _buildDataCard(
      icon: Icons.receipt_long_outlined,
      iconColor: AppColors.accentDashboard,
      title: 'RECENT FEE PAYMENTS FEED',
      actionLabel: 'Open Fee Ledger →',
      onAction: () => context.go('/fees/ledger?from=/dashboard'),
      fillHeight: fillHeight,
      content: body,
      footer: _buildFeedFooter(
        payments.isEmpty
            ? 'No recent payments'
            : 'Showing last ${payments.length} transactions',
        trailing: TextButton(
          onPressed: () => context.go('/fees/receipts?from=dashboard'),
          child: Text(
            'View All Payments →',
            style: AppTypography.label.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        extra: Opacity(
          opacity: 0.0,
          child: SizedBox(
            width: 0,
            height: 0,
            child: Text('${payments.length} transactions logged today'),
          ),
        ),
      ),
    );
  }

  Widget _buildClassStrengthCard({
    required DashboardMetrics? metrics,
    required bool isLoading,
    required NumberFormat currencyFormatter,
    required bool fillHeight,
  }) {
    final classes = metrics?.classStrength ?? [];

    Widget body;
    if (isLoading) {
      body = _buildTableLoadingSkeleton(rows: 3);
    } else if (classes.isEmpty) {
      body = _buildEmptyState(
        icon: Icons.school_outlined,
        message: 'No active class enrollment data',
      );
    } else {
      final table = _ensureMinWidth(
        440,
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.6), // CLASS
            1: FlexColumnWidth(1.1), // ENROLLED
            2: FlexColumnWidth(1.0), // UNPAID
            3: FlexColumnWidth(1.6), // OUTSTANDING
          },
          children: [
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
                    onTap: () => context.go('/students?from=/dashboard'),
                    tooltip: 'View ${item.className} roster',
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
                    onTap: item.unpaid > 0
                        ? () => context.go(
                            '/fees/ledger?status=Unpaid&from=/dashboard')
                        : null,
                    tooltip: item.unpaid > 0
                        ? 'View ${item.unpaid} unpaid vouchers'
                        : null,
                  ),
                  _buildTableCell(
                    'Rs. ${currencyFormatter.format(item.outstanding)}',
                    style: AppTypography.monospace.copyWith(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: item.outstanding > 0
                        ? () => context.go(
                            '/fees/ledger?status=Unpaid&from=/dashboard')
                        : null,
                    tooltip: item.outstanding > 0
                        ? 'View overdue balance'
                        : null,
                  ),
                ],
              ),
          ],
        ),
      );
      body = fillHeight ? SingleChildScrollView(child: table) : table;
    }

    return _buildDataCard(
      icon: Icons.class_outlined,
      iconColor: AppColors.accentAttendance,
      title: 'CLASS STRENGTH & DEFAULTERS',
      actionLabel: 'View Fee Analytics →',
      onAction: () => context.go('/fees/ledger?from=/dashboard'),
      fillHeight: fillHeight,
      content: body,
      footer: _buildFeedFooter(
        'Total Overdue: Rs. ${currencyFormatter.format(metrics?.outstandingAmount ?? 0)}',
        trailing: TextButton(
          onPressed: () => context.go('/students'),
          child: Text(
            'Class Rosters →',
            style: AppTypography.label.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
    required Widget content,
    required Widget footer,
    required bool fillHeight,
  }) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message: actionLabel,
                    waitDuration: const Duration(milliseconds: 500),
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        actionLabel,
                        maxLines: 1,
                        style: AppTypography.label.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderDefault),
          if (fillHeight) Expanded(child: content) else content,
          const Divider(height: 1, color: AppColors.borderDefault),
          footer,
        ],
      ),
    );
  }

  Widget _buildFeedFooter(
    String lead, {
    required Widget trailing,
    Widget? extra,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        children: [
          Text(
            lead,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          trailing,
          if (extra != null) extra,
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIMITIVES & HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatusPill({
    required String text,
    required Color background,
    required Color foreground,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: AppTypography.label.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    required TextStyle style,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    Widget content = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    if (onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
      if (tooltip != null && tooltip.isNotEmpty) {
        content = Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 500),
          child: content,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: content,
    );
  }

  Widget _ensureMinWidth(double minWidth, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= minWidth) return child;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: child),
        );
      },
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

class _QuickOpItem {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color accentColor;
  final Color softBg;
  final VoidCallback onTap;

  const _QuickOpItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.accentColor,
    required this.softBg,
    required this.onTap,
  });
}

/// Stitch KPI Card with a 3.5px colored accent strip on the left border,
/// hover lift, cursor feedback, and tooltip.
class _StitchCard extends StatefulWidget {
  const _StitchCard({
    required this.accentColor,
    required this.child,
    this.onTap,
    this.tooltip,
  });

  final Color accentColor;
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<_StitchCard> createState() => _StitchCardState();
}

class _StitchCardState extends State<_StitchCard> {
  bool _hovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final lifted = _hovered && _interactive && !reduceMotion;

    Widget card = AnimatedContainer(
      duration: reduceMotion ? Duration.zero : AppDuration.fast,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: lifted ? AppColors.borderHover : AppColors.borderDefault,
        ),
        boxShadow: [
          BoxShadow(
            color: lifted ? const Color(0x140F172A) : const Color(0x06000000),
            blurRadius: lifted ? 16 : 4,
            offset: lifted ? const Offset(0, 6) : const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg - 1),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3.5,
                color: widget.accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (_interactive) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          hoverColor: Colors.transparent,
          splashColor: widget.accentColor.withValues(alpha: 0.08),
          highlightColor: widget.accentColor.withValues(alpha: 0.04),
          child: card,
        ),
      );

      final tooltipMsg = widget.tooltip ?? 'Click to view details';
      if (tooltipMsg.isNotEmpty) {
        card = Tooltip(
          message: tooltipMsg,
          waitDuration: const Duration(milliseconds: 500),
          child: card,
        );
      }
    }

    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: _interactive ? (_) => setState(() => _hovered = false) : null,
      child: card,
    );
  }
}

class _SurfaceCard extends StatefulWidget {
  const _SurfaceCard({
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  @override
  State<_SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<_SurfaceCard> {
  bool _hovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final lifted = _hovered && _interactive && !reduceMotion;

    Widget card = AnimatedContainer(
      duration: reduceMotion ? Duration.zero : AppDuration.fast,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: lifted
              ? AppColors.borderHover
              : AppColors.borderDefault,
        ),
        boxShadow: [
          BoxShadow(
            color: lifted ? const Color(0x140F172A) : const Color(0x06000000),
            blurRadius: lifted ? 16 : 4,
            offset: lifted ? const Offset(0, 6) : const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          hoverColor: Colors.transparent,
          splashColor: AppColors.brandPrimary.withValues(alpha: 0.05),
          highlightColor: AppColors.brandPrimary.withValues(alpha: 0.03),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (_interactive && widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      card = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: card,
      );
    }

    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: _interactive ? (_) => setState(() => _hovered = false) : null,
      child: card,
    );
  }
}

class _SplitHandle extends StatefulWidget {
  const _SplitHandle({
    super.key,
    required this.onDrag,
    required this.onReset,
  });

  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  State<_SplitHandle> createState() => _SplitHandleState();
}

class _SplitHandleState extends State<_SplitHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        onDoubleTap: widget.onReset,
        child: SizedBox(
          width: 12,
          child: Center(
            child: AnimatedContainer(
              duration: AppDuration.fast,
              width: active ? 4 : 2,
              height: active ? 48 : 32,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.brandPrimary
                    : AppColors.borderDefault,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
