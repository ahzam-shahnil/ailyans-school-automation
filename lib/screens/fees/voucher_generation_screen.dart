import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/student_list_provider.dart';
import '../../core/providers/voucher_generation_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../models/voucher_preview_row.dart';

/// Production VoucherGenerationScreen hosted within AppShell.
/// Matches locked designs:
/// - fees-vouchers-v1-configuration.png
/// - fees-vouchers-v1-batch-progress.png
/// - fees-vouchers-v1-batch-complete.png
class VoucherGenerationScreen extends ConsumerStatefulWidget {
  const VoucherGenerationScreen({super.key});

  @override
  ConsumerState<VoucherGenerationScreen> createState() =>
      _VoucherGenerationScreenState();
}

class _VoucherGenerationScreenState
    extends ConsumerState<VoucherGenerationScreen> {
  final currencyFormat = NumberFormat('#,##0');
  final dateFormat = DateFormat('dd-MMM-yyyy');
  late final TextEditingController _lateFineController;

  @override
  void initState() {
    super.initState();
    _lateFineController = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _lateFineController.dispose();
    super.dispose();
  }

  void _onGenerate() {
    final execState = ref.read(voucherGenExecutionProvider);
    if (execState.isGenerating) return;

    ref.read(voucherGenExecutionProvider.notifier).generateVouchers();
  }

  void _onEscape() {
    final execState = ref.read(voucherGenExecutionProvider);
    if (execState.completionSummary != null) {
      ref.read(voucherGenExecutionProvider.notifier).clearSummary();
    }
  }

  Future<void> _pickBillingMonth(BuildContext context) async {
    final filters = ref.read(voucherGenFiltersProvider);
    final parts = filters.billingMonth.trim().split(RegExp(r'\s+'));
    int selectedYear = 2017;
    int selectedMonth = 10;
    if (parts.length >= 2) {
      selectedYear = int.tryParse(parts[1]) ?? 2017;
      const monthMap = {
        'january': 1,
        'february': 2,
        'march': 3,
        'april': 4,
        'may': 5,
        'june': 6,
        'july': 7,
        'august': 8,
        'september': 9,
        'october': 10,
        'november': 11,
        'december': 12,
      };
      selectedMonth = monthMap[parts[0].toLowerCase()] ?? 10;
    }

    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        int tempYear = selectedYear;
        int tempMonth = selectedMonth;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: const BorderSide(color: AppColors.borderDefault),
              ),
              title: Text(
                'Select Billing Month',
                style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setDialogState(() => tempYear--);
                          },
                        ),
                        Text(
                          '$tempYear',
                          style: AppTypography.h3.copyWith(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setDialogState(() => tempYear++);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: List.generate(12, (index) {
                        final mNum = index + 1;
                        final isSel = (tempMonth == mNum);
                        return ChoiceChip(
                          label: Text(monthNames[index].substring(0, 3)),
                          selected: isSel,
                          selectedColor: AppColors.brandPrimary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => tempMonth = mNum);
                            }
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                  ),
                  onPressed: () {
                    final newMonthStr =
                        '${monthNames[tempMonth - 1]} $tempYear';
                    ref
                        .read(voucherGenFiltersProvider.notifier)
                        .setBillingMonth(newMonthStr);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime initialDate,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(voucherGenFiltersProvider);
    final previewAsync = ref.watch(voucherGenPreviewProvider);
    final execState = ref.watch(voucherGenExecutionProvider);

    final previewList = previewAsync.valueOrNull ?? [];
    final eligibleCount = previewList.length;
    final readyCount = previewList
        .where((r) => r.status != VoucherPreviewStatus.alreadyGenerated)
        .length;
    final waiverCount = previewList
        .where((r) => r.status == VoucherPreviewStatus.fullWaiver)
        .length;
    final totalEstimatedNet = previewList
        .where((r) => r.status != VoucherPreviewStatus.alreadyGenerated)
        .fold<int>(0, (sum, r) => sum + r.netPayable);

    // Error feedback
    ref.listen<VoucherGenState>(voucherGenExecutionProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.statusErrorText,
          ),
        );
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyG, control: true):
            _onGenerate,
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true): _onGenerate,
        const SingleActivator(LogicalKeyboardKey.escape): _onEscape,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Bar / Breadcrumb
                  _buildHeader(eligibleCount),
                  const SizedBox(height: AppSpacing.lg),

                  // Optional top progress banner if generating
                  if (execState.isGenerating) ...[
                    _buildGeneratingBanner(execState),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 2. Main Workspace: Row split 40 / 60
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left 40% Card: Parameters
                        Expanded(
                          flex: 4,
                          child: _buildConfigurationCard(
                            context,
                            filters,
                            readyCount,
                            execState.isGenerating,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),

                        // Right 60% Card: Preview Table
                        Expanded(
                          flex: 6,
                          child: _buildPreviewCard(
                            previewAsync,
                            previewList,
                            eligibleCount,
                            waiverCount,
                            totalEstimatedNet,
                            readyCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Batch Complete Dialog Modal
              if (execState.completionSummary != null)
                _buildBatchCompleteDialog(
                  context,
                  execState.completionSummary!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top page header with breadcrumb, title, count badge, and mode switcher.
  Widget _buildHeader(int eligibleCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Home  >  Fees  >  Monthly Voucher Generation',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Monthly Voucher Generation Engine',
                      style: AppTypography.h1.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Text(
                      '$eligibleCount Eligible Students',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Mode Switcher (Single Student mode disabled per spec)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'batch',
                  label: Text('Batch Generation (Cohort)'),
                  icon: Icon(Icons.dynamic_feed_outlined, size: 16),
                ),
                ButtonSegment<String>(
                  value: 'single',
                  label: Tooltip(
                    message: 'Phase 2',
                    child: Text(
                      'Single Student Voucher',
                      style: TextStyle(color: AppColors.textDisabled),
                    ),
                  ),
                  enabled: false,
                  icon: Icon(Icons.person_outline, size: 16),
                ),
              ],
              selected: const {'batch'},
              onSelectionChanged: (_) {},
            ),
          ],
        ),
      ],
    );
  }

  /// Alert banner displayed at the top while batch generation is running.
  Widget _buildGeneratingBanner(VoucherGenState execState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.statusErrorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.statusErrorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, color: AppColors.statusErrorText, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Voucher Generation in Progress: Generating vouchers for the selected cohort. '
              'Please do not navigate away or close the application until the process finishes.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Left Card: Batch Generation Parameters configuration form.
  Widget _buildConfigurationCard(
    BuildContext context,
    VoucherGenFilters filters,
    int readyCount,
    bool isGenerating,
  ) {
    final classesAsync = ref.watch(classesProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final bankListAsync = ref.watch(voucherBankListProvider);
    final tariffsAsync = ref.watch(
      voucherClassTariffsProvider(filters.classId),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batch Generation Parameters',
              style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              'Configure cohort tariffs and billing schedule',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Row 1: Session Year + Billing Month (paired)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Session Year *'),
                      const SizedBox(height: AppSpacing.xxs),
                      DropdownButtonFormField<String>(
                        key: ValueKey(filters.sessionYr),
                        initialValue: filters.sessionYr,
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(
                            value: '2017-2018',
                            child: Text('2017-2018'),
                          ),
                          DropdownMenuItem(
                            value: '2016-2017',
                            child: Text('2016-2017'),
                          ),
                          DropdownMenuItem(
                            value: '2018-2019',
                            child: Text('2018-2019'),
                          ),
                        ],
                        onChanged: isGenerating
                            ? null
                            : (val) {
                                if (val != null) {
                                  ref
                                      .read(voucherGenFiltersProvider.notifier)
                                      .setSessionYr(val);
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Billing Month *'),
                      const SizedBox(height: AppSpacing.xxs),
                      InkWell(
                        onTap: isGenerating
                            ? null
                            : () => _pickBillingMonth(context),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: InputDecorator(
                          decoration: _inputDecoration(
                            prefixIcon: const Icon(
                              Icons.calendar_today,
                              size: 18,
                            ),
                          ),
                          child: Text(
                            filters.billingMonth,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Row 2: Target Class + Target Section (paired)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Target Class *'),
                      const SizedBox(height: AppSpacing.xxs),
                      classesAsync.when(
                        data: (classes) {
                          return DropdownButtonFormField<int?>(
                            key: ValueKey(filters.classId),
                            initialValue: filters.classId,
                            isExpanded: true,
                            decoration: _inputDecoration(),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Classes'),
                              ),
                              ...classes.map((c) {
                                return DropdownMenuItem<int?>(
                                  value: c.classId,
                                  child: Text(c.cName),
                                );
                              }),
                            ],
                            onChanged: isGenerating
                                ? null
                                : (val) {
                                    ref
                                        .read(
                                          voucherGenFiltersProvider.notifier,
                                        )
                                        .setClassId(val);
                                  },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading classes'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Target Section'),
                      const SizedBox(height: AppSpacing.xxs),
                      sectionsAsync.when(
                        data: (sections) {
                          final filtered = (filters.classId == null)
                              ? sections
                              : sections
                                    .where((s) => s.classId == filters.classId)
                                    .toList();
                          return DropdownButtonFormField<int?>(
                            key: ValueKey(filters.classSecId),
                            initialValue: filters.classSecId,
                            isExpanded: true,
                            decoration: _inputDecoration(),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Sections'),
                              ),
                              ...filtered.map((s) {
                                return DropdownMenuItem<int?>(
                                  value: s.classSecId,
                                  child: Text('Section ${s.secName}'),
                                );
                              }),
                            ],
                            onChanged: isGenerating
                                ? null
                                : (val) {
                                    ref
                                        .read(
                                          voucherGenFiltersProvider.notifier,
                                        )
                                        .setClassSecId(val);
                                  },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading sections'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Row 3: Issue Date + Due Date (paired)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Issue Date *'),
                      const SizedBox(height: AppSpacing.xxs),
                      InkWell(
                        onTap: isGenerating
                            ? null
                            : () => _pickDate(
                                context,
                                filters.issueDate,
                                (d) => ref
                                    .read(voucherGenFiltersProvider.notifier)
                                    .setIssueDate(d),
                              ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: InputDecorator(
                          decoration: _inputDecoration(
                            suffixIcon: const Icon(
                              Icons.calendar_month,
                              size: 16,
                            ),
                          ),
                          child: Text(
                            dateFormat.format(filters.issueDate),
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Payment Due Date *'),
                      const SizedBox(height: AppSpacing.xxs),
                      InkWell(
                        onTap: isGenerating
                            ? null
                            : () => _pickDate(
                                context,
                                filters.dueDate,
                                (d) => ref
                                    .read(voucherGenFiltersProvider.notifier)
                                    .setDueDate(d),
                              ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: InputDecorator(
                          decoration: _inputDecoration(
                            suffixIcon: const Icon(
                              Icons.calendar_month,
                              size: 16,
                            ),
                          ),
                          child: Text(
                            dateFormat.format(filters.dueDate),
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Row 4: Bank (flex 3) + Late Fine (flex 2) paired
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Receiving Bank *'),
                      const SizedBox(height: AppSpacing.xxs),
                      bankListAsync.when(
                        data: (banks) {
                          final currentBankId =
                              banks.any((b) => b.bankInfoId == filters.bankId)
                              ? filters.bankId
                              : (banks.isNotEmpty ? banks.first.bankInfoId : 1);
                          return DropdownButtonFormField<int>(
                            key: ValueKey(currentBankId),
                            initialValue: currentBankId,
                            isExpanded: true,
                            decoration: _inputDecoration(
                              prefixIcon: const Icon(
                                Icons.account_balance,
                                size: 18,
                              ),
                            ),
                            items: banks.map((b) {
                              return DropdownMenuItem<int>(
                                value: b.bankInfoId,
                                child: Text(b.displayName),
                              );
                            }).toList(),
                            onChanged: isGenerating
                                ? null
                                : (val) {
                                    if (val != null) {
                                      ref
                                          .read(
                                            voucherGenFiltersProvider.notifier,
                                          )
                                          .setBankId(val);
                                    }
                                  },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading banks'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Late Fine (Rs.)'),
                      const SizedBox(height: AppSpacing.xxs),
                      TextFormField(
                        controller: _lateFineController,
                        decoration: _inputDecoration(prefixText: 'Rs. '),
                        keyboardType: TextInputType.number,
                        enabled: !isGenerating,
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 100;
                          ref
                              .read(voucherGenFiltersProvider.notifier)
                              .setLateFineAmount(parsed);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Row 5: Fee Heads compact (Wrap chips + arrears/full-waiver note)
            _buildFeeHeadsCompact(tariffsAsync, filters),
            const SizedBox(height: AppSpacing.sm),

            // Row 6: Generate CTA — ALWAYS VISIBLE at bottom of card
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                icon: isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.bolt, size: 20),
                label: Text(
                  isGenerating
                      ? 'Generating...'
                      : 'Generate $readyCount Vouchers (Ctrl+G)',
                  style: AppTypography.label.copyWith(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                onPressed: (isGenerating || readyCount == 0)
                    ? null
                    : _onGenerate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Right Card: Preview table and KPI summary strip.
  Widget _buildPreviewCard(
    AsyncValue<List<VoucherPreviewRow>> previewAsync,
    List<VoucherPreviewRow> previewList,
    int eligibleCount,
    int waiverCount,
    int totalEstimatedNet,
    int readyCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cohort Billing Audit & Ledger Preview',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live calculation state prior to permanent database commit',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Re-calculate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    onPressed: () {
                      ref.invalidate(voucherGenPreviewProvider);
                    },
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.filter_list, size: 16),
                    label: const Text('Filter List'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // KPI Strip: 3 Cards
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Eligible Students',
                  value: '$eligibleCount students',
                  icon: Icons.people_outline,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildKpiCard(
                  title: 'Full Tuition Waiver',
                  value: '$waiverCount students',
                  icon: Icons.card_membership_outlined,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildKpiCard(
                  title: 'Estimated Net Billed',
                  value: 'Rs.  ${currencyFormat.format(totalEstimatedNet)}',
                  icon: Icons.payments_outlined,
                  color: AppColors.statusSuccessText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 7-Column Table
          Expanded(
            child: previewAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildTable(rows);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, __) => Center(
                child: Text(
                  'Error loading preview: $err',
                  style: const TextStyle(color: AppColors.statusErrorText),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Footer: Showing X of Y records
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing 1-${previewList.length} of ${previewList.length} eligible records in cohort',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Commit notice banner
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$readyCount vouchers will be created in VoucharMas + VoucharDet. '
                    'This action cannot be undone after commit.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
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

  /// KPI Mini Card.
  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 7-Column Data Table — flex-based columns to prevent overflow.
  Widget _buildTable(List<VoucherPreviewRow> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: [
          // Header Row — all flex, no fixed pixel widths to avoid overflow
          Container(
            color: AppColors.surfaceSubtle,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    'Voucher ID',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Student Name',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SubTotal',
                    textAlign: TextAlign.right,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Arrears',
                    textAlign: TextAlign.right,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Discount',
                    textAlign: TextAlign.right,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Net Payable',
                    textAlign: TextAlign.right,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderDefault),

          // Scrollable Body Rows — itemExtent keeps each row at 36px
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemExtent: 36,
              itemBuilder: (context, index) => _buildPreviewRow(rows[index]),
            ),
          ),
        ],
      ),
    );
  }

  /// Single data row in the preview table.
  Widget _buildPreviewRow(VoucherPreviewRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      child: Row(
        children: [
          // Voucher ID: fixed 88px, NO leading #
          SizedBox(
            width: 88,
            child: Text(
              row.voucherId,
              style: AppTypography.monospace.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Student Name: expands to fill available width
          Expanded(
            flex: 3,
            child: Text(
              row.studentName,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // SubTotal
          Expanded(
            flex: 2,
            child: Text(
              'Rs.\u00a0${currencyFormat.format(row.subtotal)}',
              textAlign: TextAlign.right,
              style: AppTypography.monospace.copyWith(
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Arrears
          Expanded(
            flex: 2,
            child: Text(
              'Rs.\u00a0${currencyFormat.format(row.arrears)}',
              textAlign: TextAlign.right,
              style: AppTypography.monospace.copyWith(
                color: row.arrears > 0
                    ? AppColors.statusWarningText
                    : AppColors.textMuted,
                fontWeight: row.arrears > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Discount
          Expanded(
            flex: 2,
            child: Text(
              'Rs.\u00a0${currencyFormat.format(row.discount)}',
              textAlign: TextAlign.right,
              style: AppTypography.monospace.copyWith(
                color: row.discount > 0
                    ? AppColors.statusInfoText
                    : AppColors.textMuted,
                fontWeight: row.discount > 0
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Net Payable
          Expanded(
            flex: 2,
            child: Text(
              'Rs.\u00a0${currencyFormat.format(row.netPayable)}',
              textAlign: TextAlign.right,
              style: AppTypography.monospace.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Status Badge: fixed 100px centred
          SizedBox(
            width: 100,
            child: Center(child: _buildStatusBadge(row.status)),
          ),
        ],
      ),
    );
  }

  /// Compact fee heads container using Wrap chips + info note.
  Widget _buildFeeHeadsCompact(
    AsyncValue<List<FeeHeadSummary>> tariffsAsync,
    VoucherGenFilters filters,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fee Heads Included in Cohort',
            style: AppTypography.label.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          tariffsAsync.when(
            data: (tariffs) {
              if (tariffs.isEmpty) {
                return Text(
                  'No Fee defined for Class ID Code ${filters.classId}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.statusErrorText,
                  ),
                );
              }
              return Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tariffs.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Text(
                      '${t.description.trim()} (#${t.feeParamId}): Rs. ${t.fee.toInt()}',
                      style: AppTypography.monospace.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error loading fee heads'),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Unpaid arrears auto-roll-over into Head #4. Full-waiver students generate Rs. 0 net vouchers.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Status badge widget.
  Widget _buildStatusBadge(VoucherPreviewStatus status) {
    switch (status) {
      case VoucherPreviewStatus.ready:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Text(
            'Ready',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        );
      case VoucherPreviewStatus.fullWaiver:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.statusInfoBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.statusInfoBorder),
          ),
          child: Text(
            '100% Full Waiver',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.statusInfoText,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        );
      case VoucherPreviewStatus.arrearsRollover:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.statusWarningBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.statusWarningBorder),
          ),
          child: Text(
            'Arrears Rolled Over',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.statusWarningText,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        );
      case VoucherPreviewStatus.alreadyGenerated:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Text(
            'Already Generated',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
              fontSize: 11,
            ),
          ),
        );
    }
  }

  /// Empty state illustration when 0 candidates match.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.school_outlined,
            size: 48,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No eligible students for this cohort',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Try selecting a different academic class, section, or session year.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Modal Dialog displayed upon batch completion (fees-vouchers-v1-batch-complete.png).
  Widget _buildBatchCompleteDialog(
    BuildContext context,
    BatchGenerationSummary summary,
  ) {
    return Container(
      color: Colors.black45,
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 500,
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.borderDefault),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusSuccessBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.statusSuccessBorder),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.statusSuccessText,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batch Generation Complete',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Batch complete',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Stat pills
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusSuccessBg,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.statusSuccessBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.statusSuccessText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${summary.generatedCount} Vouchers Generated',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.statusSuccessText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Text(
                      '${summary.skippedCount} Skipped (already exists)',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'All master records (VoucharMas) and fee details (VoucharDet) have been '
                'successfully committed to database.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Financial Breakdown Box
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Total Billed:',
                      'Rs.  ${currencyFormat.format(summary.totalBilled)}',
                      bold: true,
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Arrears Rolled Over:',
                      'Rs.  ${currencyFormat.format(summary.arrearsRolledOver)}',
                      color: AppColors.statusWarningText,
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Concessions Applied:',
                      'Rs.  ${currencyFormat.format(summary.concessionsApplied)}',
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ),

              if (summary.skippedReasons.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          summary.skippedReasons.first,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: Text(
                      'Print Batch Vouchers (${summary.generatedCount})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    onPressed: () {},
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                    ),
                    onPressed: _onEscape,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.monospace.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      filled: true,
      fillColor: AppColors.surfaceRaised,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
    );
  }
}
