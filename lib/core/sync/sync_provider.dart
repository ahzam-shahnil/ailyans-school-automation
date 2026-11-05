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
      );
}

class SyncPushNotifier extends StateNotifier<SyncPushState> {
  SyncPushNotifier() : super(const SyncPushState());

  /// Push-only. Kept for backward compat with existing callers.
  Future<void> triggerPush() async {
    if (state.isPushing) return;
    state = state.copyWith(isPushing: true);
    final result = await SyncService.runStartupPush();
    state = SyncPushState(
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
    final pushResult = await SyncService.runStartupPush();
    state = state.copyWith(
      isPushing: false,
      lastPushedCount: pushResult.pushedCount,
      lastFailedCount: pushResult.failedCount,
      lastErrors: pushResult.errors,
      lastAttemptAt: DateTime.now(),
    );

    // Pull phase.
    state = state.copyWith(isPulling: true);
    final pullResult = await SyncService.runStartupPull();
    state = SyncPushState(
      isPushing: false,
      isPulling: false,
      lastPushedCount: pushResult.pushedCount,
      lastFailedCount: pushResult.failedCount,
      lastErrors: pushResult.errors,
      lastAttemptAt: DateTime.now(),
      lastPulledCount: pullResult.pulledCount,
      lastPullFailedCount: pullResult.failedCount,
      lastPulledAt: DateTime.now(),
    );
  }
}

final syncPushProvider =
    StateNotifierProvider<SyncPushNotifier, SyncPushState>(
  (ref) => SyncPushNotifier(),
);
