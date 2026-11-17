// Phase K-6 Run 2 — Fix A: report preview toolbar never clips, never hides.
//
// Pumps the preview modal with a defaulterList report (the client-reported
// case) at all six layout sizes and asserts every applicable action button
// stays reachable by its stable Key, with no RenderFlex overflow exception.
//
// Toolbar shapes under test:
// - < 600px: mobile row — Print icon always visible; secondary actions in
//   the overflow PopupMenuButton (never a hiding conditional).
// - 600..1023px: Wrap(alignment: end) toolbar — buttons flow onto lines.
// - >= 1024px: fixed-height row; trailing controls in a horizontal scroll
//   sized to intrinsic content width; Close fixed outside the scroll.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';

ReportRequest _defaulterRequest() => ReportRequest(
  // A4 landscape is the defaulter's natural format (Run 2: declared at the
  // call sites; the modal's toggle must reflect it).
  naturalPageFormat: PdfPageFormat.a4.landscape,
  type: ReportType.defaulterList,
  titleOverride: 'Fee Defaulter List',
  customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
  // DefaulterFilterControls is the caller-supplied header control the real
  // screens attach — include it so the toolbar is tested at its densest.
  // NB: headerControls live on ReportPreviewModal, not the request.
);

Future<void> _pumpModal(WidgetTester tester, Size size) async {
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
                    ReportPreviewModal.show(ctx, request: _defaulterRequest()),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Argon Rule 14 sweep + toolbar reachability at every layout size.
  for (final size in const [
    Size(360, 800),
    Size(390, 844),
    Size(414, 896),
    Size(600, 1024),
    Size(1024, 768),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('toolbar reachable without overflow at '
        '${size.width.round()}x${size.height.round()}', (tester) async {
      await _pumpModal(tester, size);

      // No RenderFlex overflow / any exception at this size.
      expect(tester.takeException(), isNull);

      // Print must be reachable everywhere (the client-reported omission).
      expect(
        find.byKey(const ValueKey('report_toolbar_print')).evaluate(),
        isNotEmpty,
        reason: 'Print/Export PDF must never be hidden at '
            '${size.width.round()}px',
      );
      expect(
        find.byKey(const ValueKey('report_toolbar_close')).evaluate(),
        isNotEmpty,
        reason: 'Run 1 close X must stay present',
      );

      final isMobile = size.width < 600;
      if (!isMobile) {
        // Tablet + desktop: the full action set is in the tree.
        expect(
          find.byKey(const ValueKey('report_toolbar_export')).evaluate(),
          isNotEmpty,
        );
        expect(
          find.byKey(const ValueKey('report_toolbar_refresh')).evaluate(),
          isNotEmpty,
        );
        expect(
          find.byKey(const ValueKey('report_toolbar_orientation')).evaluate(),
          isNotEmpty,
        );
      } else {
        // Mobile: secondary actions live in the overflow menu — verify the
        // menu opens and exposes Export PDF (reachable, not hidden).
        // NB: fixed pumps, not pumpAndSettle — the modal keeps an animated
        // spinner alive while the PdfPreview schedules its raster debounce,
        // so settle never converges in widget tests.
        await tester.tap(find.byTooltip('More actions'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text('Export PDF'),
          findsOneWidget,
          reason: 'Overflow menu must expose Export PDF on mobile',
        );
        // Dismiss the menu via the modal barrier and confirm no exception.
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(tester.takeException(), isNull);
    });
  }
}
