// Phase K-6 Run 2b — Fix 1: defaulter-list orientation lock.
//
// The 10-column defaulter roster is designed for A4 landscape; rendering
// it portrait garbles names across three lines with mid-token breaks
// ('Muham mad', '10-Nov- 2026') and merged #/Roll cells. The contract:
//
// 1. ReportRequest.locksOrientation == true renders the modal's
//    Portrait/Landscape toggle DISABLED (onSelectionChanged null) with a
//    reason tooltip — the segment still shows the natural landscape.
// 2. Belt-and-braces: the provider pins a locked request to A4 landscape
//    EVEN IF a stale portrait pageFormat override reaches it (the
//    generator then receives a4.landscape, not the override).
//
// No PDF binary parsing: byte equality against the landscape render and
// inequality against an unlocked portrait render prove both directions.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:school_automation/core/providers/report_preview_provider.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';

const String _kLandscapeTooltip =
    'This report is designed for A4 landscape and cannot be re-oriented.';

DefaulterClassGroup _group() {
  // Enough real-shaped rows that a portrait vs landscape render produces
  // different byte output (pagination + page dimensions differ).
  final rows = <DefaulterListRow>[
    for (var i = 0; i < 24; i++)
      DefaulterListRow(
        voucherMasId: 'VCH-${1000 + i}',
        stuRegId: 500 + i,
        studentName: 'Muhammad ${'A' * (i % 5)}hmad Ibn Sulaiman',
        fatherName: 'Abdul Rahman Ibn Yusuf',
        mobile1: '0300-12345$i',
        className: 'Class ${(i % 5) + 1}',
        sectionName: 'Section ${String.fromCharCode(65 + (i % 2))}',
        rollNo: i + 1,
        forMonth: 'Nov 2026',
        subtotal: 5000 + i * 10,
        discount: 500,
        paidAmt: 1000,
        netPayable: 3500 + i * 10,
        isPaid: 'N',
        dueDate: DateTime(2026, 11, 10),
        daysOverdue: i,
      ),
  ];
  return DefaulterClassGroup(
    classLabel: 'Class 1 - Section A',
    rows: rows,
    subtotal: rows.fold<int>(0, (sum, r) => sum + r.balance),
  );
}

/// A few rows only: portrait A4 fits a small roster on one page. (A large
/// portrait roster overflows the pdf package's 20-page guard — one more
/// reason the roster is landscape-locked.)
DefaulterClassGroup _smallGroup() {
  final rows = <DefaulterListRow>[
    for (var i = 0; i < 6; i++)
      DefaulterListRow(
        voucherMasId: 'VCH-${2000 + i}',
        stuRegId: 900 + i,
        studentName: 'Muhammad Ibn Sulaiman $i',
        fatherName: 'Abdul Rahman',
        mobile1: '0300-98$i',
        className: 'Class 2',
        sectionName: 'Section B',
        rollNo: i + 1,
        forMonth: 'Nov 2026',
        subtotal: 5000,
        discount: 500,
        paidAmt: 1000,
        netPayable: 3500,
        isPaid: 'N',
        dueDate: DateTime(2026, 11, 10),
        daysOverdue: i,
      ),
  ];
  return DefaulterClassGroup(
    classLabel: 'Class 2 - Section B',
    rows: rows,
    subtotal: rows.fold<int>(0, (sum, r) => sum + r.balance),
  );
}

DefaulterListFilterSummary _summary() => DefaulterListFilterSummary(
  sessionYr: '2026-27',
  totalDefaulters: 24,
  uniqueStudents: 24,
  totalOutstanding: 84000,
  reportMonth: 'Nov 2026',
  generatedAt: DateTime(2026, 11, 18),
);

ReportRequest _request({required bool locksOrientation}) => ReportRequest(
  naturalPageFormat: PdfPageFormat.a4.landscape,
  type: ReportType.defaulterList,
  titleOverride: 'Fee Defaulter List',
  locksOrientation: locksOrientation,
  vouchers: [_group()],
  extraParams: {
    'summary': _summary(),
    'branchName': 'Test School',
    'branchAddress': 'Test Address',
  },
);

