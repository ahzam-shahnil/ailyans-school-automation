/// G-10 Shot 3: build-time configuration switches for the ByteWave SaaS.
///
/// The seed profile is selected at compile time via `--dart-define`:
///
///   # Ailyans Edition — bundles the 673-student production snapshot
///   flutter build apk --release --dart-define=SEED_PROFILE=ailyans
///
///   # SaaS Edition — clean onboarding database (default)
///   flutter build apk --release --dart-define=SEED_PROFILE=clean
class BuildConfig {
  /// Seed profile selected at build time. Defaults to the clean SaaS
  /// edition so unconfigured builds never ship Ailyans production data.
  static const String seedProfile = String.fromEnvironment(
    'SEED_PROFILE',
    defaultValue: 'clean',
  );

  /// True when this build bundles the Ailyans production seed database.
  static bool get isAilyansEdition => seedProfile == 'ailyans';

  /// True when this build uses the clean SaaS onboarding profile.
  static bool get isSaasEdition => seedProfile == 'clean';

  /// G-10 Shot 5: Supabase project credentials bundled at build time.
  ///
  ///   flutter build apk --release \
  ///     --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  ///     --dart-define=SUPABASE_ANON_KEY=<anon-key>
  ///
  /// Empty by default so open-source builds ship without credentials; the
  /// runtime `app_config` SQLite values (set via Cloud Sync settings or
  /// license activation) always take precedence when non-empty.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
