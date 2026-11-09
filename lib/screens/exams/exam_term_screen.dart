import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/clock_provider.dart';
import '../../core/providers/exam_term_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/exam_session_row.dart';
import '../../models/exam_term_row.dart';
import '../../widgets/mobile/mobile_kpi_card.dart';
import '../../widgets/mobile/mobile_status_pill.dart';

/// Screen 16 - ExamTermScreen at `/exams/terms`.
/// Implements §S20 (frmExams at 0x00424dcc, ObjID: 10).
class ExamTermScreen extends ConsumerStatefulWidget {
  const ExamTermScreen({super.key});

  @override
  ConsumerState<ExamTermScreen> createState() => _ExamTermScreenState();
}

class _ExamTermScreenState extends ConsumerState<ExamTermScreen> {
  final TextEditingController _termSearchController = TextEditingController();
  final TextEditingController _sessionIdSearchController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  final DateFormat _displayDateFormat = DateFormat('dd-MMM-yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(examTermProvider.notifier).loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _termSearchController.dispose();
    _sessionIdSearchController.dispose();
    _locationController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _syncTextControllers(ExamTermState state) {
    if (_locationController.text != state.formLocation) {
      _locationController.text = state.formLocation;
    }
    if (_detailController.text != state.formDetail) {
      _detailController.text = state.formDetail;
    }
  }

  Future<void> _handleSaveSession() async {
    final (ok, msg) = await ref.read(examTermProvider.notifier).saveSession();
    if (!mounted) return;
    if (ok) {
      ref.invalidate(availableSessionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.statusSuccessText,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleSessionSearch() async {
    final query = _sessionIdSearchController.text.trim();
    if (query.isEmpty) return;
    final id = int.tryParse(query);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid numeric session ID'),
          backgroundColor: AppColors.statusErrorText,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final (ok, msg) = await ref
        .read(examTermProvider.notifier)
        .lookupSessionById(id);
    if (!mounted) return;
    if (!ok && msg.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.statusErrorText,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleTermSelection(int termId) async {
    final state = ref.read(examTermProvider);
    if (state.isFormDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard Unsaved Changes?'),
          content: const Text(
            'You have unsaved changes to the active exam session. Do you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: AppColors.textOnPrimary,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }

    await ref.read(examTermProvider.notifier).selectTerm(termId);
  }

  void _showAddEditTermDialog({ExamTermRow? term}) {
    final nameCtrl = TextEditingController(text: term?.termName ?? '');
    final remarksCtrl = TextEditingController(text: term?.termRemarks ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(term == null ? 'Add Exam Term' : 'Edit Exam Term'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('add_term_name_field'),
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Term Name *',
                  hintText: 'e.g. 1st Term, Final Term',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'Optional descriptive notes',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const ValueKey('save_term_dialog_btn'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final remarks = remarksCtrl.text.trim();
              Navigator.of(ctx).pop();

              if (term == null) {
                final (ok, msg) = await ref
                    .read(examTermProvider.notifier)
                    .addTerm(name, remarks);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: ok
                        ? AppColors.statusSuccessText
                        : AppColors.statusErrorText,
                  ),
                );
              } else {
                final (ok, msg) = await ref
                    .read(examTermProvider.notifier)
                    .updateTerm(term.exTermId, name, remarks);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: ok
                        ? AppColors.statusSuccessText
                        : AppColors.statusErrorText,
                  ),
                );
              }
            },
            child: Text(term == null ? 'Save Term' : 'Update Term'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteTerm(ExamTermRow term) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete Exam Term'),
        content: Text('Are you sure you want to delete "${term.termName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusErrorText,
              foregroundColor: AppColors.textOnPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final (ok, msg) = await ref
          .read(examTermProvider.notifier)
          .deleteTerm(term.exTermId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok
              ? AppColors.statusSuccessText
              : AppColors.statusErrorText,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examTermProvider);
    final notifier = ref.read(examTermProvider.notifier);

    _syncTextControllers(state);

    // Toast listener
    ref.listen<ExamTermState>(examTermProvider, (prev, next) {
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
    });

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileScaffold(context, state, notifier);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleSaveSession,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _handleSaveSession,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            notifier.newSession,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            notifier.newSession,
        const SingleActivator(
          LogicalKeyboardKey.keyT,
          control: true,
          shift: true,
        ): () =>
            _showAddEditTermDialog(),
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Page Header (44px)
              _buildPageHeader(context),

              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // 2. Main Two-Pane Split (Expanded)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Pane (Fixed 350px): Exam Terms Catalog
                    SizedBox(
                      width: 350,
                      child: _buildLeftPane(context, state, notifier),
                    ),

                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.borderDefault,
                    ),

                    // Right Pane (Expanded): Exam Sessions & Schedule
                    Expanded(child: _buildRightPane(context, state, notifier)),
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
  // 1. TOP PAGE HEADER (44px)
  // ===========================================================================
  Widget _buildPageHeader(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surfaceRaised,
      child: Row(
        children: [
          Text(
            'Exam Terms and Sessions',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Define examination terms and schedule exam sessions for each academic year.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => context.go('/exams/marks'),
            icon: const Icon(Icons.grade_outlined, size: 14),
            label: const Text('Marks Entry', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => context.go('/exams/subjects'),
            icon: const Icon(Icons.menu_book_outlined, size: 14),
            label: const Text('Exam Subjects', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. LEFT PANE: EXAM TERMS CATALOG (350px)
  // ===========================================================================
  Widget _buildLeftPane(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    final search = _termSearchController.text.trim().toLowerCase();
    final filteredTerms = state.terms.where((t) {
      if (search.isEmpty) return true;
      return t.termName.toLowerCase().contains(search) ||
          t.exTermId.toString().contains(search);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Strip (40px)
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          color: AppColors.surfaceSubtle,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'EXAM TERMS CATALOG',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Text(
                  '${state.terms.length} Defined',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Search Bar (36px)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          color: AppColors.surfaceRaised,
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: _termSearchController,
              onChanged: (_) => setState(() {}),
              style: AppTypography.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 16),
                hintText: 'Search terms by name',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
            ),
          ),
        ),

        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Term List (Expanded)
        Expanded(
          child: filteredTerms.isEmpty
              ? _buildEmptyTermsState()
              : ListView.separated(
                  itemCount: filteredTerms.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.borderSubtle,
                  ),
                  itemBuilder: (ctx, index) {
                    final term = filteredTerms[index];
                    final isSelected = term.exTermId == state.selectedTermId;

                    return InkWell(
                      key: ValueKey('term_item_${term.exTermId}'),
                      onTap: () => _handleTermSelection(term.exTermId),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.surfaceSubtle
                              : AppColors.surfaceRaised,
                          border: Border(
                            left: BorderSide(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : Colors.transparent,
                              width: 3.5,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            // ID Mono Badge
                            SizedBox(
                              width: 44,
                              child: Text(
                                '#${term.exTermId}',
                                style: AppTypography.monospace.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Name
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    term.termName,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.brandPrimary
                                          : AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (term.sessionCount > 0)
                                    Text(
                                      '${term.sessionCount} session(s)',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Action Buttons
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Edit Term',
                              splashRadius: 16,
                              onPressed: () =>
                                  _showAddEditTermDialog(term: term),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.statusErrorText,
                              ),
                              tooltip: 'Delete Term',
                              splashRadius: 16,
                              onPressed: () => _handleDeleteTerm(term),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Left Pane Footer (44px)
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          color: AppColors.surfaceSubtle,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddEditTermDialog(),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Term', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coming in Phase E'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.print_outlined, size: 14),
                  label: const Text(
                    'Print Catalog',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTermsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 32,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No exam terms defined',
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your first term to begin scheduling examinations.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: () => _showAddEditTermDialog(),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Term', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32)),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. RIGHT PANE: EXAM SESSIONS & SCHEDULE (Main Canvas)
  // ===========================================================================
  Widget _buildRightPane(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    if (state.selectedTerm == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_note_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No term selected',
              style: AppTypography.h3.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a term from the catalog to schedule an examination session.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final termName = state.selectedTerm!.termName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Right Header Strip (40px)
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: AppColors.surfaceSubtle,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.isEditMode
                      ? 'EDITING EXAMINATION SESSION: #${state.editingSession!.examInfoId} ($termName)'
                      : 'NEW EXAMINATION SESSION ($termName)',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Session ID Lookup (txtExInfoIDGo + cmdGoExID)
              SizedBox(
                width: 84,
                height: 32,
                child: TextField(
                  controller: _sessionIdSearchController,
                  style: AppTypography.monospace.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'ID #',
                    hintStyle: AppTypography.monospace.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(
                        color: AppColors.borderDefault,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(
                        color: AppColors.borderDefault,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _handleSessionSearch(),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton(
                onPressed: _handleSessionSearch,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Go', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: notifier.newSession,
                icon: const Icon(Icons.add, size: 13),
                label: const Text(
                  'New Exam Session',
                  style: TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming in Phase E'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.print_outlined, size: 13),
                label: const Text(
                  'Print Schedule',
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

        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Supervisor Warning Banner (when non-Teacher assigned in edit mode, 32px)
        if (state.editingSession != null && state.nonTeacherSupervisor != null)
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: AppColors.statusWarningBg,
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.statusWarningText,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${state.nonTeacherSupervisor!['TName']} is registered as ${state.nonTeacherSupervisor!['TCat']}, not Teacher. The current assignment is kept until you choose a different supervisor.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusWarningText,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Error Banner (when errorMessage exists, 32px)
        if (state.errorMessage != null)
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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

        // Compact Form Area (~192px total)
        _buildCompactForm(context, state, notifier),

        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // History Table Header Strip (32px)
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: AppColors.surfaceSubtle,
          child: Row(
            children: [
              Text(
                'SESSION HISTORY: $termName (${state.currentSessions.length})',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'Click a row to edit',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Sessions History Table (Expanded flex)
        Expanded(child: _buildHistoryTable(context, state, notifier)),
      ],
    );
  }

  // ===========================================================================
  // 4. COMPACT FORM (~246px)
  // ===========================================================================
  Widget _buildCompactForm(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    // Build list of supervisor dropdown items
    final supervisorItems = <DropdownMenuItem<int>>[];

    // If supervisor is non-Teacher (e.g. Nasir Ali Principal), prepend him ONLY in edit mode
    if (state.editingSession != null && state.nonTeacherSupervisor != null) {
      final supId = (state.nonTeacherSupervisor!['TeacherID'] as num).toInt();
      final supName = state.nonTeacherSupervisor!['TName'] as String;
      final supCat = state.nonTeacherSupervisor!['TCat'] as String;
      supervisorItems.add(
        DropdownMenuItem<int>(
          value: supId,
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: AppColors.statusWarningText,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$supName ($supCat) - current assignment',
                  style: AppTypography.body.copyWith(
                    color: AppColors.statusWarningText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final t in state.availableTeachers) {
      final tid = (t['TeacherID'] as num).toInt();
      final tname = t['TName'] as String? ?? 'Teacher $tid';
      supervisorItems.add(
        DropdownMenuItem<int>(
          value: tid,
          child: Text(
            tname,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Container(
      color: AppColors.surfaceRaised,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Term | Session Year | Supervisor
          Row(
            children: [
              // Term Dropdown
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Exam Term *',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(
                          'term_${state.editingSession?.examInfoId}_${state.formExTermId}',
                        ),
                        initialValue:
                            state.terms.any(
                              (t) => t.exTermId == state.formExTermId,
                            )
                            ? state.formExTermId
                            : null,
                        isDense: true,
                        isExpanded: true,
                        menuMaxHeight: 400,
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
                        items: state.terms.map((t) {
                          return DropdownMenuItem<int>(
                            value: t.exTermId,
                            child: Text(
                              t.termName,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => notifier.setFormExTermId(val),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Session Year Dropdown
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Session Year *',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'yr_${state.editingSession?.examInfoId}_${state.formSessionYr}',
                        ),
                        initialValue:
                            state.sessionYears.contains(state.formSessionYr)
                            ? state.formSessionYr
                            : null,
                        isDense: true,
                        isExpanded: true,
                        menuMaxHeight: 400,
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
                        items: state.sessionYears.map((yr) {
                          return DropdownMenuItem<String>(
                            value: yr,
                            child: Text(
                              yr,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => notifier.setFormSessionYr(val),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Exam Supervisor Dropdown
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Exam Supervisor *',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(
                          'sup_${state.editingSession?.examInfoId}_${state.formExamSupervisorId}',
                        ),
                        initialValue:
                            supervisorItems.any(
                              (i) => i.value == state.formExamSupervisorId,
                            )
                            ? state.formExamSupervisorId
                            : null,
                        isDense: true,
                        isExpanded: true,
                        menuMaxHeight: 400,
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
                        items: supervisorItems,
                        onChanged: (val) =>
                            notifier.setFormExamSupervisorId(val),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Row 2: Start Date | End Date | Result Date | Venue
          Row(
            children: [
              // Start Date Picker
              Expanded(
                flex: 2,
                child: _buildDatePickerField(
                  label: 'Start Date *',
                  date: state.formStartDate,
                  onSelect: (d) => notifier.setFormStartDate(d),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // End Date Picker
              Expanded(
                flex: 2,
                child: _buildDatePickerField(
                  label: 'End Date *',
                  date: state.formEndDate,
                  onSelect: (d) => notifier.setFormEndDate(d),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Result Date Picker
              Expanded(
                flex: 2,
                child: _buildDatePickerField(
                  label: 'Result Date *',
                  date: state.formResultDate,
                  onSelect: (d) => notifier.setFormResultDate(d),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Venue Text Field
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Venue / Location',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _locationController,
                        onChanged: (val) => notifier.setFormLocation(val),
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceRaised,
                          hintText: 'e.g. Main Hall',
                          hintStyle: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
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
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Row 3: Detail / Instructions
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Session Detail / Instructions',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _detailController,
                  onChanged: (val) => notifier.setFormDetail(val),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceRaised,
                    hintText: 'Administrative guidelines, schedule notes...',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Row 4: Primary Form Actions
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: notifier.newSession,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Clear Form', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
              ),
              const Spacer(),
              if (state.isEditMode && state.editingSession != null) ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      _handleDeleteSession(state.editingSession!, notifier),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: AppColors.statusErrorText,
                  ),
                  label: const Text(
                    'Delete Session',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.statusErrorText,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusErrorText,
                    side: const BorderSide(color: AppColors.statusErrorBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              ElevatedButton.icon(
                onPressed: _handleSaveSession,
                icon: const Icon(Icons.save, size: 14),
                label: Text(
                  state.isEditMode
                      ? 'Update Exam Session (Ctrl+S)'
                      : 'Save Exam Session (Ctrl+S)',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteSession(
    ExamSessionRow session,
    ExamTermNotifier notifier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Delete session #${session.examInfoId}? This cannot be undone.',
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
            child: const Text('Delete Session'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = await DatabaseService.instance.database;
        await db.delete(
          'ExamInfo',
          where: 'ExamInfoID = ?',
          whereArgs: [session.examInfoId],
        );
        await notifier.loadInitialData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session deleted.'),
            backgroundColor: AppColors.statusSuccessText,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting session: $e'),
            backgroundColor: AppColors.statusErrorText,
          ),
        );
      }
    }
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: InkWell(
            onTap: () async {
              final initial = date ?? ref.read(clockProvider)();
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2040),
              );
              if (picked != null) {
                onSelect(picked);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceRaised,
                isDense: true,
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
                suffixIcon: const Icon(Icons.calendar_today, size: 14),
              ),
              child: Text(
                date != null ? _displayDateFormat.format(date) : 'Select date',
                style: AppTypography.body.copyWith(
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. HISTORY TABLE (Sticky Header, Rows 36px)
  // ===========================================================================
  Widget _buildHistoryTable(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    if (state.currentSessions.isEmpty) {
      return Center(
        child: Text(
          'No sessions have been scheduled for this term yet.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      children: [
        // Sticky Header (32px)
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: AppColors.surfaceSubtle,
          child: Row(
            children: [
              _buildHeaderCell('ID', 50),
              _buildHeaderCell('Session Year', 100),
              _buildHeaderCell('Start Date', 100),
              _buildHeaderCell('End Date', 100),
              _buildHeaderCell('Result Date', 100),
              _buildHeaderCell('Supervisor', 150),
              _buildHeaderCell('Venue', 120),
              Expanded(child: _buildHeaderCell('Detail', 0)),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Rows
        Expanded(
          child: ListView.builder(
            itemCount: state.currentSessions.length,
            itemBuilder: (ctx, index) {
              final session = state.currentSessions[index];
              final isCurrentEdit =
                  state.editingSession?.examInfoId == session.examInfoId;
              final isEven = index.isEven;

              String formatD(String raw) {
                final d = DateTime.tryParse(raw);
                return d != null ? _displayDateFormat.format(d) : raw;
              }

              return InkWell(
                onTap: () => notifier.selectSessionForEdit(session.examInfoId),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  color: isCurrentEdit
                      ? AppColors.brandPrimary.withValues(alpha: 0.08)
                      : (isEven
                            ? AppColors.surfaceRaised
                            : AppColors.surfaceSubtle),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '#${session.examInfoId}',
                          style: AppTypography.monospace.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCurrentEdit
                                ? AppColors.brandPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          session.sessionYr,
                          style: AppTypography.bodySmall.copyWith(fontSize: 11),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          formatD(session.startDate),
                          style: AppTypography.bodySmall.copyWith(fontSize: 11),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          formatD(session.endDate),
                          style: AppTypography.bodySmall.copyWith(fontSize: 11),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          formatD(session.resultDate),
                          style: AppTypography.bodySmall.copyWith(fontSize: 11),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          session.supervisorName,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: isCurrentEdit
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          session.location.isNotEmpty ? session.location : '—',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: session.location.isNotEmpty
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          session.detail.isNotEmpty ? session.detail : '—',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: session.detail.isNotEmpty
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    final w = Text(
      text,
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 10,
        color: AppColors.textSecondary,
      ),
    );
    if (width > 0) {
      return SizedBox(width: width, child: w);
    }
    return w;
  }

  // ==========================================================================
  // G-6a MOBILE BRANCH (< 600px)
  // ==========================================================================
  Widget _buildMobileScaffold(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleSaveSession,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _handleSaveSession,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            notifier.newSession,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            notifier.newSession,
        const SingleActivator(
          LogicalKeyboardKey.keyT,
          control: true,
          shift: true,
        ): () =>
            _showMobileAddEditTermDialog(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                        _buildMobileHeader(context),
                        const SizedBox(height: AppSpacing.sm),
                        // Summary strip (Phase G-9 Shot 2a)
                        _buildMobileSummaryRow(state),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileActionBar(context),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileTermList(context, state, notifier),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileSessionSection(context, state, notifier),
                      ],
                    ),
                  ),
                ),
                // Sticky bottom action bar (Phase G-9 Shot 2a)
                _buildMobileStickyBar(context, state, notifier),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2-up MobileKpiCard summary row.
  Widget _buildMobileSummaryRow(ExamTermState state) {
    return Row(
      children: [
        Expanded(
          child: MobileKpiCard(
            label: 'TOTAL EXAM TERMS',
            value: '${state.terms.length}',
            icon: Icons.calendar_today_outlined,
            accentColor: AppColors.accentExams,
            accentSoftBg: AppColors.accentExamsSoftBg,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: MobileKpiCard(
            label: 'TERM SESSIONS',
            value: '${state.selectedTerm?.sessionCount ?? 0}',
            icon: Icons.event_note_outlined,
            accentColor: AppColors.accentExams,
            accentSoftBg: AppColors.accentExamsSoftBg,
          ),
        ),
      ],
    );
  }

  /// Pinned bottom bar: Clear Form / Delete Session + primary Save button.
  Widget _buildMobileStickyBar(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    final isEditMode = state.isEditMode && state.editingSession != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        MediaQuery.paddingOf(context).bottom + AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: notifier.newSession,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'Clear Form',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              if (isEditMode) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _handleDeleteSession(state.editingSession!, notifier),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.statusErrorText,
                      ),
                      label: const Text(
                        'Delete Session',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.statusErrorText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusErrorText,
                        side: const BorderSide(
                          color: AppColors.statusErrorBorder,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _handleSaveSession,
              icon: const Icon(Icons.save, size: 18),
              label: Text(
                isEditMode
                    ? 'Update Exam Session (Ctrl+S)'
                    : 'Save Exam Session (Ctrl+S)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentExams,
                foregroundColor: AppColors.textOnPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Exam Terms and Sessions',
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          'Define examination terms and schedule exam sessions for each academic year.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMobileActionBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () => _showMobileAddEditTermDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Term'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentExams,
              foregroundColor: AppColors.textOnPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming in Phase E'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print Catalog'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/exams/marks'),
            icon: const Icon(Icons.grade_outlined, size: 16),
            label: const Text('Marks Entry'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/exams/subjects'),
            icon: const Icon(Icons.menu_book_outlined, size: 16),
            label: const Text('Exam Subjects'),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTermList(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    final search = _termSearchController.text.trim().toLowerCase();
    final filteredTerms = state.terms.where((t) {
      if (search.isEmpty) return true;
      return t.termName.toLowerCase().contains(search) ||
          t.exTermId.toString().contains(search);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'EXAM TERMS CATALOG',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Text(
                  '${state.terms.length} Defined',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _termSearchController,
              onChanged: (_) => setState(() {}),
              style: AppTypography.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 16),
                hintText: 'Search terms by name',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
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
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredTerms.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 32,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'No exam terms defined',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your first term to begin scheduling examinations.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredTerms.length,
              itemBuilder: (ctx, index) {
                return _buildMobileTermCard(filteredTerms[index], state);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMobileTermCard(ExamTermRow term, ExamTermState state) {
    final isSelected = term.exTermId == state.selectedTermId;
    // Phase G-9 Shot 2a: safe left-strip accent card (no non-uniform Border).
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isSelected ? AppColors.accentExams : AppColors.borderDefault,
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _handleTermSelection(term.exTermId),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3.5, color: AppColors.accentExams),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${term.exTermId}',
                            style: AppTypography.monospace.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.accentExams
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              term.termName,
                              style: AppTypography.body.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.accentExams
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (term.sessionCount > 0) ...[
                            const SizedBox(width: AppSpacing.xs),
                            MobileStatusPill(
                              label: '${term.sessionCount} session(s)',
                              variant: MobileStatusVariant.info,
                            ),
                          ],
                        ],
                      ),
                      if (term.termRemarks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          term.termRemarks,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showMobileAddEditTermDialog(term: term),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => _handleMobileDeleteTerm(term),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.statusErrorText,
                                ),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.statusErrorText,
                                  ),
                                ),
                              ),
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
      ),
    );
  }

  Widget _buildMobileSessionSection(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    if (state.selectedTerm == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Icon(
              Icons.event_note_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No term selected',
              style: AppTypography.h3.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Select a term from the catalog to schedule an examination session.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileSessionForm(context, state, notifier),
        const SizedBox(height: AppSpacing.sm),
        _buildMobileSessionHistory(context, state, notifier),
      ],
    );
  }

  Widget _buildMobileSessionForm(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    final termName = state.selectedTerm!.termName;

    final supervisorItems = <DropdownMenuItem<int>>[];
    if (state.editingSession != null && state.nonTeacherSupervisor != null) {
      final supId = (state.nonTeacherSupervisor!['TeacherID'] as num).toInt();
      final supName = state.nonTeacherSupervisor!['TName'] as String;
      final supCat = state.nonTeacherSupervisor!['TCat'] as String;
      supervisorItems.add(
        DropdownMenuItem<int>(
          value: supId,
          child: _mobileDropdownItemText(
            '$supName ($supCat) - current assignment',
          ),
        ),
      );
    }
    for (final t in state.availableTeachers) {
      final tid = (t['TeacherID'] as num).toInt();
      final tname = t['TName'] as String? ?? 'Teacher $tid';
      supervisorItems.add(
        DropdownMenuItem<int>(
          value: tid,
          child: _mobileDropdownItemText(tname),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.isEditMode
                ? 'EDITING EXAMINATION SESSION: #${state.editingSession!.examInfoId} ($termName)'
                : 'NEW EXAMINATION SESSION ($termName)',
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.editingSession != null &&
              state.nonTeacherSupervisor != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.statusWarningBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.statusWarningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.statusWarningText,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${state.nonTeacherSupervisor!['TName']} is registered as ${state.nonTeacherSupervisor!['TCat']}, not Teacher. The current assignment is kept until you choose a different supervisor.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.statusWarningText,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.statusErrorBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.statusErrorBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.statusErrorText,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: notifier.clearErrorMessage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          _buildMobileDropdownRow(
            label: 'Exam Term *',
            child: _buildMobileDropdown<int>(
              value: state.formExTermId,
              items: state.terms.map((t) {
                return DropdownMenuItem<int>(
                  value: t.exTermId,
                  child: _mobileDropdownItemText(t.termName),
                );
              }).toList(),
              onChanged: (val) => notifier.setFormExTermId(val),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobileDropdownRow(
            label: 'Session Year *',
            child: _buildMobileDropdown<String>(
              value: state.formSessionYr,
              items: state.sessionYears.map((yr) {
                return DropdownMenuItem<String>(
                  value: yr,
                  child: _mobileDropdownItemText(yr),
                );
              }).toList(),
              onChanged: (val) => notifier.setFormSessionYr(val),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobileDropdownRow(
            label: 'Exam Supervisor *',
            child: _buildMobileDropdown<int>(
              value: state.formExamSupervisorId,
              items: supervisorItems,
              onChanged: (val) => notifier.setFormExamSupervisorId(val),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildDatePickerField(
            label: 'Start Date *',
            date: state.formStartDate,
            onSelect: (d) => notifier.setFormStartDate(d),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildDatePickerField(
            label: 'End Date *',
            date: state.formEndDate,
            onSelect: (d) => notifier.setFormEndDate(d),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildDatePickerField(
            label: 'Result Date *',
            date: state.formResultDate,
            onSelect: (d) => notifier.setFormResultDate(d),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobileFieldLabel('Venue / Location'),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _locationController,
              onChanged: (val) => notifier.setFormLocation(val),
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceRaised,
                hintText: 'e.g. Main Hall',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
                isDense: true,
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
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobileFieldLabel('Session Detail / Instructions'),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _detailController,
              onChanged: (val) => notifier.setFormDetail(val),
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceRaised,
                hintText: 'Administrative guidelines, schedule notes...',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
                isDense: true,
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
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobileFieldLabel('Session ID Lookup'),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _sessionIdSearchController,
                    style: AppTypography.monospace.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'ID #',
                      hintStyle: AppTypography.monospace.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
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
                    onSubmitted: (_) => _handleSessionSearch(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                height: 44,
                width: 72,
                child: OutlinedButton(
                  onPressed: _handleSessionSearch,
                  child: const Text('Go', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSessionHistory(
    BuildContext context,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    final termName = state.selectedTerm!.termName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SESSION HISTORY: $termName (${state.currentSessions.length})',
          style: AppTypography.label.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (state.currentSessions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'No sessions have been scheduled for this term yet.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.currentSessions.length,
            itemBuilder: (ctx, index) {
              return _buildMobileSessionCard(
                state.currentSessions[index],
                state,
                notifier,
              );
            },
          ),
      ],
    );
  }

  Widget _buildMobileSessionCard(
    ExamSessionRow session,
    ExamTermState state,
    ExamTermNotifier notifier,
  ) {
    final isCurrentEdit =
        state.editingSession?.examInfoId == session.examInfoId;

    String formatD(String raw) {
      final d = DateTime.tryParse(raw);
      return d != null ? _displayDateFormat.format(d) : raw;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isCurrentEdit
              ? AppColors.accentExams
              : AppColors.borderDefault,
          width: isCurrentEdit ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => notifier.selectSessionForEdit(session.examInfoId),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3.5, color: AppColors.accentExams),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${session.examInfoId}',
                            style: AppTypography.monospace.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCurrentEdit
                                  ? AppColors.accentExams
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              session.sessionYr,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          if (isCurrentEdit)
                            const MobileStatusPill(
                              label: 'Editing',
                              variant: MobileStatusVariant.info,
                            )
                          else
                            const MobileStatusPill(
                              label: 'Scheduled',
                              variant: MobileStatusVariant.neutral,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatD(session.startDate)} \u2192 ${formatD(session.endDate)}',
                        style: AppTypography.monospace.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Result: ${formatD(session.resultDate)}',
                        style: AppTypography.monospace.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Supervisor: ${session.supervisorName}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (session.location.isNotEmpty)
                        Text(
                          'Venue: ${session.location}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (session.detail.isNotEmpty)
                        Text(
                          session.detail,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildMobileDropdownRow({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: DropdownButtonHideUnderline(child: child),
        ),
      ],
    );
  }

  Widget _mobileDropdownItemText(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body.copyWith(
        color: AppColors.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildMobileDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    final effectiveValue = items.any((i) => i.value == value) ? value : null;
    final itemStyle = AppTypography.body.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );
    return DropdownButton<T>(
      value: effectiveValue,
      isExpanded: true,
      isDense: true,
      menuMaxHeight: 400.0,
      dropdownColor: AppColors.surfaceRaised,
      iconEnabledColor: AppColors.textPrimary,
      iconDisabledColor: AppColors.textMuted,
      style: itemStyle,
      hint: hint == null
          ? null
          : Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
      selectedItemBuilder: (context) => items
          .map(
            (item) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                (item.child as Text).data ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: itemStyle,
              ),
            ),
          )
          .toList(),
      items: items,
      onChanged: onChanged,
    );
  }

  Future<void> _showMobileAddEditTermDialog({ExamTermRow? term}) async {
    final nameCtrl = TextEditingController(text: term?.termName ?? '');
    final remarksCtrl = TextEditingController(text: term?.termRemarks ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  term == null ? 'Add Exam Term' : 'Edit Exam Term',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('add_term_name_field'),
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Term Name *',
                    hintText: 'e.g. 1st Term, Final Term',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Optional descriptive notes',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    key: const ValueKey('save_term_dialog_btn'),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final remarks = remarksCtrl.text.trim();
                      Navigator.of(ctx).pop();

                      if (term == null) {
                        final (ok, msg) = await ref
                            .read(examTermProvider.notifier)
                            .addTerm(name, remarks);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: ok
                                ? AppColors.statusSuccessText
                                : AppColors.statusErrorText,
                          ),
                        );
                      } else {
                        final (ok, msg) = await ref
                            .read(examTermProvider.notifier)
                            .updateTerm(term.exTermId, name, remarks);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: ok
                                ? AppColors.statusSuccessText
                                : AppColors.statusErrorText,
                          ),
                        );
                      }
                    },
                    child: Text(term == null ? 'Save Term' : 'Update Term'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMobileDeleteTerm(ExamTermRow term) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm Delete Exam Term',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Are you sure you want to delete "${term.termName}"?',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusErrorText,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      final (ok, msg) = await ref
          .read(examTermProvider.notifier)
          .deleteTerm(term.exTermId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok
              ? AppColors.statusSuccessText
              : AppColors.statusErrorText,
        ),
      );
    }
  }
}
