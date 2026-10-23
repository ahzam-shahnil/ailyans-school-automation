import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/biodata_pdf_generator.dart';

StudentBiodataPrintData _minimalBiodata() {
  return const StudentBiodataPrintData(
    stuRegId: 4411,
    studentName: 'Muhammad Ali Khan',
    fullDiscount: 0,
    enrollmentHistory: [],
    feeTotalBilled: 0,
    feeTotalPaid: 0,
    feeBalance: 0,
    currentClassSection: 'Not Enrolled',
  );
}

StudentBiodataPrintData _fullBiodata({
  List<StudentEnrollmentHistoryRow>? customEnrollments,
}) {
  return StudentBiodataPrintData(
    stuRegId: 4411,
    studentName: 'Muhammad Ali Khan',
    nameMiddle: 'Ali',
    dob: DateTime(2002, 4, 12),
    sex: 'Male',
    religion: 'Islam',
    nationality: 'Pakistani',
    bFormNo: '38302-1234567-1',
    fatherName: 'Khan Muhammad',
    cnicNo: '38302-1234567-1',
    occupation: 'Engineer',
    mobile1: '0300-1234567',
    mobile2: '0321-7654321',
    pAddress: 'House 14, Street 2, Civil Lines, Mianwali',
    tAddress: 'Same as permanent',
    pSchool: 'Govt High School Kundian',
    pClass: '9th Grade',
    admInClass: 13,
    admClassName: 'Class 10',
    doAdmission: DateTime(2017, 8, 15),
    discount: 500.0,
    vmDiscount: 0,
    fullDiscount: 0,
    officeFile: 'FL-2017-B10-4411',
    remarks: 'Excellent student',
    enrollmentHistory:
        customEnrollments ??
        const [
          StudentEnrollmentHistoryRow(
            sessionYr: '2017-2018',
            className: 'Class 10',
            sectionName: 'A',
            classRollNo: 1,
            isPresent: true,
          ),
          StudentEnrollmentHistoryRow(
            sessionYr: '2016-2017',
            className: 'Class 9',
            sectionName: 'A',
            classRollNo: 5,
            isPresent: false,
          ),
        ],
    feeTotalBilled: 19200,
    feeTotalPaid: 17280,
    feeBalance: 1920,
    currentClassSection: 'Class 10-A',
  );
}

void main() {
  test('Minimal biodata generates valid PDF', () async {
    final bytes = await BiodataPdfGenerator.generateStudentBiodata(
      data: _minimalBiodata(),
      branchName: 'Test School',
      branchAddress: 'Test Address',
    );
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(3000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('Full biodata generates larger PDF', () async {
    final bytes = await BiodataPdfGenerator.generateStudentBiodata(
      data: _fullBiodata(),
      branchName: 'Test School',
      branchAddress: 'Test Address',
      branchPhone: '0300-0000000',
      branchPrincipal: 'Test Principal',
    );
    expect(bytes.length, greaterThan(5000));
  });

  test('Biodata with no photo renders placeholder', () async {
    final data = _fullBiodata(); // photoPath is null
    final bytes = await BiodataPdfGenerator.generateStudentBiodata(
      data: data,
      branchName: 'Test School',
      branchAddress: 'Test Address',
    );
    expect(bytes.length, greaterThan(5000));
  });

  test('Biodata with 5+ enrollment history rows still renders', () async {
    final extended = _fullBiodata(
      customEnrollments: const [
        StudentEnrollmentHistoryRow(
          sessionYr: '2017-2018',
          className: 'Class 10',
          sectionName: 'A',
          classRollNo: 1,
          isPresent: true,
        ),
        StudentEnrollmentHistoryRow(
          sessionYr: '2016-2017',
          className: 'Class 9',
          sectionName: 'A',
          classRollNo: 5,
          isPresent: false,
        ),
        StudentEnrollmentHistoryRow(
          sessionYr: '2015-2016',
          className: 'Class 8',
          sectionName: 'A',
          classRollNo: 7,
          isPresent: false,
        ),
        StudentEnrollmentHistoryRow(
          sessionYr: '2014-2015',
          className: 'Class 7',
          sectionName: 'B',
          classRollNo: 12,
          isPresent: false,
        ),
        StudentEnrollmentHistoryRow(
          sessionYr: '2013-2014',
          className: 'Class 6',
          sectionName: 'B',
          classRollNo: 15,
          isPresent: false,
        ),
      ],
    );

    final bytes = await BiodataPdfGenerator.generateStudentBiodata(
      data: extended,
      branchName: 'Test School',
      branchAddress: 'Test Address',
    );
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(5000));
  });

  test('Renders student 4411 biodata and writes to disk', () async {
    final data = _fullBiodata();
    final bytes = await BiodataPdfGenerator.generateStudentBiodata(
      data: data,
      branchName: "Ailyans's Higher Secondary School Mianwali",
      branchAddress: 'Muslim Bazar Mianwali',
      branchPhone: '0459-234567',
      branchPrincipal: 'Prof. Tariq Mehmood',
    );
    final outDir = Directory(
      '/Users/ahzam/flutter_projects/REA/rebuild/design/phase-e-runtime',
    );
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    File('${outDir.path}/student-biodata-4411.pdf').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(5000));
  });

  test('Biodata with sparse data (only required fields) still produces a valid bordered layout', () async {
    const sparse = StudentBiodataPrintData(
      stuRegId: 9999,
      studentName: 'Sparse Student',
      fullDiscount: 0,
      enrollmentHistory: [],
      feeTotalBilled: 0,
      feeTotalPaid: 0,
      feeBalance: 0,
      currentClassSection: 'Not Enrolled',
    );
    final bytes = await BiodataPdfGenerator.generateStudentBiodata(
      data: sparse,
      branchName: 'Test School',
      branchAddress: 'Test Address',
    );
    expect(
      bytes.length,
      greaterThan(4000),
      reason: 'Sparse biodata must still render bordered grid (not fail)',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
