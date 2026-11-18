import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/db/database.dart';

class LogoRepository {
  final Directory? overrideDirectory;

  LogoRepository({this.overrideDirectory});

  /// Resolves the writable branding directory, mirroring PhotoRepository::getPhotosDirectory.
  /// macOS/Linux: $HOME/Documents/Ailyans/branding
  /// Windows:     %USERPROFILE%\Documents\Ailyans\branding
  /// Fallback:    <appDocumentsDir>/Ailyans/branding
  Future<Directory> getBrandingDirectory() async {
    final override = overrideDirectory;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }

    String documentsPath;
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      documentsPath = (userProfile != null && userProfile.isNotEmpty)
          ? p.join(userProfile, 'Documents')
          : (await getApplicationDocumentsDirectory()).path;
    } else {
      final home = Platform.environment['HOME'];
      documentsPath = (home != null && home.isNotEmpty)
          ? p.join(home, 'Documents')
          : (await getApplicationDocumentsDirectory()).path;
    }

    final brandingDir =
        Directory(p.join(documentsPath, 'Ailyans', 'branding'));
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }
    return brandingDir;
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
      }
      return null;
    } catch (_) {
      return null; // never throw; NO self-heal writes
    }
  }
}
