import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/teacher_list_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

// Intents for keyboard navigation
class _NewTeacherIntent extends Intent {
  const _NewTeacherIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _PrintDirectoryIntent extends Intent {
  const _PrintDirectoryIntent();
}

class _ClearSearchIntent extends Intent {
  const _ClearSearchIntent();
}

/// Screen 20 - TeacherListScreen at `/staff/teachers`.
/// Implements §S25 (`frmTeachers` at `0x00431fec`, `ObjID: 14`).
class TeacherListScreen extends ConsumerStatefulWidget {
  const TeacherListScreen({super.key});

  @override
  ConsumerState<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends ConsumerState<TeacherListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  // 6 pastel backgrounds for initials avatar variety
  static const List<Color> _avatarPalette = [
    Color(0xFFE0F2FE), // Soft Sky
    Color(0xFFFCE7F3), // Soft Pink
    Color(0xFFEDE9FE), // Soft Lavender
    Color(0xFFFEF3C7), // Soft Amber
    Color(0xFFDCFCE7), // Soft Emerald
    Color(0xFFFFEDD5), // Soft Peach
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(teacherListProvider.notifier).loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(teacherListProvider.notifier).setSearchQuery(value);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    ref.read(teacherListProvider.notifier).setSearchQuery('');
  }

  void _showPhaseEStub(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming in Phase E'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Color _getAvatarBg(int teacherId) {
    return _avatarPalette[teacherId.abs() % _avatarPalette.length];
  }

