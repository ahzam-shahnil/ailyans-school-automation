import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/teacher_row.dart';
import '../db/database.dart';

/// State representation for Screen 20 - TeacherListScreen (`/staff/teachers`).
/// Implements §S25 (`frmTeachers` at `0x00431fec`, `ObjID: 14`).
class TeacherListState {
  final List<TeacherRow> allTeachers;
  final List<TeacherRow> filteredTeachers;
  final List<String> categories;

  // Filter criteria
  final String searchQuery;
  final String categoryFilter; // 'All' or specific TCat
  final bool onlyActive;

  // Pagination
  final int page;
  final int pageSize;

  final bool isLoading;
  final String? errorMessage;
  final String? toast;

  const TeacherListState({
    this.allTeachers = const [],
    this.filteredTeachers = const [],
    this.categories = const ['All Categories'],
    this.searchQuery = '',
    this.categoryFilter = 'All',
    this.onlyActive = true,
    this.page = 1,
    this.pageSize = 25,
    this.isLoading = false,
    this.errorMessage,
    this.toast,
  });

  // Unfiltered Metrics for the Header Badges (never change during filter/search)
  int get totalStaffCount => allTeachers.length;

  int get teacherCount =>
      allTeachers.where((t) => t.tCat.trim() == 'Teacher').length;

  int get staffAdminCount => allTeachers
      .where((t) => t.tCat.trim() == 'Staff' || t.tCat.trim() == 'Admin')
      .length;

  int get activeStaffCount => allTeachers.where((t) => t.isActive).length;

  // Filtered Count and Pagination Calculations
  int get totalFilteredCount => filteredTeachers.length;

  int get totalPages =>
      totalFilteredCount == 0 ? 1 : (totalFilteredCount / pageSize).ceil();

  int get startIndex =>
      filteredTeachers.isEmpty ? 0 : (page - 1) * pageSize + 1;

  int get endIndex => math.min(page * pageSize, totalFilteredCount);

  List<TeacherRow> get paginatedTeachers {
    if (filteredTeachers.isEmpty) return const [];
    final start = (page - 1) * pageSize;
    if (start >= filteredTeachers.length) return const [];
    final end = math.min(start + pageSize, filteredTeachers.length);
    return filteredTeachers.sublist(start, end);
  }

  TeacherListState copyWith({
    List<TeacherRow>? allTeachers,
    List<TeacherRow>? filteredTeachers,
    List<String>? categories,
    String? searchQuery,
    String? categoryFilter,
    bool? onlyActive,
    int? page,
    int? pageSize,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? toast,
    bool clearToast = false,
  }) {
    return TeacherListState(
      allTeachers: allTeachers ?? this.allTeachers,
      filteredTeachers: filteredTeachers ?? this.filteredTeachers,
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      onlyActive: onlyActive ?? this.onlyActive,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      toast: clearToast ? null : (toast ?? this.toast),
    );
  }
}

/// Notifier handling faculty & staff directory operations per §S25.
class TeacherListNotifier extends StateNotifier<TeacherListState> {
  TeacherListNotifier() : super(const TeacherListState());

  Future<Database> _getDb() async {
    return DatabaseService.instance.database;
  }

  /// Initial load: fetches full teacher directory and distinct categories.
  Future<void> loadInitialData() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final db = await _getDb();

      // 1. Fetch all teachers for unfiltered baseline
      final rawAll = await db.rawQuery('''
        SELECT TeacherID, TName, TFName, TCNIC, TContactNo1, TSubject, TCat, TIsPresent, TQualification, DOJoing
        FROM Teachers
        ORDER BY TeacherID ASC
      ''');
      final allRows = rawAll.map((r) => TeacherRow.fromMap(r)).toList();

      // 2. Fetch distinct employment categories from DB
      final catRows = await db.rawQuery('''
        SELECT DISTINCT TCat
        FROM Teachers
        WHERE TCat IS NOT NULL AND TRIM(TCat) != ''
        ORDER BY TCat ASC
      ''');
      final distinctCats = <String>['All Categories'];
      for (final r in catRows) {
        final c = (r['TCat'] as String?)?.trim();
        if (c != null && c.isNotEmpty && !distinctCats.contains(c)) {
          distinctCats.add(c);
        }
      }

