import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_config.dart';
import '../db/database.dart';
import '../sync/supabase_client.dart';

/// G-10 Shot 4: activation state for a ByteWave SaaS installation.
///
/// Persisted as JSON in SharedPreferences so the router can gate the app
/// behind `/license` until a valid key is activated, without requiring the
/// Supabase backend to be reachable at every launch.
class License {
  final String licenseKey;

  /// 'trial' | 'starter' | 'enterprise'
  final String tier;
  final int maxStudents;
  final DateTime validUntil;
  final DateTime cachedAt;

  /// Whether the last validation attempt (local or remote) succeeded.
  final bool lastValid;

  const License({
    required this.licenseKey,
    required this.tier,
    required this.maxStudents,
    required this.validUntil,
    required this.cachedAt,
    required this.lastValid,
  });

  bool get isCurrentlyValid => lastValid && DateTime.now().isBefore(validUntil);

  bool get needsRemoteRecheck =>
      DateTime.now().difference(cachedAt).inHours >= 24;

  Map<String, dynamic> toJson() => {
    'licenseKey': licenseKey,
    'tier': tier,
    'maxStudents': maxStudents,
    'validUntil': validUntil.toIso8601String(),
    'cachedAt': cachedAt.toIso8601String(),
    'lastValid': lastValid,
  };

  factory License.fromJson(Map<String, dynamic> json) => License(
    licenseKey: json['licenseKey'] as String,
    tier: json['tier'] as String,
    maxStudents: json['maxStudents'] as int,
    validUntil: DateTime.parse(json['validUntil'] as String),
    cachedAt: DateTime.parse(json['cachedAt'] as String),
    lastValid: json['lastValid'] as bool,
  );
}

/// Riverpod state holder for the active [License].
///
/// Follows the same "loaded" gate pattern as [TenantNotifier]: the router
/// only evaluates the license gate after SharedPreferences has actually been
/// consulted, so widget tests (no platform channel) never see the redirect.
class LicenseNotifier extends StateNotifier<License?> {
  LicenseNotifier() : super(null);

  static const _licenseKey = 'bytewave_license';

  /// Offline launch key accepted by all editions until the Supabase
  /// `validate_license` RPC is wired (see `validateAndStore`).
  static const trialKey = 'TRIAL-BYTE-2026-LAUNCH';

  bool _loaded = false;

  /// G-10 Shot 5: last rejection reason, for the license screen's error
  /// banner. Null after a successful activation.
  String? lastErrorMessage;

  /// True once SharedPreferences has been consulted (or skipped in tests).
  bool get loaded => _loaded;

  /// Loads the persisted license (if any). Safe to call multiple times.
  Future<void> loadLicense() async {
    if (_loaded) return;
    try {
      // Widget tests never register the SharedPreferences platform channel;
      // skip there so the router's license gate stays inert.
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        _loaded = true;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      _loaded = true;
      final raw = prefs.getString(_licenseKey);
      if (raw == null) return;
      state = License.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Plugin unavailable (tests) or corrupt JSON: leave the gate closed.
      _loaded = true;
    }
  }

