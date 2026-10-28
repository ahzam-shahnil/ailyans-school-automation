import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db/database.dart';
import 'library_books_provider.dart';
import 'session_provider.dart';

/// State representation for Screen 24 - BookProfileScreen (`/library/new` and `/library/:id`).
/// Implements §S27 (`frmBooks` at `0x00412598`, `ObjID: 3`) single-book authoring/edit workstation.
class BookProfileState {
  final String bookIdParam;
  final bool isNew;
  final bool isEditMode;
  final bool isLoading;
  final bool isSaving;
  final int? bookId;
  final String bookName;
  final String bAuthor;
  final int? bookCatSubj;
  final int? pages;
  final String
  pulishedBy; // [Sic: Typo preserved from legacy DB schema 'PulishedBy']
  final int? publishedYr;
  final int? bookPrice; // Whole rupees
  final String detail;
  final List<Map<String, dynamic>> subjects;
  final bool isDirty;
  final String? errorMessage;
  final String? toast;

  const BookProfileState({
    required this.bookIdParam,
    this.isNew = false,
    this.isEditMode = false,
    this.isLoading = false,
    this.isSaving = false,
    this.bookId,
    this.bookName = '',
    this.bAuthor = '',
    this.bookCatSubj,
    this.pages,
    this.pulishedBy = '',
    this.publishedYr,
    this.bookPrice,
    this.detail = '',
    this.subjects = const [],
    this.isDirty = false,
    this.errorMessage,
    this.toast,
  });

  /// Null-safe category name lookup from [subjects].
  String get currentCategoryName {
    if (bookCatSubj == null) return '';
    final matches = subjects.where(
      (s) => (s['SubjID'] as num?)?.toInt() == bookCatSubj,
    );
    return matches.isEmpty ? '' : (matches.first['SubjName'] as String? ?? '');
  }

  BookProfileState copyWith({
    String? bookIdParam,
    bool? isNew,
    bool? isEditMode,
    bool? isLoading,
    bool? isSaving,
    int? bookId,
    bool clearBookId = false,
    String? bookName,
    String? bAuthor,
    int? bookCatSubj,
    bool clearBookCatSubj = false,
    int? pages,
    bool clearPages = false,
    String? pulishedBy,
    int? publishedYr,
    bool clearPublishedYr = false,
    int? bookPrice,
    bool clearBookPrice = false,
    String? detail,
    List<Map<String, dynamic>>? subjects,
    bool? isDirty,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? toast,
    bool clearToast = false,
  }) {
    return BookProfileState(
      bookIdParam: bookIdParam ?? this.bookIdParam,
      isNew: isNew ?? this.isNew,
      isEditMode: isEditMode ?? this.isEditMode,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      bookId: clearBookId ? null : (bookId ?? this.bookId),
      bookName: bookName ?? this.bookName,
      bAuthor: bAuthor ?? this.bAuthor,
      bookCatSubj: clearBookCatSubj ? null : (bookCatSubj ?? this.bookCatSubj),
      pages: clearPages ? null : (pages ?? this.pages),
      pulishedBy: pulishedBy ?? this.pulishedBy,
      publishedYr: clearPublishedYr ? null : (publishedYr ?? this.publishedYr),
      bookPrice: clearBookPrice ? null : (bookPrice ?? this.bookPrice),
      detail: detail ?? this.detail,
      subjects: subjects ?? this.subjects,
      isDirty: isDirty ?? this.isDirty,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      toast: clearToast ? null : (toast ?? this.toast),
    );
  }
}

/// Notifier coordinating single-book authoring, editing, and deletion per §S27.
class BookProfileNotifier extends StateNotifier<BookProfileState> {
  final String bookIdParam;
  final Ref? _ref;

  BookProfileNotifier(this.bookIdParam, [this._ref])
    : super(
        BookProfileState(
          bookIdParam: bookIdParam,
          isNew: bookIdParam == 'new',
          isEditMode: bookIdParam == 'new',
        ),
      );

