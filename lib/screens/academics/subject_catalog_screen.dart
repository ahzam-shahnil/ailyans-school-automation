import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/book_profile_provider.dart';
import '../../core/providers/class_subject_mapping_provider.dart';
import '../../core/providers/library_books_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/subject_catalog_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Screen 26 - SubjectCatalogScreen at `/academics/subjects`.
/// Rebuild-only administrative catalog workspace for foundational `Subject` table.
class SubjectCatalogScreen extends ConsumerStatefulWidget {
  const SubjectCatalogScreen({super.key});

  @override
  ConsumerState<SubjectCatalogScreen> createState() =>
      _SubjectCatalogScreenState();
}

class _SubjectCatalogScreenState extends ConsumerState<SubjectCatalogScreen> {
  final TextEditingController _subjNameCtrl = TextEditingController();
  final TextEditingController _subjDetailCtrl = TextEditingController();
  final TextEditingController _subjIdDisplayCtrl = TextEditingController();

  final ScrollController _gridScrollController = ScrollController();
  final ScrollController _drawerScrollController = ScrollController();

  int get _userLvl => ref.read(sessionProvider)?.user.userLevel ?? 1;

  @override
  void initState() {
    super.initState();

    _subjNameCtrl.addListener(() {
      final notifier = ref.read(subjectCatalogProvider.notifier);
      notifier.setEditingSubjName(_subjNameCtrl.text);
    });

    _subjDetailCtrl.addListener(() {
      final notifier = ref.read(subjectCatalogProvider.notifier);
      notifier.setEditingSubjDetail(_subjDetailCtrl.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userLevel = ref.read(sessionProvider)?.user.userLevel ?? 1;
      final notifier = ref.read(subjectCatalogProvider.notifier);
      notifier.setReadOnly(userLevel == 3);
      if (ref.read(subjectCatalogProvider).subjects.isEmpty) {
        await notifier.loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _subjNameCtrl.dispose();
    _subjDetailCtrl.dispose();
    _subjIdDisplayCtrl.dispose();
    _gridScrollController.dispose();
    _drawerScrollController.dispose();
    super.dispose();
  }

  void _invalidateSharedProviders() {
    ref.invalidate(classSubjectMappingProvider);
    ref.invalidate(libraryBooksProvider);
    ref.invalidate(bookProfileProvider);
    ref.invalidate(shellMetadataProvider);
  }

  void _syncDrawerControllers() {
    final s = ref.read(subjectCatalogProvider);
    _subjNameCtrl.text = s.editingSubjName;
    _subjDetailCtrl.text = s.editingSubjDetail;
    _subjIdDisplayCtrl.text = s.isAddingNew
        ? 'Auto (next: #${s.nextSubjId})'
        : '#${s.editingSubjectId}';
  }

  Future<void> _handleAddNew() async {
    final notifier = ref.read(subjectCatalogProvider.notifier);
    await notifier.enterAddNewMode(currentUserLvl: _userLvl);
    if (!mounted) return;
    final s = ref.read(subjectCatalogProvider);
    if (s.errorMessage == null) {
      _syncDrawerControllers();
    }
  }

  void _handleEditSubject(int subjId) {
    final notifier = ref.read(subjectCatalogProvider.notifier);
    notifier.enterEditMode(subjId, currentUserLvl: _userLvl);
    final s = ref.read(subjectCatalogProvider);
    if (s.errorMessage == null) {
      _syncDrawerControllers();
    }
  }

  Future<void> _handleCloseDrawer() async {
    final state = ref.read(subjectCatalogProvider);
    if (state.isDrawerDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard Unsaved Changes?'),
          content: const Text('You have unsaved changes. Discard them?'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        ref.read(subjectCatalogProvider.notifier).closeDrawer();
      }
    } else {
      ref.read(subjectCatalogProvider.notifier).closeDrawer();
    }
  }

  Future<void> _handleSaveSubject() async {
    final notifier = ref.read(subjectCatalogProvider.notifier);
    notifier.setEditingSubjName(_subjNameCtrl.text);
    notifier.setEditingSubjDetail(_subjDetailCtrl.text);
    final ok = await notifier.saveSubject(currentUserLvl: _userLvl);
    if (!mounted) return;
    if (ok) {
      _invalidateSharedProviders();
    }
  }

  Future<void> _handleDeleteSubject(int subjId, String subjName) async {
    final notifier = ref.read(subjectCatalogProvider.notifier);

    // 1. Fast-fail FK check BEFORE dialog (UI spec: "If unused: prompts with confirmation modal")
    final deps = await notifier.checkDeleteEligibility(subjId);
    if (!mounted) return;
    if (deps.total > 0) {
      final parts = <String>[];
      if (deps.classMapCount > 0) parts.add('${deps.classMapCount} classes');
      if (deps.examDetCount > 0) parts.add('${deps.examDetCount} exam records');
      if (deps.bookCount > 0) parts.add('${deps.bookCount} library books');
      notifier.setError(
        'Cannot delete subject: Currently mapped to classes, exams, or library books (${parts.join(", ")})',
      );
      return;
    }

    // 2. Confirmation dialog (only if FK check passed)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text(
          'Remove subject "$subjName" from the catalog? This cannot be undone.',
        ),
        actions: [
          OutlinedButton(
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
    if (confirmed != true || !mounted) return;

    // 3. Execute delete
    final ok = await notifier.deleteSubject(subjId, currentUserLvl: _userLvl);
    if (!mounted) return;
    if (ok) {
      _invalidateSharedProviders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subjectCatalogProvider);
    final notifier = ref.read(subjectCatalogProvider.notifier);

    // Listen for toasts
    ref.listen<SubjectCatalogState>(subjectCatalogProvider, (prev, next) {
      if (next.toast != null && next.toast != prev?.toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(subjectCatalogProvider.notifier).clearToast();
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _handleAddNew,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            _handleAddNew,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (ref.read(subjectCatalogProvider).isDrawerOpen) {
            _handleSaveSubject();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (ref.read(subjectCatalogProvider).isDrawerOpen) {
            _handleSaveSubject();
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (ref.read(subjectCatalogProvider).isDrawerOpen) {
            _handleCloseDrawer();
          } else {
            ref.read(subjectCatalogProvider.notifier).clearError();
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
              _buildRegionA(context, state, notifier),
              const SizedBox(height: 12),

              // Region B + Region C: Side-by-Side Main Workspace
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Region B: Master Grid
                    Expanded(child: _buildMasterGrid(context, state, notifier)),
                    if (state.isDrawerOpen) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 380,
                        child: _buildAuthoringDrawer(context, state, notifier),
                      ),
                    ],
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
  // REGION A: Header (52px)
  // ===========================================================================

  Widget _buildRegionA(
    BuildContext context,
    SubjectCatalogState state,
    SubjectCatalogNotifier notifier,
  ) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Classes & Sections',
            onPressed: () => context.go('/academics/classes'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Academic Subject Catalog',
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Total Subjects Configured Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusInfoBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${state.subjectCount} Subjects Configured',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusInfoText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Total Mapped Classes Assigned Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusSuccessBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${state.totalMappedClasses} Classes Assigned',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Export CSV (Stub)
          OutlinedButton.icon(
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export CSV'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV export coming in Phase E'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Add New Subject CTA
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add New Subject (Ctrl+N)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textOnPrimary,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _handleAddNew,
          ),
          const SizedBox(width: 8),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh subjects',
            onPressed: () => notifier.loadInitialData(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REGION B: Master Grid
  // ===========================================================================

  Widget _buildMasterGrid(
    BuildContext context,
    SubjectCatalogState state,
    SubjectCatalogNotifier notifier,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error banner above grid when drawer closed
            if (state.errorMessage != null && !state.isDrawerOpen) ...[
              _buildErrorBanner(state.errorMessage!, notifier),
              const SizedBox(height: 10),
            ],

            // Table Header (36px)
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      '#ID',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Subject Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Description / Curriculum',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Center(
                      child: Text(
                        'Classes',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Center(
                      child: Text(
                        'Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Rows List
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Scrollbar(
                      controller: _gridScrollController,
                      child: ListView.builder(
                        controller: _gridScrollController,
                        itemCount: state.subjects.length,
                        itemExtent: 44,
                        itemBuilder: (context, index) {
                          final row = state.subjects[index];
                          final subjId = (row['SubjID'] as num).toInt();
                          final subjName = (row['SubjName'] as String?) ?? '';
                          final subjDetail = row['SubjDetail'] as String?;
                          final assignedClasses =
                              (row['AssignedClasses'] as num?)?.toInt() ?? 0;

                          final isEditing = state.editingSubjectId == subjId;
                          final rowBg = isEditing
                              ? AppColors.brandPrimary.withValues(alpha: 0.08)
                              : (index.isEven
                                    ? AppColors.surfaceRaised
                                    : AppColors.surface);

                          return Container(
                            decoration: BoxDecoration(
                              color: rowBg,
                              border: const Border(
                                bottom: BorderSide(
                                  color: AppColors.borderSubtle,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                // ID
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '#$subjId',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),

                                // Subject Name
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    subjName,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Description / Detail
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    subjDetail ?? '-',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Classes Badge
                                SizedBox(
                                  width: 100,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.statusInfoBg,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                      ),
                                      child: Text(
                                        '$assignedClasses Cls',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.statusInfoText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Actions
                                SizedBox(
                                  width: 120,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                        ),
                                        tooltip: 'Edit subject',
                                        style: IconButton.styleFrom(
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(32, 32),
                                        ),
                                        onPressed: () =>
                                            _handleEditSubject(subjId),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.link, size: 16),
                                        tooltip: 'Go to curriculum mapping',
                                        style: IconButton.styleFrom(
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(32, 32),
                                        ),
                                        onPressed: () =>
                                            context.go('/exams/subjects'),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                          color: AppColors.statusErrorText,
                                        ),
                                        tooltip: 'Delete subject',
                                        style: IconButton.styleFrom(
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(32, 32),
                                        ),
                                        onPressed: () => _handleDeleteSubject(
                                          subjId,
                                          subjName,
                                        ),
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
            const SizedBox(height: 8),

            // Footer Counter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Showing ${state.subjects.length} of ${state.subjects.length} Subjects',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // REGION C: Authoring Drawer (380px)
  // ===========================================================================

  Widget _buildAuthoringDrawer(
    BuildContext context,
    SubjectCatalogState state,
    SubjectCatalogNotifier notifier,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Scrollbar(
          controller: _drawerScrollController,
          child: SingleChildScrollView(
            controller: _drawerScrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      state.isAddingNew
                          ? 'Add New Subject'
                          : 'Edit Subject #${state.editingSubjectId}',
                      style: AppTypography.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Cancel (Esc)',
                      onPressed: _handleCloseDrawer,
                    ),
                  ],
                ),
                const Divider(color: AppColors.borderSubtle),
                const SizedBox(height: 12),

                // Field 1: Subject ID
                _buildExternalLabel('Subject ID'),
                const SizedBox(height: 4),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _subjIdDisplayCtrl,
                    readOnly: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceSubtle,
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
                const SizedBox(height: 14),

                // Field 2: Subject Name *
                _buildExternalLabel('Subject Name *'),
                const SizedBox(height: 4),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _subjNameCtrl,
                    autofocus: state.isAddingNew,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Physics, Chemistry, Biology',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
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
                const SizedBox(height: 14),

                // Field 3: Description / Curriculum
                _buildExternalLabel('Description / Curriculum'),
                const SizedBox(height: 4),
                TextField(
                  controller: _subjDetailCtrl,
                  maxLines: 4,
                  minLines: 4,
                  maxLength: 255,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Curriculum scope, syllabus notes',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    contentPadding: const EdgeInsets.all(10),
                    filled: true,
                    fillColor: AppColors.surfaceRaised,
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
                const SizedBox(height: 12),

                // Inline Error in Drawer
                if (state.errorMessage != null) ...[
                  _buildErrorBanner(state.errorMessage!, notifier),
                  const SizedBox(height: 12),
                ],

                // Action Bar
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _handleCloseDrawer,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        'Cancel (Esc)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
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
                          : const Icon(Icons.save_outlined, size: 16),
                      label: const Text(
                        'Save Subject (Ctrl+S)',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textOnPrimary,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: state.isSaving ? null : _handleSaveSubject,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Widget _buildExternalLabel(String text) {
    return Text(
      text,
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildErrorBanner(String message, SubjectCatalogNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              size: 16,
              color: AppColors.statusErrorText,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            splashRadius: 16,
            onPressed: notifier.clearError,
          ),
        ],
      ),
    );
  }
}
