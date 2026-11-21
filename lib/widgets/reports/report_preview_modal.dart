import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:school_automation/core/providers/report_preview_provider.dart';
import 'package:school_automation/core/sync/sync_provider.dart';
import 'package:school_automation/core/theme/app_theme_tokens.dart';
import 'package:school_automation/core/utils/platform_compat.dart';
import 'package:school_automation/core/utils/responsive_breakpoints.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';

/// Orientation choices for the preview modal's desktop toolbar toggle
/// (Phase K Shot 3b-core). pdf 3.13.x has no built-in orientation enum.
enum _PdfOrientation { portrait, landscape }

// ---------------------------------------------------------------------------
// Public entry-point
// ---------------------------------------------------------------------------

class ReportPreviewModal extends ConsumerStatefulWidget {
  const ReportPreviewModal({
    super.key,
    required this.request,
    this.headerControls,
    this.isLegacyWindowsOverride,
  });

  final ReportRequest request;
  final Widget? headerControls;
  final bool? isLegacyWindowsOverride;

  static Future<void> show(
    BuildContext context, {
    required ReportRequest request,
    Widget? headerControls,
    bool? isLegacyWindowsOverride,
  }) {
    // Phase K-6 Item 3: the dialog is barrier-dismissible so an outside
    // click/tap dismisses it on Windows touch/mouse (ESC already works via
    // the modal's CallbackShortcuts; there is no PopScope blocking pop).
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ReportPreviewModal(
        request: request,
        headerControls: headerControls,
        isLegacyWindowsOverride: isLegacyWindowsOverride,
      ),
    );
  }

  @override
  ConsumerState<ReportPreviewModal> createState() => _ReportPreviewModalState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _ReportPreviewModalState extends ConsumerState<ReportPreviewModal> {
  final FocusNode _focusNode = FocusNode();

  // Shot 6j: cached PDF preview source. `PdfPreview` re-runs its internal
  // rendering whenever its `build` callback changes identity, so we cache
  // both the latest bytes and a per-bytes closure in State. Unrelated
  // rebuilds (parent or provider ticks) reuse the same closure; only a real
  // byte change (user-driven refresh / mode toggle) produces a new one.
  Uint8List? _previewBytes;
  Future<Uint8List> Function(PdfPageFormat)? _pdfPreviewBuilder;

  void _syncPdfPreviewBuilder(Uint8List? bytes) {
    if (bytes == null) {
      _previewBytes = null;
      _pdfPreviewBuilder = null;
      return;
    }
    if (!identical(bytes, _previewBytes)) {
      _previewBytes = bytes;
      _pdfPreviewBuilder = (_) async => bytes;
    }
  }

  // Phase K Shot 3b-core, extended in K-6 Run 1: local mirror of the
  // orientation override so the segmented button reflects the active
  // selection immediately, AND an explicit argument of the preview provider
  // family key (see _previewKey) so toggling orientation rotates to a fresh
  // bytes generation instead of mutating a long-lived notifier.
  PdfPageFormat? _pageFormatOverride;

  // Local mode selection — only used when request.type == feeVoucher.
  // 0 = Three-Copy Slips, 1 = Cohort Ledger.
  int _selectedFeeMode = 0;

  /// Phase K-6 Run 1: composite provider family key. Orientation and voucher
  /// mode are explicit arguments of the bytes generation; changing either
  /// key invalidates by construction (fresh notifier, fresh loading → bytes
  /// lifecycle, previous notifier auto-disposed).
  ReportPreviewKey get _previewKey => ReportPreviewKey(
    request: widget.request,
    pageFormat: _pageFormatOverride,
    feeVoucherMode: _selectedFeeMode,
  );

  @override
  void initState() {
    super.initState();
    _pageFormatOverride = widget.request.pageFormatOverride;
  }

  /// Current orientation: the modal override wins, else the request's
  /// natural page format decides portrait vs landscape.
  ///
  /// pdf 3.13.x ships no `PdfPageOrientation` enum, so a local one mirrors
  /// the spec's segmented-button value type.
  _PdfOrientation get _currentOrientation {
    final fmt = _pageFormatOverride ?? widget.request.naturalPageFormat;
    return fmt.height > fmt.width
        ? _PdfOrientation.portrait
        : _PdfOrientation.landscape;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  bool get _isLegacy => widget.isLegacyWindowsOverride ?? isLegacyWindows();

  Future<void> _handleOpenPdf(Uint8List bytes) async {
    final success = await openPdfExternal(
      bytes: bytes,
      fileName: widget.request.effectiveFileName,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open external PDF viewer. Please use Export PDF.',
          ),
        ),
      );
    }
  }

  Future<void> _handleSavePdf(Uint8List bytes) async {
    try {
      await FilePicker.saveFile(
        fileName: widget.request.effectiveFileName,
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: 'Save PDF Report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Future<void> _handlePrint(Uint8List bytes) async {
    if (_isLegacy) {
      await _handleOpenPdf(bytes);
      return;
    }
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: widget.request.effectiveTitle,
    );
  }

  Future<void> _handleShare(Uint8List bytes, String filename) async {
    if (_isLegacy) {
      await _handleOpenPdf(bytes);
      return;
    }
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Phase K-6 Run 1: mode is an explicit argument of the provider family
  /// key — the setState alone drives regeneration (the watch key changes,
  /// creating a fresh notifier seeded with the new mode).
  void _setVoucherMode(int mode) {
    setState(() => _selectedFeeMode = mode);
  }

  void _handleClose() => Navigator.of(context).pop();

  /// Live `Refresh Data`: re-queries local SQLite with the current filters by
  /// re-running the request builder (updating the preview rows and printable
  /// PDF in-place, without closing the preview), then triggers a non-blocking
  /// background cloud sync. The sync trigger is guarded so widget tests never
  /// hang on network I/O.
  Future<void> _onRefreshData() async {
    await ref.read(reportPreviewProvider(_previewKey).notifier).generate();
    if (!const bool.fromEnvironment('FLUTTER_TEST')) {
      try {
        ref.read(syncPushProvider.notifier).triggerManualSync();
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Voucher mode toggle helper
  // ---------------------------------------------------------------------------

  /// Shot 3b: high-contrast count pill for the preview header — shows the
  /// exact number of vouchers in this batch and the pages they will print
  /// (one A4 page per voucher), e.g. '71 Vouchers · 71 Pages'. Hidden when
  /// the report carries no voucher records.
  Widget? _buildCountBadge() {
    // Defaulter list: badge reads from the summary (totalDefaulters +
    // uniqueStudents) rather than request.vouchers which carries class groups.
    if (widget.request.type == ReportType.defaulterList) {
      final summary =
          widget.request.extraParams['summary'] as DefaulterListFilterSummary?;
      if (summary == null) return null;
      final label =
          '${summary.totalDefaulters} Vouchers · ${summary.uniqueStudents} Students';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: AppTypography.label.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E40AF),
          ),
        ),
      );
    }

    // All other report types: count individual voucher records.
    final count = widget.request.vouchers?.length ?? 0;
    if (count == 0) return null;
    final label = count == 1
        ? '1 Voucher · 1 Page'
        : '$count Vouchers · $count Pages';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E40AF),
        ),
      ),
    );
  }

  Widget _buildVoucherModeToggle() {
    return SegmentedButton<int>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: AppTypography.bodySmall,
      ),
      segments: const [
        ButtonSegment<int>(value: 0, label: Text('3-Copy Slips')),
        ButtonSegment<int>(value: 1, label: Text('Cohort Ledger')),
      ],
      selected: {_selectedFeeMode},
      onSelectionChanged: (s) {
        // Phase K-6 Run 1: mode is part of the provider family key —
        // setState alone rotates to a fresh bytes generation.
        setState(() => _selectedFeeMode = s.first);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Phase K-6 Run 1: the watched family key carries the orientation and
    // voucher mode — changing either rotates to a fresh notifier instance
    // (fresh loading → bytes lifecycle) after the local state change, which
    // is the invalidation point. The previous notifier is auto-disposed, so
    // its in-flight generation can never publish stale bytes over the new
    // render.
    final state = ref.watch(reportPreviewProvider(_previewKey));

    // Shot 6j: background sync pulls (dbDataVersionProvider bumps) and parent
    // provider rebuilds must NOT regenerate the open preview — the modal
    // keeps showing the snapshot it was opened with. Regeneration happens
    // only when the user explicitly taps the toolbar's Refresh Data button
    // (_onRefreshData) or the voucher mode toggle.

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): _handleClose,
      const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
        if (state.bytes != null) _handlePrint(state.bytes!);
      },
      const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () {
        if (state.bytes != null) _handlePrint(state.bytes!);
      },
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        if (state.bytes != null) _handleSavePdf(state.bytes!);
      },
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
        if (state.bytes != null) _handleSavePdf(state.bytes!);
      },
    };

    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < ResponsiveBreakpoints.mobileMax;
    final isDesktop = size.width >= ResponsiveBreakpoints.tabletMax;
    final dialogWidth = isMobile ? size.width : size.width * 0.92;
    final dialogHeight = isMobile ? size.height : size.height * 0.92;

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          shape: isMobile
              ? const RoundedRectangleBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
          child: SafeArea(
            top: isMobile,
            bottom: false,
            left: false,
            right: false,
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: isMobile
                      ? BorderRadius.zero
                      : BorderRadius.circular(AppRadius.lg),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildToolbar(state, isMobile, isDesktop),
                    Expanded(child: _buildBody(state)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toolbar
  // ---------------------------------------------------------------------------

  /// Phase K-6 Run 2: three toolbar shapes so every applicable action is
  /// reachable at every width and no button is ever clipped off the right
  /// edge:
  /// - desktop (>= 1024): single fixed-height row; trailing controls live in
  ///   a horizontal SingleChildScrollView whose inner Row is sized to its
  ///   intrinsic content width (no Expanded/Flexible inside the scroll —
  ///   Argon Rule 13), with the Close button fixed OUTSIDE the scroll.
  /// - tablet (600..1023): Wrap(alignment: end) — buttons flow onto multiple
  ///   lines instead of scrolling out of view.
  /// - mobile (< 600): minimal row; secondary actions live in the overflow
  ///   PopupMenuButton (never a hiding conditional).
  Widget _buildToolbar(ReportPreviewState state, bool isMobile, bool isDesktop) {
    if (isMobile) {
      return _buildMobileToolbar(state);
    }
    if (!isDesktop) {
      return _buildTabletToolbar(state);
    }

    final hasBytes = state.bytes != null;

    // Title area: kept OUTSIDE the trailing scroll view so its Expanded
    // sizing (with ellipsis) stays valid. NB: bare Column here — the Row
    // wraps it in ONE Expanded (see below). Phase K-6 Run 2b: the count
    // pill lives HERE (under the title) instead of inside the action row —
    // ~140px of intrinsic width leaves the toolbar, which is the primary
    // lever that lets the whole action set fit a 1024px-wide dialog
    // without scrolling.
    final Widget titleArea = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.request.effectiveTitle,
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.request.subtitle != null &&
            widget.request.subtitle!.isNotEmpty)
          Text(
            widget.request.subtitle!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        else if (_buildCountBadge() != null)
          _buildCountBadge()!,
      ],
    );

    // Trailing controls: wrapped in a horizontal scroll view so the toolbar
    // (PDF icon, count pill, orientation toggle, voucher mode toggle, action
    // buttons) can never RenderFlex-overflow, even when every optional
    // control is present at once (Phase K Shot 3b-core fallback). The title
    // column above keeps its Expanded sizing outside the scroll view.
    // Argon Rule 13: the inner Row is sized to its INTRINSIC content width
    // (mainAxisSize.min) and contains no Expanded/Flexible/Spacer, so the
    // horizontal scroll extent is exactly the content width.
    //
    // Phase K-6 Run 2b compression (the count pill moved to the title
    // column and the Print label shortened) targets the whole action set
    // fitting a 1024px-wide dialog (942px) WITHOUT scrolling — K-1 lesson:
    // leave >=10% slack on Windows font metrics rather than an exact fit.
    // The scroll view stays as the overflow safety net.
    final compactActions = MediaQuery.sizeOf(context).width < 1280;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          bottom: BorderSide(color: AppColors.borderDefault, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.picture_as_pdf_outlined,
            color: AppColors.brandPrimary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Title: 1 flex share (it can ellipsize); the trailing controls
          // get the remaining 4 — Run 2's 50/50 split let the title's
          // unused allocation starve the scroll viewport at 1024px and
          // push Print out of the dialog (the Windows client report).
          Expanded(flex: 1, child: titleArea),
          Flexible(
            flex: 4,
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- K Shot 3b-core: orientation toggle (desktop only) -----
                  // Phase K-6 Run 2b: reports whose column layout is
                  // designed for their natural format (lockedOrientation)
                  // render the toggle DISABLED. On legacy Windows (Win 8.1),
                  // orientation toggle is omitted since in-app preview is disabled.
                  if (!_isLegacy) ...[
                    Tooltip(
                      message: widget.request.locksOrientation
                          ? 'This report is designed for A4 landscape '
                              'and cannot be re-oriented.'
                          : '',
                      child: SegmentedButton<_PdfOrientation>(
                        key: const ValueKey('report_toolbar_orientation'),
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          textStyle: AppTypography.bodySmall,
                        ),
                        segments: const [
                          ButtonSegment(
                            value: _PdfOrientation.portrait,
                            label: Text('Portrait'),
                            icon: Icon(Icons.crop_portrait, size: 14),
                          ),
                          ButtonSegment(
                            value: _PdfOrientation.landscape,
                            label: Text('Landscape'),
                            icon: Icon(Icons.crop_landscape, size: 14),
                          ),
                        ],
                        selected: {_currentOrientation},
                        onSelectionChanged: widget.request.locksOrientation
                            ? null
                            : (s) {
                                final chosen = s.first;
                                final override =
                                    chosen == _PdfOrientation.landscape
                                        ? PdfPageFormat.a4.landscape
                                        : PdfPageFormat.a4;
                                setState(() => _pageFormatOverride = override);
                              },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],

                  // --- Optional caller-supplied controls ----------------------
                  if (widget.headerControls != null) ...[
                    widget.headerControls!,
                    const SizedBox(width: AppSpacing.sm),
                  ],

                  // --- Voucher mode toggle (feeVoucher only) ------------------
                  if (widget.request.type == ReportType.feeVoucher) ...[
                    _buildVoucherModeToggle(),
                    const SizedBox(width: AppSpacing.sm),
                  ],

                  // --- Refresh Data (re-query + background sync) --------------
                  IconButton(
                    key: const ValueKey('report_toolbar_refresh'),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh Data',
                    iconSize: 20,
                    onPressed: state.isLoading ? null : _onRefreshData,
                  ),

                  const SizedBox(width: AppSpacing.xs),

                  // --- Export PDF button --------------------------------------
                  // Phase K-6 Run 2b: below 1280px the label collapses to an
                  // icon-only button (stable key retained) — at 1024px the
                  // labeled button is the second-largest fixed width in the
                  // row and pushed Print out of the dialog on Windows.
                  if (compactActions)
                    IconButton(
                      key: const ValueKey('report_toolbar_export'),
                      icon: const Icon(Icons.download_outlined, size: 20),
                      tooltip: 'Export PDF',
                      onPressed:
                          hasBytes ? () => _handleSavePdf(state.bytes!) : null,
                    )
                  else
                    OutlinedButton.icon(
                      key: const ValueKey('report_toolbar_export'),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Export PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderDefault),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed:
                          hasBytes ? () => _handleSavePdf(state.bytes!) : null,
                    ),

                  const SizedBox(width: AppSpacing.xs),

                  // --- Print button (or Open PDF on legacy) -------------------
                  if (_isLegacy)
                    compactActions
                        ? IconButton(
                            key: const ValueKey('report_toolbar_open'),
                            icon: const Icon(Icons.open_in_new_rounded, size: 20),
                            tooltip: 'Open PDF',
                            onPressed: hasBytes
                                ? () => _handleOpenPdf(state.bytes!)
                                : null,
                          )
                        : ElevatedButton.icon(
                            key: const ValueKey('report_toolbar_open'),
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Open PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: hasBytes
                                ? () => _handleOpenPdf(state.bytes!)
                                : null,
                          )
                  else
                    ElevatedButton.icon(
                      key: const ValueKey('report_toolbar_print'),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed:
                          hasBytes ? () => _handlePrint(state.bytes!) : null,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // --- Close (Phase K-6 Item 3 / Run 2 stable key) --------------
          // Fixed trailing position OUTSIDE the horizontal scroll view so
          // the close button is always visible at tablet + desktop widths,
          // even when every optional toolbar control is present and the
          // scrollable row overflows.
          IconButton(
            key: const ValueKey('report_toolbar_close'),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            iconSize: 20,
            onPressed: _handleClose,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet toolbar (600..1023): Wrap — buttons flow onto multiple lines
  // ---------------------------------------------------------------------------

  /// Phase K-6 Run 2: below desktop width the toolbar wraps onto multiple
  /// lines instead of scrolling buttons out of view. Argon Rule 13: no
  /// horizontal scroll view, so the title's Expanded lives in a plain Row
  /// inside a vertically-stacked Column (no vertical scroll view here).
  Widget _buildTabletToolbar(ReportPreviewState state) {
    final hasBytes = state.bytes != null;
    final countBadge = _buildCountBadge();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          bottom: BorderSide(color: AppColors.borderDefault, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.request.effectiveTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                ),
              ),
              if (countBadge != null) ...[
                const SizedBox(width: AppSpacing.sm),
                countBadge,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (!_isLegacy)
                Tooltip(
                  message: widget.request.locksOrientation
                      ? 'This report is designed for A4 landscape '
                          'and cannot be re-oriented.'
                      : '',
                  child: SegmentedButton<_PdfOrientation>(
                    key: const ValueKey('report_toolbar_orientation'),
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: AppTypography.bodySmall,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: _PdfOrientation.portrait,
                        label: Text('Portrait'),
                        icon: Icon(Icons.crop_portrait, size: 14),
                      ),
                      ButtonSegment(
                        value: _PdfOrientation.landscape,
                        label: Text('Landscape'),
                        icon: Icon(Icons.crop_landscape, size: 14),
                      ),
                    ],
                    selected: {_currentOrientation},
                    onSelectionChanged: widget.request.locksOrientation
                        ? null
                        : (s) {
                            final chosen = s.first;
                            final override = chosen == _PdfOrientation.landscape
                                ? PdfPageFormat.a4.landscape
                                : PdfPageFormat.a4;
                            setState(() => _pageFormatOverride = override);
                          },
                  ),
                ),
              if (widget.headerControls != null) widget.headerControls!,
              IconButton(
                key: const ValueKey('report_toolbar_refresh'),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Data',
                visualDensity: VisualDensity.compact,
                onPressed: state.isLoading ? null : _onRefreshData,
              ),
              OutlinedButton.icon(
                key: const ValueKey('report_toolbar_export'),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderDefault),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: hasBytes ? () => _handleSavePdf(state.bytes!) : null,
              ),
              if (_isLegacy)
                ElevatedButton.icon(
                  key: const ValueKey('report_toolbar_open'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed:
                      hasBytes ? () => _handleOpenPdf(state.bytes!) : null,
                )
              else
                ElevatedButton.icon(
                  key: const ValueKey('report_toolbar_print'),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: hasBytes ? () => _handlePrint(state.bytes!) : null,
                ),
              IconButton(
                key: const ValueKey('report_toolbar_close'),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: _handleClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile toolbar
  // ---------------------------------------------------------------------------

  Widget _buildMobileToolbar(ReportPreviewState state) {
    final hasBytes = state.bytes != null;
    final isVoucher = widget.request.type == ReportType.feeVoucher;

    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          bottom: BorderSide(color: AppColors.borderDefault, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.request.effectiveTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h3,
            ),
          ),
          // --- Shot 3b: N Vouchers · N Pages count pill ------------------------
          if (_buildCountBadge() != null) ...[
            _buildCountBadge()!,
            const SizedBox(width: AppSpacing.xs),
          ],
          IconButton(
            key: const ValueKey('report_toolbar_refresh'),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh Data',
            onPressed: state.isLoading ? null : _onRefreshData,
          ),
          if (!_isLegacy)
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: 'Share PDF',
              onPressed: hasBytes
                  ? () => _handleShare(
                        state.bytes!,
                        widget.request.effectiveFileName,
                      )
                  : null,
            ),
          if (_isLegacy)
            IconButton(
              key: const ValueKey('report_toolbar_open'),
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              tooltip: 'Open PDF',
              onPressed: hasBytes ? () => _handleOpenPdf(state.bytes!) : null,
            )
          else
            IconButton(
              key: const ValueKey('report_toolbar_print'),
              icon: const Icon(Icons.print_outlined, size: 20),
              tooltip: 'Print',
              onPressed: hasBytes ? () => _handlePrint(state.bytes!) : null,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: 'More actions',
            onSelected: (value) {
              switch (value) {
                case 'open_external':
                  if (hasBytes) _handleOpenPdf(state.bytes!);
                  break;
                case 'export':
                  if (hasBytes) _handleSavePdf(state.bytes!);
                  break;
                case 'regenerate':
                  _onRefreshData();
                  break;
                case 'voucher_slips':
                  _setVoucherMode(0);
                  break;
                case 'voucher_ledger':
                  _setVoucherMode(1);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (_isLegacy)
                const PopupMenuItem(
                  value: 'open_external',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Open in PDF Viewer'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Export PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'regenerate',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Regenerate'),
                  ],
                ),
              ),
              if (isVoucher) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'voucher_slips',
                  child: Text('Mode: 3-Copy Slips'),
                ),
                const PopupMenuItem(
                  value: 'voucher_ledger',
                  child: Text('Mode: Cohort Ledger'),
                ),
              ],
            ],
          ),

          // --- Close (Phase K-6 Item 3 / Run 2 stable key) --------------
          // Top-right fixed trailing position so the close affordance is
          // always visible on mobile, mirroring the desktop toolbar.
          IconButton(
            key: const ValueKey('report_toolbar_close'),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
            onPressed: _handleClose,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _buildBody(ReportPreviewState state) {
    // Dark slate canvas matching AppDarkColors.surface
    const canvasColor = Color(0xFF0F172A);

    if (state.isLoading) {
      return Container(
        color: canvasColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Generating PDF...',
                style: AppTypography.body.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (state.error != null) {
      return Container(
        color: canvasColor,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.statusErrorText,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to generate report',
                style: AppTypography.h3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  state.error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: () => ref
                        .read(reportPreviewProvider(_previewKey).notifier)
                        .generate(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _handleClose,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Legacy Windows 8.1 / 7 safe panel: in-app rasterization crashes native OS (0xc0000409).
    // Pure Dart PDF generation is fully intact; render safe export/open workstation.
    if (_isLegacy) {
      return Container(
        color: canvasColor,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderDefault),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.brandPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.request.effectiveTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'In-app PDF preview and direct print are not supported on Windows 8.1. '
                  'Use Export PDF or Open PDF to print from your PDF viewer.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ElevatedButton.icon(
                      key: const ValueKey('report_legacy_open'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: state.bytes != null
                          ? () => _handleOpenPdf(state.bytes!)
                          : null,
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('report_legacy_export'),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Export PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderDefault),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: state.bytes != null
                          ? () => _handleSavePdf(state.bytes!)
                          : null,
                    ),
                    TextButton.icon(
                      key: const ValueKey('report_legacy_close'),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Close'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _handleClose,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // PDF preview
    _syncPdfPreviewBuilder(state.bytes);
    final pdfPreviewBuilder = _pdfPreviewBuilder;
    if (pdfPreviewBuilder == null) {
      return Container(color: canvasColor);
    }
    return Container(
      color: canvasColor,
      child: PdfPreview(
        // Phase K-6 Run 1: key the viewer on the bytes instance. When the
        // provider hands over new bytes (orientation toggle, mode toggle,
        // Refresh Data), the whole PdfPreview subtree remounts with a fresh
        // internal raster state. printing 5.15.x silently DROPS a re-raster
        // requested while a previous raster is still in flight
        // (PdfPreviewRaster._raster() starts with `if (_rastering) return;`
        // behind a 300ms debounce), which is the classic "first click does
        // nothing, second click works" symptom. A fresh State can never be
        // mid-raster, so the first re-render always rasterizes.
        key: ValueKey<Uint8List?>(state.bytes),
        build: pdfPreviewBuilder,
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: widget.request.effectiveFileName,
      ),
    );
  }
}
