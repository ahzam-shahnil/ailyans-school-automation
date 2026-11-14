import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:school_automation/core/utils/attendance_pdf_generator.dart';
import 'package:school_automation/core/utils/award_certificate_pdf_generator.dart';
import 'package:school_automation/core/utils/biodata_pdf_generator.dart';
import 'package:school_automation/core/utils/class_syllabus_pdf_generator.dart';
import 'package:school_automation/core/utils/daily_collection_pdf_generator.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';
import 'package:school_automation/core/utils/exam_award_list_pdf_generator.dart';
import 'package:school_automation/core/utils/exam_marksheet_pdf_generator.dart';
import 'package:school_automation/core/utils/exam_summary_pdf_generator.dart';
import 'package:school_automation/core/utils/fee_schedule_pdf_generator.dart';
import 'package:school_automation/core/utils/library_catalog_pdf_generator.dart';
import 'package:school_automation/core/utils/receipt_pdf_generator.dart';
import 'package:school_automation/core/utils/salary_slip_pdf_generator.dart';
import 'package:school_automation/core/utils/slc_pdf_generator.dart';
import 'package:school_automation/core/utils/slc_register_pdf_generator.dart';
import 'package:school_automation/core/utils/teacher_attendance_register_pdf_generator.dart';
import 'package:school_automation/core/utils/teacher_biodata_pdf_generator.dart';
import 'package:school_automation/core/utils/voucher_pdf_generator.dart';
import 'package:school_automation/models/fee_receipt_view.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ReportPreviewState {
  final bool isLoading;
  final Uint8List? bytes;
  final String? error;

  const ReportPreviewState({this.isLoading = false, this.bytes, this.error});

  ReportPreviewState copyWith({
    bool? isLoading,
    Uint8List? bytes,
    String? error,
    bool clearBytes = false,
    bool clearError = false,
  }) {
    return ReportPreviewState(
      isLoading: isLoading ?? this.isLoading,
      bytes: clearBytes ? null : (bytes ?? this.bytes),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ReportPreviewNotifier extends StateNotifier<ReportPreviewState> {
  final ReportRequest request;

  // Tracks the selected voucher mode: 0 = Three-Copy Slips, 1 = Cohort Ledger.
  // Only meaningful when request.type == ReportType.feeVoucher.
  int _feeVoucherMode = 0;

  ReportPreviewNotifier(this.request)
    : super(const ReportPreviewState(isLoading: true)) {
    generate();
  }

  Future<void> generate() async {
    state = const ReportPreviewState(isLoading: true);
    try {
      final Uint8List bytes;

      if (request.customBytesBuilder != null) {
        bytes = await request.customBytesBuilder!();
      } else {
        bytes = await _generateByType();
      }

      if (mounted) {
        state = ReportPreviewState(bytes: bytes);
      }
    } catch (e, st) {
      if (mounted) {
        state = ReportPreviewState(error: 'Failed to generate PDF: $e\n$st');
      }
    }
  }

  Future<Uint8List> _generateByType() async {
    switch (request.type) {
      case ReportType.feeVoucher:
        return _generateFeeVoucher(_feeVoucherMode);
      case ReportType.feeReceipt:
        return _generateFeeReceipt();
      case ReportType.biodata:
        return _generateBiodata();
      case ReportType.defaulterList:
        return _generateDefaulterList();
      case ReportType.attendanceRegister:
        return _generateAttendanceRegister();
      case ReportType.slc:
        return _generateSlc();
      case ReportType.feeSchedule:
        return _generateFeeSchedule();
      case ReportType.teacherBiodata:
        return _generateTeacherBiodata();
      case ReportType.classSyllabus:
        return _generateClassSyllabus();
      case ReportType.slcRegister:
        return _generateSlcRegister();
      case ReportType.salarySlip:
        return _generateSalarySlip();
      case ReportType.salaryRegister:
        return _generateSalaryRegister();
      case ReportType.dailyCollection:
        return _generateDailyCollection();
      case ReportType.examMarksheet:
        return _generateExamMarksheet();
      case ReportType.examSummary:
        return _generateExamSummary();
      case ReportType.libraryCatalog:
        return _generateLibraryCatalog();
      case ReportType.examAwardList:
        return _generateExamAwardList();
      case ReportType.teacherAttendanceRegister:
        return _generateTeacherAttendanceRegister();
      case ReportType.awardCertificate:
        return _generateAwardCertificate();
      case ReportType.studentMarksheet:
        return _generateStudentMarksheet();
      case ReportType.feeCollectionRegister:
        return _generateFeeCollectionRegister();
      case ReportType.classDefaulters:
        return _generateClassDefaulters();
      case ReportType.examStatus:
        return _generateExamStatus();
      case ReportType.classCollectionSummary:
        return _generateClassCollectionSummary();
    }
  }

  /// Switches the voucher layout mode and re-generates the PDF.
  /// mode 0 = Three-Copy Slips, mode 1 = Cohort Ledger.
  /// No-op for non-feeVoucher request types.
  Future<void> regenerateWithMode(int mode) async {
    if (mode != 0 && mode != 1) return;
    _feeVoucherMode = mode;
    if (!mounted) return;
    state = const ReportPreviewState(isLoading: true);
    try {
      final bytes = await _generateFeeVoucher(mode);
      if (mounted) {
        state = ReportPreviewState(bytes: bytes);
      }
    } catch (e, st) {
      if (mounted) {
        state = ReportPreviewState(error: 'Failed to generate PDF: $e\n$st');
      }
    }
  }

  String _safeBranchName() {
    final raw = request.extraParams['branchName']?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return '-';
  }

  String _safeBranchAddress() {
    final raw = request.extraParams['branchAddress']?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return '-';
  }

  Future<Uint8List> _generateFeeVoucher(int mode) async {
    // Shot 2c fix: bank details are no longer hard-required. Missing or
    // blank extraParams fall back to the school's standard bank block so
    // voucher printing can never crash with 'Missing required extraParam'.
    String safeExtra(String key, String fallback) {
      final raw = request.extraParams[key]?.toString();
      if (raw != null && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    final bankName = safeExtra('bankName', 'Askari Bank Limited');
    final bankBranch = safeExtra('bankBranch', 'Ballo Khel Road');
    final bankAcctNo = safeExtra('bankAcctNo', '4528');

    final voucherList = request.vouchers;
    if (voucherList == null || voucherList.isEmpty) {
      throw ArgumentError('feeVoucher requires a non-empty vouchers list.');
    }

    final vouchers = voucherList.cast<FeeReceiptView>();
    final branchName = _safeBranchName();
    final branchAddress = _safeBranchAddress();

    if (mode == 0) {
      // Three-Copy Slips (one page per student, 3 columns: Student/School/Bank)
      return ThreeCopyVouchersPdf.generate(
        vouchers: vouchers,
        branchName: branchName,
        branchAddress: branchAddress,
        bankName: bankName,
        bankBranch: bankBranch,
        bankAcctNo: bankAcctNo,
      );
    } else {
      // Cohort Ledger — summary table of all vouchers
      return FeeLedgerVoucherGenerator(
        institutionName: branchName,
        ledgerPeriodTitle:
            'Cohort Ledger - ${vouchers.isNotEmpty ? vouchers.first.forMonth : ""}',
        transactions: vouchers
            .map(
              (v) => FeeVoucherTransactionRecord.fromFeeReceipt(
                v,
                className: v.className ?? '',
              ),
            )
            .toList(),
      ).generatePdf();
    }
  }

  Future<Uint8List> _generateFeeReceipt() async {
    final receiptList = request.vouchers;
    if (receiptList == null || receiptList.isEmpty) {
      throw ArgumentError('feeReceipt requires a non-empty vouchers list.');
    }

    return ReceiptPdfGenerator.generateThreeCopyReceipts(
      receipts: receiptList.cast<FeeReceiptPrintData>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateBiodata() async {
    if (request.vouchers == null || request.vouchers!.isEmpty) {
      throw StateError('No student data provided for biodata preview.');
    }
    final data = request.vouchers!.first as StudentBiodataPrintData;
    return BiodataPdfGenerator.generateStudentBiodata(
      data: data,
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
      branchPhone: request.extraParams['branchPhone'] as String?,
      branchPrincipal: request.extraParams['branchPrincipal'] as String?,
    );
  }

  Future<Uint8List> _generateAttendanceRegister() async {
    final data = request.extraParams['attendanceData'] as AttendancePdfData?;
    if (data == null) {
      throw StateError('Missing attendanceData in extraParams.');
    }
    final safeName = data.branchName.trim().isNotEmpty
        ? data.branchName.trim()
        : _safeBranchName();
    final safeAddress = data.branchAddress.trim().isNotEmpty
        ? data.branchAddress.trim()
        : _safeBranchAddress();

    final safeData =
        (safeName != data.branchName || safeAddress != data.branchAddress)
        ? AttendancePdfData(
            branchName: safeName,
            branchAddress: safeAddress,
            branchPhone: data.branchPhone,
            branchPrincipal: data.branchPrincipal,
            className: data.className,
            sectionName: data.sectionName,
            teacherName: data.teacherName,
            sessionYear: data.sessionYear,
            attDate: data.attDate,
            roster: data.roster,
            presentCount: data.presentCount,
            absentCount: data.absentCount,
            leaveCount: data.leaveCount,
            lateCount: data.lateCount,
            totalCount: data.totalCount,
          )
        : data;

    return buildAttendancePdf(safeData);
  }

  Future<Uint8List> _generateDefaulterList() async {
    if (request.vouchers == null || request.vouchers!.isEmpty) {
      throw StateError('No defaulter groups provided for preview.');
    }
    final summary =
        request.extraParams['summary'] as DefaulterListFilterSummary?;
    if (summary == null) {
      throw StateError('Missing summary in extraParams for defaulterList.');
    }
    final groups = request.vouchers!.cast<DefaulterClassGroup>();
    return DefaulterListPdfGenerator.generate(
      groups: groups,
      summary: summary,
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
      branchPhone: request.extraParams['branchPhone'] as String?,
      branchPrincipal: request.extraParams['branchPrincipal'] as String?,
    );
  }

  Future<Uint8List> _generateSlc() async {
    final data =
        (request.extraParams['slcData'] as Map<String, dynamic>?) ??
        (request.extraParams.containsKey('studentName') ||
                request.extraParams.containsKey('name') ||
                request.extraParams.containsKey('stuRegId') ||
                request.extraParams.containsKey('Stu_Name')
            ? request.extraParams
            : null);
    if (data == null) {
      throw StateError('Missing slcData in extraParams for slc report.');
    }
    return SlcPdfGenerator.generate(
      slcData: data,
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateFeeSchedule() async {
    final rows = request.extraParams['feeRows'] as List<dynamic>?;
    if (rows == null) {
      throw StateError(
        'Missing feeRows in extraParams for feeSchedule report.',
      );
    }
    return FeeSchedulePdfGenerator.generate(
      feeRows: rows.cast<Map<String, dynamic>>(),
      sessionYear: request.extraParams['sessionYear'] as String? ?? '',
      className: request.extraParams['className'] as String? ?? '',
      branchName: _safeBranchName(),
    );
  }

  Future<Uint8List> _generateTeacherBiodata() async {
    final data = request.extraParams['teacherData'] as Map<String, dynamic>?;
    if (data == null) throw StateError('Missing teacherData in extraParams');
    return TeacherBiodataPdfGenerator.generate(
      teacherData: data,
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateClassSyllabus() async {
    final subjects = request.extraParams['subjects'] as List<dynamic>?;
    if (subjects == null || subjects.isEmpty) {
      throw StateError(
        'Missing or empty subjects in extraParams for classSyllabus.',
      );
    }
    return ClassSyllabusPdfGenerator.generate(
      className: request.extraParams['className'] as String? ?? '',
      sessionYear: request.extraParams['sessionYear'] as String? ?? '',
      subjects: subjects.cast<Map<String, dynamic>>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateSlcRegister() async {
    final leavers = request.extraParams['leavers'] as List<dynamic>?;
    if (leavers == null || leavers.isEmpty) {
      throw StateError(
        'Missing or empty leavers in extraParams for slcRegister.',
      );
    }
    return SlcRegisterPdfGenerator.generate(
      sessionYear: request.extraParams['sessionYear'] as String? ?? '',
      leavers: leavers.cast<Map<String, dynamic>>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateSalarySlip() async {
    final data = request.extraParams['salaryData'] as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing salaryData in extraParams for salarySlip.');
    }
    return SalarySlipPdfGenerator.generateSlip(
      salaryData: data,
      branchName: _safeBranchName(),
    );
  }

  Future<Uint8List> _generateSalaryRegister() async {
    final salaries = request.extraParams['salaries'] as List<dynamic>?;
    if (salaries == null || salaries.isEmpty) {
      throw StateError(
        'Missing or empty salaries in extraParams for salaryRegister.',
      );
    }
    return SalarySlipPdfGenerator.generateRegister(
      salaries: salaries.cast<Map<String, dynamic>>(),
      month: request.extraParams['month'] as String? ?? '',
      branchName: _safeBranchName(),
    );
  }

  Future<Uint8List> _generateDailyCollection() async {
    final collections = request.extraParams['collections'] as List<dynamic>?;
    if (collections == null || collections.isEmpty) {
      throw StateError(
        'Missing or empty collections in extraParams for dailyCollection.',
      );
    }
    return DailyCollectionPdfGenerator.generate(
      date: request.extraParams['date'] as String? ?? '',
      collections: collections.cast<Map<String, dynamic>>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateExamMarksheet() async {
    final students = request.extraParams['students'] as List<dynamic>?;
    if (students == null || students.isEmpty) {
      throw StateError(
        'Missing or empty students in extraParams for examMarksheet.',
      );
    }
    return ExamMarksheetPdfGenerator.generate(
      examName: request.extraParams['examName'] as String? ?? '',
      className: request.extraParams['className'] as String? ?? '',
      students: students.cast<Map<String, dynamic>>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateExamSummary() async {
    final subjects = request.extraParams['subjects'] as List<dynamic>?;
    if (subjects == null || subjects.isEmpty) {
      throw StateError(
        'Missing or empty subjects in extraParams for examSummary.',
      );
    }
    return ExamSummaryPdfGenerator.generate(
      examName: request.extraParams['examName'] as String? ?? '',
      subjects: subjects.cast<Map<String, dynamic>>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateLibraryCatalog() async {
    final books = request.extraParams['books'] as List<dynamic>?;
    if (books == null || books.isEmpty) {
      throw StateError(
        'Missing or empty books in extraParams for libraryCatalog.',
      );
    }
    return LibraryCatalogPdfGenerator.generate(
      books: books.cast<Map<String, dynamic>>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateExamAwardList() async {
    final students = request.extraParams['students'] as List<dynamic>?;
    if (students == null || students.isEmpty) {
      throw StateError(
        'Missing or empty students in extraParams for examAwardList.',
      );
    }
    return ExamAwardListPdfGenerator.generate(
      examName: request.extraParams['examName'] as String? ?? '',
      className: request.extraParams['className'] as String? ?? '',
      students: students.cast<Map<String, dynamic>>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateTeacherAttendanceRegister() async {
    final staff =
        request.extraParams['staffAttendance'] as List<dynamic>?;
    if (staff == null || staff.isEmpty) {
      throw StateError(
        'Missing or empty staffAttendance in extraParams for teacherAttendanceRegister.',
      );
    }
    return TeacherAttendanceRegisterPdfGenerator.generate(
      month: request.extraParams['month'] as String? ?? '',
      staffAttendance: staff.cast<Map<String, dynamic>>(),
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateAwardCertificate() async {
    final student =
        request.extraParams['student'] as Map<String, dynamic>?;
    final rank = (request.extraParams['rank'] as num?)?.toInt() ?? 0;
    if (student == null) {
      throw StateError(
        'Missing student in extraParams for awardCertificate.',
      );
    }
    if (rank <= 0) {
      throw StateError(
        'Invalid or missing rank in extraParams for awardCertificate (must be > 0).',
      );
    }
    return AwardCertificatePdfGenerator.generate(
      examName: request.extraParams['examName'] as String? ?? 'Examination',
      className: request.extraParams['className'] as String? ?? 'Class',
      student: student,
      rank: rank,
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
    );
  }

  Future<Uint8List> _generateStudentMarksheet() async {
    final subjects = request.extraParams['subjects'] as List<dynamic>?;
    if (subjects == null || subjects.isEmpty) {
      throw StateError(
        'Missing or empty subjects in extraParams for studentMarksheet.',
      );
    }
    final studentName =
        request.extraParams['studentName'] as String? ?? 'Student';
    final examName =
        request.extraParams['examName'] as String? ?? 'Examination';
    final className =
        request.extraParams['className'] as String? ?? 'Class';
    final branchName = _safeBranchName();
    final branchAddress = _safeBranchAddress();

    final doc = pw.Document();
    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              branchName.toUpperCase(),
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 14,
                color: ReportTheme.primaryColor,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (branchAddress.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                branchAddress,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 8,
                  color: ReportTheme.secondaryColor,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: const pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border(
                  top: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
                  bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'STUDENT MARKSHEET - $examName',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                  pw.Text(
                    'Student: $studentName | Class: $className',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      color: ReportTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => ReportTheme.buildStandardFooter(
          context,
          branchName: branchName,
        ),
        build: (context) {
          final rows = subjects.cast<Map<String, dynamic>>();
          return [
            pw.TableHelper.fromTextArray(
              headers: ['Subject', 'Obtained', 'Total', 'Grade', 'Result'],
              data: rows.map((r) {
                final subj = r['subject']?.toString() ?? '';
                final obtained = r['obtained']?.toString() ?? '0';
                final total = r['total']?.toString() ?? '0';
                final grade = r['grade']?.toString() ?? '';
                final result = r['pass']?.toString() ?? r['result']?.toString() ?? '';
                return [subj, obtained, total, grade, result];
              }).toList(),
              border: pw.TableBorder.all(
                color: ReportTheme.borderRuleColor,
                width: 0.5,
              ),
              headerStyle: ReportTheme.tableHeaderStyle,
              headerDecoration: const pw.BoxDecoration(
                color: ReportTheme.primaryColor,
              ),
              cellStyle: ReportTheme.tableCellStyle,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              rowDecoration: const pw.BoxDecoration(
                color: ReportTheme.tableRowAltBg,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _generateFeeCollectionRegister() async {
    final collections = request.extraParams['collections'] as List<dynamic>?;
    if (collections == null || collections.isEmpty) {
      throw StateError(
        'Missing or empty collections in extraParams for feeCollectionRegister.',
      );
    }
    final date = request.extraParams['date'] as String? ?? '';
    final branchName = _safeBranchName();
    final branchAddress = _safeBranchAddress();

    final doc = pw.Document();
    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();

    final rows = collections.cast<Map<String, dynamic>>();
    num totalAmount = 0;
    for (final r in rows) {
      final amt = r['amount'];
      if (amt is num) {
        totalAmount += amt;
      } else if (amt != null) {
        totalAmount += num.tryParse(amt.toString()) ?? 0;
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              branchName.isNotEmpty ? branchName.toUpperCase() : 'SCHOOL AUTOMATION',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 14,
                color: ReportTheme.primaryColor,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (branchAddress.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                branchAddress,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 8,
                  color: ReportTheme.secondaryColor,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: const pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border(
                  top: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
                  bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DAILY COLLECTION LEDGER',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                  if (date.isNotEmpty)
                    pw.Text(
                      'Date: $date',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 9,
                        color: ReportTheme.secondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => ReportTheme.buildStandardFooter(
          context,
          branchName: branchName,
        ),
        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              headers: [
                'Time',
                'Student Name',
                'Class',
                'Voucher ID',
                'Amount',
                'Bank',
                'Collected By',
              ],
              data: rows.map((r) {
                final time = r['time']?.toString() ?? '';
                final student = r['studentName']?.toString() ??
                    r['student']?.toString() ??
                    '';
                final className = r['className']?.toString() ??
                    r['class']?.toString() ??
                    '';
                final voucher = r['voucherId']?.toString() ??
                    r['voucherNo']?.toString() ??
                    '';
                final amt = r['amount'] is num
                    ? ReportTheme.formatCurrency(r['amount'] as num)
                    : (r['amount']?.toString() ?? '0.00');
                final bank = r['bank']?.toString() ?? '';
                final collectedBy = r['collectedBy']?.toString() ?? '';
                return [
                  time,
                  student,
                  className,
                  voucher,
                  amt,
                  bank,
                  collectedBy,
                ];
              }).toList(),
              border: pw.TableBorder.all(
                color: ReportTheme.borderRuleColor,
                width: 0.5,
              ),
              headerStyle: ReportTheme.tableHeaderStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: ReportTheme.tableCellStyle,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerLeft,
                6: pw.Alignment.centerLeft,
              },
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerLeft,
                6: pw.Alignment.centerLeft,
              },
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border.all(
                  color: ReportTheme.borderRuleColor,
                  width: 0.5,
                ),
              ),
              child: pw.Text(
                'TOTAL COLLECTED: Rs. ${ReportTheme.formatCurrency(totalAmount)}',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: ReportTheme.successTextColor,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _generateClassCollectionSummary() async {
    final rowsData = (request.extraParams['rows'] as List<dynamic>?) ??
        (request.extraParams['summaryRows'] as List<dynamic>?) ??
        (request.extraParams['classes'] as List<dynamic>?);
    if (rowsData == null || rowsData.isEmpty) {
      throw StateError(
        'Missing or empty rows in extraParams for classCollectionSummary.',
      );
    }
    final month = request.extraParams['month'] as String? ?? '';
    final sessionYr = request.extraParams['sessionYr'] as String? ?? '';
    final branchName = _safeBranchName();
    final branchAddress = _safeBranchAddress();

    final doc = pw.Document();
    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();

    final rows = rowsData.cast<Map<String, dynamic>>();
    int totalBilled = 0;
    num totalGross = 0;
    num totalDisc = 0;
    num totalColl = 0;
    num totalDues = 0;

    for (final r in rows) {
      totalBilled += (r['billedCount'] as num?)?.toInt() ??
          (r['totalBilled'] as num?)?.toInt() ??
          0;
      totalGross += (r['gross'] as num?) ??
          (r['grossReceivable'] as num?) ??
          0;
      totalDisc += (r['discounts'] as num?) ??
          (r['totalDiscounts'] as num?) ??
          0;
      totalColl += (r['collected'] as num?) ??
          (r['cashCollected'] as num?) ??
          0;
      totalDues += (r['dues'] as num?) ??
          (r['outstandingDues'] as num?) ??
          0;
    }
    final overallPct = totalGross > 0
        ? ((totalColl / totalGross) * 100).toStringAsFixed(1)
        : '0.0';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              branchName.isNotEmpty ? branchName.toUpperCase() : 'SCHOOL AUTOMATION',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 14,
                color: ReportTheme.primaryColor,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (branchAddress.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                branchAddress,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 8,
                  color: ReportTheme.secondaryColor,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: const pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border(
                  top: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
                  bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CLASS COLLECTION SUMMARY',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                  pw.Text(
                    [
                      if (month.isNotEmpty) 'Month: $month',
                      if (sessionYr.isNotEmpty) 'Session: $sessionYr',
                    ].join(' | '),
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      color: ReportTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => ReportTheme.buildStandardFooter(
          context,
          branchName: branchName,
        ),
        build: (context) {
          final tableData = rows.map((r) {
            final cls = (r['className'] as String?) ?? 'Unknown';
            final billed = ((r['billedCount'] as num?)?.toInt() ??
                    (r['totalBilled'] as num?)?.toInt() ??
                    0)
                .toString();
            final gross = ReportTheme.formatCurrency(
                (r['gross'] as num?) ?? (r['grossReceivable'] as num?) ?? 0);
            final disc = ReportTheme.formatCurrency((r['discounts'] as num?) ??
                (r['totalDiscounts'] as num?) ??
                0);
            final coll = ReportTheme.formatCurrency((r['collected'] as num?) ??
                (r['cashCollected'] as num?) ??
                0);
            final dues = ReportTheme.formatCurrency(
                (r['dues'] as num?) ?? (r['outstandingDues'] as num?) ?? 0);
            final pct = r['recoveryPercent']?.toString() ?? '0.0';
            final pctStr = pct.endsWith('%') ? pct : '$pct%';
            return [cls, billed, gross, disc, coll, dues, pctStr];
          }).toList();

          return [
            pw.TableHelper.fromTextArray(
              headers: [
                'Class',
                'Billed',
                'Gross',
                'Discounts',
                'Collected',
                'Dues',
                'Recovery %',
              ],
              data: tableData,
              border: pw.TableBorder.all(
                color: ReportTheme.borderRuleColor,
                width: 0.5,
              ),
              headerStyle: ReportTheme.tableHeaderStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: ReportTheme.tableCellStyle,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border.all(color: ReportTheme.borderRuleColor, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTALS: Billed: $totalBilled | Gross: Rs. ${ReportTheme.formatCurrency(totalGross)} | Discounts: Rs. ${ReportTheme.formatCurrency(totalDisc)}',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 8.5,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                  pw.Text(
                    'Collected: Rs. ${ReportTheme.formatCurrency(totalColl)} | Dues: Rs. ${ReportTheme.formatCurrency(totalDues)} | Recovery: $overallPct%',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 8.5,
                      color: ReportTheme.successTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _generateClassDefaulters() async {
    final rawGroups = (request.extraParams['groups'] as List<dynamic>?) ??
        (request.extraParams['defaulterGroups'] as List<dynamic>?) ??
        request.vouchers;
    if (rawGroups == null || rawGroups.isEmpty) {
      throw StateError(
        'No defaulter groups provided for classDefaulters preview.',
      );
    }
    final summary =
        request.extraParams['summary'] as DefaulterListFilterSummary?;
    if (summary == null) {
      throw StateError(
        'Missing summary in extraParams for classDefaulters.',
      );
    }
    final groups = rawGroups.cast<DefaulterClassGroup>();
    return DefaulterListPdfGenerator.generate(
      groups: groups,
      summary: summary,
      branchName: _safeBranchName(),
      branchAddress: _safeBranchAddress(),
      branchPhone: request.extraParams['branchPhone'] as String?,
      branchPrincipal: request.extraParams['branchPrincipal'] as String?,
    );
  }

  Future<Uint8List> _generateExamStatus() async {
    final subjects = request.extraParams['subjects'] as List<dynamic>?;
    if (subjects == null || subjects.isEmpty) {
      throw StateError(
        'Missing or empty subjects in extraParams for examStatus.',
      );
    }
    final examName =
        request.extraParams['examName'] as String? ?? 'Examination';
    final branchName = _safeBranchName();
    final branchAddress = _safeBranchAddress();

    final doc = pw.Document();
    final boldFont = pw.Font.helveticaBold();
    final regularFont = pw.Font.helvetica();

    final rows = subjects.cast<Map<String, dynamic>>();
    int totalEnrolled = 0;
    int totalAppeared = 0;
    int totalPassed = 0;
    int totalFailed = 0;

    for (final r in rows) {
      totalEnrolled += (r['enrolled'] as num?)?.toInt() ?? 0;
      totalAppeared += (r['appeared'] as num?)?.toInt() ?? 0;
      totalPassed += (r['passed'] as num?)?.toInt() ?? 0;
      totalFailed += (r['failed'] as num?)?.toInt() ?? 0;
    }
    final overallPassPct = totalAppeared > 0
        ? (totalPassed * 100.0 / totalAppeared).toStringAsFixed(1)
        : '0.0';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              branchName.toUpperCase(),
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 14,
                color: ReportTheme.primaryColor,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (branchAddress.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                branchAddress,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 8,
                  color: ReportTheme.secondaryColor,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: const pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border(
                  top: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
                  bottom: pw.BorderSide(color: ReportTheme.primaryColor, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'EXAM STATUS REPORT - $examName',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 10,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                  pw.Text(
                    'Subjects: ${rows.length}',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      color: ReportTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => ReportTheme.buildStandardFooter(
          context,
          branchName: branchName,
        ),
        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              headers: [
                'Subject',
                'Enrolled',
                'Appeared',
                'Passed',
                'Failed',
                'Pass %',
              ],
              data: rows.map((r) {
                final subj = r['subject']?.toString() ?? '';
                final enrolled = (r['enrolled'] ?? 0).toString();
                final appeared = (r['appeared'] ?? 0).toString();
                final passed = (r['passed'] ?? 0).toString();
                final failed = (r['failed'] ?? 0).toString();
                final rawPct = r['passPercent']?.toString() ??
                    r['passPercentage']?.toString() ??
                    '0.0';
                final passPercent = rawPct.endsWith('%') ? rawPct : '$rawPct%';
                return [subj, enrolled, appeared, passed, failed, passPercent];
              }).toList(),
              border: pw.TableBorder.all(
                color: ReportTheme.borderRuleColor,
                width: 0.5,
              ),
              headerStyle: ReportTheme.tableHeaderStyle,
              headerDecoration: const pw.BoxDecoration(
                color: ReportTheme.primaryColor,
              ),
              cellStyle: ReportTheme.tableCellStyle,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              rowDecoration: const pw.BoxDecoration(
                color: ReportTheme.tableRowAltBg,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: ReportTheme.bannerBgColor,
                border: pw.Border.all(color: ReportTheme.borderRuleColor, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Overall Totals:',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                  pw.Text(
                    'Enrolled: $totalEnrolled  |  Appeared: $totalAppeared  |  Passed: $totalPassed  |  Failed: $totalFailed  |  Pass: $overallPassPct%',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      color: ReportTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final reportPreviewProvider = StateNotifierProvider.autoDispose
    .family<ReportPreviewNotifier, ReportPreviewState, ReportRequest>(
      (ref, request) => ReportPreviewNotifier(request),
    );
