import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/update_check_provider.dart';
import '../../core/services/update_check_service.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Displays release notes and download action in an alert dialog.
Future<void> showUpdateDialog(BuildContext context, UpdateManifest manifest) {
  final downloadUrl = UpdateCheckService.resolveDownloadUrl(manifest);
  final displayTag =
      manifest.tag.isNotEmpty ? manifest.tag : 'v${manifest.version}';

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.new_releases_outlined, color: AppColors.brandPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "What's New in $displayTag",
              style: AppTypography.h3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
        child: SingleChildScrollView(
          child: Text(
            manifest.notes.isNotEmpty
                ? manifest.notes
                : 'No release notes provided for this version.',
            style: AppTypography.body,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(ctx).pop();
            final uri = Uri.parse(downloadUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download'),
        ),
      ],
    ),
  );
}

/// Slim, responsive, dismissible update banner for AppShell.
class UpdateAvailableBanner extends ConsumerWidget {
  final UpdateManifest manifest;

  const UpdateAvailableBanner({super.key, required this.manifest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadUrl = UpdateCheckService.resolveDownloadUrl(manifest);
    final displayTag =
        manifest.tag.isNotEmpty ? manifest.tag : 'v${manifest.version}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.statusInfoBg,
        border: Border(
          bottom: BorderSide(color: AppColors.statusInfoBorder, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.system_update_rounded,
                      size: 20.0,
                      color: AppColors.statusInfoText,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Update available: $displayTag',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.statusInfoText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18.0),
                      color: AppColors.statusInfoText,
                      tooltip: 'Dismiss',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref
                            .read(updateCheckProvider.notifier)
                            .dismissCurrentUpdate();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4.0,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () => showUpdateDialog(context, manifest),
                      child: const Text('Changelog'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(downloadUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                    ),
                  ],
                ),
              ],
            );
          }

          // Desktop / wide screen layout: single horizontal bar
          return Row(
            children: [
              const Icon(
                Icons.system_update_rounded,
                size: 20.0,
                color: AppColors.statusInfoText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Update available: $displayTag',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.statusInfoText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => showUpdateDialog(context, manifest),
                child: const Text('Changelog'),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download'),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const Icon(Icons.close, size: 18.0),
                color: AppColors.statusInfoText,
                tooltip: 'Dismiss',
                onPressed: () {
                  ref
                      .read(updateCheckProvider.notifier)
                      .dismissCurrentUpdate();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
