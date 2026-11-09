import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/salary_management_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/salary_slip_row.dart';
import '../../widgets/mobile/mobile_kpi_card.dart';
import '../../widgets/mobile/mobile_status_pill.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

/// Screen 22 — SalaryManagementScreen at `/staff/salary`.
/// Implements §S24 (`frmTSal` at `0x00428b50`, `ObjID: 22`).
class SalaryManagementScreen extends ConsumerStatefulWidget {
  final int? fromTeacherId;

  const SalaryManagementScreen({super.key, this.fromTeacherId});

  @override
  ConsumerState<SalaryManagementScreen> createState() =>
      _SalaryManagementScreenState();
}

class _SalaryManagementScreenState
    extends ConsumerState<SalaryManagementScreen> {
  static const List<Color> _avatarPalette = [
    Color(0xFFE0F2FE), // Soft Sky
    Color(0xFFFCE7F3), // Soft Pink
    Color(0xFFEDE9FE), // Soft Lavender
  ];

  final TextEditingController _deductionsController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  final ScrollController _rosterScrollController = ScrollController();
  final ScrollController _allowanceScrollController = ScrollController();

  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _deductionsController.addListener(_onDeductionsChanged);
    _remarksController.addListener(_onRemarksChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      int? queryTeacherId = widget.fromTeacherId;
      final uri = GoRouterState.of(context).uri;
      final fromStr = uri.queryParameters['fromTeacherId'];
      if (fromStr != null) {
        queryTeacherId = int.tryParse(fromStr);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final s = ref.read(salaryManagementProvider);
          if (s.roster.isEmpty) {
            ref
                .read(salaryManagementProvider.notifier)
                .loadInitialData(autoSelectTeacherId: queryTeacherId);
          } else if (queryTeacherId != null &&
              s.selectedTeacherId != queryTeacherId) {
            ref
                .read(salaryManagementProvider.notifier)
                .selectEmployee(queryTeacherId);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _deductionsController.removeListener(_onDeductionsChanged);
    _remarksController.removeListener(_onRemarksChanged);
    _deductionsController.dispose();
    _remarksController.dispose();
    _rosterScrollController.dispose();
    _allowanceScrollController.dispose();
    super.dispose();
  }

  void _onDeductionsChanged() {
    final text = _deductionsController.text.trim();
    final val = double.tryParse(text) ?? 0.0;
    final currentVal = ref.read(salaryManagementProvider).draftDeductions;
    if (val != currentVal) {
      ref.read(salaryManagementProvider.notifier).updateDeductions(val);
    }
  }

  void _onRemarksChanged() {
    final text = _remarksController.text;
    final currentText = ref.read(salaryManagementProvider).draftRemarks;
    if (text != currentText) {
      ref.read(salaryManagementProvider.notifier).updateRemarks(text);
    }
  }

  void _handleCommit() {
    final session = ref.read(sessionProvider);
    final userLvl = session?.user.userLevel ?? 1;
    ref.read(salaryManagementProvider.notifier).commitSlip(userLvl: userLvl);
  }

  void _handlePrint([SalarySlipRow? optionalRow]) {
    final state = ref.read(salaryManagementProvider);
    final row = optionalRow ?? state.selectedTeacher;

    if (row == null || (optionalRow == null && state.selectedSlipId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Salary Slip to Print '),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final meta = ref.read(shellMetadataProvider).valueOrNull;
    final salaryData = <String, dynamic>{
      'teacherName': row.teacherName,
      'gross': row.paidAmt ?? row.grossFromDet,
      'deductions': row.tDeductions ?? 0,
      'net': row.netAmount,
      'month': row.salMonth,
      'paidDate': row.paidDate ?? row.disbursDate ?? '',
      'designation': row.teacherCat ?? 'Staff',
      'cnic': row.teacherCnic ?? '',
    };

    ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.salarySlip,
        titleOverride: 'Salary Slip - ${row.teacherName}',
        extraParams: {
          'salaryData': salaryData,
          'branchName': meta?.branchName ?? "Ailyans's Higher Secondary School",
          'branchAddress': meta?.branchAddress ?? 'Muslim Bazar Mianwali',
        },
      ),
    );
  }

  void _handlePrintRegister() {
    final meta = ref.read(shellMetadataProvider).valueOrNull;
    final state = ref.read(salaryManagementProvider);

    if (state.roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No payroll records to print for this month'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final salaries = state.roster
        .map(
          (r) => <String, dynamic>{
            'teacherName': r.teacherName,
            'name': r.teacherName,
            'gross': r.paidAmt ?? r.grossFromDet,
            'paidAmt': r.paidAmt ?? r.grossFromDet,
            'deductions': r.tDeductions ?? 0,
            'tDeductions': r.tDeductions ?? 0,
            'net': r.netAmount,
            'netAmount': r.netAmount,
            'paidDate': r.paidDate ?? r.disbursDate ?? '',
            'isPaid': r.isPaid,
          },
        )
        .toList();

    ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.salaryRegister,
        titleOverride: 'Salary Register - ${state.selectedMonth}',
        extraParams: {
          'salaries': salaries,
          'month': state.selectedMonth,
          'branchName': meta?.branchName ?? "Ailyans's Higher Secondary School",
          'branchAddress': meta?.branchAddress ?? 'Muslim Bazar Mianwali',
        },
      ),
    );
  }

  void _handleLoadCohort() {
    ref.read(salaryManagementProvider.notifier).loadPayrollCohort();
  }

  void _handleDiscard() {
    ref.read(salaryManagementProvider.notifier).discardSlip();
    _deductionsController.text = '0';
    _remarksController.text = '';
  }

  Future<void> _handleRowTap(SalarySlipRow row) async {
    final state = ref.read(salaryManagementProvider);
    final notifier = ref.read(salaryManagementProvider.notifier);

    if (state.selectedTeacherId == row.teacherId) return;

    if (state.isDirty) {
      final currentName = state.selectedTeacher?.teacherName ?? 'Employee';
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text('Discard Unsaved Changes?'),
          content: Text('Discard unsaved changes to $currentName?'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }

    await notifier.selectEmployee(row.teacherId);
    final newState = ref.read(salaryManagementProvider);
    _deductionsController.text = newState.draftDeductions == 0.0
        ? '0'
        : (newState.draftDeductions % 1 == 0
              ? newState.draftDeductions.toInt().toString()
              : newState.draftDeductions.toString());
    _remarksController.text = newState.draftRemarks;
  }

  Future<void> _showBatchDisburseDialog() async {
    final state = ref.read(salaryManagementProvider);
    final notifier = ref.read(salaryManagementProvider.notifier);
    final session = ref.read(sessionProvider);
    final userLvl = session?.user.userLevel ?? 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Confirm Batch Disburse'),
        content: Text(
          'Disburse all pending salary slips for ${state.selectedMonth}? This cannot be undone.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.batchDisbursePending(userLvl: userLvl);
    }
  }

  Future<void> _showAddAllowanceModal() async {
    final state = ref.read(salaryManagementProvider);
    final notifier = ref.read(salaryManagementProvider.notifier);

    int? selectedParamId = state.availableSalParams.isNotEmpty
        ? (state.availableSalParams.first['SalParamID'] as num?)?.toInt()
        : 1;
    final amountController = TextEditingController(text: '1000');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text(
            'Add Allowance Head',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Allowance Head',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedParamId,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceRaised,
                      items: state.availableSalParams.map((p) {
                        final id = (p['SalParamID'] as num).toInt();
                        final name = p['SalParam']?.toString() ?? 'Allowance';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedParamId = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Amount (Rs.)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: 'Rs. ',
                      prefixStyle: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
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
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
              ),
              onPressed: () {
                final amt = double.tryParse(amountController.text) ?? 0.0;
                if (selectedParamId != null && amt > 0) {
                  notifier.addAllowanceHead(selectedParamId!, amt);
                  Navigator.of(dialogCtx).pop();
                }
              },
              child: const Text('Add Head'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salaryManagementProvider);
    final notifier = ref.read(salaryManagementProvider.notifier);

    // Sync controllers on external state updates if not typing
    ref.listen<SalaryManagementState>(salaryManagementProvider, (prev, next) {
      if (prev?.selectedTeacherId != next.selectedTeacherId) {
        _deductionsController.text = next.draftDeductions == 0.0
            ? '0'
            : (next.draftDeductions % 1 == 0
                  ? next.draftDeductions.toInt().toString()
                  : next.draftDeductions.toString());
        _remarksController.text = next.draftRemarks;
      }
      if (next.toast != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            backgroundColor: AppColors.statusSuccessText,
            duration: const Duration(seconds: 2),
          ),
        );
        notifier.clearToast();
      }
    });

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileScaffold(context, state, notifier);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleCommit,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _handleCommit,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _handlePrint,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
            _handlePrint,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _handleLoadCohort,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            _handleLoadCohort,
        const SingleActivator(LogicalKeyboardKey.escape): _handleDiscard,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // a) Header row (~52px)
              _buildHeader(context, notifier),

              // Error banner if any
              if (state.errorMessage != null)
                _buildErrorBanner(state.errorMessage!, notifier),

              // b) Filter strip (~52px)
              _buildFilterStrip(context, state, notifier),

              // c) KPI cards row (~76px)
              _buildKpiStrip(state),

              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderDefault,
              ),

              // d) Two-column split (Expanded, 55/45)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT (payroll register, flex: 11)
                    Expanded(flex: 11, child: _buildLeftRegister(state)),

                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.borderDefault,
                    ),

                    // RIGHT (single employee slip drawer, flex: 9)
                    Expanded(
                      flex: 9,
                      child: _buildRightSlipDrawer(state, notifier),
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

  Widget _buildHeader(BuildContext context, SalaryManagementNotifier notifier) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 20,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: 10),
          const Text(
            'Staff Payroll & Salary Disbursement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => notifier.loadPayrollCohort(),
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text(
              'Load Payroll Cohort (Ctrl+L)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textOnPrimary,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message, SalaryManagementNotifier notifier) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.statusErrorBg,
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.statusErrorText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.statusErrorText,
            ),
            onPressed: notifier.clearErrorMessage,
            tooltip: 'Dismiss error',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStrip(
    BuildContext context,
    SalaryManagementState state,
    SalaryManagementNotifier notifier,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateDisplay = dateFormat.format(state.disbursementDate);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          // Month dropdown
          const Text(
            'Month:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.availableMonths.contains(state.selectedMonth)
                    ? state.selectedMonth
                    : null,
                hint: Text(state.selectedMonth),
                isDense: true,
                menuMaxHeight: 400,
                dropdownColor: AppColors.surfaceRaised,
                items: state.availableMonths.map((m) {
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Text(
                      m,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) notifier.setMonth(val);
                },
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Disburse Date
          const Text(
            'Disburse Date:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.disbursementDate,
                firstDate: DateTime(2015),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                notifier.setDisbursementDate(picked);
              }
            },
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Category dropdown
          const Text(
            'Category:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.categoryFilter,
                isDense: true,
                menuMaxHeight: 400,
                dropdownColor: AppColors.surfaceRaised,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
                  DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                  DropdownMenuItem(
                    value: 'Principal',
                    child: Text('Principal'),
                  ),
                  DropdownMenuItem(value: 'V-P', child: Text('V-P')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setCategoryFilter(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(SalaryManagementState state) {
    final currencyFormat = NumberFormat('#,##0');

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          _buildKpiCard(
            title: 'Total Eligible Staff',
            value: '${state.totalEligibleStaff}',
            subtitle: 'Active roster members',
            icon: Icons.people_outline,
            accentColor: AppColors.brandPrimary,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            title: 'Gross Payroll',
            value: 'Rs. ${currencyFormat.format(state.grossPayroll)}',
            subtitle: 'Base + allowances',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: AppColors.statusInfoText,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            title: 'Total Deductions',
            value: 'Rs. ${currencyFormat.format(state.totalDeductions)}',
            subtitle: 'Fines, leaves, loans',
            icon: Icons.remove_circle_outline,
            accentColor: AppColors.statusWarningText,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            title: 'Net Disbursed',
            value: 'Rs. ${currencyFormat.format(state.netDisbursed)}',
            subtitle: 'Total settled pay',
            icon: Icons.check_circle_outline,
            accentColor: AppColors.statusSuccessText,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftRegister(SalaryManagementState state) {
    final currency = NumberFormat('#,##0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Register header bar
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: AppColors.surfaceRaised,
            border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'PAYROLL REGISTER: ${state.selectedMonth}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _handlePrintRegister,
                icon: const Icon(Icons.print_outlined, size: 12),
                label: const Text(
                  'Print Register',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 26),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.roster.any((r) => r.isPending)
                    ? _showBatchDisburseDialog
                    : null,
                icon: const Icon(Icons.flash_on, size: 12),
                label: const Text(
                  'Disburse All Pending',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 26),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),

        // Table headers
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: AppColors.surfaceSubtle,
          child: const Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Slip ID',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Staff Name',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  'Gross',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  'Deductions',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 95,
                child: Text(
                  'Net',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 75,
                child: Text(
                  'Status',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 40),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: state.roster.isEmpty
              ? const Center(
                  child: Text(
                    'Select month + category, then click [Load Payroll Cohort]',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : Scrollbar(
                  controller: _rosterScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _rosterScrollController,
                    itemCount: state.roster.length,
                    itemExtent: 40,
                    itemBuilder: (context, index) {
                      final row = state.roster[index];
                      final isSelected =
                          row.teacherId == state.selectedTeacherId;
                      final gross = row.grossFromDet > 0
                          ? row.grossFromDet
                          : ((row.paidAmt ?? 0) + (row.tDeductions ?? 0));
                      final net = row.paidAmt ?? 0;
                      final deductions = row.tDeductions ?? 0;

                      return InkWell(
                        onTap: () => _handleRowTap(row),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary.withValues(alpha: 0.08)
                                : (index.isEven
                                      ? AppColors.surface
                                      : AppColors.surfaceSubtle.withValues(
                                          alpha: 0.5,
                                        )),
                            border: Border(
                              bottom: const BorderSide(
                                color: AppColors.borderDefault,
                                width: 0.5,
                              ),
                              left: isSelected
                                  ? const BorderSide(
                                      color: AppColors.brandPrimary,
                                      width: 3,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  row.tSalMasId ?? '—',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'JetBrainsMono',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  row.teacherName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: _buildCategoryBadge(row.teacherCat),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  row.isPaid == 'Y' || gross > 0
                                      ? 'Rs. ${currency.format(gross)}'
                                      : '—',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'JetBrainsMono',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  row.isPaid == 'Y' || deductions > 0
                                      ? 'Rs. ${currency.format(deductions)}'
                                      : '—',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'JetBrainsMono',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 95,
                                child: Text(
                                  row.isPaid == 'Y' || net > 0
                                      ? 'Rs. ${currency.format(net)}'
                                      : '—',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'JetBrainsMono',
                                    fontWeight: FontWeight.bold,
                                    color: row.isPaid == 'Y'
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 75,
                                child: Center(
                                  child: _buildStatusBadge(row.isPaid == 'Y'),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                  icon: const Icon(Icons.edit_note, size: 16),
                                  tooltip: 'Itemize salary slip',
                                  onPressed: () => _handleRowTap(row),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRightSlipDrawer(
    SalaryManagementState state,
    SalaryManagementNotifier notifier,
  ) {
    if (state.selectedTeacherId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'Select an employee to review or disburse salary',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final teacher = state.selectedTeacher;
    final teacherId = state.selectedTeacherId!;
    final avatarColor = _avatarPalette[teacherId.abs() % _avatarPalette.length];
    final currency = NumberFormat('#,##0');

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Staff Identity Card (fixed ~100px)
          _buildStaffCard(state, teacher, avatarColor),

          const SizedBox(height: 12),

          // 2. Allowance Items section - EXPANDED to fill middle
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Allowance Heads',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${state.draftAllowances.length} items',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.borderDefault),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          color: AppColors.surfaceSubtle,
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '#',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Allowance Head',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'Amount Rs',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 40),
                            ],
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.borderDefault,
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: _allowanceScrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _allowanceScrollController,
                              itemCount: state.draftAllowances.length,
                              itemExtent: 36,
                              itemBuilder: (context, index) {
                                final item = state.draftAllowances[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index.isEven
                                        ? AppColors.surface
                                        : AppColors.surfaceSubtle.withValues(
                                            alpha: 0.4,
                                          ),
                                    border: const Border(
                                      bottom: BorderSide(
                                        color: AppColors.borderDefault,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 30,
                                        child: Text(
                                          '${item.ser}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'JetBrainsMono',
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.detail,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          'Rs. ${currency.format(item.amount)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'JetBrainsMono',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 40,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 15,
                                            color: AppColors.statusErrorText,
                                          ),
                                          tooltip: 'Remove allowance',
                                          onPressed: () => notifier
                                              .removeAllowanceHead(item.ser),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _showAddAllowanceModal,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text(
                      'Add Allowance Head',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Financial Settlement card (fixed ~150px)
          _buildFinancialCard(state, currency),

          const SizedBox(height: 12),

          // 4. Pinned bottom actions (fixed ~52px)
          _buildBottomActions(state),
        ],
      ),
    );
  }

  Widget _buildStaffCard(
    SalaryManagementState state,
    dynamic teacher,
    Color avatarColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Center(
              child: Text(
                _computeInitials(teacher?.teacherName ?? 'T'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        teacher?.teacherName ?? 'Staff Member',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildCategoryBadge(teacher?.teacherCat),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'S/O ${teacher?.fatherName ?? '—'} | ID #${teacher?.teacherId} | CNIC: ${teacher?.teacherCnic ?? '—'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Slip: ${state.selectedSlipId ?? "Pending (New)"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(
    SalaryManagementState state,
    NumberFormat currency,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gross Earnings:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Rs. ${currency.format(state.grossEarnings)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Deductions:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(
                width: 140,
                height: 30,
                child: TextField(
                  controller: _deductionsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'JetBrainsMono',
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rs. ',
                    prefixStyle: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.textSecondary,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(
                        color: AppColors.borderDefault,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NET PAYABLE:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Rs. ${currency.format(state.netPayable)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: TextField(
              controller: _remarksController,
              maxLines: 1,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Disbursement remarks & notes...',
                hintStyle: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(SalaryManagementState state) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _handleCommit,
              icon: const Icon(Icons.check, size: 14),
              label: const Text(
                'Commit & Disburse Slip (Ctrl+S)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.textOnPrimary,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _handlePrint,
              icon: const Icon(Icons.print, size: 13),
              label: const Text(
                'Print Salary Slip (Ctrl+P)',
                style: TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _handleDiscard,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Discard Slip', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String? category) {
    Color bg;
    Color text;

    switch (category?.trim()) {
      case 'Principal':
        bg = AppColors.brandPrimary.withValues(alpha: 0.20);
        text = AppColors.brandPrimary;
        break;
      case 'Teacher':
        bg = AppColors.statusSuccessBg;
        text = AppColors.statusSuccessText;
        break;
      case 'Staff':
      default:
        bg = AppColors.surfaceSubtle;
        text = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        category?.trim().isEmpty ?? true ? 'Staff' : category!.trim(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: category == 'Principal'
              ? FontWeight.w700
              : FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isPaid) {
    final bg = isPaid ? AppColors.statusSuccessBg : AppColors.statusWarningBg;
    final text = isPaid
        ? AppColors.statusSuccessText
        : AppColors.statusWarningText;
    final label = isPaid ? 'Paid' : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  String _computeInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'T';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ===========================================================================
  // G-6b MOBILE BRANCH (< 600px)
  // ===========================================================================
  Widget _buildMobileScaffold(
    BuildContext context,
    SalaryManagementState state,
    SalaryManagementNotifier notifier,
  ) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleCommit,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _handleCommit,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _handlePrint,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
            _handlePrint,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _handleLoadCohort,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            _handleLoadCohort,
        const SingleActivator(LogicalKeyboardKey.escape): _handleDiscard,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                        _buildMobileHeader(context, notifier),
                        const SizedBox(height: AppSpacing.sm),
                        if (state.errorMessage != null) ...[
                          _buildMobileErrorBanner(
                            state.errorMessage!,
                            notifier,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        _buildMobileFilterBar(context, state, notifier),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileKpiGrid(state),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileRosterSection(context, state, notifier),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileSlipSection(context, state, notifier),
                        if (state.selectedTeacherId != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _buildMobileFooter(context, state),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildMobileStickyBottomBar(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileStickyBottomBar(
    BuildContext context,
    SalaryManagementState state,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: (state.isSaving || state.roster.isEmpty)
              ? null
              : _handleCommit,
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: Text(
            state.selectedTeacherId != null
                ? 'Save Salary Disbursement'
                : 'Generate Payslip',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentStaff,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    SalaryManagementNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.payments_outlined,
              size: 20,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Staff Payroll & Salary Disbursement',
                style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () => notifier.loadPayrollCohort(),
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text(
              'Load Payroll Cohort (Ctrl+L)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textOnPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileErrorBanner(
    String message,
    SalaryManagementNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.statusErrorBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.statusErrorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.statusErrorText,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusErrorText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.statusErrorText,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: notifier.clearErrorMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilterBar(
    BuildContext context,
    SalaryManagementState state,
    SalaryManagementNotifier notifier,
  ) {
    final dateDisplay = DateFormat('yyyy-MM-dd').format(state.disbursementDate);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMobileDropdownRow(
            label: 'Month',
            child: _buildMobileDropdown<String>(
              value: state.availableMonths.contains(state.selectedMonth)
                  ? state.selectedMonth
                  : null,
              hint: state.selectedMonth,
              items: state.availableMonths
                  .map(
                    (m) => DropdownMenuItem<String>(
                      value: m,
                      child: _mobileDropdownItemText(m),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) notifier.setMonth(val);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobileFieldLabel('Disburse Date'),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.disbursementDate,
                firstDate: DateTime(2015),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                notifier.setDisbursementDate(picked);
              }
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 44,
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateDisplay,
                    style: AppTypography.monospace.copyWith(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobileDropdownRow(
            label: 'Category',
            child: _buildMobileDropdown<String>(
              value: state.categoryFilter,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
                DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
                DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                DropdownMenuItem(value: 'Principal', child: Text('Principal')),
                DropdownMenuItem(value: 'V-P', child: Text('V-P')),
              ],
              onChanged: (val) {
                if (val != null) notifier.setCategoryFilter(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileKpiGrid(SalaryManagementState state) {
    final currencyFormat = NumberFormat('#,##0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: MobileKpiCard(
                label: 'GROSS PAYROLL',
                value: 'Rs. ${currencyFormat.format(state.grossPayroll)}',
                icon: Icons.account_balance_wallet_outlined,
                accentColor: AppColors.accentStaff,
                accentSoftBg: AppColors.accentStaffSoftBg,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MobileKpiCard(
                label: 'NET DISBURSED',
                value: 'Rs. ${currencyFormat.format(state.netDisbursed)}',
                icon: Icons.check_circle_outline,
                accentColor: AppColors.accentStaff,
                accentSoftBg: AppColors.accentStaffSoftBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: MobileKpiCard(
                label: 'ELIGIBLE STAFF',
                value: '${state.totalEligibleStaff}',
                icon: Icons.people_outline,
                accentColor: AppColors.accentStaff,
                accentSoftBg: AppColors.accentStaffSoftBg,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MobileKpiCard(
                label: 'TOTAL DEDUCTIONS',
                value: 'Rs. ${currencyFormat.format(state.totalDeductions)}',
                icon: Icons.remove_circle_outline,
                accentColor: AppColors.statusErrorText,
                accentSoftBg: AppColors.statusErrorBg,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileRosterSection(
    BuildContext context,
    SalaryManagementState state,
    SalaryManagementNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PAYROLL REGISTER: ${state.selectedMonth}',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _handlePrintRegister,
              icon: const Icon(Icons.print_outlined, size: 12),
              label: const Text(
                'Print Register',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: state.roster.any((r) => r.isPending)
                  ? _showMobileBatchDisburseDialog
                  : null,
              icon: const Icon(Icons.flash_on, size: 12),
              label: const Text(
                'Disburse All Pending',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.roster.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Select month + category, then click [Load Payroll Cohort]',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.roster.length,
              itemBuilder: (ctx, index) => _buildMobileRosterCard(
                context,
                state,
                notifier,
                state.roster[index],
                index,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileRosterCard(
    BuildContext context,
    SalaryManagementState state,
    SalaryManagementNotifier notifier,
    SalarySlipRow row,
    int index,
  ) {
    final currency = NumberFormat('#,##0');
    final isSelected = row.teacherId == state.selectedTeacherId;
    final gross = row.grossFromDet > 0
        ? row.grossFromDet
        : ((row.paidAmt ?? 0) + (row.tDeductions ?? 0));
    final net = row.paidAmt ?? 0;
    final deductions = row.tDeductions ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isSelected ? AppColors.accentStaff : AppColors.borderDefault,
        ),
      ),
      elevation: 0,
      color: AppColors.surfaceRaised,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3.5,
              color: AppColors.accentStaff,
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () => _handleMobileRowTap(row),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.teacherName,
                              style: AppTypography.body.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.accentStaff
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          MobileStatusPill(
                            label: row.isPaid == 'Y' ? 'Paid' : 'Unpaid',
                            variant: row.isPaid == 'Y'
                                ? MobileStatusVariant.success
                                : MobileStatusVariant.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            row.tSalMasId ?? '—',
                            style: AppTypography.monospace.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _buildCategoryBadge(row.teacherCat),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _buildMobileAmountPill(
                              'Gross', 'Rs. ${currency.format(gross)}'),
                          _buildMobileAmountPill(
                            'Deductions',
                            'Rs. ${currency.format(deductions)}',
                          ),
                          _buildMobileAmountPill(
                              'Net', 'Rs. ${currency.format(net)}'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => _handleMobileRowTap(row),
                                icon: const Icon(Icons.receipt_outlined,
                                    size: 16),
                                label: const Text(
                                  'View Slip',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _handlePrint,
                                icon:
                                    const Icon(Icons.print_outlined, size: 16),
                                label: const Text(
                                  'Print',
                                  style: TextStyle(fontSize: 12),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileAmountPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.monospace.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSlipSection(
    BuildContext context,
    SalaryManagementState state,
    SalaryManagementNotifier notifier,
  ) {
    if (state.selectedTeacherId == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Select an employee to review or disburse salary',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final teacher = state.selectedTeacher;
    final teacherId = state.selectedTeacherId!;
    final avatarColor = _avatarPalette[teacherId.abs() % _avatarPalette.length];
    final currency = NumberFormat('#,##0');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Center(
                  child: Text(
                    _computeInitials(teacher?.teacherName ?? 'T'),
                    style: AppTypography.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      teacher?.teacherName ?? 'Staff Member',
                      style: AppTypography.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID #${teacher?.teacherId} | ${teacher?.teacherCat ?? 'Staff'}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Slip: ${state.selectedSlipId ?? "Pending (New)"}',
                      style: AppTypography.monospace.copyWith(
                        fontSize: 11,
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Allowance Heads',
                  style: AppTypography.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${state.draftAllowances.length} items',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (state.draftAllowances.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No allowance heads added yet.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.draftAllowances.length,
              itemBuilder: (ctx, index) {
                final item = state.draftAllowances[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: const BorderSide(color: AppColors.borderDefault),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${item.ser}. ',
                          style: AppTypography.monospace.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.detail,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Rs. ${currency.format(item.amount)}',
                          style: AppTypography.monospace.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: AppColors.statusErrorText,
                          ),
                          tooltip: 'Remove allowance',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              notifier.removeAllowanceHead(item.ser),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _showMobileAddAllowanceModal,
              icon: const Icon(Icons.add, size: 14),
              label: const Text(
                'Add Allowance Head',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMobileFinancialCard(state, currency),
        ],
      ),
    );
  }

  Widget _buildMobileFinancialCard(
    SalaryManagementState state,
    NumberFormat currency,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMobileFinancialRow(
            label: 'Gross Earnings:',
            value: 'Rs. ${currency.format(state.grossEarnings)}',
          ),
          const SizedBox(height: 8),
          _buildMobileFieldLabel('Deductions'),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _deductionsController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: AppTypography.monospace.copyWith(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                prefixStyle: AppTypography.monospace.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceRaised,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildMobileFinancialRow(
            label: 'NET PAYABLE:',
            value: 'Rs. ${currency.format(state.netPayable)}',
            emphasize: true,
          ),
          const SizedBox(height: 8),
          _buildMobileFieldLabel('Remarks'),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _remarksController,
              maxLines: 1,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Disbursement remarks & notes...',
                hintStyle: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceRaised,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFinancialRow({
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: emphasize ? 13 : 12,
              fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
              color: emphasize
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.monospace.copyWith(
            fontSize: emphasize ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: emphasize ? AppColors.brandPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFooter(
    BuildContext context,
    SalaryManagementState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _handleCommit,
            icon: const Icon(Icons.check, size: 14),
            label: const Text(
              'Commit & Disburse Slip (Ctrl+S)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textOnPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _handlePrint,
            icon: const Icon(Icons.print, size: 13),
            label: const Text(
              'Print Salary Slip (Ctrl+P)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: _handleDiscard,
            child: const Text(
              'Discard Slip',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildMobileDropdownRow({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileFieldLabel(label),
        const SizedBox(height: 4),
        Container(
          height: 44,
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: DropdownButtonHideUnderline(child: child),
        ),
      ],
    );
  }

  Widget _mobileDropdownItemText(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body.copyWith(
        color: AppColors.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildMobileDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    final effectiveValue = items.any((i) => i.value == value) ? value : null;
    final itemStyle = AppTypography.body.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );
    return DropdownButton<T>(
      value: effectiveValue,
      isExpanded: true,
      isDense: true,
      menuMaxHeight: 400.0,
      dropdownColor: AppColors.surfaceRaised,
      iconEnabledColor: AppColors.textPrimary,
      iconDisabledColor: AppColors.textMuted,
      style: itemStyle,
      hint: hint == null
          ? null
          : Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
      selectedItemBuilder: (context) => items
          .map(
            (item) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                (item.child as Text).data ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: itemStyle,
              ),
            ),
          )
          .toList(),
      items: items,
      onChanged: onChanged,
    );
  }

  Future<void> _handleMobileRowTap(SalarySlipRow row) async {
    final state = ref.read(salaryManagementProvider);
    final notifier = ref.read(salaryManagementProvider.notifier);

    if (state.selectedTeacherId == row.teacherId) return;

    if (state.isDirty) {
      final currentName = state.selectedTeacher?.teacherName ?? 'Employee';
      final discard = await _showMobileDiscardDialog(currentName);
      if (discard != true) return;
    }

    await notifier.selectEmployee(row.teacherId);
    final newState = ref.read(salaryManagementProvider);
    _deductionsController.text = newState.draftDeductions == 0.0
        ? '0'
        : (newState.draftDeductions % 1 == 0
              ? newState.draftDeductions.toInt().toString()
              : newState.draftDeductions.toString());
    _remarksController.text = newState.draftRemarks;
  }

  Future<bool?> _showMobileDiscardDialog(String currentName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Discard Unsaved Changes?',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Discard unsaved changes to $currentName?',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusErrorText,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Keep Editing'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMobileBatchDisburseDialog() async {
    final state = ref.read(salaryManagementProvider);
    final notifier = ref.read(salaryManagementProvider.notifier);
    final session = ref.read(sessionProvider);
    final userLvl = session?.user.userLevel ?? 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm Batch Disburse',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Disburse all pending salary slips for ${state.selectedMonth}? This cannot be undone.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Confirm'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await notifier.batchDisbursePending(userLvl: userLvl);
    }
  }

  Future<void> _showMobileAddAllowanceModal() async {
    final state = ref.read(salaryManagementProvider);
    final notifier = ref.read(salaryManagementProvider.notifier);

    int? selectedParamId = state.availableSalParams.isNotEmpty
        ? (state.availableSalParams.first['SalParamID'] as num?)?.toInt()
        : 1;
    final amountController = TextEditingController(text: '1000');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          insetPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add Allowance Head',
                    style: AppTypography.h2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildMobileDropdownRow(
                    label: 'Allowance Head',
                    child: _buildMobileDropdown<int>(
                      value: selectedParamId,
                      items: state.availableSalParams.map((p) {
                        final id = (p['SalParamID'] as num).toInt();
                        final name = p['SalParam']?.toString() ?? 'Allowance';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: _mobileDropdownItemText(name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedParamId = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildMobileFieldLabel('Amount (Rs.)'),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: AppTypography.monospace.copyWith(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        prefixText: 'Rs. ',
                        prefixStyle: AppTypography.monospace.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
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
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.textOnPrimary,
                      ),
                      onPressed: () {
                        final amt =
                            double.tryParse(amountController.text) ?? 0.0;
                        if (selectedParamId != null && amt > 0) {
                          notifier.addAllowanceHead(selectedParamId!, amt);
                          Navigator.of(dialogCtx).pop();
                        }
                      },
                      child: const Text('Add Head'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
