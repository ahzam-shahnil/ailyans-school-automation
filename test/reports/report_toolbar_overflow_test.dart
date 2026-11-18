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
  // Phase K-6 Run 2b: the 10-column roster garbles in A4 portrait
  // (three-line wrapped names, mid-token breaks) — the modal's orientation
  // toggle renders DISABLED for locked requests.
  locksOrientation: true,
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

        // Phase K-6 Run 2b: locked request — the toggle renders DISABLED
        // (onSelectionChanged null) while still showing the natural
        // landscape segment. NB: dynamic cast — reading onSelectionChanged
        // through a downcast generic fails on non-null callbacks.
        final toggle = tester.widget(
          find.byKey(const ValueKey('report_toolbar_orientation')),
        ) as dynamic;
        expect(
          toggle.onSelectionChanged,
          isNull,
          reason: 'Orientation toggle must be disabled for locked reports',
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

  // Phase K-6 Run 2b: Run 2 asserted only that Print exists in the widget
  // tree — the Windows client still saw it clipped because a scrollable
  // ancestor keeps off-viewport children in the tree. These assertions pin
  // the button's RENDERED RECTANGLE inside the modal's bounds.
  for (final size in const [
    Size(1024, 768),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('Print button fully visible inside the dialog at '
        '${size.width.round()}x${size.height.round()}', (tester) async {
      await _pumpModal(tester, size);
      expect(tester.takeException(), isNull);

      final printRect = tester.getRect(
        find.byKey(const ValueKey('report_toolbar_print')),
      );
      final dialogRect = tester.getRect(find.byType(ReportPreviewModal));
      expect(
        printRect.left >= dialogRect.left &&
            printRect.right <= dialogRect.right,
        isTrue,
        reason: 'Print button must be fully inside the dialog horizontally '
            'at ${size.width.round()}px — got $printRect in $dialogRect',
      );
      // Every action button's rect must be inside the dialog too.
      for (final key in const [
        'report_toolbar_close',
        'report_toolbar_refresh',
        'report_toolbar_export',
        'report_toolbar_orientation',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
        expect(
          rect.left >= dialogRect.left && rect.right <= dialogRect.right,
          isTrue,
          reason: '$key must be fully inside the dialog at '
              '${size.width.round()}px — got $rect in $dialogRect',
        );
      }
    });
  }

  // ===========================================================================
  // Phase K-6-f (item 8): full containment matrix — verification run.
  //
  // CONTAINMENT LAW: every visible control sits inside dialogRect on all
  // FOUR edges; scroll-child controls ALSO sit inside the toolbar horizontal
  // scroll VIEWPORT rect on all four edges. maxScrollExtent is reported as a
  // diagnostic only (non-interactive trailing spacing may scroll while every
  // button stays visible) — never asserted to be 0.
  // ===========================================================================

  Finder toolbarScrollFinder() => find.ancestor(
        of: find.byKey(const ValueKey('report_toolbar_refresh')),
        matching: find.byWidgetPredicate(
          (w) => w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
      ).first;

  double maxScrollExtentOf(WidgetTester tester, Finder scrollFinder) {
    final scrollable = find.descendant(
      of: scrollFinder,
      matching: find.byType(Scrollable),
    );
    if (scrollable.evaluate().isEmpty) return 0;
    final state = tester.state<ScrollableState>(scrollable.first);
    return state.position.maxScrollExtent;
  }

  void expectInside(Rect inner, Rect outer, String what) {
    expect(
      inner.left >= outer.left &&
          inner.right <= outer.right &&
          inner.top >= outer.top &&
          inner.bottom <= outer.bottom,
      isTrue,
      reason: '$what rect $inner must sit inside $outer on all four edges',
    );
  }

  group('K-6-f desktop containment matrix', () {
    const scrollChildKeys = [
      'report_toolbar_orientation',
      'report_toolbar_refresh',
      'report_toolbar_export',
      'report_toolbar_print',
    ];

    for (final size in const [
      Size(1024, 768),
      Size(1280, 720),
      Size(1366, 768),
      Size(1440, 900),
    ]) {
      testWidgets(
        'all toolbar keys inside dialog AND scroll viewport at '
        '${size.width.round()}x${size.height.round()}',
        (tester) async {
          await _pumpModal(tester, size);
          expect(tester.takeException(), isNull);

          final dialogRect = tester.getRect(find.byType(ReportPreviewModal));
          final scrollRect = tester.getRect(toolbarScrollFinder());

          // The scroll viewport itself must live inside the dialog.
          expectInside(scrollRect, dialogRect, 'toolbar scroll viewport');

          // Scroll-child controls: dialog AND viewport containment.
          for (final key in scrollChildKeys) {
            final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
            expectInside(rect, dialogRect, '$key (dialog)');
            expectInside(rect, scrollRect, '$key (scroll viewport)');
          }

          // Close is FIXED outside the horizontal scroll (Run 2 design):
          // dialog containment only.
          final closeRect = tester.getRect(
            find.byKey(const ValueKey('report_toolbar_close')),
          );
          expectInside(closeRect, dialogRect, 'report_toolbar_close');

          // Title (stable text finder — no production keys added) must not
          // overlap the scroll viewport horizontally.
          final titleRect = tester.getRect(find.text('Fee Defaulter List'));
          expect(
            titleRect.right <= scrollRect.left,
            isTrue,
            reason: 'title $titleRect must end left of the scroll viewport '
                '$scrollRect at ${size.width.round()}px',
          );

          // Diagnostic only: non-interactive trailing spacing may scroll.
          final maxExtent = maxScrollExtentOf(tester, toolbarScrollFinder());
          expect(maxExtent, greaterThanOrEqualTo(0.0));
          // ignore: avoid_print
          print('K-6-f ${size.width.round()}x${size.height.round()} '
              'maxScrollExtent=$maxExtent scrollRect=$scrollRect');

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('K-6-f tablet containment upgrade (600x1024)', () {
    testWidgets('all 5 inline keys fully inside the dialog on 4 edges',
        (tester) async {
      await _pumpModal(tester, const Size(600, 1024));
      expect(tester.takeException(), isNull);

      final dialogRect = tester.getRect(find.byType(ReportPreviewModal));
      for (final key in const [
        'report_toolbar_orientation',
        'report_toolbar_refresh',
        'report_toolbar_export',
        'report_toolbar_print',
        'report_toolbar_close',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
        expectInside(rect, dialogRect, '$key (tablet)');
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('K-6-f mobile inline + opened-menu containment (390x844)', () {
    testWidgets('inline controls inside dialog; menu items inside screen',
        (tester) async {
      await _pumpModal(tester, const Size(390, 844));
      expect(tester.takeException(), isNull);

      final dialogRect = tester.getRect(find.byType(ReportPreviewModal));

      // INLINE controls only — closed-menu items are NOT in the render
      // tree, so getRect on them would throw a StateError (test bug).
      for (final key in const [
        'report_toolbar_refresh',
        'report_toolbar_print',
        'report_toolbar_close',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
        expectInside(rect, dialogRect, '$key (mobile inline)');
      }
      final triggerRect = tester.getRect(find.byTooltip('More actions'));
      expectInside(triggerRect, dialogRect, 'overflow trigger');

      // Open the overflow menu (fixed pumps — never pumpAndSettle around
      // PdfPreview) and assert each menu item inside the SCREEN rect.
      await tester.tap(find.byTooltip('More actions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final screenRect = Rect.fromLTWH(
        0,
        0,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
      for (final item in const ['Export PDF', 'Regenerate']) {
        final itemRect = tester.getRect(find.text(item));
        expectInside(itemRect, screenRect, 'menu item "$item"');
      }

      expect(tester.takeException(), isNull);

      // Close the menu via the modal barrier before the test ends.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}
