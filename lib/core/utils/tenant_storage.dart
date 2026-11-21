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

  /// Returns true if [metadataOrName] indicates an Ailyans brand (via
  /// branchName containing 'Ailyan' or [BuildConfig.isAilyansEdition]).
  static bool isAilyansBrand([dynamic metadataOrName]) {
    if (metadataOrName is String && metadataOrName.isNotEmpty) {
      return metadataOrName.toLowerCase().contains('ailyan') ||
          BuildConfig.isAilyansEdition;
    }
    if (metadataOrName != null) {
      try {
        final branchName = (metadataOrName as dynamic).branchName;
        if (branchName is String && branchName.isNotEmpty) {
          return branchName.toLowerCase().contains('ailyan') ||
              BuildConfig.isAilyansEdition;
        }
      } catch (_) {}
    }
    return BuildConfig.isAilyansEdition;
  }

  /// Resolves short brand name for shell navigation (sidebar/topbar).
  /// If Ailyans: 'Ailyans HSS' for topbar or 'Ailyans School' for sidebar.
  /// If clean tenant: first word of branchName (if 3-15 chars) or 'ByteWave'.
  static String resolveShortBrand(
    dynamic metadataOrName, {
    bool forTopBar = false,
  }) {
    if (isAilyansBrand(metadataOrName)) {
      return forTopBar ? 'Ailyans HSS' : 'Ailyans School';
    }
    String? branchName;
    if (metadataOrName is String && metadataOrName.isNotEmpty) {
      branchName = metadataOrName;
    } else if (metadataOrName != null) {
      try {
        final name = (metadataOrName as dynamic).branchName;
        if (name is String && name.isNotEmpty) {
          branchName = name;
        }
      } catch (_) {}
    }
    if (branchName != null && branchName.trim().isNotEmpty) {
      final words = branchName.trim().split(RegExp(r'\s+'));
      final candidate = words.first;
      if (candidate.length >= 3 && candidate.length <= 15) {
        return candidate;
      }
    }
    return 'ByteWave';
  }

  /// Resolves database basename for status bars and login screens.
  /// If Ailyans: 'SDB_Ailyans.db'.
  /// If clean tenant: 'school_<tenantId>.db'.
  static String resolveDbBaseName([dynamic metadataOrName]) {
    if (isAilyansBrand(metadataOrName)) {
      return 'SDB_Ailyans.db';
    }
    final tenantId = resolveActiveTenantIdSync();
    return 'school_$tenantId.db';
  }

  /// Resolves full school name.
  /// If metadata branchName is present, uses it.
  /// Otherwise falls back to Ailyans title if Ailyans brand, else [fallback].
  static String resolveSchoolName(
    dynamic metadataOrName, {
    String fallback = 'ByteWave School',
  }) {
    String? branchName;
    if (metadataOrName is String && metadataOrName.isNotEmpty) {
      branchName = metadataOrName;
    } else if (metadataOrName != null) {
      try {
        final name = (metadataOrName as dynamic).branchName;
        if (name is String && name.isNotEmpty) {
          branchName = name;
        }
      } catch (_) {}
    }
    if (branchName != null && branchName.trim().isNotEmpty) {
      return branchName.trim();
    }
    if (isAilyansBrand(metadataOrName)) {
      return "Ailyans's Higher Secondary School Mianwali";
    }
    return fallback;
  }

  /// Resolves school branch address.
  static String resolveSchoolAddress(
    dynamic metadataOrName, {
    String fallback = '',
  }) {
    String? branchAddress;
    if (metadataOrName != null) {
      try {
        final addr = (metadataOrName as dynamic).branchAddress;
        if (addr is String && addr.isNotEmpty) {
          branchAddress = addr;
        }
      } catch (_) {}
    }
    if (branchAddress != null && branchAddress.trim().isNotEmpty) {
      return branchAddress.trim();
    }
    if (isAilyansBrand(metadataOrName)) {
      return 'Muslim Bazar Mianwali';
    }
    return fallback;
  }

  /// Resolves splash title displayed while app boots.
  static String resolveSplashTitle([dynamic metadataOrName]) {
    if (metadataOrName != null) {
      String? branchName;
      if (metadataOrName is String) {
        branchName = metadataOrName;
      } else {
        try {
          final name = (metadataOrName as dynamic).branchName;
          if (name is String) branchName = name;
        } catch (_) {}
      }
      if (branchName != null && branchName.isNotEmpty) {
        if (isAilyansBrand(metadataOrName)) {
          return 'Ailyans School Automation System';
        }
        return '$branchName School Automation System';
      }
    }
    return 'Ailyans School Automation System';
  }

  /// Resolves the human-readable database path label for settings.
  static String resolveDatabaseDisplayPath({String? overrideTenantId}) {
    final tenant = resolveActiveTenantIdSync(
      overrideTenantId: overrideTenantId,
    );
    if (BuildConfig.isAilyansEdition || tenant == 'ailyans') {
      return '~/Documents/Ailyans/school_database.db';
    }
    return '~/Documents/ByteWave/school_$tenant.db';
  }

  /// Resolves the human-readable backup path label for settings.
  static String resolveBackupsDisplayPath() {
    if (BuildConfig.isAilyansEdition) {
      return '~/Documents/Ailyans/backups';
    }
    return '~/Documents/ByteWave/backups';
  }
}
