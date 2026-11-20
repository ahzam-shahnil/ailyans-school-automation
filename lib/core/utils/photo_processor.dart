import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Utility for student photo auto-compression, center-cropping, and deterministic naming.
class PhotoProcessor {
  static const int maxDimension = 400;
  static const int jpegQuality = 80;

  /// Decodes [rawBytes], center-crops to a 1:1 square, resizes down to at most
  /// [maxDimension]x[maxDimension], and encodes as JPEG with [jpegQuality].
  ///
  /// Throws [FormatException] if [rawBytes] cannot be decoded as an image.
  static Uint8List processPhotoBytes(Uint8List rawBytes) {
    final image = img.decodeImage(rawBytes);
    if (image == null) {
      throw const FormatException('Unable to decode image bytes');
    }

    // 1. Center-crop to square
    final size = image.width < image.height ? image.width : image.height;
    final x = (image.width - size) ~/ 2;
    final y = (image.height - size) ~/ 2;
    final cropped = img.copyCrop(image, x: x, y: y, width: size, height: size);

    // 2. Resize to max maxDimension x maxDimension
    final targetSize = size > maxDimension ? maxDimension : size;
    final resized =
        (cropped.width != targetSize || cropped.height != targetSize)
        ? img.copyResize(
            cropped,
            width: targetSize,
            height: targetSize,
            interpolation: img.Interpolation.linear,
          )
        : cropped;

    // 3. Encode as JPEG quality 80
    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
  }

  /// Safe variant of [processPhotoBytes] that returns `null` instead of throwing
  /// if decoding fails (e.g. for mock data in unit tests).
  static Uint8List? tryProcessPhotoBytes(Uint8List rawBytes) {
    try {
      return processPhotoBytes(rawBytes);
    } catch (_) {
      return null;
    }
  }

  /// Processes an image from [sourcePath] and writes the compressed JPEG to [destPath].
  /// If the source is not a decodable image, falls back to copying the raw file.
  static Future<File> processAndSaveFile(
    String sourcePath,
    String destPath,
  ) async {
    final srcFile = File(sourcePath);
    final rawBytes = await srcFile.readAsBytes();
    final processed = tryProcessPhotoBytes(rawBytes);

    final destFile = File(destPath);
    await destFile.parent.create(recursive: true);

    if (processed != null) {
      await destFile.writeAsBytes(processed, flush: true);
    } else {
      await srcFile.copy(destFile.path);
    }
    return destFile;
  }

  /// Sanitizes a student name into a filesystem-safe token.
  /// Converts spaces, hyphens, and periods to underscores, strips non-alphanumeric
  /// characters, collapses consecutive underscores, and trims leading/trailing underscores.
  /// Returns "Student" if the result is empty.
  static String sanitizeName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Student';
    var s = name.trim().replaceAll(RegExp(r'[\s\-.]+'), '_');
    s = s.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return s.isEmpty ? 'Student' : s;
  }

  /// Generates the canonical filename for a student's photo.
  /// If [regId] is valid (> 0), returns `{RegID}_{SanitizedStudentName}.jpg`
  /// (e.g. `4785_Ajwa_Mumtaz.jpg`).
  /// If [regId] is absent or <= 0, returns `temp_{timestamp}.jpg`.
  static String generateFilename({int? regId, String? studentName}) {
    if (regId != null && regId > 0) {
      final cleanName = sanitizeName(studentName);
      return '${regId}_$cleanName.jpg';
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'temp_$timestamp.jpg';
  }
}
