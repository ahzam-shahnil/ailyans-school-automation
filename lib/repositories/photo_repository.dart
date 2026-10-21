import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  /// Copies sourcePath into the photos directory as {stuRegId}.jpg.
  /// Returns the absolute destination path, or null on failure.
  Future<String?> copyForStudent(int stuRegId, String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final dir = await getPhotosDirectory();
      final dest = File(p.join(dir.path, '$stuRegId.jpg'));
      await src.copy(dest.path);
      return dest.path;
    } catch (e) {
      return null;
    }
  }

  /// Deletes {stuRegId}.jpg if it exists. Safe to call when absent.
  Future<void> deleteForStudent(int stuRegId) async {
    try {
      final dir = await getPhotosDirectory();
      final f = File(p.join(dir.path, '$stuRegId.jpg'));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