  Widget _buildCategoryBadge(String category) {
    Color bg;
    Color text;

    switch (category.trim()) {
      case 'Principal':
        bg = AppColors.brandPrimary.withValues(alpha: 0.15);
        text = AppColors.brandPrimary;
        break;
      case 'V-P':
        bg = AppColors.statusInfoBg;
        text = AppColors.statusInfoText;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        category.isEmpty ? 'Staff' : category,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    final bg = isActive ? AppColors.statusSuccessBg : AppColors.surfaceSubtle;
    final text = isActive ? AppColors.statusSuccessText : AppColors.textMuted;
    final label = isActive ? 'Active' : 'Relieved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherListProvider);
    final notifier = ref.read(teacherListProvider.notifier);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _NewTeacherIntent(),
        SingleActivator(LogicalKeyboardKey.slash): _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _PrintDirectoryIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _ClearSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewTeacherIntent: CallbackAction<_NewTeacherIntent>(
            onInvoke: (_) => context.go('/staff/teachers/new'),
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          _PrintDirectoryIntent: CallbackAction<_PrintDirectoryIntent>(
            onInvoke: (_) {
              _showPhaseEStub(context, 'Print Directory');
              return null;
            },
          ),
          _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(
            onInvoke: (_) {
              _clearSearch();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // a) Page Header Row (~56px)
                _buildHeader(context, state),
                const SizedBox(height: AppSpacing.xs),

                // b) Multi-Parameter Search & Filter Strip (~88px)
                _buildFilterBar(context, state, notifier),
                const SizedBox(height: AppSpacing.xs),

                // Error message banner if any
                if (state.errorMessage != null) ...[
                  Container(
                    height: 32,
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    color: AppColors.statusErrorBg,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.statusErrorText,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.statusErrorText,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.statusErrorText,
                          ),
                          splashRadius: 12,
                          onPressed: notifier.clearErrorMessage,
                        ),
                      ],
                    ),
                  ),
                ],

                // c & d) Directory Data Table & Pagination Footer (Expanded)
                Expanded(child: _buildTableCard(context, state, notifier)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // A. PAGE HEADER ROW (~56px)
  // ===========================================================================
  Widget _buildHeader(BuildContext context, TeacherListState state) {
    return Row(
      children: [
        // Left Title + 4 Metric Badges
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Faculty & Staff Directory',
                style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildMetricBadge(
                    '${state.totalStaffCount} Total Staff',
                    AppColors.surfaceSubtle,
                    AppColors.textSecondary,
                  ),
                  _buildMetricBadge(
                    '${state.teacherCount} Teachers',
                    AppColors.statusSuccessBg,
                    AppColors.statusSuccessText,
                  ),
                  _buildMetricBadge(
                    '${state.staffAdminCount} Staff/Admin',
                    AppColors.statusInfoBg,
                    AppColors.statusInfoText,
                  ),
                  _buildMetricBadge(
                    '${state.activeStaffCount} Active',
                    AppColors.brandPrimary.withValues(alpha: 0.12),
                    AppColors.brandPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Right Actions (Unconstrained Row)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.go('/staff/teachers/new'),
              icon: const Icon(Icons.add, size: 14),
              label: const Text(
                'Add New Teacher (Ctrl+N)',
                style: TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 36),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.go('/staff/salary'),
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text(
                'Monthly Payroll',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _showPhaseEStub(context, 'Export CSV'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Export CSV', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _showPhaseEStub(context, 'Print Roster'),
              icon: const Icon(Icons.print_outlined, size: 14),
              label: const Text(
                'Print Faculty Roster',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricBadge(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ===========================================================================
  // B. MULTI-PARAMETER SEARCH & FILTER STRIP (~88px)
  // ===========================================================================
  Widget _buildFilterBar(
    BuildContext context,
    TeacherListState state,
    TeacherListNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Search input + Category dropdown
          Row(
            children: [
              // Search Field (Expanded, min 320px)
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    key: const ValueKey('teacher_search_field'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      hintText: 'Search by name, CNIC, mobile, or subject',
                      hintStyle: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: _clearSearch,
                              splashRadius: 12,
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Category Dropdown (width 200)
              SizedBox(
                width: 200,
                height: 36,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('category_dropdown_${state.categoryFilter}'),
                  initialValue: state.categories.contains(state.categoryFilter)
                      ? state.categoryFilter
                      : (state.categoryFilter == 'All'
                            ? 'All Categories'
                            : (state.categories.isNotEmpty
                                  ? state.categories.first
                                  : null)),
                  isDense: true,
                  isExpanded: true,
                  menuMaxHeight: 400,
                  dropdownColor: AppColors.surfaceRaised,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                  items: state.categories.map((c) {
                    return DropdownMenuItem<String>(
                      value: c,
                      child: Text(
                        c,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setCategoryFilter(val);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Row 2: Only Active Employees checkbox + Reset Filters
          Row(
            children: [
              InkWell(
                onTap: () => notifier.setOnlyActive(!state.onlyActive),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: state.onlyActive,
                        onChanged: (val) =>
                            notifier.setOnlyActive(val ?? false),
                        activeColor: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Only Active Employees',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  notifier.resetFilters();
                },
                icon: const Icon(Icons.refresh, size: 13),
                label: const Text(
                  'Reset Filters',
                  style: TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // C & D. DIRECTORY DATA TABLE & PAGINATION FOOTER
  // ===========================================================================
  Widget _buildTableCard(
    BuildContext context,
    TeacherListState state,
    TeacherListNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sticky Table Header (36px)
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg - 1),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Avatar', 48, alignment: Alignment.center),
                _buildHeaderCell('ID', 60),
                _buildHeaderCell('Full Name', null, flex: 3),
                _buildHeaderCell('Father Name', null, flex: 2),
                _buildHeaderCell('CNIC', 140),
                _buildHeaderCell('Contact', 140),
                _buildHeaderCell('Category', 100),
                _buildHeaderCell('Subject', null, flex: 2),
                _buildHeaderCell('Status', 90),
                _buildHeaderCell('Actions', 120, alignment: Alignment.center),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderDefault,
          ),

          // Table Rows or Empty State
          Expanded(
            child: state.filteredTeachers.isEmpty
                ? _buildEmptyState(notifier)
                : ListView.builder(
                    itemCount: state.paginatedTeachers.length,
                    itemBuilder: (ctx, index) {
                      final teacher = state.paginatedTeachers[index];
                      final isEven = index.isEven;
                      final rowBg = isEven
                          ? AppColors.surfaceRaised
                          : AppColors.surfaceSubtle;

                      return InkWell(
                        onTap: () =>
                            context.go('/staff/teachers/${teacher.teacherId}'),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: rowBg,
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.borderSubtle.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar (48px)
                              SizedBox(
                                width: 48,
                                child: Center(
                                  child: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: _getAvatarBg(
                                      teacher.teacherId,
                                    ),
                                    child: Text(
                                      teacher.initials,
                                      style: AppTypography.monospace.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // ID (60px, mono)
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '#${teacher.teacherId}',
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              // Full Name (flex: 3, bold clickable link)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  teacher.tName,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandPrimary,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Father Name (flex: 2)
                              Expanded(
                                flex: 2,
                                child: Text(
                                  teacher.tfName.isEmpty ? '—' : teacher.tfName,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // CNIC (140px, mono)
                              SizedBox(
                                width: 140,
                                child: Text(
                                  teacher.tCnic,
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),

                              // Contact (140px, mono)
                              SizedBox(
                                width: 140,
                                child: Text(
                                  teacher.tContactNo1,
                                  style: AppTypography.monospace.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),

                              // Category (100px, badge)
                              SizedBox(
                                width: 100,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildCategoryBadge(teacher.tCat),
                                ),
                              ),

                              // Subject (flex: 2)
                              Expanded(
                                flex: 2,
                                child: Text(
                                  teacher.tSubject.isEmpty
                                      ? '—'
                                      : teacher.tSubject,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Status (90px, badge)
                              SizedBox(
                                width: 90,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildStatusBadge(teacher.isActive),
                                ),
                              ),

                              // Actions (120px, center)
                              SizedBox(
                                width: 120,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                      ),
                                      tooltip: 'View Profile',
                                      splashRadius: 14,
                                      color: AppColors.brandPrimary,
                                      onPressed: () => context.go(
                                        '/staff/teachers/${teacher.teacherId}',
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.print_outlined,
                                        size: 16,
                                      ),
                                      tooltip: 'Print Biodata',
                                      splashRadius: 14,
                                      color: AppColors.textSecondary,
                                      onPressed: () => _showPhaseEStub(
                                        context,
                                        'Print Biodata',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderDefault,
          ),

          // Pagination Footer (44px)
          _buildPaginationFooter(state, notifier),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TeacherListNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Record Not Found',
              style: AppTypography.h3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No staff members found matching your search criteria.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                notifier.resetFilters();
              },
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(
    TeacherListState state,
    TeacherListNotifier notifier,
  ) {
    final showingText = state.filteredTeachers.isEmpty
        ? 'Showing 0-0 of 0 Staff Members'
        : 'Showing ${state.startIndex}-${state.endIndex} of ${state.totalFilteredCount} Staff Members';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.lg - 1),
        ),
      ),
      child: Row(
        children: [
          // Left: Record summary count
          Text(
            showingText,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),

          const Spacer(),

          // Center: Previous / Next controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: state.page > 1
                    ? () => notifier.changePage(state.page - 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text('< Previous', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Text(
                'Page ${state.page} of ${state.totalPages}',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: state.page < state.totalPages
                    ? () => notifier.changePage(state.page + 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text('Next >', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),

          const Spacer(),

          // Right: Items per page selector
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Items:',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: state.pageSize,
                isDense: true,
                underline: const SizedBox(),
                dropdownColor: AppColors.surfaceRaised,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    notifier.changePageSize(val);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String label,
    double? width, {
    int flex = 1,
    Alignment alignment = Alignment.centerLeft,
  }) {
    final child = Align(
      alignment: alignment,
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex, child: child);
  }
}
