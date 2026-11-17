// Phase K-6 Run 1 — Item 3: reports modal explicit close + barrier dismiss.
//
// Test A: open modal → tap the top-right close IconButton → dismissed.
//         Re-open → tapAt on the barrier (outside click) → dismissed.
// Plus the Argon Rule 14 render sweep at 360x800, 390x844, 414x896.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';

// Stub bytes builder — no real PDF environment, no binary inspection.
ReportRequest _stubRequest() => ReportRequest(
  type: ReportType.classCollectionSummary,
  titleOverride: 'Dismiss Test Report',
  customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
);

Future<void> _pumpHost(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    ReportPreviewModal.show(ctx, request: _stubRequest()),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openModal(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  // Route transition frame + provider generate() microtasks + bytes frame,
  // then flush the viewer's internal raster debounce timer.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpDismissed(WidgetTester tester) async {
  // Pop + route exit animation, then let any pending timers expire.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Test A1: tapping the fixed top-right close button dismisses the modal',
    (tester) async {
      await _pumpHost(tester, const Size(1440, 900));
      await _openModal(tester);

      expect(find.byType(ReportPreviewModal), findsOneWidget);
      // The close button must be present and OUTSIDE the toolbar's
      // horizontal scroll viewport (always visible, never clipped).
      expect(
        find.byKey(const ValueKey('report_toolbar_close')),
        findsOneWidget,
      );
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('report_toolbar_close')));
      await _pumpDismissed(tester);

      expect(find.byType(ReportPreviewModal), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Test A2: tapping the barrier (outside click) dismisses the modal',
    (tester) async {
      await _pumpHost(tester, const Size(1440, 900));
      await _openModal(tester);

      expect(find.byType(ReportPreviewModal), findsOneWidget);

      // (10, 10) lies on the barrier strip outside the 92% dialog at this
      // desktop viewport size.
      await tester.tapAt(const Offset(10, 10));
      await _pumpDismissed(tester);

      expect(find.byType(ReportPreviewModal), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ESC key still dismisses the modal (CallbackShortcuts)', (
    tester,
  ) async {
    await _pumpHost(tester, const Size(1440, 900));
    await _openModal(tester);

    expect(find.byType(ReportPreviewModal), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pumpDismissed(tester);

    expect(find.byType(ReportPreviewModal), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Argon Rule 14: the modal (with the new trailing close button) must render
  // without exception at all three mobile portrait sizes.
  for (final size in const [
    Size(360, 800),
    Size(390, 844),
    Size(414, 896),
  ]) {
    testWidgets('modal renders without exception at '
        '${size.width.round()}x${size.height.round()}', (tester) async {
      await _pumpHost(tester, size);
      await _openModal(tester);

      expect(find.byType(ReportPreviewModal), findsOneWidget);
      // Mobile toolbar: exactly one Close affordance, top-right trailing.
      expect(find.byTooltip('Close'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }
}
