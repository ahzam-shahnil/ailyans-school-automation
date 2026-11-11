import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';

/// G-10 Shot 2: multi-tenancy identity for the ByteWave School Manager SaaS.
///
/// The active tenant is persisted in SharedPreferences under
/// [TenantNotifier.tenantKey] (`bytewave_tenant`) as a JSON blob, and the
/// tenant id is used by `DatabaseService` to derive the tenant-specific
/// on-disk database file (`school_<tenantId>.db`).
class Tenant {
  final String id;
  final String schoolName;
  final String adminName;
  final String adminContact;
  final String createdAt;

  // G-10 Shot 3: onboarding contact + admin credentials. The password is
  // persisted as a BCrypt hash (matching the `Users.Pwd` storage format);
  // the PIN is 4-6 digits and has no Users-table column, so it is kept in
  // the tenant record only. All default to '' for backward compatibility
  // with tenants created before Shot 3.
  final String contactPhone;
  final String adminUsername;
  final String adminPassword;
  final String adminPin;

  const Tenant({
    required this.id,
    required this.schoolName,
    required this.adminName,
    required this.adminContact,
    required this.createdAt,
    this.contactPhone = '',
    this.adminUsername = '',
    this.adminPassword = '',
    this.adminPin = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'schoolName': schoolName,
    'adminName': adminName,
    'adminContact': adminContact,
    'createdAt': createdAt,
    'contactPhone': contactPhone,
    'adminUsername': adminUsername,
    'adminPassword': adminPassword,
    'adminPin': adminPin,
  };

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
    id: json['id'] as String,
    schoolName: json['schoolName'] as String,
    adminName: json['adminName'] as String,
    adminContact: json['adminContact'] as String,
    createdAt: json['createdAt'] as String,
    contactPhone: json['contactPhone'] as String? ?? '',
    adminUsername: json['adminUsername'] as String? ?? '',
    adminPassword: json['adminPassword'] as String? ?? '',
    adminPin: json['adminPin'] as String? ?? '',
  );
}

/// StateNotifier holding the active tenant (null = not configured yet).
class TenantNotifier extends StateNotifier<Tenant?> {
  TenantNotifier() : super(null);

  /// SharedPreferences key shared with `DatabaseService` (which reads the
  /// tenant id to resolve the tenant-aware database path).
  static const tenantKey = 'bytewave_tenant';

  /// Tenant id pinned for legacy single-tenant installs migrated at first
  /// launch of the ByteWave multi-tenant build.
  static const legacyTenantId = 'default';

  bool _loaded = false;

  /// True once SharedPreferences has been consulted successfully. The router
  /// only redirects to `/setup` after this flag is set, so environments
  /// without the plugin (widget tests) never see the first-launch gate.
  bool get loaded => _loaded;

  /// Loads the persisted tenant (if any). Safe to call multiple times.
  Future<void> loadTenant() async {
    if (_loaded) return;
    try {
      // Widget tests never register the SharedPreferences platform channel;
      // skip there so the router's first-launch gate stays inert.
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;

      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(tenantKey);
      if (raw == null) {
        // Trigger DatabaseService's tenant resolution so legacy Ailyans
        // installs (Documents/Ailyans/school_database.db) are migrated to
        // ByteWave/school_default.db and pinned to the 'default' tenant
        // before the router's first-launch gate evaluates.
        await DatabaseService.instance.getDatabasePath();
        raw = prefs.getString(tenantKey);
      }
      _loaded = true;
      if (raw == null) return;
      state = Tenant.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Plugin unavailable (tests) or corrupt JSON: leave the gate closed.
    }
  }

  /// Creates and persists a new tenant for a first-launch school setup.
  ///
  /// [adminPassword] is hashed with BCrypt before persistence (matching the
  /// `Users.Pwd` format consumed by `AuthRepositoryImpl.authenticate`).
  /// After persisting, the cached database connection is closed so the next
  /// access provisions the tenant-scoped database (seed profile + admin
  /// user) — G-10 Shot 3.
  ///
  /// G-10 Shot 11a-2: [id] pins an explicit tenant id (the "Use Existing
  /// Account" skip flow passes `ailyans` so the renamed database file and
  /// the Supabase `school_id` stay aligned). [skipUserInsertion] stores
  /// `adminPassword` as '' WITHOUT hashing, which makes
  /// `DatabaseService._insertAdminUser` skip the Users insert entirely —
  /// the seed's existing `Users` row (with its authoritative BCrypt hash)
  /// is reused and no duplicate admin is created.
  Future<void> createTenant({
    String? id,
    required String schoolName,
    required String adminName,
    required String adminContact,
    required String adminUsername,
    required String adminPassword,
    required String adminPin,
    String contactPhone = '',
    bool skipUserInsertion = false,
  }) async {
    final tenantId = id ?? 'school_${DateTime.now().millisecondsSinceEpoch}';
    final tenant = Tenant(
      id: tenantId,
      schoolName: schoolName,
      adminName: adminName,
      adminContact: adminContact,
      createdAt: DateTime.now().toIso8601String(),
      contactPhone: contactPhone,
      adminUsername: adminUsername,
      adminPassword: skipUserInsertion
          ? ''
          : BCrypt.hashpw(adminPassword, BCrypt.gensalt()),
      adminPin: adminPin,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tenantKey, jsonEncode(tenant.toJson()));
    state = tenant;
    try {
      // Force the next database access to re-resolve the tenant-scoped path
      // and run first-open provisioning (seed profile + admin insertion).
      await DatabaseService.instance.close();
    } catch (_) {
      // Database never opened (e.g. tests): nothing to close.
    }
  }

  /// Clears the active tenant (returns the app to first-launch state).
  Future<void> clearTenant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tenantKey);
    state = null;
  }
}

/// Global provider exposing the active tenant (null when not configured).
final tenantProvider = StateNotifierProvider<TenantNotifier, Tenant?>((ref) {
  return TenantNotifier();
});
