import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/providers/dashboard_metrics_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/screens/dashboard/dashboard_screen.dart';

void main() {
  const testMetrics = DashboardMetrics(
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

  const testShellMeta = ShellMetadata(
    branchName: "Ailyans's Higher Secondary School Mianwali",
    branchAddress: 'Muslim Bazar Mianwali',
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
          path: '/students/new',
          builder: (_, __) => const Scaffold(body: Text('Students New')),
        ),
        GoRoute(
          path: '/fees/receipts',
          builder: (_, __) => const Scaffold(body: Text('Receipts')),
        ),
        GoRoute(
          path: '/attendance',
          builder: (_, __) => const Scaffold(body: Text('Attendance')),
        ),
        GoRoute(
          path: '/fees/vouchers',
          builder: (_, __) => const Scaffold(body: Text('Vouchers')),
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
          path: '/exams/marks',
          builder: (_, __) => const Scaffold(body: Text('Marks')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardMetricsProvider.overrideWith((ref) => Future.value(testMetrics)),
          shellMetadataProvider.overrideWith((ref) => Future.value(testShellMeta)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Phase K-6 Run 9 — Dashboard Snapshot Capture & Share Tests', () {
    testWidgets(
      'T1: snapshot button is present and contained inside header bar across viewports',
      (tester) async {
        const viewports = [
          Size(360, 800),
          Size(390, 844),
          Size(414, 896),
          Size(1366, 768),
        ];

        for (final vp in viewports) {
          await pumpDashboard(tester, vp);

          expect(tester.takeException(), isNull, reason: 'Zero overflow at $vp');

          final snapshotBtnFinder =
              find.byKey(const ValueKey('dashboard_snapshot_button'));
          expect(snapshotBtnFinder, findsOneWidget,
              reason: 'Snapshot button present at $vp');

          final headerFinder =
              find.byKey(const ValueKey('dashboard_header_bar'));
          expect(headerFinder, findsOneWidget,
              reason: 'Header bar present at $vp');

          final refreshFinder = find.byIcon(Icons.refresh);
          expect(refreshFinder, findsOneWidget,
              reason: 'Refresh button intact at $vp');

          final btnRect = tester.getRect(snapshotBtnFinder);
          final headerRect = tester.getRect(headerFinder);

          expect(headerRect.contains(btnRect.topLeft), isTrue,
              reason:
                  'Button topLeft within header at $vp (btn: $btnRect, header: $headerRect)');
          expect(headerRect.contains(btnRect.bottomRight), isTrue,
              reason:
                  'Button bottomRight within header at $vp (btn: $btnRect, header: $headerRect)');
        }
      },
    );

    testWidgets(
      'T2: RepaintBoundary capture yields valid non-empty PNG bytes with PNG magic header',
      (tester) async {
        await pumpDashboard(tester, const Size(1366, 768));
        expect(tester.takeException(), isNull);

        final boundaryFinder = find.descendant(
          of: find.byKey(const ValueKey('dashboard_snapshot_boundary')),
          matching: find.byType(RepaintBoundary),
        ).first;
        expect(boundaryFinder, findsOneWidget);

        final ro = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
        final bytes = await tester.runAsync(() async {
          final img = await ro.toImage(pixelRatio: 2.0);
          try {
            final bd = await img.toByteData(format: ui.ImageByteFormat.png);
            return bd?.buffer.asUint8List();
          } finally {
            img.dispose();
          }
        });

        expect(bytes, isNotNull);
        expect(bytes!.length, greaterThan(8));
        // PNG magic signature: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A (\x89PNG\r\n\x1a\n)
        expect(
          bytes.sublist(0, 8),
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        );
      },
    );
  });
}
