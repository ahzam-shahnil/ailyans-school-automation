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
  });
}
