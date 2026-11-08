import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/clock_provider.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/providers/voucher_generation_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/fee_receipt_view.dart';
import '../../models/school_class.dart';
import '../../models/voucher_preview_row.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';
import '../../widgets/voucher/voucher.dart';

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
  bool _hasValidated = false;
  bool _isParamExpanded = true;
  bool _hasAutoCollapsed = false;
  bool _hasAutoOpenedSheet = false;

  // Layout constants for the preview table.
  static const double _kIdColWidth = 82;
  static const double _kStatusColWidth = 112;
  static const double _kPrintColWidth = 36;
  static const double _kColGap = 6;
  static const double _kRowHeight = 40;

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

      // 1. Session year
      final metaAsync = ref.read(shellMetadataProvider);
      if (metaAsync.hasValue) {
        final meta = metaAsync.valueOrNull;
        if (meta != null) {
          final current = ref.read(voucherGenFiltersProvider).sessionYr;
          if (current != meta.sessionYear) {
            ref
                .read(voucherGenFiltersProvider.notifier)
                .setSessionYr(meta.sessionYear);
          }
        }
      }

      // 2. Billing month + dates from clockProvider in MMM-yyyy format (e.g. Oct-2026)
      final now = ref.read(clockProvider)();
      const monthNames = [
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
      final expectedMonth = now.year >= 2020
          ? DateFormat('MMM-yyyy').format(DateTime(now.year, now.month, 1))
          : '${monthNames[now.month - 1]} ${now.year}';
      final filters = ref.read(voucherGenFiltersProvider);
      if (filters.billingMonth != expectedMonth) {
        final notifier = ref.read(voucherGenFiltersProvider.notifier);
        notifier.setBillingMonth(expectedMonth);
        notifier.setIssueDate(DateTime(now.year, now.month, 1));
        notifier.setDueDate(DateTime(now.year, now.month, 10));
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

  Future<void> _handleGenerateTrigger(int eligibleCount) async {
    final execState = ref.read(voucherGenExecutionProvider);
    if (execState.isGenerating) return;

    final filters = ref.read(voucherGenFiltersProvider);
    if (filters.classId == null ||
        filters.sessionYr.isEmpty ||
        filters.billingMonth.isEmpty ||
        filters.dueDate.isBefore(filters.issueDate)) {
      setState(() => _hasValidated = true);
      return;
    }

    if (eligibleCount <= 0) return;

    final classesAsync = ref.read(classesProvider);
    final classes = classesAsync.valueOrNull ?? [];
    final match = classes
        .where((c) => c.classId == filters.classId)
        .firstOrNull;
    final rawClassName = match?.cName ?? '${filters.classId}';
    final classLabel = rawClassName.replaceFirst(
      RegExp(r'^Class\s*', caseSensitive: false),
      '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Create $eligibleCount vouchers for Class $classLabel, ${filters.billingMonth}?',
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
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _onGenerate();
    }
  }

  Future<void> _onGenerate() async {
    final execState = ref.read(voucherGenExecutionProvider);
    if (execState.isGenerating) return;

    await ref.read(voucherGenExecutionProvider.notifier).generateVouchers();
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
    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.feeVoucher,
        vouchers: receipts,
        extraParams: const {
          'branchName': 'Ailyans Higher Secondary School',
          'branchAddress': 'Muslim Bazar Mianwali',
          'bankName': 'Askari Bank Limited',
          'bankBranch': 'Ballo Khel Road',
          'bankAcctNo': '4528',
        },
      ),
    );
  }

  Future<List<FeeReceiptView>> _loadGeneratedVouchers() async {
    final filters = ref.read(voucherGenFiltersProvider);
    final db = await DatabaseService.instance.database;
    final yyMm = billingMonthToYyMm(filters.billingMonth);
    final isSingle =
        filters.mode == 'single' && filters.selectedStuRegId != null;
    final stuRegIdParam = isSingle ? filters.selectedStuRegId : null;
    final classIdParam = isSingle ? null : filters.classId;

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
        AND SUBSTR(vm.VoucherMasID, 1, 4) = ?
        AND (? IS NULL OR vm.ClassID = ?)
        AND (? IS NULL OR vm.Student_Class_StuRegID = ?)
      ORDER BY sc.ClassRollNo ASC
    ''',
      [
        filters.billingMonth,
        yyMm,
        classIdParam,
        classIdParam,
        stuRegIdParam,
        stuRegIdParam,
      ],
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

    // Preview auto-collapse listener for medium tier
    ref.listen<AsyncValue<List<VoucherPreviewRow>>>(voucherGenPreviewProvider, (
      prev,
      next,
    ) {
      if (mounted &&
          (prev?.valueOrNull == null || prev!.valueOrNull!.isEmpty) &&
          next.valueOrNull != null &&
          next.valueOrNull!.isNotEmpty) {
        setState(() {
          _hasAutoCollapsed = true;
          _isParamExpanded = false;
        });
      }
    });

    if (ResponsiveBreakpoints.isMobile(context)) {
      if (filters.classId == null && !_hasAutoOpenedSheet) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasAutoOpenedSheet) {
            _hasAutoOpenedSheet = true;
            _openParamSheet(
              context,
              filters,
              readyCount,
              generatedCount,
              execState.isGenerating,
            );
          }
        });
      }
      return _buildCompactLayout(
        context,
        filters,
        previewAsync,
        previewList,
        eligibleCount,
        waiverCount,
        displayLabel,
        displayBilled,
        readyCount,
        generatedCount,
        execState,
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): () =>
            _handleGenerateTrigger(eligibleCount),
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () =>
            _handleGenerateTrigger(eligibleCount),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1024) {
                return _buildMediumLayout(
                  context,
                  filters,
                  previewAsync,
                  previewList,
                  eligibleCount,
                  waiverCount,
                  displayLabel,
                  displayBilled,
                  readyCount,
                  generatedCount,
                  execState,
                );
              }

              return _buildExpandedLayout(
                context,
                constraints,
                filters,
                previewAsync,
                previewList,
                eligibleCount,
                waiverCount,
                displayLabel,
                displayBilled,
                readyCount,
                generatedCount,
                execState,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedLayout(
    BuildContext context,
    BoxConstraints constraints,
    VoucherGenFilters filters,
    AsyncValue<List<VoucherPreviewRow>> previewAsync,
    List<VoucherPreviewRow> previewList,
    int eligibleCount,
    int waiverCount,
    String displayLabel,
    int displayBilled,
    int readyCount,
    int generatedCount,
    VoucherGenState execState,
  ) {
    final isWide = constraints.maxWidth >= 1280;
    final leftPaneWidth = isWide ? 340.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(eligibleCount, filters, execState),
        const SizedBox(height: AppSpacing.sm),

        // Main workspace: Left parameter card + Right preview pane
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leftPaneWidth,
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
                child: _buildPreviewPane(
                  context,
                  filters,
                  previewAsync,
                  previewList,
                  eligibleCount,
                  waiverCount,
                  displayLabel,
                  displayBilled,
                  readyCount,
                  generatedCount,
                  execState,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Sticky bottom action bar or progress panel
        if (execState.isGenerating)
          _buildVoucherProgressPanel(execState)
        else
          if (execState.isGenerating)
            _buildVoucherProgressPanel(execState)
          else
            VoucherActionBar(
              impactState: execState.error != null
                  ? VoucherImpactState.error
                  : (eligibleCount == 0
                        ? VoucherImpactState.zero
                        : VoucherImpactState.normal),
              count: eligibleCount,
              errorText: execState.error,
              isGenerating: execState.isGenerating,
              onGenerate: (eligibleCount > 0 && !execState.isGenerating)
                  ? () => _handleGenerateTrigger(eligibleCount)
                  : null,
            ),
      ],
    );
  }

  Widget _buildMediumLayout(
    BuildContext context,
    VoucherGenFilters filters,
    AsyncValue<List<VoucherPreviewRow>> previewAsync,
    List<VoucherPreviewRow> previewList,
    int eligibleCount,
    int waiverCount,
    String displayLabel,
    int displayBilled,
    int readyCount,
    int generatedCount,
    VoucherGenState execState,
  ) {
    if (!_hasAutoCollapsed && previewList.isNotEmpty) {
      _hasAutoCollapsed = true;
      _isParamExpanded = false;
    }
    final showParamCard = _isParamExpanded || previewList.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(eligibleCount, filters, execState, isMedium: true),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: showParamCard
                    ? _buildConfigurationCard(
                        context,
                        filters,
                        readyCount,
                        generatedCount,
                        execState.isGenerating,
                        columnCount: 2,
                      )
                    : _buildParamSummaryCard(filters),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 580,
                  child: _buildPreviewPane(
                    context,
                    filters,
                    previewAsync,
                    previewList,
                    eligibleCount,
                    waiverCount,
                    displayLabel,
                    displayBilled,
                    readyCount,
                    generatedCount,
                    execState,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (execState.isGenerating)
          _buildVoucherProgressPanel(execState)
        else
          if (execState.isGenerating)
            _buildVoucherProgressPanel(execState)
          else
            VoucherActionBar(
              impactState: execState.error != null
                  ? VoucherImpactState.error
                  : (eligibleCount == 0
                        ? VoucherImpactState.zero
                        : VoucherImpactState.normal),
              count: eligibleCount,
              errorText: execState.error,
              isGenerating: execState.isGenerating,
              onGenerate: (eligibleCount > 0 && !execState.isGenerating)
                  ? () => _handleGenerateTrigger(eligibleCount)
                  : null,
            ),
      ],
    );
  }

  Widget _buildParamSummaryCard(VoucherGenFilters filters) {
    final classesAsync = ref.watch(classesProvider);
    final classes = classesAsync.valueOrNull ?? [];
    final matchClass = classes
        .where((c) => c.classId == filters.classId)
        .firstOrNull;
    final classLabel =
        matchClass?.cName ??
        (filters.classId == null ? 'All Classes' : 'Class ${filters.classId}');

    final sectionsAsync = ref.watch(sectionsProvider);
    final sections = sectionsAsync.valueOrNull ?? [];
    final matchSec = sections
        .where((s) => s.classSecId == filters.classSecId)
        .firstOrNull;
    final sectionLabel = filters.classSecId == null
        ? 'All Sections'
        : 'Section ${matchSec?.secName ?? filters.classSecId}';

    final summaryText = '$classLabel · $sectionLabel · ${filters.billingMonth}';

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summaryText,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isParamExpanded = true),
            child: const Text('Edit'),
          ),
        ],
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

  Widget _buildHeader(
    int eligibleCount,
    VoucherGenFilters filters,
    VoucherGenState execState, {
    bool isMedium = false,
  }) {
    final from = _getFromOrigin(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Home  >  Fees  >  Monthly Voucher Generation',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (from != null && from.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () => context.go(from),
                      icon: const Icon(Icons.arrow_back, size: 14),
                      label: Text(
                        from.contains('dashboard')
                            ? 'Back to Dashboard'
                            : 'Back',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderDefault),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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
        const SizedBox(height: AppSpacing.xs),
        // Header strip: [Batch | Single] ........ StepIndicator
        if (isMedium) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModeSwitch(filters),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildStepIndicator(filters, execState),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModeSwitch(filters),
              _buildStepIndicator(filters, execState),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildModeSwitch(VoucherGenFilters filters) {
    final isBatch = filters.mode == 'batch';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton(
            label: 'Batch (Cohort)',
            icon: Icons.dynamic_feed_outlined,
            isSelected: isBatch,
            onTap: () {
              ref.read(voucherGenFiltersProvider.notifier).setMode('batch');
              ref.read(voucherGenExecutionProvider.notifier).clearSummary();
            },
          ),
          _modeButton(
            label: 'Single Student',
            icon: Icons.person_outline,
            isSelected: !isBatch,
            onTap: () {
              ref.read(voucherGenFiltersProvider.notifier).setMode('single');
              ref.read(voucherGenExecutionProvider.notifier).clearSummary();
            },
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.brandPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(
    VoucherGenFilters filters,
    VoucherGenState execState,
  ) {
    final int activeIndex;
    if (execState.completionSummary != null) {
      activeIndex = 3;
    } else if (execState.isGenerating) {
      activeIndex = 2;
    } else if (filters.classId != null) {
      activeIndex = 1;
    } else {
      activeIndex = 0;
    }

    const steps = ['Select', 'Preview', 'Confirm', 'Print'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.chevron_right,
                size: 14,
                color: i <= activeIndex
                    ? AppColors.brandPrimary
                    : AppColors.textMuted,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? AppColors.brandPrimary.withAlpha(20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < activeIndex
                        ? AppColors.brandPrimary
                        : (i == activeIndex
                              ? AppColors.brandPrimary
                              : AppColors.surfaceSubtle),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i <= activeIndex
                          ? AppColors.brandPrimary
                          : AppColors.borderDefault,
                    ),
                  ),
                  child: i < activeIndex
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: i == activeIndex
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[i],
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: i == activeIndex
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i <= activeIndex
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT CARD — BATCH GENERATION PARAMETERS
  // ---------------------------------------------------------------------------

  List<String> _effectiveBillingMonths(String billingMonth, String sessionYr) {
    final parts = billingMonth.trim().split(RegExp(r'[\s\-/]+'));
    final year =
        (parts.length >= 2 ? int.tryParse(parts[1]) : null) ??
        int.tryParse(sessionYr.split('-').first) ??
        2017;
    const months = [
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
    final list = months.map((m) => '$m $year').toList();
    if (billingMonth.isNotEmpty && !list.contains(billingMonth)) {
      list.insert(0, billingMonth);
    }
    return list;
  }

  Widget _buildConfigurationCard(
    BuildContext context,
    VoucherGenFilters filters,
    int readyCount,
    int generatedCount,
    bool isGenerating, {
    int columnCount = 1,
  }) {
    final classesAsync = ref.watch(classesProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final bankListAsync = ref.watch(voucherBankListProvider);
    final availableSessionsAsync = ref.watch(availableSessionsProvider);

    final availableSessions =
        availableSessionsAsync.valueOrNull ?? const <String>[];
    final effectiveSessions = <String>{
      if (filters.sessionYr.isNotEmpty) filters.sessionYr,
      ...availableSessions,
      '2017-2018',
    }.toList()..sort((a, b) => b.compareTo(a));

    final classList = classesAsync.valueOrNull ?? const <SchoolClass>[];
    final classesData = classList
        .map((c) => (id: c.classId, label: c.cName))
        .toList();

    final sectionList = sectionsAsync.valueOrNull ?? const <ClassSec>[];
    final filteredSections = filters.classId == null
        ? sectionList
        : sectionList.where((s) => s.classId == filters.classId).toList();
    final sectionsData = filteredSections
        .map((s) => (id: s.classSecId, label: s.secName))
        .toList();

    final bankList = bankListAsync.valueOrNull ?? const <BankOption>[];
    final banksData = bankList
        .map((b) => (id: b.bankInfoId, label: '${b.bankName} - ${b.branch}'))
        .toList();

    final effectiveBillingMonths = _effectiveBillingMonths(
      filters.billingMonth,
      filters.sessionYr,
    );

    return SingleChildScrollView(
      child: Container(
        decoration: _cardDecoration(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Batch Generation Parameters',
              style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            VoucherParameterCard(
              sessionYear: filters.sessionYr,
              sessionYears: effectiveSessions,
              sessionYearError: _hasValidated && filters.sessionYr.isEmpty
                  ? 'Select a session year'
                  : null,
              billingMonth: filters.billingMonth,
              billingMonths: effectiveBillingMonths,
              billingMonthError: _hasValidated && filters.billingMonth.isEmpty
                  ? 'Select a billing month'
                  : null,
              classId: filters.classId,
              classes: classesData,
              classError: _hasValidated && filters.classId == null
                  ? 'Select a class to continue'
                  : null,
              sectionId: filters.classSecId,
              sections: sectionsData,
              issueDate: filters.issueDate,
              issueDateError: null,
              dueDate: filters.dueDate,
              dueDateError: filters.dueDate.isBefore(filters.issueDate)
                  ? 'Due date must be on or after the issue date'
                  : null,
              bankId: filters.bankId,
              banks: banksData,
              bankError: null,
              columnCount: columnCount,
              onSessionYearChanged: (val) {
                ref.read(voucherGenFiltersProvider.notifier).setSessionYr(val);
              },
              onBillingMonthChanged: (val) {
                ref
                    .read(voucherGenFiltersProvider.notifier)
                    .setBillingMonth(val);
              },
              onClassChanged: (val) {
                ref.read(voucherGenFiltersProvider.notifier).setClassId(val);
              },
              onSectionChanged: (val) {
                ref.read(voucherGenFiltersProvider.notifier).setClassSecId(val);
              },
              onIssueDateChanged: (val) {
                ref.read(voucherGenFiltersProvider.notifier).setIssueDate(val);
              },
              onDueDateChanged: (val) {
                ref.read(voucherGenFiltersProvider.notifier).setDueDate(val);
              },
              onBankChanged: (val) {
                if (val != null) {
                  ref.read(voucherGenFiltersProvider.notifier).setBankId(val);
                }
              },
              onPickIssueDate: () => _pickDate(
                context,
                filters.issueDate,
                (d) => ref
                    .read(voucherGenFiltersProvider.notifier)
                    .setIssueDate(d),
              ),
              onPickDueDate: () => _pickDate(
                context,
                filters.dueDate,
                (d) =>
                    ref.read(voucherGenFiltersProvider.notifier).setDueDate(d),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT CARD — COHORT BILLING AUDIT & LEDGER PREVIEW
  // ---------------------------------------------------------------------------

  VoucherResultKind _resultKindFor(BatchGenerationSummary s) {
    if (s.generatedCount == 0) return VoucherResultKind.cancelled;
    final total = ref.read(voucherGenExecutionProvider).totalToGenerate;
    final effectiveTotal =
        total > 0 ? total : (s.generatedCount + s.skippedCount);
    if (s.generatedCount >= effectiveTotal) return VoucherResultKind.success;
    return VoucherResultKind.partial;
  }

  Widget _buildVoucherProgressPanel(VoucherGenState execState) {
    final total = execState.totalToGenerate;
    final done = execState.generatedCount;
    final progress = total > 0 ? done / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Creating vouchers… $done of $total',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cancel not supported'),
                    ),
                  );
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceSubtle,
              valueColor: const AlwaysStoppedAnimation(AppColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherResultPanel(BatchGenerationSummary s) {
    final total = ref.read(voucherGenExecutionProvider).totalToGenerate;
    final effectiveTotal =
        total > 0 ? total : (s.generatedCount + s.skippedCount);
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: VoucherResultPanel(
        kind: _resultKindFor(s),
        createdCount: s.generatedCount,
        totalCount: effectiveTotal,
        totalAmount: s.totalBilled,
        onPrintAll: () => _openPrintPreview(),
        onSavePdf: () {
          // Dev-1 in spec: PDF generators return Uint8List, no save path.
          // Route Save PDF to print preview for now.
          _openPrintPreview();
        },
        onShare: null,
        onGenerateAnother: _onEscape,
        onResumeRemaining:
            (s.generatedCount > 0 && s.generatedCount < effectiveTotal)
                ? _onGenerate
                : null,
      ),
    );
  }

  Widget _buildPreviewPane(
    BuildContext context,
    VoucherGenFilters filters,
    AsyncValue<List<VoucherPreviewRow>> previewAsync,
    List<VoucherPreviewRow> previewList,
    int eligibleCount,
    int waiverCount,
    String displayLabel,
    int displayBilled,
    int readyCount,
    int generatedCount,
    VoucherGenState execState,
  ) {
    if (execState.completionSummary != null) {
      return _buildVoucherResultPanel(execState.completionSummary!);
    }

    return _buildPreviewCard(
      previewAsync,
      previewList,
      eligibleCount,
      waiverCount,
      displayLabel,
      displayBilled,
      readyCount,
      generatedCount,
    );
  }

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
    final execState = ref.watch(voucherGenExecutionProvider);
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

    final tariffsAsync = ref.watch(
      voucherClassTariffsProvider(filters.classId),
    );
    final feeHeadList = tariffsAsync.valueOrNull ?? const <FeeHeadSummary>[];
    final heads = feeHeadList.map((t) {
      final isChecked = !filters.excludedFeeParamIds.contains(t.feeParamId);
      return FeeHeadItem(
        feeParamId: t.feeParamId,
        name: t.description.trim(),
        amount: t.fee.toInt(),
        isChecked: isChecked,
      );
    }).toList();

    final noTariffMsg = (filters.classId == null)
        ? 'Select a class to configure fee heads'
        : (feeHeadList.isEmpty && !tariffsAsync.isLoading
              ? 'No fees set up for this class.'
              : null);

    final errorMsg = tariffsAsync.hasError ? "Couldn't load fee heads." : null;

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
              if (generatedCount > 0) ...[
                ElevatedButton.icon(
                  onPressed: () => _openPrintPreview(),
                  icon: const Icon(Icons.print, size: 16),
                  label: Text('Print $generatedCount Vouchers (Ctrl+P)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: execState.isGenerating
                      ? null
                      : _onRegenerateUnpaid,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                    side: const BorderSide(color: AppColors.brandPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ] else ...[
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

          if (hasDrift) ...[
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
          ],

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
          const SizedBox(height: AppSpacing.sm),

          // Fee heads accordion at bottom of preview pane
          FeeHeadsAccordion(
            heads: heads,
            isLoading: tariffsAsync.isLoading,
            errorMessage: errorMsg,
            noTariffMessage: noTariffMsg,
            onToggleHead: (id) =>
                ref.read(voucherGenFiltersProvider.notifier).toggleFeeHead(id),
            onRetry: () =>
                ref.invalidate(voucherClassTariffsProvider(filters.classId)),
            onOpenFeeParams: () => context.go('/fees/parameters'),
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
                final filters = ref.read(voucherGenFiltersProvider);
                final all = await _loadGeneratedVouchers();
                final match = all
                    .where(
                      (r) =>
                          r.stuRegId == row.stuRegId &&
                          r.forMonth == filters.billingMonth,
                    )
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
  // COMPACT (<600) LAYOUT
  // ---------------------------------------------------------------------------

  Widget _buildCompactLayout(
    BuildContext context,
    VoucherGenFilters filters,
    AsyncValue<List<VoucherPreviewRow>> previewAsync,
    List<VoucherPreviewRow> previewList,
    int eligibleCount,
    int waiverCount,
    String displayLabel,
    int displayBilled,
    int readyCount,
    int generatedCount,
    VoucherGenState execState,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Vouchers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final from = _getFromOrigin(context);
            if (from != null && from.isNotEmpty) {
              context.go(from);
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/fees/ledger');
            }
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'collect') {
                context.go('/fees/receipts?from=vouchers');
              } else if (val == 'ledger') {
                context.go('/fees/ledger');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'collect',
                child: Row(
                  children: [
                    Icon(Icons.point_of_sale_outlined, size: 16),
                    SizedBox(width: AppSpacing.sm),
                    Text('Collect Fee'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'ledger',
                child: Row(
                  children: [
                    Icon(Icons.assessment_outlined, size: 16),
                    SizedBox(width: AppSpacing.sm),
                    Text('View Full Ledger'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCompactModeSwitch(filters),
                  const SizedBox(height: AppSpacing.xs),
                  _buildCompactStepIndicator(execState, previewList),
                  const SizedBox(height: AppSpacing.sm),
                  _buildCompactParamSummary(
                    context: context,
                    filters: filters,
                    onEdit: () => _openParamSheet(
                      context,
                      filters,
                      readyCount,
                      generatedCount,
                      execState.isGenerating,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildCompactPreviewPane(
                    context,
                    filters,
                    previewAsync,
                    previewList,
                    eligibleCount,
                    waiverCount,
                    displayLabel,
                    displayBilled,
                    readyCount,
                    generatedCount,
                    execState,
                  ),
                ],
              ),
            ),
          ),
          if (execState.isGenerating)
            _buildVoucherProgressPanel(execState)
          else
            VoucherActionBar(
              impactState: execState.error != null
                  ? VoucherImpactState.error
                  : (eligibleCount == 0
                        ? VoucherImpactState.zero
                        : VoucherImpactState.normal),
              count: eligibleCount,
              errorText: execState.error,
              isGenerating: execState.isGenerating,
              onGenerate: (eligibleCount > 0 && !execState.isGenerating)
                  ? () => _handleGenerateTrigger(eligibleCount)
                  : null,
            ),
        ],
      ),
    );
  }



  Widget _buildCompactModeSwitch(VoucherGenFilters filters) {
    final isBatch = filters.mode == 'batch';
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                ref.read(voucherGenFiltersProvider.notifier).setMode('batch');
                ref.read(voucherGenExecutionProvider.notifier).clearSummary();
              },
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isBatch ? AppColors.surfaceRaised : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: isBatch
                      ? const [
                          BoxShadow(
                            color: Color(0x0A0F172A),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dynamic_feed_outlined,
                      size: 16,
                      color: isBatch
                          ? AppColors.brandPrimary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Batch',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: isBatch ? FontWeight.w600 : FontWeight.normal,
                        color: isBatch
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                ref.read(voucherGenFiltersProvider.notifier).setMode('single');
                ref.read(voucherGenExecutionProvider.notifier).clearSummary();
              },
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isBatch ? AppColors.surfaceRaised : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: !isBatch
                      ? const [
                          BoxShadow(
                            color: Color(0x0A0F172A),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: !isBatch
                          ? AppColors.brandPrimary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Single',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: !isBatch ? FontWeight.w600 : FontWeight.normal,
                        color: !isBatch
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStepIndicator(
    VoucherGenState execState,
    List<VoucherPreviewRow> previewList,
  ) {
    final filters = ref.watch(voucherGenFiltersProvider);
    final int activeIndex;
    if (execState.completionSummary != null) {
      activeIndex = 3;
    } else if (execState.isGenerating) {
      activeIndex = 2;
    } else if (filters.classId != null || previewList.isNotEmpty) {
      activeIndex = 1;
    } else {
      activeIndex = 0;
    }

    const steps = ['Select', 'Preview', 'Confirm', 'Print'];

    return Container(
      height: 32,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Container(
                width: 16,
                height: 2,
                color: i <= activeIndex
                    ? AppColors.brandPrimary
                    : AppColors.borderDefault,
              ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= activeIndex
                    ? AppColors.brandPrimary
                    : AppColors.surfaceSubtle,
                border: Border.all(
                  color: i <= activeIndex
                      ? AppColors.brandPrimary
                      : AppColors.borderDefault,
                  width: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Step ${activeIndex + 1}: ${steps[activeIndex]}',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactParamSummary({
    required BuildContext context,
    required VoucherGenFilters filters,
    required VoidCallback onEdit,
  }) {
    final classesAsync = ref.watch(classesProvider);
    final classes = classesAsync.valueOrNull ?? [];
    final matchClass = classes
        .where((c) => c.classId == filters.classId)
        .firstOrNull;
    final classLabel =
        matchClass?.cName ??
        (filters.classId == null ? 'Select Class' : 'Class ${filters.classId}');

    final sectionsAsync = ref.watch(sectionsProvider);
    final sections = sectionsAsync.valueOrNull ?? [];
    final matchSec = sections
        .where((s) => s.classSecId == filters.classSecId)
        .firstOrNull;
    final sectionLabel = filters.classSecId == null
        ? 'All Sections'
        : (matchSec?.secName ?? 'Section ${filters.classSecId}');

    final bankListAsync = ref.watch(voucherBankListProvider);
    final bankList = bankListAsync.valueOrNull ?? [];
    final matchBank = bankList
        .where((b) => b.bankInfoId == filters.bankId)
        .firstOrNull;
    final bankLabel = matchBank != null
        ? '${matchBank.bankName} - ${matchBank.branch}'
        : 'Bank: None';

    final title = '$classLabel · $sectionLabel · ${filters.billingMonth}';

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bankLabel,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPreviewPane(
    BuildContext context,
    VoucherGenFilters filters,
    AsyncValue<List<VoucherPreviewRow>> previewAsync,
    List<VoucherPreviewRow> previewList,
    int eligibleCount,
    int waiverCount,
    String displayLabel,
    int displayBilled,
    int readyCount,
    int generatedCount,
    VoucherGenState execState,
  ) {
    if (execState.completionSummary != null) {
      return _buildVoucherResultPanel(execState.completionSummary!);
    }

    final tariffsAsync = ref.watch(
      voucherClassTariffsProvider(filters.classId),
    );
    final feeHeadList = tariffsAsync.valueOrNull ?? const <FeeHeadSummary>[];
    final heads = _buildFeeHeadItems(feeHeadList, filters);

    final noTariffMsg = (filters.classId == null)
        ? 'Select a class to configure fee heads'
        : (feeHeadList.isEmpty && !tariffsAsync.isLoading
              ? 'No fees set up for this class.'
              : null);

    final errorMsg = tariffsAsync.hasError ? "Couldn't load fee heads." : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Preview (${previewList.length})',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () => ref.invalidate(voucherGenPreviewProvider),
                    tooltip: 'Re-calculate',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactKpi(
                      label: 'Eligible',
                      value: '$eligibleCount',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _buildCompactKpi(
                      label: 'Waivers',
                      value: '$waiverCount',
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _buildCompactKpi(
                      label: 'Total',
                      value: 'Rs. ${currencyFormat.format(displayBilled)}',
                      color: AppColors.statusSuccessText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (previewAsync.isLoading) ...[
          Container(
            height: 100,
            alignment: Alignment.center,
            decoration: _cardDecoration(),
            child: const CircularProgressIndicator(),
          ),
        ] else if (previewList.isEmpty) ...[
          Container(
            height: 90,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: _cardDecoration(),
            child: Text(
              filters.classId == null
                  ? 'Select a class to preview vouchers'
                  : 'No students found for selected criteria',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ] else ...[
          for (int i = 0; i < previewList.length; i++) ...[
            _buildCompactStudentRow(previewList[i]),
            if (i < previewList.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
        const SizedBox(height: AppSpacing.sm),
        FeeHeadsAccordion(
          heads: heads,
          isLoading: tariffsAsync.isLoading,
          errorMessage: errorMsg,
          noTariffMessage: noTariffMsg,
          onToggleHead: (id) =>
              ref.read(voucherGenFiltersProvider.notifier).toggleFeeHead(id),
          onRetry: () =>
              ref.invalidate(voucherClassTariffsProvider(filters.classId)),
          onOpenFeeParams: () => context.go('/fees/parameters'),
        ),
      ],
    );
  }

  Widget _buildCompactKpi({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.monospace.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStudentRow(VoucherPreviewRow row) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          _buildStatusDot(row.status),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  row.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  row.voucherId,
                  style: AppTypography.monospace.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rs. ${currencyFormat.format(row.netPayable)}',
                style: AppTypography.monospace.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              if (row.discount > 0)
                Text(
                  '-${currencyFormat.format(row.discount)} off',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: AppColors.statusSuccessText,
                  ),
                )
              else if (row.arrears > 0)
                Text(
                  '+${currencyFormat.format(row.arrears)} arr',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: AppColors.statusWarningText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(VoucherPreviewStatus status) {
    final Color color;
    switch (status) {
      case VoucherPreviewStatus.ready:
        color = AppColors.statusSuccessText;
      case VoucherPreviewStatus.alreadyGenerated:
        color = AppColors.textMuted;
      case VoucherPreviewStatus.fullWaiver:
        color = AppColors.brandPrimary;
      case VoucherPreviewStatus.arrearsRollover:
        color = AppColors.statusWarningText;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  List<FeeHeadItem> _buildFeeHeadItems(
    List<FeeHeadSummary> tariffs,
    VoucherGenFilters filters,
  ) {
    return tariffs.map((t) {
      final isChecked = !filters.excludedFeeParamIds.contains(t.feeParamId);
      return FeeHeadItem(
        feeParamId: t.feeParamId,
        name: t.description.trim(),
        amount: t.fee.toInt(),
        isChecked: isChecked,
      );
    }).toList();
  }

  void _openParamSheet(
    BuildContext context,
    VoucherGenFilters filters,
    int readyCount,
    int generatedCount,
    bool isGenerating,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.9,
          decoration: const BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Batch Generation Parameters',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderDefault),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Consumer(
                    builder: (c, ref, _) {
                      final currentFilters =
                          ref.watch(voucherGenFiltersProvider);
                      return _buildConfigurationCard(
                        c,
                        currentFilters,
                        readyCount,
                        generatedCount,
                        isGenerating,
                        columnCount: 1,
                      );
                    },
                  ),
                ),
              ),
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceRaised,
                  border: Border(
                    top: BorderSide(color: AppColors.borderDefault),
                  ),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String? _getFromOrigin(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.queryParameters['from'];
  } catch (_) {
    return null;
  }
}
