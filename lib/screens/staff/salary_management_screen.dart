import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/salary_management_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../models/salary_slip_row.dart';
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
        .map((r) => <String, dynamic>{
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
            })
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
}
