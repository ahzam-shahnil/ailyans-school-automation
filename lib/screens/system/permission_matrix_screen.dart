import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/permission_matrix_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/access_object.dart';
import '../../widgets/mobile/mobile_kpi_card.dart';
import '../../widgets/mobile/mobile_status_pill.dart';

/// Screen 4: Permission Matrix Screen (/system/permissions).
/// Granular role-independent module authorization matrix for operators.
class PermissionMatrixScreen extends ConsumerStatefulWidget {
  const PermissionMatrixScreen({super.key});

  @override
  ConsumerState<PermissionMatrixScreen> createState() =>
      _PermissionMatrixScreenState();
}

class _PermissionMatrixScreenState
    extends ConsumerState<PermissionMatrixScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetId = ref.read(selectedPermissionUserIdProvider) ?? 1;
      ref.read(permissionMatrixProvider.notifier).loadForUser(targetId);
    });
  }

  Future<void> _saveRights() async {
    final state = ref.read(permissionMatrixProvider);
    final notifier = ref.read(permissionMatrixProvider.notifier);

    // If 0 modules are selected, confirm with warning dialog
    if (state.selectedObjIds.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm No Access'),
          content: const Text(
            'User will have no access to any module. Proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final success = await notifier.saveRights();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User Rights updated successfully'),
          backgroundColor: AppColors.statusSuccessText,
          duration: Duration(seconds: 3),
        ),
      );
      context.go('/system/users');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(permissionMatrixProvider);
    final notifier = ref.read(permissionMatrixProvider.notifier);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveRights,
      },
      child: Focus(
        autofocus: true,
        child: ResponsiveBreakpoints.isMobile(context)
            ? _buildMobileLayout(context, state, notifier)
            : Scaffold(
                backgroundColor: AppColors.surface,
                body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceRaised,
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Users'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                      ),
                      onPressed: () => context.go('/system/users'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'USER ACCESS CONTROL MATRIX',
                            style: AppTypography.h3.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.0,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            'Operator: ${state.targetUserName}  |  Designation: ${state.targetUserDesignation}  |  Role: Level ${state.targetUserLevel}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Summary Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.brandPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '${state.selectedObjIds.length} of ${state.allModules.length} Modules Authorized',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                      ),
                      onPressed: notifier.selectAll,
                      child: const Text('Select All'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                      ),
                      onPressed: notifier.deselectAll,
                      child: const Text('Deselect All'),
                    ),
                  ],
                ),
              ),

              // Inline Error Message
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

              // Category Checklist Area (Internal Scroll)
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Column 1: Categories 1, 2, 3
                            Expanded(
                              child: Column(
                                children: [
                                  _buildCategoryCard(
                                    moduleCategories[0],
                                    state,
                                    notifier,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _buildCategoryCard(
                                    moduleCategories[1],
                                    state,
                                    notifier,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _buildCategoryCard(
                                    moduleCategories[2],
                                    state,
                                    notifier,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),

                            // Column 2: Categories 4, 5, 6
                            Expanded(
                              child: Column(
                                children: [
                                  _buildCategoryCard(
                                    moduleCategories[3],
                                    state,
                                    notifier,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _buildCategoryCard(
                                    moduleCategories[4],
                                    state,
                                    notifier,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _buildCategoryCard(
                                    moduleCategories[5],
                                    state,
                                    notifier,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Pinned Bottom Action Bar (52px height)
              Container(
                height: 52.0,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceRaised,
                  border: Border(
                    top: BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => context.go('/system/users'),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
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
                      label: const Text('Save Access Rights (Ctrl+S)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                      ),
                      onPressed: state.isSaving ? null : _saveRights,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    ModuleCategory category,
    PermissionMatrixState state,
    PermissionMatrixNotifier notifier,
  ) {
    final modules = state.allModules
        .where((m) => category.objIds.contains(m.objId))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8.0,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.borderDefault),
              ),
            ),
            child: Row(
              children: [
                Text(
                  category.title,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '(${modules.length} Modules)',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Modules list
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              children: modules.map((m) {
                final isChecked = state.selectedObjIds.contains(m.objId);
                return _buildModuleCheckboxRow(m, isChecked, notifier);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCheckboxRow(
    AccessObject module,
    bool isChecked,
    PermissionMatrixNotifier notifier,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => notifier.toggleModule(module.objId),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4.0,
          ),
          child: Row(
            children: [
              Checkbox(
                value: isChecked,
                activeColor: AppColors.brandPrimary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => notifier.toggleModule(module.objId),
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: Text(
                  '${module.displayName} (${module.objName} - #${module.objId})',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                    color: isChecked
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MOBILE BRANCH (< 600px)
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    PermissionMatrixState state,
    PermissionMatrixNotifier notifier,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMobileHeader(context, state, notifier),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileKpiStrip(state),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileBulkActionCard(context, state, notifier),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _buildMobileErrorBanner(state.errorMessage!, notifier),
                    ],
                    if (state.selectedObjIds.isEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _buildMobileZeroAccessWarning(),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileModuleChecklist(state, notifier),
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
    PermissionMatrixState state,
    PermissionMatrixNotifier notifier,
  ) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.go('/system/users'),
          icon: const Icon(Icons.arrow_back, size: 20),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'USER ACCESS CONTROL MATRIX',
                style: AppTypography.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Operator: ${state.targetUserName}  |  Level ${state.targetUserLevel}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileKpiStrip(PermissionMatrixState state) {
    return Row(
      children: [
        Expanded(
          child: MobileKpiCard(
            label: 'AUTHORIZED',
            value: '${state.selectedObjIds.length} Modules',
            icon: Icons.check_circle_outline,
            accentColor: AppColors.accentDashboard,
            accentSoftBg: AppColors.accentDashboardSoftBg,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MobileKpiCard(
            label: 'TOTAL OBJECTS',
            value: '${state.allModules.length} Modules',
            icon: Icons.shield_outlined,
            accentColor: AppColors.accentDashboard,
            accentSoftBg: AppColors.accentDashboardSoftBg,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBulkActionCard(
    BuildContext context,
    PermissionMatrixState state,
    PermissionMatrixNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: notifier.selectAll,
                child: const Text('Select All', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: notifier.deselectAll,
                child: const Text('Deselect All', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: () => context.go('/system/users'),
              child: const Text('Back to Users', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileZeroAccessWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.statusWarningBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.statusWarningText.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.statusWarningText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'User will have no access to any module.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusWarningText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileErrorBanner(
    String message,
    PermissionMatrixNotifier notifier,
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

  Widget _buildMobileModuleChecklist(
    PermissionMatrixState state,
    PermissionMatrixNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: moduleCategories.map((category) {
        final modules = state.allModules
            .where((m) => category.objIds.contains(m.objId))
            .toList();
        if (modules.isEmpty) return const SizedBox.shrink();

        final authorizedCount = modules
            .where((m) => state.selectedObjIds.contains(m.objId))
            .length;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      category.title.toUpperCase(),
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  MobileStatusPill(
                    label: '$authorizedCount / ${modules.length}',
                    variant: authorizedCount == modules.length
                        ? MobileStatusVariant.success
                        : (authorizedCount > 0
                            ? MobileStatusVariant.warning
                            : MobileStatusVariant.neutral),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Divider(height: 1, color: AppColors.borderDefault),
              const SizedBox(height: AppSpacing.xs),
              ...modules.map((m) {
                final isChecked = state.selectedObjIds.contains(m.objId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    side: BorderSide(
                      color: isChecked
                          ? AppColors.accentDashboard.withValues(alpha: 0.4)
                          : AppColors.borderDefault,
                    ),
                  ),
                  elevation: 0,
                  color: isChecked
                      ? AppColors.accentDashboardSoftBg
                      : AppColors.surfaceCanvas,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 3.5,
                          color: isChecked
                              ? AppColors.accentDashboard
                              : Colors.transparent,
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => notifier.toggleModule(m.objId),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          m.displayName,
                                          style: AppTypography.body.copyWith(
                                            fontWeight: isChecked
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '#${m.objId} · ${m.objName}',
                                          style:
                                              AppTypography.monospace.copyWith(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: AppColors.accentDashboard,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (_) =>
                                        notifier.toggleModule(m.objId),
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
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileStickyActions(
    BuildContext context,
    PermissionMatrixState state,
    PermissionMatrixNotifier notifier,
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
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: state.isSaving ? null : _saveRights,
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
            'Save Access Rights (Ctrl+S)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    );
  }
}
