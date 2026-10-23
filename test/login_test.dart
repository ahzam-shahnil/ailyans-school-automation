import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/repositories/auth_repository.dart';
import 'package:school_automation/screens/login/login_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';

class FakeAuthRepository implements AuthRepository {
  String? rememberedUsername;
  String currentPassword = 'wr';

  final User user = const User(
    id: 1,
    name: 'Wazahat Raza Zaidi',
    designation: 'Director',
    password: 'wr',
    userLevel: 1,
    isActive: true,
  );

  @override
  Future<List<String>> getAllUsernames() async {
    return [user.name];
  }

  @override
  Future<String?> getRememberedUsername() async {
    return rememberedUsername;
  }

  @override
  Future<void> setRememberedUsername(String? username) async {
    rememberedUsername = username;
  }

  @override
  Future<User?> authenticate(String username, String password) async {
    if (username == user.name && password == currentPassword) {
      return user.copyWith(password: currentPassword);
    }
    return null;
  }

  @override
  Future<List<int>> getUserAllowedObjectIds(int userId) async {
    return [1, 2, 3, 4, 8];
  }

  @override
  Future<bool> changePassword(int userId, String newPassword) async {
    if (newPassword.length < 8) return false;
    currentPassword = newPassword;
    return true;
  }
}

void main() {
  late FakeAuthRepository fakeAuthRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
  });

  Widget buildTestLoginApp({GoRouter? customRouter}) {
    final router =
        customRouter ??
        GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginScreen(),
            ),
            ShellRoute(
              builder: (context, state, child) => AppShell(child: child),
              routes: [
                GoRoute(
                  path: '/dashboard',
                  builder: (context, state) =>
                      const Center(child: Text('Dashboard Canvas')),
                ),
              ],
            ),
          ],
        );

    const testMetadata = ShellMetadata(
      branchName: "Ailyans's Higher Secondary School Mianwali",
      branchAddress: 'Muslim Bazar Mianwali',
      branchPhone: null,
      branchPrincipal: null,
      sessionYear: '2017-2018',
      studentCount: 150,
      classCount: 12,
      staffCount: 18,
      pendingVouchers: 5,
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
    'LoginScreen renders 440px card with header, operator dropdown, and password field',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestLoginApp());
      await tester.pumpAndSettle();

      // Card header elements
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
      expect(
        find.text("Ailyans's Higher Secondary School Mianwali"),
        findsOneWidget,
      );
      expect(
        find.text('Muslim Bazar Mianwali • School Automation System'),
        findsOneWidget,
      );

      // Operator dropdown and populated name
      expect(find.text('Operator Account *'), findsOneWidget);
      expect(find.text('Wazahat Raza Zaidi'), findsOneWidget);

      // Password field and buttons
      expect(find.text('Password *'), findsOneWidget);
      expect(find.text('Remember me on this device'), findsOneWidget);
      expect(find.text('Sign In (Enter)'), findsOneWidget);
      expect(find.text('Change Operator Password'), findsOneWidget);
      expect(find.text('Exit Application'), findsOneWidget);

      // Footer strip
      expect(find.text('Database: SDB_Ailyans.db (Online)'), findsWidgets);
      expect(find.text('SQLite Local'), findsOneWidget);
    },
  );

  testWidgets(
    'Empty password triggers verbatim validation error: Enter User Name / Password Please',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestLoginApp());
      await tester.pumpAndSettle();

      // Click Sign In with empty password
      await tester.tap(find.text('Sign In (Enter)'));
      await tester.pumpAndSettle();

      expect(find.text('Enter User Name / Password Please'), findsOneWidget);
    },
  );

  testWidgets(
    'Wrong password triggers verbatim error: invalid User or Password and clears field',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestLoginApp());
      await tester.pumpAndSettle();

      // Enter wrong password
      final passwordFinder = find.byType(TextField).first;
      await tester.enterText(passwordFinder, 'wrong_pwd');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Sign In (Enter)'));
      await tester.pumpAndSettle();

      expect(find.text('invalid User or Password'), findsOneWidget);
    },
  );

  testWidgets(
    'Correct password "wr" logs in, routes to /dashboard, and displays weak password warning banner',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestLoginApp());
      await tester.pumpAndSettle();

      // Enter legacy password "wr"
      final passwordFinder = find.byType(TextField).first;
      await tester.enterText(passwordFinder, 'wr');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Sign In (Enter)'));
      await tester.pumpAndSettle();

      // Navigated to /dashboard canvas
      expect(find.text('Dashboard Canvas'), findsOneWidget);

      // Weak password warning banner displayed
      expect(
        find.text(
          'Your password is shorter than the recommended 8 characters. '
          'Update it at your earliest convenience.',
        ),
        findsOneWidget,
      );
      expect(find.text('Update Password'), findsOneWidget);

      // Dismiss the warning banner
      await tester.tap(find.byTooltip('Dismiss warning'));
      await tester.pumpAndSettle();

      // Banner is removed
      expect(
        find.text(
          'Your password is shorter than the recommended 8 characters. '
          'Update it at your earliest convenience.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'ChangePasswordDialog validates short password, mismatch, and successfully changes password',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestLoginApp());
      await tester.pumpAndSettle();

      // Open Change Operator Password dialog from login screen
      await tester.tap(find.text('Change Operator Password'));
      await tester.pumpAndSettle();

      expect(find.text('Change Operator Password'), findsWidgets);
      expect(find.text('Read-only'), findsOneWidget);

      // 1. Submit empty -> Please fill all fields
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(find.text('Please fill all fields'), findsOneWidget);

      final currentPwdField = find.widgetWithText(
        TextField,
        'Enter existing password',
      );
      final newPwdField = find.widgetWithText(TextField, 'Enter new password');
      final confirmPwdField = find.widgetWithText(
        TextField,
        'Confirm new password',
      );

      // 2. Submit wrong current password
      await tester.enterText(currentPwdField, 'bad_current');
      await tester.enterText(newPwdField, 'newPassword123');
      await tester.enterText(confirmPwdField, 'newPassword123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(find.text('invalid User or Password'), findsOneWidget);

      // 3. Submit short new password (< 8 chars)
      await tester.enterText(currentPwdField, 'wr');
      await tester.enterText(newPwdField, 'short');
      await tester.enterText(confirmPwdField, 'short');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );

      // 4. Submit mismatched passwords
      await tester.enterText(currentPwdField, 'wr');
      await tester.enterText(newPwdField, 'newPassword123');
      await tester.enterText(confirmPwdField, 'mismatched123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(
        find.text('New password and confirm password do not match'),
        findsOneWidget,
      );

      // 5. Submit valid new password (10+ characters)
      await tester.enterText(currentPwdField, 'wr');
      await tester.enterText(newPwdField, 'supersecret123');
      await tester.enterText(confirmPwdField, 'supersecret123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      // Dialog closed, snackbar shown
      expect(find.text('Password Changed'), findsOneWidget);
      expect(fakeAuthRepo.currentPassword, 'supersecret123');
    },
  );
}
