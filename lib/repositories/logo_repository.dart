import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
}
