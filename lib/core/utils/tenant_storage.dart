import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_config.dart';

/// Utilities for resolving tenant IDs and portable Documents/ByteWave directories.
class TenantStorage {
  static const String tenantKey = 'bytewave_tenant';

  /// Sanitizes [raw] tenant ID into safe directory characters.
  /// Converts whitespace, hyphens, and periods to underscores, strips non-alphanumeric,
  /// collapses underscores, and lowercases.
  /// Falls back to 'ailyans' if [BuildConfig.isAilyansEdition] else 'default'.
  static String sanitizeTenantId(String? raw) {
    final fallback = BuildConfig.isAilyansEdition ? 'ailyans' : 'default';
    if (raw == null || raw.trim().isEmpty) return fallback;
    var clean = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-.]+'), '_');
    clean = clean.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    clean = clean.replaceAll(RegExp(r'_+'), '_');
    clean = clean.replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.isEmpty ? fallback : clean;
  }

  /// Resolves the active tenant ID using the same source as DatabaseService:
  /// SharedPreferences key `bytewave_tenant`, sanitized to safe directory characters,
  /// falling back to 'ailyans' if [BuildConfig.isAilyansEdition] else 'default'.
  static Future<String> resolveActiveTenantId({String? overrideTenantId}) async {
    if (overrideTenantId != null && overrideTenantId.isNotEmpty) {
      return sanitizeTenantId(overrideTenantId);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(tenantKey);
      if (raw != null) {
        if (raw.trim().startsWith('{')) {
          final decoded = jsonDecode(raw);
          final id = decoded is Map<String, dynamic> ? decoded['id'] : null;
          if (id is String && id.isNotEmpty) {
            return sanitizeTenantId(id);
          }
        } else {
          return sanitizeTenantId(raw);
        }
      }
    } catch (_) {}
    return BuildConfig.isAilyansEdition ? 'ailyans' : 'default';
  }

  /// Synchronous fallback when SharedPreferences is unavailable or async cannot be awaited.
  static String resolveActiveTenantIdSync({String? overrideTenantId}) {
    if (overrideTenantId != null && overrideTenantId.isNotEmpty) {
      return sanitizeTenantId(overrideTenantId);
    }
    return BuildConfig.isAilyansEdition ? 'ailyans' : 'default';
  }

  /// Locates the portable Documents/ directory across platforms:
  /// - Windows: %USERPROFILE%\Documents
  /// - macOS & Linux: ~/Documents
  /// - Android & iOS (or fallback): <appDocumentsDir>
  static Future<String> getDocumentsPath({String? overrideDocumentsPath}) async {
    if (overrideDocumentsPath != null && overrideDocumentsPath.isNotEmpty) {
      return overrideDocumentsPath;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    }
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return p.join(userProfile, 'Documents');
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, 'Documents');
      }
    }
    final docsDir = await getApplicationDocumentsDirectory();
    return docsDir.path;
  }

  /// Synchronous Documents directory locator using environment variables.
  static String getDocumentsPathSync({String? overrideDocumentsPath}) {
    if (overrideDocumentsPath != null && overrideDocumentsPath.isNotEmpty) {
      return overrideDocumentsPath;
    }
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return p.join(userProfile, 'Documents');
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, 'Documents');
      }
    }
    return '';
  }
}
