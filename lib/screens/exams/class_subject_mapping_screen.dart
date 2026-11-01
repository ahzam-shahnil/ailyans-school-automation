import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/class_subject_mapping_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../models/subject_mapping_row.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _ResetIntent extends Intent {
  const _ResetIntent();
}

class _PrintIntent extends Intent {
  const _PrintIntent();
}

/// Screen 17 - ClassSubjectMappingScreen at `/exams/subjects`.
/// Implements §S21 (frmExamClasSubj at 0x004136c0, ObjID: 23).
class ClassSubjectMappingScreen extends ConsumerStatefulWidget {
  const ClassSubjectMappingScreen({super.key});

  @override
  ConsumerState<ClassSubjectMappingScreen> createState() =>
      _ClassSubjectMappingScreenState();
}

class _ClassSubjectMappingScreenState
    extends ConsumerState<ClassSubjectMappingScreen> {
  final TextEditingController _theoryMarksController = TextEditingController();
  final TextEditingController _practicalMarksController = TextEditingController(
    text: '0',
  );
  int? _fromTeacherId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(classSubjectMappingProvider.notifier).loadInitialData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final uri = GoRouterState.of(context).uri;
      final fromTeacherId = uri.queryParameters['fromTeacherId'];
      if (fromTeacherId != null && fromTeacherId.isNotEmpty) {
        final parsed = int.tryParse(fromTeacherId);
        if (_fromTeacherId != parsed) {
          setState(() => _fromTeacherId = parsed);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _theoryMarksController.dispose();
    _practicalMarksController.dispose();
    super.dispose();
  }

  void _syncTextControllers(ClassSubjectMappingState state) {
    if (_theoryMarksController.text != state.formTheoryMarks) {
      _theoryMarksController.text = state.formTheoryMarks;
    }
    if (_practicalMarksController.text != state.formPracticalMarks) {
      _practicalMarksController.text = state.formPracticalMarks;
    }
  }

  Future<void> _handleSaveMapping() async {
    final (ok, msg) = await ref
        .read(classSubjectMappingProvider.notifier)
        .saveMapping();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.statusSuccessText,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleDeleteMapping(
    SubjectMappingRow mapping,
    ClassSubjectMappingNotifier notifier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Subject Mapping'),
        content: const Text(' Are You Sure Want to REMOVE ? '),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final (ok, msg) = await notifier.deleteMapping(mapping.subjClsId);
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

  void _handlePrintSyllabus() {
    final meta = ref.read(shellMetadataProvider).valueOrNull;
    final state = ref.read(classSubjectMappingProvider);

    final subjects = state.mappings
        .map(
          (row) => <String, dynamic>{
            'subject': row.subjName,
            'subjName': row.subjName,
            'subjectName': row.subjName,
            'teacher': row.teacherName,
            'teacherName': row.teacherName,
            'totalMarks': row.totalMarks,
            'practicalMarks': row.totalPracticalMarks,
          },
        )
        .toList();

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subjects mapped for this class to print'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.classSyllabus,
        titleOverride: 'Class Syllabus',
        extraParams: {
          'className': state.selectedClassName,
          'sessionYear': meta?.sessionYear ?? '2026-27',
          'subjects': subjects,
          'branchName': meta?.branchName ?? "Ailyans's Higher Secondary School",
          'branchAddress': meta?.branchAddress ?? 'Muslim Bazar Mianwali',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(classSubjectMappingProvider);
    final notifier = ref.read(classSubjectMappingProvider.notifier);

    _syncTextControllers(state);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true): _ResetIntent(),
        SingleActivator(LogicalKeyboardKey.keyP, control: true): _PrintIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) => _handleSaveMapping(),
          ),
          _ResetIntent: CallbackAction<_ResetIntent>(
            onInvoke: (_) => notifier.resetForm(),
          ),
          _PrintIntent: CallbackAction<_PrintIntent>(
            onInvoke: (_) {
              _handlePrintSyllabus();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Page Header (~44px)
                _buildPageHeader(context),
                const SizedBox(height: AppSpacing.sm),

                // 2. Class Selector + Form Card (~135px)
                _buildFormCard(context, state, notifier),
                const SizedBox(height: AppSpacing.xs),

                // 3. Supervisor Warning Banner (when non-Teacher assigned in edit mode, 32px)
                if (state.isEditMode && state.nonTeacherCurrent != null) ...[
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
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
                            '${state.nonTeacherCurrent!['TName']} is registered as ${state.nonTeacherCurrent!['TCat']}, not Teacher. Change to a certified Teacher to update this mapping, or leave as-is.',
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
                  const SizedBox(height: AppSpacing.xs),
                ],

                // Error Banner (when errorMessage exists, 32px)
                if (state.errorMessage != null) ...[
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
                  const SizedBox(height: AppSpacing.xs),
                ],

                // 4. Class Syllabus Data Grid (Expanded)
                Expanded(child: _buildSyllabusGrid(context, state, notifier)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. PAGE HEADER (~44px)
  // ===========================================================================
  Widget _buildPageHeader(BuildContext context) {
    return Row(
      children: [
        if (_fromTeacherId != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: () => context.go('/staff/teachers/$_fromTeacherId'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Teacher Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                side: const BorderSide(color: AppColors.borderDefault),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Class Subject Mapping',
                style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Configure which subjects are taught in each class, with teacher assignment and marks allocation.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.go('/exams/marks'),
          icon: const Icon(Icons.assignment_outlined, size: 14),
          label: const Text('Marks Entry', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 32),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.go('/exams/terms'),
          icon: const Icon(Icons.calendar_month_outlined, size: 14),
          label: const Text('Exam Terms', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 32),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. CLASS SELECTOR + FORM CARD (~135px)
  // ===========================================================================
  Widget _buildFormCard(
    BuildContext context,
    ClassSubjectMappingState state,
    ClassSubjectMappingNotifier notifier,
  ) {
    // Build list of teacher dropdown items
    final teacherItems = <DropdownMenuItem<int>>[];

    // If editing a row whose teacher is non-Teacher (e.g. Nasir Ali Principal), prepend
    if (state.isEditMode && state.nonTeacherCurrent != null) {
      final tid = (state.nonTeacherCurrent!['TeacherID'] as num).toInt();
      final tname = state.nonTeacherCurrent!['TName'] as String;
      final tcat = state.nonTeacherCurrent!['TCat'] as String;
      teacherItems.add(
        DropdownMenuItem<int>(
          value: tid,
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
                  '$tname ($tcat) - current assignment',
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
      teacherItems.add(
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Strip (40px): Select Class + Print Syllabus
          Row(
            children: [
              Text(
                'Select Academic Class:',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 260,
                height: 38,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('class_select_${state.selectedClassId}'),
                  initialValue:
                      state.classes.any(
                        (c) =>
                            (c['ClassID'] as num).toInt() ==
                            state.selectedClassId,
                      )
                      ? state.selectedClassId
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
                    fillColor: AppColors.surface,
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
                  items: state.classes.map((c) {
                    final cid = (c['ClassID'] as num).toInt();
                    final cname = c['CName'] as String? ?? 'Class $cid';
                    return DropdownMenuItem<int>(
                      value: cid,
                      child: Text(
                        cname,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setClassId(val);
                  },
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _handlePrintSyllabus,
                icon: const Icon(Icons.print_outlined, size: 14),
                label: const Text(
                  'Print Class Syllabus',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ],
          ),

          const Divider(
            height: 20,
            thickness: 1,
            color: AppColors.borderSubtle,
          ),

          // Bottom Strip (Row with CrossAxisAlignment.end - labels above inputs)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. Subject Dropdown (flex: 3)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Subject *',
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
                          'subj_${state.editingMapping?.subjClsId}_${state.formSubjId}',
                        ),
                        initialValue:
                            state.subjects.any(
                              (s) =>
                                  (s['SubjID'] as num).toInt() ==
                                  state.formSubjId,
                            )
                            ? state.formSubjId
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
                        items: state.subjects.map((s) {
                          final sid = (s['SubjID'] as num).toInt();
                          final sname =
                              s['SubjName'] as String? ?? 'Subject $sid';
                          return DropdownMenuItem<int>(
                            value: sid,
                            child: Text(
                              sname,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: notifier.setFormSubjId,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 2. Assigned Teacher Dropdown (flex: 3)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Assigned Teacher *',
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
                          'teacher_${state.editingMapping?.subjClsId}_${state.formTeacherId}',
                        ),
                        initialValue:
                            teacherItems.any(
                              (i) => i.value == state.formTeacherId,
                            )
                            ? state.formTeacherId
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
                        items: teacherItems,
                        onChanged: notifier.setFormTeacherId,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 3. Theory Marks (115px)
              SizedBox(
                width: 115,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Theory Marks *',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _theoryMarksController,
                        onChanged: notifier.setFormTheoryMarks,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.end,
                        style: AppTypography.monospace.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceRaised,
                          hintText: 'e.g. 100',
                          hintStyle: AppTypography.monospace.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          isDense: true,
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
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 4. Practical Marks (115px)
              SizedBox(
                width: 115,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Practical Marks',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _practicalMarksController,
                        onChanged: notifier.setFormPracticalMarks,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.end,
                        style: AppTypography.monospace.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceRaised,
                          hintText: '0',
                          hintStyle: AppTypography.monospace.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          isDense: true,
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
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // 5. Action Buttons (UNCONSTRAINED Row with MainAxisSize.min)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _handleSaveMapping,
                    icon: const Icon(Icons.save, size: 14),
                    label: Text(
                      state.isEditMode
                          ? 'Update Mapping (Ctrl+S)'
                          : 'Save Mapping (Ctrl+S)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 38),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: notifier.resetForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 38),
                    ),
                    child: const Text(
                      'Reset Form',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. CLASS SYLLABUS GRID
  // ===========================================================================
  Widget _buildSyllabusGrid(
    BuildContext context,
    ClassSubjectMappingState state,
    ClassSubjectMappingNotifier notifier,
  ) {
    final titleClassName = state.selectedClassName.toUpperCase();
    final subjectCount = state.mappings.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar (36px, surfaceSubtle)
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg - 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'ASSIGNED SUBJECTS FOR $titleClassName ($subjectCount Subjects Configured)',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusInfoBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Text(
                    'Total Marks: ${state.totalClassMarks}',
                    style: AppTypography.monospace.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
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

          // Sticky Column Headers (34px)
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: AppColors.surface,
            child: Row(
              children: [
                _buildHeaderCell('ID', 60),
                _buildHeaderCell('Subject Name', null, flex: 3),
                _buildHeaderCell('Assigned Teacher', null, flex: 3),
                _buildHeaderCell(
                  'Theory Marks',
                  110,
                  alignment: Alignment.centerRight,
                ),
                _buildHeaderCell(
                  'Practical Marks',
                  110,
                  alignment: Alignment.centerRight,
                ),
                _buildHeaderCell(
                  'Total',
                  100,
                  alignment: Alignment.centerRight,
                ),
                _buildHeaderCell('Actions', 100, alignment: Alignment.center),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderDefault,
          ),

          // Table Rows (Expanded)
          Expanded(
            child: state.mappings.isEmpty
                ? Center(
                    child: Text(
                      'No subjects mapped to ${state.selectedClassName}. Assign subjects above.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.mappings.length,
                    itemBuilder: (ctx, index) {
                      final item = state.mappings[index];
                      final isEditing =
                          state.editingMapping?.subjClsId == item.subjClsId;
                      final isEven = index.isEven;

                      Color rowBg = isEven
                          ? AppColors.surface
                          : AppColors.surfaceRaised;
                      if (isEditing) {
                        rowBg = AppColors.brandPrimary.withValues(alpha: 0.08);
                      }

                      return InkWell(
                        onTap: () =>
                            notifier.selectMappingForEdit(item.subjClsId),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: rowBg,
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.borderSubtle.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              left: isEditing
                                  ? const BorderSide(
                                      color: AppColors.brandPrimary,
                                      width: 3,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            children: [
                              // ID
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '#${item.subjClsId}',
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),

                              // Subject Name
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item.subjName,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Assigned Teacher
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    if (item.hasNonTeacher) ...[
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 13,
                                        color: AppColors.statusWarningText,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        item.hasNonTeacher
                                            ? '${item.teacherName} (${item.teacherCategory})'
                                            : item.teacherName,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: item.hasNonTeacher
                                              ? AppColors.statusWarningText
                                              : AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Theory Marks
                              SizedBox(
                                width: 110,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${item.totalMarks}',
                                    style: AppTypography.monospace.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),

                              // Practical Marks
                              SizedBox(
                                width: 110,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${item.totalPracticalMarks}',
                                    style: AppTypography.monospace.copyWith(
                                      fontSize: 12,
                                      color: item.totalPracticalMarks > 0
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),

                              // Total
                              SizedBox(
                                width: 100,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${item.combinedMarks}',
                                    style: AppTypography.monospace.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),

                              // Actions
                              SizedBox(
                                width: 100,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 15,
                                      ),
                                      tooltip: 'Edit Mapping',
                                      splashRadius: 14,
                                      color: AppColors.brandPrimary,
                                      onPressed: () => notifier
                                          .selectMappingForEdit(item.subjClsId),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 15,
                                      ),
                                      tooltip: 'Remove Mapping',
                                      splashRadius: 14,
                                      color: AppColors.statusErrorText,
                                      onPressed: () =>
                                          _handleDeleteMapping(item, notifier),
                                    ),
                                  ],
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
      ),
    );
  }

  Widget _buildHeaderCell(
    String label,
    double? width, {
    int flex = 1,
    Alignment alignment = Alignment.centerLeft,
  }) {
    final child = Align(
      alignment: alignment,
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex, child: child);
  }
}
