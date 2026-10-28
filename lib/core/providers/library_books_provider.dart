import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/library_book_row.dart';
import '../db/database.dart';

/// State representation for Screen 23 - LibraryBooksScreen (`/library`).
/// Implements §S27 (`frmBooks` at `0x00412598`, `ObjID: 3`).
class LibraryBooksState {
  final List<LibraryBookRow> rows;
  final List<LibraryBookRow> allRows;
  final List<Map<String, dynamic>> subjects;
  final int? selectedCategoryId;
  final String searchQuery;
  final int currentPage;
  final int pageSize;
  final bool isLoading;
  final bool readOnly;
  final String? errorMessage;
  final String? toast;
  final int totalBooksAvailable;
  final int categoryCount;
  final int totalValuation;

  const LibraryBooksState({
    this.rows = const [],
    this.allRows = const [],
    this.subjects = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.currentPage = 1,
    this.pageSize = 25,
    this.isLoading = false,
    this.readOnly = false,
    this.errorMessage,
    this.toast,
    this.totalBooksAvailable = 0,
    this.categoryCount = 0,
    this.totalValuation = 0,
  });

  int get totalPages =>
      allRows.isEmpty ? 1 : (((allRows.length - 1) ~/ pageSize) + 1);

  LibraryBooksState copyWith({
    List<LibraryBookRow>? rows,
    List<LibraryBookRow>? allRows,
    List<Map<String, dynamic>>? subjects,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    int? currentPage,
    int? pageSize,
    bool? isLoading,
    bool? readOnly,
    String? errorMessage,
    bool clearError = false,
    String? toast,
    bool clearToast = false,
    int? totalBooksAvailable,
    int? categoryCount,
    int? totalValuation,
  }) {
    return LibraryBooksState(
      rows: rows ?? this.rows,
      allRows: allRows ?? this.allRows,
      subjects: subjects ?? this.subjects,
      selectedCategoryId: clearCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      isLoading: isLoading ?? this.isLoading,
      readOnly: readOnly ?? this.readOnly,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      toast: clearToast ? null : (toast ?? this.toast),
      totalBooksAvailable: totalBooksAvailable ?? this.totalBooksAvailable,
      categoryCount: categoryCount ?? this.categoryCount,
      totalValuation: totalValuation ?? this.totalValuation,
    );
  }
}

/// StateNotifier handling library book catalog search, filtering, and metrics.
class LibraryBooksNotifier extends StateNotifier<LibraryBooksState> {
  LibraryBooksNotifier() : super(const LibraryBooksState());

  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<Database> _getDb() async {
    return DatabaseService.instance.database;
  }

  /// Initial load: fetches subjects, global KPI aggregates, and initial catalog.
  Future<void> loadInitialData() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final db = await _getDb();

      // 1. Fetch Subject categories
      final subjRows = await db.rawQuery(
        'SELECT SubjID, SubjName FROM Subject ORDER BY SubjName ASC',
      );

      // 2. Fetch global baseline metrics (unfiltered)
      final metaRows = await db.rawQuery('''
        SELECT COUNT(*) AS cnt,
               COUNT(DISTINCT CASE WHEN BookCatSubj IS NOT NULL THEN BookCatSubj END) AS catCnt,
               COALESCE(SUM(BookPrice), 0) AS totalVal
        FROM Books
      ''');

      final cnt = metaRows.isNotEmpty
          ? (metaRows.first['cnt'] as int? ?? 0)
          : 0;
      final catCnt = metaRows.isNotEmpty
          ? (metaRows.first['catCnt'] as int? ?? 0)
          : 0;
      final totalVal = metaRows.isNotEmpty
          ? (metaRows.first['totalVal'] as int? ?? 0)
          : 0;

      if (!mounted) return;
      state = state.copyWith(
        subjects: subjRows,
        totalBooksAvailable: cnt,
        categoryCount: catCnt,
        totalValuation: totalVal,
      );

