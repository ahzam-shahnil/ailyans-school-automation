import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class SyncPushNotifier extends StateNotifier<SyncPushState> {
  final Future<SyncPushResult> Function() _pushRunner;
  final Future<SyncPullResult> Function() _pullRunner;

  SyncPushNotifier({
    Future<SyncPushResult> Function()? pushRunner,
    Future<SyncPullResult> Function()? pullRunner,
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
  Future<void> triggerSync() async {
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
  (ref) => SyncPushNotifier(),
);
