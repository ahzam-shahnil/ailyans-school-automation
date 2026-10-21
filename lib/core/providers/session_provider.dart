import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';

/// Represents an authenticated user session with their authorized module object IDs.
class UserSession {
  final User user;
  final List<int> allowedObjIds;
  final bool hasWeakPasswordWarning;

  const UserSession({
    required this.user,
    required this.allowedObjIds,
    this.hasWeakPasswordWarning = false,
  });

  /// Checks if the current user has access to a specific securable module (ObjID).
  bool hasAccess(int objId) => allowedObjIds.contains(objId);

  /// Creates a copy of [UserSession] with updated fields.
  UserSession copyWith({
    User? user,
    List<int>? allowedObjIds,
    bool? hasWeakPasswordWarning,
  }) {
    return UserSession(
      user: user ?? this.user,
      allowedObjIds: allowedObjIds ?? this.allowedObjIds,
      hasWeakPasswordWarning:
          hasWeakPasswordWarning ?? this.hasWeakPasswordWarning,
    );
  }
}

/// StateNotifier managing current authentication session state.
class SessionNotifier extends StateNotifier<UserSession?> {
  SessionNotifier() : super(null);

  /// Returns true if a user is currently logged in.
  bool get isAuthenticated => state != null;

  /// Sets the active user session.
  void setSession(
    User user,
    List<int> allowedObjIds, {
    bool hasWeakPasswordWarning = false,
  }) {
    state = UserSession(
      user: user,
      allowedObjIds: allowedObjIds,
      hasWeakPasswordWarning: hasWeakPasswordWarning,
    );
  }

  /// Sets or updates the weak password warning state.
  void setWeakPasswordWarning(bool warning) {
    if (state != null) {
      state = state!.copyWith(hasWeakPasswordWarning: warning);
    }
  }

  /// Dismisses the weak password warning banner.
  void dismissWeakPasswordWarning() {
    if (state != null) {
      state = state!.copyWith(hasWeakPasswordWarning: false);
    }
  }

  /// Updates the user in the active session (e.g. after password change).
  void updateUser(User user) {
    if (state != null) {
      state = state!.copyWith(user: user);
    }
  }

  /// Clears the active session (logout).
  void clear() {
    state = null;
  }
}

/// Global provider for the active user session.
final sessionProvider = StateNotifierProvider<SessionNotifier, UserSession?>((
  ref,
) {
  return SessionNotifier();
});
