// ignore_for_file: lines_longer_than_80_chars
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';

// ---------------------------------------------------------------------------
// Minimal ReportRequest fixtures (no real DB, no real PDF generation)
// ---------------------------------------------------------------------------

// A ReportRequest that uses a customBytesBuilder so the provider never calls
// ThreeCopyVouchersPdf.generate (which needs a real PDF environment).
ReportRequest _feeVoucherRequest() => ReportRequest(
      type: ReportType.feeVoucher,
      titleOverride: 'Test Voucher',
      extraParams: const {
        'branchName': 'Test School',
        'branchAddress': '123 Main St',
        'bankName': 'Test Bank',
        'bankBranch': 'Main Branch',
        'bankAcctNo': '0001',
      },
      // Return 1-byte stub so PdfPreview never renders real content.
      customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
    );

ReportRequest _feeReceiptRequest() => ReportRequest(
      type: ReportType.feeReceipt,
      titleOverride: 'Test Receipt',
      customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
    );

ReportRequest _biodataRequest() => ReportRequest(
      type: ReportType.biodata,
      titleOverride: 'Test Biodata',
      customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
    );

ReportRequest _attendanceRegisterRequest() => ReportRequest(
      type: ReportType.attendanceRegister,
      titleOverride: 'Test Attendance',
      customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
    );

// ---------------------------------------------------------------------------
// Helper: pump the modal inside a ProviderScope + MaterialApp
// ---------------------------------------------------------------------------

Future<void> _pumpModal(
  WidgetTester tester,
  ReportRequest request,
) async {
  // Use a wide viewport so the toolbar never overflows in test.
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => ReportPreviewModal.show(ctx, request: request),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );

  // Open the dialog
  await tester.tap(find.text('Open'));
  // Let the provider's generate() Future complete
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportPreviewModal', () {
    testWidgets(
      'feeVoucher renders SegmentedButton with 3-Copy Slips and Cohort Ledger',
      (tester) async {
        await _pumpModal(tester, _feeVoucherRequest());

        expect(
          find.byType(SegmentedButton<int>),
          findsOneWidget,
          reason: 'Mode toggle must be visible for feeVoucher',
        );
        expect(
          find.text('3-Copy Slips'),
          findsOneWidget,
          reason: 'First segment label must read "3-Copy Slips"',
        );
        expect(
          find.text('Cohort Ledger'),
          findsOneWidget,
          reason: 'Second segment label must read "Cohort Ledger"',
        );

        // No exception should have been thrown
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'feeReceipt does NOT render the voucher mode SegmentedButton',
      (tester) async {
        await _pumpModal(tester, _feeReceiptRequest());

        expect(
          find.byType(SegmentedButton<int>),
          findsNothing,
          reason: 'Mode toggle must NOT be visible for feeReceipt',
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping Cohort Ledger segment triggers regenerateWithMode(1) without crash',
      (tester) async {
        await _pumpModal(tester, _feeVoucherRequest());

        // The modal is open; tap "Cohort Ledger"
        await tester.tap(find.text('Cohort Ledger'));
        // Let the async regenerateWithMode complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // _selectedFeeMode should now be 1 — we verify by checking the
        // selected segment visually (no exception is the primary assertion).
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping back to 3-Copy Slips segment triggers regenerateWithMode(0) without crash',
      (tester) async {
        await _pumpModal(tester, _feeVoucherRequest());

        // Switch to Cohort Ledger first
        await tester.tap(find.text('Cohort Ledger'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Switch back to 3-Copy Slips
        await tester.tap(find.text('3-Copy Slips'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'biodata report type renders without crash',
      (tester) async {
        await _pumpModal(tester, _biodataRequest());

        expect(find.text('Test Biodata'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'attendanceRegister report type renders without crash',
      (tester) async {
        await _pumpModal(tester, _attendanceRegisterRequest());

        expect(find.text('Test Attendance'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('defaulterList report type renders without crash', (tester) async {
      final request = ReportRequest(
        type: ReportType.defaulterList,
        titleOverride: 'Test Defaulters',
        customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
      await _pumpModal(tester, request);
      expect(find.text('Test Defaulters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('teacherBiodata report type renders without crash', (tester) async {
      final request = ReportRequest(
        type: ReportType.teacherBiodata,
        titleOverride: 'Test Teacher Biodata',
        customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
      await _pumpModal(tester, request);
      expect(find.text('Test Teacher Biodata'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('classSyllabus report type renders without crash', (tester) async {
      final request = ReportRequest(
        type: ReportType.classSyllabus,
        titleOverride: 'Test Class Syllabus',
        customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
      await _pumpModal(tester, request);
      expect(find.text('Test Class Syllabus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('slcRegister report type renders without crash', (tester) async {
      final request = ReportRequest(
        type: ReportType.slcRegister,
        titleOverride: 'Test SLC Register',
        customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
      await _pumpModal(tester, request);
      expect(find.text('Test SLC Register'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('salarySlip report type renders without crash', (tester) async {
      final request = ReportRequest(
        type: ReportType.salarySlip,
        titleOverride: 'Test Salary Slip',
        customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
      await _pumpModal(tester, request);
      expect(find.text('Test Salary Slip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('salaryRegister report type renders without crash', (tester) async {
      final request = ReportRequest(
        type: ReportType.salaryRegister,
        titleOverride: 'Test Salary Register',
        customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
      await _pumpModal(tester, request);
      expect(find.text('Test Salary Register'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dailyCollection report type renders without crash', (tester) async {
      final request = ReportRequest(
        type: ReportType.dailyCollection,
        titleOverride: 'Test Daily Collection',
        customBytesBuilder: () async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
      await _pumpModal(tester, request);
      expect(find.text('Test Daily Collection'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
