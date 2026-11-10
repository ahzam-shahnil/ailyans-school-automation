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

  /// G-9.10: router with real shell sub-routes for drawer navigation
  /// regression tests (marker screens assert actual navigation happened).
  GoRouter shellDrawerRouter() {
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
            GoRoute(
              path: '/attendance',
              builder: (context, state) => const SizedBox.expand(
                child: Text('ATTENDANCE_SCREEN_MARKER'),
              ),
            ),
            GoRoute(
              path: '/fees/ledger',
              builder: (context, state) => const SizedBox.expand(
                child: Text('LEDGER_SCREEN_MARKER'),
              ),
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

  Future<void> pumpShellWith(WidgetTester tester, Size size, GoRouter router) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      withProviders(MaterialApp.router(routerConfig: router)),
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

  testWidgets(
    'G-9.10 Mobile 390x844 tapping single-screen drawer item (Attendance) closes drawer and navigates to target screen',
    (tester) async {
      await pumpShellWith(tester, const Size(390, 844), shellDrawerRouter());

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.byType(MobileDrawer), findsOneWidget);

      // 'Attendance' also exists in the MobileBottomNav, so scope the finder
      // to the drawer's AppSidebar instance.
      final attendanceItem = find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Attendance'),
      );
      expect(attendanceItem, findsOneWidget);
      await tester.tap(attendanceItem);
      await tester.pumpAndSettle();

      // Drawer is closed.
      final scaffoldState = tester.state<ScaffoldState>(
        find.byType(Scaffold).first,
      );
      expect(scaffoldState.isDrawerOpen, isFalse);

      // Router actually navigated to and rendered /attendance.
      expect(find.text('ATTENDANCE_SCREEN_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'G-9.10 Mobile 390x844 expanding Fees module group and tapping Fee Ledger sub-item closes drawer and navigates',
    (tester) async {
      await pumpShellWith(tester, const Size(390, 844), shellDrawerRouter());

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.byType(MobileDrawer), findsOneWidget);

      // Group header only expands the sub-items (does NOT navigate/close).
      await tester.tap(
        find.descendant(
          of: find.byType(AppSidebar),
          matching: find.text('Fees & Billing'),
        ),
      );
      await tester.pumpAndSettle();
      // Drawer stayed open and no navigation happened — the header only
      // expanded its sub-items.
      final scaffoldAfterExpand = tester.state<ScaffoldState>(
        find.byType(Scaffold).first,
      );
      expect(scaffoldAfterExpand.isDrawerOpen, isTrue);
      expect(find.text('LEDGER_SCREEN_MARKER'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MobileDrawer),
          matching: find.text('Fee Ledger'),
        ),
        findsOneWidget,
      );

      // Leaf sub-item navigates.
      await tester.tap(
        find.descendant(
          of: find.byType(MobileDrawer),
          matching: find.text('Fee Ledger'),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldState = tester.state<ScaffoldState>(
        find.byType(Scaffold).first,
      );
      expect(scaffoldState.isDrawerOpen, isFalse);
      expect(find.text('LEDGER_SCREEN_MARKER'), findsOneWidget);
    },
  );
}
