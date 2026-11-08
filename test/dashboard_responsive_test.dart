import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/providers/dashboard_metrics_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/screens/dashboard/dashboard_screen.dart';

/// Guards the dashboard's fluid layout: KPI and action grids reflow
/// 4 → 2 → 1, the lower workspace stacks on narrow windows, nothing overflows,
/// and the two-pane split is draggable on wide ones.
void main() {
  const metrics = DashboardMetrics(
    attendancePercent: 80.0,
    presentCount: 8,
    absentCount: 1,
    leaveCount: 1,
    totalStudents: 10,
    monthlyCollected: 10800,
    monthlyExpected: 30000,
    collectionPace: 36,
    activeEnrollment: 10,
    classCount: 13,
    sectionCount: 26,
    pendingVouchers: 9,
    outstandingAmount: 19200,
    recentPayments: [
      RecentPaymentItem(
        submissionDate: '2017-10-20 11:05:00',
        voucherNo: '1710-4420',
        paidAmount: 1800,
        stuRegId: 4420,
        studentName: 'Hassan Akbar',
      ),
    ],
    classStrength: [
      ClassStrengthItem(
        className: 'Class 10-A',
        enrolled: 10,
        unpaid: 9,
        outstanding: 19200,
      ),
    ],
  );

  const shellMeta = ShellMetadata(
    branchName: 'Ailyans',
    branchAddress: 'Mianwali',
    branchPhone: null,
    branchPrincipal: null,
    sessionYear: '2017-2018',
    studentCount: 10,
    classCount: 13,
    staffCount: 5,
    pendingVouchers: 9,
  );

  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/students',
          builder: (_, __) => const Scaffold(body: Text('Students')),
        ),
        GoRoute(
          path: '/fees/ledger',
          builder: (_, __) => const Scaffold(body: Text('Ledger')),
        ),
        GoRoute(
          path: '/attendance',
          builder: (_, __) => const Scaffold(body: Text('Attendance')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardMetricsProvider.overrideWith((ref) => Future.value(metrics)),
          shellMetadataProvider.overrideWith((ref) => Future.value(shellMeta)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  double labelTop(WidgetTester tester, String label) =>
      tester.getTopLeft(find.text(label)).dy;

  testWidgets('reflows without overflow from desktop to phone widths', (
    tester,
  ) async {
    const sizes = [
      Size(1600, 1000),
      Size(1440, 900),
      Size(1100, 800),
      Size(980, 700),
      Size(900, 900),
      Size(760, 600),
      Size(600, 800),
      Size(480, 800),
      Size(390, 844),
    ];

    for (final size in sizes) {
      await pumpDashboard(tester, size);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Dashboard overflowed at ${size.width}x${size.height}',
      );
    }
  });

  testWidgets(
    'KPI grid adheres to Stitch 3-tier breakpoint grid (Desktop 3x2, Tablet 2x3, Mobile 2x2+2)',
    (tester) async {
      const card1 = 'ACTIVE ENROLLMENT';
      const card2 = "TODAY'S COLLECTION";
      const card3 = 'MONTHLY FEE COLLECTION';
      const card4 = 'PENDING VOUCHERS';
      const card5 = "TODAY'S ATTENDANCE";
      const card6 = 'ACADEMIC FACULTY';

      // 1. Desktop (>= 1024px): 3 columns x 2 rows
      await pumpDashboard(tester, const Size(1440, 900));
      expect(labelTop(tester, card1), closeTo(labelTop(tester, card3), 10.0));
      expect(labelTop(tester, card4), closeTo(labelTop(tester, card5), 10.0));
      expect(labelTop(tester, card4), closeTo(labelTop(tester, card6), 10.0));
      expect(labelTop(tester, card4), greaterThan(labelTop(tester, card1) + 40));

      // 2. Tablet (600..1023px): 2 columns x 3 rows
      await pumpDashboard(tester, const Size(900, 900));
      expect(labelTop(tester, card1), closeTo(labelTop(tester, card2), 10.0));
      expect(labelTop(tester, card3), greaterThan(labelTop(tester, card1) + 40));
      expect(labelTop(tester, card3), closeTo(labelTop(tester, card4), 10.0));
      expect(labelTop(tester, card5), greaterThan(labelTop(tester, card3) + 40));
      expect(labelTop(tester, card5), closeTo(labelTop(tester, card6), 10.0));

      // 3. Mobile (< 600px): 2x2 grid (cards 1-4) + full-width card5 + full-width card6
      await pumpDashboard(tester, const Size(390, 844));
      expect(labelTop(tester, card1), closeTo(labelTop(tester, card2), 10.0));
      expect(labelTop(tester, card3), greaterThan(labelTop(tester, card1) + 40));
      expect(labelTop(tester, card3), closeTo(labelTop(tester, card4), 10.0));
      expect(labelTop(tester, card5), greaterThan(labelTop(tester, card3) + 40));
      expect(labelTop(tester, card6), greaterThan(labelTop(tester, card5) + 40));
    },
  );

  testWidgets('lower workspace split drags and resets', (tester) async {
    await pumpDashboard(tester, const Size(1440, 1000));

    final handle = find.byKey(const ValueKey('dashboard-split-handle'));
    expect(handle, findsOneWidget);

    final start = tester.getCenter(handle).dx;
    await tester.drag(handle, const Offset(90, 0));
    await tester.pump();

    final moved = tester.getCenter(handle).dx;
    expect(moved, greaterThan(start + 40));

    // Double-click resets to the default 60/40 split.
    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getCenter(handle).dx, lessThan(moved));
  });
}
