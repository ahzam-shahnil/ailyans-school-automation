import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Default fallback version matching pubspec.yaml if platform channels fail or in tests.
const String kDefaultAppVersion = 'v2.0.0+2';

/// Asynchronous provider for the platform app version and build number.
/// Gracefully returns [kDefaultAppVersion] if platform channels are unavailable.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final buildNumber = info.buildNumber.trim();
    if (version.isEmpty) return kDefaultAppVersion;
    return buildNumber.isNotEmpty ? 'v$version+$buildNumber' : 'v$version';
  } catch (_) {
    return kDefaultAppVersion;
  }
});
