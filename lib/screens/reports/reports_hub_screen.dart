import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/build_config.dart';
import '../../core/providers/available_sessions_provider.dart';
import '../../core/providers/clock_provider.dart';
import '../../core/providers/reports_hub_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../models/school_class.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

/// VB6 one-screen report launcher hub (`Vouchers / Payment Analysis & Student
/// Reports`): a top filter bar (Session Year | Billing Month | Date | Class |
/// Section) above a categorized 1-click launcher grid with the 14 institutional
/// reports. Every card opens the shared [ReportPreviewModal] with live
/// `Refresh Data` / `Print / Export PDF` toolbar support.
class ReportsHubScreen extends ConsumerStatefulWidget {
  const ReportsHubScreen({super.key});

  @override
  ConsumerState<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends ConsumerState<ReportsHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(reportsHubFiltersProvider.notifier);
      // Default the date filter to "today" via the clock provider (never
      // DateTime.now() directly in lib/).
      final filters = ref.read(reportsHubFiltersProvider);
      if (filters.date == null) {
        notifier.setDate(ref.read(clockProvider)());
      }
      // Adopt the active session year from shell metadata when available.
      final meta = ref.read(shellMetadataProvider).valueOrNull;
      if (meta != null &&
          meta.sessionYear.isNotEmpty &&
          filters.sessionYr != meta.sessionYear) {
        notifier.setSessionYr(meta.sessionYear);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickDate(BuildContext context) async {
    final filters = ref.read(reportsHubFiltersProvider);
    final today = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: filters.date ?? today,
      firstDate: DateTime(2010),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      ref.read(reportsHubFiltersProvider.notifier).setDate(picked);
    }
  }

  Future<void> _openReport(Vb6ReportDef def) async {
    final filters = ref.read(reportsHubFiltersProvider);
    final meta = ref.read(shellMetadataProvider).valueOrNull;

    // Multi-tenant safety: use the DB branch name; only fall back to the
    // Ailyans school title when this build bundles the Ailyans edition seed.
    final dbBranchName = meta?.branchName ?? '';
    final dbBranchAddress = meta?.branchAddress ?? '';
    final branchName = dbBranchName.isNotEmpty
        ? dbBranchName
        : (BuildConfig.isAilyansEdition
            ? "Ailyan's Higher Secondary School Mianwali"
            : '-');
    final branchAddress = dbBranchAddress;

    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        // customBytesBuilder drives generation; classCollectionSummary is a
        // neutral type so the feeVoucher-only mode toggle is not rendered.
        type: ReportType.classCollectionSummary,
        titleOverride: def.title,
        subtitle: vb6ReportSubtitle(filters),
        fileNameOverride: 'vb6_${def.id}.pdf',
        extraParams: {
          'branchName': branchName,
          'branchAddress': branchAddress,
        },
        customBytesBuilder: () => buildVb6ReportPdf(
          reportId: def.id,
          title: def.title,
          filters: filters,
          branchName: branchName,
          branchAddress: branchAddress,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _billingMonthsFor(String sessionYr, String selected) {
    final out = <String>[];
    final parts = sessionYr.split('-');
    final startYear = int.tryParse(parts.isNotEmpty ? parts[0] : '') ??
        DateTime.now().year;
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    // Academic year: July (start) through June (end).
    for (int i = 0; i < 12; i++) {
      final monthIndex = (6 + i) % 12; // July == index 6
      final year = monthIndex >= 6 ? startYear : startYear + 1;
      out.add('${monthNames[monthIndex]} $year');
    }
    if (!out.contains(selected)) {
      out.add(selected);
    }
    return out;
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.borderDefault),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(reportsHubFiltersProvider);
    final sessionsAsync = ref.watch(availableSessionsProvider);
    final classesAsync = ref.watch(classesProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final metaAsync = ref.watch(shellMetadataProvider);

    final sessions = sessionsAsync.valueOrNull ?? const <String>[];
    final effectiveSessions = <String>{
      filters.sessionYr,
      ...sessions,
      '2017-2018',
    }.toList()..sort((a, b) => b.compareTo(a));

    final classList = classesAsync.valueOrNull ?? const <SchoolClass>[];
    final sectionList = sectionsAsync.valueOrNull ?? const <ClassSec>[];
    final filteredSections = filters.classId == null
        ? sectionList
        : sectionList.where((s) => s.classId == filters.classId).toList();

    final meta = metaAsync.valueOrNull;
    final headerTitle = (meta?.branchName ?? '').isNotEmpty
        ? meta!.branchName
        : (BuildConfig.isAilyansEdition
            ? "Ailyan's Higher Secondary School Mianwali"
            : 'Reports');

    final dateLabel = filters.date == null
        ? DateFormat('yyyy-MM-dd').format(ref.read(clockProvider)())
        : DateFormat('yyyy-MM-dd').format(filters.date!);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(headerTitle),
              const SizedBox(height: AppSpacing.md),
              _buildFilterCard(
                filters: filters,
                sessions: effectiveSessions,
                classList: classList,
                sections: filteredSections,
                dateLabel: dateLabel,
              ),
              for (final category in kVb6ReportCategories) ...[
                const SizedBox(height: AppSpacing.md),
                _buildCategorySection(category),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String branchName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vouchers / Payment Analysis & Student Reports',
          style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          branchName,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCard({
    required ReportsHubFilters filters,
    required List<String> sessions,
    required List<SchoolClass> classList,
    required List<ClassSec> sections,
    required String dateLabel,
  }) {
    Widget field({required String label, required Widget child}) {
      return SizedBox(
        width: 210,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          field(
            label: 'Session Year',
            child: DropdownButtonFormField<String>(
              initialValue: filters.sessionYr,
              isDense: true,
              items: sessions
                  .map(
                    (s) => DropdownMenuItem<String>(value: s, child: Text(s)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(reportsHubFiltersProvider.notifier).setSessionYr(v);
                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          field(
            label: 'Billing Month',
            child: DropdownButtonFormField<String>(
              initialValue: filters.billingMonth,
              isDense: true,
              items: _billingMonthsFor(filters.sessionYr, filters.billingMonth)
                  .map(
                    (m) => DropdownMenuItem<String>(value: m, child: Text(m)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(reportsHubFiltersProvider.notifier)
                      .setBillingMonth(v);
                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          field(
            label: 'Date',
            child: InkWell(
              onTap: () => _pickDate(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                ),
                child: Text(
                  dateLabel,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          field(
            label: 'Class',
            child: DropdownButtonFormField<int?>(
              initialValue: filters.classId,
              isDense: true,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Classes'),
                ),
                ...classList.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.classId,
                    child: Text(c.cName),
                  ),
                ),
              ],
              onChanged: (v) =>
                  ref.read(reportsHubFiltersProvider.notifier).setClassId(v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          field(
            label: 'Section',
            child: DropdownButtonFormField<int?>(
              initialValue: filters.sectionId,
              isDense: true,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Sections'),
                ),
                ...sections.map(
                  (s) => DropdownMenuItem<int?>(
                    value: s.classSecId,
                    child: Text(s.secName),
                  ),
                ),
              ],
              onChanged: (v) =>
                  ref.read(reportsHubFiltersProvider.notifier).setSectionId(v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category) {
    final reports =
        kVb6Reports.where((r) => r.category == category).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final report in reports) _buildReportCard(report),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard(Vb6ReportDef report) {
    return InkWell(
      key: Key('report_btn_${report.key}'),
      onTap: () => _openReport(report),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 250,
        child: Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  report.icon,
                  size: 18,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  report.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
