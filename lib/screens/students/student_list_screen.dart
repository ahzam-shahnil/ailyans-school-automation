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
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/student_list_row.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Selected row IDs for table row checkboxes
  final Set<int> _selectedStuRegIds = <int>{};

  // Horizontal scroll for the data table (narrow viewports)
  final ScrollController _tableHorizontalScroll = ScrollController();

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
    final filters = ref.watch(studentListFiltersProvider);
    final studentsAsync = ref.watch(studentListProvider);
    final classesAsync = ref.watch(classesProvider);
    final sectionsAsync = ref.watch(sectionsProvider);

    final allStudents = studentsAsync.value ?? <StudentListRow>[];
    final totalCount = allStudents.length;

    // Filter available sections by selected class if a class filter is active
    final allSections = sectionsAsync.value ?? [];
    final availableSections = filters.classId == null
        ? allSections
        : allSections.where((s) => s.classId == filters.classId).toList();

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
                _mobileBoundedScroll(
                  context,
                  width: 760,
                  child: Row(
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
                                value: filters.classSecId,
                                isDense: true,
                                isExpanded: true,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text(
                                      'All Sections',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textPrimary,
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
                                onChanged: (val) {
                                  ref
                                      .read(studentListFiltersProvider.notifier)
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
                        if (ResponsiveBreakpoints.isMobile(context)) {
                          return _buildMobileStudentCardList(
                            paginatedStudents,
                          );
                        }

                        // 666px fixed columns + 32px cell insets + two
                        // ~150px name columns. 900px left each name only
                        // ~101px, which still ellipsized real names (e.g.
                        // "Muhammad Ali Khan" needs ~140px).
                        const minTableWidth = 1000.0;
                        final tableWidth = constraints.maxWidth > minTableWidth
                            ? constraints.maxWidth
                            : minTableWidth;
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
                                minWidth: constraints.maxWidth,
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
                                width: 90.0,
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
                              Expanded(
                                flex: 2,
                                child: _buildSortableHeader(
                                  'STUDENT NAME',
                                  StudentSortColumn.studentName,
                                  filters,
                                ),
                              ),
                              Expanded(
                                flex: 2,
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
                              SizedBox(
                                width: 120.0,
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
                                width: 80.0,
                                child: _buildSortableHeader(
                                  'ROLL NO',
                                  StudentSortColumn.rollNo,
                                  filters,
                                  alignRight: true,
                                ),
                              ),
                              SizedBox(
                                width: 100.0,
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
                                width: 100.0,
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
                                            width: 90.0,
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
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              student.fullName,
                                              style: AppTypography.body
                                                  .copyWith(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),

                                          // Father Name
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              student.fatherName ?? '-',
                                              style: AppTypography.body
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),

                                          // Class-Sec Badge
                                          SizedBox(
                                            width: 120.0,
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
                                            width: 80.0,
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
                                            width: 100.0,
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
                                            width: 100.0,
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
                                          studentListFiltersProvider.notifier,
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
                              borderRadius: BorderRadius.circular(AppRadius.md),
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
                                          studentListFiltersProvider.notifier,
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
                                    .read(studentListFiltersProvider.notifier)
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

  Widget _buildMobileStudentCardList(List<StudentListRow> students) {
    if (students.isEmpty) {
      return Center(
        child: Text(
          'No students found',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final s = students[i];
        return Card(
          child: InkWell(
            onTap: () => context.go('/students/${s.stuRegId}'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  _buildAvatar(s),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.fullName,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${s.classSecDisplay} · Roll ${s.rollNo ?? "-"}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(s.status),
                ],
              ),
            ),
          ),
        );
      },
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