  Future<Database> _getDb() async {
    return DatabaseService.instance.database;
  }

  int _readSessionUserLevel() {
    return _ref?.read(sessionProvider)?.user.userLevel ?? 1;
  }

  /// Initial load: populates subjects dropdown and existing book record (if not 'new').
  Future<void> loadInitialData() async {
    if (!mounted) return;
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearToast: true,
    );

    try {
      final db = await _getDb();

      // 1. Fetch Subject categories
      final subjRows = await db.rawQuery(
        'SELECT SubjID, SubjName FROM Subject ORDER BY SubjName ASC',
      );

      if (bookIdParam == 'new') {
        if (!mounted) return;
        state = state.copyWith(
          isNew: true,
          isEditMode: true,
          isDirty: false,
          clearBookId: true,
          bookName: '',
          bAuthor: '',
          clearBookCatSubj: true,
          clearPages: true,
          pulishedBy: '',
          clearPublishedYr: true,
          clearBookPrice: true,
          detail: '',
          subjects: subjRows,
          isLoading: false,
          clearErrorMessage: true,
          clearToast: true,
        );
        return;
      }

      // 2. Fetch existing book by integer ID
      final id = int.tryParse(bookIdParam);
      if (id == null) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          subjects: subjRows,
          errorMessage: 'Book not found',
        );
        return;
      }

      final bookRows = await db.rawQuery(
        'SELECT * FROM Books WHERE BookID = ?',
        [id],
      );

      if (!mounted) return;

      if (bookRows.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          subjects: subjRows,
          errorMessage: 'Book not found',
        );
        return;
      }

      final row = bookRows.first;
      state = state.copyWith(
        isNew: false,
        isEditMode: false,
        isDirty: false,
        bookId: row['BookID'] as int?,
        bookName: (row['BookName'] as String?)?.trim() ?? '',
        bAuthor: (row['BAuthor'] as String?)?.trim() ?? '',
        bookCatSubj: row['BookCatSubj'] as int?,
        pages: row['Pages'] as int?,
        pulishedBy: (row['PulishedBy'] as String?)?.trim() ?? '',
        publishedYr: row['PublishedYr'] as int?,
        bookPrice: row['BookPrice'] as int?,
        detail: (row['Detail'] as String?)?.trim() ?? '',
        subjects: subjRows,
        isLoading: false,
        clearErrorMessage: true,
        clearToast: true,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load book profile: $e',
        );
      }
    }
  }

  void switchToEditMode() {
    state = state.copyWith(isEditMode: true, clearErrorMessage: true);
  }

  void updateField(String fieldName, dynamic value) {
    switch (fieldName) {
      case 'bookName':
        state = state.copyWith(bookName: value as String, isDirty: true);
        break;
      case 'bAuthor':
        state = state.copyWith(bAuthor: value as String, isDirty: true);
        break;
      case 'pages':
        final p = value is int ? value : int.tryParse(value.toString());
        state = state.copyWith(pages: p, clearPages: p == null, isDirty: true);
        break;
      case 'pulishedBy':
        state = state.copyWith(pulishedBy: value as String, isDirty: true);
        break;
      case 'publishedYr':
        final y = value is int ? value : int.tryParse(value.toString());
        state = state.copyWith(
          publishedYr: y,
          clearPublishedYr: y == null,
          isDirty: true,
        );
        break;
      case 'bookPrice':
        final pr = value is int ? value : int.tryParse(value.toString());
        state = state.copyWith(
          bookPrice: pr,
          clearBookPrice: pr == null,
          isDirty: true,
        );
        break;
      case 'detail':
        state = state.copyWith(detail: value as String, isDirty: true);
        break;
    }
  }

  void setCategory(int? subjId) {
    state = state.copyWith(
      bookCatSubj: subjId,
      clearBookCatSubj: subjId == null,
      isDirty: true,
      clearErrorMessage: true,
    );
  }

  Future<void> discardDraft() async {
    await loadInitialData();
    state = state.copyWith(isDirty: false, isEditMode: state.isNew);
  }

  /// Commits book record per §S27 `cmdSave_Click` at VA `0x006950a0`.
  Future<bool> save({int? userLvl}) async {
    // Gate 1: Permission check
    final effectiveLvl = userLvl ?? _readSessionUserLevel();
    if (effectiveLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return false;
    }

    // Gate 2: Category validation
    if (state.bookCatSubj == null) {
      state = state.copyWith(errorMessage: 'Must Select Book Category Please.');
      return false;
    }

    // Gate 3: Title validation (trailing space preserved per S27 verbatim string)
    if (state.bookName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Enter Book Name Please ');
      return false;
    }

    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final db = await _getDb();

      if (state.isNew) {
        // Compute next BookID using COALESCE(MAX(BookID), 0) + 1
        final maxRes = await db.rawQuery(
          'SELECT COALESCE(MAX(BookID), 0) + 1 AS nextId FROM Books',
        );
        final nextBookId = (maxRes.first['nextId'] as num?)?.toInt() ?? 1;

        await db.rawInsert(
          'INSERT INTO Books (BookID, BookCatSubj, BookName, BAuthor, Pages, PulishedBy, PublishedYr, BookPrice, Detail) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            nextBookId,
            state.bookCatSubj,
            state.bookName.trim(),
            state.bAuthor.trim(),
            state.pages,
            state.pulishedBy.trim(),
            state.publishedYr,
            state.bookPrice,
            state.detail.trim(),
          ],
        );

        state = state.copyWith(
          bookId: nextBookId,
          isNew: false,
          isEditMode: false,
          isSaving: false,
          isDirty: false,
          clearErrorMessage: true,
          toast: 'Book Saved Successfully',
        );

        await _ref?.read(libraryBooksProvider.notifier).loadInitialData();
        return true;
      } else {
        await db.rawUpdate(
          'UPDATE Books SET BookName = ?, BAuthor = ?, BookCatSubj = ?, Pages = ?, PulishedBy = ?, '
          'PublishedYr = ?, BookPrice = ?, Detail = ? WHERE BookID = ?',
          [
            state.bookName.trim(),
            state.bAuthor.trim(),
            state.bookCatSubj,
            state.pages,
            state.pulishedBy.trim(),
            state.publishedYr,
            state.bookPrice,
            state.detail.trim(),
            state.bookId,
          ],
        );

        state = state.copyWith(
          isEditMode: false,
          isSaving: false,
          isDirty: false,
          clearErrorMessage: true,
          toast: 'Book Saved Successfully',
        );

        await _ref?.read(libraryBooksProvider.notifier).loadInitialData();
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Database error saving book: $e',
      );
      return false;
    }
  }

  /// Deletes existing book record per §S27.
  Future<bool> delete({int? userLvl}) async {
    if (state.isNew || state.bookId == null) {
      state = state.copyWith(errorMessage: 'Select Book First');
      return false;
    }

    final effectiveLvl = userLvl ?? _readSessionUserLevel();
    if (effectiveLvl == 3) {
      state = state.copyWith(
        errorMessage: "You don't have enough rights for purpose",
      );
      return false;
    }

    try {
      final db = await _getDb();
      await db.rawDelete('DELETE FROM Books WHERE BookID = ?', [state.bookId]);

      state = state.copyWith(toast: 'Book record removed');
      await _ref?.read(libraryBooksProvider.notifier).loadInitialData();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Database error deleting book: $e');
      return false;
    }
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  void clearToast() {
    state = state.copyWith(clearToast: true);
  }
}

/// Family provider keyed by bookIdParam ('new' or integer id string).
final bookProfileProvider =
    StateNotifierProvider.family<BookProfileNotifier, BookProfileState, String>(
      (ref, bookIdParam) => BookProfileNotifier(bookIdParam, ref),
    );
