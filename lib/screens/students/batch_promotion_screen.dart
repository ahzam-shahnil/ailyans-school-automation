import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/batch_promotion_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../models/promotion_candidate_row.dart';

class BatchPromotionScreen extends ConsumerStatefulWidget {
  const BatchPromotionScreen({super.key});

  @override
  ConsumerState<BatchPromotionScreen> createState() =>
      _BatchPromotionScreenState();
}

class _BatchPromotionScreenState extends ConsumerState<BatchPromotionScreen> {
  final TextEditingController _defaultMarksController = TextEditingController(
    text: '40',
  );
  final Map<int, TextEditingController> _rowMarksControllers = {};

  @override
  void dispose() {
    _defaultMarksController.dispose();
    for (final c in _rowMarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError
                ? AppColors.statusErrorText
                : AppColors.statusSuccessText,
          ),
        ),
        backgroundColor: isError
            ? AppColors.statusErrorBg
            : AppColors.statusSuccessBg,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLoadCandidates() async {
    final (ok, msg) = await ref
        .read(batchPromotionProvider.notifier)
        .loadCandidates();
    if (!mounted) return;
    if (!ok) {
      _showSnackBar(msg, isError: true);
    } else {
      // Synchronize row controllers
      final candidates = ref.read(batchPromotionProvider).candidates;
      for (final c in candidates) {
        _rowMarksControllers.putIfAbsent(
          c.stuRegId,
          () => TextEditingController(
            text: c.currentPassingMarks?.toInt().toString() ?? '',
          ),
        );
      }
    }
  }

