import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/library_books_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../models/library_book_row.dart';
import '../../widgets/mobile/mobile_kpi_card.dart';
import '../../widgets/mobile/mobile_status_pill.dart';
import '../../widgets/reports/report_definition.dart';
import '../../widgets/reports/report_preview_modal.dart';

/// Screen 23 - LibraryBooksScreen at `/library`.
/// Implements S27 (`frmBooks` at `0x00412598`, `ObjID: 3`) per behavior and UI specs.
class LibraryBooksScreen extends ConsumerStatefulWidget {
  const LibraryBooksScreen({super.key});

  @override
  ConsumerState<LibraryBooksScreen> createState() => _LibraryBooksScreenState();
}

class _LibraryBooksScreenState extends ConsumerState<LibraryBooksScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userLevel = ref.read(sessionProvider)?.user.userLevel ?? 1;
      if (userLevel == 3) {
        ref.read(libraryBooksProvider.notifier).setReadOnly(true);
      }
      ref.read(libraryBooksProvider.notifier).loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    final s = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  void _onAddNewBook() {
    final state = ref.read(libraryBooksProvider);
    final userLvl = ref.read(sessionProvider)?.user.userLevel ?? 1;
    final isReadOnly = state.readOnly || userLvl == 3;
    if (isReadOnly) {
      ref
          .read(libraryBooksProvider.notifier)
          .setError("You don't have enough rights for purpose");
    } else {
      context.push('/library/new');
    }
  }

  Future<void> _printCatalog() async {
    final state = ref.read(libraryBooksProvider);
    final books = state.allRows.map((b) => {
      'bookId': b.bookId.toString(),
      'bookName': b.bookName,
      'author': b.bAuthor ?? '',
      'publisher': b.pulishedBy ?? '',
      'category': b.categoryName ?? '',
      'price': (b.bookPrice ?? 0).toStringAsFixed(2),
      'status': 'Available',
    }).toList();
    final meta = ref.read(shellMetadataProvider).value;
    await ReportPreviewModal.show(
      context,
      request: ReportRequest(
        type: ReportType.libraryCatalog,
        titleOverride: 'Library Books Catalog',
        extraParams: {
          'books': books,
          'branchName':
              meta?.branchName ?? "Ailyans's Higher Secondary School",
          'branchAddress': meta?.branchAddress ?? 'Mianwali',
        },
      ),
    );
  }

  void _onResetFilters() {
    _searchController.clear();
    ref.read(libraryBooksProvider.notifier).resetFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryBooksProvider);
    final notifier = ref.read(libraryBooksProvider.notifier);

    // Sync external reset to search controller
    if (state.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    // Listen for toasts
    ref.listen<LibraryBooksState>(libraryBooksProvider, (prev, next) {
      if (next.toast != null && next.toast != prev?.toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(libraryBooksProvider.notifier).clearToast();
      }
    });

    if (ResponsiveBreakpoints.isMobile(context)) {
      return _buildMobileScaffold(context, state, notifier);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _onAddNewBook,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            _onAddNewBook,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _printCatalog,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
            _printCatalog,
        const SingleActivator(LogicalKeyboardKey.escape): _onResetFilters,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // =============================================================
              // REGION A: Header + KPI Strip (~88px)
              // =============================================================
              _buildRegionA(context, state),
              const SizedBox(height: 12),

              // =============================================================
              // REGION B: Filter Strip (~56px) + Conditional Error Banner
              // =============================================================
              _buildRegionB(context, state, notifier),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                _buildErrorBanner(state.errorMessage!, notifier),
              ],
              const SizedBox(height: 12),

              // =============================================================
              // REGION C: Catalog Table (Expanded, fills remaining height)
              // =============================================================
              Expanded(child: _buildRegionC(context, state, notifier)),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Region A: Header + KPI Badges
  // ===========================================================================
  Widget _buildRegionA(BuildContext context, LibraryBooksState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: Title bar and Toolbar Actions
        Row(
          children: [
            Text(
              'Library Book Catalog',
              style: AppTypography.h2.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _onAddNewBook,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Add New Book (Ctrl+N)',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('CSV export coming in Phase E'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text(
                        'Export Catalog (CSV)',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _printCatalog,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text(
                        'Print Catalog',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: 3 KPI Badges
        Row(
          children: [
            _buildKpiBadge('${state.totalBooksAvailable} Books Available'),
            const SizedBox(width: 12),
            _buildKpiBadge('${state.categoryCount} Subject Categories'),
            const SizedBox(width: 12),
            _buildKpiBadge(
              'Total Valuation Rs. ${_formatCurrency(state.totalValuation)}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ===========================================================================
  // Region B: Filter Strip
  // ===========================================================================
  Widget _buildRegionB(
    BuildContext context,
    LibraryBooksState state,
    LibraryBooksNotifier notifier,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Search Catalog
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Search Catalog',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search by Book ID, Title, Author, or Publisher',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchController.clear();
                              notifier.setSearchQuery('');
                              setState(() {});
                            },
                          )
                        : null,
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
                  onChanged: (val) {
                    notifier.setSearchQuery(val);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Subject Category Dropdown
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Subject Category',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 38,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey(state.selectedCategoryId),
                  initialValue: state.selectedCategoryId,
                  isExpanded: true,
                  isDense: true,
                  menuMaxHeight: 400,
                  dropdownColor: AppColors.surfaceRaised,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
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
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'All Subjects',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    ...state.subjects.map(
                      (s) => DropdownMenuItem<int?>(
                        value: s['SubjID'] as int,
                        child: Text(
                          s['SubjName'] as String? ?? '',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    notifier.setCategory(val);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Action Buttons
        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: notifier.applyCategoryFilter,
            icon: const Icon(Icons.filter_list, size: 16),
            label: const Text(
              'Filter by Category',
              style: TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: notifier.showAll,
            icon: const Icon(Icons.list_alt, size: 16),
            label: const Text('Show All Books', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 38,
          child: TextButton.icon(
            onPressed: _onResetFilters,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message, LibraryBooksNotifier notifier) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.statusErrorBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.statusErrorText.withValues(alpha: 0.3),
        ),
      ),
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
                color: AppColors.statusErrorText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.statusErrorText,
            ),
            splashRadius: 12,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: notifier.clearError,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Region C: Catalog Table Card
  // ===========================================================================
  Widget _buildRegionC(
    BuildContext context,
    LibraryBooksState state,
    LibraryBooksNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          // Sticky Table Header (36px)
          _buildTableHeader(),

          // Table Content / Empty State
          Expanded(
            child: state.allRows.isEmpty
                ? _buildEmptyState(notifier)
                : _buildTableBody(state),
          ),

          // Pinned Footer (36px)
          if (state.allRows.isNotEmpty) _buildTableFooter(state, notifier),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.md),
          topRight: Radius.circular(AppRadius.md),
        ),
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 84,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Accession',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 48,
            child: Center(
              child: Text(
                'Cover',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Title',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Author',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 130,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Publisher',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 64,
            child: Text(
              'Year',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(
            width: 64,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Pages',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 100,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Price',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 76,
            child: Text(
              'Actions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LibraryBooksNotifier notifier) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No books match the current search criteria',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Adjust filters or clear search to see the full catalog',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _onResetFilters,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildTableBody(LibraryBooksState state) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.rows.length,
        itemExtent: 42,
        itemBuilder: (context, index) {
          final row = state.rows[index];
          final isEven = index % 2 == 0;
          final bg = isEven ? AppColors.surfaceRaised : AppColors.surface;

          return Container(
            height: 42,
            color: bg,
            child: Row(
              children: [
                // Accession
                SizedBox(
                  width: 84,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      row.accessionDisplay,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                // Cover Placeholder
                SizedBox(
                  width: 48,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),

                // Title (InkWell)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: InkWell(
                      onTap: () => context.push('/library/${row.bookId}'),
                      child: Text(
                        row.bookName,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

                // Author
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      row.bAuthor ?? '—',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Category Badge
                SizedBox(
                  width: 130,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.statusInfoBg,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          row.categoryName ?? 'Unassigned',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusInfoText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),

                // Publisher (row.pulishedBy)
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      row.pulishedBy ?? '—',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Year
                SizedBox(
                  width: 64,
                  child: Text(
                    row.publishedYr?.toString() ?? '—',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                // Pages
                SizedBox(
                  width: 64,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      row.pages?.toString() ?? '—',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                // Price
                SizedBox(
                  width: 100,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      row.priceDisplay,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),

                // Actions
                SizedBox(
                  width: 76,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          iconSize: 16,
                          padding: EdgeInsets.zero,
                          tooltip: 'View Book Details',
                          icon: const Icon(
                            Icons.open_in_new,
                            color: AppColors.brandPrimary,
                          ),
                          onPressed: () =>
                              context.push('/library/${row.bookId}'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          iconSize: 16,
                          padding: EdgeInsets.zero,
                          tooltip: 'Print Spine Label',
                          icon: const Icon(
                            Icons.print_outlined,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Spine label coming in Phase E'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableFooter(
    LibraryBooksState state,
    LibraryBooksNotifier notifier,
  ) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.md),
          bottomRight: Radius.circular(AppRadius.md),
        ),
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          // Left status
          Text(
            'Showing ${state.rows.length} of ${state.allRows.length} Books (${state.totalBooksAvailable} Books Available)',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),

          // Center pagination
          OutlinedButton(
            onPressed: state.currentPage > 1
                ? () => notifier.setPage(state.currentPage - 1)
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 26),
            ),
            child: const Text('< Previous', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Text(
            'Page ${state.currentPage} of ${state.totalPages}',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: state.currentPage < state.totalPages
                ? () => notifier.setPage(state.currentPage + 1)
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 26),
            ),
            child: const Text('Next >', style: TextStyle(fontSize: 11)),
          ),
          const Spacer(),

          // Right page size
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Items: ',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              DropdownButton<int>(
                value: state.pageSize,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 10,
                    child: Text('10', style: TextStyle(fontSize: 12)),
                  ),
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
                    notifier.setPageSize(val);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // G-6b MOBILE BRANCH (< 600px)
  // ===========================================================================
  Widget _buildMobileScaffold(
    BuildContext context,
    LibraryBooksState state,
    LibraryBooksNotifier notifier,
  ) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _onAddNewBook,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            _onAddNewBook,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _printCatalog,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
            _printCatalog,
        const SingleActivator(LogicalKeyboardKey.escape): _onResetFilters,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.surfaceCanvas,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMobileHeader(state),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileFilterBar(context, state, notifier),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _buildMobileErrorBanner(state.errorMessage!, notifier),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileBookList(context, state, notifier),
                        const SizedBox(height: AppSpacing.sm),
                        _buildMobileFooter(context),
                      ],
                    ),
                  ),
                ),
                _buildMobileStickyBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(LibraryBooksState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Library Book Catalog',
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: MobileKpiCard(
                label: 'BOOKS AVAILABLE',
                value: '${state.totalBooksAvailable} Books Available',
                icon: Icons.menu_book_outlined,
                accentColor: AppColors.accentLibrary,
                accentSoftBg: AppColors.accentLibrarySoftBg,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MobileKpiCard(
                label: 'CATEGORIES',
                value: '${state.categoryCount} Categories',
                icon: Icons.category_outlined,
                accentColor: AppColors.accentLibrary,
                accentSoftBg: AppColors.accentLibrarySoftBg,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFilterBar(
    BuildContext context,
    LibraryBooksState state,
    LibraryBooksNotifier notifier,
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
          _buildMobileFieldLabel('Search Catalog'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: AppTypography.body.copyWith(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search by Book ID, Title, Author, or Publisher',
                hintStyle: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearchQuery('');
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
              ),
              onChanged: (val) {
                notifier.setSearchQuery(val);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobileDropdownRow(
            label: 'Subject Category',
            child: _buildMobileDropdown<int?>(
              value: state.selectedCategoryId,
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: _mobileDropdownItemText('All Subjects'),
                ),
                ...state.subjects.map(
                  (s) => DropdownMenuItem<int?>(
                    value: s['SubjID'] as int,
                    child: _mobileDropdownItemText(
                      s['SubjName'] as String? ?? '',
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                notifier.setCategory(val);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: notifier.applyCategoryFilter,
              icon: const Icon(Icons.filter_list, size: 16),
              label: const Text(
                'Filter by Category',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: notifier.showAll,
              icon: const Icon(Icons.list_alt, size: 16),
              label: const Text(
                'Show All Books',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton.icon(
              onPressed: _onResetFilters,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text(
                'Reset Filters',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileErrorBanner(
    String message,
    LibraryBooksNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.statusErrorBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.statusErrorText.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.statusErrorText,
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
              size: 16,
              color: AppColors.statusErrorText,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: notifier.clearError,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBookList(
    BuildContext context,
    LibraryBooksState state,
    LibraryBooksNotifier notifier,
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
            'CATALOG',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.allRows.isEmpty)
            _buildMobileEmptyState(notifier)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.rows.length,
              itemBuilder: (ctx, index) => _buildMobileBookCard(
                context,
                state.rows[index],
                index,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          _buildMobilePagination(state, notifier),
        ],
      ),
    );
  }

  Widget _buildMobileEmptyState(LibraryBooksNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No books match the current search criteria',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Adjust filters or clear search to see the full catalog',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton.icon(
              onPressed: _onResetFilters,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBookCard(
    BuildContext context,
    LibraryBookRow row,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      elevation: 0,
      color: AppColors.surfaceRaised,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3.5,
              color: AppColors.accentLibrary,
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => context.push('/library/${row.bookId}'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.accentLibrarySoftBg,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              size: 20,
                              color: AppColors.accentLibrary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  row.bookName,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${row.bookId} · ${row.bAuthor ?? '—'}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          MobileStatusPill(
                            label: row.categoryName ?? 'Unassigned',
                            variant: MobileStatusVariant.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (row.pulishedBy?.isNotEmpty == true)
                            _buildMobileInfoPill(row.pulishedBy!),
                          if (row.publishedYr != null)
                            _buildMobileInfoPill('${row.publishedYr}'),
                          if (row.pages != null)
                            _buildMobileInfoPill('${row.pages} pages'),
                          _buildMobileInfoPill(
                            row.priceDisplay,
                            isMonospace: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/library/${row.bookId}'),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text(
                                  'View',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Spine label coming in Phase E',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.print_outlined, size: 16),
                                label: const Text(
                                  'Spine',
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

  Widget _buildMobileInfoPill(String label, {bool isMonospace = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (isMonospace ? AppTypography.monospace : AppTypography.bodySmall)
            .copyWith(
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildMobilePagination(
    LibraryBooksState state,
    LibraryBooksNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Showing ${state.rows.length} of ${state.allRows.length} Books (${state.totalBooksAvailable} Books Available)',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: state.currentPage > 1
                      ? () => notifier.setPage(state.currentPage - 1)
                      : null,
                  child: const Text(
                    '< Previous',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Center(
                child: Text(
                  'Page ${state.currentPage} of ${state.totalPages}',
                  style: AppTypography.monospace.copyWith(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: state.currentPage < state.totalPages
                      ? () => notifier.setPage(state.currentPage + 1)
                      : null,
                  child: const Text('Next >', style: TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildMobileDropdownRow(
          label: 'Items per page',
          child: _buildMobileDropdown<int>(
            value: state.pageSize,
            items: [
              DropdownMenuItem(
                value: 10,
                child: _mobileDropdownItemText('10'),
              ),
              DropdownMenuItem(
                value: 25,
                child: _mobileDropdownItemText('25'),
              ),
              DropdownMenuItem(
                value: 50,
                child: _mobileDropdownItemText('50'),
              ),
              DropdownMenuItem(
                value: 100,
                child: _mobileDropdownItemText('100'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                notifier.setPageSize(val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFooter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV export coming in Phase E'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export Catalog (CSV)'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _printCatalog,
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print Catalog'),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileStickyBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _onAddNewBook,
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            '+ Add New Book (Ctrl+N)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentLibrary,
            foregroundColor: AppColors.textOnPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
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
}
