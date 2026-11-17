// Phase K-6 Run 1 — Item 1: orientation toggle re-renders on the first click.
//
// Test B uses a sentinel builder that records every PdfPageFormat the bytes
// generation is invoked with (no PDF binary inspection). The provider family
// is keyed on ReportPreviewKey(request, pageFormat, feeVoucherMode), so the
// orientation is an EXPLICIT argument of the bytes generation: one toggle
// click rotates to a fresh notifier whose bytes are generated for the new
// orientation immediately.
//
// Also asserts the K-3b-fix non-regression (commit 86d70b8): a report's
// natural orientation still comes from its `naturalPageFormat` (the builder
// receives null = natural passthrough on the initial generation), and is NOT
// defaulted to portrait.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';

/// Sentinel-based format-aware stub request.
ReportRequest _request({
  required PdfPageFormat naturalPageFormat,
  required List<PdfPageFormat?> formatsUsed,
}) {
  return ReportRequest(
    type: ReportType.classCollectionSummary,
    titleOverride: 'Orientation Toggle Test',
    naturalPageFormat: naturalPageFormat,
    customBytesBuilderWithFormat: (pageFormat) async {
      formatsUsed.add(pageFormat);
      // Fresh Uint8List instance per generation so the viewer's ValueKey
      // (bytes identity) rotates on every re-render.
      return Uint8List.fromList([
        0x25,
        0x50,
        0x44,
        0x46,
        formatsUsed.length,
      ]);
    },
  );
}

Future<void> _pumpHost(WidgetTester tester, ReportRequest request) async {
  // Desktop viewport: the orientation toggle lives on the desktop toolbar.
  tester.view.physicalSize = const Size(1440, 900);
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
                onPressed: () => ReportPreviewModal.show(ctx, request: request),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Flushes one orientation-toggle click: loading frame → bytes frame →
/// viewer raster debounce.
Future<void> _pumpAfterToggle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

Uint8List? _viewerBytes(WidgetTester tester) {
  final widget = tester.widget<PdfPreview>(find.byType(PdfPreview));
  return (widget.key as ValueKey<Uint8List?>).value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Test B: portrait-natural report — ONE toggle click re-resolves bytes '
    'keyed on the new orientation',
    (tester) async {
      final formatsUsed = <PdfPageFormat?>[];
      await _pumpHost(
        tester,
        _request(
          naturalPageFormat: PdfPageFormat.a4,
          formatsUsed: formatsUsed,
        ),
      );

      // Initial generation: exactly one call, with NO override — the natural
      // portrait format passthrough (K-3b contract).
      expect(formatsUsed.length, 1, reason: 'one generation on open');
      expect(formatsUsed.single, isNull, reason: 'natural passthrough');

      // Toggle initializes to the report's natural (portrait) orientation.
      // NB: find.byType(SegmentedButton) matches the exact generic
      // runtimeType, so use a predicate finder for the private-enum widget.
      final segmented = tester.widget(
            find.byWidgetPredicate((w) => w is SegmentedButton),
          )
          as SegmentedButton;
      // The segment value type is the modal's private enum; assert via its
      // runtime toString.
      expect(
        segmented.selected.single.toString(),
        contains('portrait'),
        reason: 'portrait-natural report opens portrait',
      );

      final bytesBefore = _viewerBytes(tester);

      // --- ONE click on the Landscape segment -----------------------------
      await tester.tap(find.text('Landscape'));
      await _pumpAfterToggle(tester);

      // Bytes generation ran again immediately, explicitly keyed on the
      // landscape format.
      expect(
        formatsUsed.length,
        2,
        reason: 'orientation toggle must regenerate bytes on the first click',
      );
      final landscape = formatsUsed[1];
      expect(landscape, isNotNull);
      expect(
        landscape!.width > landscape.height,
        isTrue,
        reason: 'override must be an A4 landscape format',
      );
      expect(landscape.width, PdfPageFormat.a4.landscape.width);

      // The viewer received the NEW bytes instance — rebuilt on resolution,
      // not holding the stale snapshot.
      expect(
        identical(_viewerBytes(tester), bytesBefore),
        isFalse,
        reason: 'viewer must be handed the re-resolved bytes',
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'K-3b non-regression: landscape-natural report opens landscape and '
    'still toggles to portrait in one click',
    (tester) async {
      final formatsUsed = <PdfPageFormat?>[];
      await _pumpHost(
        tester,
        _request(
          naturalPageFormat: PdfPageFormat.a4.landscape,
          formatsUsed: formatsUsed,
        ),
      );

      // Initial generation with NO override: the builder's own landscape
      // flag decides (NOT defaulted to portrait).
      expect(formatsUsed.length, 1);
      expect(formatsUsed.single, isNull);

      final segmented = tester.widget(
            find.byWidgetPredicate((w) => w is SegmentedButton),
          )
          as SegmentedButton;
      expect(
        segmented.selected.single.toString(),
        contains('landscape'),
        reason: 'landscape-natural report must open landscape (86d70b8)',
      );

      // One click back to portrait regenerates immediately.
      await tester.tap(find.text('Portrait'));
      await _pumpAfterToggle(tester);

      expect(formatsUsed.length, 2);
      final portrait = formatsUsed[1];
      expect(portrait, isNotNull);
      expect(
        portrait!.height > portrait.width,
        isTrue,
        reason: 'override must be an A4 portrait format',
      );

      expect(tester.takeException(), isNull);
    },
  );

  // Argon Rule 14 sweep for the orientation test surface.
  for (final size in const [
    Size(360, 800),
    Size(390, 844),
    Size(414, 896),
  ]) {
    testWidgets('modal with orientation-capable report renders without '
        'exception at ${size.width.round()}x${size.height.round()}',
        (tester) async {
      final formatsUsed = <PdfPageFormat?>[];
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReportPreviewModal(
                request: _request(
                  naturalPageFormat: PdfPageFormat.a4.landscape,
                  formatsUsed: formatsUsed,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });
  }
}
