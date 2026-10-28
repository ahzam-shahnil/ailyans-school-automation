import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/class_section_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Screen 25 - ClassSectionScreen at `/academics/classes`.
/// Implements §S6 (`frmClass` at `0x00415b24`, `ObjID: 4`).
class ClassSectionScreen extends ConsumerStatefulWidget {
  const ClassSectionScreen({super.key});

  @override
  ConsumerState<ClassSectionScreen> createState() => _ClassSectionScreenState();
}

class _ClassSectionScreenState extends ConsumerState<ClassSectionScreen> {
  final TextEditingController _classNameCtrl = TextEditingController();
  final TextEditingController _secNameCtrl = TextEditingController();
  final TextEditingController _roomCtrl = TextEditingController();
  final TextEditingController _secRemarksCtrl = TextEditingController();

  final ScrollController _classScrollController = ScrollController();
  final ScrollController _sectionScrollController = ScrollController();

  bool _isDialogOpen = false;
  BuildContext? _activeDialogContext;

  int get _userLvl => ref.read(sessionProvider)?.user.userLevel ?? 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userLevel = ref.read(sessionProvider)?.user.userLevel ?? 1;
      final notifier = ref.read(classSectionProvider.notifier);
      notifier.setReadOnly(userLevel == 3);
      await notifier.loadInitialData();

