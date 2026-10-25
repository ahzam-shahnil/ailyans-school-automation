import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../screens/login/change_password_dialog.dart';
import 'app_sidebar.dart';

/// Provides list of branches configured in the system.
final branchListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
    return const [];
  }
  final db = await DatabaseService.instance.database;
  return await db.rawQuery(
    'SELECT BrnachID, BranchName FROM InstBranch ORDER BY BrnachID ASC',
  );
});

/// Current active branch name selected in the top bar.
final currentBranchProvider = StateProvider<String?>((ref) => null);

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
        _buildBranchPill(context, ref, metadata),

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
            } else if (value == 'profile') {
              _showProfileDialog(context, session);
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
    if (path.startsWith('/system/permissions')) {
      return 'Home > System Administration > User Access Control Matrix';
    }
    if (path.startsWith('/system/users')) {
      return 'Home > System Administration > Operator Accounts';
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

  Widget _buildBranchPill(
    BuildContext context,
    WidgetRef ref,
    ShellMetadata metadata,
  ) {
    final branchListAsync = ref.watch(branchListProvider);
    final branches = branchListAsync.valueOrNull ?? [];
    final currentBranch =
        ref.watch(currentBranchProvider) ??
        (branches.isNotEmpty
            ? (branches.first['BranchName'] as String? ?? metadata.branchName)
            : metadata.branchName);

    // If 1 or 0 branches: read-only chip with tooltip, no arrow
    if (branches.length <= 1) {
      return Tooltip(
        message: 'Single campus configured. Add more branches in Settings to switch.',
        child: Container(
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
                constraints: const BoxConstraints(maxWidth: 160.0),
                child: Text(
                  currentBranch,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2+ branches: interactive PopupMenuButton
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      tooltip: 'Switch Branch',
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      onSelected: (branchName) {
        ref.read(currentBranchProvider.notifier).state = branchName;
      },
      itemBuilder: (context) => branches.map((b) {
        final bName = b['BranchName'] as String? ?? '';
        final isSelected = bName == currentBranch;
        return PopupMenuItem<String>(
          value: bName,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check : Icons.business_outlined,
                size: 16.0,
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8.0),
              Text(
                bName,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isSelected
                      ? AppColors.brandPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
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
              constraints: const BoxConstraints(maxWidth: 160.0),
              child: Text(
                currentBranch,
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
    );
  }

  void _showProfileDialog(BuildContext context, UserSession? session) {
    final user = session?.user;
    if (user == null) return;

    final roleLabel = user.userLevel == 1
        ? 'Admin (Level 1)'
        : user.userLevel == 2
        ? 'Operator (Level 2)'
        : 'Guest (Level 3)';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 20.0,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: 12.0),
            Text(
              'Profile Information',
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SizedBox(
          width: 520.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileRow('Account Name:', user.name, isBold: true),
              _buildProfileRow('Designation:', user.designation ?? '-'),
              _buildProfileRow(
                'National CNIC:',
                user.cnic ?? '-',
                isMono: true,
              ),
              _buildProfileRow('Branch:', user.branch ?? '-'),
              _buildProfileRow(
                'Primary Mobile:',
                user.mobile1 ?? '-',
                isMono: true,
              ),
              _buildProfileRow(
                'Secondary Mobile:',
                user.mobile2 ?? '-',
                isMono: true,
              ),
              _buildProfileRow('Residential Address:', user.address ?? '-'),
              _buildProfileRow('User Role Level:', roleLabel),
              _buildProfileRow(
                'Account Status:',
                user.isActive ? 'Active' : 'Inactive',
                statusColor: user.isActive
                    ? AppColors.statusSuccessText
                    : AppColors.textMuted,
              ),
              _buildProfileRow('Remarks:', user.remarks ?? '-'),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_reset, size: 16),
            label: const Text('Change Password'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ChangePasswordDialog.show(context, username: user.name);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(
    String label,
    String value, {
    bool isBold = false,
    bool isMono = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150.0,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  (isMono ? AppTypography.monospace : AppTypography.bodySmall)
                      .copyWith(
                        fontWeight: isBold
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: statusColor ?? AppColors.textPrimary,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
