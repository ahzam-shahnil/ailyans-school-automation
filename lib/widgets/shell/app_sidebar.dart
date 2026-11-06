import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Riverpod provider managing sidebar expanded vs collapsed rail state.
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

class _NavItemData {
  final String label;
  final String route;
  final IconData icon;
  final List<int> requiredObjIds;
  final int Function(ShellMetadata)? getBadgeCount;

  const _NavItemData({
    required this.label,
    required this.route,
    required this.icon,
    this.requiredObjIds = const [],
    this.getBadgeCount,
  });
}

/// Persistent left navigation sidebar / rail.
class AppSidebar extends ConsumerWidget {
  /// When true the sidebar is rendered inside a mobile [Drawer]: it is always
  /// expanded, uses the wider drawer width, and hides the collapse toggle.
  final bool asDrawer;

  const AppSidebar({super.key, this.asDrawer = false});

  static const List<_NavItemData> _navItems = [
    _NavItemData(
      label: 'Dashboard',
      route: '/dashboard',
      icon: Icons.dashboard_outlined,
      requiredObjIds: [1],
    ),
    _NavItemData(
      label: 'Students',
      route: '/students',
      icon: Icons.people_outline,
      requiredObjIds: [8, 9, 11, 12, 13, 20, 26],
      getBadgeCount: _getStudentCount,
    ),
    _NavItemData(
      label: 'Academics',
      route: '/academics/classes',
      icon: Icons.menu_book_outlined,
      requiredObjIds: [4],
      getBadgeCount: _getClassCount,
    ),
    _NavItemData(
      label: 'Fees & Billing',
      route: '/fees/vouchers',
      icon: Icons.payments_outlined,
      requiredObjIds: [16, 17, 18, 19, 21],
      getBadgeCount: _getPendingVoucherCount,
    ),
    _NavItemData(
      label: 'Examinations',
      route: '/exams',
      icon: Icons.assignment_outlined,
      requiredObjIds: [10, 23, 24],
    ),
    _NavItemData(
      label: 'Attendance',
      route: '/attendance',
      icon: Icons.check_circle_outline,
      requiredObjIds: [2, 28],
    ),
    _NavItemData(
      label: 'Staff & Payroll',
      route: '/staff/teachers',
      icon: Icons.badge_outlined,
      requiredObjIds: [14, 22, 29],
      getBadgeCount: _getStaffCount,
    ),
    _NavItemData(
      label: 'Library',
      route: '/library',
      icon: Icons.local_library_outlined,
      requiredObjIds: [3],
    ),
  ];

  static int _getStudentCount(ShellMetadata m) => m.studentCount;
  static int _getClassCount(ShellMetadata m) => m.classCount;
  static int _getPendingVoucherCount(ShellMetadata m) => m.pendingVouchers;
  static int _getStaffCount(ShellMetadata m) => m.staffCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = asDrawer || ref.watch(sidebarExpandedProvider);
    final session = ref.watch(sessionProvider);
    final metadataAsync = ref.watch(shellMetadataProvider);
    final metadata = metadataAsync.valueOrNull ?? ShellMetadata.empty();

    String currentPath;
    try {
      currentPath = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      currentPath = '/dashboard';
    }

