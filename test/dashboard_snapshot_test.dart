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
          builder: (_, __) => const Scaffold(body: DashboardScreen()),
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
    Future<void> openSnapshotDialog(WidgetTester tester) async {
      final snapshotBtnFinder =
          find.byKey(const ValueKey('dashboard_snapshot_button'));
      await tester.tap(snapshotBtnFinder);
      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const ValueKey('snapshot_dialog')).evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 200));
    }

    Future<void> closeSnapshotDialog(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('snapshot_dialog_close')));
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const ValueKey('snapshot_dialog')).evaluate().isEmpty) {
          break;
        }
      }
    }

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
      'T2: tapping dashboard_snapshot_button captures snapshot and opens snapshot_dialog',
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

        // Tap snapshot button to open dialog
        await openSnapshotDialog(tester);

        // Dialog must be open with preview and 4 actions
        expect(find.byKey(const ValueKey('snapshot_dialog')), findsOneWidget);
        expect(find.text('Dashboard Snapshot'), findsOneWidget);
        expect(find.byType(Image), findsWidgets);
        expect(
          find.byKey(const ValueKey('snapshot_dialog_export')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('snapshot_dialog_print')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('snapshot_dialog_share')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('snapshot_dialog_close')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T3: tapping snapshot_dialog_close dismisses the dialog',
      (tester) async {
        await pumpDashboard(tester, const Size(1366, 768));
        await openSnapshotDialog(tester);

        expect(find.byKey(const ValueKey('snapshot_dialog')), findsOneWidget);

        await closeSnapshotDialog(tester);

        expect(find.byKey(const ValueKey('snapshot_dialog')), findsNothing);
      },
    );

    testWidgets(
      'T4: snapshot_dialog renders without overflow and actions contained across viewports',
      (tester) async {
        const viewports = [
          Size(360, 800),
          Size(390, 844),
          Size(414, 896),
          Size(1366, 768),
        ];

        for (final vp in viewports) {
          await pumpDashboard(tester, vp);
          await openSnapshotDialog(tester);

          expect(tester.takeException(), isNull, reason: 'Zero overflow at $vp');

          final dialogFinder = find.byKey(const ValueKey('snapshot_dialog'));
          expect(dialogFinder, findsOneWidget, reason: 'Dialog open at $vp');
          final dialogRect = tester.getRect(dialogFinder);

          for (final key in [
            'snapshot_dialog_export',
            'snapshot_dialog_print',
            'snapshot_dialog_share',
            'snapshot_dialog_close',
          ]) {
            final btnFinder = find.byKey(ValueKey(key));
            expect(btnFinder, findsOneWidget, reason: '$key found at $vp');
            final btnRect = tester.getRect(btnFinder);

            expect(
              btnRect.left >= dialogRect.left - 1.0 &&
                  btnRect.right <= dialogRect.right + 1.0,
              isTrue,
              reason:
                  '$key horizontally contained in dialog at $vp (btn: $btnRect, dialog: $dialogRect)',
            );
          }

          // Close dialog before next iteration
          await closeSnapshotDialog(tester);
          expect(find.byKey(const ValueKey('snapshot_dialog')), findsNothing);
        }
      },
    );
  });
}
