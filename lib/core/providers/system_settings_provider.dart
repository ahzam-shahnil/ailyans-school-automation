import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db/database.dart';
import '../sync/connectivity_service.dart';
import '../sync/node_id_allocator.dart';
import '../sync/supabase_client.dart';
import '../sync/sync_provider.dart';
import '../sync/sync_service.dart';
import 'available_sessions_provider.dart';
import 'shell_metadata_provider.dart';

/// Immutable representation of the institution / branch profile from InstBranch (BrnachID = 1).
class InstBranchData {
  final int branchId;
  final int? instituteId;
  final String branchName;
  final String branchAddress;
  final String phone;
  final String mobile;
  final String fax;
  final String email;
  final String website;
  final String principal;
  final String contactPerson;
  final String remarks;
  final String secPd;

  const InstBranchData({
    this.branchId = 1,
    this.instituteId = 1,
    this.branchName = '',
    this.branchAddress = '',
    this.phone = '',
    this.mobile = '',
    this.fax = '',
    this.email = '',
    this.website = '',
    this.principal = '',
    this.contactPerson = '',
    this.remarks = '',
    this.secPd = '',
  });

  InstBranchData copyWith({
    int? branchId,
    int? instituteId,
    String? branchName,
    String? branchAddress,
    String? phone,
    String? mobile,
    String? fax,
    String? email,
    String? website,
    String? principal,
    String? contactPerson,
    String? remarks,
    String? secPd,
  }) {
    return InstBranchData(
      branchId: branchId ?? this.branchId,
      instituteId: instituteId ?? this.instituteId,
      branchName: branchName ?? this.branchName,
      branchAddress: branchAddress ?? this.branchAddress,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      fax: fax ?? this.fax,
      email: email ?? this.email,
      website: website ?? this.website,
      principal: principal ?? this.principal,
      contactPerson: contactPerson ?? this.contactPerson,
      remarks: remarks ?? this.remarks,
      secPd: secPd ?? this.secPd,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstBranchData &&
          runtimeType == other.runtimeType &&
          branchId == other.branchId &&
          instituteId == other.instituteId &&
          branchName == other.branchName &&
          branchAddress == other.branchAddress &&
          phone == other.phone &&
          mobile == other.mobile &&
          fax == other.fax &&
          email == other.email &&
          website == other.website &&
          principal == other.principal &&
          contactPerson == other.contactPerson &&
          remarks == other.remarks &&
          secPd == other.secPd;

  @override
  int get hashCode => Object.hash(
    branchId,
    instituteId,
    branchName,
    branchAddress,
    phone,
    mobile,
    fax,
    email,
    website,
    principal,
    contactPerson,
    remarks,
    secPd,
  );
}

/// Immutable representation of the app_config keys surfaced in System Settings.
class AppConfigData {
  final String defaultSessionYr;
  final String fiscalStartMonth;
  final List<String> workingDays;
  final bool darkMode;
  final bool highDensityUi;
  final bool urduFontFallback;

  // Cloud Sync (device-local keys: never cross the sync boundary).
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String nodeId;

  const AppConfigData({
    this.defaultSessionYr = '2017-2018',
    this.fiscalStartMonth = 'April',
    this.workingDays = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ],
    this.darkMode = false,
    this.highDensityUi = false,
    this.urduFontFallback = true,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.nodeId = 'windows',
  });

  AppConfigData copyWith({
    String? defaultSessionYr,
    String? fiscalStartMonth,
    List<String>? workingDays,
    bool? darkMode,
    bool? highDensityUi,
    bool? urduFontFallback,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? nodeId,
  }) {
    return AppConfigData(
      defaultSessionYr: defaultSessionYr ?? this.defaultSessionYr,
      fiscalStartMonth: fiscalStartMonth ?? this.fiscalStartMonth,
      workingDays: workingDays ?? this.workingDays,
      darkMode: darkMode ?? this.darkMode,
      highDensityUi: highDensityUi ?? this.highDensityUi,
      urduFontFallback: urduFontFallback ?? this.urduFontFallback,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      nodeId: nodeId ?? this.nodeId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppConfigData) return false;
    if (defaultSessionYr != other.defaultSessionYr ||
        fiscalStartMonth != other.fiscalStartMonth ||
        darkMode != other.darkMode ||
        highDensityUi != other.highDensityUi ||
        urduFontFallback != other.urduFontFallback ||
        supabaseUrl != other.supabaseUrl ||
        supabaseAnonKey != other.supabaseAnonKey ||
        nodeId != other.nodeId) {
      return false;
    }
    if (workingDays.length != other.workingDays.length) return false;
    for (int i = 0; i < workingDays.length; i++) {
      if (workingDays[i] != other.workingDays[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    defaultSessionYr,
    fiscalStartMonth,
    Object.hashAll(workingDays),
    darkMode,
    highDensityUi,
    urduFontFallback,
    supabaseUrl,
    supabaseAnonKey,
    nodeId,
  );
}

/// State for the unified SystemSettingsScreen.
class SystemSettingsState {
  final bool isLoading;
  final int activeTab; // 0: Institution, 1: Calendar, 2: Appearance, 3: Info, 4: Data & Backups
  final InstBranchData branch;
  final InstBranchData originalBranch;
  final AppConfigData config;
  final AppConfigData originalConfig;
  final bool obscureSecPd;
  final String? errorMessage;
  final String? toastMessage;
  final int schemaVersion;
  final int operatorCount;

  // Read-only sync status (not part of the dirty comparison).
  final int pendingOutboxCount;
  final String? lastPulledAt;
  final String? lastPushedAt;
  final bool isForcePushing;
  final bool isForcePulling;

  const SystemSettingsState({
    this.isLoading = true,
    this.activeTab = 0,
    this.branch = const InstBranchData(),
    this.originalBranch = const InstBranchData(),
    this.config = const AppConfigData(),
    this.originalConfig = const AppConfigData(),
    this.obscureSecPd = true,
    this.errorMessage,
    this.toastMessage,
    this.schemaVersion = 7,
    this.operatorCount = 0,
    this.pendingOutboxCount = 0,
    this.lastPulledAt,
    this.lastPushedAt,
    this.isForcePushing = false,
    this.isForcePulling = false,
  });

  bool get isDirty => branch != originalBranch || config != originalConfig;

  SystemSettingsState copyWith({
    bool? isLoading,
    int? activeTab,
    InstBranchData? branch,
    InstBranchData? originalBranch,
    AppConfigData? config,
    AppConfigData? originalConfig,
    bool? obscureSecPd,
    String? Function()? errorMessage,
    String? Function()? toastMessage,
    int? schemaVersion,
    int? operatorCount,
    int? pendingOutboxCount,
    String? Function()? lastPulledAt,
    String? Function()? lastPushedAt,
    bool? isForcePushing,
    bool? isForcePulling,
  }) {
    return SystemSettingsState(
      isLoading: isLoading ?? this.isLoading,
      activeTab: activeTab ?? this.activeTab,
      branch: branch ?? this.branch,
      originalBranch: originalBranch ?? this.originalBranch,
      config: config ?? this.config,
      originalConfig: originalConfig ?? this.originalConfig,
      obscureSecPd: obscureSecPd ?? this.obscureSecPd,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      toastMessage: toastMessage != null ? toastMessage() : this.toastMessage,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      operatorCount: operatorCount ?? this.operatorCount,
      pendingOutboxCount: pendingOutboxCount ?? this.pendingOutboxCount,
      lastPulledAt:
          lastPulledAt != null ? lastPulledAt() : this.lastPulledAt,
      lastPushedAt:
          lastPushedAt != null ? lastPushedAt() : this.lastPushedAt,
      isForcePushing: isForcePushing ?? this.isForcePushing,
      isForcePulling: isForcePulling ?? this.isForcePulling,
    );
  }
}

/// StateNotifier for System Settings management.
class SystemSettingsNotifier extends StateNotifier<SystemSettingsState> {
  /// Normalizes 'YYYY-YYYY' to 'YYYY-YY' to match source .mdb format.
  /// Used before writing default_session_yr to app_config.
  String _normalizeSessionYr(String input) {
    final trimmed = input.trim();
    final match = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(trimmed);
    if (match != null) {
      final endYear = match.group(2)!;
      return '${match.group(1)}-${endYear.substring(endYear.length - 2)}';
    }
    return trimmed;
  }

  Ref? _ref;
  final Future<SyncPushResult> Function() _forcePushRunner;
  final Future<SyncPullResult> Function() _forcePullRunner;
  final Future<void> Function(String) _configureNodeBlockRunner;
  final Future<bool> Function() _reconfigureRunner;

  SystemSettingsNotifier({
    Ref? ref,
    Future<SyncPushResult> Function()? forcePushRunner,
    Future<SyncPullResult> Function()? forcePullRunner,
    Future<void> Function(String)? configureNodeBlockRunner,
    Future<bool> Function()? reconfigureRunner,
  })  : _forcePushRunner = forcePushRunner ?? SyncService.runForcePushAll,
        _forcePullRunner = forcePullRunner ?? SyncService.runForcePullAll,
        _configureNodeBlockRunner = configureNodeBlockRunner ??
            ((id) => NodeIdAllocator().configureNodeBlock(id)),
        _reconfigureRunner = reconfigureRunner ??
            SupabaseClientWrapper.reconfigure,
        super(const SystemSettingsState()) {
    _ref = ref;
  }

  /// Sets the active tab index (0..5).
  void setActiveTab(int tab) {
    if (tab < 0 || tab > 5) return;
    state = state.copyWith(activeTab: tab);
  }

  /// Toggles visibility of the SecPd password field.
  void toggleObscureSecPd() {
    state = state.copyWith(obscureSecPd: !state.obscureSecPd);
  }

  /// Clears any transient error message.
  void clearError() {
    state = state.copyWith(errorMessage: () => null);
  }

  /// Clears any transient toast message.
  void clearToast() {
    state = state.copyWith(toastMessage: () => null);
  }

  /// Loads initial configuration and branch details from the database.
  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final db = await DatabaseService.instance.database;

      // 1. Fetch InstBranch (where BrnachID = 1)
      final branchRows = await db.rawQuery(
        'SELECT BrnachID, InstituteID, BranchName, BranchAddress, BrPhone, Mobile, '
        'BrFaxNo, BrEmailAddress, BrWebsite, BrPrincipal, BrContactPerson, Remarks, SecPd '
        'FROM InstBranch WHERE BrnachID = 1 LIMIT 1',
      );

      InstBranchData branchData = const InstBranchData();
      if (branchRows.isNotEmpty) {
        final row = branchRows.first;
        branchData = InstBranchData(
          branchId: (row['BrnachID'] as int?) ?? 1,
          instituteId: row['InstituteID'] as int?,
          branchName: (row['BranchName'] as String?) ?? '',
          branchAddress: (row['BranchAddress'] as String?) ?? '',
          phone: (row['BrPhone'] as String?) ?? '',
          mobile: (row['Mobile'] as String?) ?? '',
          fax: (row['BrFaxNo'] as String?) ?? '',
          email: (row['BrEmailAddress'] as String?) ?? '',
          website: (row['BrWebsite'] as String?) ?? '',
          principal: (row['BrPrincipal'] as String?) ?? '',
          contactPerson: (row['BrContactPerson'] as String?) ?? '',
          remarks: (row['Remarks'] as String?) ?? '',
          secPd: (row['SecPd'] as String?) ?? '',
        );
      }

      // 2. Fetch app_config keys
      final configRows = await db.rawQuery(
        'SELECT config_key, config_value FROM app_config',
      );
      final Map<String, String> configMap = {};
      for (final row in configRows) {
        final k = row['config_key'] as String?;
        final v = row['config_value'] as String?;
        if (k != null && v != null) {
          configMap[k] = v;
        }
      }

      final defaultSessionYr = configMap['default_session_yr'] ?? '2017-2018';
      final fiscalStartMonth = configMap['fiscal_start_month'] ?? 'April';
      final workingDaysRaw =
          configMap['working_days'] ??
          'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday';
      final workingDays = workingDaysRaw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final darkMode = configMap['dark_mode'] == 'true';
      final highDensityUi = configMap['high_density_ui'] == 'true';
      final urduFontFallback = configMap['urdu_font_fallback'] != 'false';

      const envSupabaseUrl =
          String.fromEnvironment('SUPABASE_URL', defaultValue: '');
      const envSupabaseAnonKey =
          String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
      final dbSupabaseUrl = configMap['supabase_url'] ?? '';
      final dbSupabaseAnonKey = configMap['supabase_anon_key'] ?? '';
      final dbNodeId = configMap['node_id'] ?? '';

      final configData = AppConfigData(
        defaultSessionYr: defaultSessionYr,
        fiscalStartMonth: fiscalStartMonth,
        workingDays: workingDays,
        darkMode: darkMode,
        highDensityUi: highDensityUi,
        urduFontFallback: urduFontFallback,
        supabaseUrl:
            dbSupabaseUrl.isNotEmpty ? dbSupabaseUrl : envSupabaseUrl,
        supabaseAnonKey: dbSupabaseAnonKey.isNotEmpty
            ? dbSupabaseAnonKey
            : envSupabaseAnonKey,
        nodeId: dbNodeId.isNotEmpty ? dbNodeId : 'windows',
      );

      // 3. Schema version
      final userVersionRows = await db.rawQuery('PRAGMA user_version;');
      final schemaVersion = (userVersionRows.first.values.first as int?) ?? 7;

      // 4. Operator count
      final userCountRows = await db.rawQuery(
        'SELECT count(*) as cnt FROM Users',
      );
      final operatorCount = (userCountRows.first['cnt'] as int?) ?? 0;

      // 5. Sync stats (device-local outbox + watermarks).
      final stats = await _readSyncStats(db);

      state = state.copyWith(
        isLoading: false,
        branch: branchData,
        originalBranch: branchData,
        config: configData,
        originalConfig: configData,
        schemaVersion: schemaVersion,
        operatorCount: operatorCount,
        pendingOutboxCount: stats.pendingOutboxCount,
        lastPulledAt: () => stats.lastPulledAt,
        lastPushedAt: () => stats.lastPushedAt,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'Failed to load system settings: $e',
      );
    }
  }

  // --- Mutators for Tab 0: Institution & Branch Profile ---

  void setBranchName(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(branchName: value),
      errorMessage: () => null,
    );
  }

  void setBranchAddress(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(branchAddress: value),
      errorMessage: () => null,
    );
  }

