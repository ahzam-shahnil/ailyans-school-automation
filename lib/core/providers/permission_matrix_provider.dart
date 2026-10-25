import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/access_object.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';
import 'session_provider.dart';

/// Target user ID currently selected for permissions management. Defaults to 1 (Admin).
final selectedPermissionUserIdProvider = StateProvider<int?>((ref) => 1);

/// Represents a functional category grouping for securable modules.
class ModuleCategory {
  final String title;
  final Set<int> objIds;

  const ModuleCategory(this.title, this.objIds);
}

/// The 6 Functional Categories for the 27 active AccObj modules (Screen 4).
const List<ModuleCategory> moduleCategories = [
  ModuleCategory('STUDENTS & ENROLLMENT', {8, 9, 11, 12, 13, 20, 26}),
  ModuleCategory('FEES & FINANCIALS', {16, 17, 18, 19, 21}),
  ModuleCategory('ACADEMICS & EXAMINATIONS', {4, 10, 23, 24}),
  ModuleCategory('ATTENDANCE & HR', {2, 22, 28, 29}),
  ModuleCategory('FACULTY & LIBRARY', {3, 14}),
  ModuleCategory('SYSTEM & COMMUNICATION', {1, 5, 6, 7, 15}),
];

/// State object representing the Permission Matrix screen.
class PermissionMatrixState {
  final User? targetUser;
  final List<AccessObject> allModules;
  final Set<int> selectedObjIds;
  final bool isLoading;
  final bool isSaving;
  final String? toast;
  final String? errorMessage;

  const PermissionMatrixState({
    this.targetUser,
    this.allModules = const [],
    this.selectedObjIds = const {},
    this.isLoading = false,
    this.isSaving = false,
    this.toast,
    this.errorMessage,
  });

  String get targetUserName => targetUser?.name ?? '';
  String get targetUserDesignation => targetUser?.designation ?? 'N/A';
  int get targetUserLevel => targetUser?.userLevel ?? 1;
  int? get targetUserId => targetUser?.id;

  PermissionMatrixState copyWith({
    User? targetUser,
    bool clearTargetUser = false,
    List<AccessObject>? allModules,
    Set<int>? selectedObjIds,
    bool? isLoading,
    bool? isSaving,
    String? toast,
    bool clearToast = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PermissionMatrixState(
      targetUser: clearTargetUser ? null : (targetUser ?? this.targetUser),
      allModules: allModules ?? this.allModules,
      selectedObjIds: selectedObjIds ?? this.selectedObjIds,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      toast: clearToast ? null : (toast ?? this.toast),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

/// StateNotifier managing access rights module loading, toggling, and atomic batch persistence.
class PermissionMatrixNotifier extends StateNotifier<PermissionMatrixState> {
  final UserRepository userRepository;
  final Ref ref;

  PermissionMatrixNotifier({required this.userRepository, required this.ref})
    : super(const PermissionMatrixState());

  /// Loads operator details, 27 securable modules, and existing assigned rights.
  Future<void> loadForUser(int userId) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearToast: true,
    );

    try {
      final user = await userRepository.getUserById(userId);
      final modules = await userRepository.getAllAccessObjects();
      final assigned = await userRepository.getUserAssignedObjectIds(userId);

      state = state.copyWith(
        targetUser: user,
        allModules: modules,
        selectedObjIds: assigned.toSet(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load permissions: $e',
      );
    }
  }

  /// Toggles authorization for a specific module ObjID.
  void toggleModule(int objId) {
    final next = Set<int>.from(state.selectedObjIds);
    if (next.contains(objId)) {
      next.remove(objId);
    } else {
      next.add(objId);
    }
    state = state.copyWith(selectedObjIds: next);
  }

  /// Selects all 27 active modules.
  void selectAll() {
    final next = state.allModules.map((m) => m.objId).toSet();
    state = state.copyWith(selectedObjIds: next);
  }

  /// Deselects all modules.
  void deselectAll() {
    state = state.copyWith(selectedObjIds: <int>{});
  }

  /// Clears active toast message.
  void clearToast() {
    state = state.copyWith(clearToast: true);
  }

  /// Clears active error message.
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// Persists user access rights atomically in AccRhts.
  Future<bool> saveRights() async {
    if (state.targetUserId == null) return false;

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearToast: true,
    );

    try {
      final userId = state.targetUserId!;
      final objList = state.selectedObjIds.toList();

      await userRepository.assignUserRights(userId, objList);

      // In-place session update if target user is currently logged-in user
      final currentSession = ref.read(sessionProvider);
      if (currentSession != null && currentSession.user.id == userId) {
        ref
            .read(sessionProvider.notifier)
            .setSession(
              currentSession.user,
              objList,
              hasWeakPasswordWarning: currentSession.hasWeakPasswordWarning,
            );
      }

      state = state.copyWith(
        isSaving: false,
        toast: 'User Rights updated successfully',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to update user rights: $e',
      );
      return false;
    }
  }
}

/// Riverpod provider for [PermissionMatrixNotifier].
final permissionMatrixProvider =
    StateNotifierProvider<PermissionMatrixNotifier, PermissionMatrixState>((
      ref,
    ) {
      return PermissionMatrixNotifier(
        userRepository: ref.watch(userRepositoryProvider),
        ref: ref,
      );
    });
