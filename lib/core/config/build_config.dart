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
}
