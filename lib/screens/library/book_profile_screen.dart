import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/book_profile_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../widgets/mobile/mobile_status_pill.dart';

/// Screen 24 - BookProfileScreen at `/library/new` and `/library/:id`.
/// Implements §S27 (`frmBooks` at `0x00412598`, `ObjID: 3`) single-book authoring/edit workstation.
class BookProfileScreen extends ConsumerStatefulWidget {
  final String bookIdParam;

  const BookProfileScreen({super.key, required this.bookIdParam});

  @override
  ConsumerState<BookProfileScreen> createState() => _BookProfileScreenState();
}

class _BookProfileScreenState extends ConsumerState<BookProfileScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _authorCtrl = TextEditingController();
  final TextEditingController _publisherCtrl = TextEditingController();
  final TextEditingController _pubYearCtrl = TextEditingController();
  final TextEditingController _pagesCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _detailCtrl = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(bookProfileProvider(widget.bookIdParam).notifier)
            .loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _publisherCtrl.dispose();
    _pubYearCtrl.dispose();
    _pagesCtrl.dispose();
    _priceCtrl.dispose();
    _detailCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncControllersFromState(BookProfileState state) {
    if (_titleCtrl.text != state.bookName) _titleCtrl.text = state.bookName;
    if (_authorCtrl.text != state.bAuthor) _authorCtrl.text = state.bAuthor;
    if (_publisherCtrl.text != state.pulishedBy) {
      _publisherCtrl.text = state.pulishedBy;
    }
    final yStr = state.publishedYr?.toString() ?? '';
    if (_pubYearCtrl.text != yStr) _pubYearCtrl.text = yStr;
    final pStr = state.pages?.toString() ?? '';
    if (_pagesCtrl.text != pStr) _pagesCtrl.text = pStr;
    final prStr = state.bookPrice?.toString() ?? '';
    if (_priceCtrl.text != prStr) _priceCtrl.text = prStr;
    if (_detailCtrl.text != state.detail) _detailCtrl.text = state.detail;
  }

  Future<bool> _showDiscardDialog(
    BuildContext context, {
    required bool isNew,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Discard Unsaved Changes?'),
          content: Text(
            isNew
                ? 'This new book record has not been saved. If you leave now, the details you entered will be lost.'
                : 'You have unsaved changes to this book profile. If you leave now, they will be lost.',
            style: AppTypography.body,
          ),
          actions: [
            OutlinedButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard Changes'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _handleBack() async {
    final state = ref.read(bookProfileProvider(widget.bookIdParam));
    if (state.isDirty) {
      final discard = await _showDiscardDialog(context, isNew: state.isNew);
      if (!discard) return;
    }
    if (mounted) {
      context.go('/library');
    }
  }

  Future<void> _handleCancelEdit() async {
    final state = ref.read(bookProfileProvider(widget.bookIdParam));
    if (state.isDirty) {
      final discard = await _showDiscardDialog(context, isNew: false);
      if (!discard) return;
    }
    await ref
        .read(bookProfileProvider(widget.bookIdParam).notifier)
        .discardDraft();
  }

  Future<void> _handleSave() async {
    final userLevel = ref.read(sessionProvider)?.user.userLevel ?? 1;
    final notifier = ref.read(bookProfileProvider(widget.bookIdParam).notifier);
    final success = await notifier.save(userLvl: userLevel);
    if (success && mounted) {
      final state = ref.read(bookProfileProvider(widget.bookIdParam));
      if (widget.bookIdParam == 'new' && state.bookId != null) {
        context.go('/library/${state.bookId}');
      }
    }
  }

  Future<void> _handleDelete() async {
    final state = ref.read(bookProfileProvider(widget.bookIdParam));
    final notifier = ref.read(bookProfileProvider(widget.bookIdParam).notifier);
    final userLevel = ref.read(sessionProvider)?.user.userLevel ?? 1;

    if (state.isNew || state.bookId == null) {
      notifier.setError('Select Book First');
      return;
    }

    if (userLevel == 3) {
      notifier.setError("You don't have enough rights for purpose");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Book Record?'),
          content: Text(
            'Are you sure you want to permanently delete "${state.bookName.isEmpty ? "this book" : state.bookName}" (Accession #${state.bookId}) from the library catalog?',
            style: AppTypography.body,
          ),
          actions: [
            OutlinedButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusErrorText,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete Book'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final ok = await notifier.delete(userLvl: userLevel);
      if (ok && mounted) {
        context.go('/library');
      }
    }
  }

  void _showSpineLabelNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Spine label coming in Phase E'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookProfileProvider(widget.bookIdParam));
    final notifier = ref.read(bookProfileProvider(widget.bookIdParam).notifier);

    // One-time controller sync upon initial data load
    if (!_isInit && !state.isLoading && (state.bookId != null || state.isNew)) {
      _isInit = true;
      _syncControllersFromState(state);
    }

    // React to state changes (toasts, external resets)
    ref.listen<BookProfileState>(bookProfileProvider(widget.bookIdParam), (
      prev,
      next,
    ) {
      if (prev?.isDirty == true && !next.isDirty) {
        _syncControllersFromState(next);
      }
      if (prev?.isLoading == true && !next.isLoading) {
        _syncControllersFromState(next);
      }
      if (next.toast != null && next.toast != prev?.toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.toast!),
            duration: const Duration(seconds: 2),
          ),
        );
        ref.read(bookProfileProvider(widget.bookIdParam).notifier).clearToast();
      }
    });

    final liveTitle = _titleCtrl.text.trim();
    final liveAuthor = _authorCtrl.text.trim();
    final livePrice = _priceCtrl.text.trim();
    final livePages = _pagesCtrl.text.trim();
    final livePubYear = _pubYearCtrl.text.trim();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleSave,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _handleSave,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () {
          if (!state.isEditMode && !state.isNew) {
            notifier.switchToEditMode();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true): () {
          if (!state.isEditMode && !state.isNew) {
            notifier.switchToEditMode();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            context.go('/library/new'),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            context.go('/library/new'),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _showSpineLabelNotice,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
            _showSpineLabelNotice,
        const SingleActivator(LogicalKeyboardKey.escape): _handleBack,
      },
      child: Focus(
        autofocus: true,
        child: ResponsiveBreakpoints.isMobile(context)
            ? _buildMobileLayout(context, state, notifier)
            : Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // =============================================================
              // REGION A: Header & Action Bar (~52px)
              // =============================================================
              _buildHeader(context, state, notifier),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                _buildErrorBanner(state.errorMessage!, notifier),
              ],
              const SizedBox(height: 12),

              // =============================================================
              // REGION B: Two-Column Body (Expanded)
              // =============================================================
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Column (Cover Card & Live Summary)
                    SizedBox(
                      width: 310,
                      child: _buildLeftCoverCard(
                        state,
                        liveTitle,
                        liveAuthor,
                        livePrice,
                        livePages,
                        livePubYear,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right Column (Bibliographic Form)
                    Expanded(child: _buildRightFormCard(state, notifier)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Region A: Header Row
  // ===========================================================================
  Widget _buildHeader(
    BuildContext context,
    BookProfileState state,
    BookProfileNotifier notifier,
  ) {
    return Row(
      children: [
        // Back button
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Book Catalog',
          onPressed: _handleBack,
        ),
        const SizedBox(width: 8),

        // Title
        Text(
          'Book Accession Dossier',
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(width: 12),

        // Accession Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.statusInfoBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '#${state.isNew ? "NEW" : state.bookId}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.statusInfoText,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Category Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            state.currentCategoryName.isEmpty
                ? 'Uncategorized'
                : state.currentCategoryName,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Unsaved changes dirty badge
        if (state.isDirty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Text(
              'Unsaved Changes',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.statusWarningText,
              ),
            ),
          ),

        const SizedBox(width: 16),

        // Right Action Toolbar Buttons
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!state.isEditMode && !state.isNew) ...[
                  ElevatedButton.icon(
                    onPressed: notifier.switchToEditMode,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Edit Book (Ctrl+E)',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/library/new'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add Another Book (Ctrl+N)',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showSpineLabelNotice,
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text(
                      'Print Label (Ctrl+P)',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _handleDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppColors.statusErrorText,
                    ),
                    label: const Text(
                      'Delete Book',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.statusErrorText,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      side: const BorderSide(color: AppColors.statusErrorText),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _handleSave,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text(
                      'Save Changes (Ctrl+S)',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                  if (!state.isNew)
                    OutlinedButton(
                      onPressed: _handleCancelEdit,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _showSpineLabelNotice,
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text(
                      'Print Label (Ctrl+P)',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  if (!state.isNew)
                    OutlinedButton.icon(
                      onPressed: _handleDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.statusErrorText,
                      ),
                      label: const Text(
                        'Delete Book',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.statusErrorText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: const BorderSide(
                          color: AppColors.statusErrorText,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message, BookProfileNotifier notifier) {
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
  // Region B (Left): Stylized Book Cover & Summary Card
  // ===========================================================================
  Widget _buildLeftCoverCard(
    BookProfileState state,
    String liveTitle,
    String liveAuthor,
    String livePrice,
    String livePages,
    String livePubYear,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stylized Book Cover Display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 64,
                    color: AppColors.brandPrimary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    liveTitle.isEmpty ? 'Untitled Book' : liveTitle,
                    style: AppTypography.h3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    liveAuthor.isEmpty ? '(no author)' : liveAuthor,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusInfoBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      state.currentCategoryName.isEmpty
                          ? 'Uncategorized'
                          : state.currentCategoryName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusInfoText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20, color: AppColors.borderSubtle),

          // Summary Rows
          _buildSummaryRow(
            'Accession Number',
            state.isNew ? 'Auto (next available)' : '#${state.bookId}',
            isBold: true,
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            'Replacement Price',
            'Rs. ${livePrice.isEmpty ? "0" : livePrice}',
            isBold: true,
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            'Page Count',
            livePages.isEmpty ? '-' : '$livePages pp.',
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            'Publication Year',
            livePubYear.isEmpty ? '-' : livePubYear,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Region B (Right): Bibliographic Form Card
  // ===========================================================================
  Widget _buildRightFormCard(
    BookProfileState state,
    BookProfileNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1 Header
              Text(
                'BIBLIOGRAPHIC & PUBLICATION METADATA',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Row 1: Book Title * and Subject Category *
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book Title *',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _titleCtrl,
                            readOnly: !state.isEditMode,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Enter book title',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
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
                            onChanged: (v) {
                              notifier.updateField('bookName', v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subject Category *',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey(state.bookCatSubj),
                            initialValue: state.bookCatSubj,
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
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
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
                            hint: const Text(
                              'Select Subject',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            items: state.subjects.map((s) {
                              return DropdownMenuItem<int?>(
                                value: (s['SubjID'] as num?)?.toInt(),
                                child: Text(
                                  s['SubjName'] as String? ?? '',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: state.isEditMode
                                ? (v) => notifier.setCategory(v)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Author / Editor and Publisher
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Author / Editor',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _authorCtrl,
                            readOnly: !state.isEditMode,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Author or editor name',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
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
                            onChanged: (v) {
                              notifier.updateField('bAuthor', v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publisher',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _publisherCtrl,
                            readOnly: !state.isEditMode,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Publisher name',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
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
                            onChanged: (v) {
                              notifier.updateField('pulishedBy', v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Publication Year, Total Pages, Price (Rs.)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publication Year',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _pubYearCtrl,
                            readOnly: !state.isEditMode,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'e.g. 2017',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
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
                            onChanged: (v) {
                              notifier.updateField('publishedYr', v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Pages',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _pagesCtrl,
                            readOnly: !state.isEditMode,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'e.g. 280',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
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
                            onChanged: (v) {
                              notifier.updateField('pages', v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price (Rs.)',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _priceCtrl,
                            readOnly: !state.isEditMode,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'e.g. 350',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
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
                            onChanged: (v) {
                              notifier.updateField('bookPrice', v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 2 Header
              Text(
                'NARRATIVE REMARKS / CONDITION NOTES',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Remarks TextField
              Text(
                'Remarks',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _detailCtrl,
                readOnly: !state.isEditMode,
                minLines: 3,
                maxLines: 4,
                maxLength: 255,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Optional notes on edition, shelf location, or condition...',
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.borderDefault,
                    ),
                  ),
                ),
                onChanged: (v) {
                  notifier.updateField('detail', v);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MOBILE BRANCH (< 600px)
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    BookProfileState state,
    BookProfileNotifier notifier,
  ) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMobileHeader(context, state, notifier),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileHeroCard(state),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _buildErrorBanner(state.errorMessage!, notifier),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _buildMobileFormCard(context, state, notifier),
                  ],
                ),
              ),
            ),
            _buildMobileStickyActions(context, state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    BookProfileState state,
    BookProfileNotifier notifier,
  ) {
    final title = state.isNew ? 'New Book Record' : 'Book Profile';
    return Row(
      children: [
        IconButton(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back, size: 20),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            title,
            style: AppTypography.h2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!state.isNew && !state.isEditMode)
          const MobileStatusPill(
            label: 'Read Only',
            variant: MobileStatusVariant.neutral,
          )
        else if (state.isDirty)
          const MobileStatusPill(
            label: 'Unsaved',
            variant: MobileStatusVariant.warning,
          ),
      ],
    );
  }

  Widget _buildMobileHeroCard(BookProfileState state) {
    final liveTitle = _titleCtrl.text.trim();
    final liveAuthor = _authorCtrl.text.trim();
    final displayTitle = liveTitle.isNotEmpty
        ? liveTitle
        : (state.bookName.isNotEmpty
            ? state.bookName
            : (state.isNew ? 'New Book Record' : 'Untitled Book'));
    final displayAuthor = liveAuthor.isNotEmpty
        ? liveAuthor
        : (state.bAuthor.isNotEmpty ? state.bAuthor : '—');
    final categoryName = state.subjects
        .firstWhere(
          (c) => (c['SubjID'] as num?)?.toInt() == state.bookCatSubj,
          orElse: () => {'SubjName': 'Unassigned'},
        )['SubjName'] as String? ??
        'Unassigned';

    return Card(
      margin: EdgeInsets.zero,
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
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.accentLibrarySoftBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.menu_book,
                        size: 28,
                        color: AppColors.accentLibrary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayTitle,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Author: $displayAuthor',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Accession #${state.bookId ?? "NEW"}',
                                style: AppTypography.monospace.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              MobileStatusPill(
                                label: categoryName,
                                variant: MobileStatusVariant.neutral,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFormCard(
    BuildContext context,
    BookProfileState state,
    BookProfileNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'BIBLIOGRAPHIC & PUBLICATION METADATA',
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Title
          _buildMobileFormFieldLabel('Book Title *'),
          const SizedBox(height: 4),
          TextField(
            controller: _titleCtrl,
            readOnly: !state.isEditMode,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('Enter book title'),
            onChanged: (v) {
              notifier.updateField('bookName', v);
              setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Subject Category dropdown
          _buildMobileFormFieldLabel('Subject Category *'),
          const SizedBox(height: 4),
          Container(
            height: 44,
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                key: ValueKey(state.bookCatSubj),
                value: state.subjects.any(
                  (s) => (s['SubjID'] as num?)?.toInt() == state.bookCatSubj,
                )
                    ? state.bookCatSubj
                    : null,
                isExpanded: true,
                isDense: true,
                dropdownColor: AppColors.surfaceRaised,
                hint: const Text(
                  'Select Subject',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                selectedItemBuilder: (ctx) => state.subjects.map((s) {
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      s['SubjName'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                items: state.subjects.map((s) {
                  return DropdownMenuItem<int?>(
                    value: (s['SubjID'] as num?)?.toInt(),
                    child: Text(
                      s['SubjName'] as String? ?? '',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: state.isEditMode
                    ? (v) => notifier.setCategory(v)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Author / Editor
          _buildMobileFormFieldLabel('Author / Editor'),
          const SizedBox(height: 4),
          TextField(
            controller: _authorCtrl,
            readOnly: !state.isEditMode,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('Author or editor name'),
            onChanged: (v) {
              notifier.updateField('bAuthor', v);
              setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Publisher
          _buildMobileFormFieldLabel('Publisher'),
          const SizedBox(height: 4),
          TextField(
            controller: _publisherCtrl,
            readOnly: !state.isEditMode,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('Publisher name'),
            onChanged: (v) {
              notifier.updateField('pulishedBy', v);
              setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Publication Year & Pages
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMobileFormFieldLabel('Publication Year'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _pubYearCtrl,
                      readOnly: !state.isEditMode,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: _mobileInputDecoration('e.g. 2017'),
                      onChanged: (v) {
                        notifier.updateField('publishedYr', v);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMobileFormFieldLabel('Total Pages'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _pagesCtrl,
                      readOnly: !state.isEditMode,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: _mobileInputDecoration('e.g. 280'),
                      onChanged: (v) {
                        notifier.updateField('pages', v);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Price
          _buildMobileFormFieldLabel('Price (Rs.)'),
          const SizedBox(height: 4),
          TextField(
            controller: _priceCtrl,
            readOnly: !state.isEditMode,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration('e.g. 350'),
            onChanged: (v) {
              notifier.updateField('bookPrice', v);
              setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Section 2: Remarks
          Text(
            'NARRATIVE REMARKS / CONDITION NOTES',
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMobileFormFieldLabel('Remarks'),
          const SizedBox(height: 4),
          TextField(
            controller: _detailCtrl,
            readOnly: !state.isEditMode,
            minLines: 3,
            maxLines: 4,
            maxLength: 255,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _mobileInputDecoration(
              'Additional details or condition notes...',
            ),
            onChanged: (v) {
              notifier.updateField('detail', v);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFormFieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  InputDecoration _mobileInputDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppTypography.bodySmall.copyWith(
        color: AppColors.textMuted,
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
    );
  }

  Widget _buildMobileStickyActions(
    BuildContext context,
    BookProfileState state,
    BookProfileNotifier notifier,
  ) {
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
      child: state.isEditMode || state.isNew
          ? Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _handleCancelEdit,
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _handleSave,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text(
                        'Save Changes (Ctrl+S)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => notifier.switchToEditMode(),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Book (Ctrl+E)'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _handleDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.statusErrorText,
                      ),
                      label: const Text(
                        'Delete Book',
                        style: TextStyle(color: AppColors.statusErrorText),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.statusErrorText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
