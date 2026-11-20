import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:school_automation/core/utils/photo_processor.dart';

void main() {
  group('PhotoProcessor Tests', () {
    test('1. Large rectangular image (>400x400) is center-cropped to square, resized to 400x400, and encoded as JPEG', () {
      // Create an 800x600 test image with distinct colored quadrants
      final testImg = img.Image(width: 800, height: 600);
      img.fill(testImg, color: img.ColorRgb8(100, 150, 200));
      final rawPng = Uint8List.fromList(img.encodePng(testImg));

      expect(rawPng.length, greaterThan(1000));

      final processedBytes = PhotoProcessor.processPhotoBytes(rawPng);

      // Verify JPEG magic bytes (0xFF, 0xD8)
      expect(processedBytes[0], 0xFF);
      expect(processedBytes[1], 0xD8);

      // Decode the result
      final resultImg = img.decodeJpg(processedBytes);
      expect(resultImg, isNotNull);
      expect(resultImg!.width, 400);
      expect(resultImg.height, 400);

      // Compressed JPEG should be compact (well below 50 KB)
      expect(processedBytes.lengthInBytes, lessThan(50 * 1024));
    });

    test('2. Smaller image (250x300) is center-cropped to 250x250 without enlarging', () {
      final testImg = img.Image(width: 250, height: 300);
      img.fill(testImg, color: img.ColorRgb8(50, 80, 120));
      final rawPng = Uint8List.fromList(img.encodePng(testImg));

      final processedBytes = PhotoProcessor.processPhotoBytes(rawPng);
      final resultImg = img.decodeJpg(processedBytes);

      expect(resultImg, isNotNull);
      expect(resultImg!.width, 250);
      expect(resultImg.height, 250);
    });

    test('3. Corrupted or invalid bytes throw FormatException in processPhotoBytes', () {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(
        () => PhotoProcessor.processPhotoBytes(invalidBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      '4. tryProcessPhotoBytes returns null on invalid bytes without throwing',
      () {
        final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        expect(PhotoProcessor.tryProcessPhotoBytes(invalidBytes), isNull);
      },
    );

    test('5. processAndSaveFile writes valid JPEG file to disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('processor_test_');
      try {
        final srcFile = File('${tempDir.path}/source.png');
        final destFile = File('${tempDir.path}/dest.jpg');

        final testImg = img.Image(width: 500, height: 500);
        img.fill(testImg, color: img.ColorRgb8(200, 100, 50));
        await srcFile.writeAsBytes(img.encodePng(testImg));

        final saved = await PhotoProcessor.processAndSaveFile(
          srcFile.path,
          destFile.path,
        );

        expect(await saved.exists(), isTrue);
        final bytes = await saved.readAsBytes();
        expect(bytes[0], 0xFF);
        expect(bytes[1], 0xD8);

        final decoded = img.decodeJpg(bytes);
        expect(decoded, isNotNull);
        expect(decoded!.width, 400);
        expect(decoded.height, 400);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    group('Filename Sanitization & Generation', () {
      test('6. sanitizeName handles normal, accented, and spaced names', () {
        expect(PhotoProcessor.sanitizeName('Ajwa Mumtaz'), 'Ajwa_Mumtaz');
        expect(
          PhotoProcessor.sanitizeName('Muhammad-Ali Khan'),
          'Muhammad_Ali_Khan',
        );
        expect(
          PhotoProcessor.sanitizeName('  John.Doe-Smith   '),
          'John_Doe_Smith',
        );
      });

      test(
        '7. sanitizeName strips special characters and collapses underscores',
        () {
          expect(
            PhotoProcessor.sanitizeName('Student!@#\$%^&*()_+Name'),
            'Student_Name',
          );
          expect(PhotoProcessor.sanitizeName('___Test___'), 'Test');
        },
      );

      test('8. sanitizeName falls back to "Student" for empty, whitespace, or null', () {
        expect(PhotoProcessor.sanitizeName(null), 'Student');
        expect(PhotoProcessor.sanitizeName(''), 'Student');
        expect(PhotoProcessor.sanitizeName('    '), 'Student');
        expect(PhotoProcessor.sanitizeName('!@#\$%'), 'Student');
      });

      test('9. generateFilename generates {RegID}_{SanitizedName}.jpg when regId > 0', () {
        expect(
          PhotoProcessor.generateFilename(
            regId: 4785,
            studentName: 'Ajwa Mumtaz',
          ),
          '4785_Ajwa_Mumtaz.jpg',
        );
        expect(
          PhotoProcessor.generateFilename(regId: 1001, studentName: 'Ali-Raza'),
          '1001_Ali_Raza.jpg',
        );
        expect(
          PhotoProcessor.generateFilename(regId: 2002, studentName: null),
          '2002_Student.jpg',
        );
      });

      test('10. generateFilename generates temp_{timestamp}.jpg when regId is null or <= 0', () {
        final f1 = PhotoProcessor.generateFilename(studentName: 'Ajwa');
        expect(f1, startsWith('temp_'));
        expect(f1, endsWith('.jpg'));

        final f2 = PhotoProcessor.generateFilename(
          regId: 0,
          studentName: 'Ajwa',
        );
        expect(f2, startsWith('temp_'));
        expect(f2, endsWith('.jpg'));

        final f3 = PhotoProcessor.generateFilename(regId: -1);
        expect(f3, startsWith('temp_'));
        expect(f3, endsWith('.jpg'));
      });
    });
  });
}
