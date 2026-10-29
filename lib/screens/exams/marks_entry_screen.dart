import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/marks_entry_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../models/marks_entry_row.dart';

/// Screen 18 - MarksEntryScreen at /exams/marks.
/// Consolidates legacy frmExamMarks (lpObjectInfo VA 0x0042ab68, ObjID: 24).
class MarksEntryScreen extends ConsumerStatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  ConsumerState<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends ConsumerState<MarksEntryScreen> {
  final Map<int, TextEditingController> _theoryControllers = {};
  final Map<int, TextEditingController> _pracControllers = {};
  final Map<int, FocusNode> _theoryFocusNodes = {};
  final Map<int, FocusNode> _pracFocusNodes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(marksEntryProvider.notifier).loadInitialData();

      final metaAsync = ref.read(shellMetadataProvider);
      if (!metaAsync.hasValue) return;
      final meta = metaAsync.valueOrNull;
      if (meta == null) return;
      final current = ref.read(marksEntryProvider).selectedSessionYr;
      if (current != meta.sessionYear) {
        ref.read(marksEntryProvider.notifier).setSessionYr(meta.sessionYear);
      }
    });
  }

  @override
  void dispose() {
    _disposeRowControllers();
    super.dispose();
  }

  void _disposeRowControllers() {
    for (final c in _theoryControllers.values) {
      c.dispose();
    }
    for (final c in _pracControllers.values) {
      c.dispose();
    }
    for (final f in _theoryFocusNodes.values) {
      f.dispose();
    }
    for (final f in _pracFocusNodes.values) {
      f.dispose();
    }
    _theoryControllers.clear();
    _pracControllers.clear();
    _theoryFocusNodes.clear();
    _pracFocusNodes.clear();
  }

  void _syncControllers(List<MarksEntryRow> roster) {
    final currentIds = roster.map((r) => r.stuRegId).toSet();

    // Clean up removed rows
    final removedIds = _theoryControllers.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in removedIds) {
      _theoryControllers.remove(id)?.dispose();
      _pracControllers.remove(id)?.dispose();
      _theoryFocusNodes.remove(id)?.dispose();
      _pracFocusNodes.remove(id)?.dispose();
    }

    // Create or update existing
    for (final row in roster) {
      final id = row.stuRegId;

      if (!_theoryControllers.containsKey(id)) {
        final initialText = row.theoryObtained != null
            ? (row.theoryObtained! == row.theoryObtained!.roundToDouble()
                  ? row.theoryObtained!.toInt().toString()
                  : row.theoryObtained!.toString())
            : '';
        _theoryControllers[id] = TextEditingController(text: initialText);
        _theoryFocusNodes[id] = FocusNode();
      } else {
        final fNode = _theoryFocusNodes[id];
        if (fNode == null || !fNode.hasFocus) {
          final targetText = row.theoryObtained != null
              ? (row.theoryObtained! == row.theoryObtained!.roundToDouble()
                    ? row.theoryObtained!.toInt().toString()
                    : row.theoryObtained!.toString())
              : '';
          if (_theoryControllers[id]!.text != targetText) {
            _theoryControllers[id]!.text = targetText;
          }
        }
      }

      if (!_pracControllers.containsKey(id)) {
        final initialText = row.practicalObtained != null
            ? (row.practicalObtained! == row.practicalObtained!.roundToDouble()
                  ? row.practicalObtained!.toInt().toString()
                  : row.practicalObtained!.toString())
            : '';
        _pracControllers[id] = TextEditingController(text: initialText);
        _pracFocusNodes[id] = FocusNode();
      } else {
        final fNode = _pracFocusNodes[id];
        if (fNode == null || !fNode.hasFocus) {
          final targetText = row.practicalObtained != null
              ? (row.practicalObtained! ==
                        row.practicalObtained!.roundToDouble()
                    ? row.practicalObtained!.toInt().toString()
                    : row.practicalObtained!.toString())
              : '';
          if (_pracControllers[id]!.text != targetText) {
            _pracControllers[id]!.text = targetText;
          }
        }
      }
    }
  }

  void _onTheorySubmitted(int index, List<MarksEntryRow> roster, int pracMax) {
    final row = roster[index];
    if (pracMax > 0) {
      _pracFocusNodes[row.stuRegId]?.requestFocus();
    } else if (index + 1 < roster.length) {
      _theoryFocusNodes[roster[index + 1].stuRegId]?.requestFocus();
    }
  }

  void _onPracSubmitted(int index, List<MarksEntryRow> roster) {
    if (index + 1 < roster.length) {
      _theoryFocusNodes[roster[index + 1].stuRegId]?.requestFocus();
    }
  }

  Future<void> _handleSave() async {
    final notifier = ref.read(marksEntryProvider.notifier);
    final state = ref.read(marksEntryProvider);

    final hasMarks = state.roster.any(
      (r) =>
          r.theoryObtained != null || r.practicalObtained != null || r.isAbsent,
    );
    if (state.roster.isEmpty || state.selectedSubjId == null || !hasMarks) {
      return;
    }

    // Gate validations handled inside notifier, but overwrite check requires UI dialog
    final hasExisting = await notifier.hasExistingMarks();
    if (hasExisting) {
      final className =
          state.classes.firstWhere(
            (c) => c['ClassID'] == state.selectedClassId,
            orElse: () => {'CName': ''},
          )['CName'] ??
          '';
      final secName =
          state.sections.firstWhere(
            (s) => s['ClassSecID'] == state.selectedClassSecId,
            orElse: () => {'SecName': ''},
          )['SecName'] ??
          '';
      final subjName =
          state.subjects.firstWhere(
            (s) => s['SubjID'] == state.selectedSubjId,
            orElse: () => {'SubjName': ''},
          )['SubjName'] ??
          '';

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: const Text('Confirm Replace Marks'),
          content: Text(
            'Marks already entered for class ( $className ) and Section ( $secName ) and Subject ( $subjName ). ARE YOU SURE WANT TO REPLACE ?',
            style: AppTypography.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: AppColors.textOnPrimary,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marks Not Updated.'),
              backgroundColor: AppColors.statusErrorText,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      await notifier.saveAllMarks(overwriteConfirmed: true);
    } else {
      await notifier.saveAllMarks(overwriteConfirmed: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marksEntryProvider);
    final notifier = ref.read(marksEntryProvider.notifier);

    _syncControllers(state.roster);

    // Toast listener
    ref.listen<MarksEntryState>(marksEntryProvider, (prev, next) {
      if (next.toast != null && next.toast != prev?.toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            backgroundColor: AppColors.statusSuccessText,
            duration: const Duration(seconds: 4),
          ),
        );
        notifier.clearToast();
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleSave,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _handleSave,
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Filter Bar (~88px)
              _buildFilterBar(context, state, notifier),

              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // Step Indicator Strip
              _buildStepIndicator(state),

              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // 2. Cohort Action Strip (~52px)
              _buildCohortActionStrip(context, state, notifier),

              // 3. Error Banner (if error message exists)
              if (state.errorMessage != null)
                _buildErrorBanner(context, state.errorMessage!, notifier),

              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // 4. Primary Grading Grid (Expanded)
              Expanded(child: _buildGradingGrid(context, state, notifier)),

              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // 5. Sticky Footer Action Bar (~52px)
              _buildFooterBar(context, state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 1. FILTER BAR
  // ==========================================================================
  Widget _buildFilterBar(
    BuildContext context,
    MarksEntryState state,
    MarksEntryNotifier notifier,
  ) {
    final availableSessionsAsync = ref.watch(availableSessionsProvider);
    final availableSessions =
        availableSessionsAsync.valueOrNull ?? const <String>[];
    final effectiveSessions = <String>{
      if (state.selectedSessionYr.isNotEmpty) state.selectedSessionYr,
      ...availableSessions,
      ...state.sessionYears,
      '2017-2018',
    }.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Session, Term, ExamInfo, Class, Section, Subject Dropdowns
          Row(
            children: [
              // Session Year
              Expanded(
                flex: 2,
                child: _buildDropdownField<String>(
                  label: 'Session',
                  value: effectiveSessions.contains(state.selectedSessionYr)
                      ? state.selectedSessionYr
                      : (effectiveSessions.isNotEmpty
                            ? effectiveSessions.first
                            : null),
                  items: effectiveSessions.map((yr) {
                    return DropdownMenuItem<String>(
                      value: yr,
                      child: Text(yr, style: AppTypography.bodySmall),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setSessionYr(val);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Term
              Expanded(
                flex: 3,
                child: _buildDropdownField<int>(
                  label: 'Term',
                  value: state.selectedExTermId,
                  items: state.terms.map((t) {
                    final termId = (t['ExTermID'] as num).toInt();
                    final termName = t['TermName'] as String? ?? 'Term $termId';
                    return DropdownMenuItem<int>(
                      value: termId,
                      child: Text(termName, style: AppTypography.bodySmall),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setExTermId(val);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Exam Info
              Expanded(
                flex: 3,
                child: _buildDropdownField<int>(
                  label: 'Exam Schedule',
                  value: state.selectedExamInfoId,
                  items: state.examInfos.map((info) {
                    final infoId = (info['ExamInfoID'] as num).toInt();
                    final detail = info['Detail'] as String? ?? 'Exam #$infoId';
                    return DropdownMenuItem<int>(
                      value: infoId,
                      child: Text(
                        detail.isNotEmpty ? detail : 'Exam #$infoId',
                        style: AppTypography.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setExamInfoId(val);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Class
              Expanded(
                flex: 3,
                child: _buildDropdownField<int>(
                  label: 'Class',
                  value: state.selectedClassId,
                  items: state.classes.map((c) {
                    final cid = (c['ClassID'] as num).toInt();
                    final cname = c['CName'] as String? ?? 'Class $cid';
                    return DropdownMenuItem<int>(
                      value: cid,
                      child: Text(cname, style: AppTypography.bodySmall),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setClassId(val);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Section
              Expanded(
                flex: 2,
                child: _buildDropdownField<int>(
                  label: 'Section',
                  value: state.selectedClassSecId,
                  items: state.sections.map((s) {
                    final sid = (s['ClassSecID'] as num).toInt();
                    final sname = s['SecName'] as String? ?? 'Sec $sid';
                    return DropdownMenuItem<int>(
                      value: sid,
                      child: Text(sname, style: AppTypography.bodySmall),
                    );
                  }).toList(),
                  onChanged: (val) => notifier.setClassSecId(val),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Subject
              Expanded(
                flex: 4,
                child: _buildDropdownField<int>(
                  label: 'Subject',
                  value: state.selectedSubjId,
                  items: state.subjects.map((s) {
                    final subId = (s['SubjID'] as num).toInt();
                    final subName = s['SubjName'] as String? ?? 'Subj $subId';
                    return DropdownMenuItem<int>(
                      value: subId,
                      child: Text(
                        subName,
                        style: AppTypography.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => notifier.setSubjId(val),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // Row 2: Badges for Theory Max, Practical Max, and Teacher Override Dropdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: _buildBadgePill(
                  label: 'Theory Max',
                  value: '${state.theoryMax}',
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: _buildBadgePill(
                  label: 'Prac Max',
                  value: '${state.practicalMax}',
                  color: state.practicalMax > 0
                      ? AppColors.brandSecondary
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Teacher Override Dropdown (200px width, menuMaxHeight: 400)
              SizedBox(
                width: 200.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 32.0,
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey(state.selectedTeacherIdOverride),
                        initialValue: state.selectedTeacherIdOverride,
                        isExpanded: true,
                        menuMaxHeight: 400.0,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12.0,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 6.0,
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: const BorderSide(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          suffixIcon: state.selectedTeacherIdOverride != null
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 14),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  splashRadius: 12,
                                  tooltip: 'Revert to curriculum default',
                                  onPressed: () =>
                                      notifier.setTeacherOverride(null),
                                )
                              : null,
                        ),
                        hint: Text(
                          'Select Teacher',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11.0,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Not Assigned',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11.0,
                              ),
                            ),
                          ),
                          ...state.teachers.map((t) {
                            final tid = (t['TeacherID'] as num).toInt();
                            final tname =
                                t['TName'] as String? ?? 'Teacher $tid';
                            return DropdownMenuItem<int?>(
                              value: tid,
                              child: Text(
                                tname,
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) => notifier.setTeacherOverride(val),
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'Default: ${state.subjectTeacher ?? 'Not Assigned'}',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10.0,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => context.go('/exams/terms'),
                icon: const Icon(Icons.calendar_today_outlined, size: 14),
                label: const Text('Exam Terms', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderDefault),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => context.go('/exams/subjects'),
                icon: const Icon(Icons.menu_book_outlined, size: 14),
                label: const Text(
                  'Class Subjects',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderDefault),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11.0,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36.0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderDefault),
          ),
          alignment: Alignment.center,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: items.any((i) => i.value == value) ? value : null,
              items: items,
              onChanged: onChanged,
              menuMaxHeight: 400.0,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgePill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 11.0,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. STEP INDICATOR & COHORT ACTION STRIP
  // ==========================================================================
  Widget _buildStepIndicator(MarksEntryState state) {
    int activeStep = 1;
    final selectedStudents = state.roster.where((r) => r.isSelected).toList();
    final effectiveCohort = selectedStudents.isNotEmpty
        ? selectedStudents
        : state.roster;
    final anyMarksEntered = state.roster.any(
      (r) =>
          r.theoryObtained != null || r.practicalObtained != null || r.isAbsent,
    );

    if (state.roster.isEmpty) {
      activeStep = 1;
    } else if (effectiveCohort.any((r) => r.examMasId == null)) {
      activeStep = 2;
    } else if (anyMarksEntered) {
      activeStep = 4;
    } else {
      activeStep = 3;
    }

    final steps = [
      '1. Load Students',
      '2. Register for Exam',
      '3. Enter Marks',
      '4. Save',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4.0,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 9.0,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
              ),
            Container(
              height: 28.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeStep == i + 1
                    ? AppColors.brandPrimary
                    : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: activeStep == i + 1
                      ? AppColors.brandPrimary
                      : AppColors.borderDefault,
                ),
              ),
              child: Text(
                steps[i],
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11.0,
                  fontWeight: activeStep == i + 1
                      ? FontWeight.w700
                      : FontWeight.normal,
                  color: activeStep == i + 1
                      ? Colors.white
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCohortActionStrip(
    BuildContext context,
    MarksEntryState state,
    MarksEntryNotifier notifier,
  ) {
    final selectedCount = state.roster.where((r) => r.isSelected).length;

    return Container(
      height: 48.0,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surfaceRaised,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 1. [Load Students] - Primary CTA
                  ElevatedButton.icon(
                    icon: const Icon(Icons.people_outline, size: 16),
                    label: const Text('Load Students'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    onPressed: state.isLoading
                        ? null
                        : () => notifier.loadEnrolledStudents(),
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // 2. [Register Students for Exam] - Secondary CTA
                  Tooltip(
                    message: state.roster.isEmpty ? 'Load students first' : 'Creates exam records for all loaded students. Required before saving marks.',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_task_outlined, size: 16),
                      label: const Text('Register Students for Exam'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandPrimary,
                        side: BorderSide(
                          color: state.roster.isEmpty
                              ? AppColors.borderDefault
                              : AppColors.brandPrimary,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                      onPressed: state.isLoading || state.roster.isEmpty
                          ? null
                          : () => notifier.generateExamCohort(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // 3. [Load Existing] - Tertiary
                  TextButton.icon(
                    icon: const Icon(Icons.history_outlined, size: 16),
                    label: const Text('Load Existing'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    onPressed:
                        (state.isLoading ||
                            state.roster.isEmpty ||
                            state.selectedSubjId == null)
                        ? null
                        : () => notifier.loadExistingMarks(),
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // 4. [Select All]
                  OutlinedButton.icon(
                    icon: Icon(
                      state.roster.isNotEmpty &&
                              state.roster.every((r) => r.isSelected)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                    ),
                    label: const Text('Select All'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    onPressed: state.roster.isEmpty
                        ? null
                        : () => notifier.toggleSelectAll(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Cohort Tally Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Text(
              'Students: ${state.roster.length} Loaded | $selectedCount Selected',
              style: AppTypography.monospace.copyWith(
                fontSize: 12.0,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. ERROR BANNER
  // ==========================================================================
  Widget _buildErrorBanner(
    BuildContext context,
    String message,
    MarksEntryNotifier notifier,
  ) {
    return Container(
      color: AppColors.statusErrorBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 18.0,
            color: AppColors.statusErrorText,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16.0),
            color: AppColors.statusErrorText,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: () => notifier.clearError(),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 4. PRIMARY GRADING GRID
  // ==========================================================================
  Widget _buildGradingGrid(
    BuildContext context,
    MarksEntryState state,
    MarksEntryNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.roster.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.school_outlined,
              size: 48.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Select Session, Term, Class, Section, and Subject, then click Load Students',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Grid Sticky Header
        _buildGridHeader(context, state, notifier),
        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Grid Scrollable Body
        Expanded(
          child: ListView.builder(
            itemCount: state.roster.length,
            itemExtent: 44.0,
            itemBuilder: (context, index) {
              final row = state.roster[index];
              return _buildGridRow(context, index, row, state, notifier);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridHeader(
    BuildContext context,
    MarksEntryState state,
    MarksEntryNotifier notifier,
  ) {
    final allSelected =
        state.roster.isNotEmpty && state.roster.every((r) => r.isSelected);

    return Container(
      height: 38.0,
      color: AppColors.surfaceSubtle,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // Select Checkbox
          SizedBox(
            width: 40.0,
            child: Checkbox(
              value: allSelected,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => notifier.toggleSelectAll(),
            ),
          ),

          // RollNo
          const SizedBox(
            width: 60.0,
            child: Text(
              'RollNo',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
            ),
          ),

          // Reg ID
          const SizedBox(
            width: 70.0,
            child: Text(
              'Reg ID',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
            ),
          ),

          // Student Name
          const Expanded(
            flex: 3,
            child: Text(
              'Student Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
            ),
          ),

          // Father Name
          const Expanded(
            flex: 3,
            child: Text(
              'Father Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
            ),
          ),

          // Theory [Max]
          SizedBox(
            width: 110.0,
            child: Text(
              'Theory [${state.theoryMax}]',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.0,
              ),
            ),
          ),

          // Prac [Max]
          SizedBox(
            width: 110.0,
            child: Text(
              'Prac [${state.practicalMax}]',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.0,
              ),
            ),
          ),

          // Absent
          const SizedBox(
            width: 60.0,
            child: Center(
              child: Text(
                'Absent',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
              ),
            ),
          ),

          // Total
          const SizedBox(
            width: 70.0,
            child: Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
            ),
          ),

          // Grade
          const SizedBox(
            width: 65.0,
            child: Text(
              'Grade',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridRow(
    BuildContext context,
    int index,
    MarksEntryRow row,
    MarksEntryState state,
    MarksEntryNotifier notifier,
  ) {
    final isEven = index % 2 == 0;
    final rowBg = isEven ? AppColors.surfaceRaised : AppColors.surfaceSubtle;
    final grade = row.computeGrade(state.exGradeRows);

    final theoryController = _theoryControllers[row.stuRegId];
    final pracController = _pracControllers[row.stuRegId];
    final theoryFocusNode = _theoryFocusNodes[row.stuRegId];
    final pracFocusNode = _pracFocusNodes[row.stuRegId];

    return Container(
      height: 44.0,
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // Select Checkbox
          SizedBox(
            width: 40.0,
            child: Checkbox(
              value: row.isSelected,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => notifier.toggleRowSelect(row.stuRegId),
            ),
          ),

          // RollNo
          SizedBox(
            width: 60.0,
            child: Text(
              row.rollNo.toString(),
              style: AppTypography.monospace.copyWith(fontSize: 12.0),
            ),
          ),

          // Reg ID
          SizedBox(
            width: 70.0,
            child: Text(
              row.stuRegId.toString(),
              style: AppTypography.monospace.copyWith(fontSize: 12.0),
            ),
          ),

          // Student Name
          Expanded(
            flex: 3,
            child: Text(
              row.studentName,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Father Name
          Expanded(
            flex: 3,
            child: Text(
              row.fatherName ?? '-',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Theory Input Cell
          SizedBox(
            width: 110.0,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: SizedBox(
                height: 30.0,
                child: TextField(
                  controller: theoryController,
                  focusNode: theoryFocusNode,
                  enabled: !row.isAbsent,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  style: AppTypography.monospace.copyWith(fontSize: 12.0),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 6.0,
                    ),
                    filled: true,
                    fillColor: row.isAbsent
                        ? AppColors.surfaceSubtle
                        : AppColors.surfaceRaised,
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  onChanged: (text) {
                    final val = double.tryParse(text.trim());
                    notifier.updateTheory(row.stuRegId, val);
                  },
                  onSubmitted: (_) {
                    _onTheorySubmitted(index, state.roster, state.practicalMax);
                  },
                ),
              ),
            ),
          ),

          // Practical Input Cell
          SizedBox(
            width: 110.0,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: SizedBox(
                height: 30.0,
                child: TextField(
                  controller: pracController,
                  focusNode: pracFocusNode,
                  enabled: !row.isAbsent && state.practicalMax > 0,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  style: AppTypography.monospace.copyWith(fontSize: 12.0),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 6.0,
                    ),
                    filled: true,
                    fillColor: (row.isAbsent || state.practicalMax == 0)
                        ? AppColors.surfaceSubtle
                        : AppColors.surfaceRaised,
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  onChanged: (text) {
                    final val = double.tryParse(text.trim());
                    notifier.updatePractical(row.stuRegId, val);
                  },
                  onSubmitted: (_) {
                    _onPracSubmitted(index, state.roster);
                  },
                ),
              ),
            ),
          ),

          // Absent Checkbox
          SizedBox(
            width: 60.0,
            child: Center(
              child: Checkbox(
                value: row.isAbsent,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => notifier.toggleAbsent(row.stuRegId),
              ),
            ),
          ),

          // Total Marks
          SizedBox(
            width: 70.0,
            child: Text(
              row.isAbsent
                  ? '0/${row.totalMax}'
                  : '${row.totalObtained.toInt()}/${row.totalMax}',
              style: AppTypography.monospace.copyWith(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Grade Badge
          SizedBox(width: 65.0, child: _buildGradeBadge(grade)),
        ],
      ),
    );
  }

  Widget _buildGradeBadge(String grade) {
    Color bg;
    Color text;

    if (grade == 'A' || grade == 'A+' || grade == 'PASS') {
      bg = AppColors.statusSuccessBg;
      text = AppColors.statusSuccessText;
    } else if (grade == 'B' || grade == 'C') {
      bg = AppColors.statusInfoBg;
      text = AppColors.statusInfoText;
    } else if (grade == 'D') {
      bg = AppColors.statusWarningBg;
      text = AppColors.statusWarningText;
    } else {
      bg = AppColors.statusErrorBg;
      text = AppColors.statusErrorText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        grade,
        style: TextStyle(
          color: text,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ==========================================================================
  // 5. STICKY FOOTER ACTION BAR
  // ==========================================================================
  Widget _buildFooterBar(
    BuildContext context,
    MarksEntryState state,
    MarksEntryNotifier notifier,
  ) {
    int enteredCnt = 0;
    int absentCnt = 0;
    int modifiedCnt = 0;

    for (final row in state.roster) {
      if (row.isAbsent) {
        absentCnt++;
      } else if (row.theoryObtained != null || row.practicalObtained != null) {
        enteredCnt++;
      }
      if (row.persistedTheory != null &&
          (row.theoryObtained != row.persistedTheory ||
              row.practicalObtained != row.persistedPractical)) {
        modifiedCnt++;
      }
    }

    return Container(
      height: 52.0,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.surfaceRaised,
      child: Row(
        children: [
          // Left: Tally (Expanded pushes right buttons to the right edge)
          Expanded(
            child: Text(
              '$enteredCnt Entered, $modifiedCnt Changed, $absentCnt Absent',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Reports placeholders and primary save button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Student Mark Sheets report (\\Rpt31_StuMarkSheet.rpt) will be available in Phase E.',
                  ),
                ),
              );
            },
            child: const Text('Mark Sheets'),
          ),
          const SizedBox(width: AppSpacing.xs),

          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Class Award List report (\\Rpt32_ClassMark.rpt) will be available in Phase E.',
                  ),
                ),
              );
            },
            child: const Text('Award List'),
          ),
          const SizedBox(width: AppSpacing.xs),

          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Exam Statistics report (\\Rpt35_ExamSTAT.rpt) will be available in Phase E.',
                  ),
                ),
              );
            },
            child: const Text('Statistics'),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Primary Save Button
          ElevatedButton.icon(
            icon: state.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPrimary,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 16),
            label: const Text(
              'Save All Marks (Ctrl+S)',
              maxLines: 1,
              softWrap: false,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textOnPrimary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            onPressed:
                (state.isSaving ||
                    state.roster.isEmpty ||
                    state.selectedSubjId == null ||
                    !state.roster.any(
                      (r) =>
                          r.theoryObtained != null ||
                          r.practicalObtained != null ||
                          r.isAbsent,
                    ))
                ? null
                : _handleSave,
          ),
        ],
      ),
    );
  }
}
