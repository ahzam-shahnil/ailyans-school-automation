import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/school_leaving_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/leaving_student_row.dart';
import '../../widgets/mobile/mobile_dropdown_field.dart';
import '../../widgets/mobile/mobile_kpi_card.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

class SchoolLeavingScreen extends ConsumerStatefulWidget {
  const SchoolLeavingScreen({super.key});

  @override
  ConsumerState<SchoolLeavingScreen> createState() =>
      _SchoolLeavingScreenState();
}

class _SchoolLeavingScreenState extends ConsumerState<SchoolLeavingScreen> {
  final TextEditingController _remarksController = TextEditingController();

  String? _lastSyncedUri;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final uri = GoRouterState.of(context).uri;
      final uriStr = uri.toString();
      if (_lastSyncedUri == uriStr) return;
      _lastSyncedUri = uriStr;

      final sid = uri.queryParameters['studentId'];
      final parsedId = sid != null ? int.tryParse(sid) : null;
      if (parsedId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(schoolLeavingProvider.notifier).selectStudent(parsedId);
          }
        });
      }
    } catch (_) {
      // Safe fallback if GoRouter is not available in test harness
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
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

  Future<void> _handleCommit() async {
    final state = ref.read(schoolLeavingProvider);
    final (canCommit, error) = ref
        .read(schoolLeavingProvider.notifier)
        .canCommit();

    if (!canCommit) {
      _showSnackBar(error ?? 'Cannot commit school leaving', isError: true);
      return;
    }

    final student = state.selectedStudent!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm School Leaving'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WARNING. No Vouchers will b egeberated in Future. ARE YOU SURE?',
                  style: AppTypography.label.copyWith(
                    color: AppColors.statusErrorText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '1. Active classroom enrollment for ${student.stuRegId} - ${student.studentName} will be deactivated.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  '2. A School Leaving record will be saved with the terms entered.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  '3. No further fee vouchers will be generated for this student.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: AppColors.textOnPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Commit Withdrawal'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final (ok, msg) = await ref
          .read(schoolLeavingProvider.notifier)
          .commitLeaving();
      if (!mounted) return;
      _showSnackBar(msg, isError: !ok);
    }
  }

  void _handlePrintCertificate() {
    final slcState = ref.read(schoolLeavingProvider);
    if (!slcState.hasExistingSlc && slcState.committedSlc == null) {
      _showSnackBar('No leaving record available to print', isError: true);
      return;
    }

    final student = slcState.selectedStudent!;
    final meta = ref.read(shellMetadataProvider).valueOrNull;

    // Build the slcData map from available state.
    // Prefer the committedSlc map (just-committed) over the existingSlc fields.
    final String leavingDate;
    final String conduct;
    final String reason;
    final String remarks;

    if (slcState.committedSlc != null) {
      leavingDate = slcState.committedSlc!['LeftDate'] as String? ?? '';
      conduct = slcState.conduct?.trim() ?? '';
      reason = slcState.reason?.trim() ?? '';
      remarks = slcState.remarks;
    } else {
      leavingDate = student.existingSlcDate ?? '';
      conduct = student.existingSlcConduct?.trim() ?? '';
      reason = student.existingSlcTerm?.trim() ?? '';
      remarks = student.existingSlcRemarks ?? '';
    }

    final slcData = <String, dynamic>{
      'studentName': student.studentName,
      'fatherName': student.fatherName ?? '',
      'className': student.classSecDisplay,
      'dob': (slcState.committedSlc?['DOB'] ??
              slcState.committedSlc?['dob'] ??
              student.dob ??
              '')
          .toString(),
      'admissionDate': student.admissionDate ?? '',
      'leavingDate': leavingDate,
      'conduct': conduct,
      'reason': reason,
      'remarks': remarks,
      'leftDate': leavingDate,
      'leftClass': student.classSecDisplay,
      'charactor': conduct,
      'termOfLeaving': reason,
    };

    ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.slc,
        id: '${student.stuRegId}',
        extraParams: {
          'slcData': slcData,
          'branchName': meta?.branchName ?? '',
          'branchAddress': meta?.branchAddress ?? '',
        },
      ),
    );
  }

  void _handlePrintRegister() {
    final meta = ref.read(shellMetadataProvider).valueOrNull;
    final state = ref.read(schoolLeavingProvider);

    final leavers = state.students
        .where((s) => s.hasSLC)
        .map(
          (s) => <String, dynamic>{
            'stuRegId': s.stuRegId.toString(),
            'regId': s.stuRegId.toString(),
            'name': s.studentName,
            'studentName': s.studentName,
            'father': s.fatherName ?? '',
            'fatherName': s.fatherName ?? '',
            'className': s.classSecDisplay,
            'classLeft': s.classSecDisplay,
            'dateLeft': s.existingSlcDate ?? '',
            'leavingDate': s.existingSlcDate ?? '',
            'reason': s.existingSlcTerm ?? '',
          },
        )
        .toList();

    if (leavers.isEmpty) {
      _showSnackBar('No leaving records available to print', isError: true);
      return;
    }

    ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.slcRegister,
        titleOverride: 'SLC Register',
        extraParams: {
          'sessionYear': meta?.sessionYear ?? '2026-27',
          'leavers': leavers,
          'branchName': meta?.branchName ?? '-',
          'branchAddress': meta?.branchAddress ?? '-',
        },
      ),
    );
  }

  Future<void> _selectLeavingDate() async {
    final state = ref.read(schoolLeavingProvider);
    if (!state.isFormEditable) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: state.leavingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );

    if (picked != null) {
      ref.read(schoolLeavingProvider.notifier).setLeavingDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schoolLeavingProvider);

    ref.listen<SchoolLeavingState>(schoolLeavingProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _showSnackBar(next.errorMessage!, isError: true);
      } else if (next.toast != null && next.toast != prev?.toast) {
        _showSnackBar(next.toast!, isError: false);
      }

      if (next.remarks != _remarksController.text) {
        _remarksController.text = next.remarks;
      }
    });

    final student = state.selectedStudent;
    final printEnabled = state.hasExistingSlc || state.committedSlc != null;
    final commitDisabled = state.hasExistingSlc;

    final fromParam = () {
      try {
        return GoRouterState.of(context).uri.queryParameters['from'];
      } catch (_) {
        return null;
      }
    }();
    final backTarget = fromParam;
    final backLabel = backTarget != null && backTarget.startsWith('/students/')
        ? 'Back to Student Profile'
        : 'Back to Students';

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileScaffold(
        state,
        student,
        printEnabled,
        commitDisabled,
        backTarget,
        backLabel,
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleCommit,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          if (printEnabled) _handlePrintCertificate();
        },
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () {
          ref.read(schoolLeavingProvider.notifier).setTodayDate();
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
              // ── a) Title Block (~44px) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.go(backTarget ?? '/students'),
                          icon: const Icon(Icons.arrow_back, size: 14),
                          label: Text(backLabel),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(
                              color: AppColors.borderDefault,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'School Leaving',
                                style: AppTypography.h2.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Student withdrawal clearance and School Leaving Certificate (SLC)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (student != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: state.hasExistingSlc
                            ? AppColors.statusInfoBg
                            : (state.hasDues
                                  ? AppColors.statusErrorBg
                                  : AppColors.statusSuccessBg),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: state.hasExistingSlc
                              ? AppColors.statusInfoBorder
                              : (state.hasDues
                                    ? AppColors.statusErrorBorder
                                    : AppColors.statusSuccessBorder),
                        ),
                      ),
                      child: Text(
                        state.hasExistingSlc
                            ? 'SLC Issued'
                            : (state.hasDues
                                  ? 'Arrears Blocked'
                                  : 'Clearance Ready'),
                        style: AppTypography.bodySmall.copyWith(
                          color: state.hasExistingSlc
                              ? AppColors.statusInfoText
                              : (state.hasDues
                                    ? AppColors.statusErrorText
                                    : AppColors.statusSuccessText),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── b) Two-Column Split (5:7 ratio) ──
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT CARD: STUDENT CLEARANCE DOSSIER (Flex 5)
                    Expanded(
                      flex: 5,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Strip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.borderDefault,
                                  ),
                                ),
                              ),
                              child: Text(
                                'STUDENT CLEARANCE DOSSIER',
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Student Selector
                                    InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Student',
                                        hintText: 'Search by Reg ID or name',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        border: OutlineInputBorder(),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value:
                                              (student != null &&
                                                  state.students.any(
                                                    (s) =>
                                                        s.stuRegId ==
                                                        student.stuRegId,
                                                  ))
                                              ? student.stuRegId
                                              : null,
                                          isDense: true,
                                          isExpanded: true,
                                          menuMaxHeight: 400,
                                          hint: const Text(
                                            'Search by Reg ID or name',
                                          ),
                                          items: state.students.map((s) {
                                            return DropdownMenuItem<int>(
                                              value: s.stuRegId,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${s.stuRegId} - ${s.studentName}',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (s.hasExistingSlc)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .statusInfoBg,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppRadius.sm,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'SLC Issued',
                                                        style: AppTypography
                                                            .bodySmall
                                                            .copyWith(
                                                              fontSize: 10,
                                                              color: AppColors
                                                                  .statusInfoText,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            ref
                                                .read(
                                                  schoolLeavingProvider
                                                      .notifier,
                                                )
                                                .selectStudent(val);
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),

                                    // Identity Card (when selected)
                                    if (student != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.md,
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
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Avatar 64x64
                                            Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                color: AppColors.brandPrimary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.md,
                                                    ),
                                                border: Border.all(
                                                  color:
                                                      AppColors.borderDefault,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                student.nameFirst.isNotEmpty
                                                    ? student.nameFirst[0]
                                                          .toUpperCase()
                                                    : 'S',
                                                style: AppTypography.h2
                                                    .copyWith(
                                                      color: AppColors
                                                          .brandPrimary,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.md,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student.studentName,
                                                    style: AppTypography.h3
                                                        .copyWith(
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Father: ${student.fatherName ?? '-'}',
                                                    style: AppTypography
                                                        .bodySmall
                                                        .copyWith(
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Class: ${student.classSecDisplay}',
                                                    style: AppTypography
                                                        .bodySmall
                                                        .copyWith(
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Admitted: ${student.admissionDate ?? '-'}',
                                                    style: AppTypography
                                                        .bodySmall
                                                        .copyWith(
                                                          color: AppColors
                                                              .textMuted,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),

                                      // Financial Arrears Gate Card
                                      _buildArrearsGateCard(state),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.md),

                    // RIGHT CARD: WITHDRAWAL DETAILS & CERTIFICATE (Flex 7)
                    Expanded(
                      flex: 7,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Strip with 4px brand primary accent
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.borderDefault,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandPrimary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'WITHDRAWAL DETAILS & CERTIFICATE',
                                    style: AppTypography.label.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: student == null
                                  ? _buildEmptyState()
                                  : SingleChildScrollView(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildStatusBanner(state),
                                          const SizedBox(height: AppSpacing.md),
                                          _buildWithdrawalForm(state),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── c) Pinned Action Bar (~52px) ──
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _handlePrintRegister,
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Print SLC Register'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: printEnabled
                            ? _handlePrintCertificate
                            : null,
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: Text(
                          state.hasExistingSlc
                              ? 'Reprint Leaving Certificate'
                              : 'Print Leaving Certificate',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton.icon(
                        onPressed: commitDisabled ? null : _handleCommit,
                        icon: const Icon(Icons.exit_to_app, size: 16),
                        label: const Text('Commit School Leaving'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusErrorText,
                          foregroundColor: AppColors.textOnPrimary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_search_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Select Student First',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a student to view clearance status and record a withdrawal.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildArrearsGateCard(SchoolLeavingState state) {
    final dues = state.outstandingDues;
    final months = state.overdueMonths;
    final isBlocked = dues > 0;

    if (isBlocked) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.statusErrorBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.statusErrorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OUTSTANDING DUES BALANCE',
                  style: AppTypography.label.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusErrorText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusErrorText,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'BLOCKED',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Rs. ${dues.toStringAsFixed(0)}',
              style: AppTypography.h2.copyWith(
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Student has out standing dues Rs. ${dues.toStringAsFixed(0)} for $months Months. Must pay before left',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusErrorText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Status: BLOCKED',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final stuId = state.selectedStudent?.stuRegId;
                      final fromParam = () {
                        try {
                          return GoRouterState.of(context)
                              .uri
                              .queryParameters['from'];
                        } catch (_) {
                          return null;
                        }
                      }();
                      final returnToLeavingUrl =
                          '/students/leaving?studentId=$stuId'
                          '${fromParam != null && fromParam.isNotEmpty ? '&from=${Uri.encodeComponent(fromParam)}' : ''}';
                      context.go(
                        '/fees/receipts?studentId=$stuId'
                        '&from=${Uri.encodeComponent(returnToLeavingUrl)}',
                      );
                    },
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('Pay Arrears Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusErrorText,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(schoolLeavingProvider.notifier)
                        .refreshSelectedStudent();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh Status'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusErrorText,
                    side: const BorderSide(color: AppColors.statusErrorBorder),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusSuccessBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.statusSuccessBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'OUTSTANDING DUES BALANCE',
            style: AppTypography.label.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.statusSuccessText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs. 0.00',
            style: AppTypography.h3.copyWith(
              color: AppColors.statusSuccessText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Financial Clearance Verified',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.statusSuccessText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(SchoolLeavingState state) {
    if (state.committedSlc != null) {
      final dateStr = state.committedSlc!['LeftDate'] ?? '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.statusSuccessBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.statusSuccessBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 16,
              color: AppColors.statusSuccessText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'School leaving committed on $dateStr. Certificate is ready to print.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.statusSuccessText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state.hasExistingSlc) {
      final leftDate = state.selectedStudent?.existingSlcDate ?? '-';
      final term = state.selectedStudent?.existingSlcTerm ?? '-';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.statusInfoBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.statusInfoBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.statusInfoText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'A School Leaving record already exists for this student (left $leftDate, $term). Fields are read-only.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.statusInfoText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state.hasDues) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.statusWarningBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.statusWarningBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline,
              size: 16,
              color: AppColors.statusWarningText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Withdrawal details are locked until all arrears are paid.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.statusWarningText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.statusSuccessBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.statusSuccessBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 16,
            color: AppColors.statusSuccessText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Financial clearance verified. Ready to record withdrawal.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusSuccessText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalForm(SchoolLeavingState state) {
    final enabled = state.isFormEditable;

    return Tooltip(
      message: !enabled && state.hasDues
          ? 'Pay arrears first to enable withdrawal details'
          : '',
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Effective Leaving Date + Today button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: enabled ? _selectLeavingDate : null,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Effective Leaving Date',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(
                          DateFormat('dd-MMM-yyyy').format(state.leavingDate),
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: enabled
                        ? () => ref
                              .read(schoolLeavingProvider.notifier)
                              .setTodayDate()
                        : null,
                    icon: const Icon(Icons.today, size: 16),
                    label: const Text('Today'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(90, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Row 2: Reason for Leaving
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason for Leaving',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildRadioOption<String>(
                        value: 'Leaving',
                        groupValue: state.reason,
                        label: 'Leaving',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setReason(val),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildRadioOption<String>(
                        value: 'Completed Studies',
                        groupValue: state.reason,
                        label: 'Completed Studies',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setReason(val),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildRadioOption<String>(
                        value: 'Dismissed',
                        groupValue: state.reason,
                        label: 'Dismissed',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setReason(val),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Row 3: Character & Conduct
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Character & Conduct',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildRadioOption<String>(
                        value: 'Good ',
                        groupValue: state.conduct,
                        label: 'Good',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setConduct(val),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildRadioOption<String>(
                        value: 'Satisfactory',
                        groupValue: state.conduct,
                        label: 'Satisfactory',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setConduct(val),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildRadioOption<String>(
                        value: 'Bad',
                        groupValue: state.conduct,
                        label: 'Bad',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setConduct(val),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Row 4: Administrative Remarks
              TextField(
                controller: _remarksController,
                enabled: enabled,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Administrative Remarks',
                  hintText: 'Enter any remarks for the certificate (optional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
                style: AppTypography.bodySmall,
                onChanged: (val) =>
                    ref.read(schoolLeavingProvider.notifier).setRemarks(val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioOption<T>({
    required T value,
    required T? groupValue,
    required String label,
    required ValueChanged<T?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<T>(
            value: value,
            // ignore: deprecated_member_use
            groupValue: groupValue,
            // ignore: deprecated_member_use
            onChanged: onChanged,
            activeColor: AppColors.brandPrimary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(
    SchoolLeavingState state,
    LeavingStudentRow? student,
    bool printEnabled,
    bool commitDisabled,
    String? backTarget,
    String backLabel,
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
                    _buildMobileHeader(state, student, backTarget, backLabel),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileKpiRow(state, student),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileStudentSelectorCard(state, student),
                    const SizedBox(height: AppSpacing.sm),
                    if (student != null) ...[
                      _buildMobileStudentIdentityCard(student),
                      const SizedBox(height: AppSpacing.sm),
                      _buildMobileArrearsGateCard(state),
                      const SizedBox(height: AppSpacing.sm),
                      _buildStatusBanner(state),
                      const SizedBox(height: AppSpacing.sm),
                      _buildMobileWithdrawalForm(state),
                      const SizedBox(height: AppSpacing.sm),
                    ] else ...[
                      _buildEmptyState(),
                    ],
                  ],
                ),
              ),
            ),
            _buildMobileStickyActions(state, printEnabled, commitDisabled),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    SchoolLeavingState state,
    LeavingStudentRow? student,
    String? backTarget,
    String backLabel,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (backTarget != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => context.go(backTarget),
                  tooltip: backLabel,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Leaving',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Withdrawal clearance and Leaving Certificate',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
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
        if (student != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: state.hasExistingSlc
                  ? AppColors.statusInfoBg
                  : (state.hasDues
                      ? AppColors.statusErrorBg
                      : AppColors.statusSuccessBg),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: state.hasExistingSlc
                    ? AppColors.statusInfoBorder
                    : (state.hasDues
                        ? AppColors.statusErrorBorder
                        : AppColors.statusSuccessBorder),
              ),
            ),
            child: Text(
              state.hasExistingSlc
                  ? 'SLC Issued'
                  : (state.hasDues ? 'Blocked' : 'Cleared'),
              style: AppTypography.bodySmall.copyWith(
                color: state.hasExistingSlc
                    ? AppColors.statusInfoText
                    : (state.hasDues
                        ? AppColors.statusErrorText
                        : AppColors.statusSuccessText),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileKpiRow(
    SchoolLeavingState state,
    LeavingStudentRow? student,
  ) {
    return Row(
      children: [
        Expanded(
          child: MobileKpiCard(
            label: 'ISSUED CERTIFICATES',
            value: '${state.students.where((s) => s.hasSLC).length}',
            icon: Icons.history_edu,
            accentColor: AppColors.accentStudents,
            accentSoftBg: AppColors.accentStudentsSoftBg,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MobileKpiCard(
            label: 'CLEARANCE STATUS',
            value: student != null
                ? (state.hasDues ? 'Arrears' : 'Cleared')
                : 'No Student',
            icon: Icons.verified_user_outlined,
            accentColor: state.hasDues
                ? AppColors.statusErrorText
                : AppColors.chartTeal,
            accentSoftBg: state.hasDues
                ? AppColors.statusErrorBg
                : AppColors.chartTeal.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileStudentSelectorCard(
    SchoolLeavingState state,
    LeavingStudentRow? student,
  ) {
    return Container(
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
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.accentStudents,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'STUDENT CLEARANCE DOSSIER',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MobileDropdownField<int>(
            label: 'Student',
            value: (student != null &&
                    state.students.any((s) => s.stuRegId == student.stuRegId))
                ? student.stuRegId
                : null,
            hintText: 'Search by Reg ID or name',
            items: state.students.map((s) {
              return DropdownMenuItem<int>(
                value: s.stuRegId,
                child: Text(
                  '${s.stuRegId} - ${s.studentName}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              ref.read(schoolLeavingProvider.notifier).selectStudent(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStudentIdentityCard(LeavingStudentRow student) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            alignment: Alignment.center,
            child: Text(
              student.nameFirst.isNotEmpty
                  ? student.nameFirst[0].toUpperCase()
                  : 'S',
              style: AppTypography.h3.copyWith(color: AppColors.brandPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.studentName,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Father: ${student.fatherName ?? '-'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Class: ${student.classSecDisplay}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Admitted: ${student.admissionDate ?? '-'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileArrearsGateCard(SchoolLeavingState state) {
    final dues = state.outstandingDues;
    final isBlocked = dues > 0;

    if (isBlocked) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.statusErrorBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.statusErrorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'OUTSTANDING DUES BALANCE',
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusErrorText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusErrorText,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'BLOCKED',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Rs. ${dues.toStringAsFixed(0)}',
              style: AppTypography.h3.copyWith(
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Status: BLOCKED',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                final stuId = state.selectedStudent?.stuRegId;
                final fromParam = () {
                  try {
                    return GoRouterState.of(context)
                        .uri
                        .queryParameters['from'];
                  } catch (_) {
                    return null;
                  }
                }();
                final returnToLeavingUrl =
                    '/students/leaving?studentId=$stuId'
                    '${fromParam != null && fromParam.isNotEmpty ? '&from=${Uri.encodeComponent(fromParam)}' : ''}';
                context.go(
                  '/fees/receipts?studentId=$stuId'
                  '&from=${Uri.encodeComponent(returnToLeavingUrl)}',
                );
              },
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('Pay Arrears Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: () {
                ref
                    .read(schoolLeavingProvider.notifier)
                    .refreshSelectedStudent();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusErrorText,
                side: const BorderSide(color: AppColors.statusErrorBorder),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildArrearsGateCard(state);
  }

  Widget _buildMobileWithdrawalForm(SchoolLeavingState state) {
    final enabled = state.isFormEditable;

    return Container(
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
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WITHDRAWAL DETAILS',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Effective Leaving Date + Today
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: enabled ? _selectLeavingDate : null,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Effective Leaving Date',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                              suffixIcon:
                                  Icon(Icons.calendar_today, size: 16),
                            ),
                            child: Text(
                              DateFormat('dd-MMM-yyyy')
                                  .format(state.leavingDate),
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: enabled
                            ? () => ref
                                .read(schoolLeavingProvider.notifier)
                                .setTodayDate()
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(60, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: const Text('Today'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Reason for Leaving
                  Text(
                    'Reason for Leaving',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    children: [
                      _buildRadioOption<String>(
                        value: 'Leaving',
                        groupValue: state.reason,
                        label: 'Leaving',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setReason(val),
                      ),
                      _buildRadioOption<String>(
                        value: 'Completed Studies',
                        groupValue: state.reason,
                        label: 'Completed Studies',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setReason(val),
                      ),
                      _buildRadioOption<String>(
                        value: 'Dismissed',
                        groupValue: state.reason,
                        label: 'Dismissed',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setReason(val),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Character & Conduct
                  Text(
                    'Character & Conduct',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    children: [
                      _buildRadioOption<String>(
                        value: 'Good ',
                        groupValue: state.conduct,
                        label: 'Good',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setConduct(val),
                      ),
                      _buildRadioOption<String>(
                        value: 'Satisfactory',
                        groupValue: state.conduct,
                        label: 'Satisfactory',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setConduct(val),
                      ),
                      _buildRadioOption<String>(
                        value: 'Bad',
                        groupValue: state.conduct,
                        label: 'Bad',
                        onChanged: (val) => ref
                            .read(schoolLeavingProvider.notifier)
                            .setConduct(val),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Remarks
                  TextField(
                    controller: _remarksController,
                    enabled: enabled,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Administrative Remarks',
                      hintText: 'Enter any remarks for the certificate',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10),
                    ),
                    style: AppTypography.bodySmall,
                    onChanged: (val) => ref
                        .read(schoolLeavingProvider.notifier)
                        .setRemarks(val),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStickyActions(
    SchoolLeavingState state,
    bool printEnabled,
    bool commitDisabled,
  ) {
    final student = state.selectedStudent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handlePrintRegister,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('SLC Register'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: printEnabled ? _handlePrintCertificate : null,
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: Text(
                    state.hasExistingSlc ? 'Reprint SLC' : 'Print SLC',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (student != null && !commitDisabled) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: commitDisabled ? null : _handleCommit,
                icon: const Icon(Icons.exit_to_app, size: 16),
                label: const Text('Commit School Leaving'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusErrorText,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on LeavingStudentRow {
  String? get dob => null;
}
