import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';

void main() {
  test(
    'Empty defaulter list generates valid PDF starting with %PDF-',
    () async {
      final validSummary = DefaulterListFilterSummary(
        sessionYr: '2017-2018',
        classFilter: null,
        totalDefaulters: 0,
        uniqueStudents: 0,
        totalOutstanding: 0,
        reportMonth: 'October 2017',
        generatedAt: DateTime(2026, 10, 24),
      );

      final bytes = await DefaulterListPdfGenerator.generate(
        groups: const [],
        summary: validSummary,
        branchName: "Ailyans's Higher Secondary School Mianwali",
        branchAddress: 'Muslim Bazar Mianwali',
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(3000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
  );

  test('Single class with defaulters generates valid landscape PDF', () async {
    final rows = [
      DefaulterListRow(
        voucherMasId: '1710-4411',
        stuRegId: 4411,
        studentName: 'Muhammad Ali Khan',
        fatherName: 'Khan Muhammad',
        mobile1: '0300-1234567',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 1,
        forMonth: 'October 2017',
        subtotal: 1920,
        discount: 0,
        paidAmt: 0,
        netPayable: 1920,
        isPaid: 'N',
        dueDate: DateTime(2017, 10, 10),
        daysOverdue: 14,
      ),
      DefaulterListRow(
        voucherMasId: '1710-4412',
        stuRegId: 4412,
        studentName: 'Usman Tariq',
        fatherName: 'Tariq Mehmood',
        mobile1: '0300-7654321',
        className: 'Class 10',
        sectionName: 'A',
        rollNo: 2,
        forMonth: 'October 2017',
        subtotal: 2100,
        discount: 100,
        paidAmt: 500,
        netPayable: 1500,
        isPaid: 'N',
        dueDate: DateTime(2017, 10, 10),
        daysOverdue: 14,
      ),
    ];

    final group = DefaulterClassGroup(
      classLabel: 'Class 10 - Section A',
      rows: rows,
      subtotal: 3420,
    );

    final summary = DefaulterListFilterSummary(
      sessionYr: '2017-2018',
      classFilter: 'Class 10',
      totalDefaulters: 2,
      uniqueStudents: 2,
      totalOutstanding: 3420,
      reportMonth: 'October 2017',
      generatedAt: DateTime(2026, 10, 24),
    );

    final bytes = await DefaulterListPdfGenerator.generate(
      groups: [group],
      summary: summary,
      branchName: "Ailyans's Higher Secondary School Mianwali",
      branchAddress: 'Muslim Bazar Mianwali',
      branchPhone: '0459-234567',
      branchPrincipal: 'Prof. Tariq Mehmood',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(4000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    final outDir = Directory(
      '/Users/ahzam/flutter_projects/REA/rebuild/design/phase-e-runtime',
    );
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    File('${outDir.path}/fee-defaulters-roster.pdf').writeAsBytesSync(bytes);
  });

  test('Multiple class groups generate multi-section PDF', () async {
    final group1 = DefaulterClassGroup(
      classLabel: 'Class 10 - Section A',
      rows: [
        DefaulterListRow(
          voucherMasId: '1710-4411',
          stuRegId: 4411,
          studentName: 'Muhammad Ali',
          fatherName: 'Ali Khan',
          mobile1: '0300-1111111',
          className: 'Class 10',
          sectionName: 'A',
          rollNo: 1,
          forMonth: 'October 2017',
          subtotal: 1920,
          discount: 0,
          paidAmt: 0,
          netPayable: 1920,
          isPaid: 'N',
          dueDate: DateTime(2017, 10, 10),
          daysOverdue: 20,
        ),
      ],
      subtotal: 1920,
    );

    final group2 = DefaulterClassGroup(
      classLabel: 'Class 9 - Section B',
      rows: [
        DefaulterListRow(
          voucherMasId: '1710-4420',
          stuRegId: 4420,
          studentName: 'Bilal Ahmed',
          fatherName: 'Ahmed Raza',
          mobile1: '0300-2222222',
          className: 'Class 9',
          sectionName: 'B',
          rollNo: 5,
          forMonth: 'October 2017',
          subtotal: 1800,
          discount: 200,
          paidAmt: 0,
          netPayable: 1600,
          isPaid: 'O',
          dueDate: DateTime(2017, 9, 10),
          daysOverdue: 50,
        ),
      ],
      subtotal: 1600,
    );

    final summary = DefaulterListFilterSummary(
      sessionYr: '2017-2018',
      classFilter: null,
      totalDefaulters: 2,
      uniqueStudents: 2,
      totalOutstanding: 3520,
      reportMonth: 'All Billing Months',
      generatedAt: DateTime(2026, 10, 24),
    );

    final bytes = await DefaulterListPdfGenerator.generate(
      groups: [group1, group2],
      summary: summary,
      branchName: "Ailyans's Higher Secondary School Mianwali",
      branchAddress: 'Muslim Bazar Mianwali',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(5000));
  });

  test(
    'High daysOverdue and partial PaidAmt balance render cleanly without error',
    () async {
      final rows = [
        DefaulterListRow(
          voucherMasId: '1610-9999',
          stuRegId: 9999,
          studentName: 'Long Overdue Student',
          fatherName: 'Guardian Name',
          mobile1: '0333-9999999',
          className: 'Class 5',
          sectionName: 'A',
          rollNo: 15,
          forMonth: 'October 2016',
          subtotal: 5000,
          discount: 500,
          paidAmt: 2500,
          netPayable: 2000,
          isPaid: 'O',
          dueDate: DateTime(2016, 10, 10),
          daysOverdue: 400,
        ),
      ];

      final group = DefaulterClassGroup(
        classLabel: 'Class 5 - Section A',
        rows: rows,
        subtotal: 2000,
      );

      final summary = DefaulterListFilterSummary(
        sessionYr: '2016-2017',
        classFilter: 'Class 5',
        totalDefaulters: 1,
        uniqueStudents: 1,
        totalOutstanding: 2000,
        reportMonth: 'October 2016',
        generatedAt: DateTime(2026, 10, 24),
      );

      final bytes = await DefaulterListPdfGenerator.generate(
        groups: [group],
        summary: summary,
        branchName: "Ailyans's Higher Secondary School Mianwali",
        branchAddress: 'Muslim Bazar Mianwali',
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(4000));
    },
  );
}
