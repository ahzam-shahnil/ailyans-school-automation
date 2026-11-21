import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:school_automation/core/services/update_check_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateCheckService Semver Comparison', () {
    test('1. Semver + build comparison logic', () {
      const installed = '2.0.0+2';

      // Newer build number on same version -> true
      expect(UpdateCheckService.isNewerVersion('2.0.0+3', installed), isTrue);
      expect(UpdateCheckService.isNewerVersion('v2.0.0+3', installed), isTrue);

      // Newer minor version -> true
      expect(UpdateCheckService.isNewerVersion('2.1.0+1', installed), isTrue);
      expect(UpdateCheckService.isNewerVersion('v2.1.0+1', installed), isTrue);

      // Newer major version -> true
      expect(UpdateCheckService.isNewerVersion('3.0.0+1', installed), isTrue);

      // Identical version and build -> false
      expect(UpdateCheckService.isNewerVersion('2.0.0+2', installed), isFalse);
      expect(UpdateCheckService.isNewerVersion('v2.0.0+2', installed), isFalse);

      // Older version -> false
      expect(UpdateCheckService.isNewerVersion('1.9.9+99', installed), isFalse);
      expect(UpdateCheckService.isNewerVersion('v1.9.9+99', installed), isFalse);

      // Older build number on same version -> false
      expect(UpdateCheckService.isNewerVersion('2.0.0+1', installed), isFalse);
    });
  });

  group('UpdateCheckService Manifest Fetching', () {
    const validJson = '''
    {
      "version": "2.1.0",
      "build": 3,
      "tag": "v2.1.0+3",
      "published_at": "2026-11-21T00:00:00Z",
      "notes": "Feature release notes",
      "assets": {
        "windows_clean": "https://github.com/ahzam-shahnil/bytewave-releases/releases/download/v2.1.0+3/bytewave-school-manager-windows.zip",
        "android_clean": "https://github.com/ahzam-shahnil/bytewave-releases/releases/download/v2.1.0+3/bytewave-school-manager.apk"
      }
    }
    ''';

    test('2. Valid latest.json parsing via injected mock http.Client', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.toString(), equals(UpdateCheckService.manifestUrl));
        return http.Response(validJson, 200, headers: {'content-type': 'application/json'});
      });

      final service = UpdateCheckService(client: mockClient);
      final manifest = await service.fetchLatestManifest(connectivity: ConnectivityResult.wifi);

      expect(manifest, isNotNull);
      expect(manifest!.version, equals('2.1.0'));
      expect(manifest.build, equals(3));
      expect(manifest.tag, equals('v2.1.0+3'));
      expect(manifest.notes, equals('Feature release notes'));
      expect(manifest.assets.length, equals(2));
      expect(manifest.assets.containsKey('windows_clean'), isTrue);
      expect(manifest.assets.containsKey('android_clean'), isTrue);
      expect(manifest.assets.containsKey('windows_ailyans'), isFalse);
    });

    test('3. Offline guard skips network request', () async {
      var called = false;
      final mockClient = MockHttpClient((request) async {
        called = true;
        return http.Response(validJson, 200);
      });

      final service = UpdateCheckService(client: mockClient);
      final manifest = await service.fetchLatestManifest(connectivity: ConnectivityResult.none);

      expect(manifest, isNull);
      expect(called, isFalse);
    });

    test('4. Malformed JSON / HTTP 404 / timeout returns null without throwing', () async {
      // 404 Not Found
      final client404 = MockHttpClient((request) async {
        return http.Response('Not Found', 404);
      });
      final service404 = UpdateCheckService(client: client404);
      expect(await service404.fetchLatestManifest(connectivity: ConnectivityResult.wifi), isNull);

      // Malformed JSON
      final clientMalformed = MockHttpClient((request) async {
        return http.Response('{not valid json', 200);
      });
      final serviceMalformed = UpdateCheckService(client: clientMalformed);
      expect(await serviceMalformed.fetchLatestManifest(connectivity: ConnectivityResult.wifi), isNull);

      // Timeout is caught cleanly
      final clientException = MockHttpClient((request) async {
        throw TimeoutException('Timed out');
      });
      final serviceException = UpdateCheckService(client: clientException);
      expect(await serviceException.fetchLatestManifest(connectivity: ConnectivityResult.wifi), isNull);
    });

    test('5. Dismissed tag suppresses banner until a newer tag arrives', () async {
      SharedPreferences.setMockInitialValues({
        UpdateCheckService.dismissedTagKey: 'v2.1.0+3',
      });

      final prefs = await SharedPreferences.getInstance();
      final service = UpdateCheckService(prefs: prefs);

      expect(await service.isTagDismissed('v2.1.0+3'), isTrue);
      expect(await service.isTagDismissed('v2.2.0+1'), isFalse);

      await service.dismissTag('v2.2.0+1');
      expect(await service.isTagDismissed('v2.2.0+1'), isTrue);
    });

    test('6. Ailyans Edition guard returns null immediately without network call', () async {
      var called = false;
      final mockClient = MockHttpClient((request) async {
        called = true;
        return http.Response(validJson, 200);
      });

      final service = UpdateCheckService(
        client: mockClient,
        isAilyansEditionOverride: true,
      );
      final manifest = await service.fetchLatestManifest(
        connectivity: ConnectivityResult.wifi,
      );

      expect(manifest, isNull);
      expect(called, isFalse);
    });

    test('7. resolveDownloadUrl uses clean assets and falls back gracefully', () {
      final manifest = UpdateManifest.fromJson(const {
        'version': '2.1.0',
        'build': 3,
        'tag': 'v2.1.0+3',
        'assets': {
          'windows_clean': 'https://example.com/windows_clean.zip',
          'android_clean': 'https://example.com/android_clean.apk',
        },
      });

      // 1. Windows platform override -> windows_clean URL
      expect(
        UpdateCheckService.resolveDownloadUrl(
          manifest,
          isWindowsOverride: true,
          isAndroidOverride: false,
        ),
        equals('https://example.com/windows_clean.zip'),
      );

      // 2. Android platform override -> android_clean URL
      expect(
        UpdateCheckService.resolveDownloadUrl(
          manifest,
          isWindowsOverride: false,
          isAndroidOverride: true,
        ),
        equals('https://example.com/android_clean.apk'),
      );

      // 3. Other platform fallback -> releases/latest
      expect(
        UpdateCheckService.resolveDownloadUrl(
          manifest,
          isWindowsOverride: false,
          isAndroidOverride: false,
        ),
        equals(UpdateCheckService.fallbackReleaseUrl),
      );
    });
  });
}
