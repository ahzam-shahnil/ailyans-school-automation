import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';

void main() {
  testWidgets(
    'AppShell renders sidebar with all 8 navigation groups, top bar, and status bar',
    (WidgetTester tester) async {
      // Configure desktop viewport constraints (1440x900)
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const testUser = User(
        id: 1,
        name: 'Wazahat Raza Zaidi',
        designation: 'Director',
        password: 'hash',
        userLevel: 1,
        isActive: true,
      );

      // 25 allowed module IDs for Director
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

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) =>
                    const Center(child: Text('Dashboard Content Canvas')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) {
              final notifier = SessionNotifier();
              notifier.setSession(testUser, allowedObjIds);
              return notifier;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify brand title
      expect(find.text('Ailyans School'), findsOneWidget);
      expect(find.text('Automation v2.0'), findsOneWidget);

      // 2. Verify all 8 navigation groups exist in sidebar
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Academics'), findsOneWidget);
      expect(find.text('Fees & Billing'), findsOneWidget);
      expect(find.text('Examinations'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Staff & Payroll'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);

      // 3. Verify footer system settings
      expect(find.text('System Settings'), findsOneWidget);

      // 4. Verify Top Bar elements
      expect(find.text('Search students, staff, vouchers...'), findsOneWidget);
      expect(find.text('Ctrl+K'), findsOneWidget);
      expect(find.text('WZ'), findsOneWidget);

      // 5. Verify Status Bar elements
      expect(find.text('DB: SDB_Ailyans.db (Online)'), findsOneWidget);
      expect(find.text('? Shortcuts'), findsOneWidget);
    },
  );
}
