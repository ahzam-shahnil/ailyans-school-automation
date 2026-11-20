import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:school_automation/core/providers/app_version_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('appVersionProvider Tests', () {
    test('1. Falls back gracefully to kDefaultAppVersion when platform channel is unmocked', () async {
      PackageInfo.setMockInitialValues(
        appName: 'School Automation',
        packageName: 'com.example.schoolAutomation',
        version: '',
        buildNumber: '',
        buildSignature: '',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final version = await container.read(appVersionProvider.future);
      expect(version, kDefaultAppVersion);
    });

    test('2. Formats version and buildNumber cleanly (vX.Y.Z+B)', () async {
      PackageInfo.setMockInitialValues(
        appName: 'School Automation',
        packageName: 'com.example.schoolAutomation',
        version: '2.0.0',
        buildNumber: '2',
        buildSignature: '',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final version = await container.read(appVersionProvider.future);
      expect(version, 'v2.0.0+2');
    });

    test(
      '3. Formats version without buildNumber if buildNumber is empty',
      () async {
        PackageInfo.setMockInitialValues(
          appName: 'School Automation',
          packageName: 'com.example.schoolAutomation',
          version: '1.5.0',
          buildNumber: '',
          buildSignature: '',
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final version = await container.read(appVersionProvider.future);
        expect(version, 'v1.5.0');
      },
    );
  });
}
