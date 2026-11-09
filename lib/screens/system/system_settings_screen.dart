import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/db/backup_service.dart';
import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/backup_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/system_settings_provider.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';

/// Screen 27: System Settings & Configuration Screen (/system/settings).
/// Consolidates legacy Win32 utility dialogs into a unified 4-tab admin workstation.
/// Restricted to SuperAdmin (userLevel == 1) only.
class SystemSettingsScreen extends ConsumerStatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  ConsumerState<SystemSettingsScreen> createState() =>
      _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  // Tab 0 Controllers
  final _branchNameCtrl = TextEditingController();
  final _branchAddressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _faxCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _secPdCtrl = TextEditingController();

  // Tab 5 Controllers (Cloud Sync)
  final _supabaseUrlCtrl = TextEditingController();
  final _supabaseAnonKeyCtrl = TextEditingController();

  final ScrollController _panelScrollController = ScrollController();
  bool _isInitialized = false;
  bool _tab4Refreshed = false;
  bool _cloudSyncStatsRefreshed = false;
  bool _obscureAnonKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndLoad();
    });
  }

  void _checkPermissionsAndLoad() {
    final session = ref.read(sessionProvider);
    // If a session exists and user is not SuperAdmin (userLevel != 1), redirect
    if (session != null && session.user.userLevel != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You don't have enough rights for purpose"),
          backgroundColor: AppColors.statusErrorText,
          duration: Duration(seconds: 3),
        ),
      );
      context.go('/dashboard');
      return;
    }

    final currentState = ref.read(systemSettingsProvider);
    if (currentState.isLoading) {
      ref.read(systemSettingsProvider.notifier).loadInitialData();
    }
  }

  void _syncControllers(SystemSettingsState state) {
    if (_branchNameCtrl.text != state.branch.branchName) {
      _branchNameCtrl.text = state.branch.branchName;
    }
    if (_branchAddressCtrl.text != state.branch.branchAddress) {
      _branchAddressCtrl.text = state.branch.branchAddress;
    }
    if (_phoneCtrl.text != state.branch.phone) {
      _phoneCtrl.text = state.branch.phone;
    }
    if (_mobileCtrl.text != state.branch.mobile) {
      _mobileCtrl.text = state.branch.mobile;
    }
    if (_faxCtrl.text != state.branch.fax) {
      _faxCtrl.text = state.branch.fax;
    }
    if (_emailCtrl.text != state.branch.email) {
      _emailCtrl.text = state.branch.email;
    }
    if (_websiteCtrl.text != state.branch.website) {
      _websiteCtrl.text = state.branch.website;
    }
    if (_principalCtrl.text != state.branch.principal) {
      _principalCtrl.text = state.branch.principal;
    }
    if (_contactPersonCtrl.text != state.branch.contactPerson) {
      _contactPersonCtrl.text = state.branch.contactPerson;
    }
    if (_remarksCtrl.text != state.branch.remarks) {
      _remarksCtrl.text = state.branch.remarks;
    }
    if (_secPdCtrl.text != state.branch.secPd) {
      _secPdCtrl.text = state.branch.secPd;
    }
    if (_supabaseUrlCtrl.text != state.config.supabaseUrl) {
      _supabaseUrlCtrl.text = state.config.supabaseUrl;
    }
    if (_supabaseAnonKeyCtrl.text != state.config.supabaseAnonKey) {
      _supabaseAnonKeyCtrl.text = state.config.supabaseAnonKey;
    }
  }

  @override
  void dispose() {
    _branchNameCtrl.dispose();
    _branchAddressCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _faxCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _principalCtrl.dispose();
    _contactPersonCtrl.dispose();
    _remarksCtrl.dispose();
    _secPdCtrl.dispose();
    _supabaseUrlCtrl.dispose();
    _supabaseAnonKeyCtrl.dispose();
    _panelScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final session = ref.read(sessionProvider);
    final userLvl = session?.user.userLevel ?? 1;
    final notifier = ref.read(systemSettingsProvider.notifier);
    await notifier.saveSettings(userLevel: userLvl);
  }

  void _handleDiscard() {
    ref.read(systemSettingsProvider.notifier).discardChanges();
    final state = ref.read(systemSettingsProvider);
    _syncControllers(state);
  }

  void _showRotatePasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _RotatePasswordModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(systemSettingsProvider);
    final notifier = ref.read(systemSettingsProvider.notifier);

    // Initial population and synchronization
    if (!state.isLoading && !_isInitialized) {
      _isInitialized = true;
      _syncControllers(state);
    }

    // Listen for toasts
    ref.listen<SystemSettingsState>(systemSettingsProvider, (prev, next) {
      if (next.toastMessage != null &&
          next.toastMessage != prev?.toastMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toastMessage!),
            backgroundColor: AppColors.statusSuccessText,
            duration: const Duration(seconds: 3),
          ),
        );
        notifier.clearToast();
      }

      // Sync if reset/discarded or refreshed
      if (next.branch != prev?.branch && !next.isLoading) {
        _syncControllers(next);
      }

      // F-6 fix: reset stats latch when tab 5 becomes active OR after save.
      if (next.activeTab == 5 && prev?.activeTab != 5) {
        _cloudSyncStatsRefreshed = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(systemSettingsProvider.notifier).refreshSyncStats();
        });
      }
      if (next.config != prev?.config || next.branch != prev?.branch) {
        _cloudSyncStatsRefreshed = false;
      }
    });

    final shortcutBindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        if (state.isDirty) _handleSave();
      },
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
        if (state.isDirty) _handleSave();
      },
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (state.errorMessage != null) {
          notifier.clearError();
        } else if (state.isDirty) {
          _handleDiscard();
        }
      },
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
          notifier.setActiveTab(0),
      const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
          notifier.setActiveTab(0),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
          notifier.setActiveTab(1),
      const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
          notifier.setActiveTab(1),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
          notifier.setActiveTab(2),
      const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
          notifier.setActiveTab(2),
      const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
          notifier.setActiveTab(3),
      const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () =>
          notifier.setActiveTab(3),
      const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
          notifier.setActiveTab(4),
      const SingleActivator(LogicalKeyboardKey.digit5, meta: true): () =>
          notifier.setActiveTab(4),
      const SingleActivator(LogicalKeyboardKey.digit6, control: true): () =>
          notifier.setActiveTab(5),
      const SingleActivator(LogicalKeyboardKey.digit6, meta: true): () =>
          notifier.setActiveTab(5),
    };

    // Mobile stitch: dedicated single-column layout below the 600px breakpoint.
    // The desktop master-detail Row (260px strip + panel) overflows on phones.
    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileLayout(context, state, notifier);
    }

    return CallbackShortcuts(
      bindings: shortcutBindings,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Region A: Header Bar (52px)
              _buildHeader(context, state),

              // Region A.5: Conditional Error Banner
              if (state.errorMessage != null) ...[
                _buildErrorBanner(state.errorMessage!, notifier),
              ],

              // Region B: Two-Column Settings Console
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Tab Strip (260px)
                          _buildLeftTabStrip(context, state, notifier),

                          // Vertical Pane Divider
                          Container(width: 1.0, color: AppColors.borderDefault),

                          // Right Content Panel
                          Expanded(
                            child: _buildRightContentPanel(
                              context,
                              state,
                              notifier,
                            ),
                          ),
                        ],
                      ),
              ),

              // Region C: Pinned Bottom Action Bar (56px)
              _buildBottomActionBar(context, state),
            ],
          ),
        ),
      ),
    );
  }

  // --- Region A: Header Bar ---

  Widget _buildHeader(BuildContext context, SystemSettingsState state) {
    return Container(
      height: 52.0,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8.0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.settings_applications_outlined,
            size: 22.0,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'SYSTEM SETTINGS & CONFIGURATION',
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.0,
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
                      'SuperAdmin Only',
                      style: AppTypography.monospace.copyWith(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Cross-Navigation Buttons
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: 4.0,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('Operator Accounts'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 6.0,
                  ),
                ),
                onPressed: () => context.go('/system/users'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.security_outlined, size: 16),
                label: const Text('Access Control Matrix'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 6.0,
                  ),
                ),
                onPressed: () => context.go('/system/permissions'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Region A.5: Error Banner ---

  Widget _buildErrorBanner(String message, SystemSettingsNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8.0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.statusErrorBg,
        border: Border(bottom: BorderSide(color: AppColors.statusErrorText)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 18.0,
            color: AppColors.statusErrorText,
          ),
          const SizedBox(width: AppSpacing.sm),
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
            icon: const Icon(Icons.close, size: 16.0),
            color: AppColors.statusErrorText,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: notifier.clearError,
          ),
        ],
      ),
    );
  }

  // --- Shared settings category registry (desktop strip + mobile cards) ---

  static const List<(int, IconData, String, String)> _settingsTabs = [
    (
      0,
      Icons.business_outlined,
      'Institution Profile',
      'Identity, contact & supervisor key',
    ),
    (
      1,
      Icons.calendar_month_outlined,
      'Academic Calendar',
      'Default session, fiscal & work week',
    ),
    (
      2,
      Icons.palette_outlined,
      'Appearance & Locale',
      'Dark mode, density & typography',
    ),
    (
      3,
      Icons.info_outline,
      'System Information',
      'Build, database & provenance',
    ),
    (
      4,
      Icons.backup_outlined,
      'Data & Backups',
      'Export, restore & auto-backup',
    ),
    (5, Icons.sync, 'Cloud Sync', 'Supabase endpoint & force sync'),
  ];

  // --- Region B: Left Tab Strip ---

  Widget _buildLeftTabStrip(
    BuildContext context,
    SystemSettingsState state,
    SystemSettingsNotifier notifier,
  ) {
    const tabs = _settingsTabs;

    return Container(
      width: 260.0,
      color: AppColors.surfaceRaised,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: tabs.map((tab) {
          final isSelected = state.activeTab == tab.$1;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2.0,
            ),
            child: Material(
              color: isSelected
                  ? AppColors.brandPrimary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => notifier.setActiveTab(tab.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 10.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.brandPrimary
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tab.$2,
                        size: 20.0,
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tab.$3,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              tab.$4,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 10.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Region B: Right Content Panel ---

  Widget _buildRightContentPanel(
    BuildContext context,
    SystemSettingsState state,
    SystemSettingsNotifier notifier,
  ) {
    if (state.activeTab == 4) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _buildTab4Backups(state),
      );
    }
    return Scrollbar(
      controller: _panelScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _panelScrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.activeTab == 0) _buildTab0Institution(state, notifier),
            if (state.activeTab == 1) _buildTab1Calendar(state, notifier),
            if (state.activeTab == 2) _buildTab2Appearance(state, notifier),
            if (state.activeTab == 3) _buildTab3Info(state, notifier),
            if (state.activeTab == 5) _buildTab5CloudSync(state, notifier),
          ],
        ),
      ),
    );
  }

  // --- Mobile Stitch: single-column layout for phones (<600px) ---

  Widget _buildMobileLayout(
    BuildContext context,
    SystemSettingsState state,
    SystemSettingsNotifier notifier,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMobileHeader(context, state),
            if (state.errorMessage != null)
              _buildErrorBanner(state.errorMessage!, notifier),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMobileCategoryList(context, state, notifier),
                          const SizedBox(height: AppSpacing.md),
                          _buildMobileActivePanel(state, notifier),
                        ],
                      ),
                    ),
            ),
            _buildMobileBottomBar(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context, SystemSettingsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings_applications_outlined,
                  size: 20.0,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'SYSTEM SETTINGS',
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                    'SuperAdmin Only',
                    style: AppTypography.monospace.copyWith(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4.0,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.people_outline, size: 16),
                  label: const Text(
                    'Operator Accounts',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 6.0,
                    ),
                  ),
                  onPressed: () => context.go('/system/users'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.security_outlined, size: 16),
                  label: const Text(
                    'Access Control Matrix',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 6.0,
                    ),
                  ),
                  onPressed: () => context.go('/system/permissions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Vertical list of left-strip category cards (44px tall, 3.5px accent
  /// strip). Tapping a card selects that settings category.
  Widget _buildMobileCategoryList(
    BuildContext context,
    SystemSettingsState state,
    SystemSettingsNotifier notifier,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: _settingsTabs.length,
      itemBuilder: (ctx, i) {
        final tab = _settingsTabs[i];
        final isSelected = state.activeTab == tab.$1;
        return Container(
          height: 44.0,
          margin: const EdgeInsets.only(bottom: 8.0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentDashboardSoftBg
                : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => notifier.setActiveTab(tab.$1),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3.5,
                      color: isSelected
                          ? AppColors.accentDashboard
                          : AppColors.borderDefault,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: [
                            Icon(
                              tab.$2,
                              size: 18.0,
                              color: isSelected
                                  ? AppColors.accentDashboard
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                tab.$3,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.accentDashboard
                                      : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.chevron_right,
                                size: 18.0,
                                color: AppColors.accentDashboard,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Active category form content, stacked vertically for phones.
  Widget _buildMobileActivePanel(
    SystemSettingsState state,
    SystemSettingsNotifier notifier,
  ) {
    switch (state.activeTab) {
      case 0:
        return _buildTab0Institution(state, notifier, stacked: true);
      case 1:
        return _buildTab1Calendar(state, notifier, stacked: true);
      case 2:
        return _buildTab2Appearance(state, notifier);
      case 3:
        return _buildTab3Info(state, notifier, stacked: true);
      case 4:
        return _buildTab4Backups(state, stacked: true);
      case 5:
        return _buildTab5CloudSync(state, notifier);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Pinned sticky bottom bar: save status + Discard / Save actions.
  Widget _buildMobileBottomBar(
    BuildContext context,
    SystemSettingsState state,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                state.isDirty
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 16.0,
                color: state.isDirty
                    ? AppColors.statusWarningText
                    : AppColors.statusSuccessText,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  state.isDirty
                      ? 'Unsaved changes pending'
                      : 'All settings saved',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: state.isDirty
                        ? AppColors.statusWarningText
                        : AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44.0,
                  child: OutlinedButton(
                    onPressed: state.isDirty ? _handleDiscard : null,
                    child: const Text(
                      'Discard Changes',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 44.0,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentDashboard,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: state.isDirty ? _handleSave : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Tab 0: Institution & Branch Profile ---

  Widget _buildTab0Institution(
    SystemSettingsState state,
    SystemSettingsNotifier notifier, {
    bool stacked = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(
          'BRANCH IDENTIFICATION & LEADERSHIP',
          'Primary organizational credentials printed on report cards, fee vouchers, and payroll slips.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildTextField(
          controller: _branchNameCtrl,
          label: 'Institution / Branch Name *',
          onChanged: notifier.setBranchName,
          hint: 'e.g. Ailyans\'s Higher Secondary School Mianwali',
          dense: stacked,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildTextField(
          controller: _branchAddressCtrl,
          label: 'Branch Address',
          maxLines: 2,
          onChanged: notifier.setBranchAddress,
          hint: 'e.g. Muslim Bazar Mianwali',
          dense: stacked,
        ),
        const SizedBox(height: AppSpacing.sm),
        _fieldGroup(stacked, [
          _buildTextField(
            controller: _principalCtrl,
            label: 'Principal / Head of Institution',
            onChanged: notifier.setPrincipal,
            hint: 'e.g. Nasir ali',
            dense: stacked,
          ),
          _buildTextField(
            controller: _contactPersonCtrl,
            label: 'Contact Person / Administrative Officer',
            onChanged: notifier.setContactPerson,
            hint: 'e.g. Administrative Officer',
            dense: stacked,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle(
          'COMMUNICATION & ONLINE PRESENCE',
          'Official contact details for outward student and parent communications.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _fieldGroup(stacked, [
          _buildTextField(
            controller: _phoneCtrl,
            label: 'Official Phone',
            onChanged: notifier.setPhone,
            hint: '03334449993',
            dense: stacked,
          ),
          _buildTextField(
            controller: _mobileCtrl,
            label: 'Mobile Hotline',
            onChanged: notifier.setMobile,
            hint: '03001234567',
            dense: stacked,
          ),
          _buildTextField(
            controller: _faxCtrl,
            label: 'Fax Number',
            onChanged: notifier.setFax,
            hint: 'Optional fax line',
            dense: stacked,
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        _fieldGroup(stacked, [
          _buildTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            onChanged: notifier.setEmail,
            hint: 'info@ailyans.edu.pk',
            dense: stacked,
          ),
          _buildTextField(
            controller: _websiteCtrl,
            label: 'Official Website',
            onChanged: notifier.setWebsite,
            hint: 'www.ailyans.edu.pk',
            dense: stacked,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle(
          'SUPERVISORY SECURITY & REVOCATION KEY',
          'Master security key (SecPd) safeguarding fee receipt revocation and sensitive reversal procedures.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.brandPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppColors.brandPrimary,
                size: 20.0,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Supervisory Revocation Password (SecPd) authorizes fee receipt revocation and critical reversals. Never share this key with operators.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _secPdCtrl,
                    obscureText: state.obscureSecPd,
                    onChanged: notifier.setSecPd,
                    decoration: InputDecoration(
                      labelText: 'Supervisory Revocation Password (SecPd) *',
                      hintText: 'Enter at least 6 characters',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          state.obscureSecPd
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18.0,
                        ),
                        onPressed: notifier.toggleObscureSecPd,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.key_outlined, size: 16),
                    label: const Text('Rotate Password'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 12.0,
                      ),
                    ),
                    onPressed: _showRotatePasswordDialog,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _secPdCtrl,
                      obscureText: state.obscureSecPd,
                      onChanged: notifier.setSecPd,
                      decoration: InputDecoration(
                        labelText: 'Supervisory Revocation Password (SecPd) *',
                        hintText: 'Enter at least 6 characters',
                        suffixIcon: IconButton(
                          icon: Icon(
                            state.obscureSecPd
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18.0,
                          ),
                          onPressed: notifier.toggleObscureSecPd,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.key_outlined, size: 16),
                      label: const Text('Rotate Password'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 14.0,
                        ),
                      ),
                      onPressed: _showRotatePasswordDialog,
                    ),
                  ),
                ],
              ),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle(
          'SYSTEM REMARKS',
          'Internal branch audit notes and historical registration reference.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildTextField(
          controller: _remarksCtrl,
          label: 'Branch Remarks',
          maxLines: 2,
          onChanged: notifier.setRemarks,
          hint: 'Internal administrative notes',
          dense: stacked,
        ),
      ],
    );
  }

  // --- Tab 1: Academic Calendar & Sessions ---

  Widget _buildTab1Calendar(
    SystemSettingsState state,
    SystemSettingsNotifier notifier, {
    bool stacked = false,
  }) {
    final sessionYearsAsync = ref.watch(availableSessionsProvider);
    final sessionYears = sessionYearsAsync.valueOrNull ?? const <String>[];

    // If current defaultSessionYr not in list, prepend it (avoids dropdown assert):
    final effectiveSessionYears = <String>{
      if (state.config.defaultSessionYr.isNotEmpty)
        state.config.defaultSessionYr,
      ...sessionYears,
      '2017-2018',
    }.toList()..sort((a, b) => b.compareTo(a));

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    const allDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(
          'DEFAULT ENROLLMENT & BILLING SESSION',
          'Configures default academic session year and financial cycle start month.',
        ),
        const SizedBox(height: AppSpacing.sm),
        stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue:
                        effectiveSessionYears.contains(
                          state.config.defaultSessionYr,
                        )
                        ? state.config.defaultSessionYr
                        : (effectiveSessionYears.isNotEmpty
                              ? effectiveSessionYears.first
                              : '2017-2018'),
                    decoration: const InputDecoration(
                      labelText: 'Default Academic Session Year',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                    ),
                    items: effectiveSessionYears.map((yr) {
                      return DropdownMenuItem(value: yr, child: Text(yr));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setDefaultSessionYr(val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: months.contains(state.config.fiscalStartMonth)
                        ? state.config.fiscalStartMonth
                        : 'April',
                    decoration: const InputDecoration(
                      labelText: 'Fiscal / Academic Cycle Start Month',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                    ),
                    items: months.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setFiscalStartMonth(val);
                    },
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          effectiveSessionYears.contains(
                            state.config.defaultSessionYr,
                          )
                          ? state.config.defaultSessionYr
                          : (effectiveSessionYears.isNotEmpty
                                ? effectiveSessionYears.first
                                : '2017-2018'),
                      decoration: const InputDecoration(
                        labelText: 'Default Academic Session Year',
                      ),
                      items: effectiveSessionYears.map((yr) {
                        return DropdownMenuItem(value: yr, child: Text(yr));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) notifier.setDefaultSessionYr(val);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          months.contains(state.config.fiscalStartMonth)
                          ? state.config.fiscalStartMonth
                          : 'April',
                      decoration: const InputDecoration(
                        labelText: 'Fiscal / Academic Cycle Start Month',
                      ),
                      items: months.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) notifier.setFiscalStartMonth(val);
                      },
                    ),
                  ),
                ],
              ),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle(
          'INSTITUTIONAL WORKING DAYS',
          'Defines days of the week when daily student and staff attendance is mandated.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Select active operating days for this campus:',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: allDays.map((day) {
            final isWorking = state.config.workingDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: isWorking,
              selectedColor: AppColors.brandPrimary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.brandPrimary,
              labelStyle: AppTypography.bodySmall.copyWith(
                fontWeight: isWorking ? FontWeight.w700 : FontWeight.w500,
                color: isWorking
                    ? AppColors.brandPrimary
                    : AppColors.textPrimary,
              ),
              onSelected: (_) => notifier.toggleWorkingDay(day),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Tab 2: Appearance & Regionalization ---

  Widget _buildTab2Appearance(
    SystemSettingsState state,
    SystemSettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(
          'THEME & VISUAL DENSITY',
          'Client-side visual customization and screen density preferences.',
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          title: const Text('Dark Theme (Requires App Restart)'),
          subtitle: const Text(
            'Activates high-contrast dark color palette on next desktop launch.',
          ),
          value: state.config.darkMode,
          onChanged: notifier.setDarkMode,
        ),
        SwitchListTile(
          title: const Text('High Density Workspace'),
          subtitle: const Text(
            'Reduces row padding in tables and data grids for data-entry operators.',
          ),
          value: state.config.highDensityUi,
          onChanged: notifier.setHighDensityUi,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle(
          'TYPOGRAPHY & REGIONALIZATION',
          'Bi-directional text rendering and regional typography support.',
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          title: const Text('Urdu Typography Fallback'),
          subtitle: const Text(
            'Renders student/parent names in Jameel Noori Nastaliq font when Urdu text is present.',
          ),
          value: state.config.urduFontFallback,
          onChanged: notifier.setUrduFontFallback,
        ),
      ],
    );
  }

  // --- Tab 3: System Information & Provenance ---

  Widget _buildTab3Info(
    SystemSettingsState state,
    SystemSettingsNotifier notifier, {
    bool stacked = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(
          'APPLICATION IDENTIFICATION',
          'Desktop runtime environment and architectural specifications.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard([
          ('Product Edition', 'School Management System — Ailyans Edition'),
          ('Target Win32 Binary', 'school.exe (VB6 / MS Access / SQLite)'),
          ('Rebuild Runtime', 'Flutter Desktop (macOS / Windows / Linux)'),
          (
            'Architecture Pattern',
            'Clean Architecture / Riverpod 2.x / SQLite',
          ),
        ], stacked: stacked),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle(
          'DATABASE & STORAGE INTEGRITY',
          'Live database engine, migration version, and operator counts.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard([
          ('Database Engine', 'SQLite 3 (WAL Mode)'),
          (
            'Schema Version',
            'Level ${state.schemaVersion} (Migrations 001-010 applied)',
          ),
          ('Configured Operators', '${state.operatorCount} active users'),
          ('Database Path', '~/Documents/Ailyans/school_database.db'),
        ], stacked: stacked),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle(
          'HISTORICAL PROVENANCE & CREDITS',
          'Heritage of the legacy Win32 system and modernization team credits.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard([
          ('Original Win32 Author', 'Nasir Ali (Ailyans Software, Mianwali)'),
          (
            'Modernization Engineering',
            'Antigravity Rebuild Architecture Team',
          ),
          ('Copyright', '© 2017-2026 Ailyans & Modernization Rebuild Project'),
        ], stacked: stacked),
      ],
    );
  }

  // --- Tab 4: Data & Backups ---

  Widget _buildTab4Backups(SystemSettingsState state, {bool stacked = false}) {
    final backupState = ref.watch(backupProvider);
    final backupNotifier = ref.read(backupProvider.notifier);

    if (!_tab4Refreshed) {
      _tab4Refreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(backupProvider.notifier).refreshBackupsList();
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(
          'DATABASE BACKUP & RESTORE',
          'Export snapshots of the live database, restore from a prior backup, or open the folder.',
        ),
        const SizedBox(height: AppSpacing.sm),

        // Action row: Export / Open Folder
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.save_alt, size: 16),
              label: Text(
                backupState.isExporting ? 'Exporting...' : 'Export Backup Now',
              ),
              onPressed: backupState.isExporting || backupState.isRestoring
                  ? null
                  : () async {
                      await backupNotifier.exportNow();
                      if (mounted) {
                        final s = ref.read(backupProvider);
                        if (s.infoMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(s.infoMessage!),
                              backgroundColor: AppColors.statusSuccessText,
                            ),
                          );
                          backupNotifier.clearMessages();
                        } else if (s.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(s.errorMessage!),
                              backgroundColor: AppColors.statusErrorText,
                            ),
                          );
                          backupNotifier.clearMessages();
                        }
                      }
                    },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Open Data Folder'),
              onPressed: () => backupNotifier.openBackupsFolder(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Restore section
        _buildSectionTitle(
          'RESTORE FROM BACKUP',
          'Select a .db file. All current data will be overwritten after a safety backup is created.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file, size: 16),
              label: Text(
                backupState.isRestoring
                    ? 'Restoring...'
                    : 'Choose Backup File...',
              ),
              onPressed: backupState.isRestoring
                  ? null
                  : () => _handleRestoreClicked(backupNotifier),
            ),
            if (backupState.isRestoring)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Available backups list (Expanded, scrollable)
        _buildSectionTitle(
          'AVAILABLE BACKUPS',
          'Files in ~/Documents/Ailyans/backups/. Newest first.',
        ),
        const SizedBox(height: AppSpacing.sm),
        stacked
            ? SizedBox(
                height: 240.0,
                child: backupState.availableBackups.isEmpty
                    ? Center(
                        child: Text(
                          'No backups yet. Click Export Backup Now.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          border: Border.all(color: AppColors.borderDefault),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: ListView.separated(
                          itemCount: backupState.availableBackups.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: AppColors.borderDefault,
                          ),
                          itemBuilder: (ctx, i) {
                            final name = backupState.availableBackups[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.storage_outlined,
                                size: 18,
                              ),
                              title: Text(
                                name,
                                style: AppTypography.monospace.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                              trailing: TextButton.icon(
                                icon: const Icon(Icons.restore, size: 14),
                                label: const Text('Restore'),
                                onPressed: backupState.isRestoring
                                    ? null
                                    : () => _handleRestorePathPicked(
                                        backupNotifier,
                                        name,
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
              )
            : Expanded(
                child: backupState.availableBackups.isEmpty
                    ? Center(
                        child: Text(
                          'No backups yet. Click Export Backup Now.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          border: Border.all(color: AppColors.borderDefault),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: ListView.separated(
                          itemCount: backupState.availableBackups.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: AppColors.borderDefault,
                          ),
                          itemBuilder: (ctx, i) {
                            final name = backupState.availableBackups[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.storage_outlined,
                                size: 18,
                              ),
                              title: Text(
                                name,
                                style: AppTypography.monospace.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                              trailing: TextButton.icon(
                                icon: const Icon(Icons.restore, size: 14),
                                label: const Text('Restore'),
                                onPressed: backupState.isRestoring
                                    ? null
                                    : () => _handleRestorePathPicked(
                                        backupNotifier,
                                        name,
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  // --- Tab 5: Cloud Sync ---

  Widget _buildTab5CloudSync(
    SystemSettingsState state,
    SystemSettingsNotifier notifier,
  ) {
    const nodeOptions = ['windows', 'android_a', 'android_b'];
    final nodeValue = nodeOptions.contains(state.config.nodeId)
        ? state.config.nodeId
        : 'windows';
    final busy = state.isForcePushing || state.isForcePulling;

    if (!_cloudSyncStatsRefreshed) {
      _cloudSyncStatsRefreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(systemSettingsProvider.notifier).refreshSyncStats();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(
          'SUPABASE CLOUD ENDPOINT',
          'Device-local credentials. These values are stored on this device only and never sync to other nodes.',
        ),
        const SizedBox(height: AppSpacing.sm),

        // Supabase URL
        Text(
          'Supabase URL',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4.0),
        SizedBox(
          height: 38.0,
          child: TextField(
            controller: _supabaseUrlCtrl,
            onChanged: notifier.setSupabaseUrl,
            decoration: const InputDecoration(
              hintText: 'https://<project-ref>.supabase.co',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Anon key
        Text(
          'Supabase Anon Key',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4.0),
        SizedBox(
          height: 38.0,
          child: TextField(
            controller: _supabaseAnonKeyCtrl,
            obscureText: _obscureAnonKey,
            onChanged: notifier.setSupabaseAnonKey,
            decoration: InputDecoration(
              hintText: 'eyJhbGciOi...',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureAnonKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18.0,
                ),
                onPressed: () =>
                    setState(() => _obscureAnonKey = !_obscureAnonKey),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Node block
        Text(
          'Device Node Block',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4.0),
        SizedBox(
          height: 38.0,
          child: DropdownButton<String>(
            value: nodeValue,
            isExpanded: true,
            isDense: true,
            dropdownColor: AppColors.surfaceRaised,
            items: const [
              DropdownMenuItem(value: 'windows', child: Text('windows')),
              DropdownMenuItem(value: 'android_a', child: Text('android_a')),
              DropdownMenuItem(value: 'android_b', child: Text('android_b')),
            ],
            onChanged: (value) {
              if (value != null) notifier.setNodeId(value);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Sync status
        _buildSectionTitle(
          'SYNC STATUS',
          'Pending outbox rows and the most recent successful watermarks.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSyncStatRow(
                'Pending changes',
                '${state.pendingOutboxCount}',
              ),
              const SizedBox(height: 6.0),
              _buildSyncStatRow('Last pulled', state.lastPulledAt ?? 'never'),
              const SizedBox(height: 6.0),
              _buildSyncStatRow('Last pushed', state.lastPushedAt ?? 'never'),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh Stats'),
                  onPressed: busy ? null : notifier.refreshSyncStats,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Actions
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.cloud_download_outlined, size: 16),
              label: Text(state.isForcePulling ? 'Pulling...' : 'Force Pull'),
              onPressed: busy ? null : notifier.forcePullAll,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
              label: Text(state.isForcePushing ? 'Pushing...' : 'Force Push'),
              onPressed: busy ? null : notifier.forcePushAll,
            ),
            FilledButton.icon(
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Sync Now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: busy
                  ? null
                  : () async {
                      await ref.read(syncPushProvider.notifier).triggerSync();
                      if (mounted) {
                        await notifier.refreshSyncStats();
                      }
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncStatRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160.0,
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
            style: AppTypography.monospace.copyWith(
              fontSize: 12.0,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRestoreClicked(BackupNotifier backupNotifier) async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Select Database Backup',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (files.isEmpty || files.first.path == null) {
      return;
    }
    final path = files.first.path!;
    if (!mounted) return;
    await _validateAndConfirm(backupNotifier, path);
  }

  Future<void> _handleRestorePathPicked(
    BackupNotifier backupNotifier,
    String basename,
  ) async {
    final dir = await BackupService.instance.backupsDirectory();
    final fullPath = p.join(dir.path, basename);
    if (!mounted) return;
    await _validateAndConfirm(backupNotifier, fullPath);
  }

  Future<void> _validateAndConfirm(
    BackupNotifier backupNotifier,
    String candidatePath,
  ) async {
    final validation = await backupNotifier.pickAndValidate(candidatePath);
    if (!mounted) return;
    if (validation == null) return;
    if (!validation.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.failureReason ?? 'Invalid backup file'),
          backgroundColor: AppColors.statusErrorText,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will overwrite the current database with:',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              candidatePath,
              style: AppTypography.monospace.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'A pre-restore safety backup will be saved to:',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              '~/Documents/Ailyans/backups/pre_restore_<timestamp>.db',
              style: AppTypography.monospace.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              'You will be logged out and must sign in again.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusWarningText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusErrorText,
            ),
            child: const Text('Restore & Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final success = await backupNotifier.confirmRestore(candidatePath);
    if (!mounted) return;
    if (success) {
      ref.read(sessionProvider.notifier).clear();
      context.go('/login');
    } else {
      final s = ref.read(backupProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.errorMessage ?? 'Restore failed'),
          backgroundColor: AppColors.statusErrorText,
        ),
      );
      backupNotifier.clearMessages();
    }
  }

  // --- Region C: Pinned Bottom Action Bar ---

  Widget _buildBottomActionBar(
    BuildContext context,
    SystemSettingsState state,
  ) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8.0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          // Left: Unsaved changes indicator
          Icon(
            state.isDirty
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            size: 18.0,
            color: state.isDirty
                ? AppColors.statusWarningText
                : AppColors.statusSuccessText,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            state.isDirty ? 'Unsaved changes pending' : 'All settings saved',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: state.isDirty
                  ? AppColors.statusWarningText
                  : AppColors.textMuted,
            ),
          ),
          const Spacer(),
          // Action Buttons
          OutlinedButton(
            onPressed: state.isDirty ? _handleDiscard : null,
            child: const Text('Discard Changes (Esc)'),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Settings (Ctrl+S)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: state.isDirty ? _handleSave : null,
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    String? hint,
    bool dense = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: dense,
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0)
            : null,
      ),
    );
  }

  /// Lays sibling form fields side-by-side on desktop, stacked vertically
  /// (full-width, 44px-dense) on mobile.
  Widget _fieldGroup(bool stacked, List<Widget> fields) {
    if (!stacked) {
      return Row(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: fields[i]),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          fields[i],
        ],
      ],
    );
  }

  Widget _buildInfoCard(List<(String, String)> items, {bool stacked = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: items.map((item) {
          final label = Text(
            item.$1,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          );
          final value = Text(
            item.$2,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 2.0), value],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 180.0, child: label),
                      Expanded(child: value),
                    ],
                  ),
          );
        }).toList(),
      ),
    );
  }
}

/// Modal dialog for rotating supervisory password (SecPd).
class _RotatePasswordModal extends ConsumerStatefulWidget {
  const _RotatePasswordModal();

  @override
  ConsumerState<_RotatePasswordModal> createState() =>
      _RotatePasswordModalState();
}

class _RotatePasswordModalState extends ConsumerState<_RotatePasswordModal> {
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _modalError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _modalError = null;
      _isSubmitting = true;
    });

    final session = ref.read(sessionProvider);
    final userLvl = session?.user.userLevel ?? 1;

    final err = await ref
        .read(systemSettingsProvider.notifier)
        .rotatePassword(
          userLevel: userLvl,
          currentPassword: _currentPwdCtrl.text.trim(),
          newPassword: _newPwdCtrl.text.trim(),
          confirmPassword: _confirmPwdCtrl.text.trim(),
        );

    if (mounted) {
      if (err != null) {
        setState(() {
          _modalError = err;
          _isSubmitting = false;
        });
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460.0),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.key_outlined,
                    color: AppColors.brandPrimary,
                    size: 22.0,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Rotate Supervisory Password',
                      style: AppTypography.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18.0),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                'Update the master key used to authorize fee voucher revocations and critical operations.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Modal Error Banner
              if (_modalError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusErrorBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.statusErrorText),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16.0,
                        color: AppColors.statusErrorText,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _modalError!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.statusErrorText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Fields
              TextField(
                controller: _currentPwdCtrl,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Supervisory Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18.0,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _newPwdCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Supervisory Password (min 6 chars)',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18.0,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _confirmPwdCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18.0,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update Password'),
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
