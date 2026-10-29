import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/school_leaving_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

class SchoolLeavingScreen extends ConsumerStatefulWidget {
  const SchoolLeavingScreen({super.key});

  @override
  ConsumerState<SchoolLeavingScreen> createState() =>
      _SchoolLeavingScreenState();
}

class _SchoolLeavingScreenState extends ConsumerState<SchoolLeavingScreen> {
  final TextEditingController _remarksController = TextEditingController();

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
    final state = ref.read(schoolLeavingProvider);
    if (!state.hasExistingSlc && state.committedSlc == null) {
      _showSnackBar('No leaving record available to print', isError: true);
      return;
    }
    _showSnackBar('Coming in Phase E');
  }

  void _handlePrintRegister() {
    _showSnackBar('Coming in Phase E');
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Leaving',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Student withdrawal clearance and School Leaving Certificate (SLC)',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
                                          value: student?.stuRegId,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _handlePrintRegister,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print SLC Register'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(150, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: printEnabled ? _handlePrintCertificate : null,
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: Text(
                        state.hasExistingSlc
                            ? 'Reprint Leaving Certificate'
                            : 'Print Leaving Certificate',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(180, 36),
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
                        minimumSize: const Size(190, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
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
            ElevatedButton.icon(
              onPressed: () {
                final stuId = state.selectedStudent?.stuRegId;
                context.go('/fees/receipts?studentId=$stuId&from=leaving');
              },
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('Pay Arrears Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
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
}
