import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  /// Launch behaviour is trial-key-only (offline). TODO: wire the Supabase
  /// RPC once the `licenses` table + `validate_license` function are live:
  ///
  /// ```dart
  /// final supabase = SupabaseClientWrapper.instance;
  /// final response = await supabase.rpc(
  ///   'validate_license',
  ///   params: {'p_license_key': licenseKey},
  /// );
  /// ```
  Future<bool> validateAndStore(String licenseKey) async {
    // Trial key bypass (offline).
    if (licenseKey.trim().toUpperCase() == trialKey) {
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
    // TODO(Supabase): rpc('validate_license', params: {'p_license_key': ...})
    return false;
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
