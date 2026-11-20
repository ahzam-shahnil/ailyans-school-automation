import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/utils/photo_processor.dart';

class PhotoRepository {
  final String? overrideDocumentsPath;

  PhotoRepository({this.overrideDocumentsPath});

  /// Resolves the writable photos directory, mirroring database.dart::_getDatabasePath.
  /// macOS/Linux: $HOME/Documents/Ailyans/photos
  /// Windows:     %USERPROFILE%\Documents\Ailyans/photos
  /// Fallback:    <appDocumentsDir>/Ailyans/photos
  Future<Directory> getPhotosDirectory() async {
    String documentsPath;
    final customPath = overrideDocumentsPath;
    if (customPath != null && customPath.isNotEmpty) {
      documentsPath = customPath;
    } else if (Platform.isWindows) {
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
    final photosDir = Directory(p.join(documentsPath, 'Ailyans', 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// Copies and auto-compresses sourcePath into the photos directory.
  /// If [studentName] is provided, saves as `{stuRegId}_{SanitizedStudentName}.jpg`.
  /// Otherwise, saves as `{stuRegId}.jpg` (preserving backwards compatibility).
  /// Returns the absolute destination path, or null on failure.
  Future<String?> copyForStudent(
    int stuRegId,
    String sourcePath, {
    String? studentName,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final dir = await getPhotosDirectory();

      final String filename;
      if (studentName != null && studentName.trim().isNotEmpty) {
        filename = PhotoProcessor.generateFilename(
          regId: stuRegId,
          studentName: studentName,
        );
      } else {
        filename = '$stuRegId.jpg';
      }

      final dest = File(p.join(dir.path, filename));
      await PhotoProcessor.processAndSaveFile(src.path, dest.path);

      // Clean up legacy {stuRegId}.jpg if the new filename is different
      if (filename != '$stuRegId.jpg') {
        final legacy = File(p.join(dir.path, '$stuRegId.jpg'));
        if (await legacy.exists()) {
          try {
            await legacy.delete();
          } catch (_) {}
        }
      }

      return dest.path;
    } catch (e) {
      return null;
    }
  }

  /// Stages a photo for a new admission before a registration ID is assigned.
  /// Auto-compresses and saves into the photos directory as `temp_{timestamp}.jpg`.
  Future<String?> stageTempPhoto(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final dir = await getPhotosDirectory();
      final filename = PhotoProcessor.generateFilename();
      final dest = File(p.join(dir.path, filename));
      await PhotoProcessor.processAndSaveFile(src.path, dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  /// Deletes all photo variants for [stuRegId] (`{stuRegId}.jpg` and `{stuRegId}_*.jpg`).
  /// Safe to call when absent.
  Future<void> deleteForStudent(int stuRegId) async {
    try {
      final dir = await getPhotosDirectory();
      final legacy = File(p.join(dir.path, '$stuRegId.jpg'));
      if (await legacy.exists()) await legacy.delete();

      if (await dir.exists()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final basename = p.basename(entity.path);
            if (basename.startsWith('${stuRegId}_') &&
                basename.endsWith('.jpg')) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
  }
}