      if (!mounted) return;
      state = state.copyWith(
        allTeachers: allRows,
        categories: distinctCats,
        searchQuery: '',
        categoryFilter: 'All',
        onlyActive: true,
        page: 1,
        pageSize: 25,
        isLoading: false,
      );

      await _executeFilteredQuery();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load faculty directory: $e',
      );
    }
  }

  /// Updates the free-text search filter (matches Name, CNIC, Phone, or Subject).
  Future<void> setSearchQuery(String query) async {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query, page: 1);
    await _executeFilteredQuery();
  }

  /// Updates category filter ('All' or 'All Categories' or specific TCat).
  Future<void> setCategoryFilter(String category) async {
    final normalized = (category == 'All Categories' || category == 'All')
        ? 'All'
        : category;
    if (state.categoryFilter == normalized) return;
    state = state.copyWith(categoryFilter: normalized, page: 1);
    await _executeFilteredQuery();
  }

  /// Toggles only-active employees checkbox.
  Future<void> setOnlyActive(bool onlyActive) async {
    if (state.onlyActive == onlyActive) return;
    state = state.copyWith(onlyActive: onlyActive, page: 1);
    await _executeFilteredQuery();
  }

  /// Resets all filters back to defaults: empty query, 'All', onlyActive = true.
  Future<void> resetFilters() async {
    state = state.copyWith(
      searchQuery: '',
      categoryFilter: 'All',
      onlyActive: true,
      page: 1,
      clearErrorMessage: true,
    );
    await _executeFilteredQuery();
  }

  /// Changes the current pagination page index.
  void changePage(int newPage) {
    if (newPage < 1 || newPage > state.totalPages) return;
    state = state.copyWith(page: newPage);
  }

  /// Changes the page size (25, 50, 100).
  void changePageSize(int newSize) {
    if (newSize <= 0 || newSize == state.pageSize) return;
    state = state.copyWith(pageSize: newSize, page: 1);
  }

  /// Clears active error message.
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// Clears active toast message.
  void clearToast() {
    state = state.copyWith(clearToast: true);
  }

  /// Executes dynamic SQL search matching S25 `cmdSearch_Click` (0x00634a00).
  Future<void> _executeFilteredQuery() async {
    try {
      final db = await _getDb();
      final queryParam = state.searchQuery.trim().isEmpty
          ? null
          : state.searchQuery.trim();
      final catParam = state.categoryFilter;
      final activeParam = state.onlyActive ? 'Y' : 'N';

      final results = await db.rawQuery(
        '''
        SELECT TeacherID, TName, TFName, TCNIC, TContactNo1, TSubject, TCat, TIsPresent, TQualification, DOJoing
        FROM Teachers
        WHERE (? IS NULL OR UPPER(TName) LIKE '%' || UPPER(?) || '%'
               OR TCNIC LIKE '%' || ? || '%'
               OR TContactNo1 LIKE '%' || ? || '%'
               OR UPPER(TSubject) LIKE '%' || UPPER(?) || '%')
          AND (? = 'All' OR TCat = ?)
          AND (? = 'N' OR TIsPresent = 'Y')
        ORDER BY TeacherID ASC
      ''',
        [
          queryParam,
          queryParam ?? '',
          queryParam ?? '',
          queryParam ?? '',
          queryParam ?? '',
          catParam,
          catParam,
          activeParam,
        ],
      );

      final filteredRows = results.map((r) => TeacherRow.fromMap(r)).toList();
      if (!mounted) return;
      state = state.copyWith(
        filteredTeachers: filteredRows,
        page:
            state.page > 1 &&
                (state.page - 1) * state.pageSize >= filteredRows.length
            ? 1
            : state.page,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'Search query error: $e');
    }
  }
}

/// Global Riverpod provider for Faculty & Staff Directory per §S25.
final teacherListProvider =
    StateNotifierProvider<TeacherListNotifier, TeacherListState>(
      (ref) => TeacherListNotifier(),
    );
