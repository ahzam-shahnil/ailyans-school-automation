import 'dart:typed_data';

enum ReportType {
  feeVoucher,
  feeReceipt,
  biodata,
  defaulterList,
  attendanceRegister,
  slc,
  feeSchedule,
  teacherBiodata,
  classSyllabus,
  slcRegister,
  salarySlip,
  salaryRegister,
  dailyCollection,
  examMarksheet,
  examSummary,
  libraryCatalog,
  examAwardList,
  teacherAttendanceRegister,
  awardCertificate,
}

extension ReportTypePath on ReportType {
  String get path => switch (this) {
    ReportType.feeVoucher => 'fee-voucher',
    ReportType.feeReceipt => 'fee-receipt',
    ReportType.biodata => 'biodata',
    ReportType.defaulterList => 'defaulter-list',
    ReportType.attendanceRegister => 'attendance-register',
    ReportType.slc => 'slc',
    ReportType.feeSchedule => 'fee-schedule',
    ReportType.teacherBiodata => 'teacher-biodata',
    ReportType.classSyllabus => 'class-syllabus',
    ReportType.slcRegister => 'slc-register',
    ReportType.salarySlip => 'salary-slip',
    ReportType.salaryRegister => 'salary-register',
    ReportType.dailyCollection => 'daily-collection',
    ReportType.examMarksheet => 'exam-marksheet',
    ReportType.examSummary => 'exam-summary',
    ReportType.libraryCatalog => 'library-catalog',
    ReportType.examAwardList => 'exam-award-list',
    ReportType.teacherAttendanceRegister => 'teacher-attendance-register',
    ReportType.awardCertificate => 'award-certificate',
  };

  String get displayName => switch (this) {
    ReportType.feeVoucher => 'Fee Voucher Challan',
    ReportType.feeReceipt => 'Fee Payment Receipt',
    ReportType.biodata => 'Student Biodata Dossier',
    ReportType.defaulterList => 'Fee Defaulter List',
    ReportType.attendanceRegister => 'Daily Attendance Register',
    ReportType.slc => 'School Leaving Certificate',
    ReportType.feeSchedule => 'Fee Schedule',
    ReportType.teacherBiodata => 'Teacher Biodata',
    ReportType.classSyllabus => 'Class Subject Syllabus',
    ReportType.slcRegister => 'SLC Register',
    ReportType.salarySlip => 'Salary Slip',
    ReportType.salaryRegister => 'Salary Register',
    ReportType.dailyCollection => 'Daily Fee Collection',
    ReportType.examMarksheet => 'Exam Marksheet',
    ReportType.examSummary => 'Exam Summary',
    ReportType.libraryCatalog => 'Library Books Catalog',
    ReportType.examAwardList => 'Exam Award List',
    ReportType.teacherAttendanceRegister => 'Teacher Attendance Register',
    ReportType.awardCertificate => 'Award Certificate',
  };

  String get defaultFileName => '${path}_report.pdf';

  static ReportType? fromPath(String path) => ReportType.values
      .cast<ReportType?>()
      .firstWhere((t) => t!.path == path, orElse: () => null);
}

class ReportRequest {
  final ReportType type;
  final String? id;
  final String? titleOverride;
  final String? subtitle;
  final String? fileNameOverride;
  final List<dynamic>? vouchers;
  final Map<String, dynamic> extraParams;
  final Future<Uint8List> Function()? customBytesBuilder;

  const ReportRequest({
    required this.type,
    this.id,
    this.titleOverride,
    this.subtitle,
    this.fileNameOverride,
    this.vouchers,
    this.extraParams = const {},
    this.customBytesBuilder,
  });

  String get effectiveTitle => titleOverride ?? type.displayName;

  String get effectiveFileName =>
      fileNameOverride ??
      (id != null && id!.isNotEmpty
          ? '${type.path}_$id.pdf'
          : type.defaultFileName);
}
