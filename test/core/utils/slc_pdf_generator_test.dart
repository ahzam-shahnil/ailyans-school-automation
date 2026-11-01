import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/slc_pdf_generator.dart';
import 'package:school_automation/core/utils/slc_register_pdf_generator.dart';

void main() {
  group('SlcPdfGenerator & SlcRegisterPdfGenerator Tests', () {
    test(
      'SlcPdfGenerator.generate produces valid A4 PDF without Flex exception',
      () async {
        final slcData = <String, dynamic>{
          'studentName': 'Muhammad Usman',
          'fatherName': 'Tariq Mehmood',
          'className': 'Class 10-A',
          'admissionDate': '01-Apr-2020',
          'leavingDate': '31-Oct-2026',
          'conduct': 'Exemplary',
          'reason': 'Relocation',
          'remarks': 'Dues cleared and character certificate issued.',
        };

        final bytes = await SlcPdfGenerator.generate(
          slcData: slcData,
          branchName: "Ailyans's Higher Secondary School",
          branchAddress: 'Muslim Bazar Mianwali',
        );

        expect(bytes, isA<Uint8List>());
        expect(bytes.isNotEmpty, isTrue);
        // Valid PDF magic header %PDF-
        expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      },
    );

    test(
      'SlcPdfGenerator.generate handles alternate database column keys',
      () async {
        final slcData = <String, dynamic>{
          'name': 'Fatima Bibi',
          'fName': 'Ahmed Khan',
          'leftClass': 'Class 8-B',
          'admDate': '15-Aug-2018',
          'leftDate': '12-May-2025',
          'charactor': 'Good',
          'termOfLeaving': 'Passed Examination',
          'slRemarks': 'All clear',
        };

        final bytes = await SlcPdfGenerator.generate(
          slcData: slcData,
          branchName: "Ailyans's Higher Secondary School",
          branchAddress: 'Muslim Bazar Mianwali',
        );

        expect(bytes, isA<Uint8List>());
        expect(bytes.isNotEmpty, isTrue);
        expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      },
    );

    test('SlcRegisterPdfGenerator.generate handles 582 records without PdfTooBigPageException', () async {
      // Create 582 leavers records to reproduce and verify the 20+ page pagination fix
      final leavers = List.generate(582, (i) {
        final regId = 1000 + i;
        return <String, dynamic>{
          'stuRegId': '$regId',
          'studentName': 'Student Number $regId',
          'fatherName': 'Father $regId',
          'className': 'Class ${(i % 10) + 1}-A',
          'leavingDate': '15-Oct-2026',
          'reason': 'Completed Studies',
        };
      });

      final bytes = await SlcRegisterPdfGenerator.generate(
        sessionYear: '2026-27',
        leavers: leavers,
        branchName: "Ailyans's Higher Secondary School",
        branchAddress: 'Muslim Bazar Mianwali',
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('SlcRegisterPdfGenerator.generate handles empty list', () async {
      final bytes = await SlcRegisterPdfGenerator.generate(
        sessionYear: '2026-27',
        leavers: const [],
        branchName: "Ailyans's Higher Secondary School",
        branchAddress: 'Muslim Bazar Mianwali',
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
    test(
      'SlcPdfGenerator.generate handles raw timestamps like 04/02/24 00:00:00',
      () async {
        final slcData = <String, dynamic>{
          'studentName': 'Zainab Bibi',
          'fatherName': 'Muhammad Aslam',
          'className': 'Class 9-A',
          'admissionDate': '04/02/24 00:00:00',
          'leavingDate': '2026-10-31',
          'conduct': 'Good',
          'reason': 'Shifting',
          'remarks': '',
        };

        final bytes = await SlcPdfGenerator.generate(
          slcData: slcData,
          branchName: "Ailyans's Higher Secondary School",
          branchAddress: 'Muslim Bazar Mianwali',
        );

        expect(bytes, isA<Uint8List>());
        expect(bytes.isNotEmpty, isTrue);
        expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      },
    );
  });
}
