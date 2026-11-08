import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme_tokens.dart';

/// Card hosting all parameter selection fields for cohort voucher generation.
class VoucherParameterCard extends StatelessWidget {
  const VoucherParameterCard({
    required this.sessionYear,
    required this.sessionYears,
    required this.sessionYearError,
    required this.billingMonth,
    required this.billingMonths,
    required this.billingMonthError,
    required this.classId,
    required this.classes,
    required this.classError,
    required this.sectionId,
    required this.sections,
    required this.issueDate,
    required this.issueDateError,
    required this.dueDate,
    required this.dueDateError,
    required this.bankId,
    required this.banks,
    required this.bankError,
    required this.columnCount,
    required this.onSessionYearChanged,
    required this.onBillingMonthChanged,
    required this.onClassChanged,
    required this.onSectionChanged,
    required this.onIssueDateChanged,
    required this.onDueDateChanged,
    required this.onBankChanged,
    required this.onPickIssueDate,
    required this.onPickDueDate,
    super.key,
  });

  final String sessionYear;
  final List<String> sessionYears;
  final String? sessionYearError;

  final String billingMonth;
  final List<String> billingMonths;
  final String? billingMonthError;

  final int? classId;
  final List<({int id, String label})> classes;
  final String? classError;

  final int? sectionId;
  final List<({int id, String label})> sections;

  final DateTime issueDate;
  final String? issueDateError;

  final DateTime dueDate;
  final String? dueDateError;

  final int? bankId;
  final List<({int id, String label})> banks;
  final String? bankError;

  final int columnCount;

  final ValueChanged<String> onSessionYearChanged;
  final ValueChanged<String> onBillingMonthChanged;
  final ValueChanged<int?> onClassChanged;
  final ValueChanged<int?> onSectionChanged;
  final ValueChanged<DateTime> onIssueDateChanged;
  final ValueChanged<DateTime> onDueDateChanged;
  final ValueChanged<int?> onBankChanged;
  final VoidCallback onPickIssueDate;
  final VoidCallback onPickDueDate;

