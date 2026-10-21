import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/shell_metadata_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Contextual bottom status bar of the desktop application shell.
class AppStatusBar extends ConsumerWidget {
  const AppStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadataAsync = ref.watch(shellMetadataProvider);
    final metadata = metadataAsync.valueOrNull ?? ShellMetadata.empty();

    return Container(
      height: 28.0,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border(
          top: BorderSide(color: AppColors.borderDefault, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // 1. Left: DB Connection Status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.0,
                height: 8.0,
                decoration: const BoxDecoration(
                  color: AppColors.statusSuccessText,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'DB: SDB_Ailyans.db (Online)',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11.0,
                ),
              ),
            ],
          ),

          Expanded(
            child: Center(
              child: Text(
                'Branch: ${metadata.branchName} | Session: ${metadata.sessionYear}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 3. Right: Keyboard Shortcuts Quick Reference Button
          InkWell(
            onTap: () => _showShortcutsDialog(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: 2.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_outlined,
                    size: 14.0,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    '? Shortcuts',
                    style: AppTypography.monospace.copyWith(
                      fontSize: 11.0,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShortcutsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.keyboard_outlined,
              color: AppColors.brandPrimary,
              size: 22.0,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Keyboard Shortcuts Reference',
              style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: const SizedBox(
          width: 420.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShortcutRow(
                keys: 'Ctrl + N / Cmd + N',
                action: 'New Student / New Record',
              ),
              _ShortcutRow(
                keys: 'Ctrl + K / Cmd + K',
                action: 'Global Search Palette',
              ),
              _ShortcutRow(
                keys: 'Ctrl + S / Cmd + S',
                action: 'Save Active Form',
              ),
              _ShortcutRow(
                keys: 'Ctrl + P / Cmd + P',
                action: 'Print / Export PDF Preview',
              ),
              _ShortcutRow(keys: 'F2', action: 'Inline Row Edit in Data Grids'),
              _ShortcutRow(
                keys: 'Escape',
                action: 'Dismiss Dialog / Clear Search',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String action;

  const _ShortcutRow({required this.keys, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border.all(color: AppColors.borderDefault),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              keys,
              style: AppTypography.monospace.copyWith(
                fontSize: 11.0,
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              action,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
