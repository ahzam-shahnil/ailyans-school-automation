import 'dart:typed_data';

import 'package:pdf/pdf.dart';

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
  studentMarksheet,
  feeCollectionRegister,
  classDefaulters,
  examStatus,
  classCollectionSummary,
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
    ReportType.studentMarksheet => 'student-marksheet',
    ReportType.feeCollectionRegister => 'fee-collection-register',
    ReportType.classDefaulters => 'class-defaulters',
    ReportType.examStatus => 'exam-status',
    ReportType.classCollectionSummary => 'class-collection-summary',
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
    ReportType.studentMarksheet => 'Student Marksheet',
    ReportType.feeCollectionRegister => 'Fee Collection Register',
    ReportType.classDefaulters => 'Class Defaulters',
    ReportType.examStatus => 'Exam Status Report',
    ReportType.classCollectionSummary => 'Class Collection Summary',
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

  /// Builds the PDF bytes for this request (legacy zero-argument shape).
  ///
  /// For format-aware builders (e.g. the VB6 report path) prefer
  /// [customBytesBuilderWithFormat], which receives the active page format
  /// (user orientation override, if any).
  final Future<Uint8List> Function()? customBytesBuilder;

  /// Phase K Shot 3b-core: format-aware custom builder. Receives the active
  /// [PdfPageFormat] — the user's Portrait/Landscape override when set — so
  /// the builder can honor the preview's orientation toggle.
  final Future<Uint8List> Function(PdfPageFormat? pageFormat)?
      customBytesBuilderWithFormat;

  /// Phase K Shot 3b-core: explicit page format override chosen in the
  /// preview modal (Portrait/Landscape). Null = use [naturalPageFormat].
  final PdfPageFormat? pageFormatOverride;

  /// The page format this report naturally renders in (its shipped default,
  /// e.g. A4 for a biodata, A4-landscape for a wide ledger). Used as the
  /// orientation fallback when no override is set.
  final PdfPageFormat naturalPageFormat;

  /// Phase K-6 Run 2b: when true, the preview modal's Portrait/Landscape
  /// toggle renders DISABLED (the report's column layout is designed for
  /// its natural format and garbles in the other orientation — e.g. the
  /// 10-column defaulter roster in A4 portrait). The generator also pins
  /// the page format belt-and-braces. Default false: every other report
  /// type keeps its honor-override behavior.
  final bool locksOrientation;

  const ReportRequest({
    required this.type,
    this.id,
    this.titleOverride,
    this.subtitle,
    this.fileNameOverride,
    this.vouchers,
    this.extraParams = const {},
    this.customBytesBuilder,
    this.customBytesBuilderWithFormat,
    this.pageFormatOverride,
    this.naturalPageFormat = PdfPageFormat.a4,
    this.locksOrientation = false,
  });

  ReportRequest copyWith({
    Future<Uint8List> Function()? customBytesBuilder,
    Future<Uint8List> Function(PdfPageFormat?)? customBytesBuilderWithFormat,
    PdfPageFormat? pageFormatOverride,
    bool clearPageFormatOverride = false,
    PdfPageFormat? naturalPageFormat,
    bool? locksOrientation,
  }) {
    return ReportRequest(
      type: type,
      id: id,
      titleOverride: titleOverride,
      subtitle: subtitle,
      fileNameOverride: fileNameOverride,
      vouchers: vouchers,
      extraParams: extraParams,
      customBytesBuilder: customBytesBuilder ?? this.customBytesBuilder,
      customBytesBuilderWithFormat:
          customBytesBuilderWithFormat ?? this.customBytesBuilderWithFormat,
      pageFormatOverride: clearPageFormatOverride
          ? null
          : (pageFormatOverride ?? this.pageFormatOverride),
      naturalPageFormat: naturalPageFormat ?? this.naturalPageFormat,
      locksOrientation: locksOrientation ?? this.locksOrientation,
    );
  }

  String get effectiveTitle => titleOverride ?? type.displayName;

  String get effectiveFileName =>
      fileNameOverride ??
      (id != null && id!.isNotEmpty
          ? '${type.path}_$id.pdf'
          : type.defaultFileName);
}