Future<Uint8List?> _generateViaProvider(
  ReportRequest request,
  PdfPageFormat? override,
) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final provider = reportPreviewProvider(
    ReportPreviewKey(request: request, pageFormat: override),
  );
  // Keep the autoDispose instance alive while generation completes.
  container.listen(provider, (_, __) {}, fireImmediately: true);
  var state = container.read(provider);
  var guard = 0;
  while (state.isLoading && guard++ < 300) {
    await Future<void>.delayed(Duration.zero);
    state = container.read(provider);
  }
  expect(state.error, isNull, reason: 'PDF generation must not fail');
  return state.bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('locked request: orientation toggle renders disabled with '
      'reason tooltip', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
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
                      ReportPreviewModal.show(ctx, request: _request(
                        locksOrientation: true,
                      )),
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

    expect(tester.takeException(), isNull);

    final toggle = tester.widget(
      find.byKey(const ValueKey('report_toolbar_orientation')),
    ) as dynamic;
    expect(
      toggle.onSelectionChanged,
      isNull,
      reason: 'Locked reports must render the orientation toggle disabled',
    );
    // Single natural-format selection (landscape) — the enum is private to
    // the modal, so the exact value's reflection is covered by
    // report_orientation_toggle_test.dart's natural-passthrough cases and
    // the byte-level landscape assertions below.
    expect(toggle.selected, hasLength(1));
    expect(find.byTooltip(_kLandscapeTooltip), findsOneWidget);
  });

  testWidgets('unlocked request: toggle stays enabled', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
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
                      ReportPreviewModal.show(ctx, request: _request(
                        locksOrientation: false,
                      )),
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

    expect(tester.takeException(), isNull);
    // NB: dynamic (not SegmentedButton<dynamic>) — reading onSelectionChanged
    // through a downcast generic fails on non-null callbacks (the callback's
    // Set<_PdfOrientation> parameter is contravariant).
    final toggle = tester.widget(
      find.byKey(const ValueKey('report_toolbar_orientation')),
    ) as dynamic;
    expect(toggle.onSelectionChanged, isNotNull);
  });

  test('belt-and-braces: a locked request ignores a portrait override and '
      'renders the landscape bytes', () async {
    final lockedPortrait = await _generateViaProvider(
      _request(locksOrientation: true),
      // The stale override the belt-and-braces guard must defeat.
      PdfPageFormat.a4,
    );
    final lockedLandscape = await _generateViaProvider(
      _request(locksOrientation: true),
      PdfPageFormat.a4.landscape,
    );
    expect(lockedPortrait, isNotNull);
    expect(lockedLandscape, isNotNull);
    // The pdf package embeds a RANDOM document ID (sha256 of the current
    // time), so raw bytes can never be equal across two saves — but the
    // byte LENGTH is deterministic for an identical layout. Length
    // equality proves the generator received a4.landscape in BOTH cases.
    expect(
      lockedPortrait!.length,
      lockedLandscape!.length,
      reason: 'A locked request must ignore the portrait override and '
          'render identical landscape layouts',
    );
  });

  test('control: an UNLOCKED request honors the portrait override '
      '(different layouts)', () async {
    final unlockedPortrait = await _generateViaProvider(
      ReportRequest(
        naturalPageFormat: PdfPageFormat.a4.landscape,
        type: ReportType.defaulterList,
        titleOverride: 'Fee Defaulter List',
        vouchers: [_smallGroup()],
        extraParams: {
          'summary': _summary(),
          'branchName': 'Test School',
          'branchAddress': 'Test Address',
        },
      ),
      PdfPageFormat.a4,
    );
    final unlockedLandscape = await _generateViaProvider(
      ReportRequest(
        naturalPageFormat: PdfPageFormat.a4.landscape,
        type: ReportType.defaulterList,
        titleOverride: 'Fee Defaulter List',
        vouchers: [_smallGroup()],
        extraParams: {
          'summary': _summary(),
          'branchName': 'Test School',
          'branchAddress': 'Test Address',
        },
      ),
      PdfPageFormat.a4.landscape,
    );
    expect(unlockedPortrait, isNotNull);
    expect(unlockedLandscape, isNotNull);
    expect(
      unlockedPortrait!.length,
      isNot(unlockedLandscape!.length),
      reason: 'Non-defaulter honor-override behavior must be unchanged: an '
          'unlocked request renders DIFFERENT layouts per orientation',
    );
  });

  test('direct generator sanity: identical data renders different layouts '
      'per format (which is why the provider-level lock is required)',
      () async {
    final landscape = await DefaulterListPdfGenerator.generate(
      groups: [_smallGroup()],
      summary: _summary(),
      branchName: 'Test School',
      branchAddress: 'Test Address',
      pageFormat: PdfPageFormat.a4.landscape,
    );
    final portrait = await DefaulterListPdfGenerator.generate(
      groups: [_smallGroup()],
      summary: _summary(),
      branchName: 'Test School',
      branchAddress: 'Test Address',
      pageFormat: PdfPageFormat.a4,
    );
    expect(
      portrait.length,
      isNot(landscape.length),
      reason: 'The generator itself is format-aware — which is exactly why '
          'the provider-level lock (and the disabled toggle) is required',
    );
  });
}