  Widget _buildFieldLabel(String labelText, {bool isRequired = false, bool isOptional = false}) {
    return Semantics(
      label: isRequired ? '$labelText required' : labelText,
      child: Text.rich(
        TextSpan(
          text: labelText,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AppColors.statusErrorText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isOptional)
              const TextSpan(
                text: ' (optional)',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      height: 44,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _buildErrorText(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        error,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.statusErrorText,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSessionYearField() {
    final itemStyle = AppTypography.body.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );
    final effectiveValue = sessionYears.contains(sessionYear) ? sessionYear : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Session Year', isRequired: true),
        const SizedBox(height: 4),
        _buildDropdownContainer(
          child: DropdownButton<String>(
            value: effectiveValue,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 360,
            dropdownColor: AppColors.surfaceRaised,
            iconEnabledColor: AppColors.textPrimary,
            style: itemStyle,
            hint: Text(
              'Select a session year',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selectedItemBuilder: (context) => sessionYears
                .map(
                  (y) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      y,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            items: sessionYears
                .map(
                  (y) => DropdownMenuItem(
                    value: y,
                    child: Text(
                      y,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) onSessionYearChanged(val);
            },
          ),
        ),
        _buildErrorText(sessionYearError),
      ],
    );
  }

  Widget _buildBillingMonthField() {
    final itemStyle = AppTypography.body.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );
    final effectiveValue = billingMonths.contains(billingMonth) ? billingMonth : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Billing Month', isRequired: true),
        const SizedBox(height: 4),
        _buildDropdownContainer(
          child: DropdownButton<String>(
            value: effectiveValue,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 360,
            dropdownColor: AppColors.surfaceRaised,
            iconEnabledColor: AppColors.textPrimary,
            style: itemStyle,
            hint: Text(
              'Select a billing month',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selectedItemBuilder: (context) => billingMonths
                .map(
                  (m) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      m,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            items: billingMonths
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      m,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) onBillingMonthChanged(val);
            },
          ),
        ),
        _buildErrorText(billingMonthError),
      ],
    );
  }

  Widget _buildClassField() {
    final itemStyle = AppTypography.body.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );
    final effectiveValue = classes.any((c) => c.id == classId) ? classId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Target Class', isRequired: true),
        const SizedBox(height: 4),
        _buildDropdownContainer(
          child: DropdownButton<int?>(
            value: effectiveValue,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 360,
            dropdownColor: AppColors.surfaceRaised,
            iconEnabledColor: AppColors.textPrimary,
            style: itemStyle,
            hint: Text(
              'Select a class to continue',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selectedItemBuilder: (context) => classes
                .map(
                  (c) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      c.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            items: classes
                .map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(
                      c.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            onChanged: onClassChanged,
          ),
        ),
        _buildErrorText(classError),
      ],
    );
  }

  Widget _buildSectionField() {
    final itemStyle = AppTypography.body.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );
    final allItems = [
      (id: null, label: 'All sections'),
      ...sections.map((s) => (id: s.id as int?, label: s.label)),
    ];
    final effectiveValue = allItems.any((s) => s.id == sectionId) ? sectionId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Target Section', isOptional: true),
        const SizedBox(height: 4),
        _buildDropdownContainer(
          child: DropdownButton<int?>(
            value: effectiveValue,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 360,
            dropdownColor: AppColors.surfaceRaised,
            iconEnabledColor: AppColors.textPrimary,
            style: itemStyle,
            selectedItemBuilder: (context) => allItems
                .map(
                  (s) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            items: allItems
                .map(
                  (s) => DropdownMenuItem<int?>(
                    value: s.id,
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            onChanged: onSectionChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String labelText,
    required DateTime date,
    required String? error,
    required VoidCallback onTap,
  }) {
    final dateFormat = DateFormat('dd-MMM-yyyy');
    final formatted = dateFormat.format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel(labelText, isRequired: true),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  formatted,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
        _buildErrorText(error),
      ],
    );
  }

  Widget _buildBankField() {
    final itemStyle = AppTypography.body.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );
    final effectiveValue = banks.any((b) => b.id == bankId) ? bankId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Receiving Bank', isRequired: true),
        const SizedBox(height: 4),
        _buildDropdownContainer(
          child: DropdownButton<int?>(
            value: effectiveValue,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 360,
            dropdownColor: AppColors.surfaceRaised,
            iconEnabledColor: AppColors.textPrimary,
            style: itemStyle,
            hint: Text(
              'Select a receiving bank',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selectedItemBuilder: (context) => banks
                .map(
                  (b) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      b.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            items: banks
                .map(
                  (b) => DropdownMenuItem<int?>(
                    value: b.id,
                    child: Text(
                      b.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: itemStyle,
                    ),
                  ),
                )
                .toList(),
            onChanged: onBankChanged,
          ),
        ),
        _buildErrorText(bankError),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionYearWidget = _buildSessionYearField();
    final billingMonthWidget = _buildBillingMonthField();
    final classWidget = _buildClassField();
    final sectionWidget = _buildSectionField();
    final issueDateWidget = _buildDateField(
      labelText: 'Issue Date',
      date: issueDate,
      error: issueDateError,
      onTap: onPickIssueDate,
    );
    final dueDateWidget = _buildDateField(
      labelText: 'Payment Due Date',
      date: dueDate,
      error: dueDateError,
      onTap: onPickDueDate,
    );
    final bankWidget = _buildBankField();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: columnCount == 2
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sessionYearWidget),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: billingMonthWidget),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: classWidget),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: sectionWidget),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: issueDateWidget),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: dueDateWidget),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                bankWidget,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sessionYearWidget,
                const SizedBox(height: AppSpacing.sm),
                billingMonthWidget,
                const SizedBox(height: AppSpacing.sm),
                classWidget,
                const SizedBox(height: AppSpacing.sm),
                sectionWidget,
                const SizedBox(height: AppSpacing.sm),
                issueDateWidget,
                const SizedBox(height: AppSpacing.sm),
                dueDateWidget,
                const SizedBox(height: AppSpacing.sm),
                bankWidget,
              ],
            ),
    );
  }
}