      if (mounted) {
        final state = ref.read(classSectionProvider);
        if (state.selectedClassName.isNotEmpty) {
          _classNameCtrl.text = state.selectedClassName;
        }
      }
    });
  }

  @override
  void dispose() {
    _classNameCtrl.dispose();
    _secNameCtrl.dispose();
    _roomCtrl.dispose();
    _secRemarksCtrl.dispose();
    _classScrollController.dispose();
    _sectionScrollController.dispose();
    super.dispose();
  }

  void _invalidateSharedProviders() {
    ref.invalidate(classesProvider);
    ref.invalidate(sectionsProvider);
    ref.invalidate(shellMetadataProvider);
  }

  // ===========================================================================
  // CLASS ACTION HANDLERS
  // ===========================================================================

  void _handleNewClass() {
    final notifier = ref.read(classSectionProvider.notifier);
    notifier.enterNewClassMode();
    _classNameCtrl.clear();
  }

  void _handleEditClass() {
    final notifier = ref.read(classSectionProvider.notifier);
    final state = ref.read(classSectionProvider);
    notifier.enterEditClassMode();
    _classNameCtrl.text = state.selectedClassName;
  }

  void _handleCancelClassEdit() {
    final notifier = ref.read(classSectionProvider.notifier);
    notifier.cancelClassEdit();
    _classNameCtrl.text = ref.read(classSectionProvider).selectedClassName;
  }

  Future<void> _handleSaveClass() async {
    final notifier = ref.read(classSectionProvider.notifier);
    final ok = await notifier.saveClass(
      className: _classNameCtrl.text,
      currentUserLvl: _userLvl,
    );

    if (!mounted) return;
    if (ok) {
      _invalidateSharedProviders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class Updated/Added Successfully'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ===========================================================================
  // SECTION ACTION HANDLERS
  // ===========================================================================

  void _handleNewSection() {
    final notifier = ref.read(classSectionProvider.notifier);
    notifier.enterNewSectionMode();
    final state = ref.read(classSectionProvider);
    if (state.errorMessage == null) {
      _showSectionEditorDialog();
    }
  }

  void _handleEditSection(int classSecId) {
    final notifier = ref.read(classSectionProvider.notifier);
    notifier.enterEditSectionMode(classSecId);
    final state = ref.read(classSectionProvider);
    if (state.errorMessage == null) {
      _showSectionEditorDialog();
    }
  }

  void _showSectionEditorDialog() {
    final state = ref.read(classSectionProvider);
    _secNameCtrl.text = state.editingSecName;
    _roomCtrl.text = state.editingRoomNo;
    _secRemarksCtrl.text = state.editingSecRemarks;
    _isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        _activeDialogContext = dialogCtx;
        return _buildSectionEditorDialog(dialogCtx);
      },
    ).then((_) {
      _isDialogOpen = false;
      _activeDialogContext = null;
      if (mounted) {
        ref.read(classSectionProvider.notifier).cancelSectionEdit();
      }
    });
  }

  Future<void> _handleSaveSection(BuildContext dialogCtx) async {
    final notifier = ref.read(classSectionProvider.notifier);
    notifier.setEditingSecName(_secNameCtrl.text);
    notifier.setEditingRoomNo(_roomCtrl.text);
    notifier.setEditingSecRemarks(_secRemarksCtrl.text);

    final ok = await notifier.saveSection(currentUserLvl: _userLvl);
    if (!mounted) return;

    if (ok) {
      if (dialogCtx.mounted) {
        Navigator.of(dialogCtx).pop();
      }
      _invalidateSharedProviders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Section Saved Successfully'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleDeleteSection(int classSecId) async {
    final state = ref.read(classSectionProvider);
    final sec = state.sections.firstWhere(
      (s) => (s['ClassSecID'] as num).toInt() == classSecId,
      orElse: () => <String, dynamic>{},
    );
    if (sec.isEmpty) return;

    final secName = sec['SecName'] as String? ?? '';
    final className = state.selectedClassName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section?'),
        content: Text(
          'Remove section "$secName" from $className? This cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(classSectionProvider.notifier);
    final ok = await notifier.deleteSection(
      classSecId,
      currentUserLvl: _userLvl,
    );
    if (!mounted) return;

    if (ok) {
      _invalidateSharedProviders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Section Removed Successfully'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleRefreshSections() {
    final classId = ref.read(classSectionProvider).selectedClassId;
    ref.read(classSectionProvider.notifier).loadSectionsForClass(classId);
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(classSectionProvider);
    final notifier = ref.read(classSectionProvider.notifier);

    // Sync class name when selected class changes in view mode
    if (!state.isClassEditMode &&
        !state.isNewClassMode &&
        _classNameCtrl.text != state.selectedClassName) {
      _classNameCtrl.text = state.selectedClassName;
    }

    // Listen for toasts
    ref.listen<ClassSectionState>(classSectionProvider, (prev, next) {
      if (next.toast != null && next.toast != prev?.toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(classSectionProvider.notifier).clearToast();
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _handleNewClass,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            _handleNewClass,
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
          shift: true,
        ): _handleNewSection,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
            _handleNewSection,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true):
            _handleEditClass,
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
            _handleEditClass,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (_isDialogOpen && _activeDialogContext != null) {
            _handleSaveSection(_activeDialogContext!);
          } else if (state.isClassEditMode) {
            _handleSaveClass();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (_isDialogOpen && _activeDialogContext != null) {
            _handleSaveSection(_activeDialogContext!);
          } else if (state.isClassEditMode) {
            _handleSaveClass();
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isDialogOpen && _activeDialogContext != null) {
            Navigator.of(_activeDialogContext!).pop();
          } else if (state.isClassEditMode) {
            _handleCancelClassEdit();
          } else if (state.errorMessage != null) {
            notifier.clearError();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Region A: Header (52px)
              _buildRegionA(context, state),
              if (state.errorMessage != null && !_isDialogOpen) ...[
                const SizedBox(height: 8),
                _buildErrorBanner(state.errorMessage!, notifier),
              ],
              const SizedBox(height: 12),

              // Region B: Two-Column Master-Detail Layout
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT PANEL: Classes Master Hierarchy (Flex 35)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 340,
                        maxWidth: 420,
                      ),
                      child: SizedBox(
                        width: 360,
                        child: _buildLeftClassPanel(context, state, notifier),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // RIGHT PANEL: Sections Cohort Management (Flex 65)
                    Expanded(
                      child: _buildRightSectionPanel(context, state, notifier),
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

  // ===========================================================================
  // REGION A: Header
  // ===========================================================================

  Widget _buildRegionA(BuildContext context, ClassSectionState state) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Dashboard',
            onPressed: () => context.go('/dashboard'),
          ),
          const SizedBox(width: 8),
          Text(
            'Classes & Sections',
            style: AppTypography.h2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),

          // ID Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.statusInfoBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '#${state.selectedClassId ?? "none"}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.statusInfoText,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Total Classes Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.statusSuccessBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${state.classes.length} Classes',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.statusSuccessText,
              ),
            ),
          ),

          if (state.readOnly) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusWarningBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text(
                'Read-only',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.statusWarningText,
                ),
              ),
            ),
          ],

          const Spacer(),

          OutlinedButton.icon(
            onPressed: () => context.go('/academics/subjects'),
            icon: const Icon(Icons.menu_book_outlined, size: 16),
            label: const Text(
              'Subject Catalog',
              style: TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REGION B (LEFT): Class Master Panel
  // ===========================================================================

  Widget _buildLeftClassPanel(
    BuildContext context,
    ClassSectionState state,
    ClassSectionNotifier notifier,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      color: AppColors.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ACADEMIC CLASSES',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _handleNewClass,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text(
                    'New Class (Ctrl+N)',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Form row for Class Name
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExternalLabel(
                  state.isNewClassMode
                      ? 'New Class Name *'
                      : 'Selected Class Name *',
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _classNameCtrl,
                    readOnly: !state.isClassEditMode,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'e.g. Class 10, Play Group',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      filled: !state.isClassEditMode,
                      fillColor:
                          state.isClassEditMode
                              ? Colors.transparent
                              : AppColors.surfaceSubtle,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(
                          color: AppColors.borderDefault,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(
                          color: AppColors.borderDefault,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (state.isClassEditMode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _handleCancelClassEdit,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: _handleSaveClass,
                        icon: const Icon(Icons.save_outlined, size: 15),
                        label: const Text(
                          'Save Class (Ctrl+S)',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _handleEditClass,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text(
                        'Edit (Ctrl+E)',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Scrollable Class list
          Expanded(
            child: Scrollbar(
              controller: _classScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _classScrollController,
                itemCount: state.classes.length,
                itemExtent: 44,
                itemBuilder: (context, index) {
                  final row = state.classes[index];
                  final cid = (row['ClassID'] as num).toInt();
                  final cname = row['CName'] as String? ?? '';
                  final secCount = (row['SectionCount'] as num?)?.toInt() ?? 0;
                  final isSelected =
                      !state.isNewClassMode && state.selectedClassId == cid;

                  return InkWell(
                    onTap: () {
                      notifier.selectClass(cid);
                      _classNameCtrl.text = cname;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandPrimary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : Colors.transparent,
                            width: 3,
                          ),
                          bottom: const BorderSide(
                            color: AppColors.borderSubtle,
                            width: 0.5,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          // Mono ID Badge
                          Container(
                            width: 44,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '#$cid',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Class Name
                          Expanded(
                            child: Text(
                              cname,
                              style: AppTypography.body.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Section Count Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusInfoBg,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '$secCount Sec',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.statusInfoText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REGION B (RIGHT): Section Cohort Panel
  // ===========================================================================

  Widget _buildRightSectionPanel(
    BuildContext context,
    ClassSectionState state,
    ClassSectionNotifier notifier,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      color: AppColors.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.selectedClassId != null
                        ? 'Sections for: ${state.selectedClassName} (ID: #${state.selectedClassId})'
                        : 'Select a class to manage sections',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _handleNewSection,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'New Section (Ctrl+Shift+N)',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _handleRefreshSections,
                  tooltip: 'Refresh sections',
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Table or Empty state
          Expanded(
            child: state.selectedClassId == null
                ? _buildEmptyState(
                    icon: Icons.groups_outlined,
                    message: 'Select a class from the left panel to view and manage sections',
                  )
                : state.sections.isEmpty
                ? _buildEmptyState(
                    icon: Icons.groups_outlined,
                    message:
                        'No sections in ${state.selectedClassName}. Click [New Section (Ctrl+Shift+N)] to add one.',
                    action: TextButton.icon(
                      onPressed: _handleNewSection,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'New Section',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _buildSectionTableHeader(),
                      Expanded(
                        child: Scrollbar(
                          controller: _sectionScrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _sectionScrollController,
                            itemCount: state.sections.length,
                            itemExtent: 44,
                            itemBuilder: (context, index) {
                              final row = state.sections[index];
                              final secId = (row['ClassSecID'] as num).toInt();
                              final secName = row['SecName'] as String? ?? '';
                              final teacher =
                                  row['TeacherName'] as String? ??
                                  'Not assigned';
                              final proctor =
                                  row['ProctorName'] as String? ??
                                  'Not assigned';
                              final room = row['RoomNo'] as String? ?? '-';
                              final enrolled =
                                  (row['EnrolledCount'] as num?)?.toInt() ?? 0;

                              final isEven = index % 2 == 0;
                              return Container(
                                color: isEven
                                    ? AppColors.surfaceRaised
                                    : AppColors.surface,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        '#$secId',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        secName,
                                        style: AppTypography.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        teacher,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: teacher == 'Not assigned'
                                              ? AppColors.textMuted
                                              : AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        proctor,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: proctor == 'Not assigned'
                                              ? AppColors.textMuted
                                              : AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        room,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: enrolled > 0
                                                ? AppColors.statusSuccessBg
                                                : AppColors.surfaceSubtle,
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.sm,
                                            ),
                                          ),
                                          child: Text(
                                            '$enrolled students',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: enrolled > 0
                                                  ? AppColors.statusSuccessText
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            style: IconButton.styleFrom(
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(32, 32),
                                            ),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                            ),
                                            tooltip: 'Edit section',
                                            splashRadius: 16,
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                  width: 32,
                                                  height: 32,
                                                ),
                                            onPressed: () =>
                                                _handleEditSection(secId),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            style: IconButton.styleFrom(
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(32, 32),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: AppColors.statusErrorText,
                                            ),
                                            tooltip: 'Delete section',
                                            splashRadius: 16,
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                  width: 32,
                                                  height: 32,
                                                ),
                                            onPressed: () =>
                                                _handleDeleteSection(secId),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  Widget _buildSectionTableHeader() {
    return Container(
      height: 36,
      color: AppColors.surfaceSubtle,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 60,
            child: Text(
              '#ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(
            width: 70,
            child: Text(
              'Sec',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Incharge Teacher',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Proctor',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(
            width: 100,
            child: Text(
              'Room',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(
            width: 100,
            child: Center(
              child: Text(
                'Enrolled',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Actions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION EDITOR MODAL DIALOG
  // ===========================================================================

  Widget _buildSectionEditorDialog(BuildContext dialogCtx) {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(classSectionProvider);
        final notifier = ref.read(classSectionProvider.notifier);

        // Prepend current assignment if non-Teacher
        final currentTeacherId = state.editingSecTeacherId;
        final hasNonTeacherCurrent =
            currentTeacherId != null &&
            !state.teacherOptions.any(
              (t) => (t['TeacherID'] as num).toInt() == currentTeacherId,
            ) &&
            state.allTeachers.any(
              (t) => (t['TeacherID'] as num).toInt() == currentTeacherId,
            );

        Map<String, dynamic>? nonTeacherRecord;
        if (hasNonTeacherCurrent) {
          nonTeacherRecord = state.allTeachers.firstWhere(
            (t) => (t['TeacherID'] as num).toInt() == currentTeacherId,
          );
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 540,
            constraints: const BoxConstraints(maxHeight: 520),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.editingSectionId == null
                            ? 'New Section in ${state.selectedClassName}'
                            : 'Edit Section',
                        style: AppTypography.h3.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderSubtle),
                const SizedBox(height: 12),

                // Inline Error Banner in Dialog
                if (state.errorMessage != null) ...[
                  _buildErrorBanner(state.errorMessage!, notifier),
                  const SizedBox(height: 12),
                ],

                // Body Fields
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildExternalLabel('Section Name *'),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _secNameCtrl,
                            autofocus: true,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. A, B, Green',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                            ),
                            onChanged: notifier.setEditingSecName,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildExternalLabel('Incharge Teacher'),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 40,
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey(state.editingSecTeacherId),
                            initialValue: state.editingSecTeacherId,
                            isExpanded: true,
                            isDense: true,
                            menuMaxHeight: 400,
                            dropdownColor: AppColors.surfaceRaised,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  'Not assigned',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (hasNonTeacherCurrent &&
                                  nonTeacherRecord != null)
                                DropdownMenuItem<int?>(
                                  value: currentTeacherId,
                                  child: Text(
                                    '${nonTeacherRecord['TName']} (${nonTeacherRecord['TCat']}) - current assignment',
                                    style: const TextStyle(
                                      color: AppColors.statusWarningText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ...state.teacherOptions.map((t) {
                                final tid = (t['TeacherID'] as num).toInt();
                                final tname =
                                    t['TName'] as String? ?? 'Teacher $tid';
                                return DropdownMenuItem<int?>(
                                  value: tid,
                                  child: Text(
                                    tname,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: notifier.setEditingSecTeacher,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildExternalLabel('Proctor'),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 40,
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey(state.editingSecProctorId),
                            initialValue: state.editingSecProctorId,
                            isExpanded: true,
                            isDense: true,
                            menuMaxHeight: 400,
                            dropdownColor: AppColors.surfaceRaised,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  'Not assigned',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              ...state.allTeachers.map((t) {
                                final tid = (t['TeacherID'] as num).toInt();
                                final tname =
                                    t['TName'] as String? ?? 'Teacher $tid';
                                final tcat = t['TCat'] as String? ?? 'Staff';
                                return DropdownMenuItem<int?>(
                                  value: tid,
                                  child: Text(
                                    '$tname ($tcat)',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: notifier.setEditingSecProctor,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildExternalLabel('Room No'),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _roomCtrl,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 101, Main Hall, Science Lab',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                            ),
                            onChanged: notifier.setEditingRoomNo,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildExternalLabel('Section Remarks'),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _secRemarksCtrl,
                          maxLines: null,
                          minLines: 2,
                          maxLength: 255,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Optional section notes...',
                            isDense: true,
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                color: AppColors.borderDefault,
                              ),
                            ),
                          ),
                          onChanged: notifier.setEditingSecRemarks,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderSubtle),
                const SizedBox(height: 12),

                // Dialog Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _handleSaveSection(dialogCtx),
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: Text(
                        state.editingSectionId == null
                            ? 'Save Section (Ctrl+S)'
                            : 'Update Section (Ctrl+S)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // REUSABLE HELPER WIDGETS
  // ===========================================================================

  Widget _buildExternalLabel(String text) {
    return Text(
      text,
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message, ClassSectionNotifier notifier) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.statusErrorText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            onPressed: notifier.clearError,
          ),
        ],
      ),
    );
  }
}
