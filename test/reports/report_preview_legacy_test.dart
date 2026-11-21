import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:school_automation/core/utils/platform_compat.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';

ReportRequest _createTestRequest() => ReportRequest(
      type: ReportType.feeVoucher,
      titleOverride: 'Monthly Fee Vouchers',
      extraParams: const {
        'branchName': 'ByteWave High School',
        'branchAddress': '123 Main St',
        'bankName': 'Test Bank',
        'bankBranch': 'Main Branch',
        'bankAcctNo': '0001',
      },
      customBytesBuilder: () async =>
          Uint8List.fromList([0x25, 0x50, 0x44, 0x46]), // '%PDF'
    );

Future<void> _pumpLegacyModal(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => ReportPreviewModal.show(
                ctx,
                request: _createTestRequest(),
                isLegacyWindowsOverride: true,
              ),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Modal'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugIsLegacyWindowsOverride = true;
  });

  tearDown(() {
    debugIsLegacyWindowsOverride = null;
  });

  group('ReportPreviewModal Legacy Windows 8.1 Safe Path', () {
    const testSizes = [
      Size(360, 800), // Mobile narrow
      Size(390, 844), // Mobile standard
      Size(414, 896), // Mobile large
      Size(1366, 768), // Desktop standard
    ];

    for (final size in testSizes) {
      testWidgets(
        'Legacy Windows safe panel renders with zero overflow at ${size.width.toInt()}x${size.height.toInt()}',
        (WidgetTester tester) async {
          await _pumpLegacyModal(tester, size: size);

          expect(tester.takeException(), isNull);

          // 1. In-app PdfPreview must NEVER be mounted
          expect(find.byType(PdfPreview), findsNothing);

          // 2. Safe panel message must be visible
          expect(
            find.text(
              'In-app PDF preview and direct print are not supported on Windows 8.1. '
              'Use Export PDF or Open PDF to print from your PDF viewer.',
            ),
            findsOneWidget,
          );

          // 3. Export PDF, Open PDF, and Close buttons must be present
          final openBtn = find.byKey(const ValueKey('report_legacy_open'));
          final exportBtn = find.byKey(const ValueKey('report_legacy_export'));
          final closeBtn = find.byKey(const ValueKey('report_legacy_close'));

          expect(openBtn, findsOneWidget);
          expect(exportBtn, findsOneWidget);
          expect(closeBtn, findsOneWidget);

          expect(find.text('Open PDF'), findsWidgets);
          expect(find.text('Export PDF'), findsWidgets);
          expect(find.text('Close'), findsWidgets);

          // 4. Buttons must be contained within viewport bounds
          final viewport = Rect.fromLTWH(0, 0, size.width, size.height);

          final openRect = tester.getRect(openBtn);
          final exportRect = tester.getRect(exportBtn);
          final closeRect = tester.getRect(closeBtn);

          expect(
            viewport.contains(openRect.topLeft) &&
                viewport.contains(openRect.bottomRight),
            isTrue,
            reason: 'Open PDF button must be fully inside viewport at $size',
          );
          expect(
            viewport.contains(exportRect.topLeft) &&
                viewport.contains(exportRect.bottomRight),
            isTrue,
            reason: 'Export PDF button must be fully inside viewport at $size',
          );
          expect(
            viewport.contains(closeRect.topLeft) &&
                viewport.contains(closeRect.bottomRight),
            isTrue,
            reason: 'Close button must be fully inside viewport at $size',
          );
        },
      );
    }

    testWidgets('Close button dismisses the legacy modal', (tester) async {
      await _pumpLegacyModal(tester, size: const Size(1366, 768));

      expect(find.byType(ReportPreviewModal), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('report_legacy_close')));
      await tester.pumpAndSettle();

      expect(find.byType(ReportPreviewModal), findsNothing);
    });
  });
}
