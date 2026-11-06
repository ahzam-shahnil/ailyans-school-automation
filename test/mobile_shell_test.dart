import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/widgets/shell/app_sidebar.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
import 'package:school_automation/widgets/shell/mobile_bottom_nav.dart';

void main() {
  const testUser = User(
    id: 1,
    name: 'Wazahat Raza Zaidi',
    designation: 'Director',
    password: 'hash',
    userLevel: 1,
    isActive: true,
  );

  const allowedObjIds = [
    1,
    2,
    3,
    4,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    28,
    29,
  ];

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

  const navLabels = [
    'Dashboard',
    'Students',
    'Academics',
    'Fees & Billing',
    'Examinations',
    'Attendance',
    'Staff & Payroll',
    'Library',
  ];

  ProviderScope withProviders(Widget child) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) {
          final notifier = SessionNotifier();
          notifier.setSession(testUser, allowedObjIds);
          return notifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: child,
    );
  }

  GoRouter shellRouter() {
    return GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const SizedBox.expand(),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      withProviders(MaterialApp.router(routerConfig: shellRouter())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Desktop 1440x900 renders AppSidebar with all 8 navigation items and no BottomNavigationBar',
    (tester) async {
      await pumpShell(tester, const Size(1440, 900));

      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(MobileBottomNav), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);

      for (final label in navLabels) {
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Mobile 390x844 renders MobileBottomNav with 4 tabs (Home, Students, Fees, Attendance) and hides fixed AppSidebar',
    (tester) async {
      await pumpShell(tester, const Size(390, 844));

      expect(find.byType(MobileBottomNav), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(AppSidebar), findsNothing);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
    },
  );

  testWidgets(
    'Mobile 390x844 renders AppShell with SizedBox child with zero RenderFlex overflow (tester.takeException() isNull)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        withProviders(
          const MaterialApp(home: AppShell(child: SizedBox.expand())),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Mobile 390x844 tapping hamburger menu icon opens MobileDrawer displaying all 8 navigation modules',
    (tester) async {
      await pumpShell(tester, const Size(390, 844));

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.byType(MobileDrawer), findsOneWidget);
      final drawerSidebar = find.byType(AppSidebar);
      expect(drawerSidebar, findsOneWidget);

      for (final label in navLabels) {
        expect(
          find.descendant(of: drawerSidebar, matching: find.text(label)),
          findsOneWidget,
        );
      }
    },
  );
}
