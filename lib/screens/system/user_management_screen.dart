import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/permission_matrix_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/user_management_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/input_formatters.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/user.dart';
import '../../widgets/mobile/mobile_kpi_card.dart';
import '../../widgets/mobile/mobile_status_pill.dart';

/// Screen 3: User Management Screen (/system/users).
/// Master-detail administrative control over all school software operators.
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _desigController = TextEditingController();
  final _cnicController = TextEditingController();
  final _pwdController = TextEditingController();
  final _mobile1Controller = TextEditingController();
  final _mobile2Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _remarksController = TextEditingController();

  bool _obscurePassword = true;
  String? _selectedBranch;
  int _userLevel = 2;
  bool _isActive = true;
  int? _lastSyncedUserId;
  bool _lastSyncedCreatingNew = false;

  final FocusNode _nameFocusNode = FocusNode();
  final ScrollController _formScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userManagementProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _desigController.dispose();
    _cnicController.dispose();
    _pwdController.dispose();
    _mobile1Controller.dispose();
    _mobile2Controller.dispose();
    _addressController.dispose();
    _remarksController.dispose();
    _nameFocusNode.dispose();
    _formScrollController.dispose();
    super.dispose();
  }

  void _syncForm(UserManagementState state) {
    if (state.isCreatingNew) {
      if (!_lastSyncedCreatingNew) {
        _lastSyncedCreatingNew = true;
        _lastSyncedUserId = null;
        _nameController.clear();
        _desigController.clear();
        _cnicController.clear();
        _pwdController.clear();
        _mobile1Controller.clear();
        _mobile2Controller.clear();
        _addressController.clear();
        _remarksController.clear();
        _userLevel = 2; // Default to Level 2 (Operator) per spec
        _isActive = true;
        _selectedBranch = state.branches.isNotEmpty
            ? state.branches.first
            : 'Management';
      }
      return;
    }

    final user = state.selectedUser;
    if (user != null &&
        (_lastSyncedUserId != user.id || _lastSyncedCreatingNew)) {
      _lastSyncedCreatingNew = false;
      _lastSyncedUserId = user.id;
      _nameController.text = user.name;
      _desigController.text = user.designation ?? '';
      _cnicController.text = user.cnic ?? '';
      _pwdController.clear();
      _mobile1Controller.text = user.mobile1 ?? '';
      _mobile2Controller.text = user.mobile2 ?? '';
      _addressController.text = user.address ?? '';
      _remarksController.text = user.remarks ?? '';
      _userLevel = user.userLevel;
      _isActive = user.isActive;
      _selectedBranch =
          user.branch ??
          (state.branches.isNotEmpty ? state.branches.first : 'Management');
    }
  }

  Future<void> _submitForm() async {
    final notifier = ref.read(userManagementProvider.notifier);
    final currentSession = ref.read(sessionProvider);

    await notifier.saveUser(
      name: _nameController.text,
      designation: _desigController.text,
      cnic: _cnicController.text,
      rawPassword: _pwdController.text,
      branch: _selectedBranch,
      address: _addressController.text,
      mobile1: _mobile1Controller.text,
      mobile2: _mobile2Controller.text,
      userLevel: _userLevel,
      isActive: _isActive,
      remarks: _remarksController.text,
      currentLoggedInUserId: currentSession?.user.id,
    );
  }

  Future<void> _confirmDeactivate(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Operator Account'),
        content: Text(
          'Are you sure you want to deactivate operator ${user.name}? They will not be able to log in until reactivated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusErrorText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final currentSession = ref.read(sessionProvider);
      await ref
          .read(userManagementProvider.notifier)
          .deactivateUser(
            user.id,
            currentLoggedInUserId: currentSession?.user.id,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userManagementProvider);
    final notifier = ref.read(userManagementProvider.notifier);

    // Sync form whenever selectedUser or isCreatingNew changes
    ref.listen<UserManagementState>(userManagementProvider, (prev, next) {
      if (next.toast != null && next.toast != prev?.toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            backgroundColor: AppColors.statusSuccessText,
            duration: const Duration(seconds: 3),
          ),
        );
        notifier.clearToast();
      }

      if (next.selectedUser != prev?.selectedUser ||
          next.isCreatingNew != prev?.isCreatingNew) {
        setState(() {
          _syncForm(next);
        });

        if (next.isCreatingNew && prev?.isCreatingNew != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _nameFocusNode.requestFocus();
            }
          });
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _formScrollController.hasClients) {
            _formScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // Make sure initial form state is synced when user list first loads
    if (state.selectedUser != null &&
        _lastSyncedUserId != state.selectedUser!.id &&
        !state.isCreatingNew) {
      _syncForm(state);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _submitForm,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            notifier.startNewUser,
      },
      child: Focus(
        autofocus: true,
        child: ResponsiveBreakpoints.isMobile(context)
            ? _buildMobileLayout(context, state, notifier)
            : Scaffold(
                backgroundColor: AppColors.surface,
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Pane (Master, 55% width)
                    Expanded(
                      flex: 55,
                      child: _buildMasterPane(context, state, notifier),
                    ),

                    // Pane Divider
                    Container(width: 1.0, color: AppColors.borderDefault),

                    // Right Pane (Detail, 45% width)
                    Expanded(
                      flex: 45,
                      child: _buildDetailPane(context, state, notifier),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMasterPane(
    BuildContext context,
    UserManagementState state,
    UserManagementNotifier notifier,
  ) {
    final filtered = state.filteredUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceRaised,
            border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'OPERATOR DIRECTORY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h3.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.0,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Text(
                  '${state.users.length}',
                  style: AppTypography.monospace.copyWith(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Settings'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                ),
                onPressed: () => context.go('/system/settings'),
              ),
              const SizedBox(width: AppSpacing.xs),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('New User (Ctrl+N)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 8.0,
                  ),
                ),
                onPressed: notifier.startNewUser,
              ),
            ],
          ),
        ),

        // Search Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: AppColors.surfaceRaised,
          child: TextField(
            controller: _searchController,
            onChanged: notifier.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Filter users by name or designation...',
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppColors.textMuted,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        notifier.setSearchQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 8.0,
              ),
              isDense: true,
            ),
          ),
        ),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8.0,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            border: Border(
              top: BorderSide(color: AppColors.borderDefault),
              bottom: BorderSide(color: AppColors.borderDefault),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48.0,
                child: Text(
                  'ID',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Name',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Role / Designation',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Mobile',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 80.0,
                child: Text(
                  'Status',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Operator List Table Body
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? Center(
                  child: Text(
                    'No operators match search criteria',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    final isSelected =
                        !state.isCreatingNew &&
                        state.selectedUser?.id == user.id;

                    return Material(
                      color: isSelected
                          ? AppColors.brandPrimary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => notifier.selectUser(user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: const BorderSide(
                                color: AppColors.borderSubtle,
                              ),
                              left: isSelected
                                  ? const BorderSide(
                                      color: AppColors.brandPrimary,
                                      width: 3.0,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            children: [
                              // ID
                              SizedBox(
                                width: 48.0,
                                child: Text(
                                  '#${user.id}',
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 12.0,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),

                              // Name
                              Expanded(
                                flex: 3,
                                child: Text(
                                  user.name,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.brandPrimary
                                        : AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Role & Designation
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    _buildRoleBadge(user.userLevel),
                                    if (user.designation != null &&
                                        user.designation!.isNotEmpty) ...[
                                      const SizedBox(width: 6.0),
                                      Flexible(
                                        child: Text(
                                          user.designation!,
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Mobile
                              Expanded(
                                flex: 2,
                                child: Text(
                                  user.mobile1 ?? '—',
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 12.0,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Status Badge
                              SizedBox(
                                width: 80.0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 3.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.isActive
                                          ? AppColors.statusSuccessBg
                                          : AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      border: Border.all(
                                        color: user.isActive
                                            ? AppColors.statusSuccessBorder
                                            : AppColors.borderDefault,
                                      ),
                                    ),
                                    child: Text(
                                      user.isActive ? 'Active' : 'Inactive',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11.0,
                                        color: user.isActive
                                            ? AppColors.statusSuccessText
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(int level) {
    final label = level == 1
        ? 'Admin'
        : level == 2
        ? 'Operator'
        : 'Guest';
    final color = level == 1
        ? AppColors.brandPrimary
        : level == 2
        ? AppColors.brandSecondary
        : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailPane(
    BuildContext context,
    UserManagementState state,
    UserManagementNotifier notifier,
  ) {
    final user = state.selectedUser;
    final isNew = state.isCreatingNew;

    // Build branch items list guaranteeing selected branch is present
    final branchItems = <String>{...state.branches};
    if (_selectedBranch != null && _selectedBranch!.trim().isNotEmpty) {
      branchItems.add(_selectedBranch!.trim());
    }

    final initialBranchVal = branchItems.contains(_selectedBranch)
        ? _selectedBranch
        : (branchItems.isNotEmpty ? branchItems.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isNew
                ? AppColors.brandPrimary.withValues(alpha: 0.08)
                : AppColors.surfaceRaised,
            border: isNew
                ? Border.all(color: AppColors.brandPrimary, width: 1.0)
                : const Border(
                    bottom: BorderSide(color: AppColors.borderDefault),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isNew
                      ? 'NEW OPERATOR ACCOUNT'
                      : 'OPERATOR DETAILS (ID: #${user?.id ?? 0} - ${user?.name ?? ''})',
                  style: AppTypography.h3.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.0,
                    color: isNew
                        ? AppColors.brandPrimary
                        : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isNew && user != null) ...[
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.security, size: 16),
                  label: const Text('Permissions Matrix'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                  ),
                  onPressed: () {
                    ref.read(selectedPermissionUserIdProvider.notifier).state =
                        user.id;
                    context.go('/system/permissions');
                  },
                ),
              ],
            ],
          ),
        ),

        // Inline Error Banner
        if (state.errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8.0,
            ),
            color: AppColors.statusErrorBg,
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: AppColors.statusErrorText,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusErrorText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.statusErrorText,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: notifier.clearErrorMessage,
                ),
              ],
            ),
          ),

        // Scrollable Form Fields
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: SingleChildScrollView(
              key: ValueKey(
                '${state.isCreatingNew}-${state.selectedUser?.id ?? "new"}',
              ),
              controller: _formScrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: Account Name * + Designation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'Account Name *',
                          controller: _nameController,
                          hint: 'Unique login username',
                          focusNode: _nameFocusNode,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildFormField(
                          label: 'Designation',
                          controller: _desigController,
                          hint: 'e.g. Principal / Accountant',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Row 2: National CNIC + Branch Identifier
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'National CNIC',
                          controller: _cnicController,
                          hint: 'XXXXX-XXXXXXX-X',
                          inputFormatters: const [CnicInputFormatter()],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Branch Identifier',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            DropdownButtonFormField<String>(
                              key: ValueKey(initialBranchVal),
                              initialValue: initialBranchVal,
                              isExpanded: true,
                              menuMaxHeight: 400,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 8.0,
                                ),
                              ),
                              items: branchItems.map((b) {
                                return DropdownMenuItem<String>(
                                  value: b,
                                  child: Text(
                                    b,
                                    style: AppTypography.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedBranch = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Row 3: Primary Mobile + Secondary Mobile
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'Primary Mobile',
                          controller: _mobile1Controller,
                          hint: '03XX-XXXXXXX',
                          inputFormatters: const [MobileInputFormatter()],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildFormField(
                          label: 'Secondary Mobile',
                          controller: _mobile2Controller,
                          hint: '03XX-XXXXXXX',
                          inputFormatters: const [MobileInputFormatter()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Row 4: Password * + Account Active Switch
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password *',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            TextField(
                              controller: _pwdController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: isNew
                                    ? 'Enter initial password (min 8 chars)'
                                    : '•••••••• (Leave blank to keep existing)',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 8.0,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Status',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Container(
                              height: 38.0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _isActive
                                          ? 'Active (Can Log In)'
                                          : 'Inactive',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: _isActive
                                            ? AppColors.statusSuccessText
                                            : AppColors.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Switch(
                                    value: _isActive,
                                    activeThumbColor: AppColors.brandPrimary,
                                    onChanged: (val) {
                                      setState(() {
                                        _isActive = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Row 5: User Role Level * (Radio Group)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Role Level *',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildRadioOption('Level 1 (Admin)', 1),
                            ),
                            Expanded(
                              child: _buildRadioOption('Level 2 (Operator)', 2),
                            ),
                            Expanded(
                              child: _buildRadioOption('Level 3 (Guest)', 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Row 6: Residential Address
                  _buildFormField(
                    label: 'Residential Address',
                    controller: _addressController,
                    hint: 'Mailing / residential street address',
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Row 7: Remarks / Internal Notes
                  _buildFormField(
                    label: 'Remarks / Internal Notes',
                    controller: _remarksController,
                    hint:
                        'Account notes, authorization details, or legacy memo',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Pinned Bottom Action Bar (min 52px height; wraps when narrow)
        Container(
          constraints: const BoxConstraints(minHeight: 52.0),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6.0,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceRaised,
            border: Border(top: BorderSide(color: AppColors.borderDefault)),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Deactivate User Button
              if (!isNew && user != null && user.isActive)
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_off, size: 16),
                  label: const Text('Deactivate User'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusErrorText,
                    side: const BorderSide(color: AppColors.statusErrorBorder),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                  ),
                  onPressed: () => _confirmDeactivate(user),
                ),

              // Cancel Button
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _syncForm(state);
                  });
                },
                child: const Text('Cancel'),
              ),

              // Save User CTA
              ElevatedButton.icon(
                icon: state.isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 16),
                label: const Text('Save User (Ctrl+S)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                ),
                onPressed: state.isSaving ? null : _submitForm,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadioOption(String label, int value) {
    final isSelected = _userLevel == value;
    return InkWell(
      onTap: () {
        setState(() {
          _userLevel = value;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14.0,
              height: 14.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.brandPrimary
                      : AppColors.borderDefault,
                  width: isSelected ? 4.0 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6.0),
            Flexible(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 11.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4.0),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8.0,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MOBILE BRANCH (< 600px)
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    UserManagementState state,
    UserManagementNotifier notifier,
  ) {
    final totalUsers = state.users.length;
    final adminUsers = state.users.where((u) => u.userLevel == 1).length;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _formScrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMobileHeader(
                      context,
                      state,
                      notifier,
                      totalUsers,
                      adminUsers,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileSearchBar(notifier),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _buildMobileErrorBanner(state.errorMessage!, notifier),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileOperatorList(context, state, notifier),
                    const SizedBox(height: AppSpacing.md),
                    _buildMobileDetailForm(context, state, notifier),
                  ],
                ),
              ),
            ),
            _buildMobileStickyActions(context, state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    UserManagementState state,
    UserManagementNotifier notifier,
    int totalUsers,
    int adminUsers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'OPERATOR DIRECTORY',
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: MobileKpiCard(
                label: 'TOTAL OPERATORS',
                value: '$totalUsers Accounts',
                icon: Icons.people_outline,
                accentColor: AppColors.accentDashboard,
                accentSoftBg: AppColors.accentDashboardSoftBg,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MobileKpiCard(
                label: 'SUPERADMINS',
                value: '$adminUsers Level 1',
                icon: Icons.admin_panel_settings_outlined,
                accentColor: AppColors.accentDashboard,
                accentSoftBg: AppColors.accentDashboardSoftBg,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileSearchBar(UserManagementNotifier notifier) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search operators by name or designation...',
          hintStyle: AppTypography.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _searchController.clear();
                    notifier.setSearchQuery('');
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
        ),
        onChanged: (v) {
          notifier.setSearchQuery(v);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildMobileErrorBanner(
    String message,
    UserManagementNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 8.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.statusErrorBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.statusErrorText.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.statusErrorText,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.statusErrorText,
            ),
            splashRadius: 12,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: notifier.clearErrorMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileOperatorList(
    BuildContext context,
    UserManagementState state,
    UserManagementNotifier notifier,
  ) {
    final users = state.filteredUsers;
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'No operators match search criteria',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (ctx, idx) {
        final u = users[idx];
        final isSelected =
            !state.isCreatingNew && state.selectedUser?.id == u.id;
        final initials = u.name.trim().isNotEmpty
            ? u.name
                .trim()
                .split(' ')
                .map((s) => s.isNotEmpty ? s[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : 'U';
        final levelLabel = u.userLevel == 1
            ? 'SuperAdmin'
            : (u.userLevel == 2 ? 'Operator' : 'Reader');

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: isSelected
                  ? AppColors.accentDashboard
                  : AppColors.borderDefault,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          elevation: 0,
          color: isSelected
              ? AppColors.accentDashboardSoftBg
              : AppColors.surfaceRaised,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3.5,
                  color: isSelected
                      ? AppColors.accentDashboard
                      : Colors.transparent,
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () {
                      notifier.selectUser(u);
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected
                                ? AppColors.accentDashboard
                                : AppColors.accentDashboardSoftBg,
                            child: Text(
                              initials,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.accentDashboard,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  u.name,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  u.designation?.isNotEmpty == true
                                      ? u.designation!
                                      : '—',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          MobileStatusPill(
                            label: levelLabel,
                            variant: u.userLevel == 1
                                ? MobileStatusVariant.info
                                : (u.userLevel == 2
                                    ? MobileStatusVariant.success
                                    : MobileStatusVariant.neutral),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDetailForm(
    BuildContext context,
    UserManagementState state,
    UserManagementNotifier notifier,
  ) {
    final title = state.isCreatingNew
        ? 'NEW OPERATOR ACCOUNT'
        : 'OPERATOR DETAILS (#${state.selectedUser?.id ?? ""})';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Name
          _buildMobileFormFieldLabel('Full Name *'),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('Operator full name'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Designation
          _buildMobileFormFieldLabel('Designation / Job Title'),
          const SizedBox(height: 4),
          TextField(
            controller: _desigController,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('e.g. Accounts Officer'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // CNIC
          _buildMobileFormFieldLabel('National Identity Card (CNIC)'),
          const SizedBox(height: 4),
          TextField(
            controller: _cnicController,
            inputFormatters: const [CnicInputFormatter()],
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('38302-XXXXXXX-X'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Password
          _buildMobileFormFieldLabel(
            state.isCreatingNew
                ? 'Initial Password *'
                : 'Reset Password (leave empty to retain)',
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _pwdController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('Enter password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // User Level Dropdown
          _buildMobileFormFieldLabel('Access Authorization Level *'),
          const SizedBox(height: 4),
          Container(
            height: 44,
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _userLevel,
                isExpanded: true,
                isDense: true,
                dropdownColor: AppColors.surfaceRaised,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                selectedItemBuilder: (ctx) => [
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Level 1 - Administrator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Level 2 - Operator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Level 3 - Reader',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('Level 1 - Administrator (Full System Control)'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('Level 2 - Standard Operator (Access Matrix)'),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('Level 3 - Read-Only Viewer (No Mutations)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _userLevel = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Phones
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMobileFormFieldLabel('Primary Mobile'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _mobile1Controller,
                      inputFormatters: const [MobileInputFormatter()],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: _mobileInputDecoration('03XX-XXXXXXX'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMobileFormFieldLabel('Secondary Mobile'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _mobile2Controller,
                      inputFormatters: const [MobileInputFormatter()],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: _mobileInputDecoration('Optional'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Address
          _buildMobileFormFieldLabel('Residential Address'),
          const SizedBox(height: 4),
          TextField(
            controller: _addressController,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('House / street details'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Branch Dropdown
          _buildMobileFormFieldLabel('Operational Branch Assignment'),
          const SizedBox(height: 4),
          Container(
            height: 44,
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.branches.contains(_selectedBranch)
                    ? _selectedBranch
                    : (state.branches.isNotEmpty ? state.branches.first : null),
                isExpanded: true,
                isDense: true,
                dropdownColor: AppColors.surfaceRaised,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                selectedItemBuilder: (ctx) => state.branches.map((b) {
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      b,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                items: state.branches.map((b) {
                  return DropdownMenuItem(
                    value: b,
                    child: Text(b),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedBranch = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Active Status Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Status',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Switch(
                value: _isActive,
                activeThumbColor: AppColors.accentDashboard,
                onChanged: (val) {
                  setState(() {
                    _isActive = val;
                  });
                },
              ),
            ],
          ),

          if (!state.isCreatingNew && state.selectedUser != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(selectedPermissionUserIdProvider.notifier).state =
                      state.selectedUser!.id;
                  context.go('/system/permissions');
                },
                icon: const Icon(Icons.security, size: 16),
                label: const Text('Configure Permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentDashboard,
                  foregroundColor: AppColors.textOnPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileFormFieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  InputDecoration _mobileInputDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppTypography.bodySmall.copyWith(
        color: AppColors.textMuted,
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
    );
  }

  Widget _buildMobileStickyActions(
    BuildContext context,
    UserManagementState state,
    UserManagementNotifier notifier,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: notifier.startNewUser,
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text(
                  'New User (Ctrl+N)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: state.isSaving ? null : _submitForm,
                icon: state.isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: const Text(
                  'Save User (Ctrl+S)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentDashboard,
                  foregroundColor: AppColors.textOnPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
