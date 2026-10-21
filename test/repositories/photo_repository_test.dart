import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:school_automation/repositories/photo_repository.dart';

void main() {
  late Directory tempDir;
  late PhotoRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('photo_repo_test_');
    repo = PhotoRepository(overrideDocumentsPath: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PhotoRepository Tests', () {
    test('1. getPhotosDirectory creates directory tree if missing', () async {
      final photosDir = await repo.getPhotosDirectory();
      expect(await photosDir.exists(), isTrue);
      expect(photosDir.path, p.join(tempDir.path, 'Ailyans', 'photos'));
    });

    test(
      '2. copyForStudent copies file to {stuRegId}.jpg with matching content',
      () async {
        final dummySource = File(p.join(tempDir.path, 'source_photo.jpg'));
        await dummySource.writeAsString('test-photo-binary-bytes');

        final resultPath = await repo.copyForStudent(4411, dummySource.path);

        expect(resultPath, isNotNull);
        final destFile = File(resultPath!);
        expect(await destFile.exists(), isTrue);
        expect(
          destFile.path,
          p.join(tempDir.path, 'Ailyans', 'photos', '4411.jpg'),
        );
        expect(await destFile.readAsString(), 'test-photo-binary-bytes');
      },
    );

    test(
      '3. copyForStudent returns null for nonexistent source file',
      () async {
        final missingPath = p.join(tempDir.path, 'nonexistent.jpg');

        final resultPath = await repo.copyForStudent(4411, missingPath);

        expect(resultPath, isNull);
        final expectedDest = File(
          p.join(tempDir.path, 'Ailyans', 'photos', '4411.jpg'),
        );
        expect(await expectedDest.exists(), isFalse);
      },
    );

    test(
      '4. deleteForStudent removes file; calling again is a safe no-op',
      () async {
        final dummySource = File(p.join(tempDir.path, 'source_photo.jpg'));
        await dummySource.writeAsString('sample');
        final resultPath = await repo.copyForStudent(4411, dummySource.path);
        expect(resultPath, isNotNull);
        final destFile = File(resultPath!);
        expect(await destFile.exists(), isTrue);

        // First delete
        await repo.deleteForStudent(4411);
        expect(await destFile.exists(), isFalse);

        // Safe no-op delete when already absent
        await expectLater(repo.deleteForStudent(4411), completes);
      },
    );
  });
}
