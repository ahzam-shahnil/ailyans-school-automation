import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/clock_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/teacher_profile_provider.dart';
import '../../core/providers/teacher_list_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../widgets/mobile/mobile_status_pill.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

/// Screen 21 — TeacherProfileScreen (`/staff/teachers/:id` and `/staff/teachers/new`).
/// Implements §S25 (`frmTeachers` at `0x00431fec`, `ObjID: 14`) in edit/detail mode.
class TeacherProfileScreen extends ConsumerStatefulWidget {
  final int? teacherId;
  final bool? isCreateMode;

  const TeacherProfileScreen({super.key, this.teacherId, this.isCreateMode});

  @override
  ConsumerState<TeacherProfileScreen> createState() =>
      _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  // 6 pastel backgrounds for initials avatar variety
  static const List<Color> _avatarPalette = [
    Color(0xFFE0F2FE), // Soft Sky
    Color(0xFFFCE7F3), // Soft Pink
    Color(0xFFEDE9FE), // Soft Lavender
    Color(0xFFFEF3C7), // Soft Amber
    Color(0xFFDCFCE7), // Soft Emerald
    Color(0xFFFFEDD5), // Soft Peach
  ];

  static const List<String> _employmentCategories = [
    'Teacher',
    'Principal',
    'V-P',
    'Staff',
    'Admin',
  ];

  static const List<String> _fieldKeys = [
    'TName',
    'TFName',
    'TCNIC',
    'TContactNo1',
    'TContactNo2',
    'Domicile',
    'TAddress',
    'TSubject',
    'OfficeFile',
    'TBioSer',
    'AttSMSCont',
    'TEmergencyContactName',
    'TEmergencyContactNo',
    'Detail',
    'TQualification',
    'TProfessional',
    'TCertificate',
    'TFiledOfExperty',
    'TExperience',
    'TAnySpeciality',
  ];

  final Map<String, TextEditingController> _controllers = {};
  final ScrollController _tab1ScrollController = ScrollController();
  final ScrollController _tab4ScrollController = ScrollController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _cnicFocusNode = FocusNode();
  final FocusNode _contactFocusNode = FocusNode();

