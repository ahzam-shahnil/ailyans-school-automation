import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:school_automation/core/utils/class_biodata_pdf_generator.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClassBiodataPdfGenerator Tests', () {
    test('margins follow invariant 12 (40pt left gutter, >= 30pt right margin)', () {
      expect(ClassBiodataPdfGenerator.kMarginLeft, 40);
      expect(ClassBiodataPdfGenerator.kMarginRight, greaterThanOrEqualTo(30));
      expect(ClassBiodataPdfGenerator.kMarginTop, 30);
      expect(ClassBiodataPdfGenerator.kMarginBottom, 30);

      final printable = ClassBiodataPdfGenerator.printableWidth(PdfPageFormat.a4.landscape);
      expect(printable, closeTo(841.8897637795277 - 70, 0.01));
    });

    test('generates valid %PDF- bytes in A4 landscape with page count < 20 for a realistic roster', () async {
      final students = List.generate(
        40,
        (i) => ClassBiodataStudent(
          rollNo: i + 1,
          regId: 1000 + i + 1,
          studentName: 'Student Number ${i + 1}',
          fatherName: 'Father Name ${i + 1}',
          dob: '2008-05-15',
          admissionDate: '2020-08-01',
          contactNo: '0300-123456$i',
          address: 'Street $i, Sector F-10, Islamabad',
        ),
      );

      final bytes = await ClassBiodataPdfGenerator.generate(
        className: 'Class 10',
        sectionName: 'A',
        sessionYr: '2025-2026',
        students: students,
        branchName: 'Horizon Grammar School',
        branchAddress: 'Civic Centre, Phase 4, Islamabad',
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

      final pageCount = _extractPageCount(bytes);
      expect(pageCount, isNotNull);
      expect(pageCount!, greaterThan(0));
      expect(pageCount, lessThan(20), reason: 'Must stay well within the 20-page guard');
    });

    test('clean-tenant leak test: zero Ailyan / Mianwali strings when non-Ailyan branch metadata is passed', () async {
      final students = [
        const ClassBiodataStudent(
          rollNo: 1,
          regId: 5001,
          studentName: 'Hamza Farooq',
          fatherName: 'Farooq Azam',
          dob: '2010-02-14',
          admissionDate: '2022-04-10',
          contactNo: '0312-9876543',
          address: 'House 12, Street 4, Lahore',
        ),
      ];

      final bytes = await ClassBiodataPdfGenerator.generate(
        className: 'Class 8',
        sectionName: 'Green',
        sessionYr: '2026-2027',
        students: students,
        branchName: 'Beacon Model High School Lahore',
        branchAddress: 'Gulberg III, Lahore, Punjab',
      );

      final decoded = latin1.decode(bytes, allowInvalid: true);
      expect(decoded.contains('Ailyan'), isFalse, reason: 'Zero Ailyan leaks in clean tenant PDF');
      expect(decoded.contains('Mianwali'), isFalse, reason: 'Zero Mianwali leaks in clean tenant PDF');
      expect(decoded.toLowerCase().contains('ailyan'), isFalse, reason: 'Zero ailyan leaks in clean tenant PDF');
      expect(decoded.toLowerCase().contains('mianwali'), isFalse, reason: 'Zero mianwali leaks in clean tenant PDF');
    });

    test('null-safety test: missing optional fields (DOB, DOAdmission, EmergencyNo, P_Address) render cleanly without throwing', () async {
      final studentsWithNulls = [
        const ClassBiodataStudent(
          rollNo: 1,
          regId: 2001,
          studentName: 'Minimal Student One',
          fatherName: 'Father One',
          dob: null,
          admissionDate: null,
          contactNo: null,
          address: null,
        ),
        const ClassBiodataStudent(
          rollNo: 2,
          regId: 2002,
          studentName: 'Minimal Student Two',
          fatherName: 'Father Two',
          dob: '',
          admissionDate: '   ',
          contactNo: '',
          address: ' ',
        ),
      ];

      final bytes = await ClassBiodataPdfGenerator.generate(
        className: 'Class 5',
        sectionName: 'B',
        sessionYr: '2024-2025',
        students: studentsWithNulls,
        branchName: 'Standard Public School',
        branchAddress: 'Main Boulevard, Rawalpindi',
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