  /// Validates [licenseKey] and persists the resulting [License].
  ///
  /// G-10 Shot 5 validation rules:
  /// - `TRIAL-BYTE-2026-LAUNCH` activates offline (bundled 30-day launch
  ///   trial) — no network call, safe for unit/widget tests.
  /// - Any other key is verified online against the Supabase
  ///   `public.validate_license` RPC (10s timeout). [rpcValidator] injects a
  ///   fake for unit testing; production passes null to use the real client.
  /// - 0 rows or `valid != true` → rejects with 'Invalid or expired license
  ///   key.'
  /// - Unconfigured/unreachable Supabase → rejects with the connectivity
  ///   message; arbitrary keys are NEVER silently accepted offline.
  ///
  /// On success the license is stored and the cloud-sync configuration
  /// (school id, bundled Supabase credentials, RPC-returned sync account) is
  /// seeded into SQLite `app_config` so Cloud Sync works immediately.
  Future<bool> validateAndStore(
    String licenseKey, {
    Future<Map<String, dynamic>?> Function(String licenseKey)? rpcValidator,
  }) async {
    lastErrorMessage = null;
    final normalizedKey = licenseKey.trim().toUpperCase();

    // (a) Offline fallback launch key.
    if (normalizedKey == trialKey) {
      final license = License(
        licenseKey: trialKey,
        tier: 'trial',
        maxStudents: 100,
        validUntil: DateTime.now().add(const Duration(days: 30)),
        cachedAt: DateTime.now(),
        lastValid: true,
      );
      await _store(license);
      return true;
    }

    // (b) Online keys: verify via Supabase RPC.
    final validator = rpcValidator ?? SupabaseClientWrapper.validateLicenseRpc;
    final Map<String, dynamic>? row;
    try {
      row = await validator(normalizedKey);
    } catch (e) {
      // (e) Network / unconfigured Supabase: never accept the key offline.
      debugPrint('[LicenseNotifier] online validation failed: $e');
      lastErrorMessage =
          'Unable to verify license key online. '
          'Please check your internet connection.';
      return false;
    }

    // (d) Unknown or expired key.
    if (row == null || row['valid'] != true) {
      lastErrorMessage = 'Invalid or expired license key.';
      return false;
    }

    // (c) Valid row: persist the license and auto-configure Cloud Sync.
    final validUntilRaw = row['valid_until'];
    final DateTime validUntil;
    if (validUntilRaw is DateTime) {
      validUntil = validUntilRaw;
    } else if (validUntilRaw is String) {
      validUntil = DateTime.parse(validUntilRaw);
    } else {
      lastErrorMessage = 'Invalid or expired license key.';
      return false;
    }

    final schoolId = (row['school_id'] as String?) ??
        (normalizedKey == 'TRIAL-BYTE-2026-AILYANS' ? 'ailyans' : null);

    final license = License(
      licenseKey: normalizedKey,
      tier: (row['tier'] as String?) ?? 'trial',
      maxStudents: (row['max_students'] as num?)?.toInt() ?? 100,
      validUntil: validUntil,
      cachedAt: DateTime.now(),
      lastValid: true,
    );
    await _store(license);
    await _seedAppConfig(
      schoolId: schoolId,
      syncEmail: row['sync_email'] as String?,
      syncPassword: row['sync_password'] as String?,
    );
    return true;
  }

  /// G-10 Shot 5: seeds the SQLite `app_config` table so Cloud Sync is
  /// configured immediately after activation. Best-effort: silently skipped
  /// when the database is unavailable (unit tests, pre-provisioning).
  Future<void> _seedAppConfig({
    required String? schoolId,
    required String? syncEmail,
    required String? syncPassword,
  }) async {
    try {
      final db = await DatabaseService.instance.database;
      final entries = <String, String>{
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
        if (BuildConfig.supabaseUrl.isNotEmpty)
          'supabase_url': BuildConfig.supabaseUrl,
        if (BuildConfig.supabaseAnonKey.isNotEmpty)
          'supabase_anon_key': BuildConfig.supabaseAnonKey,
        if (syncEmail != null && syncEmail.isNotEmpty)
          'supabase_sync_email': syncEmail,
        if (syncPassword != null && syncPassword.isNotEmpty)
          'supabase_sync_password': syncPassword,
      };
      for (final entry in entries.entries) {
        await db.execute(
          'INSERT OR REPLACE INTO app_config (config_key, config_value) '
          'VALUES (?, ?)',
          [entry.key, entry.value],
        );
      }
    } catch (e) {
      debugPrint('[LicenseNotifier] app_config seeding skipped: $e');
    }
  }

  Future<void> _store(License license) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKey, jsonEncode(license.toJson()));
    state = license;
  }

  /// Removes the persisted license (support / re-activation flows).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKey);
    state = null;
  }
}

final licenseProvider =
    StateNotifierProvider<LicenseNotifier, License?>((ref) {
      return LicenseNotifier();
    });