      await loadCatalog();
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load library catalog: $e',
        );
      }
    }
  }

  /// Loads catalog applying current selectedCategoryId and searchQuery filters.
  Future<void> loadCatalog() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      final db = await _getDb();
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (state.selectedCategoryId != null) {
        whereClauses.add('b.BookCatSubj = ?');
        whereArgs.add(state.selectedCategoryId);
      }

      final q = state.searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        whereClauses.add('''
          (LOWER(b.BookName) LIKE ?
           OR LOWER(COALESCE(b.BAuthor, '')) LIKE ?
           OR LOWER(COALESCE(b.PulishedBy, '')) LIKE ?
           OR CAST(b.BookID AS TEXT) LIKE ?)
        ''');
        final term = '%$q%';
        whereArgs.addAll([term, term, term, term]);
      }

      final whereSql = whereClauses.isEmpty
          ? ''
          : 'WHERE ${whereClauses.join(' AND ')}';

      final sql =
          '''
        SELECT b.BookID, b.BookCatSubj, b.BookName, b.BAuthor, b.Pages,
               b.PulishedBy, b.PublishedYr, b.BookPrice, b.Detail,
               s.SubjName AS CategoryName
        FROM Books b
        LEFT JOIN Subject s ON b.BookCatSubj = s.SubjID
        $whereSql
        ORDER BY b.BookCatSubj ASC, b.BookName ASC
      ''';

      final results = await db.rawQuery(sql, whereArgs);
      final allRows = results.map((r) => LibraryBookRow.fromMap(r)).toList();

      if (!mounted) return;

      final totalPages = allRows.isEmpty
          ? 1
          : (((allRows.length - 1) ~/ state.pageSize) + 1);
      final clampedPage = state.currentPage.clamp(1, totalPages);
      final start = (clampedPage - 1) * state.pageSize;
      final end = (start + state.pageSize).clamp(0, allRows.length);
      final pageRows = start >= allRows.length
          ? <LibraryBookRow>[]
          : allRows.sublist(start, end);

      state = state.copyWith(
        allRows: allRows,
        rows: pageRows,
        currentPage: clampedPage,
        isLoading: false,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to query catalog: $e',
        );
      }
    }
  }

  void _slice() {
    final totalPages = state.totalPages;
    final clampedPage = state.currentPage.clamp(1, totalPages);
    final start = (clampedPage - 1) * state.pageSize;
    final end = (start + state.pageSize).clamp(0, state.allRows.length);
    final pageRows = start >= state.allRows.length
        ? <LibraryBookRow>[]
        : state.allRows.sublist(start, end);

    state = state.copyWith(rows: pageRows, currentPage: clampedPage);
  }

  /// Sets search query with 250ms debounce.
  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q, currentPage: 1);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadCatalog();
    });
  }

  /// Sets subject category filter directly.
  Future<void> setCategory(int? subjId) async {
    state = state.copyWith(
      selectedCategoryId: subjId,
      clearCategory: subjId == null,
      currentPage: 1,
      clearError: true,
    );
    await loadCatalog();

    if (state.allRows.isEmpty && subjId != null) {
      final match = state.subjects.firstWhere(
        (s) => (s['SubjID'] as int?) == subjId,
        orElse: () => {'SubjName': 'Unknown'},
      );
      final name = match['SubjName'] as String? ?? 'Unknown';
      state = state.copyWith(toast: ' No Books Available in $name Category');
    }
  }

  /// Validates and applies category filter on button press.
  Future<bool> applyCategoryFilter() async {
    if (state.selectedCategoryId == null) {
      state = state.copyWith(
        errorMessage: 'Must Select Book Category Please.',
        clearToast: true,
      );
      return false;
    }
    await setCategory(state.selectedCategoryId);
    return true;
  }

  /// Resets category filter ONLY (preserves search query per S27 cmdAllBks).
  Future<void> showAll() async {
    state = state.copyWith(
      clearCategory: true,
      currentPage: 1,
      clearError: true,
    );
    await loadCatalog();
  }

  /// Resets BOTH search query and category filter.
  Future<void> resetFilters() async {
    _searchDebounce?.cancel();
    state = state.copyWith(
      searchQuery: '',
      clearCategory: true,
      currentPage: 1,
      clearError: true,
      clearToast: true,
    );
    await loadCatalog();
  }

  /// Navigates to a specific page.
  void setPage(int page) {
    final clamped = page.clamp(1, state.totalPages);
    state = state.copyWith(currentPage: clamped);
    _slice();
  }

  /// Changes pagination page size.
  void setPageSize(int size) {
    state = state.copyWith(pageSize: size, currentPage: 1);
    _slice();
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  void setReadOnly(bool ro) {
    state = state.copyWith(readOnly: ro);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearToast() {
    state = state.copyWith(clearToast: true);
  }
}

/// Global provider for library books catalog state and operations.
final libraryBooksProvider =
    StateNotifierProvider<LibraryBooksNotifier, LibraryBooksState>(
      (ref) => LibraryBooksNotifier(),
    );