  Future<void> _handlePromote() async {
    final state = ref.read(batchPromotionProvider);
    final (valid, error) = ref
        .read(batchPromotionProvider.notifier)
        .validateBeforePromote();

    if (!valid) {
      _showSnackBar(error ?? 'Validation failed', isError: true);
      return;
    }

    final selectedCount = state.selectedCount;
    final isGrad = state.isGraduationMode;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            isGrad ? 'Confirm Graduation' : 'Confirm Batch Promotion',
          ),
          content: Text(
            isGrad
                ? 'Are you sure you want to graduate $selectedCount students from Class 10? They will be marked as left in School Leaving and will not be enrolled in any class.'
                : 'Are you sure you want to promote $selectedCount selected students to the destination cohort?',
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, Go Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isGrad
                    ? AppColors.statusErrorText
                    : AppColors.brandPrimary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isGrad ? 'Yes, Graduate' : 'Yes, Promote'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final (ok, msg) = await ref
          .read(batchPromotionProvider.notifier)
          .promoteSelectedStudents();
      if (!mounted) return;
      if (ok) {
        ref.invalidate(availableSessionsProvider);
      }
      _showSnackBar(msg, isError: !ok);
    }
  }

  Future<void> _handleAutoReRoll() async {
    final (ok, msg) = await ref
        .read(batchPromotionProvider.notifier)
        .autoReRollTargetCohort();
    if (!mounted) return;
    _showSnackBar(msg, isError: !ok);
  }

  Future<void> _handleClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Clear Staging History'),
          content: const Text(
            'Are you Sure want to clear Temprary History of Promotion',
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, Keep'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: AppColors.textOnPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final (ok, msg) = await ref
          .read(batchPromotionProvider.notifier)
          .clearStagingHistory();
      if (!mounted) return;
      _showSnackBar(msg, isError: !ok);
    }
  }

  Future<void> _selectPromotionDate() async {
    final state = ref.read(batchPromotionProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: state.promotionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      ref.read(batchPromotionProvider.notifier).setPromotionDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchPromotionProvider);

    ref.listen<BatchPromotionState>(batchPromotionProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _showSnackBar(next.errorMessage!, isError: true);
      } else if (next.toast != null && next.toast != prev?.toast) {
        _showSnackBar(next.toast!, isError: false);
      }
    });

    final eligibleCandidates = state.candidates
        .where((c) => !c.isFailed)
        .toList();
    final allSelected =
        eligibleCandidates.isNotEmpty &&
        eligibleCandidates.every((c) => c.isSelected);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _handleLoadCandidates,
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          control: true,
          shift: true,
        ): _handlePromote,
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          ref.read(batchPromotionProvider.notifier).toggleSelectAll();
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
              // ── a) Header Row (~44px) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batch Promotion',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Move students from one session and class to the next.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: state.isGraduationMode
                          ? AppColors.statusWarningBg
                          : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: state.isGraduationMode
                            ? AppColors.statusWarningBorder
                            : AppColors.borderDefault,
                      ),
                    ),
                    child: Text(
                      state.isGraduationMode
                          ? 'Graduation Mode'
                          : (state.loadedRoster
                                ? '${state.candidates.length} Candidates'
                                : 'Ready'),
                      style: AppTypography.bodySmall.copyWith(
                        color: state.isGraduationMode
                            ? AppColors.statusWarningText
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── b) Source / Target Cards Row (~144px) ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT CARD: SOURCE COHORT (FROM)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SOURCE COHORT (FROM)',
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Text(
                                  'Active: ${state.candidates.length}',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              // Session
                              Expanded(
                                flex: 3,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Session',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: state.sourceSessionYr,
                                      isDense: true,
                                      isExpanded: true,
                                      menuMaxHeight: 400,
                                      items: state.availableSessions.map((yr) {
                                        return DropdownMenuItem<String>(
                                          value: yr,
                                          child: Text(yr),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        ref
                                            .read(
                                              batchPromotionProvider.notifier,
                                            )
                                            .setSourceSessionYr(val);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              // Class
                              Expanded(
                                flex: 3,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Class',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: state.sourceClassId,
                                      isDense: true,
                                      isExpanded: true,
                                      menuMaxHeight: 400,
                                      hint: const Text('Select Class'),
                                      items: state.classes.map((c) {
                                        return DropdownMenuItem<int>(
                                          value: c['ClassID'] as int,
                                          child: Text(c['CName'] as String),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        ref
                                            .read(
                                              batchPromotionProvider.notifier,
                                            )
                                            .setSourceClassId(val);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              // Section
                              Expanded(
                                flex: 2,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Section',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: state.sourceClassSecId,
                                      isDense: true,
                                      isExpanded: true,
                                      menuMaxHeight: 400,
                                      hint: const Text('Select Sec'),
                                      items: state.sourceSections.map((s) {
                                        return DropdownMenuItem<int>(
                                          value: s['ClassSecID'] as int,
                                          child: Text(s['SecName'] as String),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        ref
                                            .read(
                                              batchPromotionProvider.notifier,
                                            )
                                            .setSourceClassSecId(val);
                                      },
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

                  const SizedBox(width: AppSpacing.md),

                  // RIGHT CARD: DESTINATION COHORT (TO)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
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
                              Container(
                                width: 4,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'DESTINATION COHORT (TO)',
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (state.isGraduationMode) ...[
                            Container(
                              height: 38,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                              child: Text(
                                'Graduating (School Leaving)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                // Target Session
                                Expanded(
                                  flex: 3,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Target Session',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: state.targetSessionYr,
                                        isDense: true,
                                        isExpanded: true,
                                        menuMaxHeight: 400,
                                        items: state.availableSessions.map((
                                          yr,
                                        ) {
                                          return DropdownMenuItem<String>(
                                            value: yr,
                                            child: Text(yr),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          ref
                                              .read(
                                                batchPromotionProvider.notifier,
                                              )
                                              .setTargetSessionYr(val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                // Target Class
                                Expanded(
                                  flex: 3,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Target Class',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: state.targetClassId,
                                        isDense: true,
                                        isExpanded: true,
                                        menuMaxHeight: 400,
                                        hint: const Text('Target Class'),
                                        items: state.classes.map((c) {
                                          return DropdownMenuItem<int>(
                                            value: c['ClassID'] as int,
                                            child: Text(c['CName'] as String),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          ref
                                              .read(
                                                batchPromotionProvider.notifier,
                                              )
                                              .setTargetClassId(val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                // Target Section
                                Expanded(
                                  flex: 2,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Target Section',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: state.targetClassSecId,
                                        isDense: true,
                                        isExpanded: true,
                                        menuMaxHeight: 400,
                                        hint: const Text('Target Sec'),
                                        items: state.targetSections.map((s) {
                                          return DropdownMenuItem<int>(
                                            value: s['ClassSecID'] as int,
                                            child: Text(s['SecName'] as String),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          ref
                                              .read(
                                                batchPromotionProvider.notifier,
                                              )
                                              .setTargetClassSecId(val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              // Promotion Date
                              Expanded(
                                flex: 3,
                                child: InkWell(
                                  onTap: _selectPromotionDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Promotion Date',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      border: OutlineInputBorder(),
                                      suffixIcon: Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                      ),
                                    ),
                                    child: Text(
                                      DateFormat('dd-MMM-yyyy')
                                          .format(state.promotionDate),
                                      style: AppTypography.bodySmall,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              // Default Passing Marks
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _defaultMarksController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Default Passing Marks',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 12,
                                  ),
                                  onChanged: (val) {
                                    final d = double.tryParse(val);
                                    if (d != null && d >= 0) {
                                      ref
                                          .read(batchPromotionProvider.notifier)
                                          .setDefaultPassingMarks(d);
                                    }
                                  },
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
              const SizedBox(height: AppSpacing.xs),

              // ── c) Route Strip (~36px) ──
              _buildRouteStrip(state),
              const SizedBox(height: AppSpacing.xs),

              // ── d) Action Toolbar (~40px) ──
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _handleLoadCandidates,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Load Candidates (Ctrl+L)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.textOnPrimary,
                      minimumSize: const Size(150, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.candidates.isEmpty
                        ? null
                        : () {
                            ref
                                .read(batchPromotionProvider.notifier)
                                .toggleSelectAll();
                          },
                    icon: Icon(
                      allSelected ? Icons.deselect : Icons.select_all,
                      size: 16,
                    ),
                    label: Text(allSelected ? 'Deselect All' : 'Select All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(120, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _handlePromote,
                    icon: Icon(
                      state.isGraduationMode
                          ? Icons.school_outlined
                          : Icons.trending_up,
                      size: 16,
                    ),
                    label: const Text(
                      'Promote Selected Students (Ctrl+Shift+P)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isGraduationMode
                          ? AppColors.statusErrorText
                          : AppColors.brandPrimary,
                      foregroundColor: AppColors.textOnPrimary,
                      minimumSize: const Size(180, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: state.isGraduationMode
                        ? 'No target cohort to re-roll'
                        : 'Renumber active students in target cohort sequentially 1..N',
                    child: OutlinedButton.icon(
                      onPressed: state.isGraduationMode
                          ? null
                          : _handleAutoReRoll,
                      icon: const Icon(Icons.format_list_numbered, size: 16),
                      label: const Text('Auto Re-Roll'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(120, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Clear promotion staging history',
                    child: OutlinedButton.icon(
                      onPressed: _handleClearHistory,
                      icon: const Icon(
                        Icons.delete_sweep_outlined,
                        size: 16,
                        color: AppColors.statusErrorText,
                      ),
                      label: const Text(
                        'Clear Staging History',
                        style: TextStyle(color: AppColors.statusErrorText),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.statusErrorBorder,
                        ),
                        minimumSize: const Size(140, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── e) Candidate Grid (Expanded, internal scroll) ──
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: _buildCandidateGrid(state),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── f) Pinned Footer (~44px) ──
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Row(
                  children: [
                    Text(
                      '${state.selectedCount} of ${state.candidates.length} students selected',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: state.committing
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                LinearProgressIndicator(
                                  value: state.commitTotal > 0
                                      ? state.commitProgress / state.commitTotal
                                      : null,
                                  backgroundColor: AppColors.surfaceSubtle,
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.brandPrimary,
                                  ),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Committing ${state.commitProgress} of ${state.commitTotal} students...',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      state.committing
                          ? 'Committing'
                          : (state.loadedRoster ? 'Cohort loaded' : 'Ready'),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
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

  Widget _buildRouteStrip(BatchPromotionState state) {
    Color bg = AppColors.surfaceSubtle;
    Color textColor = AppColors.textSecondary;
    String message = '';
    IconData icon = Icons.info_outline;

    final srcYr = BatchPromotionNotifier.parseStartYear(state.sourceSessionYr);
    final tgtYr = BatchPromotionNotifier.parseStartYear(state.targetSessionYr);

    if (state.sourceClassId == 13) {
      bg = AppColors.statusWarningBg;
      textColor = AppColors.statusWarningText;
      icon = Icons.school_outlined;
      message = 'Class 10 is the graduation class. Selected students will be marked as graduated and recorded in School Leaving with the Promotion Date as their leaving date. They will not be enrolled in any class.';
    } else if (state.targetSessionYr != null &&
        state.sourceSessionYr != null &&
        tgtYr <= srcYr) {
      bg = AppColors.statusErrorBg;
      textColor = AppColors.statusErrorText;
      icon = Icons.error_outline;
      message = 'Target session must be later than source session.';
    } else if (state.targetClassId != null &&
        state.sourceClassId != null &&
        state.targetClassId! < state.sourceClassId!) {
      bg = AppColors.statusErrorBg;
      textColor = AppColors.statusErrorText;
      icon = Icons.error_outline;
      message = 'Target class is lower than source class. Choose the same or a higher class.';
    } else if (state.targetClassId != null &&
        state.sourceClassId != null &&
        state.targetClassId! == state.sourceClassId!) {
      bg = AppColors.statusWarningBg;
      textColor = AppColors.statusWarningText;
      icon = Icons.warning_amber_rounded;
      message = 'Promoting to the same class is unusual. Confirm this is intentional.';
    } else if (state.targetClassId != null &&
        state.sourceClassId != null &&
        (state.targetClassId! - state.sourceClassId!) >= 2) {
      bg = AppColors.statusWarningBg;
      textColor = AppColors.statusWarningText;
      icon = Icons.warning_amber_rounded;
      message =
          'Skipping a class level is unusual. Confirm this is intentional.';
    } else {
      bg = AppColors.surfaceSubtle;
      textColor = AppColors.textSecondary;
      icon = Icons.arrow_forward;
      final srcClass = state.classes.firstWhere(
        (c) => c['ClassID'] == state.sourceClassId,
        orElse: () => {'CName': 'Class ?'},
      )['CName'];
      final tgtClass = state.classes.firstWhere(
        (c) => c['ClassID'] == state.targetClassId,
        orElse: () => {'CName': 'Class ?'},
      )['CName'];
      message =
          '$srcClass (${state.sourceSessionYr ?? '-'}) -> $tgtClass (${state.targetSessionYr ?? '-'})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateGrid(BatchPromotionState state) {
    if (!state.loadedRoster) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_add_outlined,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'No candidates loaded',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Select the source session, class and section, then click Load Candidates.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (state.candidates.isEmpty) {
      final className = state.classes.firstWhere(
        (c) => c['ClassID'] == state.sourceClassId,
        orElse: () => {'CName': 'Class'},
      )['CName'];
      final secName = state.sourceSections.firstWhere(
        (s) => s['ClassSecID'] == state.sourceClassSecId,
        orElse: () => {'SecName': '-'},
      )['SecName'];

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'No active students found',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Class $className-$secName has no active students in session ${state.sourceSessionYr}.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Sticky Header Row (40px)
        Container(
          height: 40,
          color: AppColors.surfaceSubtle,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Checkbox(
                  value:
                      state.candidates.where((c) => !c.isFailed).isNotEmpty &&
                      state.candidates
                          .where((c) => !c.isFailed)
                          .every((c) => c.isSelected),
                  onChanged: (_) {
                    ref.read(batchPromotionProvider.notifier).toggleSelectAll();
                  },
                ),
              ),
              const SizedBox(
                width: 80,
                child: Text(
                  'Reg ID',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(
                width: 60,
                child: Text(
                  'Roll',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Student Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Father Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(
                width: 100,
                child: Text(
                  'Passing Marks',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(
                width: 160,
                child: Text(
                  'Target Status',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),

        // Scrollable Table Body
        Expanded(
          child: ListView.builder(
            itemCount: state.candidates.length,
            itemBuilder: (context, index) {
              final c = state.candidates[index];
              final isEven = index % 2 == 0;
              final controller = _rowMarksControllers.putIfAbsent(
                c.stuRegId,
                () => TextEditingController(
                  text: c.currentPassingMarks?.toInt().toString() ?? '',
                ),
              );

              return Container(
                height: 40,
                color: isEven
                    ? AppColors.surfaceSubtle.withValues(alpha: 0.3)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Checkbox(
                        value: c.isSelected,
                        onChanged: c.isFailed
                            ? null
                            : (_) {
                                ref
                                    .read(batchPromotionProvider.notifier)
                                    .toggleRowSelected(c.stuRegId);
                              },
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '#${c.stuRegId}',
                        style: AppTypography.monospace.copyWith(fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        c.rollNo.toString().padLeft(2, '0'),
                        style: AppTypography.monospace.copyWith(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        c.studentName,
                        style: AppTypography.label.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        c.fatherName ?? '-',
                        style: AppTypography.bodySmall.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: AppTypography.monospace.copyWith(fontSize: 12),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: c.isManuallyEdited
                                ? const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppColors.brandPrimary,
                                      width: 1.5,
                                    ),
                                  )
                                : const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppColors.borderDefault,
                                    ),
                                  ),
                          ),
                          onChanged: (val) {
                            final m = double.tryParse(val);
                            ref
                                .read(batchPromotionProvider.notifier)
                                .updateRowPassingMarks(c.stuRegId, m);
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: _buildTargetStatusBadge(state, c),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTargetStatusBadge(
    BatchPromotionState state,
    PromotionCandidateRow c,
  ) {
    if (c.isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.statusErrorBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          'Retained (Failed)',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.statusErrorText,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (state.isGraduationMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.statusWarningBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          'Graduating Matric',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.statusWarningText,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final tgtClass = state.classes.firstWhere(
      (cls) => cls['ClassID'] == state.targetClassId,
      orElse: () => {'CName': 'Next Class'},
    )['CName'];
    final tgtSec = state.targetSections.firstWhere(
      (sec) => sec['ClassSecID'] == state.targetClassSecId,
      orElse: () => {'SecName': ''},
    )['SecName'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.statusSuccessBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        'Promotes to $tgtClass${tgtSec.isNotEmpty ? '-$tgtSec' : ''}',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.statusSuccessText,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
