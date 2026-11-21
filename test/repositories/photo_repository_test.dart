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
      expect(
        photosDir.path,
        p.join(tempDir.path, 'ByteWave', 'default', 'photos'),
      );
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
          p.join(tempDir.path, 'ByteWave', 'default', 'photos', '4411.jpg'),
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
          p.join(tempDir.path, 'ByteWave', 'default', 'photos', '4411.jpg'),
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

    test(
      '5. copyForStudent with studentName creates {stuRegId}_{SanitizedName}.jpg and removes legacy file',
      () async {
        // First create legacy file in tenant directory
        final legacy = File(
          p.join(tempDir.path, 'ByteWave', 'default', 'photos', '4411.jpg'),
        );
        await legacy.parent.create(recursive: true);
        await legacy.writeAsString('old-legacy');
        expect(await legacy.exists(), isTrue);

        final dummySource = File(p.join(tempDir.path, 'source_photo.jpg'));
        await dummySource.writeAsString('sample');

        final resultPath = await repo.copyForStudent(
          4411,
          dummySource.path,
          studentName: 'Ajwa Mumtaz',
        );

        expect(resultPath, isNotNull);
        expect(p.basename(resultPath!), '4411_Ajwa_Mumtaz.jpg');
        expect(await File(resultPath).exists(), isTrue);
        // Legacy file was purged
        expect(await legacy.exists(), isFalse);

        // deleteForStudent removes the sanitized file too
        await repo.deleteForStudent(4411);
        expect(await File(resultPath).exists(), isFalse);
      },
    );

    test(
      '6. stageTempPhoto creates temporary photo file in photos directory',
      () async {
        final dummySource = File(p.join(tempDir.path, 'source_photo.jpg'));
        await dummySource.writeAsString('temp-sample');

        final stagedPath = await repo.stageTempPhoto(dummySource.path);
        expect(stagedPath, isNotNull);
        final filename = p.basename(stagedPath!);
        expect(filename, startsWith('temp_'));
        expect(filename, endsWith('.jpg'));
        expect(await File(stagedPath).exists(), isTrue);
      },
    );

    test(
      '7. copyForStudent creates parent directory recursively if missing before write',
      () async {
        // Ensure photos directory does not exist yet
        final photosDir = Directory(
          p.join(tempDir.path, 'ByteWave', 'default', 'photos'),
        );
        if (await photosDir.exists()) {
          await photosDir.delete(recursive: true);
        }
        expect(await photosDir.exists(), isFalse);

        final dummySource = File(p.join(tempDir.path, 'source_photo.jpg'));
        await dummySource.writeAsString('sample');

        final resultPath = await repo.copyForStudent(
          5500,
          dummySource.path,
          studentName: 'Test Student',
        );

        expect(resultPath, isNotNull);
        expect(await File(resultPath!).exists(), isTrue);
        expect(await photosDir.exists(), isTrue);
      },
    );

    test(
      '8. Multi-tenant isolation: school_a and school_b write to separate directories',
      () async {
        final repoA = PhotoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'school_a',
        );
        final repoB = PhotoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'school_b',
        );

        final dummySource = File(p.join(tempDir.path, 'source_photo.jpg'));
        await dummySource.writeAsString('common-source');

        final pathA = await repoA.copyForStudent(
          101,
          dummySource.path,
          studentName: 'Alice',
        );
        final pathB = await repoB.copyForStudent(
          101,
          dummySource.path,
          studentName: 'Alice',
        );

        expect(pathA, isNotNull);
        expect(pathB, isNotNull);
        expect(pathA, isNot(equals(pathB)));

        expect(
          pathA,
          p.join(
            tempDir.path,
            'ByteWave',
            'school_a',
            'photos',
            '101_Alice.jpg',
          ),
        );
        expect(
          pathB,
          p.join(
            tempDir.path,
            'ByteWave',
            'school_b',
            'photos',
            '101_Alice.jpg',
          ),
        );

        expect(await File(pathA!).exists(), isTrue);
        expect(await File(pathB!).exists(), isTrue);

        // Deleting from school_a does not affect school_b
        await repoA.deleteForStudent(101);
        expect(await File(pathA).exists(), isFalse);
        expect(await File(pathB).exists(), isTrue);
      },
    );

    test(
      '9. Legacy Fallback: Documents/Ailyans/photos files resolve cleanly for tenant ailyans',
      () async {
        final legacyDir = Directory(
          p.join(tempDir.path, 'Ailyans', 'photos'),
        );
        await legacyDir.create(recursive: true);
        final legacyPhoto = File(p.join(legacyDir.path, '4411.jpg'));
        await legacyPhoto.writeAsString('legacy-bytes');

        final repoAilyans = PhotoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'ailyans',
        );

        // Resolving by regId finds legacy file when not in ByteWave/ailyans/photos
        final resolved = await repoAilyans.resolvePhotoPath(null, stuRegId: 4411);
        expect(resolved, equals(legacyPhoto.path));
        expect(await File(resolved!).readAsString(), equals('legacy-bytes'));

        // Resolving by filename also works
        final resolvedByFilename =
            await repoAilyans.resolvePhotoPath('4411.jpg');
        expect(resolvedByFilename, equals(legacyPhoto.path));

        // When a new photo is saved to ByteWave/ailyans/photos, it takes precedence
        final dummySource = File(p.join(tempDir.path, 'new_source.jpg'));
        await dummySource.writeAsString('new-bytes');
        final newPath = await repoAilyans.copyForStudent(4411, dummySource.path);
        expect(newPath, isNotNull);

        final resolvedNew = await repoAilyans.resolvePhotoPath(null, stuRegId: 4411);
        expect(resolvedNew, equals(newPath));
        expect(await File(resolvedNew!).readAsString(), equals('new-bytes'));
      },
    );

    test(
      '10. Stored absolute path directly resolves if it exists on disk',
      () async {
        final arbitraryDir = Directory(p.join(tempDir.path, 'custom_folder'));
        await arbitraryDir.create(recursive: true);
        final customFile = File(p.join(arbitraryDir.path, 'special.jpg'));
        await customFile.writeAsString('custom-bytes');

        final repoOther = PhotoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'school_x',
        );

        final resolved = await repoOther.resolvePhotoPath(customFile.path);
        expect(resolved, equals(customFile.path));
      },
    );

    test(
      '11. Non-ailyans tenant does not fall back to legacy Documents/Ailyans/photos',
      () async {
        final legacyDir = Directory(
          p.join(tempDir.path, 'Ailyans', 'photos'),
        );
        await legacyDir.create(recursive: true);
        final legacyPhoto = File(p.join(legacyDir.path, '9999.jpg'));
        await legacyPhoto.writeAsString('legacy-bytes');

        final repoClean = PhotoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'clean_school',
        );

        final resolved = await repoClean.resolvePhotoPath(null, stuRegId: 9999);
        expect(resolved, isNull);
      },
    );

    test(
      '12. resolvePhotoFileSync synchronous resolution helper',
      () async {
        final legacyDir = Directory(
          p.join(tempDir.path, 'Ailyans', 'photos'),
        );
        await legacyDir.create(recursive: true);
        final legacyPhoto = File(p.join(legacyDir.path, '7777.jpg'));
        await legacyPhoto.writeAsString('legacy-sync');

        final tenantDir = Directory(
          p.join(tempDir.path, 'ByteWave', 'tenant_sync', 'photos'),
        );
        await tenantDir.create(recursive: true);
        final tenantPhoto = File(p.join(tenantDir.path, '8888_John.jpg'));
        await tenantPhoto.writeAsString('tenant-sync');

        // Direct path match
        expect(
          PhotoRepository.resolvePhotoFileSync(photoPath: tenantPhoto.path)?.path,
          equals(tenantPhoto.path),
        );

        // Tenant lookup by regId
        expect(
          PhotoRepository.resolvePhotoFileSync(
            stuRegId: 8888,
            documentsPath: tempDir.path,
            tenantId: 'tenant_sync',
          )?.path,
          equals(tenantPhoto.path),
        );

        // Legacy fallback for 'ailyans' tenant
        expect(
          PhotoRepository.resolvePhotoFileSync(
            stuRegId: 7777,
            documentsPath: tempDir.path,
            tenantId: 'ailyans',
          )?.path,
          equals(legacyPhoto.path),
        );

        // No fallback for other tenant
        expect(
          PhotoRepository.resolvePhotoFileSync(
            stuRegId: 7777,
            documentsPath: tempDir.path,
            tenantId: 'other_tenant',
          ),
          isNull,
        );
      },
    );
  });
}
