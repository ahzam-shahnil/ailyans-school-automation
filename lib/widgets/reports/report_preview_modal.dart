import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:school_automation/core/providers/report_preview_provider.dart';
import 'package:school_automation/core/theme/app_theme_tokens.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';

// ---------------------------------------------------------------------------
// Public entry-point
// ---------------------------------------------------------------------------

class ReportPreviewModal extends ConsumerStatefulWidget {
  const ReportPreviewModal({
    super.key,
    required this.request,
    this.headerControls,
  });

  final ReportRequest request;
  final Widget? headerControls;

  static Future<void> show(
    BuildContext context, {
    required ReportRequest request,
    Widget? headerControls,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportPreviewModal(
        request: request,
        headerControls: headerControls,
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

  // Local mode selection — only used when request.type == feeVoucher.
  // 0 = Three-Copy Slips, 1 = Cohort Ledger.
  int _selectedFeeMode = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _handlePrint(Uint8List bytes) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: widget.request.effectiveTitle,
    );
  }

  void _handleClose() => Navigator.of(context).pop();

  // ---------------------------------------------------------------------------
  // Voucher mode toggle helper
  // ---------------------------------------------------------------------------

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
        final newMode = s.first;
        setState(() => _selectedFeeMode = newMode);
        ref
            .read(reportPreviewProvider(widget.request).notifier)
            .regenerateWithMode(newMode);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportPreviewProvider(widget.request));

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
    final dialogWidth = size.width * 0.92;
    final dialogHeight = size.height * 0.92;

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildToolbar(state),
                  Expanded(child: _buildBody(state)),
                ],
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

  Widget _buildToolbar(ReportPreviewState state) {
    final hasBytes = state.bytes != null;

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
          // --- PDF icon + title -----------------------------------------------
          const Icon(Icons.picture_as_pdf_outlined,
              color: AppColors.brandPrimary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.effectiveTitle,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.request.subtitle != null &&
                    widget.request.subtitle!.isNotEmpty)
                  Text(
                    widget.request.subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // --- Optional caller-supplied controls ------------------------------
          if (widget.headerControls != null) ...[
            widget.headerControls!,
            const SizedBox(width: AppSpacing.sm),
          ],

          // --- Voucher mode toggle (feeVoucher only) --------------------------
          if (widget.request.type == ReportType.feeVoucher) ...[
            _buildVoucherModeToggle(),
            const SizedBox(width: AppSpacing.sm),
          ],

          // --- Refresh --------------------------------------------------------
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Regenerate',
            iconSize: 20,
            onPressed: () => ref
                .read(reportPreviewProvider(widget.request).notifier)
                .generate(),
          ),

          const SizedBox(width: AppSpacing.xs),

          // --- Export PDF button ----------------------------------------------
          OutlinedButton.icon(
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

          const SizedBox(width: AppSpacing.xs),

          // --- Print button ---------------------------------------------------
          ElevatedButton.icon(
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

          const SizedBox(width: AppSpacing.sm),

          // --- Close ----------------------------------------------------------
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close (Esc)',
            iconSize: 20,
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
                style: AppTypography.body.copyWith(
                  color: Colors.white70,
                ),
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
              const Icon(Icons.error_outline,
                  color: AppColors.statusErrorText, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to generate report',
                style: AppTypography.h3.copyWith(
                  color: Colors.white,
                ),
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
                        .read(reportPreviewProvider(widget.request).notifier)
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

    // PDF preview
    return Container(
      color: canvasColor,
      child: PdfPreview(
        build: (_) async => state.bytes!,
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
