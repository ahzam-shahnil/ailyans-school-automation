import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:school_automation/core/theme/app_theme_tokens.dart';

/// Modal dialog previewing a captured dashboard PNG snapshot with actions to
/// Export PNG (via [FilePicker.saveFile]), Print as a single-page landscape PDF
/// (via [Printing.layoutPdf]), or Share (via [Printing.sharePdf]).
class SnapshotDialog extends StatefulWidget {
  const SnapshotDialog({
    super.key,
    required this.bytes,
    required this.filename,
    this.imageWidth,
    this.imageHeight,
  });

  final Uint8List bytes;
  final String filename;
  final int? imageWidth;
  final int? imageHeight;

  @override
  State<SnapshotDialog> createState() => _SnapshotDialogState();
}

class _SnapshotDialogState extends State<SnapshotDialog> {
  Future<void> _handleExport() async {
    try {
      // ignore: deprecated_member_use
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export PNG Snapshot',
        fileName: widget.filename,
        bytes: widget.bytes,
        // ignore: deprecated_member_use
        type: FileType.custom,
        // ignore: deprecated_member_use
        allowedExtensions: const ['png'],
        mimeType: 'image/png',
      );
      if (uri != null) {
        try {
          final path = uri.toFilePath();
          if (path.isNotEmpty) {
            await File(path).writeAsBytes(widget.bytes);
          }
        } catch (_) {
          // Handled directly by saveFile plugin on non-file scheme platforms.
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dashboard snapshot exported successfully'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _handlePrint() async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(widget.bytes),
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
      final pdfBytes = await doc.save();
      final printName = widget.filename.replaceAll('.png', '');
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: printName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    try {
      await Printing.sharePdf(
        bytes: widget.bytes,
        filename: widget.filename,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  void _handleClose() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('snapshot_dialog'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Dashboard Snapshot',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Image Preview
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.40,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.memory(
                        widget.bytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Actions (Wrap)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('snapshot_dialog_close'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderDefault),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      minimumSize: const Size(0, 38),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _handleClose,
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('snapshot_dialog_share'),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      minimumSize: const Size(0, 38),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _handleShare,
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('snapshot_dialog_export'),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Export PNG'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      minimumSize: const Size(0, 38),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _handleExport,
                  ),
                  ElevatedButton.icon(
                    key: const ValueKey('snapshot_dialog_print'),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      minimumSize: const Size(0, 38),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _handlePrint,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
