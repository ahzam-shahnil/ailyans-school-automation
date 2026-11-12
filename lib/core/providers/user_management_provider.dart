import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../repositories/user_repository.dart';
import '../db/database.dart';
import 'session_provider.dart';

/// State object representing the User Management view.
class UserManagementState {
  final List<User> users;
  final User? selectedUser;
  final bool isCreatingNew;
  final String searchQuery;
  final List<String> branches;
  final Map<int, int> assignedRightsCount;
  final bool isLoading;
  final bool isSaving;
  final String? toast;
  final String? errorMessage;

  const UserManagementState({
    this.users = const [],
    this.selectedUser,
    this.isCreatingNew = false,
    this.searchQuery = '',
    this.branches = const [],
    this.assignedRightsCount = const {},
    this.isLoading = false,
    this.isSaving = false,
    this.toast,
    this.errorMessage,
  });

  /// Filters users case-insensitively by name, designation, or primary mobile.
  List<User> get filteredUsers {
    if (searchQuery.trim().isEmpty) return users;
    final q = searchQuery.trim().toLowerCase();
    return users.where((u) {
      final nameMatches = u.name.toLowerCase().contains(q);
      final desigMatches = (u.designation ?? '').toLowerCase().contains(q);
      final mobileMatches = (u.mobile1 ?? '').toLowerCase().contains(q);
      return nameMatches || desigMatches || mobileMatches;
    }).toList();
  }

