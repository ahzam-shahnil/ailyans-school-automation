import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/db/database.dart';
import '../core/utils/tenant_storage.dart';

class LogoRepository {
  final Directory? overrideDirectory;
  final String? overrideDocumentsPath;
  final String? overrideTenantId;

  LogoRepository({
    this.overrideDirectory,
    this.overrideDocumentsPath,
    this.overrideTenantId,
  });

  /// Resolves the active tenant ID for this repository instance.
  Future<String> resolveTenantId() async {
    return TenantStorage.resolveActiveTenantId(
      overrideTenantId: overrideTenantId,
    );
  }

  /// Resolves the portable Documents directory.
  Future<String> getDocumentsPath() async {
    return TenantStorage.getDocumentsPath(
      overrideDocumentsPath: overrideDocumentsPath,
    );
  }

  /// Resolves the writable branding directory, mirroring PhotoRepository::getPhotosDirectory.
  /// `<Documents>/ByteWave/<tenantId>/branding/`
  /// If [overrideDirectory] is set (tests), returns it directly.
  Future<Directory> getBrandingDirectory() async {
    final override = overrideDirectory;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }

    final documentsPath = await getDocumentsPath();
    final tenantId = await resolveTenantId();
    final brandingDir =
        Directory(p.join(documentsPath, 'ByteWave', tenantId, 'branding'));
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }
    return brandingDir;
  }

  /// Resolves legacy branding directory:
  /// `<Documents>/Ailyans/branding/`.
  Future<Directory> getLegacyBrandingDirectory() async {
    final documentsPath = await getDocumentsPath();
    return Directory(p.join(documentsPath, 'Ailyans', 'branding'));
  }

  /// Resolves an existing logo path with legacy read fallback:
  /// 1. If [storedPath] is an absolute path that exists on disk, returns it directly.
  /// 2. If [storedPath] filename exists in `<Documents>/ByteWave/<tenantId>/branding/`, returns it.
  /// 3. Looks for any `logo.*` in `<Documents>/ByteWave/<tenantId>/branding/`.
  /// 4. If tenant is 'ailyans', falls back to legacy `<Documents>/Ailyans/branding/`.
  Future<String?> resolveLogoPath([String? storedPath]) async {
    // 1. Direct check: existing file on disk
    if (storedPath != null && storedPath.trim().isNotEmpty) {
      final file = File(storedPath.trim());
      if (await file.exists()) {
        return file.path;
      }
    }

    // 2. Check tenant branding directory
    final brandingDir = await getBrandingDirectory();
    if (await brandingDir.exists()) {
      if (storedPath != null && storedPath.trim().isNotEmpty) {
        final candidate = File(
          p.join(brandingDir.path, p.basename(storedPath.trim())),
        );
        if (await candidate.exists()) return candidate.path;
      }
      final found = await _findLogoFileInDir(brandingDir);
      if (found != null) return found.path;
    }

    // 3. Legacy Ailyan's fallback (read-only) when tenant is 'ailyans'
    final tenantId = await resolveTenantId();
    if (tenantId == 'ailyans') {
      final legacyDir = await getLegacyBrandingDirectory();
      if (await legacyDir.exists()) {
        if (storedPath != null && storedPath.trim().isNotEmpty) {
          final candidate = File(
            p.join(legacyDir.path, p.basename(storedPath.trim())),
          );
          if (await candidate.exists()) return candidate.path;
        }
        final found = await _findLogoFileInDir(legacyDir);
        if (found != null) return found.path;
      }
    }

    return null;
  }

  static Future<File?> _findLogoFileInDir(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith('logo.')) {
            return entity;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Copies [sourcePath] into the branding directory as `logo.<originalExt>`.
  /// Preserves the original file extension; raw copy, no re-encode.
  /// Returns the absolute destination path, or null on failure.
  Future<String?> copyLogo(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final ext = p.extension(sourcePath); // e.g. '.jpg', '.png'
      final dir = await getBrandingDirectory();
      final dest = File(p.join(dir.path, 'logo$ext'));
      if (!await dest.parent.exists()) {
        await dest.parent.create(recursive: true);
      }
      await src.copy(dest.path);
      return dest.path;
    } catch (e) {
      return null;
    }
  }

  /// Removes any `logo.*` file in the branding directory. Safe to call when absent.
  Future<void> deleteLogo() async {
    try {
      final dir = await getBrandingDirectory();
      await _deleteFilesInDir(dir);

      final tenantId = await resolveTenantId();
      if (tenantId == 'ailyans') {
        final legacyDir = await getLegacyBrandingDirectory();
        if (await legacyDir.exists()) {
          await _deleteFilesInDir(legacyDir);
        }
      }
    } catch (_) {}
  }

  static Future<void> _deleteFilesInDir(Directory dir) async {
    if (!await dir.exists()) return;
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith('logo.')) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }

  /// Base64-authoritative logo bytes loader.
  /// Pure reader: NEVER writes to disk or database.
  /// Catch-all: returns null on missing DB, missing keys, invalid base64, missing file.
  static Future<Uint8List?> loadLogoBytes([DatabaseExecutor? dbOverride]) async {
    try {
      if (dbOverride == null &&
          Platform.environment.containsKey('FLUTTER_TEST')) {
        // In Flutter testWidgets (AutomatedTestWidgetsFlutterBinding / FakeAsync),
        // querying sqflite isolate without runAsync deadlocks. Furthermore, pure
        // unit tests without an active open DB must not trigger disk initialization.
        final dynamic binding = WidgetsBinding.instance;
        bool isWidgetTest = false;
        try {
          isWidgetTest = binding != null && (binding.inTest == true);
        } catch (_) {}
        if (isWidgetTest || !DatabaseService.instance.isOpen) {
          return null;
        }
      }
      final db = dbOverride ?? await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        "SELECT config_key, config_value FROM app_config "
        "WHERE config_key IN ('school_logo_path','school_logo_base64')",
      );
      String? path;
      String? b64;
      bool hasB64 = false;
      for (final r in rows) {
        final k = r['config_key'] as String?;
        final v = r['config_value'] as String?;
        if (k == 'school_logo_path') path = v;
        if (k == 'school_logo_base64') {
          hasB64 = true;
          b64 = v;
        }
      }
      if (hasB64) {
        if (b64 == null || b64.isEmpty) return null; // globally removed; overrides stale local file
        final decoded = base64Decode(b64);
        return decoded.isEmpty ? null : decoded;
      }
      // Legacy 8a-only install (no base64 key yet): local file fallback.
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (f.existsSync()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        }
        final resolved = await LogoRepository().resolveLogoPath(path);
        if (resolved != null) {
          final rf = File(resolved);
          if (rf.existsSync()) {
            final bytes = await rf.readAsBytes();
            if (bytes.isNotEmpty) return bytes;
          }
        }
      } else {
        final resolved = await LogoRepository().resolveLogoPath();
        if (resolved != null) {
          final rf = File(resolved);
          if (rf.existsSync()) {
            final bytes = await rf.readAsBytes();
            if (bytes.isNotEmpty) return bytes;
          }
        }
      }
      return null;
    } catch (_) {
      return null; // never throw; NO self-heal writes
    }
  }
}