    return AnimatedContainer(
      duration: AppDuration.fast,
      width: asDrawer ? 280.0 : (isExpanded ? 240.0 : 68.0),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          right: BorderSide(color: AppColors.borderDefault, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Brand Header
          _buildBrandHeader(isExpanded),
          const Divider(height: 1.0, color: AppColors.borderDefault),

          // 2. Navigation Items (8 Groups)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              children: [
                for (final item in _navItems)
                  if (_isAllowed(session, item.requiredObjIds))
                    _buildNavItem(
                      context: context,
                      item: item,
                      isExpanded: isExpanded,
                      isActive: _isRouteActive(currentPath, item.route),
                      badgeCount: item.getBadgeCount?.call(metadata) ?? 0,
                    ),
              ],
            ),
          ),

          const Divider(height: 1.0, color: AppColors.borderDefault),

          // 3. Footer: System Settings & Rail Collapse Toggle
          if (session == null || session.user.userLevel == 1)
            _buildNavItem(
              context: context,
              item: const _NavItemData(
                label: 'System Settings',
                route: '/system/settings',
                icon: Icons.settings_outlined,
                requiredObjIds: [],
              ),
              isExpanded: isExpanded,
              isActive: _isRouteActive(currentPath, '/system'),
              badgeCount: 0,
            ),

          if (!asDrawer) _buildCollapseToggle(ref, isExpanded),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(bool isExpanded) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCollapsed = constraints.maxWidth < 60 || !isExpanded;
        return Container(
          height: 64.0,
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0.0 : AppSpacing.sm,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.school,
                  color: AppColors.surfaceRaised,
                  size: 20.0,
                ),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ailyans School',
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Automation v2.0',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required _NavItemData item,
    required bool isExpanded,
    required bool isActive,
    required int badgeCount,
  }) {
    final itemWidget = InkWell(
      onTap: () {
        if (asDrawer) {
          Navigator.of(context).maybePop();
        }
        context.go(item.route);
      },
      child: Container(
        height: 44.0,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2.0,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.brandPrimary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCollapsed = !isExpanded || constraints.maxWidth <= 60;
            return Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              mainAxisSize: isCollapsed ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Active left indicator bar (3px when active, 0px when inactive)
                SizedBox(
                  width: isActive ? 3.0 : 0.0,
                  height: 24.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.brandPrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                if (!isCollapsed) const SizedBox(width: AppSpacing.xs),
                // Icon (fixed 20px)
                Icon(
                  item.icon,
                  size: 20.0,
                  color: isActive
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTypography.label.copyWith(
                        color: isActive
                            ? AppColors.brandPrimary
                            : AppColors.textPrimary,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7.0,
                        vertical: 2.0,
                      ),
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.brandPrimary
                            : AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: AppTypography.bodySmall.copyWith(
                          color: isActive
                              ? AppColors.surfaceRaised
                              : AppColors.textSecondary,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );

    if (!isExpanded) {
      return Tooltip(
        message: badgeCount > 0 ? '${item.label} ($badgeCount)' : item.label,
        waitDuration: AppDuration.fast,
        child: itemWidget,
      );
    }

    return itemWidget;
  }

  Widget _buildCollapseToggle(WidgetRef ref, bool isExpanded) {
    return InkWell(
      onTap: () {
        ref.read(sidebarExpandedProvider.notifier).state = !isExpanded;
      },
      child: Container(
        height: 44.0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: isExpanded
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(
              isExpanded ? Icons.menu_open : Icons.menu,
              size: 18.0,
              color: AppColors.textSecondary,
            ),
            if (isExpanded) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Collapse Sidebar',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isRouteActive(String currentPath, String itemRoute) {
    if (itemRoute == '/dashboard') {
      return currentPath == '/dashboard';
    }
    if (itemRoute.startsWith('/academics')) {
      return currentPath.startsWith('/academics');
    }
    if (itemRoute.startsWith('/fees')) {
      return currentPath.startsWith('/fees');
    }
    if (itemRoute.startsWith('/staff')) {
      return currentPath.startsWith('/staff');
    }
    return currentPath.startsWith(itemRoute);
  }

  bool _isAllowed(UserSession? session, List<int> requiredObjIds) {
    if (session == null) return true;
    if (session.user.userLevel == 1) return true;
    if (requiredObjIds.isEmpty) return false;
    return requiredObjIds.any((id) => session.allowedObjIds.contains(id));
  }
}

/// Mobile slide-out navigation drawer wrapping [AppSidebar] in drawer mode.
class MobileDrawer extends StatelessWidget {
  const MobileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(
      width: 280,
      child: SafeArea(child: AppSidebar(asDrawer: true)),
    );
  }
}
