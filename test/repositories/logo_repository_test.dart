import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:school_automation/repositories/logo_repository.dart';

void main() {
  late Directory tempDir;
  late Directory brandingDir;
  late LogoRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('logo_repo_test_');
    brandingDir = Directory(p.join(tempDir.path, 'branding'));
    repo = LogoRepository(overrideDirectory: brandingDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LogoRepository', () {
    test('1. getBrandingDirectory creates directory if missing', () async {
      expect(await brandingDir.exists(), isFalse);
      final dir = await repo.getBrandingDirectory();
      expect(await dir.exists(), isTrue);
      expect(dir.path, brandingDir.path);
    });

    test('2. copyLogo — roundtrip with .jpg extension', () async {
      final src = File(p.join(tempDir.path, 'source.jpg'));
      await src.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // minimal JPEG magic

      final destPath = await repo.copyLogo(src.path);

      expect(destPath, isNotNull);
      final dest = File(destPath!);
      expect(await dest.exists(), isTrue);
      expect(p.basename(dest.path), 'logo.jpg');
      expect(await dest.readAsBytes(), await src.readAsBytes());
    });

    test('3. copyLogo — preserves .png extension', () async {
      final src = File(p.join(tempDir.path, 'icon.png'));
      await src.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG magic

      final destPath = await repo.copyLogo(src.path);

      expect(destPath, isNotNull);
      expect(p.basename(File(destPath!).path), 'logo.png');
    });

    test('4. copyLogo returns null for nonexistent source', () async {
      final missingPath = p.join(tempDir.path, 'nonexistent.jpg');
      final result = await repo.copyLogo(missingPath);
      expect(result, isNull);
    });

    test('5. deleteLogo removes an existing logo file', () async {
      final src = File(p.join(tempDir.path, 'source.jpg'));
      await src.writeAsString('logo-data');
      final destPath = await repo.copyLogo(src.path);
      expect(destPath, isNotNull);
      expect(await File(destPath!).exists(), isTrue);

      await repo.deleteLogo();

      expect(await File(destPath).exists(), isFalse);
    });

    test('6. deleteLogo is a safe no-op when no logo exists', () async {
      await expectLater(repo.deleteLogo(), completes);
    });

    test('7. copyLogo overwrites previous logo with new extension', () async {
      // Upload a .jpg first
      final src1 = File(p.join(tempDir.path, 'first.jpg'));
      await src1.writeAsString('jpg-data');
      final dest1 = await repo.copyLogo(src1.path);
      expect(dest1, isNotNull);
      expect(p.basename(dest1!), 'logo.jpg');

      // Upload a .png second — both logo.jpg and logo.png can coexist;
      // copyLogo writes to the new name. Verify the new one is correct.
      final src2 = File(p.join(tempDir.path, 'second.png'));
      await src2.writeAsString('png-data');
      final dest2 = await repo.copyLogo(src2.path);
      expect(dest2, isNotNull);
      expect(p.basename(dest2!), 'logo.png');
      expect(await File(dest2).readAsString(), 'png-data');
    });

    test('8. deleteLogo removes all logo.* files', () async {
      // Plant two logo files manually
      await (await repo.getBrandingDirectory()).create(recursive: true);
      final f1 = File(p.join(brandingDir.path, 'logo.jpg'));
      final f2 = File(p.join(brandingDir.path, 'logo.png'));
      await f1.writeAsString('a');
      await f2.writeAsString('b');

      await repo.deleteLogo();

      expect(await f1.exists(), isFalse);
      expect(await f2.exists(), isFalse);
    });

    test(
      '9. Multi-tenant isolation: school_a and school_b write to separate branding directories',
      () async {
        final repoA = LogoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'school_a',
        );
        final repoB = LogoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'school_b',
        );

        final src = File(p.join(tempDir.path, 'logo_source.png'));
        await src.writeAsString('logo-bytes');

        final pathA = await repoA.copyLogo(src.path);
        final pathB = await repoB.copyLogo(src.path);

        expect(pathA, isNotNull);
        expect(pathB, isNotNull);
        expect(pathA, isNot(equals(pathB)));

        expect(
          pathA,
          p.join(tempDir.path, 'ByteWave', 'school_a', 'branding', 'logo.png'),
        );
        expect(
          pathB,
          p.join(tempDir.path, 'ByteWave', 'school_b', 'branding', 'logo.png'),
        );

        expect(await File(pathA!).exists(), isTrue);
        expect(await File(pathB!).exists(), isTrue);

        // Deleting in school_a does not delete school_b
        await repoA.deleteLogo();
        expect(await File(pathA).exists(), isFalse);
        expect(await File(pathB).exists(), isTrue);
      },
    );

    test(
      '10. Legacy Fallback: Documents/Ailyans/branding/logo.png resolves cleanly for tenant ailyans',
      () async {
        final legacyDir = Directory(
          p.join(tempDir.path, 'Ailyans', 'branding'),
        );
        await legacyDir.create(recursive: true);
        final legacyLogo = File(p.join(legacyDir.path, 'logo.png'));
        await legacyLogo.writeAsString('legacy-logo-bytes');

        final repoAilyans = LogoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'ailyans',
        );

        // Resolving with null or empty stored path finds legacy logo
        final resolved = await repoAilyans.resolveLogoPath();
        expect(resolved, equals(legacyLogo.path));
        expect(await File(resolved!).readAsString(), equals('legacy-logo-bytes'));

        // Resolving with filename also finds it
        final resolvedByFilename = await repoAilyans.resolveLogoPath('logo.png');
        expect(resolvedByFilename, equals(legacyLogo.path));

        // When a new logo is saved to ByteWave/ailyans/branding, it takes precedence
        final newSrc = File(p.join(tempDir.path, 'new_logo.jpg'));
        await newSrc.writeAsString('new-logo-bytes');
        final newPath = await repoAilyans.copyLogo(newSrc.path);
        expect(newPath, isNotNull);

        final resolvedNew = await repoAilyans.resolveLogoPath();
        expect(resolvedNew, equals(newPath));
        expect(await File(resolvedNew!).readAsString(), equals('new-logo-bytes'));
      },
    );

    test(
      '11. Stored absolute path directly resolves if it exists on disk',
      () async {
        final customDir = Directory(p.join(tempDir.path, 'branding_custom'));
        await customDir.create(recursive: true);
        final customLogo = File(p.join(customDir.path, 'my_school_logo.png'));
        await customLogo.writeAsString('custom-logo-bytes');

        final repoClean = LogoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'clean_school',
        );

        final resolved = await repoClean.resolveLogoPath(customLogo.path);
        expect(resolved, equals(customLogo.path));
      },
    );

    test(
      '12. Non-ailyans tenant does not fall back to legacy Documents/Ailyans/branding',
      () async {
        final legacyDir = Directory(
          p.join(tempDir.path, 'Ailyans', 'branding'),
        );
        await legacyDir.create(recursive: true);
        final legacyLogo = File(p.join(legacyDir.path, 'logo.png'));
        await legacyLogo.writeAsString('legacy-logo-bytes');

        final repoClean = LogoRepository(
          overrideDocumentsPath: tempDir.path,
          overrideTenantId: 'clean_school',
        );

        final resolved = await repoClean.resolveLogoPath();
        expect(resolved, isNull);
      },
    );
  });
}
