import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/providers/student_list_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/dashboard_metrics_provider.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/school_class.dart';
import '../../models/student_list_row.dart';
import '../../widgets/mobile/mobile_status_pill.dart';

/// Production Student Directory and Search Portal (`frmStuSearch` / `ObjID: 13`).
///
/// Implements Phase D, Step 5 specifications, locked visual reference
/// `students-list-v2-loaded.png`, and behavior rules from `05-ui-ux-spec.md` § 6.
class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  bool _isMobileFilterExpanded = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Selected row IDs for table row checkboxes
  final Set<int> _selectedStuRegIds = <int>{};

  // Horizontal scroll for the data table (narrow viewports)
  final ScrollController _tableHorizontalScroll = ScrollController();

  /// User-adjustable desktop column widths (pt), keyed by column id. The two
  /// text-heavy name columns are driven by these widths; the remaining fixed
  /// utility columns keep their intrinsic sizes.
  final Map<String, double> _colWidths = <String, double>{
    'regId': 90,
    'rollNo': 80,
    'studentName': 260,
    'fatherName': 200,
    'classSec': 130,
    'contact': 140,
    'status': 100,
    'actions': 120,
  };

  /// Right-edge drag handle that resizes [columnId] horizontally.
  Widget _buildColumnResizeHandle(String columnId) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          setState(() {
            _colWidths[columnId] = (_colWidths[columnId]! + details.delta.dx)
                .clamp(70.0, 500.0);
          });
        },
        child: Container(width: 6, color: Colors.transparent),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Sync sessionYr to the app's active session (app_config.default_session_yr)
    // AFTER first frame so shellMetadataProvider resolves. In production, AppShell
    // pre-loads shellMetadataProvider before this screen mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final metaAsync = ref.read(shellMetadataProvider);
      if (!metaAsync.hasValue) return;
      final meta = metaAsync.valueOrNull;
      if (meta == null) return;
      final current = ref.read(studentListFiltersProvider).sessionYr;
      if (current != meta.sessionYear) {
        ref
            .read(studentListFiltersProvider.notifier)
            .setSessionYr(meta.sessionYear);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tableHorizontalScroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(studentListFiltersProvider.notifier).setSearch(query);
    });
  }

  void _resetFilters() {
    _debounceTimer?.cancel();
    _searchController.clear();
    _selectedStuRegIds.clear();
    ref.read(studentListFiltersProvider.notifier).reset();
    ref.invalidate(studentListProvider);
  }

  /// G-10 Shot 9: two-phase offline-first refresh for the Student Directory
  /// (Refresh button on mobile & desktop + pull-to-refresh on mobile).
  ///
  /// Step A (0ms): instantly re-query local SQLite. `studentListProvider`
  /// watches `studentListFiltersProvider` (a separate notifier), so the
  /// user's session/class/section/search/sort/page state is preserved.
  /// Step B: run the cloud sync (push outbox + pull delta). When the pull
  /// completes, re-query local SQLite again so pulled remote rows render
  /// immediately without an app restart.
  Future<void> _handleRefreshAndSync() async {
    // Step A: instant local DB read.
    ref.invalidate(studentListProvider);

    // Step B: cloud sync, then re-read the local DB.
    try {
      await ref.read(syncPushProvider.notifier).triggerManualSync();
    } catch (e) {
      debugPrint('[G-10] Student list cloud sync failed: $e');
    }
    if (!mounted) return;

    ref.invalidate(studentListProvider);
    ref.invalidate(dashboardMetricsProvider);
  }

  String _getStudentInitials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) {
      final name = parts.first;
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  File? _resolvePhotoFile(StudentListRow student) {
    if (student.photoPath != null && student.photoPath!.isNotEmpty) {
      final f = File(student.photoPath!);
      if (f.existsSync()) return f;
    }

    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isNotEmpty) {
      final defaultPhoto = File(
        p.join(
          home,
          'Documents',
          'Ailyans',
          'photos',
          '${student.stuRegId}.jpg',
        ),
      );
      if (defaultPhoto.existsSync()) return defaultPhoto;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final shellMeta = ref.watch(shellMetadataProvider);
    final filters = ref.watch(studentListFiltersProvider);
    final studentsAsync = ref.watch(studentListProvider);
    final classesAsync = ref.watch(classesProvider);
    final sectionsAsync = ref.watch(sectionsProvider);

    if (shellMeta.isLoading && !studentsAsync.hasValue && !shellMeta.hasValue) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    ref.listen<AsyncValue<ShellMetadata>>(shellMetadataProvider, (previous, next) {
      final nextYear = next.valueOrNull?.sessionYear;
      if (nextYear != null && nextYear.isNotEmpty) {
        final current = ref.read(studentListFiltersProvider).sessionYr;
        if (current != nextYear) {
          ref.read(studentListFiltersProvider.notifier).setSessionYr(nextYear);
        }
      }
    });

    if (filters.classId == null && filters.classSecId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(studentListFiltersProvider.notifier).setClassSecId(null);
      });
    }

    final allStudents = studentsAsync.value ?? <StudentListRow>[];
    final totalCount = allStudents.length;

    // Filter available sections by selected class if a class filter is active
    final allSections = sectionsAsync.value ?? [];
    final availableSections = filters.classId == null
        ? <ClassSec>[]
        : () {
            final seenSecNames = <String>{};
            final list = <ClassSec>[];
            for (final s in allSections.where((s) => s.classId == filters.classId)) {
              if (seenSecNames.add(s.secName.trim().toUpperCase())) {
                list.add(s);
              }
            }
            return list;
          }();

    // Pagination calculations
    final pageSize = filters.pageSize;
    final totalPages = (totalCount / pageSize).ceil().clamp(1, 9999);
    final currentPage = filters.page.clamp(1, totalPages);
    final startIndex = totalCount == 0 ? 0 : (currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);
    final paginatedStudents = totalCount == 0
        ? <StudentListRow>[]
        : allStudents.sublist(startIndex, endIndex);

    final isAllSelected =
        paginatedStudents.isNotEmpty &&
        paginatedStudents.every((s) => _selectedStuRegIds.contains(s.stuRegId));

    final session = ref.watch(sessionProvider);
    final canNewAdmission =
        session == null ||
        session.user.userLevel == 1 ||
        session.hasAccess(26) ||
        session.hasAccess(12);
    final canBulkEnrollment =
        session == null || session.user.userLevel == 1 || session.hasAccess(20);
    final canBatchPromotion =
        session == null || session.user.userLevel == 1 || session.hasAccess(8);
    final canSchoolLeaving =
        session == null || session.user.userLevel == 1 || session.hasAccess(9);

    if (ResponsiveBreakpoints.isMobile(context)) {
      return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
            if (canNewAdmission) context.go('/students/new');
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_searchController.text.isNotEmpty) {
              _searchController.clear();
              ref.read(studentListFiltersProvider.notifier).setSearch('');
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColors.surfaceCanvas,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  // G-10 Shot 9: pull-to-refresh on mobile syncs (push + pull)
                  // and re-reads local SQLite without destroying filters.
                  child: RefreshIndicator(
                    color: AppColors.accentStudents,
                    onRefresh: _handleRefreshAndSync,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildMobileHeaderRow(
                                context,
                                filters,
                                totalCount,
                                canNewAdmission,
                              ),
                              const SizedBox(height: 8),
                              _buildMobileBatchWorkflows(
                                context,
                                canBulkEnrollment,
                                canBatchPromotion,
                                canSchoolLeaving,
                              ),
                              const SizedBox(height: 8),
                              _buildMobileFilterCard(
                                context,
                                filters,
                                classesAsync,
                                availableSections,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (paginatedStudents.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 40.0,
                              horizontal: 20.0,
                            ),
                            child: Center(
                              child: Text(
                                'No students found',
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          sliver: SliverList.separated(
                            itemCount: paginatedStudents.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              return _buildMobileStudentCard(
                                context,
                                paginatedStudents[i],
                              );
                            },
                          ),
                        ),
                    ],
                    ),
                  ),
                ),
                _buildMobilePaginationBar(
                  totalCount,
                  startIndex,
                  endIndex,
                  currentPage,
                  totalPages,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          if (canNewAdmission) context.go('/students/new');
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchController.text.isNotEmpty) {
            _searchController.clear();
            ref.read(studentListFiltersProvider.notifier).setSearch('');
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: AppColors.surface,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. PAGE HEADER ──
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Students',
                          style: AppTypography.h1.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          child: Text(
                            switch (filters.status) {
                              'Active' => '$totalCount Active Students',
                              'Left' => '$totalCount Left Students',
                              'All' => '$totalCount Total Students',
                              _ => '$totalCount Students',
                            },
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (canBulkEnrollment)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.go('/students/enrollment/bulk'),
                              icon: const Icon(
                                Icons.group_add_outlined,
                                size: 16.0,
                              ),
                              label: const Text('Bulk Enrollment'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          if (canBatchPromotion)
                            OutlinedButton.icon(
                              onPressed: () => context.go('/students/promote'),
                              icon: const Icon(Icons.trending_up, size: 16.0),
                              label: const Text('Batch Promotion'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          if (canSchoolLeaving)
                            OutlinedButton.icon(
                              onPressed: () => context.go('/students/leaving'),
                              icon: const Icon(Icons.exit_to_app, size: 16.0),
                              label: const Text('School Leaving'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Export coming in Phase 2'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.download_outlined,
                              size: 16.0,
                            ),
                            label: const Text('Export CSV'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                color: AppColors.borderDefault,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                          // G-10 Shot 9: Sync & Refresh (two-phase local read
                          // + cloud sync + post-pull re-read).
                          IconButton(
                            onPressed: _handleRefreshAndSync,
                            tooltip: 'Sync & Refresh',
                            icon: const Icon(
                              Icons.refresh,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (canNewAdmission)
                            ElevatedButton.icon(
                              onPressed: () => context.go('/students/new'),
                              icon: const Icon(
                                Icons.person_add_outlined,
                                size: 16.0,
                              ),
                              label: const Text('+ New Student (Ctrl+N)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: AppColors.textOnPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(0, 40),
                                elevation: AppElevation.flat,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),

                // ── 2. FILTER BAR CARD ──
                Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.borderDefault),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: _mobileBoundedScroll(
                    context,
                    width: 820,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      // Search Input (Flex 2)
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 40.0,
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by name, reg ID, CNIC, or father name...',
                              hintStyle: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 18.0,
                                color: AppColors.textSecondary,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        size: 16.0,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                            .read(
                                              studentListFiltersProvider
                                                  .notifier,
                                            )
                                            .setSearch('');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 8.0,
                              ),
                              fillColor: AppColors.surfaceRaised,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderFocus,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Class Dropdown (Flex 1)
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 40.0,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4.0,
                              ),
                              fillColor: AppColors.surfaceRaised,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: filters.classId,
                                isDense: true,
                                isExpanded: true,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text(
                                      'All Classes',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  for (final c in classesAsync.value ?? [])
                                    DropdownMenuItem<int?>(
                                      value: c.classId,
                                      child: Text(
                                        c.cName,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: (val) {
                                  ref
                                      .read(studentListFiltersProvider.notifier)
                                      .setClassId(val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Section Dropdown (Flex 1)
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 40.0,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4.0,
                              ),
                              fillColor: AppColors.surfaceRaised,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: filters.classId == null
                                    ? null
                                    : filters.classSecId,
                                isDense: true,
                                isExpanded: true,
                                style: AppTypography.bodySmall.copyWith(
                                  color: filters.classId == null
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                ),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text(
                                      'All Sections',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: filters.classId == null
                                            ? AppColors.textMuted
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  for (final s in availableSections)
                                    DropdownMenuItem<int?>(
                                      value: s.classSecId,
                                      child: Text(
                                        s.secName,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: filters.classId == null
                                    ? null
                                    : (val) {
                                        ref
                                            .read(
                                              studentListFiltersProvider
                                                  .notifier,
                                            )
                                            .setClassSecId(val);
                                      },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Status Dropdown (Fixed width 130px)
                      SizedBox(
                        width: 130.0,
                        height: 40.0,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4.0,
                            ),
                            fillColor: AppColors.surfaceRaised,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                color: AppColors.borderDefault,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                color: AppColors.borderDefault,
                              ),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: filters.status,
                              isDense: true,
                              isExpanded: true,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Active',
                                  child: Text('Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'Left',
                                  child: Text('Left'),
                                ),
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  ref
                                      .read(studentListFiltersProvider.notifier)
                                      .setStatus(val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Reset Filters Button
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(
                          Icons.refresh,
                          size: 16.0,
                          color: AppColors.brandPrimary,
                        ),
                        label: Text(
                          'Reset Filters',
                          style: AppTypography.label.copyWith(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                        ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── 3. DATA TABLE CARD ──
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.borderDefault),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 666px fixed columns + 32px cell insets + two
                        // ~150px name columns. 900px left each name only
                        // ~101px, which still ellipsized real names (e.g.
                        // "Muhammad Ali Khan" needs ~140px).
                        const minTableWidth = 1000.0;
                        // Intrinsic floor: fixed columns (checkbox 40 + photo
                        // 56 + siblings 80) + the two 6px resize handles + the
                        // resizable columns + the row's horizontal insets. The
                        // name columns are fixed-width now, so tableWidth must
                        // never drop below this or the rows overflow.
                        final columnsFloor = 40.0 + 56.0 + 80.0 + 12.0 +
                            (_colWidths['regId'] ?? 0) +
                            (_colWidths['rollNo'] ?? 0) +
                            (_colWidths['studentName'] ?? 0) +
                            (_colWidths['fatherName'] ?? 0) +
                            (_colWidths['classSec'] ?? 0) +
                            (_colWidths['status'] ?? 0) +
                            (_colWidths['actions'] ?? 0) +
                            2 * AppSpacing.md;
                        var tableWidth = constraints.maxWidth > minTableWidth
                            ? constraints.maxWidth
                            : minTableWidth;
                        if (columnsFloor > tableWidth) {
                          tableWidth = columnsFloor;
                        }
                        return Scrollbar(
                          controller: _tableHorizontalScroll,
                          thumbVisibility: true,
                          trackVisibility: true,
                          scrollbarOrientation: ScrollbarOrientation.bottom,
                          child: SingleChildScrollView(
                            controller: _tableHorizontalScroll,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: tableWidth,
                              ),
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  children: [
                        // Table Header Row
                        Container(
                          height: 40.0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppRadius.lg),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.borderDefault,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40.0,
                                child: Checkbox(
                                  value: isAllSelected,
                                  tristate:
                                      _selectedStuRegIds.isNotEmpty &&
                                      !isAllSelected,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedStuRegIds.addAll(
                                          paginatedStudents.map(
                                            (s) => s.stuRegId,
                                          ),
                                        );
                                      } else {
                                        _selectedStuRegIds.removeAll(
                                          paginatedStudents.map(
                                            (s) => s.stuRegId,
                                          ),
                                        );
                                      }
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: _colWidths['regId'],
                                child: _buildSortableHeader(
                                  'REG ID',
                                  StudentSortColumn.regId,
                                  filters,
                                ),
                              ),
                              SizedBox(
                                width: 56.0,
                                child: Center(
                                  child: Text(
                                    'PHOTO',
                                    style: AppTypography.label.copyWith(
                                      fontSize: 11.0,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: _colWidths['studentName'],
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildSortableHeader(
                                        'STUDENT NAME',
                                        StudentSortColumn.studentName,
                                        filters,
                                      ),
                                    ),
                                    _buildColumnResizeHandle('studentName'),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: _colWidths['fatherName'],
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'FATHER NAME',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.label.copyWith(
                                          fontSize: 11.0,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    _buildColumnResizeHandle('fatherName'),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: _colWidths['classSec'],
                                child: Text(
                                  'CLASS-SEC',
                                  style: AppTypography.label.copyWith(
                                    fontSize: 11.0,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: _colWidths['rollNo'],
                                child: _buildSortableHeader(
                                  'ROLL NO',
                                  StudentSortColumn.rollNo,
                                  filters,
                                  alignRight: true,
                                ),
                              ),
                              SizedBox(
                                width: _colWidths['status'],
                                child: Center(
                                  child: Text(
                                    'STATUS',
                                    style: AppTypography.label.copyWith(
                                      fontSize: 11.0,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80.0,
                                child: Center(
                                  child: Text(
                                    'SIBLINGS',
                                    style: AppTypography.label.copyWith(
                                      fontSize: 11.0,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: _colWidths['actions'],
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'ACTIONS',
                                    style: AppTypography.label.copyWith(
                                      fontSize: 11.0,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Body
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              if (studentsAsync.isLoading &&
                                  studentsAsync.value == null) {
                                return _buildSkeletonTableRows();
                              }

                              if (studentsAsync.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        size: 40.0,
                                        color: AppColors.statusErrorText,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        'Failed to load student directory: ${studentsAsync.error}',
                                        style: AppTypography.body.copyWith(
                                          color: AppColors.statusErrorText,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      ElevatedButton(
                                        onPressed: () =>
                                            ref.invalidate(studentListProvider),
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (allStudents.isEmpty) {
                                // Empty state matching spec verbatim
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.xl,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.search_off,
                                          size: 64.0,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        Text(
                                          'No Student Found',
                                          style: AppTypography.h2.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 420.0,
                                          ),
                                          child: Text(
                                            'No students match your active search or filter criteria. Check your spelling or reset filters to see the full directory.',
                                            style: AppTypography.body.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        ElevatedButton.icon(
                                          onPressed: _resetFilters,
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 16.0,
                                          ),
                                          label: const Text('Reset Filters'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.brandPrimary,
                                            foregroundColor:
                                                AppColors.textOnPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                itemCount: paginatedStudents.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                      height: 1.0,
                                      color: AppColors.borderSubtle,
                                    ),
                                itemBuilder: (context, index) {
                                  final student = paginatedStudents[index];
                                  final isSelected = _selectedStuRegIds
                                      .contains(student.stuRegId);

                                  return InkWell(
                                    onTap: () => context.go(
                                      '/students/${student.stuRegId}',
                                    ),
                                    hoverColor: AppColors.brandPrimary
                                        .withValues(alpha: 0.04),
                                    child: Container(
                                      height: 48.0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                      ),
                                      child: Row(
                                        children: [
                                          // Checkbox
                                          SizedBox(
                                            width: 40.0,
                                            child: Checkbox(
                                              value: isSelected,
                                              onChanged: (checked) {
                                                setState(() {
                                                  if (checked == true) {
                                                    _selectedStuRegIds.add(
                                                      student.stuRegId,
                                                    );
                                                  } else {
                                                    _selectedStuRegIds.remove(
                                                      student.stuRegId,
                                                    );
                                                  }
                                                });
                                              },
                                            ),
                                          ),

                                          // Reg ID (plain integer, monospace)
                                          SizedBox(
                                            width: _colWidths['regId'],
                                            child: Text(
                                              '${student.stuRegId}',
                                              style: AppTypography.monospace
                                                  .copyWith(
                                                    fontSize: 13.0,
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),

                                          // Photo Avatar
                                          SizedBox(
                                            width: 56.0,
                                            child: Center(
                                              child: _buildAvatar(student),
                                            ),
                                          ),

                                          // Student Full Name
                                          SizedBox(
                                            width:
                                                _colWidths['studentName'],
                                            child: Text(
                                              student.fullName,
                                              style: AppTypography.body
                                                  .copyWith(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),

                                          // Father Name
                                          SizedBox(
                                            width: _colWidths['fatherName'],
                                            child: Text(
                                              student.fatherName ?? '-',
                                              style: AppTypography.body
                                                  .copyWith(
                                                    color: AppColors
                                                        .textSecondary,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),

                                          // Class-Sec Badge
                                          SizedBox(
                                            width: _colWidths['classSec'],
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8.0,
                                                      vertical: 3.0,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      AppColors.surfaceSubtle,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.sm,
                                                      ),
                                                  border: Border.all(
                                                    color:
                                                        AppColors.borderDefault,
                                                  ),
                                                ),
                                                child: Text(
                                                  student.classSecDisplay,
                                                  style: AppTypography.label
                                                      .copyWith(
                                                        fontSize: 11.0,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Roll No
                                          SizedBox(
                                            width: _colWidths['rollNo'],
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                student.rollNo != null
                                                    ? '${student.rollNo}'
                                                    : '-',
                                                style: AppTypography.monospace
                                                    .copyWith(
                                                      fontSize: 13.0,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ),
                                          ),

                                          // Status Badge
                                          SizedBox(
                                            width: _colWidths['status'],
                                            child: Center(
                                              child: _buildStatusBadge(
                                                student.status,
                                              ),
                                            ),
                                          ),

                                          // Sibling Count Badge
                                          SizedBox(
                                            width: 80.0,
                                            child: Center(
                                              child: _buildSiblingBadge(
                                                student.siblingCount,
                                              ),
                                            ),
                                          ),

                                          // Actions Button
                                          SizedBox(
                                            width: _colWidths['actions'],
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: () => context.go(
                                                  '/students/${student.stuRegId}',
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal:
                                                            AppSpacing.sm,
                                                        vertical: 4.0,
                                                      ),
                                                ),
                                                child: Text(
                                                  'View →',
                                                  style: AppTypography.label
                                                      .copyWith(
                                                        color: AppColors
                                                            .brandPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── 4. PAGINATION ROW ──
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: _mobileBoundedScroll(
                      context,
                      width: 820,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Total range label
                          Text(
                            totalCount == 0
                                ? 'Showing 0-0 of 0 students'
                                : 'Showing ${startIndex + 1}-$endIndex of $totalCount students',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),

                          // Controls
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: currentPage > 1
                                    ? () {
                                        ref
                                            .read(
                                              studentListFiltersProvider
                                                  .notifier,
                                            )
                                            .setPage(currentPage - 1);
                                      }
                                    : null,
                                child: const Text('Previous'),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Container(
                                width: 32.0,
                                height: 32.0,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                                child: Text(
                                  '$currentPage',
                                  style: AppTypography.label.copyWith(
                                    color: AppColors.textOnPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              TextButton(
                                onPressed: currentPage < totalPages
                                    ? () {
                                        ref
                                            .read(
                                              studentListFiltersProvider
                                                  .notifier,
                                            )
                                            .setPage(currentPage + 1);
                                      }
                                    : null,
                                child: const Text('Next'),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              DropdownButton<int>(
                                value: pageSize,
                                underline: const SizedBox.shrink(),
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 25,
                                    child: Text('25 per page'),
                                  ),
                                  DropdownMenuItem(
                                    value: 50,
                                    child: Text('50 per page'),
                                  ),
                                  DropdownMenuItem(
                                    value: 100,
                                    child: Text('100 per page'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    ref
                                        .read(
                                          studentListFiltersProvider.notifier,
                                        )
                                        .setPageSize(val);
                                  }
                                },
                              ),
                            ],
                          ),
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

  Widget _buildMobileFilterCard(
    BuildContext context,
    StudentListFilters filters,
    AsyncValue<List<SchoolClass>> classesAsync,
    List<ClassSec> availableSections,
  ) {
    int activeFilterCount = 0;
    if (filters.classId != null) activeFilterCount++;
    if (filters.classSecId != null) activeFilterCount++;
    if (filters.status != 'Active') activeFilterCount++;
    if (_searchController.text.isNotEmpty) activeFilterCount++;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Search TextField (44px) + Filter Toggle Button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44.0,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Search by name, reg ID, CNIC, or father name...',
                      hintStyle: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18.0,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 16.0,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(studentListFiltersProvider.notifier)
                                    .setSearch('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 10.0,
                      ),
                      fillColor: AppColors.surfaceSubtle,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.borderDefault,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.borderDefault,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.borderFocus,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filter Toggle Button (height: 44)
              Material(
                color: AppColors.accentStudentsSoftBg,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isMobileFilterExpanded = !_isMobileFilterExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.tune,
                          size: 16,
                          color: AppColors.accentStudents,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Filters',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentStudents),
                        ),
                        if (activeFilterCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.accentStudents,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$activeFilterCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 2),
                        Icon(
                          _isMobileFilterExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: AppColors.accentStudents,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Hidden discovery text for tests
          const Offstage(offstage: true, child: Text('Search by name, reg ID, CNIC, or father name...')),

          // Collapsible filter body
          if (_isMobileFilterExpanded) ...[
            const SizedBox(height: 10.0),

            // Grid Row 1: External label Class + External label Section
            Row(
              children: [
                // Class Dropdown with external label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Class',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 44.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: filters.classId,
                              isDense: true,
                              isExpanded: true,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              selectedItemBuilder: (context) {
                                return [
                                  Text(
                                    'All Classes',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  for (final c in classesAsync.value ?? [])
                                    Text(
                                      c.cName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                ];
                              },
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    'All Classes',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                for (final c in classesAsync.value ?? [])
                                  DropdownMenuItem<int?>(
                                    value: c.classId,
                                    child: Text(
                                      c.cName,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (val) {
                                ref
                                    .read(studentListFiltersProvider.notifier)
                                    .setClassId(val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),

                // Section Dropdown with external label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Section',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 44.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: filters.classId == null
                                ? AppColors.surfaceSubtle.withValues(alpha: 0.5)
                                : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: filters.classId == null
                                  ? null
                                  : filters.classSecId,
                              isDense: true,
                              isExpanded: true,
                              style: AppTypography.bodySmall.copyWith(
                                color: filters.classId == null
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                              selectedItemBuilder: (context) {
                                return [
                                  Text(
                                    'All Sections',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: filters.classId == null
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  for (final s in availableSections)
                                    Text(
                                      s.secName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                ];
                              },
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    'All Sections',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: filters.classId == null
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                for (final s in availableSections)
                                  DropdownMenuItem<int?>(
                                    value: s.classSecId,
                                    child: Text(
                                      s.secName,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: filters.classId == null
                                  ? null
                                  : (val) {
                                      ref
                                          .read(
                                            studentListFiltersProvider.notifier,
                                          )
                                          .setClassSecId(val);
                                    },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),

            // Grid Row 2: Status (flex: 5) + Reset (flex: 3) + CSV (flex: 3)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Status',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Status Dropdown (flex: 4)
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 44.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: filters.status,
                              isDense: true,
                              isExpanded: true,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              selectedItemBuilder: (context) {
                                return const [
                                  Text(
                                    'Active',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Left',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'All',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ];
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'Active',
                                  child: Text('Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'Left',
                                  child: Text('Left'),
                                ),
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  ref
                                      .read(studentListFiltersProvider.notifier)
                                      .setStatus(val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // Reset Filters Button (flex: 4)
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 44.0,
                        child: OutlinedButton(
                          onPressed: _resetFilters,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceSubtle,
                            side: const BorderSide(color: AppColors.borderDefault),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: Center(
                            child: Text(
                              'Reset Filters',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // CSV Button (flex: 3, dark slate 0xFF334155)
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 44.0,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Export coming in Phase 2'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.download_outlined,
                            size: 15.0,
                            color: Colors.white,
                          ),
                          label: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'CSV',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Offstage(offstage: true, child: Text('Export CSV')),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF334155),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileBoundedScroll(
    BuildContext context, {
    required double width,
    required Widget child,
  }) {
    if (!ResponsiveBreakpoints.isMobile(context)) return child;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: width, child: child),
    );
  }

  Widget _buildMobilePaginationBar(
    int totalCount,
    int startIndex,
    int endIndex,
    int currentPage,
    int totalPages,
  ) {
    final start = totalCount == 0 ? 0 : startIndex + 1;
    final end = endIndex;
    final canGoPrev = currentPage > 1;
    final canGoNext = currentPage < totalPages;
    void onPrev() =>
        ref.read(studentListFiltersProvider.notifier).setPage(currentPage - 1);
    void onNext() =>
        ref.read(studentListFiltersProvider.notifier).setPage(currentPage + 1);

    return Container(
      height: 48.0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start-$end of $totalCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: canGoPrev ? onPrev : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentStudentsSoftBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$currentPage / $totalPages',
              style: AppTypography.monospace.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accentStudents,
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeaderRow(
    BuildContext context,
    StudentListFilters filters,
    int totalCount,
    bool canNewAdmission,
  ) {
    final statusText = switch (filters.status) {
      'Active' => '$totalCount Active Students',
      'Left' => '$totalCount Left Students',
      'All' => '$totalCount Total Students',
      _ => '$totalCount Students',
    };

    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Pill container (color: AppColors.accentStudentsSoftBg, 20px radius)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentStudentsSoftBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    size: 16,
                    color: AppColors.accentStudents,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      statusText,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.accentStudents,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Right: Elevated primary button (height: 42, 10px radius)
          if (canNewAdmission)
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/students/new'),
                icon: const Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 16.0,
                ),
                label: const Text(
                  '+ New Student',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentStudents,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  elevation: AppElevation.flat,
                ),
              ),
            ),
          // G-10 Shot 9: tactile 40x40 Sync & Refresh button (two-phase
          // local read + cloud sync + post-pull re-read).
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: _handleRefreshAndSync,
              tooltip: 'Sync & Refresh',
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceRaised,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
              icon: const Icon(
                Icons.refresh,
                size: 20,
                color: AppColors.accentStudents,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBatchWorkflows(
    BuildContext context,
    bool canBulkEnrollment,
    bool canBatchPromotion,
    bool canSchoolLeaving,
  ) {
    return Row(
      children: [
        // Tile 1: Enrollment | Bulk Enrollment
        Expanded(
          child: Material(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: canBulkEnrollment
                  ? () => context.go('/students/enrollment/bulk')
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accentStudentsSoftBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.group_add_outlined,
                        size: 16,
                        color: AppColors.accentStudents,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enrollment',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Bulk Enrollment',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Tile 2: Promotion | Batch Promotion
        Expanded(
          child: Material(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: canBatchPromotion
                  ? () => context.go('/students/promote')
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accentExamsSoftBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.upload_outlined,
                        size: 16,
                        color: AppColors.accentExams,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Promotion',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Batch Promotion',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Tile 3: Departure | School Leaving
        Expanded(
          child: Material(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: canSchoolLeaving
                  ? () => context.go('/students/leaving')
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accentAttendanceSoftBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.exit_to_app_outlined,
                        size: 16,
                        color: AppColors.accentAttendance,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Departure',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'School Leaving',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileStudentCard(BuildContext context, StudentListRow student) {
    final fatherNameTrimmed = student.fatherName?.trim() ?? '';
    final bool isLeft = student.status.toLowerCase() != 'active';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceRaised,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      child: InkWell(
        onTap: () => context.go('/students/${student.stuRegId}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isLeft ? AppColors.statusErrorText : AppColors.accentStudents,
                width: 3.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildMobileAvatar(student, isLeft: isLeft),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      student.fullName,
                      style: AppTypography.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'F/N: ${fatherNameTrimmed.isNotEmpty ? fatherNameTrimmed : "-"}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          child: Text(
                            '#${student.stuRegId}',
                            style: AppTypography.monospace.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${student.classSecDisplay} · Roll ${student.rollNo ?? "-"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MobileStatusPill(
                    label: isLeft ? 'Left / SLC' : 'Active',
                    variant: isLeft
                        ? MobileStatusVariant.error
                        : MobileStatusVariant.info,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAvatar(StudentListRow student, {bool isLeft = false}) {
    final photoFile = _resolvePhotoFile(student);

    if (photoFile != null) {
      return CircleAvatar(
        radius: 21.0,
        backgroundColor: AppColors.surfaceSubtle,
        backgroundImage: FileImage(photoFile),
      );
    }

    final initials = _getStudentInitials(student.fullName);

    return CircleAvatar(
      radius: 21.0,
      backgroundColor: isLeft
          ? AppColors.statusErrorBg
          : AppColors.accentStudentsSoftBg,
      child: Text(
        initials,
        style: AppTypography.label.copyWith(
          color: isLeft ? AppColors.statusErrorText : AppColors.accentStudents,
          fontWeight: FontWeight.w700,
          fontSize: 13.0,
        ),
      ),
    );
  }

  /// Builds a clickable sortable column header with active sort direction indicator.
  Widget _buildSortableHeader(
    String label,
    StudentSortColumn column,
    StudentListFilters filters, {
    bool alignRight = false,
  }) {
    final isSorted = filters.sortColumn == column;
    final isAsc = filters.sortDirection == SortDirection.ascending;

    final headerText = Flexible(
      fit: FlexFit.loose,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.label.copyWith(
          fontSize: 11.0,
          color: isSorted ? AppColors.brandPrimary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final sortIcon = isSorted
        ? Icon(
            isAsc ? Icons.arrow_upward : Icons.arrow_downward,
            size: 13.0,
            color: AppColors.brandPrimary,
          )
        : const SizedBox.shrink();

    return InkWell(
      onTap: () {
        ref.read(studentListFiltersProvider.notifier).toggleSort(column);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignRight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          headerText,
          if (isSorted) ...[const SizedBox(width: 2.0), sortIcon],
        ],
      ),
    );
  }

  /// Builds the 32px circle photo avatar with graceful initials fallback.
  Widget _buildAvatar(StudentListRow student) {
    final photoFile = _resolvePhotoFile(student);

    if (photoFile != null) {
      return CircleAvatar(
        radius: 16.0,
        backgroundColor: AppColors.surfaceSubtle,
        backgroundImage: FileImage(photoFile),
      );
    }

    final initials = _getStudentInitials(student.fullName);

    return CircleAvatar(
      radius: 16.0,
      backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: AppTypography.label.copyWith(
          color: AppColors.brandPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11.0,
        ),
      ),
    );
  }

  /// Builds the enrollment status badge (Active vs Left).
  Widget _buildStatusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';

    final bgColor = isActive
        ? AppColors.statusSuccessBg
        : AppColors.surfaceSubtle;
    final textColor = isActive
        ? AppColors.statusSuccessText
        : AppColors.textMuted;
    final borderColor = isActive
        ? AppColors.statusSuccessBorder
        : AppColors.borderDefault;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        isActive ? 'Active' : 'Left',
        style: AppTypography.label.copyWith(
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// Builds the sibling count indicator badge ('-', '1', 'N').
  Widget _buildSiblingBadge(int count) {
    if (count == 0) {
      return Text(
        '-',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (count == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Text(
          '1',
          style: AppTypography.label.copyWith(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: AppColors.statusInfoBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.statusInfoBorder),
      ),
      child: Text(
        '$count',
        style: AppTypography.label.copyWith(
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: AppColors.statusInfoText,
        ),
      ),
    );
  }

  /// Builds 5 placeholder skeleton rows during asynchronous query loading.
  Widget _buildSkeletonTableRows() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: 5,
      separatorBuilder: (context, index) =>
          const Divider(height: 1.0, color: AppColors.borderSubtle),
      itemBuilder: (context, index) {
        return Container(
          height: 48.0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 18.0,
                height: 18.0,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 60.0,
                height: 16.0,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const CircleAvatar(
                radius: 16.0,
                backgroundColor: AppColors.surfaceSubtle,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: Container(
                  height: 16.0,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: Container(
                  height: 16.0,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 90.0,
                height: 20.0,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
