import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_config.dart';

/// Semantic version representation with build number support.
class AppSemver implements Comparable<AppSemver> {
  final int major;
  final int minor;
  final int patch;
  final int build;

  const AppSemver({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
  });

  /// Parses strings like "v2.0.0+2", "2.1.0", "v1.9.9+99", etc.
  static AppSemver parse(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }

    int build = 0;
    if (s.contains('+')) {
      final parts = s.split('+');
      s = parts[0];
      build = int.tryParse(parts[1]) ?? 0;
    }

    final vParts = s.split('.');
    final major = vParts.isNotEmpty ? (int.tryParse(vParts[0]) ?? 0) : 0;
    final minor = vParts.length > 1 ? (int.tryParse(vParts[1]) ?? 0) : 0;
    final patch = vParts.length > 2 ? (int.tryParse(vParts[2]) ?? 0) : 0;

    return AppSemver(major: major, minor: minor, patch: patch, build: build);
  }

  @override
  int compareTo(AppSemver other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  bool operator >(AppSemver other) => compareTo(other) > 0;
  bool operator <(AppSemver other) => compareTo(other) < 0;
  bool operator >=(AppSemver other) => compareTo(other) >= 0;
  bool operator <=(AppSemver other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSemver &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          build == other.build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => '$major.$minor.$patch+$build';
}

/// Release metadata manifest published in `bytewave-releases`.
class UpdateManifest {
  final String version;
  final int build;
  final String tag;
  final String publishedAt;
  final String notes;
  final Map<String, String> assets;

  const UpdateManifest({
    required this.version,
    required this.build,
    required this.tag,
    required this.publishedAt,
    required this.notes,
    required this.assets,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final assetsMap = <String, String>{};
    if (json['assets'] is Map) {
      final rawAssets = json['assets'] as Map;
      for (final entry in rawAssets.entries) {
        if (entry.key != null && entry.value != null) {
          assetsMap[entry.key.toString()] = entry.value.toString().trim();
        }
      }
    }

    return UpdateManifest(
      version: (json['version'] ?? '0.0.0').toString(),
      build: (json['build'] is int)
          ? json['build'] as int
          : (int.tryParse(json['build']?.toString() ?? '0') ?? 0),
      tag: (json['tag'] ?? '').toString(),
      publishedAt: (json['published_at'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      assets: assetsMap,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'build': build,
    'tag': tag,
    'published_at': publishedAt,
    'notes': notes,
    'assets': assets,
  };
}

/// Service to check for application updates against the public release manifest.
class UpdateCheckService {
  final http.Client? client;
  final SharedPreferences? prefs;
  final bool? isAilyansEditionOverride;

  static const String manifestUrl =
      'https://raw.githubusercontent.com/ahzam-shahnil/bytewave-releases/main/latest.json';
  static const String dismissedTagKey = 'dismissed_update_tag';
  static const String fallbackReleaseUrl =
      'https://github.com/ahzam-shahnil/bytewave-releases/releases/latest';

  UpdateCheckService({
    this.client,
    this.prefs,
    this.isAilyansEditionOverride,
  });

  /// True when this client runs the Ailyans production edition.
  bool get isAilyansEdition =>
      isAilyansEditionOverride ?? BuildConfig.isAilyansEdition;

  /// Compares [remote] version against [installed] version.
  /// Returns `true` only if remote > installed.
  static bool isNewerVersion(String remote, String installed) {
    final remoteSemver = AppSemver.parse(remote);
    final installedSemver = AppSemver.parse(installed);
    return remoteSemver > installedSemver;
  }

  /// Resolves the specific artifact download URL based on OS (clean builds only).
  static String resolveDownloadUrl(UpdateManifest manifest) {
    String? assetKey;
    if (Platform.isWindows) {
      assetKey = 'windows_clean';
    } else if (Platform.isAndroid) {
      assetKey = 'android_clean';
    }

    if (assetKey != null) {
      final url = manifest.assets[assetKey];
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return fallbackReleaseUrl;
  }

  /// Fetches latest update manifest from public repo.
  /// Fails silently and returns `null` on network errors, timeouts, or invalid JSON.
  /// If [isAilyansEdition] is true, returns `null` immediately without making any network call.
  Future<UpdateManifest?> fetchLatestManifest({
    ConnectivityResult? connectivity,
  }) async {
    // 0. Ailyan's Edition guard: public releases are generic clean edition only.
    if (isAilyansEdition) {
      return null;
    }

    // 1. Offline guard
    if (connectivity == ConnectivityResult.none) {
      return null;
    }

    // 2. Test guard: if no client injected and running in test environment, skip
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (client == null && isTest) {
      return null;
    }

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return UpdateManifest.fromJson(decoded);
    } catch (_) {
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Checks whether a given release tag has been dismissed by the user.
  Future<bool> isTagDismissed(String tag) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final dismissed = p.getString(dismissedTagKey);
      return dismissed == tag;
    } catch (_) {
      return false;
    }
  }

  /// Records a release tag as dismissed so it won't banner again.
  Future<void> dismissTag(String tag) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(dismissedTagKey, tag);
    } catch (_) {}
  }
}
