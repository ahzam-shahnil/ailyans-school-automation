import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/utils/photo_processor.dart';
import '../core/utils/tenant_storage.dart';

class PhotoRepository {
  final String? overrideDocumentsPath;
  final String? overrideTenantId;

  PhotoRepository({
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

  /// Resolves the writable photos directory for the active tenant:
  /// `<Documents>/ByteWave/<tenantId>/photos/`.
  /// Automatically creates directory tree if missing.
  Future<Directory> getPhotosDirectory() async {
    final documentsPath = await getDocumentsPath();
    final tenantId = await resolveTenantId();
    final photosDir = Directory(
      p.join(documentsPath, 'ByteWave', tenantId, 'photos'),
    );
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// Resolves legacy Ailyans photos directory:
  /// `<Documents>/Ailyans/photos/`.
  Future<Directory> getLegacyPhotosDirectory() async {
    final documentsPath = await getDocumentsPath();
    return Directory(p.join(documentsPath, 'Ailyans', 'photos'));
  }

  /// Resolves the absolute path for an existing photo with legacy read fallback:
  /// 1. If [storedPath] is an absolute path that exists on disk (including legacy
  ///    `<Documents>/Ailyans/photos/...` or `<Documents>/ByteWave/<tenantId>/photos/...`),
  ///    returns it directly.
  /// 2. If looking up by filename or [stuRegId], searches in:
  ///    - Tenant directory: `<Documents>/ByteWave/<tenantId>/photos/`
  ///    - Legacy directory (read-only fallback for tenant 'ailyans'): `<Documents>/Ailyans/photos/`
  /// Returns the absolute path if found, or null otherwise.
  Future<String?> resolvePhotoPath(
    String? storedPath, {
    int? stuRegId,
    String? studentName,
  }) async {
    // 1. Direct check: existing file on disk (works for absolute paths)
    if (storedPath != null && storedPath.trim().isNotEmpty) {
      final file = File(storedPath.trim());
      if (await file.exists()) {
        return file.path;
      }
    }

    final tenantId = await resolveTenantId();
    final photosDir = await getPhotosDirectory();

    // 2. Check tenant directory by filename
    if (storedPath != null && storedPath.trim().isNotEmpty) {
      final filename = p.basename(storedPath.trim());
      final candidate = File(p.join(photosDir.path, filename));
      if (await candidate.exists()) {
        return candidate.path;
      }
    }

    // 3. Check tenant directory by stuRegId / studentName
    if (stuRegId != null && stuRegId > 0) {
      final found = await _findInDirectory(
        photosDir,
        stuRegId,
        studentName: studentName,
      );
      if (found != null) return found;
    }

    // 4. Legacy Ailyan's fallback (read-only) when tenant is 'ailyans'
    if (tenantId == 'ailyans') {
      final legacyDir = await getLegacyPhotosDirectory();
      if (await legacyDir.exists()) {
        if (storedPath != null && storedPath.trim().isNotEmpty) {
          final filename = p.basename(storedPath.trim());
          final candidate = File(p.join(legacyDir.path, filename));
          if (await candidate.exists()) {
            return candidate.path;
          }
        }
        if (stuRegId != null && stuRegId > 0) {
          final found = await _findInDirectory(
            legacyDir,
            stuRegId,
            studentName: studentName,
          );
          if (found != null) return found;
        }
      }
    }

    return null;
  }

  /// Synchronous variant of photo resolution for immediate UI build operations.
  static File? resolvePhotoFileSync({
    String? photoPath,
    int? stuRegId,
    String? studentName,
    String? documentsPath,
    String? tenantId,
  }) {
    if (photoPath != null && photoPath.trim().isNotEmpty) {
      final f = File(photoPath.trim());
      if (f.existsSync()) return f;
    }

    final docs = documentsPath ?? TenantStorage.getDocumentsPathSync();
    if (docs.isEmpty) return null;

    final resolvedTenant =
        tenantId ?? TenantStorage.resolveActiveTenantIdSync();

    // Check tenant directory
    final tenantPhotosDir = Directory(
      p.join(docs, 'ByteWave', resolvedTenant, 'photos'),
    );
    if (photoPath != null && photoPath.trim().isNotEmpty) {
      final candidate = File(
        p.join(tenantPhotosDir.path, p.basename(photoPath.trim())),
      );
      if (candidate.existsSync()) return candidate;
    }
    if (stuRegId != null && stuRegId > 0) {
      final found = _findInDirectorySync(
        tenantPhotosDir,
        stuRegId,
        studentName: studentName,
      );
      if (found != null) return found;
    }

    // Legacy fallback for 'ailyans' tenant
    if (resolvedTenant == 'ailyans') {
      final legacyDir = Directory(p.join(docs, 'Ailyans', 'photos'));
      if (photoPath != null && photoPath.trim().isNotEmpty) {
        final candidate = File(
          p.join(legacyDir.path, p.basename(photoPath.trim())),
        );
        if (candidate.existsSync()) return candidate;
      }
      if (stuRegId != null && stuRegId > 0) {
        final found = _findInDirectorySync(
          legacyDir,
          stuRegId,
          studentName: studentName,
        );
        if (found != null) return found;
      }
    }

    return null;
  }

  static Future<String?> _findInDirectory(
    Directory dir,
    int stuRegId, {
    String? studentName,
  }) async {
    if (!await dir.exists()) return null;
    final direct = File(p.join(dir.path, '$stuRegId.jpg'));
    if (await direct.exists()) return direct.path;

    if (studentName != null && studentName.trim().isNotEmpty) {
      final nameFile = File(
        p.join(
          dir.path,
          PhotoProcessor.generateFilename(
            regId: stuRegId,
            studentName: studentName,
          ),
        ),
      );
      if (await nameFile.exists()) return nameFile.path;
    }

    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final base = p.basename(entity.path);
          if (base.startsWith('${stuRegId}_') && base.endsWith('.jpg')) {
            return entity.path;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static File? _findInDirectorySync(
    Directory dir,
    int stuRegId, {
    String? studentName,
  }) {
    if (!dir.existsSync()) return null;
    final direct = File(p.join(dir.path, '$stuRegId.jpg'));
    if (direct.existsSync()) return direct;

    if (studentName != null && studentName.trim().isNotEmpty) {
      final nameFile = File(
        p.join(
          dir.path,
          PhotoProcessor.generateFilename(
            regId: stuRegId,
            studentName: studentName,
          ),
        ),
      );
      if (nameFile.existsSync()) return nameFile;
    }

    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final base = p.basename(entity.path);
          if (base.startsWith('${stuRegId}_') && base.endsWith('.jpg')) {
            return entity;
          }
        }
      }
    } catch (_) {}
    return null;
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
      if (!await dest.parent.exists()) {
        await dest.parent.create(recursive: true);
      }
      await PhotoProcessor.processAndSaveFile(src.path, dest.path);

      // Clean up legacy {stuRegId}.jpg if the new filename is different
      if (filename != '$stuRegId.jpg') {
        final legacy = File(p.join(dir.path, '$stuRegId.jpg'));
        if (await legacy.exists()) {
          try {
            await legacy.delete();
          } catch (_) {}
        }
        final tenantId = await resolveTenantId();
        if (tenantId == 'ailyans') {
          final legacyDir = await getLegacyPhotosDirectory();
          final legacyFile = File(p.join(legacyDir.path, '$stuRegId.jpg'));
          if (await legacyFile.exists()) {
            try {
              await legacyFile.delete();
            } catch (_) {}
          }
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
      if (!await dest.parent.exists()) {
        await dest.parent.create(recursive: true);
      }
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
      await _deleteInDirectory(dir, stuRegId);

      final tenantId = await resolveTenantId();
      if (tenantId == 'ailyans') {
        final legacyDir = await getLegacyPhotosDirectory();
        if (await legacyDir.exists()) {
          await _deleteInDirectory(legacyDir, stuRegId);
        }
      }
    } catch (_) {}
  }

  static Future<void> _deleteInDirectory(Directory dir, int stuRegId) async {
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
  }
}
