import 'dart:math' as math;

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

/// Resolved dashboard geometry for the current viewport.
///
/// One source of truth for padding, gutters, column counts and type scale so
/// every section reflows together instead of each widget guessing its own
/// breakpoints.
class _DashboardLayout {
  const _DashboardLayout({
    required this.width,
    required this.height,
    required this.pagePadding,
    required this.gutter,
    required this.kpiColumns,
    required this.quickColumns,
    required this.twoPane,
    required this.fillViewport,
    required this.headerStacked,
  });

  final double width;
  final double height;
  final double pagePadding;
  final double gutter;
  final int kpiColumns;
  final int quickColumns;

  /// Whether the lower workspace can sit side by side.
  final bool twoPane;

  /// Whether the whole page can fill the viewport without scrolling.
  final bool fillViewport;

  /// Whether the header title and controls stack vertically.
  final bool headerStacked;

  double get contentWidth => width - pagePadding * 2;

  factory _DashboardLayout.from(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final twoPane = w >= 980;
    return _DashboardLayout(
      width: w,
      height: constraints.maxHeight,
      pagePadding: w < 640 ? 12.0 : (w < 1280 ? 16.0 : 24.0),
      gutter: w < 640 ? 10.0 : 12.0,
      kpiColumns: w >= 1040 ? 4 : (w >= 620 ? 2 : 1),
      quickColumns: w >= 1040 ? 4 : (w >= 620 ? 2 : 1),
      twoPane: twoPane,
      fillViewport: twoPane && constraints.maxHeight >= 720,
      headerStacked: w < 760,
    );
  }
}