  UserManagementState copyWith({
    List<User>? users,
    User? selectedUser,
    bool clearSelectedUser = false,
    bool? isCreatingNew,
    String? searchQuery,
    List<String>? branches,
    Map<int, int>? assignedRightsCount,
    bool? isLoading,
    bool? isSaving,
    String? toast,
    bool clearToast = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return UserManagementState(
      users: users ?? this.users,
      selectedUser: clearSelectedUser
          ? null
          : (selectedUser ?? this.selectedUser),
      isCreatingNew: isCreatingNew ?? this.isCreatingNew,
      searchQuery: searchQuery ?? this.searchQuery,
      branches: branches ?? this.branches,
      assignedRightsCount: assignedRightsCount ?? this.assignedRightsCount,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      toast: clearToast ? null : (toast ?? this.toast),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

/// StateNotifier managing business logic, validation gates, and persistence for user operators.
class UserManagementNotifier extends StateNotifier<UserManagementState> {
  final UserRepository userRepository;
  final Ref ref;

  UserManagementNotifier({required this.userRepository, required this.ref})
    : super(const UserManagementState());

  /// Loads users from SQLite, queries active branch list, counts assigned rights,
  /// and selects the requested user or defaults to the first user.
  Future<void> loadUsers({int? selectUserId}) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearToast: true,
    );

    try {
      final userList = await userRepository.getAllUsers();

      final db = await DatabaseService.instance.database;

      // 1. Fetch branches from InstBranch
      final branchRows = await db.rawQuery(
        'SELECT BranchName FROM InstBranch ORDER BY BrnachID ASC',
      );
      final fetchedBranches = branchRows
          .map((r) => r['BranchName'] as String?)
          .whereType<String>()
          .toList();

      const defaultBranches = [
        '-',
        'Management',
        'Main Campus',
      ];

      final branchSet = <String>{...fetchedBranches, ...defaultBranches};

      // 2. Fetch assigned rights count per user
      final countRows = await db.rawQuery(
        'SELECT UID, COUNT(*) AS cnt FROM AccRhts WHERE ObjID != 25 GROUP BY UID',
      );
      final counts = <int, int>{};
      for (final r in countRows) {
        final uid = r['UID'] as int?;
        final cnt = r['cnt'] as int?;
        if (uid != null && cnt != null) {
          counts[uid] = cnt;
        }
      }

      // 3. Determine selected user
      User? targetUser;
      if (selectUserId != null) {
        targetUser = userList.where((u) => u.id == selectUserId).firstOrNull;
      }
      targetUser ??= userList.isNotEmpty ? userList.first : null;

      if (targetUser?.branch != null && targetUser!.branch!.trim().isNotEmpty) {
        branchSet.add(targetUser.branch!.trim());
      }

      state = state.copyWith(
        users: userList,
        selectedUser: targetUser,
        clearSelectedUser: targetUser == null,
        isCreatingNew: false,
        branches: branchSet.toList(),
        assignedRightsCount: counts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load user directory: $e',
      );
    }
  }

  /// Selects an existing user and populates form view.
  void selectUser(User user) {
    final branchSet = <String>{...state.branches};
    if (user.branch != null && user.branch!.trim().isNotEmpty) {
      branchSet.add(user.branch!.trim());
    }

    state = state.copyWith(
      selectedUser: user,
      branches: branchSet.toList(),
      isCreatingNew: false,
      clearErrorMessage: true,
      clearToast: true,
    );
  }

  /// Resets selection and switches to New User creation mode.
  void startNewUser() {
    state = state.copyWith(
      clearSelectedUser: true,
      isCreatingNew: true,
      clearErrorMessage: true,
      clearToast: true,
    );
  }

  /// Updates search filter query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clears active toast message.
  void clearToast() {
    state = state.copyWith(clearToast: true);
  }

  /// Clears active error message.
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// Sequential validation gates and persistence for creating or updating a user.
  Future<bool> saveUser({
    required String name,
    String? designation,
    String? cnic,
    required String rawPassword,
    String? branch,
    String? address,
    String? mobile1,
    String? mobile2,
    required int userLevel,
    required bool isActive,
    String? remarks,
    int? currentLoggedInUserId,
  }) async {
    // Validation Gate 1: Empty Name
    if (name.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter User Name Please',
        clearToast: true,
      );
      return false;
    }

    // Validation Gate 2: New user empty password
    if (state.isCreatingNew && rawPassword.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter User Name / Password Please',
        clearToast: true,
      );
      return false;
    }

    // Validation Gate 3: Password length (if provided)
    if (rawPassword.isNotEmpty && rawPassword.length < 8) {
      state = state.copyWith(
        errorMessage: 'Password must be at least 8 characters',
        clearToast: true,
      );
      return false;
    }

    final db = await DatabaseService.instance.database;

    // Validation Gate 4: Duplicate Name Check (case-insensitive)
    final targetId = state.isCreatingNew ? -1 : (state.selectedUser?.id ?? -1);
    final dupRows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM Users WHERE LOWER(Name) = LOWER(?) AND ID != ?',
      [name.trim(), targetId],
    );
    final dupCount = (dupRows.first['cnt'] as int?) ?? 0;
    if (dupCount > 0) {
      state = state.copyWith(
        errorMessage: 'User Name already exists',
        clearToast: true,
      );
      return false;
    }

