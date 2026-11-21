import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/platform_compat.dart';

void main() {
  group('isLegacyWindows', () {
    test('"Windows 8.1 Pro" 6.3 (Build 9600) -> true', () {
      expect(
        isLegacyWindows(
          versionOverride: '"Windows 8.1 Pro" 6.3 (Build 9600)',
          isWindowsOverride: true,
        ),
        isTrue,
      );
    });

    test('6.3.9600 -> true', () {
      expect(
        isLegacyWindows(
          versionOverride: '6.3.9600',
          isWindowsOverride: true,
        ),
        isTrue,
      );
    });

    test('"Windows 7 Professional" 6.1 (Build 7601) -> true', () {
      expect(
        isLegacyWindows(
          versionOverride: '"Windows 7 Professional" 6.1 (Build 7601)',
          isWindowsOverride: true,
        ),
        isTrue,
      );
    });

    test('"Windows 10 Pro" 10.0 (Build 19045) -> false', () {
      expect(
        isLegacyWindows(
          versionOverride: '"Windows 10 Pro" 10.0 (Build 19045)',
          isWindowsOverride: true,
        ),
        isFalse,
      );
    });

    test('10.0.22621 -> false', () {
      expect(
        isLegacyWindows(
          versionOverride: '10.0.22621',
          isWindowsOverride: true,
        ),
        isFalse,
      );
    });

    test('isWindowsOverride: false -> false', () {
      expect(
        isLegacyWindows(
          versionOverride: '6.3.9600',
          isWindowsOverride: false,
        ),
        isFalse,
      );
    });

    test('garbage -> false', () {
      expect(
        isLegacyWindows(
          versionOverride: 'garbage',
          isWindowsOverride: true,
        ),
        isFalse,
      );
    });

    test('debugIsLegacyWindowsOverride flag works', () {
      addTearDown(() => debugIsLegacyWindowsOverride = null);

      debugIsLegacyWindowsOverride = true;
      expect(isLegacyWindows(), isTrue);

      debugIsLegacyWindowsOverride = false;
      expect(isLegacyWindows(), isFalse);
    });
  });
}
