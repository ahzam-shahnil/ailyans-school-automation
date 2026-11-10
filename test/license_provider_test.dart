import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_automation/core/providers/license_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late LicenseNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    notifier = container.read(licenseProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('LicenseNotifier.validateAndStore', () {
    test('TRIAL-BYTE-2026-LAUNCH activates offline without any RPC call',
        () async {
      var rpcCalled = false;
      Future<Map<String, dynamic>?> failValidator(String key) async {
        rpcCalled = true;
        throw StateError('RPC must not be called for the offline trial key');
      }

      final ok = await notifier.validateAndStore(
        'trial-byte-2026-launch',
        rpcValidator: failValidator,
      );

      expect(ok, isTrue);
      expect(rpcCalled, isFalse);
      expect(notifier.lastErrorMessage, isNull);

      final license = container.read(licenseProvider);
      expect(license, isNotNull);
      expect(license!.licenseKey, 'TRIAL-BYTE-2026-LAUNCH');
      expect(license.tier, 'trial');
      expect(license.maxStudents, 100);
      expect(license.isCurrentlyValid, isTrue);

      // Persisted to SharedPreferences for offline relaunch.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bytewave_license'), isNotNull);
    });

    test(
        'Online key activates when the RPC validator returns a valid row, '
        'and reports no error', () async {
      Future<Map<String, dynamic>?> validator(String key) async {
        expect(key, 'TRIAL-BYTE-2026-AILYANS');
        return {
          'valid': true,
          'tier': 'trial',
          'max_students': 100,
          'valid_until': '2026-12-10T00:00:00Z',
          'school_id': 'ailyans',
        };
      }

      final ok = await notifier.validateAndStore(
        'TRIAL-BYTE-2026-AILYANS',
        rpcValidator: validator,
      );

      expect(ok, isTrue);
      expect(notifier.lastErrorMessage, isNull);

      final license = container.read(licenseProvider);
      expect(license, isNotNull);
      expect(license!.licenseKey, 'TRIAL-BYTE-2026-AILYANS');
      expect(license.tier, 'trial');
      expect(license.maxStudents, 100);
      expect(license.validUntil, DateTime.parse('2026-12-10T00:00:00Z'));
      expect(license.isCurrentlyValid, isTrue);
    });

    test('RPC returning null (0 rows) rejects as invalid', () async {
      Future<Map<String, dynamic>?> validator(String key) async => null;

      final ok = await notifier.validateAndStore(
        'UNKNOWN-KEY',
        rpcValidator: validator,
      );

      expect(ok, isFalse);
      expect(notifier.lastErrorMessage, 'Invalid or expired license key.');
      expect(container.read(licenseProvider), isNull);
    });

    test('RPC returning valid:false rejects as invalid', () async {
      Future<Map<String, dynamic>?> validator(String key) async => {
            'valid': false,
            'tier': 'trial',
            'max_students': 100,
            'valid_until': '2026-12-10T00:00:00Z',
          };

      final ok = await notifier.validateAndStore(
        'EXPIRED-KEY',
        rpcValidator: validator,
      );

      expect(ok, isFalse);
      expect(notifier.lastErrorMessage, 'Invalid or expired license key.');
      expect(container.read(licenseProvider), isNull);
    });

    test(
        'Network error on an online-only key rejects cleanly without '
        'activating', () async {
      Future<Map<String, dynamic>?> validator(String key) async {
        throw const SocketExceptionMock();
      }

      final ok = await notifier.validateAndStore(
        'TRIAL-BYTE-2026-AILYANS',
        rpcValidator: validator,
      );

      expect(ok, isFalse);
      expect(
        notifier.lastErrorMessage,
        'Unable to verify license key online. '
        'Please check your internet connection.',
      );
      expect(container.read(licenseProvider), isNull);

      // Nothing persisted — an unverified key must not survive relaunch.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bytewave_license'), isNull);
    });
  });
}

/// Thrown by a fake validator to simulate an unreachable Supabase instance.
class SocketExceptionMock implements Exception {
  const SocketExceptionMock();
}
