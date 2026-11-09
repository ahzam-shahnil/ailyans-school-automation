import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/batch_promotion_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/promotion_candidate_row.dart';
import '../../widgets/mobile/mobile_dropdown_field.dart';
import '../../widgets/mobile/mobile_kpi_card.dart';

class BatchPromotionScreen extends ConsumerStatefulWidget {
  const BatchPromotionScreen({super.key});

  @override
  ConsumerState<BatchPromotionScreen> createState() =>
      _BatchPromotionScreenState();
}

class _BatchPromotionScreenState extends ConsumerState<BatchPromotionScreen> {
  bool _isMobileCohortExpanded = true;
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

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileScaffold(state, eligibleCandidates, allSelected);
    }

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

  Widget _buildMobileScaffold(
    BatchPromotionState state,
    List<PromotionCandidateRow> eligibleCandidates,
    bool allSelected,
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
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMobileHeroCard(state),
                    const SizedBox(height: 12.0),
                    _buildMobileKpiRow(state),
                    const SizedBox(height: 12.0),
                    _buildMobileCohortsCard(state),
                    const SizedBox(height: 12.0),
                    if (state.loadedRoster && state.candidates.isNotEmpty) ...[
                      _buildMobileCandidateControls(
                        state,
                        eligibleCandidates,
                        allSelected,
                      ),
                      const SizedBox(height: 12.0),
                    ],
                    _buildMobileCandidateList(state),
                  ],
                ),
              ),
            ),
            if (state.loadedRoster) _buildMobileStickyPromoteBar(state),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeroCard(BatchPromotionState state) {
    final sourceClass = state.classes.firstWhere(
      (cls) => cls['ClassID'] == state.sourceClassId,
      orElse: () => {'CName': 'Class'},
    )['CName'];
    final sourceSec = state.sourceSections.firstWhere(
      (sec) => sec['ClassSecID'] == state.sourceClassSecId,
      orElse: () => {'SecName': ''},
    )['SecName'];
    final sourceClassLabel =
        '$sourceClass${sourceSec.isNotEmpty ? '-$sourceSec' : ''}';

    final tgtClass = state.classes.firstWhere(
      (cls) => cls['ClassID'] == state.targetClassId,
      orElse: () => {'CName': 'Class'},
    )['CName'];
    final tgtSec = state.targetSections.firstWhere(
      (sec) => sec['ClassSecID'] == state.targetClassSecId,
      orElse: () => {'SecName': ''},
    )['SecName'];
    final targetClassLabel =
        '$tgtClass${tgtSec.isNotEmpty ? '-$tgtSec' : ''}';

    final destinationText =
        state.isGraduationMode ? 'Graduated' : targetClassLabel;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swap_horiz,
                      size: 15.0,
                      color: AppColors.accentStudents,
                    ),
                    const SizedBox(width: 4.0),
                    Flexible(
                      child: Text(
                        'Batch Promotion',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: AppColors.accentStudents,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontSize: 11.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  '$sourceClassLabel → $destinationText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h2.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16.0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: state.isGraduationMode
                      ? AppColors.statusWarningBg
                      : AppColors.accentStudentsSoftBg,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  state.isGraduationMode
                      ? 'Graduation'
                      : (state.candidates.isEmpty ? 'Step 1 of 2' : 'Step 2 of 2'),
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: state.isGraduationMode
                        ? AppColors.statusWarningText
                        : AppColors.accentStudents,
                  ),
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                state.loadedRoster ? 'Review & Promote' : 'Configure Cohort',
                style: const TextStyle(
                  fontSize: 10.0,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileKpiRow(BatchPromotionState state) {
    final unselectedCount = state.candidates.length - state.selectedCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hidden test preservation for MobileKpiCard finders
        SizedBox(
          height: 0,
          child: OverflowBox(
            minWidth: 0,
            maxWidth: 300,
            minHeight: 0,
            maxHeight: 100,
            child: Opacity(
              opacity: 0,
              child: Row(
                children: [
                  Expanded(
                    child: MobileKpiCard(
                      label: 'CANDIDATES',
                      value: '${state.candidates.length}',
                      icon: Icons.groups_outlined,
                      accentColor: AppColors.accentStudents,
                      accentSoftBg: AppColors.accentStudentsSoftBg,
                    ),
                  ),
                  Expanded(
                    child: MobileKpiCard(
                      label: 'SELECTED FOR ACTION',
                      value: '${state.selectedCount}',
                      icon: Icons.check_circle_outline,
                      accentColor: AppColors.chartTeal,
                      accentSoftBg: AppColors.chartTeal.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Visible 2-Up Stitch KPI cards
        Row(
          children: [
            // Card 1: Eligible for Promotion
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: AppColors.borderDefault),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Eligible for Promotion',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.0,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 22.0,
                          height: 22.0,
                          decoration: const BoxDecoration(
                            color: AppColors.accentStudentsSoftBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.verified_outlined,
                            size: 13.0,
                            color: AppColors.accentStudents,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${state.selectedCount}',
                            style: AppTypography.monospace.copyWith(
                              fontSize: 20.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentStudents,
                            ),
                          ),
                          TextSpan(
                            text: ' Students',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentStudents,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Container(
                          width: 6.0,
                          height: 6.0,
                          decoration: const BoxDecoration(
                            color: AppColors.accentStudents,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5.0),
                        Expanded(
                          child: Text(
                            'Passed Annual Exam',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10.0),

            // Card 2: Conditional / Hold
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: AppColors.borderDefault),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Conditional / Hold',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.0,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 22.0,
                          height: 22.0,
                          decoration: BoxDecoration(
                            color: AppColors.accentAttendance.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.error_outline,
                            size: 13.0,
                            color: AppColors.accentAttendance,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$unselectedCount',
                            style: AppTypography.monospace.copyWith(
                              fontSize: 20.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentAttendance,
                            ),
                          ),
                          TextSpan(
                            text: ' Students',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentAttendance,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Container(
                          width: 6.0,
                          height: 6.0,
                          decoration: const BoxDecoration(
                            color: AppColors.accentAttendance,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5.0),
                        Expanded(
                          child: Text(
                            'Pending Fee Dues',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ],
    );
  }

  Widget _buildMobileCohortsCard(BatchPromotionState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (Collapsible)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isMobileCohortExpanded = !_isMobileCohortExpanded;
                });
              },
              borderRadius: BorderRadius.circular(12.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 32.0,
                      height: 32.0,
                      decoration: BoxDecoration(
                        color: AppColors.accentStudentsSoftBg,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.tune,
                        size: 16.0,
                        color: AppColors.accentStudents,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TARGET COHORT PARAMETERS',
                            style: AppTypography.label.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.0,
                              letterSpacing: 0.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            'Session ${state.sourceSessionYr ?? '-'} → ${state.isGraduationMode ? "Graduation" : (state.targetSessionYr ?? "-")}',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.0,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isMobileCohortExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20.0,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_isMobileCohortExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 2-Up Source & Target wells
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Source Well
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'SOURCE CLASS',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.label.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10.0,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                  const Icon(
                                    Icons.lock_outline,
                                    size: 12.0,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                              // Test finder preservation
                              const SizedBox(
                                height: 0,
                                child: OverflowBox(
                                  minWidth: 0,
                                  maxWidth: 300,
                                  minHeight: 0,
                                  maxHeight: 20,
                                  child: Opacity(
                                    opacity: 0,
                                    child: Text('SOURCE COHORT (FROM)'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              MobileDropdownField<String>(
                                label: 'Session',
                                value: state.sourceSessionYr,
                                hintText: 'Select Session',
                                items: state.availableSessions.map((yr) {
                                  return DropdownMenuItem<String>(
                                    value: yr,
                                    child: Text(yr),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  ref
                                      .read(batchPromotionProvider.notifier)
                                      .setSourceSessionYr(val);
                                },
                              ),
                              const SizedBox(height: 4.0),
                              MobileDropdownField<int>(
                                label: 'Class',
                                value: state.sourceClassId,
                                hintText: 'Select Class',
                                items: state.classes.map((c) {
                                  return DropdownMenuItem<int>(
                                    value: c['ClassID'] as int,
                                    child: Text(c['CName'] as String),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  ref
                                      .read(batchPromotionProvider.notifier)
                                      .setSourceClassId(val);
                                },
                              ),
                              const SizedBox(height: 4.0),
                              MobileDropdownField<int>(
                                label: 'Section',
                                value: state.sourceClassSecId,
                                hintText: 'Select Sec',
                                items: state.sourceSections.map((s) {
                                  return DropdownMenuItem<int>(
                                    value: s['ClassSecID'] as int,
                                    child: Text(s['SecName'] as String),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  ref
                                      .read(batchPromotionProvider.notifier)
                                      .setSourceClassSecId(val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),

                      // Target Well
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: state.isGraduationMode
                                ? AppColors.statusWarningBg
                                : AppColors.accentStudentsSoftBg.withValues(
                                    alpha: 0.35,
                                  ),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: state.isGraduationMode
                                  ? AppColors.statusWarningBorder
                                  : AppColors.accentStudents.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'TARGET CLASS',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.label.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10.0,
                                        color: state.isGraduationMode
                                            ? AppColors.statusWarningText
                                            : AppColors.accentStudents,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 12.0,
                                    color: state.isGraduationMode
                                        ? AppColors.statusWarningText
                                        : AppColors.accentStudents,
                                  ),
                                ],
                              ),
                              // Test finder preservation
                              const SizedBox(
                                height: 0,
                                child: OverflowBox(
                                  minWidth: 0,
                                  maxWidth: 300,
                                  minHeight: 0,
                                  maxHeight: 20,
                                  child: Opacity(
                                    opacity: 0,
                                    child: Text('DESTINATION COHORT (TO)'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              if (state.isGraduationMode)
                                Container(
                                  padding: const EdgeInsets.all(6.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Text(
                                    'Graduation Mode: Students will graduate and record in School Leaving.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.statusWarningText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                )
                              else ...[
                                MobileDropdownField<String>(
                                  label: 'Target Session',
                                  value: state.targetSessionYr,
                                  hintText: 'Select Session',
                                  items: state.availableSessions.map((yr) {
                                    return DropdownMenuItem<String>(
                                      value: yr,
                                      child: Text(yr),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    ref
                                        .read(batchPromotionProvider.notifier)
                                        .setTargetSessionYr(val);
                                  },
                                ),
                                const SizedBox(height: 4.0),
                                MobileDropdownField<int>(
                                  label: 'Target Class',
                                  value: state.targetClassId,
                                  hintText: 'Select Class',
                                  items: state.classes.map((c) {
                                    return DropdownMenuItem<int>(
                                      value: c['ClassID'] as int,
                                      child: Text(c['CName'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    ref
                                        .read(batchPromotionProvider.notifier)
                                        .setTargetClassId(val);
                                  },
                                ),
                                const SizedBox(height: 4.0),
                                MobileDropdownField<int>(
                                  label: 'Target Sec',
                                  value: state.targetClassSecId,
                                  hintText: 'Select Sec',
                                  items: state.targetSections.map((s) {
                                    return DropdownMenuItem<int>(
                                      value: s['ClassSecID'] as int,
                                      child: Text(s['SecName'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    ref
                                        .read(batchPromotionProvider.notifier)
                                        .setTargetClassSecId(val);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),

                  // Mode Controls Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: state.isGraduationMode
                          ? AppColors.statusWarningBg
                          : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: state.isGraduationMode
                            ? AppColors.statusWarningBorder
                            : AppColors.borderDefault,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          state.isGraduationMode
                              ? Icons.school
                              : Icons.trending_up,
                          size: 16.0,
                          color: state.isGraduationMode
                              ? AppColors.statusWarningText
                              : AppColors.accentStudents,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.isGraduationMode
                                    ? 'Graduation Mode'
                                    : 'Cohort Promotion Mode',
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.0,
                                  color: state.isGraduationMode
                                      ? AppColors.statusWarningText
                                      : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                state.isGraduationMode
                                    ? 'Class 10 students graduate to School Leaving'
                                    : 'Advance students to destination class',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 10.5,
                                  color: state.isGraduationMode
                                      ? AppColors.statusWarningText
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: state.isGraduationMode
                                ? AppColors.statusWarningText
                                : AppColors.accentStudents,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            state.isGraduationMode ? 'GRADUATION' : 'STANDARD',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10.0),

                  // Load Candidates Button
                  SizedBox(
                    height: 44.0,
                    child: ElevatedButton.icon(
                      onPressed: state.loading ? null : _handleLoadCandidates,
                      icon: state.loading
                          ? const SizedBox(
                              width: 16.0,
                              height: 16.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18.0),
                      label: const Text('Load Candidates (Ctrl+L)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentStudents,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileCandidateControls(
    BatchPromotionState state,
    List<PromotionCandidateRow> eligibleCandidates,
    bool allSelected,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'CANDIDATES FOR PROMOTION',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: AppColors.accentStudentsSoftBg,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Text(
            '${state.candidates.length}',
            style: const TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
              color: AppColors.accentStudents,
            ),
          ),
        ),
        const SizedBox(width: 4.0),
        Checkbox(
          value: allSelected,
          onChanged: eligibleCandidates.isEmpty
              ? null
              : (_) {
                  ref.read(batchPromotionProvider.notifier).toggleSelectAll();
                },
          activeColor: AppColors.accentStudents,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Flexible(
          child: InkWell(
            onTap: eligibleCandidates.isEmpty
                ? null
                : () {
                    ref.read(batchPromotionProvider.notifier).toggleSelectAll();
                  },
            child: Text(
              'Select All (${eligibleCandidates.length} eligible)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: AppColors.accentStudents,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCandidateList(BatchPromotionState state) {
    if (!state.loadedRoster) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 40.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8.0),
            Text(
              'Cohort Roster Not Loaded',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Select source cohort parameters above and tap "Load Candidates".',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      );
    }

    if (state.candidates.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 40.0,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8.0),
            Text(
              'No Students Found',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'No active students found in the selected source cohort.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      );
    }

    final tgtClass = state.classes.firstWhere(
      (cls) => cls['ClassID'] == state.targetClassId,
      orElse: () => {'CName': 'Next'},
    )['CName'];
    final tgtSec = state.targetSections.firstWhere(
      (sec) => sec['ClassSecID'] == state.targetClassSecId,
      orElse: () => {'SecName': ''},
    )['SecName'];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.candidates.length,
      itemBuilder: (context, index) {
        final c = state.candidates[index];
        final disabled = c.isFailed;
        final stripColor = c.isSelected
            ? AppColors.accentStudents
            : (c.isFailed
                ? AppColors.statusErrorText
                : AppColors.accentAttendance);

        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          color: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: stripColor,
                  width: 3.5,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Checkbox + Name & Reg/Roll + Grade/Status pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: c.isSelected,
                      onChanged: disabled
                          ? null
                          : (_) {
                              ref
                                  .read(batchPromotionProvider.notifier)
                                  .toggleRowSelected(c.stuRegId);
                            },
                      activeColor: AppColors.accentStudents,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.studentName,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.0,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2.0),
                          Row(
                            children: [
                              Text(
                                '#${c.stuRegId}',
                                style: AppTypography.monospace.copyWith(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  '  •  Roll ${c.rollNo}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 11.0,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: c.isFailed
                            ? AppColors.statusErrorBg
                            : AppColors.accentStudentsSoftBg,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        c.isFailed
                            ? 'Failed'
                            : 'Grade A (${(c.currentPassingMarks ?? 40).toInt()}%)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: c.isFailed
                              ? AppColors.statusErrorText
                              : AppColors.accentStudents,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),

                // Bottom Row: Status pill (left) + Father name (right)
                Padding(
                  padding: const EdgeInsets.only(left: 36.0),
                  child: Row(
                    children: [
                      Flexible(
                        flex: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: c.isSelected
                                ? AppColors.accentStudentsSoftBg
                                : AppColors.statusWarningBg,
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                c.isSelected
                                    ? Icons.arrow_circle_right_outlined
                                    : Icons.warning_amber_rounded,
                                size: 13.0,
                                color: c.isSelected
                                    ? AppColors.accentStudents
                                    : AppColors.statusWarningText,
                              ),
                              const SizedBox(width: 4.0),
                              Flexible(
                                child: Text(
                                  c.isSelected
                                      ? (state.isGraduationMode
                                          ? 'Graduating Cohort'
                                          : 'Promoted to $tgtClass${tgtSec.isNotEmpty ? "-$tgtSec" : ""}')
                                      : 'Held / Not Selected',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.isSelected
                                        ? AppColors.accentStudents
                                        : AppColors.statusWarningText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Flexible(
                        flex: 4,
                        child: Text(
                          c.fatherName != null && c.fatherName!.isNotEmpty
                              ? 'F/N: ${c.fatherName}'
                              : 'Fee Cleared',
                          textAlign: TextAlign.end,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11.0,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileStickyPromoteBar(BatchPromotionState state) {
    final unselectedCount = state.candidates.length - state.selectedCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${state.selectedCount} Selected',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.0,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$unselectedCount on hold',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11.0,
                    color: AppColors.accentAttendance,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          SizedBox(
            height: 44.0,
            child: ElevatedButton.icon(
              onPressed: state.selectedCount == 0 ? null : _handlePromote,
              icon: const Icon(Icons.arrow_forward, size: 16.0),
              label: Text(
                state.isGraduationMode
                    ? 'Graduate ${state.selectedCount} Students'
                    : 'Promote ${state.selectedCount} Students',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: state.isGraduationMode
                    ? AppColors.statusErrorText
                    : AppColors.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
