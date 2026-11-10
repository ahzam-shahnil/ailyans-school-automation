import 'dart:convert';
import 'dart:io';

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

  const Tenant({
    required this.id,
    required this.schoolName,
    required this.adminName,
    required this.adminContact,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'schoolName': schoolName,
    'adminName': adminName,
    'adminContact': adminContact,
    'createdAt': createdAt,
  };

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
    id: json['id'] as String,
    schoolName: json['schoolName'] as String,
    adminName: json['adminName'] as String,
    adminContact: json['adminContact'] as String,
    createdAt: json['createdAt'] as String,
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
  Future<void> createTenant({
    required String schoolName,
    required String adminName,
    required String adminContact,
  }) async {
    final id = 'school_${DateTime.now().millisecondsSinceEpoch}';
    final tenant = Tenant(
      id: id,
      schoolName: schoolName,
      adminName: adminName,
      adminContact: adminContact,
      createdAt: DateTime.now().toIso8601String(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tenantKey, jsonEncode(tenant.toJson()));
    state = tenant;
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
