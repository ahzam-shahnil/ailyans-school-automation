import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dashboard_metrics_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/student_list_provider.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Contextual bottom status bar of the desktop application shell.
/// Fixed 28px height, pinned at the bottom of the AppShell root Column.
class AppStatusBar extends ConsumerWidget {
  /// When false (login/pre-auth), sync state is neither watched nor rendered.
  final bool showSyncStatus;

  const AppStatusBar({super.key, this.showSyncStatus = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadataAsync = ref.watch(shellMetadataProvider);
    final metadata = metadataAsync.valueOrNull ?? ShellMetadata.empty();
    final syncState = showSyncStatus ? ref.watch(syncPushProvider) : null;
    // G-10 Shot 9: user-initiated sync — refresh local providers first
    // (Step A: instant local SQLite read), then run push + pull; the
    // post-pull hook re-reads local SQLite again upon completion (Step B).
    final VoidCallback? onSyncNow = showSyncStatus
        ? () async {
            ref.invalidate(studentListProvider);
            ref.invalidate(dashboardMetricsProvider);
            ref.invalidate(shellMetadataProvider);
            await ref.read(syncPushProvider.notifier).triggerManualSync();
          }
        : null;

    return Container(
      height: 28.0,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border(
          top: BorderSide(color: AppColors.borderDefault, width: 1.0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final compact = width < 480.0;
          final horizontalPadding = compact ? AppSpacing.xs : AppSpacing.md;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: compact
                ? _buildCompactRow(
                    metadata,
                    metadataAsync.hasError,
                    syncState,
                  )
                : _buildFullRow(
                    context,
                    metadata,
                    metadataAsync.hasError,
                    syncState,
                    onSyncNow,
                    showShortcuts: width >= 900.0,
                    maxLeftWidth: width * 0.45,
                  ),
          );
        },
      ),
    );
  }

  /// Below 480px: DB status dot, shortened session chip, and a sync label.
  Widget _buildCompactRow(
    ShellMetadata metadata,
    bool hasError,
    SyncPushState? syncState,
  ) {
    final dotColor = hasError
        ? AppColors.statusErrorText
        : AppColors.statusSuccessText;

    return Row(
      children: [
        Tooltip(
          message: hasError
              ? 'DB: SDB_Ailyans.db (Offline)'
              : 'DB: SDB_Ailyans.db (Online)',
          child: Icon(Icons.circle, size: 8.0, color: dotColor),
        ),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            border: Border.all(color: AppColors.borderDefault),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            _shortSessionYear(metadata.sessionYear),
            maxLines: 1,
            style: AppTypography.monospace.copyWith(
              fontSize: 10.0,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (syncState != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.circle, size: 8.0, color: _syncColor(syncState)),
          const SizedBox(width: 4.0),
          Text(
            _compactSyncLabel(syncState),
            maxLines: 1,
            style: AppTypography.bodySmall.copyWith(
              color: _syncColor(syncState),
              fontSize: 10.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  /// Above 480px: DB label, branch/session, sync status + action, shortcuts.
  Widget _buildFullRow(
    BuildContext context,
    ShellMetadata metadata,
    bool hasError,
    SyncPushState? syncState,
    VoidCallback? onSyncNow, {
    required bool showShortcuts,
    required double maxLeftWidth,
  }) {
    final dotColor = hasError
        ? AppColors.statusErrorText
        : AppColors.statusSuccessText;

    return Row(
      children: [
        // 1. Left: DB Connection Status
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxLeftWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'DB: SDB_Ailyans.db (Online)',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.0,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Center(
            child: Text(
              'Branch: ${metadata.branchName} | Session: ${metadata.sessionYear}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.0,
              ),
            ),
          ),
        ),

        // 3. Sync status + manual trigger (F-5).
        if (syncState != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.circle, size: 8.0, color: _syncColor(syncState)),
          const SizedBox(width: 4.0),
          Flexible(
            child: Text(
              _syncLabel(syncState),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: _syncColor(syncState),
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4.0),
          TextButton(
            onPressed: onSyncNow,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.brandPrimary,
            ),
            child: Text(
              'Sync Now',
              style: AppTypography.label.copyWith(fontSize: 11.0),
            ),
          ),
        ],

        // 4. Right: Keyboard Shortcuts Quick Reference Button
        if (showShortcuts) ...[
          const SizedBox(width: AppSpacing.xs),
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
      ],
    );
  }

  /// Full-row label. Only `ConnectivityResult.none` is offline; null (not
  /// checked yet) is treated as online.
  String _syncLabel(SyncPushState state) {
    if (state.isPushing || state.isPulling) return 'Syncing...';
    if (state.connectivity == ConnectivityResult.none) return 'Offline Mode';
    return 'Online - Synced';
  }

  /// Compact-row label (<480px), short enough to fit beside the session chip.
  String _compactSyncLabel(SyncPushState state) {
    if (state.isPushing || state.isPulling) return 'Syncing';
    if (state.connectivity == ConnectivityResult.none) return 'Offline';
    return 'Synced';
  }

  Color _syncColor(SyncPushState state) {
    if (state.isPushing || state.isPulling) return AppColors.statusInfoText;
    if (state.connectivity == ConnectivityResult.none) {
      return AppColors.statusErrorText;
    }
    return AppColors.statusSuccessText;
  }

  /// Shortens `2017-2018` -> `17-18` and `2026-27` -> `26-27`.
  String _shortSessionYear(String sessionYear) {
    final value = sessionYear.trim();
    if (value.isEmpty) return '--';

    final parts = value.split('-');
    if (parts.length >= 2) {
      final start = parts.first;
      final end = parts[1];
      final startShort = start.length >= 2
          ? start.substring(start.length - 2)
          : start;
      final endShort = end.length >= 2 ? end.substring(end.length - 2) : end;
      if (startShort.isNotEmpty && endShort.isNotEmpty) {
        return '$startShort-$endShort';
      }
    }

    return value.length <= 5 ? value : value.substring(value.length - 5);
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