/// Central Executive Dashboard Cockpit for School Administration.
///
/// Implements Phase D, Step 4B specifications and pixel-faithful layout
/// derived from `05-ui-ux-spec.md` Screen 5 and `dashboard-v2-loaded.png`.
///
/// Layout is fully fluid: KPI cards and quick actions collapse 4 → 2 → 1,
/// the lower workspace stacks below 980px and becomes a drag-resizable
/// split pane above it.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const double _defaultSplitRatio = 0.6;
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

    // React to provider state changes outside of build; mutating an
    // AnimationController while building schedules work during layout.
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
          color: AppColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = _DashboardLayout.from(constraints);
              final gap = SizedBox(height: layout.gutter);

              final children = <Widget>[
                if (metricsAsync.hasError) ...[
                  _buildErrorBanner(metricsAsync, layout),
                  gap,
                ],
                _buildHeaderBar(layout, shellMeta, todayFormatted),
                gap,
                _buildKpiCardsRow(layout, metricsAsync, currencyFormatter),
                gap,
                _buildQuickActionsBar(layout),
                gap,
                if (layout.fillViewport)
                  Expanded(
                    child: _buildLowerWorkspace(
                      layout: layout,
                      metrics: metrics,
                      isLoading: isLoading,
                      currencyFormatter: currencyFormatter,
                      fillHeight: true,
                    ),
                  )
                else if (layout.twoPane)
                  SizedBox(
                    height: math.max(
                      420.0,
                      math.min(560.0, constraints.maxHeight - 280.0),
                    ),
                    child: _buildLowerWorkspace(
                      layout: layout,
                      metrics: metrics,
                      isLoading: isLoading,
                      currencyFormatter: currencyFormatter,
                      fillHeight: true,
                    ),
                  )
                else
                  _buildLowerWorkspace(
                    layout: layout,
                    metrics: metrics,
                    isLoading: isLoading,
                    currencyFormatter: currencyFormatter,
                    fillHeight: false,
                  ),
              ];

              if (layout.fillViewport) {
                return Padding(
                  padding: EdgeInsets.all(layout.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                );
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(layout.pagePadding),
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

  // ─────────────────────────────────────────────────────────────────────────
  // ACCESS RESTRICTED STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAccessRestricted(UserSession session) {
    final authorizedModules = _candidateModules
        .where((m) => m.objIds.any(session.allowedObjIds.contains))
        .toList();

    return Container(
      color: AppColors.surface,
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
    _DashboardLayout layout,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.gutter,
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
    _DashboardLayout layout,
    ShellMetadata? shellMeta,
    String todayFormatted,
  ) {
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
      padding: EdgeInsets.symmetric(
        horizontal: layout.gutter + 2,
        vertical: 10,
      ),
      child: layout.headerStacked
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
  // KPI CARDS
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds the KPI summary cards as a fluid grid (4 → 2 → 1 columns).
  Widget _buildKpiCardsRow(
    _DashboardLayout layout,
    AsyncValue<DashboardMetrics> metricsAsync,
    NumberFormat currencyFormatter,
  ) {
    final metrics = metricsAsync.value;
    final isLoading = metricsAsync.isLoading && metrics == null;

    final columns = layout.kpiColumns;
    // Floor keeps floating-point drift from wrapping a full row.
    final tileWidth =
        ((layout.contentWidth - layout.gutter * (columns - 1)) / columns)
            .floorToDouble();
    final valueSize = (tileWidth * 0.115).clamp(22.0, 34.0).toDouble();
    final feeValueSize = (valueSize * 0.86).clamp(20.0, 30.0).toDouble();
    final tileHeight = columns == 4 ? 172.0 : (columns == 2 ? 164.0 : 160.0);

    Widget tile(Widget child) =>
        SizedBox(width: tileWidth, height: tileHeight, child: child);

    return Wrap(
      spacing: layout.gutter,
      runSpacing: layout.gutter,
      children: [
        // Card 1: Today's Attendance
        tile(
          _buildKpiCard(
            label: "TODAY'S ATTENDANCE",
            icon: Icons.fact_check_outlined,
            iconColor: AppColors.chartBlue,
            isLoading: isLoading,
            valueWidget: _buildKpiValue(
              value:
                  '${metrics?.attendancePercent.toStringAsFixed(1) ?? '0.0'}%',
              size: valueSize,
            ),
            footerText: isLoading
                ? 'Loading attendance...'
                : '${metrics?.presentCount ?? 0} / ${metrics?.totalStudents ?? 0} Present',
            progress: isLoading
                ? null
                : (metrics?.attendancePercent ?? 0) / 100,
            progressColor: AppColors.chartBlue,
            onTap: () => context.go('/attendance'),
          ),
        ),

        // Card 2: Monthly Fee Collection
        tile(
          _buildKpiCard(
            label: 'MONTHLY FEE COLLECTION',
            icon: Icons.payments_outlined,
            iconColor: AppColors.chartTeal,
            isLoading: isLoading,
            valueWidget: _buildKpiValue(
              value:
                  'Rs. ${currencyFormatter.format(metrics?.monthlyCollected ?? 0)}',
              size: feeValueSize,
              monospace: true,
              badge: metrics == null
                  ? null
                  : _buildStatusPill(
                      text: '${metrics.collectionPace}% Pace',
                      background: metrics.collectionPace >= 70
                          ? AppColors.statusSuccessBg
                          : AppColors.statusWarningBg,
                      foreground: metrics.collectionPace >= 70
                          ? AppColors.statusSuccessText
                          : AppColors.statusWarningText,
                      border: metrics.collectionPace >= 70
                          ? AppColors.statusSuccessBorder
                          : AppColors.statusWarningBorder,
                    ),
            ),
            footerText: isLoading
                ? 'Calculating collection...'
                : (metrics?.latestBilledMonthLabel != null &&
                      metrics!.latestBilledMonthLabel.isNotEmpty)
                ? '${metrics.latestBilledMonthLabel} • Exp: Rs. ${currencyFormatter.format(metrics.monthlyExpected)}'
                : 'Exp: Rs. ${currencyFormatter.format(metrics?.monthlyExpected ?? 0)}',
            progress: isLoading ? null : (metrics?.collectionPace ?? 0) / 100,
            progressColor: (metrics?.collectionPace ?? 0) >= 70
                ? AppColors.chartEmerald
                : AppColors.chartAmber,
            onTap: () => context.go('/fees/ledger?from=/dashboard'),
          ),
        ),

        // Card 3: Active Enrollment
        tile(
          _buildKpiCard(
            label: 'ACTIVE ENROLLMENT',
            icon: Icons.school_outlined,
            iconColor: AppColors.chartAmber,
            isLoading: isLoading,
            valueWidget: _buildKpiValue(
              value: '${metrics?.activeEnrollment ?? 0}',
              size: valueSize,
              suffix: 'Students',
            ),
            footerText: isLoading
                ? 'Querying enrollment...'
                : '${metrics?.classCount ?? 0} Classes, ${metrics?.sectionCount ?? 0} Sections',
            onTap: () => context.go('/students'),
          ),
        ),

        // Card 4: Pending Vouchers
        tile(
          _buildKpiCard(
            label: 'PENDING VOUCHERS',
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.chartRose,
            isLoading: isLoading,
            valueWidget: _buildKpiValue(
              value: '${metrics?.pendingVouchers ?? 0}',
              size: valueSize,
              color: (metrics?.pendingVouchers ?? 0) > 0
                  ? AppColors.statusErrorText
                  : AppColors.textPrimary,
              suffix: 'Defaulters',
              badge: (metrics?.pendingVouchers ?? 0) > 0
                  ? _buildStatusPill(
                      text: 'Action Req',
                      background: AppColors.statusErrorBg,
                      foreground: AppColors.statusErrorText,
                      border: AppColors.statusErrorBorder,
                      fontSize: 10,
                    )
                  : null,
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
            onTap: () =>
                context.go('/fees/ledger?status=Unpaid&from=/dashboard'),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isLoading,
    required Widget valueWidget,
    required String footerText,
    Widget? footerWidget,
    double? progress,
    Color? progressColor,
    VoidCallback? onTap,
  }) {
    final card = _SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (isLoading)
            _buildSkeletonBox(width: 120, height: 34)
          else
            valueWidget,
          const SizedBox(height: 6),
          if (isLoading)
            _buildSkeletonBox(width: 150, height: 12)
          else
            (footerWidget ??
                Text(
                  footerText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                )),
          if (!isLoading && progress != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: progress.clamp(0.0, 1.0).toDouble(),
              ),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : AppDuration.slow,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 3,
                    backgroundColor: AppColors.surfaceSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressColor ?? AppColors.brandPrimary,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Tooltip(
      message: 'Click to view details',
      waitDuration: const Duration(milliseconds: 500),
      child: card,
    );
  }

  /// Scaled KPI value that shrinks to fit narrow cards instead of overflowing.
  Widget _buildKpiValue({
    required String value,
    required double size,
    String? suffix,
    Widget? badge,
    Color? color,
    bool monospace = false,
  }) {
    final style = AppTypography.display.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.05,
      color: color ?? AppColors.textPrimary,
      fontFamily: monospace ? AppTypography.monospace.fontFamily : null,
    );

    // The number owns the full line and scales down when the tile narrows;
    // the unit label drops to its own line so nothing can collide.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, maxLines: 1, style: style),
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(bottom: size * 0.16),
                child: badge,
              ),
            ],
          ],
        ),
        if (suffix != null) ...[
          const SizedBox(height: 2),
          Text(
            suffix,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h3.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusPill({
    required String text,
    required Color background,
    required Color foreground,
    required Color border,
    double fontSize = 11,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: AppTypography.label.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds the compact Quick Actions bar as a fluid button grid.
  Widget _buildQuickActionsBar(_DashboardLayout layout) {
    final columns = layout.quickColumns;
    const gap = 8.0;
    // 28 = horizontal padding, 2 = card border; keeps a full row from wrapping.
    final innerWidth = layout.contentWidth - 30.0;
    final buttonWidth = ((innerWidth - gap * (columns - 1)) / columns)
        .floorToDouble();

    final buttons = <Widget>[
      _QuickAction(
        width: buttonWidth,
        label: '+ New Admission (Ctrl+N)',
        icon: Icons.person_add_alt_outlined,
        primary: true,
        onPressed: () => context.go('/students/new?from=/dashboard'),
      ),
      _QuickAction(
        width: buttonWidth,
        label: 'Collect Fee',
        icon: Icons.payments_outlined,
        primary: true,
        onPressed: () => context.go('/fees/receipts?from=dashboard'),
      ),
      _QuickAction(
        width: buttonWidth,
        label: 'Mark Roll Call',
        icon: Icons.check_circle_outlined,
        primary: false,
        onPressed: () => context.go('/attendance?from=/dashboard'),
      ),
      _QuickAction(
        width: buttonWidth,
        label: 'Batch Voucher',
        icon: Icons.receipt_long_outlined,
        primary: false,
        onPressed: () => context.go('/fees/vouchers?from=/dashboard'),
      ),
    ];

    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'QUICK ACTIONS',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: buttons,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOWER WORKSPACE
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds the lower workspace. Wide viewports get a drag-resizable two-pane
  /// split; narrower ones stack the cards.
  Widget _buildLowerWorkspace({
    required _DashboardLayout layout,
    required DashboardMetrics? metrics,
    required bool isLoading,
    required NumberFormat currencyFormatter,
    required bool fillHeight,
  }) {
    final recentPayments = _buildRecentPaymentsCard(
      layout: layout,
      metrics: metrics,
      isLoading: isLoading,
      currencyFormatter: currencyFormatter,
      fillHeight: fillHeight,
    );
    final classStrength = _buildClassStrengthCard(
      layout: layout,
      metrics: metrics,
      isLoading: isLoading,
      currencyFormatter: currencyFormatter,
      fillHeight: fillHeight,
    );

    if (!layout.twoPane) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          recentPayments,
          SizedBox(height: layout.gutter),
          classStrength,
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const handleWidth = 12.0;
        final available = constraints.maxWidth - handleWidth;
        if (available < 760) {
          // Safety net: never let the split starve a panel.
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA CARDS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRecentPaymentsCard({
    required _DashboardLayout layout,
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
      );
      body = fillHeight ? SingleChildScrollView(child: table) : table;
    }

    return _buildDataCard(
      icon: Icons.receipt_long_outlined,
      iconColor: AppColors.chartBlue,
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
    required _DashboardLayout layout,
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
      );
      body = fillHeight ? SingleChildScrollView(child: table) : table;
    }

    return _buildDataCard(
      icon: Icons.class_outlined,
      iconColor: AppColors.chartAmber,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                TextButton(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
  // PRIMITIVES
  // ─────────────────────────────────────────────────────────────────────────

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

  Widget _buildTableCell(String text, {required TextStyle style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }

  /// Lets a dense table scroll horizontally instead of crushing its columns.
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

// ───────────────────────────────────────────────────────────────────────────
// SHARED DASHBOARD WIDGETS
// ───────────────────────────────────────────────────────────────────────────

/// One card style for the whole dashboard: same radius, border, shadow and
/// hover response. Interactive cards lift 2px and warm their border.
class _SurfaceCard extends StatefulWidget {
  const _SurfaceCard({
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

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

    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: _interactive ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
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
      ),
    );
  }
}

/// Draggable handle between the two lower dashboard panes.
class _SplitHandle extends StatefulWidget {
  const _SplitHandle({super.key, required this.onDrag, required this.onReset});

  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  State<_SplitHandle> createState() => _SplitHandleState();
}

class _SplitHandleState extends State<_SplitHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onDoubleTap: widget.onReset,
        child: Tooltip(
          message: 'Drag to resize · double-click to reset',
          waitDuration: const Duration(milliseconds: 500),
          child: Center(
            child: AnimatedContainer(
              duration: reduceMotion ? Duration.zero : AppDuration.fast,
              width: _hovered ? 4 : 2,
              height: _hovered ? 56 : 44,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppColors.brandPrimary
                    : AppColors.borderHover,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single quick-action button that respects the responsive grid width.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.width,
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final double width;
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return SizedBox(
      width: width,
      height: 42,
      child: primary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.textOnPrimary,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: AppElevation.flat,
                animationDuration: AppDuration.fast,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderDefault),
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                animationDuration: AppDuration.fast,
              ),
              child: child,
            ),
    );
  }
}