  int? _resolvedId;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    for (final key in _fieldKeys) {
      _controllers[key] = TextEditingController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      _parseRoute();
      final current = ref
          .read(teacherProfileProvider(_resolvedId))
          .currentTeacher;
      if (current != null) {
        _syncControllers(current);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initProvider();
        }
      });
    }
  }

  void _syncControllers(dynamic current) {
    if (current == null) return;
    _updateControllerText('TName', current.tName ?? '');
    _updateControllerText('TFName', current.tFName ?? '');
    _updateControllerText('TCNIC', current.tCnic ?? '');
    _updateControllerText('TContactNo1', current.tContactNo1 ?? '');
    _updateControllerText('TContactNo2', current.tContactNo2 ?? '');
    _updateControllerText('Domicile', current.domicile ?? '');
    _updateControllerText('TAddress', current.tAddress ?? '');
    _updateControllerText('TSubject', current.tSubject ?? '');
    _updateControllerText('OfficeFile', current.officeFile ?? '');
    _updateControllerText(
      'TBioSer',
      current.tBioSer != null
          ? (current.tBioSer! % 1 == 0
                ? current.tBioSer!.toInt().toString()
                : current.tBioSer!.toString())
          : '',
    );
    _updateControllerText('AttSMSCont', current.attSmsCont ?? '');
    _updateControllerText(
      'TEmergencyContactName',
      current.tEmergencyContactName ?? '',
    );
    _updateControllerText(
      'TEmergencyContactNo',
      current.tEmergencyContactNo ?? '',
    );
    _updateControllerText('Detail', current.detail ?? '');
    _updateControllerText('TQualification', current.tQualification ?? '');
    _updateControllerText('TProfessional', current.tProfessional ?? '');
    _updateControllerText('TCertificate', current.tCertificate ?? '');
    _updateControllerText('TFiledOfExperty', current.tFiledOfExperty ?? '');
    _updateControllerText('TExperience', current.tExperience ?? '');
    _updateControllerText('TAnySpeciality', current.tAnySpeciality ?? '');
  }

  void _updateControllerText(String key, String newText) {
    final controller = _controllers[key];
    if (controller != null && controller.text != newText) {
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
        composing: TextRange.empty,
      );
    }
  }

  void _parseRoute() {
    int? parsedId = widget.teacherId;
    bool isCreate = widget.isCreateMode ?? false;

    if (parsedId == null && !isCreate) {
      try {
        final state = GoRouterState.of(context);
        final idParam = state.pathParameters['id'];
        if (idParam == null || idParam == 'new') {
          isCreate = true;
        } else {
          parsedId = int.tryParse(idParam);
        }
      } catch (_) {}
    }

    if (isCreate) {
      _resolvedId = null;
    } else {
      _resolvedId = parsedId ?? 1;
    }
  }

  void _initProvider() {
    final session = ref.read(sessionProvider);
    final userLvl = session?.user.userLevel;

    if (_resolvedId == null) {
      if (userLvl == 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You don't have enough rights for purpose"),
            backgroundColor: AppColors.statusErrorText,
          ),
        );
        context.go('/staff/teachers');
        return;
      }
      ref
          .read(teacherProfileProvider(_resolvedId).notifier)
          .initNewTeacher(userLvl: userLvl);
    } else {
      final notifier = ref.read(teacherProfileProvider(_resolvedId).notifier);
      notifier.init(_resolvedId, userLvl: userLvl);
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _cnicFocusNode.dispose();
    _contactFocusNode.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _tab1ScrollController.dispose();
    _tab4ScrollController.dispose();
    super.dispose();
  }

  Color _getAvatarBg(int? teacherId) {
    if (teacherId == null) return AppColors.surfaceSubtle;
    return _avatarPalette[teacherId.abs() % _avatarPalette.length];
  }

  Future<bool> _showDiscardDialog(
    BuildContext context, {
    required bool isNew,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Discard Unsaved Changes?'),
          content: Text(
            isNew
                ? 'This new teacher record has not been created. If you leave now, the details you entered will be lost.'
                : 'You have unsaved changes to this teacher profile. If you leave now, they will be lost.',
            style: AppTypography.body,
          ),
          actions: [
            OutlinedButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard Changes'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _handleBackToDirectory(
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) async {
    if (state.isDirty) {
      final discard = await _showDiscardDialog(context, isNew: state.isNew);
      if (!discard) return;
    }
    if (mounted) {
      ref.read(teacherListProvider.notifier).loadInitialData();
      context.go('/staff/teachers');
    }
  }

  Future<void> _handleDeleteTeacher(
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) async {
    final teacherId =
        state.currentTeacher?.teacherId ??
        state.teacherId ??
        _resolvedId ??
        widget.teacherId;
    if (teacherId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Staff Member'),
          content: const Text(
            'Are you sure you want to delete this staff member? This action cannot be undone.',
            style: AppTypography.body,
          ),
          actions: [
            OutlinedButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await notifier.deleteTeacher(teacherId);
      if (mounted) {
        ref.read(teacherListProvider.notifier).loadInitialData();
        context.go('/staff/teachers');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff member deleted successfully'),
            backgroundColor: AppColors.statusSuccessBg,
          ),
        );
      }
    }
  }

  Future<void> _handleCancelEdits(
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) async {
    if (state.isDirty) {
      final discard = await _showDiscardDialog(context, isNew: state.isNew);
      if (!discard) return;
    }
    notifier.cancelEdits();
  }

  Future<void> _handleSave(
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) async {
    final session = ref.read(sessionProvider);
    final userLvl = session?.user.userLevel;

    final newId = await notifier.save(userLvl: userLvl);
    if (newId != null) {
      if (mounted) {
        final toast = ref.read(teacherProfileProvider(_resolvedId)).toast;
        if (toast != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(toast),
              backgroundColor: AppColors.statusSuccessBg,
            ),
          );
        }
        if (state.isNew) {
          context.go('/staff/teachers/$newId');
        }
      }
    } else {
      final errors = ref.read(teacherProfileProvider(_resolvedId)).fieldErrors;
      if (errors.containsKey('TName')) {
        _nameFocusNode.requestFocus();
      } else if (errors.containsKey('TCNIC')) {
        _cnicFocusNode.requestFocus();
      } else if (errors.containsKey('TContactNo1')) {
        _contactFocusNode.requestFocus();
      }
    }
  }

  void _handleSaveShortcut() {
    final state = ref.read(teacherProfileProvider(_resolvedId));
    final notifier = ref.read(teacherProfileProvider(_resolvedId).notifier);
    if (state.isEditMode && state.canSave) {
      _handleSave(state, notifier);
    }
  }

  void _handleEditShortcut() {
    final state = ref.read(teacherProfileProvider(_resolvedId));
    final notifier = ref.read(teacherProfileProvider(_resolvedId).notifier);
    final session = ref.read(sessionProvider);
    if (!state.isEditMode && !state.isNew && session?.user.userLevel != 3) {
      notifier.enterEditMode(userLvl: session?.user.userLevel);
    }
  }

  void _handlePrintShortcut() {
    final state = ref.read(teacherProfileProvider(_resolvedId));
    if (!state.isEditMode && !state.isNew) {
      _showPrintStub();
    }
  }

  void _handleEscapeShortcut() {
    final state = ref.read(teacherProfileProvider(_resolvedId));
    final notifier = ref.read(teacherProfileProvider(_resolvedId).notifier);
    if (state.isEditMode) {
      _handleCancelEdits(state, notifier);
    }
  }

  void _showPrintStub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming in Phase E'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProfileProvider(_resolvedId));
    final notifier = ref.read(teacherProfileProvider(_resolvedId).notifier);
    final session = ref.watch(sessionProvider);
    final isReadOnlyUser = session?.user.userLevel == 3;

    // Synchronize form controllers on state updates
    ref.listen<dynamic>(
      teacherProfileProvider(_resolvedId).select((s) => s.currentTeacher),
      (prev, next) {
        _syncControllers(next);
      },
    );

    ref.listen<bool>(
      teacherProfileProvider(_resolvedId).select((s) => s.isEditMode),
      (prev, next) {
        final current = ref
            .read(teacherProfileProvider(_resolvedId))
            .currentTeacher;
        _syncControllers(current);
      },
    );

    // Toast listener
    ref.listen<String?>(
      teacherProfileProvider(_resolvedId).select((s) => s.toast),
      (prev, next) {
        if (next != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next),
              backgroundColor: AppColors.brandPrimary,
            ),
          );
          notifier.clearToast();
        }
      },
    );

    // Error listener
    ref.listen<String?>(
      teacherProfileProvider(_resolvedId).select((s) => s.errorMessage),
      (prev, next) {
        if (next != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next),
              backgroundColor: AppColors.statusErrorText,
            ),
          );
        }
      },
    );

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileLayout(context, state, notifier, isReadOnlyUser);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleSaveShortcut,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _handleSaveShortcut,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true):
            _handleEditShortcut,
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
            _handleEditShortcut,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _handlePrintShortcut,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
            _handlePrintShortcut,
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscapeShortcut,
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () =>
            notifier.switchTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () {
          if (!state.isNew) notifier.switchTab(1);
        },
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () {
          if (!state.isNew) notifier.switchTab(2);
        },
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () =>
            notifier.switchTab(3),
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // a) Profile Header (~120px)
              _buildHeader(context, state, notifier, isReadOnlyUser),

              // Error banner if any
              if (state.errorMessage != null)
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  color: AppColors.statusErrorBg,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.statusErrorText,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.statusErrorText,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.statusErrorText,
                        ),
                        splashRadius: 12,
                        onPressed: notifier.clearErrorMessage,
                      ),
                    ],
                  ),
                ),

              // b) Tab Bar (~40px)
              _buildTabBar(context, state, notifier),

              // c) Tab Content (Expanded, inner scroll)
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTabContent(context, state, notifier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // A. PERSISTENT HEADER BAR (~120px)
  // ===========================================================================
  Widget _buildHeader(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
    bool isReadOnlyUser,
  ) {
    final current = state.currentTeacher;
    final isNew = state.isNew;
    final isEdit = state.isEditMode;

    final avatarBg = _getAvatarBg(current?.teacherId);

    // Row 2 identity subtitle
    String row2Text = '';
    if (isNew) {
      row2Text = 'Complete the required fields to create this record.';
    } else if (current != null) {
      final parts = <String>[];
      if (current.tFName != null && current.tFName!.trim().isNotEmpty) {
        parts.add('S/O ${current.tFName}');
      }
      if (current.teacherId != null) {
        parts.add('ID #${current.teacherId}');
      }
      if (current.tCnic.isNotEmpty) {
        parts.add('CNIC: ${current.tCnic}');
      }
      if (current.tContactNo1.isNotEmpty) {
        parts.add('Mobile: ${current.tContactNo1}');
      }
      row2Text = parts.join(' | ');
    }

    // Row 3 emergency contact
    String? row3Text;
    if (!isNew &&
        current != null &&
        current.tEmergencyContactName != null &&
        current.tEmergencyContactName!.trim().isNotEmpty) {
      final phone = current.tEmergencyContactNo ?? '';
      row3Text =
          'Emergency: ${current.tEmergencyContactName}${phone.isNotEmpty ? ' ($phone)' : ''}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, Badges, Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 72x72 Initials Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isNew ? AppColors.surfaceSubtle : avatarBg,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Center(
                  child: isNew
                      ? const Icon(
                          Icons.add,
                          size: 32,
                          color: AppColors.textMuted,
                        )
                      : Text(
                          current?.initials ?? '?',
                          style: AppTypography.h2.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Title and Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      runSpacing: 4,
                      children: [
                        Text(
                          isNew
                              ? 'New Teacher'
                              : (current?.tName.isEmpty ?? true
                                    ? 'Unnamed Teacher'
                                    : current!.tName),
                          style: AppTypography.h2.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isNew && current != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          _buildCategoryBadge(current.tCat),
                          _buildStatusBadge(current.isActive),
                        ],
                        if (state.isDirty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusWarningBg,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: AppColors.statusWarningText.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              'Unsaved Changes',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.statusWarningText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Row 2 Identity Details
                    Text(
                      row2Text,
                      style: isNew
                          ? AppTypography.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            )
                          : AppTypography.monospace.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Row 3 Emergency Details
                    if (row3Text != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        row3Text,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Right-aligned Action Buttons
              _buildHeaderActions(
                context,
                state,
                notifier,
                isNew,
                isEdit,
                isReadOnlyUser,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
    bool isNew,
    bool isEdit,
    bool isReadOnlyUser,
  ) {
    if (isNew) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: state.canSave
                ? () => _handleSave(state, notifier)
                : null,
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Create Employee'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => _handleBackToDirectory(state, notifier),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Back to Directory'),
          ),
        ],
      );
    }

    if (isEdit) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: state.canSave
                ? () => _handleSave(state, notifier)
                : null,
            icon: const Icon(Icons.save_outlined, size: 14),
            label: const Text('Save Changes (Ctrl+S)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => _handleCancelEdits(state, notifier),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Cancel Edits'),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: isReadOnlyUser
                ? null
                : () => _handleDeleteTeacher(state, notifier),
            icon: const Icon(
              Icons.delete_outline,
              size: 14,
              color: AppColors.statusErrorText,
            ),
            label: const Text(
              'Delete Staff',
              style: TextStyle(color: AppColors.statusErrorText),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
              side: const BorderSide(color: AppColors.statusErrorBorder),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => _handleBackToDirectory(state, notifier),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Back to Directory'),
          ),
        ],
      );
    }

    // View mode
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: 'Refresh profile and child data',
          onPressed: () {
            final id = _resolvedId ?? widget.teacherId;
            if (id != null) {
              ref.read(teacherProfileProvider(id).notifier).loadTeacher(id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile refreshed'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        const SizedBox(width: AppSpacing.xs),
        if (isReadOnlyUser)
          Tooltip(
            message: "You don't have enough rights for purpose",
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
              ),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () => notifier.enterEditMode(),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
          ),
        const SizedBox(width: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: () {
            final meta = ref.read(shellMetadataProvider).valueOrNull;
            final teacher = ref
                .read(teacherProfileProvider(_resolvedId))
                .currentTeacher;
            if (teacher == null) return;

            final teacherData = <String, dynamic>{
              'name': teacher.tName,
              'fatherName': teacher.tFName,
              'designation': teacher.tCat,
              'cnic': teacher.tCnic,
              'phone': teacher.tContactNo1,
              'phone2': teacher.tContactNo2 ?? '',
              'address': teacher.tAddress ?? '',
              'joiningDate': teacher.doJoing ?? '',
              'subject': teacher.tSubject ?? '',
              'qualification': teacher.tQualification ?? '',
              'photoPath': teacher.officeFile,
            };

            ReportPreviewModal.show(
              context,
              request: ReportRequest(
                type: ReportType.teacherBiodata,
                titleOverride: 'Teacher Biodata - ${teacher.tName}',
                extraParams: {
                  'teacherData': teacherData,
                  'branchName':
                      meta?.branchName ??
                      '-',
                  'branchAddress':
                      meta?.branchAddress ?? '-',
                },
              ),
            );
          },
          icon: const Icon(Icons.print_outlined, size: 14),
          label: const Text('Print Biodata'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: isReadOnlyUser
              ? null
              : () => _handleDeleteTeacher(state, notifier),
          icon: const Icon(
            Icons.delete_outline,
            size: 14,
            color: AppColors.statusErrorText,
          ),
          label: const Text(
            'Delete Staff',
            style: TextStyle(color: AppColors.statusErrorText),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
            side: const BorderSide(color: AppColors.statusErrorBorder),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        OutlinedButton(
          onPressed: () => _handleBackToDirectory(state, notifier),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
          child: const Text('Back to Directory'),
        ),
      ],
    );
  }

  Widget _buildCategoryBadge(String category) {
    Color bg;
    Color text;
    FontWeight weight = FontWeight.w600;

    switch (category.trim()) {
      case 'Principal':
        bg = AppColors.brandPrimary.withValues(alpha: 0.20);
        text = AppColors.brandPrimary;
        weight = FontWeight.w700;
        break;
      case 'V-P':
        bg = AppColors.statusInfoBg;
        text = AppColors.statusInfoText;
        break;
      case 'Teacher':
        bg = AppColors.statusSuccessBg;
        text = AppColors.statusSuccessText;
        break;
      case 'Staff':
      default:
        bg = AppColors.surfaceSubtle;
        text = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        category.isEmpty ? 'Staff' : category,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: weight,
          color: text,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    final bg = isActive ? AppColors.statusSuccessBg : AppColors.statusErrorBg;
    final text = isActive
        ? AppColors.statusSuccessText
        : AppColors.statusErrorText;
    final label = isActive ? 'Active' : 'Relieved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  // ===========================================================================
  // B. TAB BAR (~40px, Component #38)
  // ===========================================================================
  Widget _buildTabBar(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final subjCount = state.subjectAssignments.length;
    final salCount = state.salarySlips.length;

    final tabs = [
      '1. Personal & Biodata',
      state.isNew ? '2. Class Subjects' : '2. Class Subjects ($subjCount)',
      state.isNew ? '3. Payroll History' : '3. Payroll History ($salCount)',
      '4. Qualifications',
    ];

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = state.activeTab == idx;
          final isDisabled = state.isNew && (idx == 1 || idx == 2);

          return InkWell(
            onTap: isDisabled ? null : () => notifier.switchTab(idx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                tabs[idx],
                style: AppTypography.label.copyWith(
                  color: isDisabled
                      ? AppColors.textMuted
                      : (isSelected
                            ? AppColors.brandPrimary
                            : AppColors.textSecondary),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // C. TAB CONTENT DISPATCHER
  // ===========================================================================
  Widget _buildTabContent(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    switch (state.activeTab) {
      case 0:
        return _buildTab1PersonalBiodata(context, state, notifier);
      case 1:
        return _buildTab2ClassSubjects(context, state, notifier);
      case 2:
        return _buildTab3PayrollHistory(context, state, notifier);
      case 3:
        return _buildTab4Qualifications(context, state, notifier);
      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // TAB 1: PERSONAL & BIODATA
  // ===========================================================================
  Widget _buildTab1PersonalBiodata(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final current = state.currentTeacher;
    final isEdit = state.isEditMode;
    final isReadOnlyUser = ref.watch(sessionProvider)?.user.userLevel == 3;

    return Scrollbar(
      controller: _tab1ScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _tab1ScrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Status Bar: Active Employment Status Toggle
            if (!state.isNew && current != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Row(
                  children: [
                    Icon(
                      current.isActive
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      size: 18,
                      color: current.isActive
                          ? AppColors.statusSuccessText
                          : AppColors.statusErrorText,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Employment Status: ${current.isActive ? "Active Faculty Member" : "Relieved / Inactive"}',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: current.isActive
                            ? AppColors.statusSuccessText
                            : AppColors.statusErrorText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Active',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: current.isActive,
                      activeThumbColor: AppColors.brandPrimary,
                      onChanged: isReadOnlyUser
                          ? null
                          : (active) async {
                              final tid = current.teacherId;
                              if (tid != null) {
                                await notifier.toggleActiveStatus(tid, active);
                                ref
                                    .read(teacherListProvider.notifier)
                                    .loadInitialData();
                              }
                            },
                    ),
                  ],
                ),
              ),

            // Section A: PERSONAL & CONTACT INFORMATION
            _buildSectionHeader('PERSONAL & CONTACT INFORMATION'),
            const SizedBox(height: AppSpacing.sm),

            // Row 1: Full Name * (full width)
            _buildField(
              label: 'Full Name *',
              fieldKey: 'TName',
              isEdit: isEdit,
              focusNode: _nameFocusNode,
              errorText: state.fieldErrors['TName'],
              placeholder: 'e.g. Syed Wazahat Raza Zaidi',
              onChanged: (val) => notifier.updateField('TName', val),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 2: Father/Spouse Name, DOB
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Father / Spouse Name',
                    fieldKey: 'TFName',
                    isEdit: isEdit,
                    placeholder: 'e.g. Syed Ibn-i-Hassan Zaidi',
                    onChanged: (val) => notifier.updateField('TFName', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildDateField(
                    label: 'Date of Birth',
                    value: current?.dob,
                    isEdit: isEdit,
                    onChanged: (val) => notifier.updateField('DOB', val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 3: CNIC *, Primary Mobile *
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'CNIC *',
                    fieldKey: 'TCNIC',
                    isEdit: isEdit,
                    focusNode: _cnicFocusNode,
                    errorText: state.fieldErrors['TCNIC'],
                    placeholder: 'e.g. 38302-1111111-1',
                    onChanged: (val) => notifier.updateField('TCNIC', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildField(
                    label: 'Primary Mobile *',
                    fieldKey: 'TContactNo1',
                    isEdit: isEdit,
                    focusNode: _contactFocusNode,
                    errorText: state.fieldErrors['TContactNo1'],
                    placeholder: 'e.g. 0333-1111111',
                    onChanged: (val) =>
                        notifier.updateField('TContactNo1', val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 4: Secondary Mobile, Domicile
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Secondary Mobile',
                    fieldKey: 'TContactNo2',
                    isEdit: isEdit,
                    placeholder: 'e.g. 0321-1234567',
                    onChanged: (val) =>
                        notifier.updateField('TContactNo2', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildField(
                    label: 'Domicile',
                    fieldKey: 'Domicile',
                    isEdit: isEdit,
                    placeholder: 'e.g. Mianwali',
                    onChanged: (val) => notifier.updateField('Domicile', val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 5: Residential Address (full width)
            _buildField(
              label: 'Residential Address',
              fieldKey: 'TAddress',
              isEdit: isEdit,
              placeholder: 'e.g. Branch Address',
              onChanged: (val) => notifier.updateField('TAddress', val),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Section B: EMPLOYMENT & INSTITUTIONAL PROFILE
            _buildSectionHeader('EMPLOYMENT & INSTITUTIONAL PROFILE'),
            const SizedBox(height: AppSpacing.sm),

            // Row 1: Employment Category * Dropdown, Teaching Subject
            Row(
              children: [
                Expanded(
                  child: isEdit
                      ? _buildDropdownField(
                          label: 'Employment Category *',
                          value: current?.tCat ?? 'Teacher',
                          items: _employmentCategories,
                          onChanged: (val) {
                            if (val != null) {
                              notifier.updateField('TCat', val);
                            }
                          },
                        )
                      : _buildViewField(
                          label: 'Employment Category *',
                          value: current?.tCat ?? 'Teacher',
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildField(
                    label: 'Teaching Subject',
                    fieldKey: 'TSubject',
                    isEdit: isEdit,
                    placeholder: 'e.g. Physics',
                    onChanged: (val) => notifier.updateField('TSubject', val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 2: Date of Joining (DOJoing), Date of Leaving (TDoLeft)
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Date of Joining',
                    value: current?.doJoing,
                    isEdit: isEdit,
                    onChanged: (val) => notifier.updateField('DOJoing', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildDateField(
                    label: 'Date of Leaving',
                    value: current?.tDoLeft,
                    isEdit: isEdit,
                    onChanged: (val) => notifier.updateField('TDoLeft', val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 3: Physical Office File No, Biometric Device ID
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Physical Office File No',
                    fieldKey: 'OfficeFile',
                    isEdit: isEdit,
                    placeholder: 'e.g. FILE-ADM-001',
                    onChanged: (val) => notifier.updateField('OfficeFile', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildField(
                    label: 'Biometric Device ID',
                    fieldKey: 'TBioSer',
                    isEdit: isEdit,
                    placeholder: 'e.g. 101',
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      notifier.updateField('TBioSer', parsed);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 4: SMS Notification Contact, Active Employment Switch
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'SMS Notification Contact',
                    fieldKey: 'AttSMSCont',
                    isEdit: isEdit,
                    placeholder: 'e.g. 0333-1111111',
                    onChanged: (val) => notifier.updateField('AttSMSCont', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Employment Status',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isEdit
                              ? AppColors.surfaceRaised
                              : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Row(
                          children: [
                            Text(
                              current?.isActive == true ? 'Active' : 'Relieved',
                              style: AppTypography.body.copyWith(
                                color: current?.isActive == true
                                    ? AppColors.statusSuccessText
                                    : AppColors.statusErrorText,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: current?.isActive ?? true,
                              activeThumbColor: AppColors.brandPrimary,
                              onChanged: isReadOnlyUser
                                  ? null
                                  : (active) async {
                                      if (isEdit) {
                                        notifier.updateField(
                                          'TIsPresent',
                                          active ? 'Y' : 'N',
                                        );
                                      } else {
                                        final tid = current?.teacherId;
                                        if (tid != null) {
                                          await notifier.toggleActiveStatus(
                                            tid,
                                            active,
                                          );
                                          ref
                                              .read(
                                                teacherListProvider.notifier,
                                              )
                                              .loadInitialData();
                                        }
                                      }
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
            const SizedBox(height: AppSpacing.lg),

            // Section C: EMERGENCY CONTACT
            _buildSectionHeader('EMERGENCY CONTACT'),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Emergency Contact Name',
                    fieldKey: 'TEmergencyContactName',
                    isEdit: isEdit,
                    placeholder: 'e.g. Dr. Aamir Ali',
                    onChanged: (val) =>
                        notifier.updateField('TEmergencyContactName', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildField(
                    label: 'Emergency Contact Phone',
                    fieldKey: 'TEmergencyContactNo',
                    isEdit: isEdit,
                    placeholder: 'e.g. 0300-9876543',
                    onChanged: (val) =>
                        notifier.updateField('TEmergencyContactNo', val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Section D: ADMINISTRATIVE REMARKS
            _buildSectionHeader('ADMINISTRATIVE REMARKS'),
            const SizedBox(height: AppSpacing.sm),

            _buildField(
              label: 'Administrative Remarks / Detail',
              fieldKey: 'Detail',
              isEdit: isEdit,
              maxLines: 4,
              placeholder: 'Add any disciplinary or administrative notes...',
              onChanged: (val) => notifier.updateField('Detail', val),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: CLASS & SUBJECT ASSIGNMENTS
  // ===========================================================================
  Widget _buildTab2ClassSubjects(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final tName = state.currentTeacher?.tName ?? 'Faculty';
    final assignments = state.subjectAssignments;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header with right CTA
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: AppColors.surfaceSubtle,
            child: Row(
              children: [
                Text(
                  'SUBJECTS TAUGHT BY ${tName.toUpperCase()}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (state.isDirty) {
                      final discard = await _showDiscardDialog(
                        context,
                        isNew: state.isNew,
                      );
                      if (!discard) return;
                    }
                    if (context.mounted) {
                      final tId = _resolvedId ?? widget.teacherId ?? 1;
                      await context.push('/exams/subjects?fromTeacherId=$tId');
                      notifier.refreshChildData();
                    }
                  },
                  icon: const Icon(Icons.add, size: 13),
                  label: const Text(
                    'Assign Class Subject',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderDefault,
          ),

          // Table or Empty State
          Expanded(
            child: assignments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 40,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'This teacher is not assigned to any class subjects yet.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (state.isDirty) {
                              final discard = await _showDiscardDialog(
                                context,
                                isNew: state.isNew,
                              );
                              if (!discard) return;
                            }
                            if (context.mounted) {
                              final tId = _resolvedId ?? widget.teacherId ?? 1;
                              await context.push(
                                '/exams/subjects?fromTeacherId=$tId',
                              );
                              notifier.refreshChildData();
                            }
                          },
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Assign Class Subject'),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sticky Header
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          color: AppColors.surfaceSubtle,
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 60,
                                child: Text('ID', style: _tblHeaderStyle),
                              ),
                              SizedBox(
                                width: 150,
                                child: Text(
                                  'Class Name',
                                  style: _tblHeaderStyle,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Subject Name',
                                  style: _tblHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'Theory Marks',
                                  textAlign: TextAlign.right,
                                  style: _tblHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'Practical Marks',
                                  textAlign: TextAlign.right,
                                  style: _tblHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Total Marks',
                                  textAlign: TextAlign.right,
                                  style: _tblHeaderStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.borderDefault,
                        ),

                        // Rows
                        Expanded(
                          child: ListView.builder(
                            itemCount: assignments.length,
                            itemBuilder: (ctx, idx) {
                              final row = assignments[idx];
                              final isEven = idx.isEven;
                              final bg = isEven
                                  ? AppColors.surfaceRaised
                                  : AppColors.surfaceSubtle;

                              return Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  border: const Border(
                                    bottom: BorderSide(
                                      color: AppColors.borderSubtle,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        '#${row.subjClsId}',
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        row.className,
                                        style: AppTypography.body.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        row.subjName,
                                        style: AppTypography.body.copyWith(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        row.totalMarks.toStringAsFixed(0),
                                        textAlign: TextAlign.right,
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        row.totalPracticalMarks.toStringAsFixed(
                                          0,
                                        ),
                                        textAlign: TextAlign.right,
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        row.combinedMarks.toStringAsFixed(0),
                                        textAlign: TextAlign.right,
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  // ===========================================================================
  // TAB 3: PAYROLL & SALARY HISTORY
  // ===========================================================================
  Widget _buildTab3PayrollHistory(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final slips = state.salarySlips;
    final n = slips.length;
    final headerTitle =
        'RECENT SALARY DISBURSEMENTS ($n ${n == 1 ? 'slip' : 'slips'})';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header with right CTA
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: AppColors.surfaceSubtle,
            child: Row(
              children: [
                Text(
                  headerTitle,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (state.isDirty) {
                      final discard = await _showDiscardDialog(
                        context,
                        isNew: state.isNew,
                      );
                      if (!discard) return;
                    }
                    if (context.mounted) {
                      final tid = _resolvedId ?? widget.teacherId ?? 1;
                      context.go('/staff/salary?fromTeacherId=$tid');
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 13),
                  label: const Text(
                    'View Full Payroll Terminal',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderDefault,
          ),

          // Table or Empty State
          Expanded(
            child: slips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No salary slips recorded for this employee yet.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sticky Header
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          color: AppColors.surfaceSubtle,
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text('Slip ID', style: _tblHeaderStyle),
                              ),
                              SizedBox(
                                width: 140,
                                child: Text('Month', style: _tblHeaderStyle),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'Gross',
                                  textAlign: TextAlign.right,
                                  style: _tblHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'Deductions',
                                  textAlign: TextAlign.right,
                                  style: _tblHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'Net Paid',
                                  textAlign: TextAlign.right,
                                  style: _tblHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  'Status',
                                  textAlign: TextAlign.center,
                                  style: _tblHeaderStyle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Paid Date',
                                  textAlign: TextAlign.right,
                                  style: _tblHeaderStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.borderDefault,
                        ),

                        // Rows
                        Expanded(
                          child: ListView.builder(
                            itemCount: slips.length,
                            itemBuilder: (ctx, idx) {
                              final slip = slips[idx];
                              final isEven = idx.isEven;
                              final bg = isEven
                                  ? AppColors.surfaceRaised
                                  : AppColors.surfaceSubtle;
                              final isPaid = slip.isPaid == 'Y';

                              return Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  border: const Border(
                                    bottom: BorderSide(
                                      color: AppColors.borderSubtle,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        slip.tSalMasId,
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        slip.salMonth,
                                        style: AppTypography.body.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        'Rs. ${slip.grossAmount.toStringAsFixed(0)}',
                                        textAlign: TextAlign.right,
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        'Rs. ${slip.tDeductions.toStringAsFixed(0)}',
                                        textAlign: TextAlign.right,
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                          color: slip.tDeductions > 0
                                              ? AppColors.statusErrorText
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        'Rs. ${slip.netAmount.toStringAsFixed(0)}',
                                        textAlign: TextAlign.right,
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandPrimary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPaid
                                                ? AppColors.statusSuccessBg
                                                : AppColors.statusWarningBg,
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.sm,
                                            ),
                                          ),
                                          child: Text(
                                            isPaid ? 'Paid' : 'Pending',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: isPaid
                                                      ? AppColors
                                                            .statusSuccessText
                                                      : AppColors
                                                            .statusWarningText,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        isPaid ? (slip.paidDate ?? '-') : '-',
                                        textAlign: TextAlign.right,
                                        style: AppTypography.monospace.copyWith(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  // ===========================================================================
  // TAB 4: QUALIFICATIONS & CREDENTIALS
  // ===========================================================================
  Widget _buildTab4Qualifications(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final isEdit = state.isEditMode;

    return Scrollbar(
      controller: _tab4ScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _tab4ScrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('QUALIFICATIONS & CREDENTIALS'),
            const SizedBox(height: AppSpacing.sm),

            // Row 1: Academic Degrees (TQualification), Professional Certifications (TProfessional)
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Academic Degrees',
                    fieldKey: 'TQualification',
                    isEdit: isEdit,
                    placeholder: 'e.g. B.Sc, MA',
                    onChanged: (val) =>
                        notifier.updateField('TQualification', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildField(
                    label: 'Professional Certifications',
                    fieldKey: 'TProfessional',
                    isEdit: isEdit,
                    placeholder: 'e.g. BEd, DIAEd',
                    onChanged: (val) =>
                        notifier.updateField('TProfessional', val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 2: Teaching Certificates (TCertificate), Field of Expertise (TFiledOfExperty)
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Teaching Certificates',
                    fieldKey: 'TCertificate',
                    isEdit: isEdit,
                    placeholder: 'e.g. IT, CT, TE',
                    onChanged: (val) =>
                        notifier.updateField('TCertificate', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildField(
                    label: 'Field of Expertise',
                    fieldKey: 'TFiledOfExperty',
                    isEdit: isEdit,
                    placeholder: 'e.g. Education, Sciences',
                    onChanged: (val) =>
                        notifier.updateField('TFiledOfExperty', val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 3: Cumulative Experience (TExperience), Special Skills / Distinctions (TAnySpeciality)
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Cumulative Experience',
                    fieldKey: 'TExperience',
                    isEdit: isEdit,
                    placeholder: 'e.g. 15 Years',
                    onChanged: (val) =>
                        notifier.updateField('TExperience', val),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildField(
                    label: 'Special Skills / Distinctions',
                    fieldKey: 'TAnySpeciality',
                    isEdit: isEdit,
                    placeholder: 'e.g. Science Fair Mentor',
                    onChanged: (val) =>
                        notifier.updateField('TAnySpeciality', val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // REUSABLE FIELD BUILDERS
  // ===========================================================================

  Widget _buildSectionHeader(String title) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surfaceSubtle,
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: AppTypography.label.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String fieldKey,
    required bool isEdit,
    FocusNode? focusNode,
    String? errorText,
    String? placeholder,
    int maxLines = 1,
    TextInputType? keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    final controller = _controllers[fieldKey];
    final textVal = controller?.text ?? '';

    if (!isEdit) {
      return _buildViewField(label: label, value: textVal, maxLines: maxLines);
    }

    final hasError = errorText != null && errorText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: hasError
                ? AppColors.statusErrorText
                : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          key: ValueKey('${fieldKey}_field'),
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTypography.body.copyWith(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.surfaceRaised,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: maxLines > 1 ? 10 : 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: hasError
                    ? AppColors.statusErrorText
                    : AppColors.borderDefault,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: hasError
                    ? AppColors.statusErrorText
                    : AppColors.borderDefault,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: hasError
                    ? AppColors.statusErrorText
                    : AppColors.brandPrimary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 2),
          Text(
            errorText,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.statusErrorText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildViewField({
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    final clean = value.trim();
    final isBlank = clean.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: maxLines > 1 ? null : 38,
          constraints: maxLines > 1
              ? const BoxConstraints(minHeight: 60)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            isBlank ? 'Not recorded' : clean,
            style: AppTypography.body.copyWith(
              color: isBlank ? AppColors.textMuted : AppColors.textPrimary,
              fontSize: 13,
              fontStyle: isBlank ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: maxLines,
            overflow: maxLines == 1 ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required String? value,
    required bool isEdit,
    required ValueChanged<String?> onChanged,
  }) {
    if (!isEdit) {
      return _buildViewField(label: label, value: value ?? '');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final now = ref.read(clockProvider)();
            DateTime initDate = now;
            if (value != null && value.isNotEmpty) {
              final parsed = DateTime.tryParse(value);
              if (parsed != null) initDate = parsed;
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initDate,
              firstDate: DateTime(1940),
              lastDate: DateTime(2050),
            );
            if (picked != null) {
              final formatted =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              onChanged(formatted);
            }
          },
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (value != null && value.isNotEmpty)
                        ? value
                        : 'Select date...',
                    style: AppTypography.body.copyWith(
                      color: (value != null && value.isNotEmpty)
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: DropdownButtonFormField<String>(
            initialValue: items.contains(value) ? value : items.first,
            isDense: true,
            isExpanded: true,
            dropdownColor: AppColors.surfaceRaised,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceRaised,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
            ),
            items: items.map((cat) {
              return DropdownMenuItem<String>(
                value: cat,
                child: Text(
                  cat,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MOBILE STITCH ARCHITECTURE (< 600px)
  // ===========================================================================

  Widget _buildMobileLayout(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
    bool isReadOnlyUser,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMobileHeroCard(
                      context,
                      state,
                      notifier,
                      isReadOnlyUser,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.statusErrorBg,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border:
                              Border.all(color: AppColors.statusErrorBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.statusErrorText,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                state.errorMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.statusErrorText,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.statusErrorText,
                              ),
                              splashRadius: 12,
                              onPressed: notifier.clearErrorMessage,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _buildMobileTabBar(context, state, notifier),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _buildMobileTabContent(context, state, notifier),
                  ],
                ),
              ),
            ),
            _buildMobileStickyActions(
              context,
              state,
              notifier,
              isReadOnlyUser,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeroCard(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
    bool isReadOnlyUser,
  ) {
    final current = state.currentTeacher;
    final isNew = state.isNew;
    final teacherName = isNew
        ? 'New Employee'
        : (current?.tName.isNotEmpty == true
            ? current!.tName
            : 'Teacher Profile');
    final designation =
        current?.tCat.isNotEmpty == true ? current!.tCat : 'Teacher';
    final subject =
        current?.tSubject?.isNotEmpty == true ? current!.tSubject! : 'General';
    final isActive = current?.isActive ?? true;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      elevation: 0,
      color: AppColors.surfaceRaised,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3.5,
              color: AppColors.accentStaff,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _getAvatarBg(_resolvedId ?? 1),
                      child: Text(
                        isNew ? 'N' : (current?.initials ?? 'T'),
                        style: AppTypography.monospace.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  teacherName,
                                  style: AppTypography.h3.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              MobileStatusPill(
                                label: isActive ? 'Active' : 'Inactive',
                                variant: isActive
                                    ? MobileStatusVariant.success
                                    : MobileStatusVariant.neutral,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$designation • $subject',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (current != null && current.tCnic.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              current.tCnic,
                              style: AppTypography.monospace.copyWith(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTabBar(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final subjCount = state.subjectAssignments.length;
    final salCount = state.salarySlips.length;

    final tabs = [
      '1. Personal & Biodata',
      state.isNew ? '2. Class Subjects' : '2. Class Subjects ($subjCount)',
      state.isNew ? '3. Payroll History' : '3. Payroll History ($salCount)',
      '4. Qualifications',
    ];

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final isSelected = state.activeTab == idx;
            final isDisabled = state.isNew && (idx == 1 || idx == 2);

            return InkWell(
              onTap: isDisabled ? null : () => notifier.switchTab(idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppColors.accentStaff
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  tabs[idx],
                  style: AppTypography.label.copyWith(
                    color: isDisabled
                        ? AppColors.textMuted
                        : (isSelected
                            ? AppColors.accentStaff
                            : AppColors.textSecondary),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMobileTabContent(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    switch (state.activeTab) {
      case 0:
        return _buildMobileTab1PersonalBiodata(context, state, notifier);
      case 1:
        return _buildMobileTab2ClassSubjects(context, state, notifier);
      case 2:
        return _buildMobileTab3PayrollHistory(context, state, notifier);
      case 3:
        return _buildMobileTab4Qualifications(context, state, notifier);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMobileTab1PersonalBiodata(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final current = state.currentTeacher;
    final isEdit = state.isEditMode;
    final isReadOnlyUser = ref.watch(sessionProvider)?.user.userLevel == 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!state.isNew && current != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              children: [
                Icon(
                  current.isActive
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  size: 18,
                  color: current.isActive
                      ? AppColors.statusSuccessText
                      : AppColors.statusErrorText,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Status: ${current.isActive ? "Active Faculty" : "Relieved"}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: current.isActive
                          ? AppColors.statusSuccessText
                          : AppColors.statusErrorText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  value: current.isActive,
                  activeThumbColor: AppColors.brandPrimary,
                  onChanged: isReadOnlyUser
                      ? null
                      : (active) async {
                          final tid = current.teacherId;
                          if (tid != null) {
                            await notifier.toggleActiveStatus(tid, active);
                            ref
                                .read(teacherListProvider.notifier)
                                .loadInitialData();
                          }
                        },
                ),
              ],
            ),
          ),

        _buildSectionHeader('PERSONAL & CONTACT INFORMATION'),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Full Name *',
          fieldKey: 'TName',
          isEdit: isEdit,
          focusNode: _nameFocusNode,
          errorText: state.fieldErrors['TName'],
          placeholder: 'e.g. Syed Wazahat Raza Zaidi',
          onChanged: (val) => notifier.updateField('TName', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Father / Spouse Name',
          fieldKey: 'TFName',
          isEdit: isEdit,
          placeholder: 'e.g. Syed Ibn-i-Hassan Zaidi',
          onChanged: (val) => notifier.updateField('TFName', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildDateField(
          label: 'Date of Birth',
          value: current?.dob,
          isEdit: isEdit,
          onChanged: (val) => notifier.updateField('DOB', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'CNIC *',
          fieldKey: 'TCNIC',
          isEdit: isEdit,
          focusNode: _cnicFocusNode,
          errorText: state.fieldErrors['TCNIC'],
          placeholder: 'e.g. 38302-1111111-1',
          onChanged: (val) => notifier.updateField('TCNIC', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Primary Mobile *',
          fieldKey: 'TContactNo1',
          isEdit: isEdit,
          focusNode: _contactFocusNode,
          errorText: state.fieldErrors['TContactNo1'],
          placeholder: 'e.g. 0333-1111111',
          onChanged: (val) => notifier.updateField('TContactNo1', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Secondary Mobile',
          fieldKey: 'TContactNo2',
          isEdit: isEdit,
          placeholder: 'e.g. 0321-1234567',
          onChanged: (val) => notifier.updateField('TContactNo2', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Domicile',
          fieldKey: 'Domicile',
          isEdit: isEdit,
          placeholder: 'e.g. Mianwali',
          onChanged: (val) => notifier.updateField('Domicile', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Residential Address',
          fieldKey: 'TAddress',
          isEdit: isEdit,
          placeholder: 'e.g. Branch Address',
          onChanged: (val) => notifier.updateField('TAddress', val),
        ),
        const SizedBox(height: AppSpacing.lg),

        _buildSectionHeader('EMPLOYMENT & COMPENSATION'),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Office File Number',
          fieldKey: 'OfficeFile',
          isEdit: isEdit,
          placeholder: 'e.g. OF-2018-042',
          onChanged: (val) => notifier.updateField('OfficeFile', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Biometric Serial',
          fieldKey: 'TBioSer',
          isEdit: isEdit,
          placeholder: 'e.g. BIO-1024',
          onChanged: (val) => notifier.updateField('TBioSer', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Subject Specialization',
          fieldKey: 'TSubject',
          isEdit: isEdit,
          placeholder: 'e.g. Mathematics, English',
          onChanged: (val) => notifier.updateField('TSubject', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        isEdit
            ? _buildDropdownField(
                label: 'Salary Category',
                value: state.currentTeacher?.tCat ?? 'Teacher',
                items: _employmentCategories,
                onChanged: (val) {
                  if (val != null) {
                    notifier.updateField('TCat', val);
                  }
                },
              )
            : _buildViewField(
                label: 'Salary Category',
                value: state.currentTeacher?.tCat ?? 'Teacher',
              ),
        const SizedBox(height: AppSpacing.lg),

        _buildSectionHeader('EMERGENCY CONTACT'),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Emergency Contact Name',
          fieldKey: 'TEmergencyContactName',
          isEdit: isEdit,
          placeholder: 'e.g. Dr. Aamir Ali',
          onChanged: (val) =>
              notifier.updateField('TEmergencyContactName', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Emergency Contact Phone',
          fieldKey: 'TEmergencyContactNo',
          isEdit: isEdit,
          placeholder: 'e.g. 0300-7654321',
          onChanged: (val) =>
              notifier.updateField('TEmergencyContactNo', val),
        ),
      ],
    );
  }

  Widget _buildMobileTab2ClassSubjects(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final assignments = state.subjectAssignments;
    if (assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This teacher is not assigned to any class subjects yet.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assignments.length,
      itemBuilder: (ctx, idx) {
        final a = assignments[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
          elevation: 0,
          color: AppColors.surfaceRaised,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3.5,
                  color: AppColors.accentStaff,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                a.className,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'ID: ${a.subjId}',
                              style: AppTypography.monospace.copyWith(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.subjName,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Theory: ${a.totalMarks.toStringAsFixed(0)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Practical: ${a.totalPracticalMarks.toStringAsFixed(0)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Total: ${a.combinedMarks.toStringAsFixed(0)}',
                              style: AppTypography.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentStaff,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildMobileTab3PayrollHistory(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final slips = state.salarySlips;
    if (slips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No salary slips recorded for this employee yet.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currency = NumberFormat('#,##0');
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slips.length,
      itemBuilder: (ctx, idx) {
        final slip = slips[idx];
        final isPaid = slip.isPaid == 'Y';
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
          elevation: 0,
          color: AppColors.surfaceRaised,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3.5,
                  color: AppColors.accentStaff,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                slip.salMonth,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            MobileStatusPill(
                              label: isPaid ? 'Paid' : 'Pending',
                              variant: isPaid
                                  ? MobileStatusVariant.success
                                  : MobileStatusVariant.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Slip #${slip.tSalMasId}',
                          style: AppTypography.monospace.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Gross: Rs. ${currency.format(slip.grossAmount)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Deduct: Rs. ${currency.format(slip.tDeductions)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: slip.tDeductions > 0
                                    ? AppColors.statusErrorText
                                    : AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Net: Rs. ${currency.format(slip.netAmount)}',
                              style: AppTypography.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentStaff,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildMobileTab4Qualifications(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
  ) {
    final isEdit = state.isEditMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('QUALIFICATIONS & CREDENTIALS'),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Academic Degrees',
          fieldKey: 'TQualification',
          isEdit: isEdit,
          placeholder: 'e.g. B.Sc, MA',
          onChanged: (val) => notifier.updateField('TQualification', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Professional Certifications',
          fieldKey: 'TProfessional',
          isEdit: isEdit,
          placeholder: 'e.g. BEd, DIAEd',
          onChanged: (val) => notifier.updateField('TProfessional', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Teaching Certificates',
          fieldKey: 'TCertificate',
          isEdit: isEdit,
          placeholder: 'e.g. IT, CT, TE',
          onChanged: (val) => notifier.updateField('TCertificate', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Field of Expertise',
          fieldKey: 'TFiledOfExperty',
          isEdit: isEdit,
          placeholder: 'e.g. Education, Sciences',
          onChanged: (val) => notifier.updateField('TFiledOfExperty', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Cumulative Experience',
          fieldKey: 'TExperience',
          isEdit: isEdit,
          placeholder: 'e.g. 15 Years',
          onChanged: (val) => notifier.updateField('TExperience', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Special Skills / Distinctions',
          fieldKey: 'TAnySpeciality',
          isEdit: isEdit,
          placeholder: 'e.g. Science Fair Organizer, IT Incharge',
          onChanged: (val) => notifier.updateField('TAnySpeciality', val),
        ),
        const SizedBox(height: AppSpacing.sm),

        _buildField(
          label: 'Biographical Narrative',
          fieldKey: 'Detail',
          isEdit: isEdit,
          maxLines: 4,
          placeholder:
              'Comprehensive service record and administrative achievements...',
          onChanged: (val) => notifier.updateField('Detail', val),
        ),
      ],
    );
  }

  Widget _buildMobileStickyActions(
    BuildContext context,
    TeacherProfileState state,
    TeacherProfileNotifier notifier,
    bool isReadOnlyUser,
  ) {
    final isNew = state.isNew;
    final isEdit = state.isEditMode;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: isNew
          ? Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: state.canSave
                          ? () => _handleSave(state, notifier)
                          : null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Create Employee'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentStaff,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _handleBackToDirectory(state, notifier),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            )
          : isEdit
              ? Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: state.canSave
                              ? () => _handleSave(state, notifier)
                              : null,
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Save Teacher'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentStaff,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => _handleCancelEdits(state, notifier),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    if (!isReadOnlyUser) ...[
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => notifier.enterEditMode(
                              userLvl:
                                  ref.read(sessionProvider)?.user.userLevel,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit Profile'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentStaff,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _handleBackToDirectory(state, notifier),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Directory'),
                      ),
                    ),
                  ],
                ),
    );
  }
}

const TextStyle _tblHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: AppColors.textSecondary,
  letterSpacing: 0.5,
);
