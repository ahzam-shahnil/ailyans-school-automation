import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_metrics_provider.dart';
import '../providers/shell_metadata_provider.dart';
import '../providers/student_list_provider.dart';
import 'sync_service.dart';

class SyncPushState {
  final bool isPushing;
  final int lastPushedCount;
  final int lastFailedCount;
  final List<String> lastErrors;
  final DateTime? lastAttemptAt;
  final bool isPulling;
  final int lastPulledCount;
  final int lastPullFailedCount;
  final DateTime? lastPulledAt;

  /// F-5: null means "not checked yet". Only [ConnectivityResult.none] is
  /// treated as offline; null is treated as online by the status bar.
  final ConnectivityResult? connectivity;

  /// F-5 fix: true once the first connectivity result has been observed.
  final bool hasHadFirstCheck;

  /// F-5 fix: true once a non-none result has been observed. Suppresses the
  /// plugin's boot sequence (none -> wifi) from firing a duplicate sync.
  final bool hasSeenOnline;

  const SyncPushState({
    this.isPushing = false,
    this.lastPushedCount = 0,
    this.lastFailedCount = 0,
    this.lastErrors = const [],
    this.lastAttemptAt,
    this.isPulling = false,
    this.lastPulledCount = 0,
    this.lastPullFailedCount = 0,
    this.lastPulledAt,
    this.connectivity,
    this.hasHadFirstCheck = false,
    this.hasSeenOnline = false,
  });

  SyncPushState copyWith({
    bool? isPushing,
    int? lastPushedCount,
    int? lastFailedCount,
    List<String>? lastErrors,
    DateTime? lastAttemptAt,
    bool? isPulling,
    int? lastPulledCount,
    int? lastPullFailedCount,
    DateTime? lastPulledAt,
    ConnectivityResult? connectivity,
    bool? hasHadFirstCheck,
    bool? hasSeenOnline,
  }) =>
      SyncPushState(
        isPushing: isPushing ?? this.isPushing,
        lastPushedCount: lastPushedCount ?? this.lastPushedCount,
        lastFailedCount: lastFailedCount ?? this.lastFailedCount,
        lastErrors: lastErrors ?? this.lastErrors,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        isPulling: isPulling ?? this.isPulling,
        lastPulledCount: lastPulledCount ?? this.lastPulledCount,
        lastPullFailedCount: lastPullFailedCount ?? this.lastPullFailedCount,
        lastPulledAt: lastPulledAt ?? this.lastPulledAt,
        connectivity: connectivity ?? this.connectivity,
        hasHadFirstCheck: hasHadFirstCheck ?? this.hasHadFirstCheck,
        hasSeenOnline: hasSeenOnline ?? this.hasSeenOnline,
      );
}

/// G-10 Shot 9: re-queries local SQLite through the active UI providers after
/// a cloud pull (or a manual refresh request) so open screens render freshly
/// pulled remote rows without an app restart.
///
/// Non-destructive: `studentListProvider` watches `studentListFiltersProvider`
/// (a separate notifier), so invalidating the list provider re-runs its
/// SQLite query while the user's session/class/section/search/sort/page state
/// is preserved. If `app_config.default_session_yr` changed remotely, the
/// refreshed `shellMetadataProvider` re-syncs the directory session through
/// its existing listener.
void refreshLocalDataProviders(Ref ref) {
  ref.invalidate(studentListProvider);
  ref.invalidate(dashboardMetricsProvider);
  ref.invalidate(shellMetadataProvider);
}

class SyncPushNotifier extends StateNotifier<SyncPushState> {
  final Future<SyncPushResult> Function() _pushRunner;
  final Future<SyncPullResult> Function() _pullRunner;

  /// G-10 Shot 9: invoked after each pull so the Riverpod layer can refresh
  /// the active UI providers from local SQLite. Optional to keep the
  /// constructor backward-compatible with all sync unit tests.
  final void Function(int pulledCount)? onPullComplete;