    // Validation Gate 5: Deactivation checks if editing existing user and isActive is false
    if (!state.isCreatingNew && !isActive) {
      if (currentLoggedInUserId != null &&
          state.selectedUser?.id == currentLoggedInUserId) {
        state = state.copyWith(
          errorMessage: 'Cannot deactivate the currently logged-in user.',
          clearToast: true,
        );
        return false;
      }

      final adminRows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM Users WHERE UserLvl = 1 AND IsActive = 1 AND ID != ?',
        [state.selectedUser!.id],
      );
      final adminCount = (adminRows.first['cnt'] as int?) ?? 0;
      if (state.selectedUser!.userLevel == 1 && adminCount == 0) {
        state = state.copyWith(
          errorMessage: 'Cannot deactivate the last remaining administrator.',
          clearToast: true,
        );
        return false;
      }
    }

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearToast: true,
    );

    try {
      if (state.isCreatingNew) {
        final hashedPassword = BCrypt.hashpw(rawPassword, BCrypt.gensalt());
        final newUser = User(
          id: 0,
          name: name.trim(),
          designation: designation?.trim().isEmpty == true
              ? null
              : designation?.trim(),
          cnic: cnic?.trim().isEmpty == true ? null : cnic?.trim(),
          password: hashedPassword,
          branch: branch?.trim().isEmpty == true ? null : branch?.trim(),
          address: address?.trim().isEmpty == true ? null : address?.trim(),
          mobile1: mobile1?.trim().isEmpty == true ? null : mobile1?.trim(),
          mobile2: mobile2?.trim().isEmpty == true ? null : mobile2?.trim(),
          userLevel: userLevel,
          remarks: remarks?.trim().isEmpty == true ? null : remarks?.trim(),
          isActive: isActive,
        );

        final newId = await userRepository.insertUser(newUser);
        await loadUsers(selectUserId: newId);
        state = state.copyWith(
          toast: 'Record Saved Successfully',
          isSaving: false,
          clearErrorMessage: true,
        );
        return true;
      } else {
        final selected = state.selectedUser!;
        final pwdHash = rawPassword.isNotEmpty
            ? BCrypt.hashpw(rawPassword, BCrypt.gensalt())
            : selected.password;

        final updatedUser = selected.copyWith(
          name: name.trim(),
          designation: designation?.trim().isEmpty == true
              ? null
              : designation?.trim(),
          cnic: cnic?.trim().isEmpty == true ? null : cnic?.trim(),
          password: pwdHash,
          branch: branch?.trim().isEmpty == true ? null : branch?.trim(),
          address: address?.trim().isEmpty == true ? null : address?.trim(),
          mobile1: mobile1?.trim().isEmpty == true ? null : mobile1?.trim(),
          mobile2: mobile2?.trim().isEmpty == true ? null : mobile2?.trim(),
          userLevel: userLevel,
          remarks: remarks?.trim().isEmpty == true ? null : remarks?.trim(),
          isActive: isActive,
        );

        await userRepository.updateUser(updatedUser);

        // If current logged-in user edited their own profile, refresh session in place
        final currentSession = ref.read(sessionProvider);
        if (currentSession != null &&
            currentSession.user.id == updatedUser.id) {
          ref
              .read(sessionProvider.notifier)
              .setSession(
                updatedUser,
                currentSession.allowedObjIds,
                hasWeakPasswordWarning: currentSession.hasWeakPasswordWarning,
              );
        }

        await loadUsers(selectUserId: updatedUser.id);
        state = state.copyWith(
          toast: 'Record Saved Successfully',
          isSaving: false,
          clearErrorMessage: true,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Database Error: Could not save operator record ($e)',
        clearToast: true,
      );
      return false;
    }
  }

  /// Deactivates a user account while preserving records and permissions.
  Future<bool> deactivateUser(
    int targetUserId, {
    required int? currentLoggedInUserId,
  }) async {
    // Guard 1 (Self)
    if (currentLoggedInUserId != null &&
        targetUserId == currentLoggedInUserId) {
      state = state.copyWith(
        errorMessage: 'Cannot deactivate the currently logged-in user.',
        clearToast: true,
      );
      return false;
    }

    final db = await DatabaseService.instance.database;

    // Guard 2 (Last Admin)
    final adminRows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM Users WHERE UserLvl = 1 AND IsActive = 1 AND ID != ?',
      [targetUserId],
    );
    final adminCount = (adminRows.first['cnt'] as int?) ?? 0;

    final targetUser = await userRepository.getUserById(targetUserId);
    if (targetUser != null && targetUser.userLevel == 1 && adminCount == 0) {
      state = state.copyWith(
        errorMessage: 'Cannot deactivate the last remaining administrator.',
        clearToast: true,
      );
      return false;
    }

    try {
      await userRepository.deactivateUser(targetUserId);
      await loadUsers(selectUserId: targetUserId);
      state = state.copyWith(
        toast: 'User deactivated successfully',
        clearErrorMessage: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to deactivate user: $e',
        clearToast: true,
      );
      return false;
    }
  }
}

/// Riverpod provider for [UserManagementNotifier].
final userManagementProvider =
    StateNotifierProvider<UserManagementNotifier, UserManagementState>((ref) {
      return UserManagementNotifier(
        userRepository: ref.watch(userRepositoryProvider),
        ref: ref,
      );
    });