  void setPhone(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(phone: value),
      errorMessage: () => null,
    );
  }

  void setMobile(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(mobile: value),
      errorMessage: () => null,
    );
  }

  void setFax(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(fax: value),
      errorMessage: () => null,
    );
  }

  void setEmail(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(email: value),
      errorMessage: () => null,
    );
  }

  void setWebsite(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(website: value),
      errorMessage: () => null,
    );
  }

  void setPrincipal(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(principal: value),
      errorMessage: () => null,
    );
  }

  void setContactPerson(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(contactPerson: value),
      errorMessage: () => null,
    );
  }

  void setRemarks(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(remarks: value),
      errorMessage: () => null,
    );
  }

  void setSecPd(String value) {
    state = state.copyWith(
      branch: state.branch.copyWith(secPd: value),
      errorMessage: () => null,
    );
  }

  // --- Mutators for Tab 1: Academic Calendar & Sessions ---

  void setDefaultSessionYr(String value) {
    state = state.copyWith(
      config: state.config.copyWith(defaultSessionYr: value),
      errorMessage: () => null,
    );
  }

  void setFiscalStartMonth(String value) {
    state = state.copyWith(
      config: state.config.copyWith(fiscalStartMonth: value),
      errorMessage: () => null,
    );
  }

  void toggleWorkingDay(String day) {
    final list = List<String>.from(state.config.workingDays);
    if (list.contains(day)) {
      list.remove(day);
    } else {
      list.add(day);
    }
    // Keep canonical Mon..Sun order
    const daysOrder = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    list.sort((a, b) => daysOrder.indexOf(a).compareTo(daysOrder.indexOf(b)));
    state = state.copyWith(
      config: state.config.copyWith(workingDays: list),
      errorMessage: () => null,
    );
  }

  // --- Mutators for Tab 2: Appearance & Regionalization ---

  void setDarkMode(bool value) {
    state = state.copyWith(
      config: state.config.copyWith(darkMode: value),
      errorMessage: () => null,
    );
  }

  void setHighDensityUi(bool value) {
    state = state.copyWith(
      config: state.config.copyWith(highDensityUi: value),
      errorMessage: () => null,
    );
  }

  void setUrduFontFallback(bool value) {
    state = state.copyWith(
      config: state.config.copyWith(urduFontFallback: value),
      errorMessage: () => null,
    );
  }

  // --- Mutators for Tab 5: Cloud Sync ---

  void setSupabaseUrl(String value) {
    state = state.copyWith(
      config: state.config.copyWith(supabaseUrl: value.trim()),
      errorMessage: () => null,
    );
  }

  void setSupabaseAnonKey(String value) {
    state = state.copyWith(
      config: state.config.copyWith(supabaseAnonKey: value.trim()),
      errorMessage: () => null,
    );
  }

  void setNodeId(String value) {
    state = state.copyWith(
      config: state.config.copyWith(nodeId: value),
      errorMessage: () => null,
    );
  }

  // --- Actions ---

  /// Discards all uncommitted changes and reverts to database state.
  void discardChanges() {
    state = state.copyWith(
      branch: state.originalBranch,
      config: state.originalConfig,
      errorMessage: () => null,
    );
  }

  /// Rotates supervisory password (SecPd) with strict validation.
  /// Returns null on success, or an error message on failure.
  Future<String?> rotatePassword({
    required int userLevel,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // 1. Permission gate
    if (userLevel != 1) {
      return "You don't have enough rights for purpose";
    }

    // 2. Current password match against database
    final db = await DatabaseService.instance.database;
    final branchRows = await db.rawQuery(
      'SELECT SecPd FROM InstBranch WHERE BrnachID = 1 LIMIT 1',
    );
    final dbSecPd = branchRows.isNotEmpty
        ? ((branchRows.first['SecPd'] as String?) ?? '')
        : '';

    if (currentPassword != dbSecPd) {
      return 'Current password is incorrect';
    }

    // 3. New password confirmation match
    if (newPassword != confirmPassword) {
      return 'New password confirmation does not match';
    }

    // 4. Minimum length
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters';
    }

    // 5. Must differ from current
    if (newPassword == currentPassword) {
      return 'New password must differ from current password';
    }

    try {
      await db.rawUpdate('UPDATE InstBranch SET SecPd = ? WHERE BrnachID = 1', [
        newPassword,
      ]);

      final updatedBranch = state.branch.copyWith(secPd: newPassword);
      final updatedOrigBranch = state.originalBranch.copyWith(
        secPd: newPassword,
      );

      state = state.copyWith(
        branch: updatedBranch,
        originalBranch: updatedOrigBranch,
        toastMessage: () => 'Supervisory password updated successfully',
      );

      return null;
    } catch (e) {
      return 'Failed to rotate password: $e';
    }
  }

  /// Saves settings with strict validation.
  /// Returns true on success, false on validation or database error.
  Future<bool> saveSettings({required int userLevel}) async {
    // 1. Permission gate
    if (userLevel != 1) {
      state = state.copyWith(
        errorMessage: () => "You don't have enough rights for purpose",
      );
      return false;
    }

    // 2. Validate BranchName
    if (state.branch.branchName.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: () => 'Institution / Branch Name is required',
      );
      return false;
    }

    // 3. Validate SecPd blank
    if (state.branch.secPd.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: () =>
            'Supervisory Revocation Password (SecPd) cannot be blank',
      );
      return false;
    }

    // 4. Validate SecPd minimum length if modified
    if (state.branch.secPd != state.originalBranch.secPd &&
        state.branch.secPd.length < 6) {
      state = state.copyWith(
        errorMessage: () => 'SecPd must be at least 6 characters',
      );
      return false;
    }

    try {
      final db = await DatabaseService.instance.database;
      final oldConfig = state.originalConfig;

      await db.transaction((txn) async {
        // Update InstBranch
        await txn.rawUpdate(
          '''
          UPDATE InstBranch
          SET BranchName = ?,
              BranchAddress = ?,
              BrPhone = ?,
              Mobile = ?,
              BrFaxNo = ?,
              BrEmailAddress = ?,
              BrWebsite = ?,
              BrPrincipal = ?,
              BrContactPerson = ?,
              Remarks = ?,
              SecPd = ?
          WHERE BrnachID = 1
          ''',
          [
            state.branch.branchName.trim(),
            state.branch.branchAddress.trim(),
            state.branch.phone.trim(),
            state.branch.mobile.trim(),
            state.branch.fax.trim(),
            state.branch.email.trim(),
            state.branch.website.trim(),
            state.branch.principal.trim(),
            state.branch.contactPerson.trim(),
            state.branch.remarks.trim(),
            state.branch.secPd.trim(),
          ],
        );

        // Update app_config keys (INSERT OR REPLACE)
        final workingDaysStr = state.config.workingDays.join(',');
        final configs = [
          (
            'default_session_yr',
            _normalizeSessionYr(state.config.defaultSessionYr.trim()),
          ),
          ('fiscal_start_month', state.config.fiscalStartMonth.trim()),
          ('working_days', workingDaysStr),
          ('dark_mode', state.config.darkMode ? 'true' : 'false'),
          ('high_density_ui', state.config.highDensityUi ? 'true' : 'false'),
          (
            'urdu_font_fallback',
            state.config.urduFontFallback ? 'true' : 'false',
          ),
          ('supabase_url', state.config.supabaseUrl.trim()),
          ('supabase_anon_key', state.config.supabaseAnonKey.trim()),
          ('node_id', state.config.nodeId),
        ];

        for (final (k, v) in configs) {
          await txn.rawInsert(
            'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
            [k, v],
          );
        }

        // Device-local keys must never pollute the outbox. The APP_CONFIG
        // triggers fire on the writes above, so clear those rows here.
        await txn.delete(
          '_sync_outbox',
          where: "table_name = 'app_config' AND record_pk IN "
              "('supabase_url', 'supabase_anon_key', 'node_id')",
        );
      });

      // Invalidate shellMetadataProvider so top-bar immediately displays the updated institution name
      _ref?.invalidate(shellMetadataProvider);
      _ref?.invalidate(availableSessionsProvider);

      // Follow-ups: node block re-allocation and live client reconfiguration.
      if (state.config.nodeId != oldConfig.nodeId) {
        await _configureNodeBlockRunner(state.config.nodeId);
      }
      if (state.config.supabaseUrl != oldConfig.supabaseUrl ||
          state.config.supabaseAnonKey != oldConfig.supabaseAnonKey) {
        await _reconfigureRunner();
      }

      // F-6 fix: force connectivity re-check so status bar flips immediately
      // after URL/key change (Argon fix 4).
      if (_ref != null) {
        try {
          final connSvc = _ref!.read(connectivityServiceProvider);
          final result = await connSvc.checkCurrent();
          _ref!.read(syncPushProvider.notifier).updateConnectivity(result);
        } catch (e) {
          debugPrint('[F-6] Post-save connectivity check failed: $e');
        }
      }

      await refreshSyncStats();

      final toast = state.config.darkMode != state.originalConfig.darkMode
          ? 'Settings saved successfully (Theme change requires app restart)'
          : 'Settings saved successfully';

      state = state.copyWith(
        originalBranch: state.branch,
        originalConfig: state.config,
        errorMessage: () => null,
        toastMessage: () => toast,
      );

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: () => 'Failed to save settings: $e');
      return false;
    }
  }

  // --- Cloud Sync actions ---

  /// Reads outbox count and latest watermarks straight from SQLite.
  Future<({int pendingOutboxCount, String? lastPulledAt, String? lastPushedAt})>
      _readSyncStats(Database db) async {
    final outboxRows =
        await db.rawQuery('SELECT COUNT(*) AS n FROM _sync_outbox');
    final pending = (outboxRows.first['n'] as num?)?.toInt() ?? 0;

    final stateRows = await db.rawQuery(
      'SELECT MAX(last_pulled_at) AS max_pulled, '
      'MAX(last_pushed_at) AS max_pushed FROM _sync_state',
    );
    String? maxPulled;
    String? maxPushed;
    if (stateRows.isNotEmpty) {
      maxPulled = stateRows.first['max_pulled'] as String?;
      maxPushed = stateRows.first['max_pushed'] as String?;
    }
    return (
      pendingOutboxCount: pending,
      lastPulledAt: maxPulled,
      lastPushedAt: maxPushed,
    );
  }

  /// Refreshes pending-outbox and watermark stats from the database.
  Future<void> refreshSyncStats() async {
    try {
      final db = await DatabaseService.instance.database;
      final stats = await _readSyncStats(db);
      state = state.copyWith(
        pendingOutboxCount: stats.pendingOutboxCount,
        lastPulledAt: () => stats.lastPulledAt,
        lastPushedAt: () => stats.lastPushedAt,
      );
    } catch (_) {
      // Stats are cosmetic; never propagate read failures.
    }
  }

  /// Force pushes every pending outbox row (retry counters reset first).
  Future<void> forcePushAll() async {
    if (state.isForcePushing) return;
    state = state.copyWith(
      isForcePushing: true,
      errorMessage: () => null,
    );
    try {
      final result = await _forcePushRunner();
      await refreshSyncStats();
      if (result.failedCount > 0) {
        state = state.copyWith(
          errorMessage: () => 'Force push: ${result.failedCount} rows failed',
        );
      } else if (result.skipped) {
        state = state.copyWith(
          toastMessage: () => 'Cloud sync is not configured',
        );
      } else {
        state = state.copyWith(
          toastMessage: () =>
              'Force push complete (${result.pushedCount} pushed)',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: () => 'Force push failed: $e');
    } finally {
      state = state.copyWith(isForcePushing: false);
    }
  }

  /// Force pulls every table from scratch (watermarks cleared first).
  Future<void> forcePullAll() async {
    if (state.isForcePulling) return;
    state = state.copyWith(
      isForcePulling: true,
      errorMessage: () => null,
    );
    try {
      final result = await _forcePullRunner();
      await refreshSyncStats();
      if (result.failedCount > 0) {
        state = state.copyWith(
          errorMessage: () => 'Force pull: ${result.failedCount} rows failed',
        );
      } else if (result.skipped) {
        state = state.copyWith(
          toastMessage: () => 'Cloud sync is not configured',
        );
      } else {
        state = state.copyWith(
          toastMessage: () =>
              'Force pull complete (${result.pulledCount} pulled)',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: () => 'Force pull failed: $e');
    } finally {
      state = state.copyWith(isForcePulling: false);
    }
  }
}

/// Provider for system settings state.
final systemSettingsProvider =
    StateNotifierProvider<SystemSettingsNotifier, SystemSettingsState>((ref) {
      return SystemSettingsNotifier(ref: ref);
    });
