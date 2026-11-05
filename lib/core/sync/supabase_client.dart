import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    // 1. Resolve credentials from dart-define, then app_config fallback.
    String url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    String anonKey =
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    String email =
        const String.fromEnvironment('SUPABASE_SYNC_EMAIL', defaultValue: '');
    String password = const String.fromEnvironment(
      'SUPABASE_SYNC_PASSWORD',
      defaultValue: '',
    );

    if (url.isEmpty || anonKey.isEmpty || email.isEmpty || password.isEmpty) {
      try {
        final db = await DatabaseService.instance.database;
        final rows = await db.query(
          'app_config',
          columns: ['config_key', 'config_value'],
          where: "config_key IN ('supabase_url', 'supabase_anon_key', "
              "'supabase_sync_email', 'supabase_sync_password')",
        );
        for (final r in rows) {
          final key = r['config_key'];
          final value = (r['config_value'] as String?) ?? '';
          if (key == 'supabase_url' && url.isEmpty) url = value;
          if (key == 'supabase_anon_key' && anonKey.isEmpty) anonKey = value;
          if (key == 'supabase_sync_email' && email.isEmpty) email = value;
          if (key == 'supabase_sync_password' && password.isEmpty) {
            password = value;
          }
        }
      } catch (e) {
        debugPrint('[F-4a-1] app_config read failed: $e');
      }
    }

    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint('[F-4a-1] Supabase credentials not configured; sync disabled.');
      return false;
    }

    // 2. Initialize Supabase (global singleton).
    if (!_initialized) {
      try {
        // ignore: deprecated_member_use
        await Supabase.initialize(url: url, anonKey: anonKey);
        _initialized = true;
        _currentUrl = url;
      } catch (e) {
        debugPrint('[F-4a-1] Supabase.initialize failed: $e');
        return false;
      }
    } else {
      _currentUrl = url;
    }

    // 3. Sign in as sync service account if no session exists.
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        if (email.isEmpty || password.isEmpty) {
          debugPrint('[F-4a-1] Sync credentials missing; auth skipped.');
          _authReady = false;
          return false;
        }
        final resp = await auth.signInWithPassword(email: email, password: password);
        if (resp.session == null) {
          debugPrint('[F-4a-1] signInWithPassword returned null session.');
          _authReady = false;
          return false;
        }
      }
      _authReady = true;
      debugPrint('[F-4a-1] Supabase ready, session active.');
      return true;
    } catch (e) {
      debugPrint('[F-4a-1] Sign-in failed: $e');
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

  /// Test-only: reset the singleton state. Do not call from production code.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _authReady = false;
    _currentUrl = null;
  }
}
