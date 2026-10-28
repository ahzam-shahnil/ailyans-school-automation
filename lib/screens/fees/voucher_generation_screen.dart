import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/providers/voucher_generation_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/fee_head_display.dart';
import '../../core/utils/voucher_pdf_generator.dart';
import '../../models/fee_receipt_view.dart';
import '../../models/voucher_preview_row.dart';
import '../../core/providers/shell_metadata_provider.dart';

/// Production VoucherGenerationScreen hosted within AppShell.
/// Matches locked designs:
/// - fees-vouchers-v1-configuration.png
/// - fees-vouchers-v1-batch-progress.png
/// - fees-vouchers-v1-batch-complete.png
///
/// UI refactor: grouped inputs, pill late-fine control, fee-head chip grid,
/// dashboard KPI strip, zebra table with sticky header + pill status badges.
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

  // Layout constants for the preview table.
  static const double _kIdColWidth = 82;
  static const double _kStatusColWidth = 112;
  static const double _kPrintColWidth = 36;
  static const double _kColGap = 6;
  static const double _kRowHeight = 40;
  static const double _kFieldHeight = 36;

  @override
  void initState() {
    super.initState();
    _lateFineController = TextEditingController(text: '100');
    // Sync sessionYr to the app's active session (from app_config default_session_yr).
    // In production, AppShell pre-loads shellMetadataProvider before any screen mounts,
    // so the value is available immediately. In tests (no DB), the provider isn't
    // loaded — skip the sync rather than triggering a DB query that leaves a timer pending.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final metaAsync = ref.read(shellMetadataProvider);
      if (!metaAsync.hasValue) return; // don't trigger a fresh load in tests
      final meta = metaAsync.valueOrNull;
      if (meta == null) return;
      final current = ref.read(voucherGenFiltersProvider).sessionYr;
      if (current != meta.sessionYear) {
        ref
            .read(voucherGenFiltersProvider.notifier)
            .setSessionYr(meta.sessionYear);
      }
    });
  }

  @override
  void dispose() {
    _lateFineController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOGIC (unchanged)
  // ---------------------------------------------------------------------------

  void _onGenerate() {
    final execState = ref.read(voucherGenExecutionProvider);
    if (execState.isGenerating) return;

    ref.read(voucherGenExecutionProvider.notifier).generateVouchers();
  }

  Future<void> _onRegenerateUnpaid() async {
    final filters = ref.read(voucherGenFiltersProvider);
    final classesAsync = ref.read(classesProvider);
    final classes = classesAsync.valueOrNull ?? [];
    final match = classes
        .where((c) => c.classId == filters.classId)
        .firstOrNull;
    final resolvedClassName = match?.cName ?? 'Class ${filters.classId}';
    final sectionLabel = filters.classSecId == null
        ? 'All Sections'
        : 'Section ${filters.classSecId}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Vouchers'),
        content: Text(
          'Cohort: $resolvedClassName / $sectionLabel / ${filters.billingMonth} / ${filters.sessionYr}\n\n'
          'This will delete all UNPAID vouchers for this cohort and regenerate them '
          'with the current fee-head configuration.\n\n'
          'Paid vouchers are never touched. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final summary = await ref
        .read(voucherGenExecutionProvider.notifier)
        .regenerateUnpaidCohortVouchers();
    if (!mounted) return;

    if (summary != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Regenerated ${summary.generatedCount} voucher(s) with current configuration.',
          ),
          backgroundColor: AppColors.statusSuccessText,
        ),
      );
    } else {
      final error = ref.read(voucherGenExecutionProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.statusErrorText,
          ),
        );
      }
    }
  }

  void _onEscape() {
    final execState = ref.read(voucherGenExecutionProvider);
    if (execState.completionSummary != null) {
      ref.read(voucherGenExecutionProvider.notifier).clearSummary();
    }
  }

  Future<void> _openPrintPreview({List<FeeReceiptView>? specific}) async {
    List<FeeReceiptView> receipts;
    try {
      receipts = specific ?? await _loadGeneratedVouchers();
    } catch (e, st) {
      debugPrint('Print preview load failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load vouchers: $e')));
      return;
    }
    if (receipts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No generated vouchers to print')),
      );
      return;
    }
    if (!mounted) return;
    await showVoucherPrintPreviewDialog(
      context,
      vouchers: receipts,
      branchName: 'Ailyans Higher Secondary School',
      branchAddress: 'Muslim Bazar Mianwali',
      bankName: 'Askari Bank Limited',
      bankBranch: 'Ballo Khel Road',
      bankAcctNo: '4528',
    );
  }

  Future<List<FeeReceiptView>> _loadGeneratedVouchers() async {
    final filters = ref.read(voucherGenFiltersProvider);
    final db = await DatabaseService.instance.database;
    final classIdParam = filters.classId;
    final rows = await db.rawQuery(
      '''
      SELECT vm.*, sr.NameFirst, sr.NameLast, sr.F_Name,
             c.CName AS class_name, cs.SecName AS section_name,
             sc.ClassRollNo, sc.SessionYr
      FROM VoucharMas vm
      JOIN Stu_Reg sr ON vm.student_class_StuRegId = sr.Stu_RegID
      LEFT JOIN Student_Class sc
        ON sr.Stu_RegID = sc.Stu_RegID AND sc.SessionYr = vm.SessionYr
      LEFT JOIN Class c ON sc.ClassID = c.ClassID
      LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
      WHERE vm.ForMonth = ?
        AND (? IS NULL OR vm.ClassID = ?)
      ORDER BY sc.ClassRollNo ASC
    ''',
      [filters.billingMonth, classIdParam, classIdParam],
    );

    final out = <FeeReceiptView>[];
    for (final row in rows) {
      final vid = row['VoucherMasID'] as String;
      final det = await db.rawQuery(
        '''
        SELECT vd.feeParameterID, vd.Amount, vd.Discount,
               fp.ParamDesciption
        FROM VoucharDet vd
        LEFT JOIN FeeParameters fp ON vd.feeParameterID = fp.FeeParamID
        WHERE vd.VoucharMasID = ?
        ORDER BY vd.feeParameterID ASC
      ''',
        [vid],
      );
      out.add(
        FeeReceiptView.fromFlatMap(
          Map<String, dynamic>.from(row),
          lineItems: det.map((m) => Map<String, dynamic>.from(m)).toList(),
        ),
      );
    }
    return out;
  }

  Future<void> _onApplyLateFine() async {
    final filters = ref.read(voucherGenFiltersProvider);
    final fineAmount = int.tryParse(_lateFineController.text.trim()) ?? 0;
    if (fineAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a positive late fine amount')),
      );
      return;
    }
    try {
      final count = await ref
          .read(voucherGenExecutionProvider.notifier)
          .applyLateFineToCohort(
            billingMonth: filters.billingMonth,
            feeParamId: 8, // Late Fee head (per FeeParameters table)
            fineAmount: fineAmount,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fine Added for $count Vouchers')));
      ref.invalidate(voucherGenPreviewProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to apply late fine: $e')));
    }
  }

  Future<void> _onSyncDueDate() async {
    final filters = ref.read(voucherGenFiltersProvider);
    try {
      final count = await ref
          .read(voucherGenExecutionProvider.notifier)
          .syncDueDateForCohort(
            billingMonth: filters.billingMonth,
            newDueDate: filters.dueDate,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Due Date updated for $count Vouchers')),
      );
      ref.invalidate(voucherGenPreviewProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to sync due dates: $e')));
    }
  }

  Future<void> _pickBillingMonth(BuildContext context) async {
    final filters = ref.read(voucherGenFiltersProvider);
    final parts = filters.billingMonth.trim().split(RegExp(r'\s+'));
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    if (parts.length >= 2) {
      selectedYear = int.tryParse(parts[1]) ?? now.year;
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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(voucherGenFiltersProvider);
    final previewAsync = ref.watch(voucherGenPreviewProvider);
    final execState = ref.watch(voucherGenExecutionProvider);

    final previewList = previewAsync.valueOrNull ?? [];
    final eligibleCount = previewList.length;
    final readyRows = previewList
        .where((r) => r.status != VoucherPreviewStatus.alreadyGenerated)
        .toList();
    final generatedRows = previewList
        .where((r) => r.status == VoucherPreviewStatus.alreadyGenerated)
        .toList();

    final readyCount = readyRows.length;
    final generatedCount = generatedRows.length;
    final waiverCount = previewList
        .where((r) => r.status == VoucherPreviewStatus.fullWaiver)
        .length;

    final int displayBilled;
    final String displayLabel;

    if (readyRows.isNotEmpty) {
      displayBilled = readyRows.fold<int>(0, (s, r) => s + r.netPayable);
      displayLabel = 'Estimated Net Billed';
    } else if (generatedRows.isNotEmpty) {
      displayBilled = generatedRows.fold<int>(0, (s, r) => s + r.netPayable);
      displayLabel = 'Cohort Total Billed';
    } else {
      displayBilled = 0;
      displayLabel = 'Estimated Net Billed';
    }

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(eligibleCount),
                  const SizedBox(height: AppSpacing.sm),

                  if (execState.isGenerating) ...[
                    _buildGeneratingBanner(execState),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // Main workspace: 34 / 66 split, no page scrolling.
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 34,
                          child: _buildConfigurationCard(
                            context,
                            filters,
                            readyCount,
                            generatedCount,
                            execState.isGenerating,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 66,
                          child: _buildPreviewCard(
                            previewAsync,
                            previewList,
                            eligibleCount,
                            waiverCount,
                            displayLabel,
                            displayBilled,
                            readyCount,
                            generatedCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (execState.completionSummary != null)
                Positioned.fill(
                  child: _buildBatchCompleteDialog(
                    context,
                    execState.completionSummary!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED CARD CHROME
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.surfaceRaised,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: Border.all(color: AppColors.borderDefault),
    boxShadow: const [
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(int eligibleCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Home  >  Fees  >  Monthly Voucher Generation',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        Row(
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
                      maxLines: 1,
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
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
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
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.go('/fees/receipts?from=vouchers'),
              icon: const Icon(Icons.point_of_sale_outlined, size: 16),
              label: const Text('Collect Fee'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 32),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneratingBanner(VoucherGenState execState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.statusErrorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.statusErrorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, color: AppColors.statusErrorText, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Voucher Generation in Progress: Generating vouchers for the selected cohort. '
              'Please do not navigate away or close the application until the process finishes.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

  // ---------------------------------------------------------------------------
  // LEFT CARD — BATCH GENERATION PARAMETERS
  // ---------------------------------------------------------------------------

  Widget _buildConfigurationCard(
    BuildContext context,
    VoucherGenFilters filters,
    int readyCount,
    int generatedCount,
    bool isGenerating,
  ) {
    final classesAsync = ref.watch(classesProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final bankListAsync = ref.watch(voucherBankListProvider);
    final tariffsAsync = ref.watch(
      voucherClassTariffsProvider(filters.classId),
    );

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Batch Generation Parameters',
            style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Group 1: Session + Month
          _buildFieldGroup(
            left: _labeledField(
              'Session Year *',
              DropdownButtonFormField<String>(
                key: ValueKey(filters.sessionYr),
                initialValue: filters.sessionYr,
                isExpanded: true,
                decoration: _inputDecoration(),
                items: const [
                  DropdownMenuItem(value: '2026-27', child: Text('2026-27')),
                  DropdownMenuItem(value: '2025-26', child: Text('2025-26')),
                  DropdownMenuItem(
                    value: '2017-2018',
                    child: Text('2017-2018'),
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
            ),
            right: _labeledField(
              'Billing Month *',
              _pickerField(
                text: filters.billingMonth,
                icon: Icons.calendar_today,
                iconAtStart: true,
                onTap: isGenerating ? null : () => _pickBillingMonth(context),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Group 2: Class + Section
          _buildFieldGroup(
            left: _labeledField(
              'Target Class *',
              classesAsync.when(
                data: (classes) => DropdownButtonFormField<int?>(
                  key: ValueKey(filters.classId),
                  initialValue: filters.classId,
                  isExpanded: true,
                  decoration: _inputDecoration(),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Classes'),
                    ),
                    ...classes.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.classId,
                        child: Text(c.cName, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: isGenerating
                      ? null
                      : (val) {
                          ref
                              .read(voucherGenFiltersProvider.notifier)
                              .setClassId(val);
                        },
                ),
                loading: () => const SizedBox(
                  height: _kFieldHeight,
                  child: Center(child: LinearProgressIndicator()),
                ),
                error: (_, __) => const Text('Error loading classes'),
              ),
            ),
            right: _labeledField(
              'Target Section',
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
                      ...filtered.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.classSecId,
                          child: Text(
                            'Section ${s.secName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: isGenerating
                        ? null
                        : (val) {
                            ref
                                .read(voucherGenFiltersProvider.notifier)
                                .setClassSecId(val);
                          },
                  );
                },
                loading: () => const SizedBox(
                  height: _kFieldHeight,
                  child: Center(child: LinearProgressIndicator()),
                ),
                error: (_, __) => const Text('Error loading sections'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Group 3: Issue + Due
          _buildFieldGroup(
            left: _labeledField(
              'Issue Date *',
              _pickerField(
                text: dateFormat.format(filters.issueDate),
                icon: Icons.calendar_month,
                onTap: isGenerating
                    ? null
                    : () => _pickDate(
                        context,
                        filters.issueDate,
                        (d) => ref
                            .read(voucherGenFiltersProvider.notifier)
                            .setIssueDate(d),
                      ),
              ),
            ),
            right: _labeledField(
              'Payment Due Date *',
              _pickerField(
                text: dateFormat.format(filters.dueDate),
                icon: Icons.calendar_month,
                onTap: isGenerating
                    ? null
                    : () => _pickDate(
                        context,
                        filters.dueDate,
                        (d) => ref
                            .read(voucherGenFiltersProvider.notifier)
                            .setDueDate(d),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Receiving bank: actionable selection with bank icon tile
          _labeledField(
            'Receiving Bank *',
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
                  icon: const Icon(
                    Icons.unfold_more,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  decoration: _inputDecoration(
                    prefixIcon: const Icon(
                      Icons.account_balance,
                      size: 18,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  items: banks
                      .map(
                        (b) => DropdownMenuItem<int>(
                          value: b.bankInfoId,
                          child: Text(
                            b.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isGenerating
                      ? null
                      : (val) {
                          if (val != null) {
                            ref
                                .read(voucherGenFiltersProvider.notifier)
                                .setBankId(val);
                          }
                        },
                );
              },
              loading: () => const SizedBox(
                height: _kFieldHeight,
                child: Center(child: LinearProgressIndicator()),
              ),
              error: (_, __) => const Text('Error loading banks'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Late fine pill + secondary Sync button (single compact row)
          Row(
            children: [
              Expanded(flex: 11, child: _buildLateFinePill()),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 9,
                child: Tooltip(
                  message: 'Apply the Payment Due Date to existing vouchers',
                  child: SizedBox(
                    height: _kFieldHeight,
                    child: TextButton.icon(
                      onPressed: _onSyncDueDate,
                      icon: const Icon(Icons.event_repeat, size: 16),
                      label: const Text(
                        'Sync Due Date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        backgroundColor: AppColors.surfaceSubtle,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Fee heads fill the remaining space; never overflow (clips + scrolls
          // internally only if a class has an unusually large number of heads).
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildFeeHeadsCompact(tariffsAsync, filters),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _buildBottomAction(
            readyCount,
            generatedCount,
            isGenerating,
            _onGenerate,
          ),
        ],
      ),
    );
  }

  /// Subtle tinted container grouping a logical pair of inputs (no border).
  Widget _buildFieldGroup({required Widget left, required Widget right}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: right),
        ],
      ),
    );
  }

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [_buildFieldLabel(label), const SizedBox(height: 6), child],
    );
  }

  Widget _pickerField({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool iconAtStart = false,
  }) {
    final iconWidget = Icon(icon, size: 16, color: AppColors.textMuted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        height: _kFieldHeight,
        child: InputDecorator(
          decoration: _inputDecoration(
            prefixIcon: iconAtStart
                ? Padding(
                    padding: const EdgeInsets.only(left: 10, right: 6),
                    child: iconWidget,
                  )
                : null,
            suffixIcon: iconAtStart
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: iconWidget,
                  ),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  /// Late fine input + "Fine" action fused into one pill.
  Widget _buildLateFinePill() {
    return Container(
      height: _kFieldHeight,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          const SizedBox(width: 10),
          Text(
            'Rs.',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _lateFineController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTypography.monospace.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Material(
            color: AppColors.brandPrimary,
            child: InkWell(
              onTap: _onApplyLateFine,
              child: const SizedBox(
                width: 56,
                height: double.infinity,
                child: Center(
                  child: Text(
                    'Fine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fee heads as a compact 2-column chip grid with monospace amounts.
  /// The whole panel scrolls internally, so it can never overflow no matter
  /// how little vertical space the card has left.
  Widget _buildFeeHeadsCompact(
    AsyncValue<List<FeeHeadSummary>> tariffsAsync,
    VoucherGenFilters filters,
  ) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 12, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'FEE HEADS',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/fees/parameters'),
                  icon: const Icon(Icons.edit_outlined, size: 12),
                  label: const Text(
                    'Edit tariffs',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            tariffsAsync.when(
              data: (tariffs) {
                return LayoutBuilder(
                  builder: (context, c) {
                    const gap = 6.0;
                    final w = (c.maxWidth - gap) / 2;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tariffs.isEmpty)
                          Text(
                            'No tariffs defined for this selection',
                            style: AppTypography.bodySmall,
                          )
                        else
                          Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: tariffs.map((t) {
                              final isIncluded = !filters.excludedFeeParamIds
                                  .contains(t.feeParamId);
                              return SizedBox(
                                width: w,
                                child: _buildFeeChip(t, isIncluded),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        _buildArrearsChip(filters.includeArrears),
                      ],
                    );
                  },
                );
              },
              loading: () =>
                  const SizedBox(height: 12, child: LinearProgressIndicator()),
              error: (_, __) => const Text(
                'Error loading fee heads',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeChip(FeeHeadSummary t, bool isIncluded) {
    return InkWell(
      onTap: () {
        ref
            .read(voucherGenFiltersProvider.notifier)
            .toggleFeeHead(t.feeParamId);
        ref.invalidate(voucherGenPreviewProvider);
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isIncluded ? AppColors.surfaceRaised : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isIncluded
                ? AppColors.brandPrimary
                : AppColors.borderDefault,
            width: isIncluded ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isIncluded ? Icons.check_box : Icons.check_box_outline_blank,
              size: 14,
              color: isIncluded ? AppColors.brandPrimary : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${FeeHeadDisplay.of(t.description)}: Rs. ${currencyFormat.format(t.fee.toInt())}',
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: isIncluded
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isIncluded
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrearsChip(bool includeArrears) {
    return InkWell(
      onTap: () {
        ref
            .read(voucherGenFiltersProvider.notifier)
            .setIncludeArrears(!includeArrears);
        ref.invalidate(voucherGenPreviewProvider);
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: includeArrears
              ? AppColors.surfaceRaised
              : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: includeArrears
                ? AppColors.brandPrimary
                : AppColors.borderDefault,
            width: includeArrears ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              includeArrears ? Icons.check_box : Icons.check_box_outline_blank,
              size: 14,
              color: includeArrears
                  ? AppColors.brandPrimary
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Include Past Arrears',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: includeArrears
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: includeArrears
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Primary CTA: 48px, full width, soft shadow.
  Widget _buildBottomAction(
    int readyCount,
    int generatedCount,
    bool isGenerating,
    VoidCallback onGenerate,
  ) {
    const double h = 48;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    Widget shadowed(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [
          BoxShadow(
            color: Color(0x401E3A8A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (isGenerating) {
      return SizedBox(
        height: h,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          label: Text(
            'Generating...',
            style: AppTypography.label.copyWith(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: AppColors.brandPrimary,
            minimumSize: const Size.fromHeight(h),
            shape: shape,
          ),
        ),
      );
    }
    if (readyCount > 0) {
      return shadowed(
        SizedBox(
          height: h,
          child: ElevatedButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.bolt, size: 20),
            label: Text(
              'Generate $readyCount Vouchers (Ctrl+G)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(h),
              shape: shape,
            ),
          ),
        ),
      );
    }
    if (generatedCount > 0) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: () => _openPrintPreview(),
              icon: const Icon(Icons.print, size: 20),
              label: Text(
                'Print $generatedCount Vouchers (Ctrl+P)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(h),
                shape: shape,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: h,
            child: OutlinedButton.icon(
              onPressed: isGenerating ? null : _onRegenerateUnpaid,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Regenerate',
                maxLines: 1,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                side: const BorderSide(color: AppColors.brandPrimary),
                minimumSize: const Size(0, h),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: shape,
              ),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      height: h,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(h),
          shape: shape,
        ),
        child: const Text('No eligible students'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT CARD — COHORT BILLING AUDIT & LEDGER PREVIEW
  // ---------------------------------------------------------------------------

  Widget _buildPreviewCard(
    AsyncValue<List<VoucherPreviewRow>> previewAsync,
    List<VoucherPreviewRow> previewList,
    int eligibleCount,
    int waiverCount,
    String displayLabel,
    int displayBilled,
    int readyCount,
    int generatedCount,
  ) {
    final filters = ref.watch(voucherGenFiltersProvider);
    final generatedRows = previewList
        .where((r) => r.status == VoucherPreviewStatus.alreadyGenerated)
        .toList();
    final readyRows = previewList
        .where((r) => r.status != VoucherPreviewStatus.alreadyGenerated)
        .toList();

    final persistedSum = generatedRows.isNotEmpty
        ? generatedRows.first.subtotal
        : null;

    int? currentToggleSum = readyRows.firstOrNull?.subtotal;
    if (currentToggleSum == null && filters.classId != null) {
      final tariffsAsync = ref.watch(
        voucherClassTariffsProvider(filters.classId),
      );
      currentToggleSum = tariffsAsync.maybeWhen(
        data: (tariffs) {
          final activeTariffs = tariffs
              .where((t) => !filters.excludedFeeParamIds.contains(t.feeParamId))
              .toList();
          return activeTariffs.fold<int>(0, (s, t) => s + t.fee.toInt());
        },
        orElse: () => null,
      );
    }

    final bool hasDrift =
        persistedSum != null &&
        currentToggleSum != null &&
        currentToggleSum != persistedSum;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live calculation state prior to permanent database commit',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Re-calculate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderDefault),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => ref.invalidate(voucherGenPreviewProvider),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.go('/fees/ledger'),
                icon: const Icon(Icons.assessment_outlined, size: 16),
                label: const Text('View Full Ledger'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderDefault),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // KPI strip
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Eligible Students',
                  value: '$eligibleCount students',
                  icon: Icons.people_outline,
                  color: AppColors.textPrimary,
                  bg: AppColors.surfaceSubtle,
                  border: AppColors.borderDefault,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildKpiCard(
                  title: 'Full Tuition Waiver',
                  value: '$waiverCount students',
                  icon: Icons.card_membership_outlined,
                  color: AppColors.brandPrimary,
                  bg: AppColors.statusInfoBg,
                  border: AppColors.statusInfoBorder,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildKpiCard(
                  title: displayLabel,
                  value: 'Rs. ${currencyFormat.format(displayBilled)}',
                  icon: Icons.payments_outlined,
                  color: AppColors.statusSuccessText,
                  bg: AppColors.statusSuccessBg,
                  border: AppColors.statusSuccessBorder,
                  emphasize: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (hasDrift)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.statusWarningBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.statusWarningBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.statusWarningText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Fee head configuration changed. Click Regenerate to apply.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.statusWarningText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Table (header sticky, body scrolls internally, footer pinned)
          Expanded(
            child: previewAsync.when(
              data: (rows) {
                if (rows.isEmpty) return _buildEmptyState();
                return _buildTable(rows, readyCount, generatedCount);
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
          const SizedBox(height: AppSpacing.xs),

          // Commit notice
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.statusWarningText,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '$readyCount vouchers will be created in VoucharMas + VoucharDet. '
                    'This action cannot be undone after commit.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.statusWarningText,
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    bool emphasize = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: AppTypography.h2.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: emphasize ? 20 : 17,
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

  // ---------------------------------------------------------------------------
  // TABLE
  // ---------------------------------------------------------------------------

  Widget _buildTable(
    List<VoucherPreviewRow> rows,
    int readyCount,
    int generatedCount,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            // Sticky header
            Container(
              height: 36,
              color: AppColors.surfaceSubtle,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  _headerCell('Voucher ID', width: _kIdColWidth),
                  const SizedBox(width: _kColGap),
                  _headerCell('Student Name', flex: 30),
                  const SizedBox(width: _kColGap),
                  _headerCell('SubTotal (Rs)', flex: 16, right: true),
                  const SizedBox(width: _kColGap),
                  _headerCell('Arrears', flex: 13, right: true),
                  const SizedBox(width: _kColGap),
                  _headerCell('Discount', flex: 13, right: true),
                  const SizedBox(width: _kColGap),
                  _headerCell('Net Pay (Rs)', flex: 18, right: true),
                  const SizedBox(width: _kColGap),
                  _headerCell('Status', width: _kStatusColWidth, center: true),
                  const SizedBox(width: _kColGap),
                  const SizedBox(width: _kPrintColWidth),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderDefault),

            // Body (internal scroll only if the cohort is large)
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemExtent: _kRowHeight,
                itemBuilder: (context, index) =>
                    _buildPreviewRow(rows[index], index),
              ),
            ),

            // Footer summary
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                border: Border(top: BorderSide(color: AppColors.borderDefault)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing 1-${rows.length} of ${rows.length} eligible records in cohort',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                  ),
                  Text(
                    '$readyCount ready  ·  $generatedCount generated',
                    maxLines: 1,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(
    String text, {
    double? width,
    int? flex,
    bool right = false,
    bool center = false,
  }) {
    final cell = Text(
      text,
      textAlign: right
          ? TextAlign.right
          : (center ? TextAlign.center : TextAlign.left),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.label.copyWith(
        fontSize: 11,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
    if (width != null) return SizedBox(width: width, child: cell);
    return Expanded(flex: flex ?? 1, child: cell);
  }

  Widget _buildPreviewRow(VoucherPreviewRow row, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.surfaceRaised : AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceSubtle),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kIdColWidth,
            child: Text(
              row.voucherId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monospace.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: _kColGap),
          Expanded(
            flex: 30,
            child: Text(
              row.studentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: _kColGap),
          _numCell(
            currencyFormat.format(row.subtotal),
            flex: 16,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: _kColGap),
          _numCell(
            currencyFormat.format(row.arrears),
            flex: 13,
            color: row.arrears > 0
                ? AppColors.statusWarningText
                : AppColors.textMuted,
            weight: row.arrears > 0 ? FontWeight.w600 : FontWeight.w400,
          ),
          const SizedBox(width: _kColGap),
          _numCell(
            currencyFormat.format(row.discount),
            flex: 13,
            color: row.discount > 0
                ? AppColors.statusInfoText
                : AppColors.textMuted,
            weight: row.discount > 0 ? FontWeight.w600 : FontWeight.w400,
          ),
          const SizedBox(width: _kColGap),
          _numCell(
            currencyFormat.format(row.netPayable),
            flex: 18,
            color: AppColors.textPrimary,
            weight: FontWeight.w700,
          ),
          const SizedBox(width: _kColGap),
          SizedBox(
            width: _kStatusColWidth,
            child: Center(child: _buildStatusBadge(row.status)),
          ),
          const SizedBox(width: _kColGap),
          SizedBox(
            width: _kPrintColWidth,
            child: IconButton(
              icon: const Icon(Icons.print_outlined, size: 16),
              color: AppColors.textMuted,
              tooltip: 'Print this voucher',
              padding: EdgeInsets.zero,
              onPressed: () async {
                final all = await _loadGeneratedVouchers();
                final match = all
                    .where((r) => r.stuRegId == row.stuRegId)
                    .toList();
                if (match.isNotEmpty && mounted) {
                  await _openPrintPreview(specific: match);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _numCell(
    String text, {
    required int flex,
    required Color color,
    FontWeight weight = FontWeight.w400,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.monospace.copyWith(
          color: color,
          fontWeight: weight,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Modern pill: dot + label.
  Widget _buildStatusBadge(VoucherPreviewStatus status) {
    final String label;
    final Color bg;
    final Color fg;
    final Color dot;

    switch (status) {
      case VoucherPreviewStatus.ready:
        label = 'Ready';
        bg = AppColors.surfaceSubtle;
        fg = AppColors.textSecondary;
        dot = AppColors.textMuted;
        break;
      case VoucherPreviewStatus.alreadyGenerated:
        label = 'Generated';
        bg = AppColors.statusSuccessBg;
        fg = AppColors.statusSuccessText;
        dot = AppColors.statusSuccessText;
        break;
      case VoucherPreviewStatus.arrearsRollover:
        label = 'Arrears';
        bg = AppColors.statusWarningBg;
        fg = AppColors.statusWarningText;
        dot = AppColors.statusWarningText;
        break;
      case VoucherPreviewStatus.fullWaiver:
        label = '100% Waiver';
        bg = AppColors.statusInfoBg;
        fg = AppColors.statusInfoText;
        dot = AppColors.statusInfoText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  // ---------------------------------------------------------------------------
  // BATCH COMPLETE DIALOG (unchanged visuals)
  // ---------------------------------------------------------------------------

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
                  Flexible(
                    child: Container(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
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
                Padding(
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
                    onPressed: () => _openPrintPreview(),
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

  // ---------------------------------------------------------------------------
  // FORM HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
        vertical: 8,
      ),
      filled: true,
      fillColor: AppColors.surfaceRaised,
      prefixIcon: prefixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 20),
      prefixText: prefixText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
    );
  }
}
