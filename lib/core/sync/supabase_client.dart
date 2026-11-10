import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/build_config.dart';
import '../db/database.dart';

/// Phase F-4a-1: Supabase client init + sync service account sign-in.
///
/// Auth model:
/// - RLS policies are TO authenticated on all 19 tables.
/// - Anonymous client cannot read/write.
/// - We sign in as a dedicated sync service account (sync@ailyans.local)
///   created in Supabase Dashboard -> Authentication -> Users.
/// - The service-role key (SUPABASE_SERVICE_ROLE_KEY) is NEVER used here;
///   it is only for the Python seeder.
class SupabaseClientWrapper {
  static bool _initialized = false;
  static bool _authReady = false;
  static String? _currentUrl;

  /// The Supabase project URL currently in use, or null when unconfigured.
  static String? get supabaseUrl => _currentUrl;

  /// Returns true iff Supabase is initialized AND a valid session exists.
  /// Idempotent. Never throws.
  static Future<bool> init() async {
    if (_initialized && _authReady) return true;

    String url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    String anonKey =
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    String email =
        const String.fromEnvironment('SUPABASE_SYNC_EMAIL', defaultValue: '');
    String password = const String.fromEnvironment(
      'SUPABASE_SYNC_PASSWORD',
      defaultValue: '',
    );

    // Runtime app_config ALWAYS overrides compile-time dart-define when non-empty.
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'app_config',
        columns: ['config_key', 'config_value'],
        where: "config_key IN ('supabase_url', 'supabase_anon_key', "
            "'supabase_sync_email', 'supabase_sync_password')",
      );
      final cfg = <String, String>{
        for (final r in rows)
          if (r['config_key'] is String && r['config_value'] is String)
            r['config_key'] as String: (r['config_value'] as String).trim(),
      };
      if ((cfg['supabase_url'] ?? '').isNotEmpty) {
        url = cfg['supabase_url']!;
      }
      if ((cfg['supabase_anon_key'] ?? '').isNotEmpty) {
        anonKey = cfg['supabase_anon_key']!;
      }
      if ((cfg['supabase_sync_email'] ?? '').isNotEmpty) {
        email = cfg['supabase_sync_email']!;
      }
      if ((cfg['supabase_sync_password'] ?? '').isNotEmpty) {
        password = cfg['supabase_sync_password']!;
      }
    } catch (_) {
      // Fallback to dart-define if DB is unavailable in isolated unit tests.
    }

    if (url.isEmpty || anonKey.isEmpty || email.isEmpty || password.isEmpty) {
      return false;
    }

    // Set _currentUrl BEFORE network/auth calls so ConnectivityService probes
    // the exact configured URL even if signInWithPassword fails on a bad URL.
    _currentUrl = url;

    try {
      if (!_initialized) {
        // ignore: deprecated_member_use
        await Supabase.initialize(url: url, anonKey: anonKey);
        _initialized = true;
      }
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        await client.auth.signInWithPassword(email: email, password: password);
      }
      _authReady = client.auth.currentSession != null;
      return _authReady;
    } catch (e) {
      debugPrint('[SupabaseClientWrapper] init failed for $url: $e');
      _authReady = false;
      return false;
    }
  }

  /// Disposes the live Supabase client (if any) and re-initializes from the
  /// current credentials. Returns true only if init + auth both succeed.
  static Future<bool> reconfigure() async {
    if (_initialized) {
      try {
        await Supabase.instance.dispose();
      } catch (_) {
        // Never initialized, or already disposed.
      }
    }
    _initialized = false;
    _authReady = false;
    _currentUrl = null;
    return await init();
  }

  /// G-10 Shot 5: initializes Supabase for license validation only — no sync
  /// service-account sign-in is required (`validate_license` is callable
  /// anonymously with the project's anon key).
  ///
  /// Credentials: BuildConfig dart-defines first, falling back to the runtime
  /// `app_config` SQLite values (`supabase_url` / `supabase_anon_key`).
  /// Returns false when unconfigured or the client cannot be created.
  static Future<bool> initForLicenseValidation() async {
    if (_initialized) return true;

    var url = BuildConfig.supabaseUrl;
    var anonKey = BuildConfig.supabaseAnonKey;

    // Runtime app_config ALWAYS overrides compile-time dart-define when
    // non-empty (same precedence as init()).
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'app_config',
        columns: ['config_key', 'config_value'],
        where: "config_key IN ('supabase_url', 'supabase_anon_key')",
      );
      final cfg = <String, String>{
        for (final r in rows)
          if (r['config_key'] is String && r['config_value'] is String)
            r['config_key'] as String: (r['config_value'] as String).trim(),
      };
      if ((cfg['supabase_url'] ?? '').isNotEmpty) {
        url = cfg['supabase_url']!;
      }
      if ((cfg['supabase_anon_key'] ?? '').isNotEmpty) {
        anonKey = cfg['supabase_anon_key']!;
      }
    } catch (_) {
      // DB unavailable (isolated tests / pre-provisioning): use dart-defines.
    }

    if (url.isEmpty || anonKey.isEmpty) return false;

    _currentUrl = url;
    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(url: url, anonKey: anonKey);
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint(
        '[SupabaseClientWrapper] license-validation init failed for $url: $e',
      );
      return false;
    }
  }

  /// G-10 Shot 5: calls the `public.validate_license` Postgres RPC and
  /// returns the first result row, or null when the RPC returns 0 rows
  /// (unknown/expired key).
  ///
  /// Throws when Supabase is unconfigured or unreachable — callers must
  /// distinguish "invalid key" (null) from "cannot verify online" (throw).
  static Future<Map<String, dynamic>?> validateLicenseRpc(
    String licenseKey,
  ) async {
    if (!await initForLicenseValidation()) {
      throw StateError('Supabase is not configured for license validation');
    }
    final client = Supabase.instance.client;
    final rows = await client
        .rpc('validate_license', params: {'p_license_key': licenseKey})
        .timeout(const Duration(seconds: 10));
    if (rows is! List || rows.isEmpty) return null;
    final row = rows.first;
    return row is Map<String, dynamic> ? row : Map<String, dynamic>.from(row);
  }

  /// Test-only: reset the singleton state. Do not call from production code.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _authReady = false;
    _currentUrl = null;
  }
}
