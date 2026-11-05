import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_service.dart';

class SyncPushState {
  final bool isPushing;
  final int lastPushedCount;
  final int lastFailedCount;
  final List<String> lastErrors;
  final DateTime? lastAttemptAt;

  const SyncPushState({
    this.isPushing = false,
    this.lastPushedCount = 0,
    this.lastFailedCount = 0,
    this.lastErrors = const [],
    this.lastAttemptAt,
  });

  SyncPushState copyWith({
    bool? isPushing,
    int? lastPushedCount,
    int? lastFailedCount,
    List<String>? lastErrors,
    DateTime? lastAttemptAt,
  }) =>
      SyncPushState(
        isPushing: isPushing ?? this.isPushing,
        lastPushedCount: lastPushedCount ?? this.lastPushedCount,
        lastFailedCount: lastFailedCount ?? this.lastFailedCount,
        lastErrors: lastErrors ?? this.lastErrors,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      );
}

class SyncPushNotifier extends StateNotifier<SyncPushState> {
  SyncPushNotifier() : super(const SyncPushState());

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
}

final syncPushProvider =
    StateNotifierProvider<SyncPushNotifier, SyncPushState>(
  (ref) => SyncPushNotifier(),
);