  SyncPushNotifier({
    Future<SyncPushResult> Function()? pushRunner,
    Future<SyncPullResult> Function()? pullRunner,
    this.onPullComplete,
  })  : _pushRunner = pushRunner ?? SyncService.runStartupPush,
        _pullRunner = pullRunner ?? SyncService.runStartupPull,
        super(const SyncPushState());

  /// Push-only. Kept for backward compat with existing callers.
  Future<void> triggerPush() async {
    if (state.isPushing) return;
    state = state.copyWith(isPushing: true);
    final result = await _pushRunner();
    state = state.copyWith(
      isPushing: false,
      lastPushedCount: result.pushedCount,
      lastFailedCount: result.failedCount,
      lastErrors: result.errors,
      lastAttemptAt: DateTime.now(),
    );
  }

  /// Push then pull (full sync). Guards on both isPushing and isPulling.
  ///
  /// Periodic/background callers (AppShell 30s timer, offline->online edge)
  /// refresh the UI providers ONLY when the pull landed at least one row
  /// (no flicker on 0-row deltas).
  Future<void> triggerSync() => _runSync(manual: false);

  /// G-10 Shot 9: user-initiated full sync (Sync Now button, Dashboard
  /// Refresh, Student List Refresh / pull-to-refresh). Refreshes the active
  /// UI providers unconditionally after the pull so remote state re-reads
  /// even when nothing new arrived.
  Future<void> triggerManualSync() => _runSync(manual: true);

  Future<void> _runSync({required bool manual}) async {
    if (state.isPushing || state.isPulling) return;

    // Push phase.
    state = state.copyWith(isPushing: true);
    final pushResult = await _pushRunner();
    state = state.copyWith(
      isPushing: false,
      lastPushedCount: pushResult.pushedCount,
      lastFailedCount: pushResult.failedCount,
      lastErrors: pushResult.errors,
      lastAttemptAt: DateTime.now(),
    );

    // Pull phase.
    state = state.copyWith(isPulling: true);
    final pullResult = await _pullRunner();
    state = state.copyWith(
      isPulling: false,
      lastPulledCount: pullResult.pulledCount,
      lastPullFailedCount: pullResult.failedCount,
      lastPulledAt: DateTime.now(),
    );

    // G-10 Shot 9: the pull wrote new/updated rows into local SQLite —
    // notify the active Riverpod UI providers so open screens update
    // immediately without an app restart.
    if (manual || pullResult.pulledCount > 0) {
      onPullComplete?.call(pullResult.pulledCount);
    }
  }

  /// Updates connectivity and auto-syncs on a real offline -> online edge.
  /// The plugin's boot handshake (none -> wifi) is suppressed entirely.
  void updateConnectivity(ConnectivityResult result) {
    if (state.connectivity == result) {
      if (!state.hasHadFirstCheck) {
        state = state.copyWith(hasHadFirstCheck: true);
      }
      return;
    }
    final firstCheck = !state.hasHadFirstCheck;
    final firstOnline =
        !state.hasSeenOnline && result != ConnectivityResult.none;
    final wasOffline = state.connectivity == ConnectivityResult.none;
    state = state.copyWith(
      connectivity: result,
      hasHadFirstCheck: true,
      hasSeenOnline: state.hasSeenOnline || result != ConnectivityResult.none,
    );
    if (!firstCheck &&
        !firstOnline &&
        wasOffline &&
        result != ConnectivityResult.none) {
      unawaited(triggerSync());
    }
  }
}

final syncPushProvider =
    StateNotifierProvider<SyncPushNotifier, SyncPushState>(
  (ref) => SyncPushNotifier(
    // G-10 Shot 9: wire the post-pull UI refresh into the real provider.
    // Periodic background sync (AppShell 30s timer) lands here with the
    // pulled > 0 guard enforced inside triggerSync; manual callers use
    // triggerManualSync() which refreshes unconditionally.
    onPullComplete: (_) => refreshLocalDataProviders(ref),
  ),
);
