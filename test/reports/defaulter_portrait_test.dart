// Phase K-6 Run B — Fee Defaulter A4-portrait layout, orientation unlock & count badge.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';

int? _extractPageCount(List<int> bytes) {
  final text = latin1.decode(bytes);
  final r1 = RegExp(r'/Type\s*/Pages[^>]*?/Count\s+(\d+)');
  final m1 = r1.firstMatch(text);
  if (m1 != null) return int.parse(m1.group(1)!);
  final r2 = RegExp(r'/Count\s+(\d+)[^>]*?/Type\s*/Pages');
  final m2 = r2.firstMatch(text);
  if (m2 != null) return int.parse(m2.group(1)!);
  return null;
}

(List<DefaulterClassGroup>, DefaulterListFilterSummary) _build75RowFixture() {
  final groups = <DefaulterClassGroup>[];
  var totalOutstanding = 0;
  for (var g = 1; g <= 3; g++) {
    final rows = <DefaulterListRow>[];
    for (var r = 1; r <= 25; r++) {
      final idx = (g - 1) * 25 + r;
      final sub = 2500 + idx * 50;
      const disc = 100;
      const paid = 500;
      final net = sub - disc - paid;
      totalOutstanding += net;
      rows.add(
        DefaulterListRow(
          voucherMasId: 'VCH-${2000 + idx}',
          stuRegId: 1000 + idx,
          studentName: 'Student Name $idx',
          fatherName: 'Father Name $idx',
          mobile1: '0300-${1000000 + idx}',
          className: 'Class $g',
          sectionName: 'A',
          rollNo: r,
          forMonth: 'Nov 2026',
          subtotal: sub,
          discount: disc,
          paidAmt: paid,
          netPayable: net,
          isPaid: 'N',
          dueDate: DateTime(2026, 11, 10),
          daysOverdue: 14 + (idx % 30),
        ),
      );
    }
    groups.add(
      DefaulterClassGroup(
        classLabel: 'Class $g - Section A',
        rows: rows,
        subtotal: rows.fold<int>(0, (sum, row) => sum + row.balance),
      ),
    );
  }
  final summary = DefaulterListFilterSummary(
    sessionYr: '2026-2027',
    classFilter: null,
    totalDefaulters: 75,
    uniqueStudents: 75,
    totalOutstanding: totalOutstanding,
    reportMonth: 'Nov 2026',
    generatedAt: DateTime(2026, 11, 18),
  );
  return (groups, summary);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Defaulter A4 Portrait Generator', () {
    test('portrait generate produces valid %PDF-, deterministic byte length, != landscape length', () async {
      final (groups, summary) = _build75RowFixture();
      final portraitBytes1 = await DefaulterListPdfGenerator.generate(
        groups: groups,
        summary: summary,
        branchName: "Ailyans's Higher Secondary School",
        branchAddress: 'Muslim Bazar Mianwali',
        pageFormat: PdfPageFormat.a4,
      );
      final portraitBytes2 = await DefaulterListPdfGenerator.generate(
        groups: groups,
        summary: summary,
        branchName: "Ailyans's Higher Secondary School",
        branchAddress: 'Muslim Bazar Mianwali',
        pageFormat: PdfPageFormat.a4,
      );
      final landscapeBytes = await DefaulterListPdfGenerator.generate(
        groups: groups,
        summary: summary,
        branchName: "Ailyans's Higher Secondary School",
        branchAddress: 'Muslim Bazar Mianwali',
        pageFormat: PdfPageFormat.a4.landscape,
      );

      expect(portraitBytes1, isNotEmpty);
      expect(String.fromCharCodes(portraitBytes1.take(5)), '%PDF-');
      // Deterministic byte length for identical inputs
      expect(portraitBytes1.length, equals(portraitBytes2.length));
      // Portrait layout differs from landscape layout
      expect(portraitBytes1.length, isNot(equals(landscapeBytes.length)));
    });

    test('portrait fixed column budget 350 <= printableWidth with flex remainder > 100', () {
      final portraitWidth = DefaulterListPdfGenerator.printableWidth(PdfPageFormat.a4);
      // A4 portrait width (595.28) - margins (40 + 30) = 525.28pt
      expect(portraitWidth, closeTo(525.28, 0.05));

      // Fixed budget: 20 (#) + 26 (Roll) + 36 (Reg ID) + 70 (Contact) + 64 (Voucher) + 70 (Due) + 64 (Bal) = 350
      const fixedBudget = 350.0;
      expect(fixedBudget, lessThanOrEqualTo(portraitWidth));
      final flexRemainder = portraitWidth - fixedBudget;
      expect(flexRemainder, greaterThan(100.0));
      expect(flexRemainder, closeTo(175.28, 0.05));
    });

    test('75-row 3-group fixture portrait page count < 20 (pdf guard)', () async {
      final (groups, summary) = _build75RowFixture();
      final bytes = await DefaulterListPdfGenerator.generate(
        groups: groups,
        summary: summary,
        branchName: "Ailyans's Higher Secondary School",
        branchAddress: 'Muslim Bazar Mianwali',
        pageFormat: PdfPageFormat.a4,
      );
      final pageCount = _extractPageCount(bytes);
      expect(pageCount, isNotNull);
      expect(pageCount!, greaterThan(1));
      expect(pageCount, lessThan(20), reason: 'Must stay well within 20-page guard');
    });

    test('portrait stacked header and unconstrained footer render without exception', () async {
      final (groups, summary) = _build75RowFixture();
      // Test portrait rendering with long branch name (which previously threatened footer squashing/stretching)
      final bytes = await DefaulterListPdfGenerator.generate(
        groups: groups,
        summary: summary,
        branchName: "Ailyans's Higher Secondary School Mianwali - Main Campus System",
        branchAddress: 'Muslim Bazar Mianwali District Mianwali Punjab Pakistan',
        branchPhone: '0300-1234567',
        branchPrincipal: 'Prof. Muhammad Tariq Mehmood Khan',
        pageFormat: PdfPageFormat.a4,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final pageCount = _extractPageCount(bytes);
      expect(pageCount, isNotNull);
      expect(pageCount!, lessThan(20));
    });
  });

  group('Report Preview Modal Defaulter Badge & Unlock', () {
    testWidgets('count badge: defaulter request reads summary totalDefaulters, not group count', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 8 groups passed in vouchers, but summary has 19 totalDefaulters and 19 uniqueStudents
      final groups = List.generate(
        8,
        (i) => DefaulterClassGroup(classLabel: 'Class $i', rows: const [], subtotal: 0),
      );
      final summary = DefaulterListFilterSummary(
        sessionYr: '2026-2027',
        totalDefaulters: 19,
        uniqueStudents: 19,
        totalOutstanding: 45000,
        reportMonth: 'Nov 2026',
        generatedAt: DateTime(2026, 11, 18),
      );

      final request = ReportRequest(
        type: ReportType.defaulterList,
        naturalPageFormat: PdfPageFormat.a4.landscape,
        locksOrientation: false,
        vouchers: groups,
        extraParams: {
          'summary': summary,
          'branchName': 'Test School',
          'branchAddress': 'Test Address',
        },
      );

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

      expect(tester.takeException(), isNull);
      // Badge must show '19 Vouchers · 19 Students'
      expect(find.text('19 Vouchers · 19 Students'), findsWidgets);
      // Must NOT show 8 Vouchers (the class groups count)
      expect(find.textContaining('8 Vouchers'), findsNothing);
      // Must NOT claim pages for defaulter list
      expect(find.textContaining('Pages'), findsNothing);
    });

    testWidgets('count badge: voucher request uses standard voucher/page counting', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const request = ReportRequest(
        type: ReportType.feeVoucher,
        naturalPageFormat: PdfPageFormat.a4,
        vouchers: [1, 2, 3, 4, 5],
        extraParams: {
          'branchName': 'Test School',
          'branchAddress': 'Test Address',
        },
      );

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

      expect(tester.takeException(), isNull);
      expect(find.text('5 Vouchers · 5 Pages'), findsWidgets);
    });

    testWidgets('defaulter report request has locksOrientation: false and orientation toggle enabled', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final summary = DefaulterListFilterSummary(
        sessionYr: '2026-2027',
        totalDefaulters: 5,
        uniqueStudents: 5,
        totalOutstanding: 15000,
        reportMonth: 'Nov 2026',
        generatedAt: DateTime(2026, 11, 18),
      );

      final request = ReportRequest(
        type: ReportType.defaulterList,
        naturalPageFormat: PdfPageFormat.a4.landscape,
        locksOrientation: false,
        vouchers: const [],
        extraParams: {
          'summary': summary,
          'branchName': 'Test School',
          'branchAddress': 'Test Address',
        },
      );

      expect(request.locksOrientation, isFalse);
      expect(request.naturalPageFormat, equals(PdfPageFormat.a4.landscape));

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

      expect(tester.takeException(), isNull);

      final toggle = tester.widget(
        find.byKey(const ValueKey('report_toolbar_orientation')),
      ) as dynamic;
      expect(
        toggle.onSelectionChanged,
        isNotNull,
        reason: 'Orientation toggle must be enabled for unlocked defaulter request',
      );
    });
  });
}
