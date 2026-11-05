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

  testWidgets('KPI grid collapses 4 → 2 → 1 columns', (tester) async {
    const first = "TODAY'S ATTENDANCE";
    const second = 'MONTHLY FEE COLLECTION';
    const third = 'ACTIVE ENROLLMENT';
    const fourth = 'PENDING VOUCHERS';

    await pumpDashboard(tester, const Size(1440, 900));
    expect(labelTop(tester, first), labelTop(tester, fourth));

    await pumpDashboard(tester, const Size(900, 900));
    expect(labelTop(tester, first), labelTop(tester, second));
    expect(labelTop(tester, third), greaterThan(labelTop(tester, first)));
    expect(labelTop(tester, third), labelTop(tester, fourth));

    await pumpDashboard(tester, const Size(600, 900));
    expect(labelTop(tester, second), greaterThan(labelTop(tester, first)));
    expect(labelTop(tester, third), greaterThan(labelTop(tester, second)));
    expect(labelTop(tester, fourth), greaterThan(labelTop(tester, third)));
  });

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
