import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../screens/login/change_password_dialog.dart';
import 'app_sidebar.dart';

/// Persistent top bar of the desktop application shell.
class AppTopBar extends ConsumerWidget {
  final FocusNode searchFocusNode;

  const AppTopBar({super.key, required this.searchFocusNode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final metadataAsync = ref.watch(shellMetadataProvider);
    final metadata = metadataAsync.valueOrNull ?? ShellMetadata.empty();

    final currentPath = GoRouterState.of(context).matchedLocation;
    final breadcrumb = _getBreadcrumb(currentPath);

    return Container(
      height: 64.0,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          bottom: BorderSide(color: AppColors.borderDefault, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // 1. Left: Sidebar Toggle, Branch Selector Pill, Breadcrumbs
          _buildLeftSection(context, ref, metadata, breadcrumb),

          const SizedBox(width: AppSpacing.md),

          // 2. Center: Search Input Pill (up to 360px centered)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360.0),
                child: _buildSearchPill(context),
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // 3. Right: Session Badge, Notification Bell, Divider, User Menu
          _buildRightSection(context, ref, metadata, session),
        ],
      ),
    );
  }

  Widget _buildLeftSection(
    BuildContext context,
    WidgetRef ref,
    ShellMetadata metadata,
    String breadcrumb,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.menu, size: 20.0),
          color: AppColors.textPrimary,
          tooltip: 'Toggle Sidebar',
          onPressed: () {
            ref.read(sidebarExpandedProvider.notifier).update((v) => !v);
          },
        ),
        const SizedBox(width: AppSpacing.xs),

        // Branch Selector Pill
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            border: Border.all(color: AppColors.borderDefault),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15.0,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 4.0),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150.0),
                child: Text(
                  'Main Campus',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2.0),
              const Icon(
                Icons.arrow_drop_down,
                size: 16.0,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Contextual Breadcrumbs
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240.0),
          child: Text(
            breadcrumb,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchPill(BuildContext context) {
    return Container(
      height: 38.0,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18.0, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              focusNode: searchFocusNode,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search students, staff, vouchers...',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                isDense: true,
                filled: false,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border.all(color: AppColors.borderDefault),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'Ctrl+K',
              style: AppTypography.monospace.copyWith(
                fontSize: 10.0,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSection(
    BuildContext context,
    WidgetRef ref,
    ShellMetadata metadata,
    UserSession? session,
  ) {
    final userName = session?.user.name ?? 'Guest User';
    final userDesig = session?.user.designation ?? 'Operator';
    final initials = _getInitials(userName);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Session Year Badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.statusInfoBg,
            border: Border.all(color: AppColors.statusInfoBorder),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            metadata.sessionYear,
            style: AppTypography.label.copyWith(
              color: AppColors.statusInfoText,
              fontSize: 12.0,
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.sm),

        // Notification Bell
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, size: 20.0),
          color: AppColors.textSecondary,
          tooltip: 'Notifications',
          onPressed: () {},
        ),

        const SizedBox(
          height: 24.0,
          child: VerticalDivider(
            width: AppSpacing.md,
            thickness: 1.0,
            color: AppColors.borderDefault,
          ),
        ),

        // User Profile Menu
        PopupMenuButton<String>(
          offset: const Offset(0, 48),
          color: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              ref.read(sessionProvider.notifier).clear();
              context.go('/login');
            } else if (value == 'change_password') {
              ChangePasswordDialog.show(context, username: session?.user.name);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    userDesig,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18.0,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Profile Information', style: AppTypography.bodySmall),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'change_password',
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 18.0,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Change Password', style: AppTypography.bodySmall),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(
                    Icons.logout,
                    size: 18.0,
                    color: AppColors.statusErrorText,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Sign Out',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusErrorText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: Row(
            children: [
              CircleAvatar(
                radius: 16.0,
                backgroundColor: AppColors.brandPrimary,
                child: Text(
                  initials,
                  style: AppTypography.label.copyWith(
                    color: AppColors.surfaceRaised,
                    fontSize: 12.0,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    userDesig,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10.0,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 18.0,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getBreadcrumb(String path) {
    if (path == '/dashboard') {
      return 'Home > Dashboard';
    }
    if (path == '/students') {
      return 'Home > Students > Directory';
    }
    if (path == '/students/new') {
      return 'Home > Students > New Admission';
    }
    if (path.startsWith('/students/')) {
      return 'Home > Students > Student Profile';
    }
    if (path.startsWith('/fees/parameters')) {
      return 'Home > Fees > Fee Structure & Bank Setup';
    }
    if (path == '/fees/vouchers') {
      return 'Home > Fees > Voucher Generation';
    }
    if (path == '/fees/receipts') {
      return 'Home > Fees > Fee Collection';
    }
    if (path.startsWith('/academics')) {
      return 'Home > Academics';
    }
    if (path.startsWith('/exams/marks')) {
      return 'Home > Examinations > Marks Entry';
    }
    if (path.startsWith('/exams')) {
      return 'Home > Examinations';
    }
    if (path.startsWith('/attendance')) {
      return 'Home > Attendance';
    }
    if (path.startsWith('/staff')) {
      return 'Home > Staff & Payroll';
    }
    if (path.startsWith('/library')) {
      return 'Home > Library';
    }
    if (path.startsWith('/system')) {
      return 'Home > System Settings';
    }
    return 'Home';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
