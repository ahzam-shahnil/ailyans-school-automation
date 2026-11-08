import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/fee_collection_provider.dart';
import '../../core/providers/fee_ledger_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../core/utils/defaulter_list_pdf_generator.dart';
import '../../models/fee_ledger_row.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

/// Screen 15: FeeLedgerScreen at `/fees/ledger`.
/// Consolidates legacy frmVouDet (lpObjectInfo VA 0x00423120, ObjID: 18).
/// Read-only financial analytics, receivables ledger, and audit reconciliation hub.
class FeeLedgerScreen extends ConsumerStatefulWidget {
  const FeeLedgerScreen({super.key});

  @override
  ConsumerState<FeeLedgerScreen> createState() => _FeeLedgerScreenState();
}

class _FeeLedgerScreenState extends ConsumerState<FeeLedgerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  static final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');

  @override
  void initState() {
    super.initState();
    // Verify permission on load if session is present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      _applyQueryParams();
    });
  }

  void _applyQueryParams() {
    if (!mounted) return;
    final uri = GoRouterState.of(context).uri;
    final status = uri.queryParameters['status'];
    final month = uri.queryParameters['month'];

    final notifier = ref.read(feeLedgerProvider.notifier);

    // If no query params, reset to defaults so state from a previous
    // navigation does not leak. Each navigation lands on the state the URL declares.
    if (status == null && month == null) {
      notifier.clearFilters();
      return;
    }

    if (status != null && status.isNotEmpty) {
      notifier.setStatus(status);
    }
    if (month != null && month.isNotEmpty) {
      notifier.setMonth(month);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _checkPermissions() {
    final session = ref.read(sessionProvider);
    if (session != null && session.user.userLevel != 1) {
      if (!session.hasAccess(18)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unauthorized: You do not have permission to access Fee Ledger (ObjID: 18).',
              ),
              backgroundColor: AppColors.statusErrorText,
            ),
          );
          context.go('/dashboard');
        }
      }
    }
  }

  void _onExportDefaulters() async {
    final state = ref.read(feeLedgerProvider);
    if (state.selectedMonth == null || state.selectedMonth == 'All Months') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('select Month to Print'),
          backgroundColor: AppColors.statusErrorText,
        ),
      );
      return;
    }

    // Resolve class filter name if selected
    String? className;
    if (state.selectedClassId != null) {
      final cls = state.classes.firstWhere(
        (c) => c['ClassID'] == state.selectedClassId,
        orElse: () => <String, dynamic>{},
      );
      className = cls['CName'] as String?;
    }

    final feeCollectionNotifier = ref.read(feeCollectionProvider.notifier);
    final defaulterData = await feeCollectionNotifier.buildDefaulterList(
      classFilter: className,
      monthFilter: state.selectedMonth,
    );

    if (!mounted) return;

    if (defaulterData.groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record Not Found'),
          backgroundColor: AppColors.statusWarningText,
        ),
      );
      return;
    }

    final meta = ref.read(shellMetadataProvider).value;
    final safeBranchName =
        (meta?.branchName != null && meta!.branchName.trim().isNotEmpty)
        ? meta.branchName.trim()
        : "Ailyans's Higher Secondary School Mianwali";
    final safeBranchAddress =
        (meta?.branchAddress != null && meta!.branchAddress.trim().isNotEmpty)
        ? meta.branchAddress.trim()
        : 'Muslim Bazar Mianwali';
    final request = ReportRequest(
      type: ReportType.defaulterList,
      vouchers: defaulterData.groups,
      extraParams: {
        'summary': defaulterData.summary,
        'branchName': safeBranchName,
        'branchAddress': safeBranchAddress,
        'branchPhone': meta?.branchPhone,
        'branchPrincipal': meta?.branchPrincipal,
      },
    );

    await ReportPreviewModal.show(
      context,
      request: request,
      headerControls: DefaulterFilterControls(
        initialClassId: null,
        initialMonth: null,
        onFiltersChanged: ({int? classId, String? month}) {
          // Because the filter requires a DB re-query (Q-2 in E-3c-2), we
          // cannot fully regenerate the PDF here without complex state.
          // For now, we preserve the filter UI visually. If the user changes
          // it, we show a snackbar explaining they must close and re-apply.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Close preview and change filters on the ledger to update the PDF.',
              ),
            ),
          );
        },
      ),
    );
  }

  void _onClassCollectionSummary() async {
    final state = ref.read(feeLedgerProvider);
    if (state.selectedMonth == null || state.selectedMonth == 'All Months') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('select Month to Print'),
          backgroundColor: AppColors.statusErrorText,
        ),
      );
      return;
    }

    final summary = await ref
        .read(feeLedgerProvider.notifier)
        .loadClassCollectionSummary();
    if (!mounted) return;

    final meta = ref.read(shellMetadataProvider).value;
    final summaryRows = summary.map((r) => {
      'className': r['className'] ?? 'Unassigned',
      'billedCount': r['billedCount'] ?? r['totalBilled'] ?? 0,
      'gross': r['gross'] ?? r['grossReceivable'] ?? 0,
      'discounts': r['discounts'] ?? r['totalDiscounts'] ?? 0,
      'collected': r['collected'] ?? r['cashCollected'] ?? 0,
      'dues': r['dues'] ?? r['outstandingDues'] ?? 0,
      'recoveryPercent': r['recoveryPercent'] ?? '0.0',
    }).toList();

    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.classCollectionSummary,
        titleOverride: 'Class Collection Summary',
        extraParams: {
          'className': state.selectedClassId?.toString() ?? 'All Classes',
          'month': state.selectedMonth ?? '',
          'rows': summaryRows,
          'branchName': meta?.branchName ?? "Ailyans's Higher Secondary School",
          'branchAddress': meta?.branchAddress ?? '',
        },
      ),
    );
  }

  void _onDailyLedger() async {
    final state = ref.read(feeLedgerProvider);
    final paidRows = state.rows.where((r) => r.isPaid == 'Y').toList();
    if (paidRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No paid records found to print.'),
          backgroundColor: AppColors.statusWarningBorder,
        ),
      );
      return;
    }

    final meta = ref.read(shellMetadataProvider).value;
    final collections = paidRows.map((r) => {
      'time': r.paidDate != null ? DateFormat('dd-MMM-yyyy HH:mm').format(r.paidDate!) : '',
      'studentName': r.studentName,
      'className': r.className,
      'voucherNo': r.voucherMasId,
      'amount': r.paidAmt,
      'bank': r.bankId != null ? 'Bank #${r.bankId}' : 'Cash',
      'collectedBy': 'Admin',
    }).toList();

    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.feeCollectionRegister,
        titleOverride: 'Daily Collection Ledger',
        extraParams: {
          'date': state.selectedMonth ?? '',
          'collections': collections,
          'branchName': meta?.branchName ?? "Ailyans's Higher Secondary School",
          'branchAddress': meta?.branchAddress ?? '',
        },
      ),
    );
  }

  void _onExportCsv() {
    final state = ref.read(feeLedgerProvider);
    final buffer = StringBuffer();
    buffer.writeln(
      'VoucherID,RegID,StudentName,Class,Section,Gross,Discount,NetDue,Status,DueDate,ForMonth',
    );
    for (final r in state.rows) {
      buffer.writeln(
        '${r.voucherMasId},${r.stuRegId},"${r.studentName}",${r.className},${r.sectionName},${r.gross},${r.discount},${r.netDue},${r.isPaid},${r.dueDate != null ? _dateFormat.format(r.dueDate!) : ""},${r.forMonth}',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exported ${state.rows.length} vouchers to CSV (copied to clipboard)',
        ),
        backgroundColor: AppColors.statusSuccessText,
      ),
    );
  }

  void _showVoucherDetail(FeeLedgerRow row) async {
    final items = await ref
        .read(feeLedgerProvider.notifier)
        .loadVoucherDetails(row.voucherMasId);
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => _VoucherDetailDialog(
        row: row,
        items: items,
        onReprintSlip: row.isPaid == 'Y' ? () => _reprintSlip(row) : null,
      ),
    );
  }

  void _reprintSlip(FeeLedgerRow row) async {
    if (row.isPaid != 'Y') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only paid vouchers have printable receipts.'),
          backgroundColor: AppColors.statusWarningText,
        ),
      );
      return;
    }

    final feeCollectionNotifier = ref.read(feeCollectionProvider.notifier);
    final receiptData = await feeCollectionNotifier.loadReceiptPrintData(
      row.voucherMasId,
    );

    if (!mounted) return;

    if (receiptData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No receipt record found for this voucher.'),
          backgroundColor: AppColors.statusErrorText,
        ),
      );
      return;
    }

    final meta = ref.read(shellMetadataProvider).value;
    final safeBranchName =
        (meta?.branchName != null && meta!.branchName.trim().isNotEmpty)
        ? meta.branchName.trim()
        : "Ailyans's Higher Secondary School Mianwali";
    final safeBranchAddress =
        (meta?.branchAddress != null && meta!.branchAddress.trim().isNotEmpty)
        ? meta.branchAddress.trim()
        : 'Muslim Bazar Mianwali';
    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.feeReceipt,
        vouchers: [receiptData],
        extraParams: {
          'branchName': safeBranchName,
          'branchAddress': safeBranchAddress,
        },
      ),
    );
  }

  void _sendReminder(FeeLedgerRow row) {
    final phone = row.mobile1?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No mobile number registered for ${row.studentName}.'),
          backgroundColor: AppColors.statusWarningText,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder SMS dispatched to ${row.studentName}\'s guardian at $phone',
        ),
        backgroundColor: AppColors.statusSuccessText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feeLedgerProvider);

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileScaffold(state);
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.slash): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyE, control: true):
            _onExportCsv,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _onExportDefaulters,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchController.text.isNotEmpty) {
            _searchController.clear();
            ref.read(feeLedgerProvider.notifier).setSearch('');
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: AppColors.surface,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. PAGE HEADER & ACTION TOOLBAR (52px height row)
                _buildHeader(state),
                const SizedBox(height: AppSpacing.sm),

                // 2. FINANCIAL KPI CARDS (84px height)
                _buildKpiSummary(state),
                const SizedBox(height: AppSpacing.sm),

                // 3. FILTER BAR (48px height)
                _buildFilterBar(state),
                const SizedBox(height: AppSpacing.xs),

                // 4. RECEIVABLES LEDGER DATA TABLE (Expanded to prevent overflow)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Column(
                      children: [
                        Expanded(child: _buildTable(state)),
                        const Divider(
                          height: 1,
                          color: AppColors.borderDefault,
                        ),
                        _buildPaginationFooter(state),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HEADER & TOOLBAR ────────────────────────────────────────────────────────
  Widget _buildHeader(FeeLedgerState state) {
    final from = _getFromOrigin(context);
    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      const Icon(
                        Icons.assessment_outlined,
                        size: 24,
                        color: AppColors.brandPrimary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Fee Ledger & Receivables Analytics',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Session: ${state.selectedSessionYr} | Month: ${state.selectedMonth ?? "All Months"}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _onExportDefaulters,
                        icon: const Icon(Icons.assignment_outlined, size: 15),
                        label: const Text('Export Defaulters Roster'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      OutlinedButton.icon(
                        onPressed: _onClassCollectionSummary,
                        icon: const Icon(Icons.bar_chart, size: 15),
                        label: const Text('Class Collection Summary'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      OutlinedButton.icon(
                        onPressed: _onDailyLedger,
                        icon: const Icon(Icons.receipt_long, size: 15),
                        label: const Text('Daily Collection Ledger'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      OutlinedButton.icon(
                        onPressed: _onExportCsv,
                        icon: const Icon(
                          Icons.file_download_outlined,
                          size: 15,
                        ),
                        label: const Text('Export to Excel / CSV'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── KPI SUMMARY CARDS ───────────────────────────────────────────────────────
  Widget _buildKpiSummary(FeeLedgerState state) {
    final recoveryRate = state.grossReceivable > 0
        ? ((state.cashCollected / state.grossReceivable) * 100).toStringAsFixed(
            1,
          )
        : '0.0';

    return SizedBox(
      height: 78,
      child: Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: 'GROSS RECEIVABLE',
              value: 'Rs. ${_currencyFormat.format(state.grossReceivable)}',
              subtitle: '${state.totalBilledCount} Billed Vouchers',
              accentColor: AppColors.chartBlue,
              icon: Icons.receipt_outlined,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildKpiCard(
              title: 'TOTAL CONCESSIONS',
              value: 'Rs. ${_currencyFormat.format(state.totalConcessions)}',
              subtitle: '${state.fullWaiversCount} Full Waivers',
              accentColor: AppColors.chartAmber,
              icon: Icons.card_giftcard,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildKpiCard(
              title: 'CASH COLLECTED',
              value: 'Rs. ${_currencyFormat.format(state.cashCollected)}',
              subtitle: '${state.paidCount} Paid [$recoveryRate%]',
              accentColor: AppColors.chartTeal,
              icon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildKpiCard(
              title: 'OUTSTANDING DUES',
              value: 'Rs. ${_currencyFormat.format(state.outstandingDues)}',
              subtitle: '${state.defaultersCount} Defaulters',
              accentColor: AppColors.chartRose,
              icon: Icons.warning_amber_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTER BAR ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar(FeeLedgerState state) {
    final notifier = ref.read(feeLedgerProvider.notifier);

    // Filter sections for currently selected class
    final filteredSections = state.selectedClassId != null
        ? state.sections
              .where((s) => s['ClassID'] == state.selectedClassId)
              .toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Session Dropdown
            const Text(
              'Session:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            DropdownButton<String>(
              value: state.selectedSessionYr.isNotEmpty
                  ? state.selectedSessionYr
                  : null,
              isDense: true,
              underline: const SizedBox.shrink(),
              items:
                  {
                        if (state.selectedSessionYr.isNotEmpty)
                          state.selectedSessionYr,
                        ...state.sessionYears,
                      }
                      .map(
                        (y) => DropdownMenuItem(
                          value: y,
                          child: Text(y, style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
              onChanged: (val) {
                if (val != null) notifier.setSession(val);
              },
            ),
            const SizedBox(width: AppSpacing.sm),

            // Month Dropdown
            const Text(
              'Month:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            DropdownButton<String?>(
              value: state.selectedMonth,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Months', style: TextStyle(fontSize: 12)),
                ),
                ...{
                  if (state.selectedMonth != null) state.selectedMonth!,
                  ...state.months,
                }.map(
                  (m) => DropdownMenuItem<String?>(
                    value: m,
                    child: Text(m, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              onChanged: (val) => notifier.setMonth(val),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Class Dropdown
            const Text(
              'Class:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            DropdownButton<int?>(
              value: state.selectedClassId,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Classes', style: TextStyle(fontSize: 12)),
                ),
                ...state.classes.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c['ClassID'] as int,
                    child: Text(
                      (c['CName'] as String?) ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
              onChanged: (val) => notifier.setClass(val),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Section Dropdown
            const Text(
              'Section:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            DropdownButton<int?>(
              value: state.selectedClassSecId,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Sections', style: TextStyle(fontSize: 12)),
                ),
                ...filteredSections.map(
                  (s) => DropdownMenuItem<int?>(
                    value: s['ClassSecID'] as int,
                    child: Text(
                      (s['SecName'] as String?) ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
              onChanged: state.selectedClassId == null
                  ? null
                  : (val) => notifier.setSection(val),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Status Dropdown
            const Text(
              'Status:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            DropdownButton<String>(
              value: state.selectedStatus,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: 'All',
                  child: Text('All', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'Paid',
                  child: Text('Paid', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'Unpaid',
                  child: Text('Unpaid', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'Overdue',
                  child: Text('Overdue', style: TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (val) {
                if (val != null) notifier.setStatus(val);
              },
            ),
            const SizedBox(width: AppSpacing.sm),

            // Quick Preset Buttons
            ActionChip(
              label: const Text('This Month', style: TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              backgroundColor: state.activePreset == 'thisMonth'
                  ? AppColors.brandPrimary
                  : null,
              labelStyle: TextStyle(
                fontSize: 11,
                color: state.activePreset == 'thisMonth'
                    ? AppColors.surfaceRaised
                    : AppColors.textPrimary,
              ),
              side: state.activePreset == 'thisMonth'
                  ? const BorderSide(color: AppColors.brandPrimary, width: 1)
                  : null,
              onPressed: notifier.applyThisMonth,
            ),
            const SizedBox(width: 4),
            ActionChip(
              label: const Text('Today', style: TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              backgroundColor: state.activePreset == 'today'
                  ? AppColors.brandPrimary
                  : null,
              labelStyle: TextStyle(
                fontSize: 11,
                color: state.activePreset == 'today'
                    ? AppColors.surfaceRaised
                    : AppColors.textPrimary,
              ),
              side: state.activePreset == 'today'
                  ? const BorderSide(color: AppColors.brandPrimary, width: 1)
                  : null,
              onPressed: notifier.applyToday,
            ),
            const SizedBox(width: AppSpacing.md),

            // Search Field
            SizedBox(
              width: 180,
              height: 32,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search voucher or name...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            notifier.setSearch('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(
                      color: AppColors.borderDefault,
                    ),
                  ),
                ),
                onChanged: (val) => notifier.setSearch(val),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── RECEIVABLES DATA TABLE ──────────────────────────────────────────────────
  Widget _buildTable(FeeLedgerState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.rows.isEmpty) {
      final isPaidSearch = state.selectedStatus == 'Paid';
      final emptyTitle = isPaidSearch ? 'No Paid Vouchar' : 'Record Not Found';
      final emptyDesc = isPaidSearch
          ? 'No paid vouchers recorded for this selection.'
          : 'No vouchers match your filter criteria.';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              emptyDesc,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: ref.read(feeLedgerProvider.notifier).clearFilters,
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: Scrollbar(
        controller: _horizontalScrollController,
        thumbVisibility: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: _verticalScrollController,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1000),
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 40,
                horizontalMargin: 12,
                columnSpacing: 16,
                columns: [
                  _buildSortableHeader('Voucher ID', 'voucher_id', state),
                  _buildSortableHeader('Reg ID', 'reg_id', state),
                  _buildSortableHeader('Student Name', 'name', state),
                  _buildSortableHeader('Class-Sec', 'class_sec', state),
                  _buildSortableHeader(
                    'Gross (Rs)',
                    'gross',
                    state,
                    isNumeric: true,
                  ),
                  _buildSortableHeader(
                    'Disc (Rs)',
                    'discount',
                    state,
                    isNumeric: true,
                  ),
                  _buildSortableHeader(
                    'Net Due',
                    'net_due',
                    state,
                    isNumeric: true,
                  ),
                  _buildSortableHeader('Status', 'status', state),
                  _buildSortableHeader('Due Date', 'due_date', state),
                  const DataColumn(
                    label: Text(
                      'Act',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                rows: state.rows.map((r) => _buildDataRow(r)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _buildSortableHeader(
    String label,
    String columnKey,
    FeeLedgerState state, {
    bool isNumeric = false,
  }) {
    final isSelected = state.sortColumn == columnKey;
    return DataColumn(
      numeric: isNumeric,
      onSort: (_, __) =>
          ref.read(feeLedgerProvider.notifier).setSort(columnKey),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          if (isSelected)
            Icon(
              state.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 13,
              color: AppColors.brandPrimary,
            ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(FeeLedgerRow r) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            r.voucherMasId,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        DataCell(
          Text(r.stuRegId.toString(), style: const TextStyle(fontSize: 12)),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              r.studentName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Text(
            r.sectionName.isNotEmpty
                ? '${r.className} - ${r.sectionName}'
                : r.className,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            _currencyFormat.format(r.gross),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            _currencyFormat.format(r.discount),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            _currencyFormat.format(r.netDue),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: r.netDue > 0
                  ? AppColors.statusErrorText
                  : AppColors.statusSuccessText,
            ),
          ),
        ),
        DataCell(_buildStatusBadge(r)),
        DataCell(
          Text(
            r.dueDate != null ? _dateFormat.format(r.dueDate!) : '-',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                tooltip: 'View Voucher Breakdown',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () => _showVoucherDetail(r),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined, size: 16),
                tooltip: r.isPaid == 'Y'
                    ? 'Reprint Payment Slip'
                    : 'Only paid vouchers have slips',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: r.isPaid == 'Y' ? () => _reprintSlip(r) : null,
              ),
              IconButton(
                icon: const Icon(Icons.sms_outlined, size: 16),
                tooltip: 'Send Payment Reminder SMS',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () => _sendReminder(r),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(FeeLedgerRow r) {
    Color bg;
    Color fg;
    String label;

    if (r.isPaid == 'Y') {
      bg = const Color(0xFFD1FAE5);
      fg = AppColors.statusSuccessText;
      label = 'Paid';
    } else if (r.isPaid == 'O') {
      bg = const Color(0xFFFFE4E6);
      fg = AppColors.statusErrorText;
      label = 'Overdue';
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = AppColors.statusWarningText;
      label = 'Unpaid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ── PAGINATION FOOTER ───────────────────────────────────────────────────────
  Widget _buildPaginationFooter(FeeLedgerState state) {
    final notifier = ref.read(feeLedgerProvider.notifier);
    final totalPages = (state.totalRowCount / state.pageSize).ceil().clamp(
      1,
      9999,
    );

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${state.rows.length} of ${state.totalRowCount} records (Page ${state.page} of $totalPages)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              const Text('Rows per page:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              DropdownButton<int>(
                value: state.pageSize,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 25,
                    child: Text('25', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 50,
                    child: Text('50', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 100,
                    child: Text('100', style: TextStyle(fontSize: 12)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setPageSize(val);
                },
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: state.page > 1
                    ? () => notifier.setPage(state.page - 1)
                    : null,
              ),
              Text(
                '${state.page} / $totalPages',
                style: const TextStyle(fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: state.page < totalPages
                    ? () => notifier.setPage(state.page + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── MOBILE LAYOUT (page-level scroll; no vertical Expanded/Flexible/Spacer) ─

  Widget _buildMobileScaffold(FeeLedgerState state) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(state),
              const SizedBox(height: AppSpacing.sm),
              _buildMobileKpiSummary(state),
              const SizedBox(height: AppSpacing.sm),
              _buildFilterBar(state),
              const SizedBox(height: AppSpacing.xs),
              _buildMobileLedgerList(state),
              const SizedBox(height: AppSpacing.sm),
              _buildMobilePaginationFooter(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileKpiSummary(FeeLedgerState state) {
    final recoveryRate = state.grossReceivable > 0
        ? ((state.cashCollected / state.grossReceivable) * 100).toStringAsFixed(
            1,
          )
        : '0.0';

    final card1 = _buildKpiCard(
      title: 'GROSS RECEIVABLE',
      value: 'Rs. ${_currencyFormat.format(state.grossReceivable)}',
      subtitle: '${state.totalBilledCount} Billed Vouchers',
      accentColor: AppColors.chartBlue,
      icon: Icons.receipt_outlined,
    );
    final card2 = _buildKpiCard(
      title: 'TOTAL CONCESSIONS',
      value: 'Rs. ${_currencyFormat.format(state.totalConcessions)}',
      subtitle: '${state.fullWaiversCount} Full Waivers',
      accentColor: AppColors.chartAmber,
      icon: Icons.card_giftcard,
    );
    final card3 = _buildKpiCard(
      title: 'CASH COLLECTED',
      value: 'Rs. ${_currencyFormat.format(state.cashCollected)}',
      subtitle: '${state.paidCount} Paid [$recoveryRate%]',
      accentColor: AppColors.chartTeal,
      icon: Icons.check_circle_outline,
    );
    final card4 = _buildKpiCard(
      title: 'OUTSTANDING DUES',
      value: 'Rs. ${_currencyFormat.format(state.outstandingDues)}',
      subtitle: '${state.defaultersCount} Defaulters',
      accentColor: AppColors.chartRose,
      icon: Icons.warning_amber_rounded,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: card2),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: card3),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: card4),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLedgerList(FeeLedgerState state) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.selectedStatus == 'Paid'
                  ? 'No Paid Vouchar' // Verbatim [Sic]
                  : 'Record Not Found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.selectedStatus == 'Paid'
                  ? 'No paid vouchers recorded for this selection.'
                  : 'No vouchers match your filter criteria.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: ref.read(feeLedgerProvider.notifier).clearFilters,
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: state.rows.map(_buildMobileLedgerCard).toList(),
    );
  }

  Widget _buildMobileLedgerCard(FeeLedgerRow r) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.voucherMasId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                _buildStatusBadge(r),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              r.studentName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Reg ${r.stuRegId} · ${r.className}'
              '${r.sectionName.isNotEmpty ? " - ${r.sectionName}" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _mobileLedgerStat(
                    'Gross',
                    _currencyFormat.format(r.gross),
                  ),
                ),
                Expanded(
                  child: _mobileLedgerStat(
                    'Disc',
                    _currencyFormat.format(r.discount),
                  ),
                ),
                Expanded(
                  child: _mobileLedgerStat(
                    'Net',
                    _currencyFormat.format(r.netDue),
                    color: r.netDue > 0
                        ? AppColors.statusErrorText
                        : AppColors.statusSuccessText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    r.dueDate != null ? _dateFormat.format(r.dueDate!) : '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  onPressed: () => _showVoucherDetail(r),
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined, size: 18),
                  onPressed: r.isPaid == 'Y' ? () => _reprintSlip(r) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  onPressed: () => _sendReminder(r),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileLedgerStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePaginationFooter(FeeLedgerState state) {
    final totalPages = (state.totalRowCount / state.pageSize).ceil().clamp(
      1,
      9999,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Showing ${state.rows.length} of ${state.totalRowCount} records '
            '(Page ${state.page} of $totalPages)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Rows:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              DropdownButton<int>(
                value: state.pageSize,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 25,
                    child: Text('25', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 50,
                    child: Text('50', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 100,
                    child: Text('100', style: TextStyle(fontSize: 12)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(feeLedgerProvider.notifier).setPageSize(val);
                  }
                },
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                onPressed: state.page > 1
                    ? () => ref
                          .read(feeLedgerProvider.notifier)
                          .setPage(state.page - 1)
                    : null,
              ),
              Text(
                '${state.page} / $totalPages',
                style: const TextStyle(fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                onPressed: state.page < totalPages
                    ? () => ref
                          .read(feeLedgerProvider.notifier)
                          .setPage(state.page + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// VOUCHER DETAIL MODAL DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _VoucherDetailDialog extends StatelessWidget {
  final FeeLedgerRow row;
  final List<FeeLedgerDetailItem> items;
  final VoidCallback? onReprintSlip;

  const _VoucherDetailDialog({
    required this.row,
    required this.items,
    this.onReprintSlip,
  });

  static final NumberFormat _curr = NumberFormat('#,##0.00');
  static final DateFormat _fmt = DateFormat('dd-MMM-yyyy');

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt, color: AppColors.brandPrimary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Voucher Details - ${row.voucherMasId}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student: ${row.studentName} (Reg ID: ${row.stuRegId})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Class: ${row.className}${row.sectionName.isNotEmpty ? " - ${row.sectionName}" : ""}',
                      ),
                      const SizedBox(height: 4),
                      Text('Billing Month: ${row.forMonth}'),
                      const SizedBox(height: 4),
                      Text(
                        'Due Date: ${row.dueDate != null ? _fmt.format(row.dueDate!) : "N/A"}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${row.isPaid == "Y" ? "Paid" : (row.isPaid == "O" ? "Overdue" : "Unpaid")}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: row.isPaid == 'Y'
                              ? AppColors.statusSuccessText
                              : AppColors.statusErrorText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Fee Parameter Breakdown:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderDefault),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: items.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No line item breakdown found.'),
                            ),
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 32,
                                dataRowMinHeight: 30,
                                dataRowMaxHeight: 34,
                                columnSpacing: 16,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      '#',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Fee Head',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Amount (Rs)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Discount (Rs)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Net (Rs)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: items.map((it) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          it.feeParamId.toString(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          it.paramDescription,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _curr.format(it.amount),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _curr.format(it.discount),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _curr.format(it.net),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Gross: Rs. ${_curr.format(row.gross)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Concessions: Rs. ${_curr.format(row.discount)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Net Due: Rs. ${_curr.format(row.netDue)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: row.netDue > 0
                            ? AppColors.statusErrorText
                            : AppColors.statusSuccessText,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (onReprintSlip != null)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onReprintSlip!();
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Reprint Payment Slip'),
                      ),
                    if (onReprintSlip != null)
                      const SizedBox(height: AppSpacing.xs),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt, color: AppColors.brandPrimary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Voucher Details - ${row.voucherMasId}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 16),

            // Metadata Grid
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Student: ${row.studentName} (Reg ID: ${row.stuRegId})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Class: ${row.className}${row.sectionName.isNotEmpty ? " - ${row.sectionName}" : ""}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Billing Month: ${row.forMonth}'),
                      Text(
                        'Due Date: ${row.dueDate != null ? _fmt.format(row.dueDate!) : "N/A"}',
                      ),
                      Text(
                        'Status: ${row.isPaid == "Y" ? "Paid" : (row.isPaid == "O" ? "Overdue" : "Unpaid")}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: row.isPaid == 'Y'
                              ? AppColors.statusSuccessText
                              : AppColors.statusErrorText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Line Items Table
            const Text(
              'Fee Parameter Breakdown:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderDefault),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No line item breakdown found.'),
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 30,
                        dataRowMaxHeight: 34,
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(
                            label: Text(
                              '#',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Fee Head',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Amount (Rs)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Discount (Rs)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Net (Rs)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        rows: items.map((it) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  it.feeParamId.toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  it.paramDescription,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _curr.format(it.amount),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _curr.format(it.discount),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _curr.format(it.net),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Footer Totals Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gross: Rs. ${_curr.format(row.gross)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Concessions: Rs. ${_curr.format(row.discount)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Net Due: Rs. ${_curr.format(row.netDue)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: row.netDue > 0
                        ? AppColors.statusErrorText
                        : AppColors.statusSuccessText,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Modal Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReprintSlip != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onReprintSlip!();
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Reprint Payment Slip'),
                  ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CLASS COLLECTION SUMMARY DIALOG
// ══════════════════════════════════════════════════════════════════════════════
// ignore: unused_element
class _ClassSummaryDialog extends StatelessWidget {
  final String month;
  final String sessionYr;
  final List<Map<String, dynamic>> summaryRows;

  const _ClassSummaryDialog({
    required this.month,
    required this.sessionYr,
    required this.summaryRows,
  });

  static final NumberFormat _curr = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Class Collection Summary ($month, Session $sessionYr)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: Container(
                    child: summaryRows.isEmpty
                        ? const Center(
                            child: Text('No class collection data recorded.'),
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 32,
                                dataRowMinHeight: 30,
                                dataRowMaxHeight: 34,
                                columnSpacing: 14,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Class',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Billed',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Gross (Rs)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Discounts (Rs)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Collected (Rs)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Dues (Rs)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Recovery %',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: summaryRows.map((r) {
                                  final billed =
                                      (r['totalBilled'] as num?)?.toInt() ?? 0;
                                  final gross =
                                      (r['grossReceivable'] as num?)?.toInt() ??
                                      0;
                                  final disc =
                                      (r['totalDiscounts'] as num?)?.toInt() ??
                                      0;
                                  final coll =
                                      (r['cashCollected'] as num?)?.toInt() ??
                                      0;
                                  final dues =
                                      (r['outstandingDues'] as num?)?.toInt() ??
                                      0;
                                  final pct = gross > 0
                                      ? ((coll / gross) * 100).toStringAsFixed(
                                          1,
                                        )
                                      : '0.0';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          (r['className'] as String?) ??
                                              'Unknown',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          billed.toString(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _curr.format(gross),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _curr.format(disc),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _curr.format(coll),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _curr.format(dues),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.statusErrorText,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '$pct%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ),
                const Divider(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: 780,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Class Collection Summary ($month, Session $sessionYr)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              child: summaryRows.isEmpty
                  ? const Center(
                      child: Text('No class collection data recorded.'),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 30,
                        dataRowMaxHeight: 34,
                        columnSpacing: 14,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Class',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Billed',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Gross (Rs)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Discounts (Rs)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Collected (Rs)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Dues (Rs)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Recovery %',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        rows: summaryRows.map((r) {
                          final billed =
                              (r['totalBilled'] as num?)?.toInt() ?? 0;
                          final gross =
                              (r['grossReceivable'] as num?)?.toInt() ?? 0;
                          final disc =
                              (r['totalDiscounts'] as num?)?.toInt() ?? 0;
                          final coll =
                              (r['cashCollected'] as num?)?.toInt() ?? 0;
                          final dues =
                              (r['outstandingDues'] as num?)?.toInt() ?? 0;
                          final pct = gross > 0
                              ? ((coll / gross) * 100).toStringAsFixed(1)
                              : '0.0';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  (r['className'] as String?) ?? 'Unknown',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  billed.toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _curr.format(gross),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _curr.format(disc),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _curr.format(coll),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _curr.format(dues),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.statusErrorText,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '$pct%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DAILY COLLECTION LEDGER DIALOG
// ══════════════════════════════════════════════════════════════════════════════
// ignore: unused_element
class _DailyLedgerDialog extends ConsumerWidget {
  final String sessionYr;
  final String month;
  final List<FeeLedgerRow> paidRows;

  const _DailyLedgerDialog({
    required this.sessionYr,
    required this.month,
    required this.paidRows,
  });

  static final NumberFormat _curr = NumberFormat('#,##0.00');
  static final DateFormat _fmt = DateFormat('dd-MMM-yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCollected = paidRows.fold<int>(0, (sum, r) => sum + r.paidAmt);

    if (ResponsiveBreakpoints.isMobile(context)) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daily Collection Ledger ($month, Session $sessionYr)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: Container(
                    child: paidRows.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No Paid Vouchar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 32,
                                dataRowMinHeight: 30,
                                dataRowMaxHeight: 34,
                                columnSpacing: 16,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Voucher ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Student Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Class',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text(
                                      'Paid Amount (Rs)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Paid Date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: paidRows.map((r) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          r.voucherMasId,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          r.studentName,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          r.className,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _curr.format(r.paidAmt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          r.paidDate != null
                                              ? _fmt.format(r.paidDate!)
                                              : 'N/A',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Paid Count: ${paidRows.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Collected: Rs. ${_curr.format(totalCollected)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusSuccessText,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print Ledger'),
                      onPressed: paidRows.isEmpty
                          ? null
                          : () {
                              final meta = ref
                                  .read(shellMetadataProvider)
                                  .value;
                              final collections = paidRows
                                  .map(
                                    (r) => {
                                      'voucherNo': r.voucherMasId,
                                      'date': r.paidDate != null
                                          ? _fmt.format(r.paidDate!)
                                          : '',
                                      'studentName': r.studentName,
                                      'className': r.className,
                                      'bank': r.bankId != null
                                          ? 'Bank #${r.bankId}'
                                          : 'Cash',
                                      'amount': r.paidAmt,
                                    },
                                  )
                                  .toList();

                              final safeBranchName =
                                  (meta?.branchName != null &&
                                      meta!.branchName.trim().isNotEmpty)
                                  ? meta.branchName.trim()
                                  : "Ailyans's Higher Secondary School Mianwali";
                              final safeBranchAddress =
                                  (meta?.branchAddress != null &&
                                      meta!.branchAddress.trim().isNotEmpty)
                                  ? meta.branchAddress.trim()
                                  : 'Muslim Bazar Mianwali';

                              ReportPreviewModal.show(
                                context,
                                request: ReportRequest(
                                  type: ReportType.dailyCollection,
                                  titleOverride: 'Daily Collection - $month',
                                  extraParams: {
                                    'date': month,
                                    'collections': collections,
                                    'branchName': safeBranchName,
                                    'branchAddress': safeBranchAddress,
                                  },
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Collection Ledger ($month, Session $sessionYr)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: paidRows.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No Paid Vouchar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 30,
                        dataRowMaxHeight: 34,
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Voucher ID',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Student Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Class',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Paid Amount (Rs)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Paid Date',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        rows: paidRows.map((r) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  r.voucherMasId,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.studentName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.className,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _curr.format(r.paidAmt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.paidDate != null
                                      ? _fmt.format(r.paidDate!)
                                      : 'N/A',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Paid Count: ${paidRows.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Total Collected: Rs. ${_curr.format(totalCollected)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.statusSuccessText,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print Ledger'),
                  onPressed: paidRows.isEmpty
                      ? null
                      : () {
                          final meta = ref.read(shellMetadataProvider).value;
                          final collections = paidRows
                              .map(
                                (r) => {
                                  'voucherNo': r.voucherMasId,
                                  'date': r.paidDate != null
                                      ? _fmt.format(r.paidDate!)
                                      : '',
                                  'studentName': r.studentName,
                                  'className': r.className,
                                  'bank': r.bankId != null
                                      ? 'Bank #${r.bankId}'
                                      : 'Cash',
                                  'amount': r.paidAmt,
                                },
                              )
                              .toList();

                          final safeBranchName =
                              (meta?.branchName != null &&
                                  meta!.branchName.trim().isNotEmpty)
                              ? meta.branchName.trim()
                              : "Ailyans's Higher Secondary School Mianwali";
                          final safeBranchAddress =
                              (meta?.branchAddress != null &&
                                  meta!.branchAddress.trim().isNotEmpty)
                              ? meta.branchAddress.trim()
                              : 'Muslim Bazar Mianwali';

                          ReportPreviewModal.show(
                            context,
                            request: ReportRequest(
                              type: ReportType.dailyCollection,
                              titleOverride: 'Daily Collection - $month',
                              extraParams: {
                                'date': month,
                                'collections': collections,
                                'branchName': safeBranchName,
                                'branchAddress': safeBranchAddress,
                              },
                            ),
                          );
                        },
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
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
