import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/student.dart';
import '../../models/student_enrollment.dart';
import '../../models/student_voucher.dart';
import '../db/database.dart';
import '../utils/biodata_pdf_generator.dart';

/// Aggregated data bundle for the 360-degree Student Profile Workstation.
class StudentProfileBundle {
  final Student student;
  final List<StudentEnrollment> enrollments;
  final List<StudentVoucher> vouchers;
  final int totalBilled;
  final int totalPaid;
  final int outstandingArrears;
  final int classRollNo;
  final String currentClassName;
  final String currentSectionName;
  final String fatherName;
  final String mobile1;
  final String feeBalanceSummary;
  final List<Map<String, dynamic>> advances;
  final List<Map<String, dynamic>> exams;
  final List<Map<String, dynamic>> attendance;

  const StudentProfileBundle({
    required this.student,
    required this.enrollments,
    required this.vouchers,
    required this.totalBilled,
    required this.totalPaid,
    required this.outstandingArrears,
    required this.classRollNo,
    required this.currentClassName,
    required this.currentSectionName,
    required this.fatherName,
    required this.mobile1,
    required this.feeBalanceSummary,
    required this.advances,
    required this.exams,
    required this.attendance,
  });
}

/// Provider managing active tab index on the student profile (0..6).
final selectedStudentTabProvider = StateProvider<int>((ref) => 0);

/// Provider controlling whether the student profile is in View Mode (false) or Edit Mode (true).
final studentEditModeProvider = StateProvider<bool>((ref) => false);

/// Riverpod FutureProvider.family fetching all student profile data by registration ID.
final studentProfileProvider = FutureProvider.family<StudentProfileBundle, int>(
  (ref, stuRegId) async {
    final db = await DatabaseService.instance.database;

    // 1. Fetch student demographic record
    final studentRows = await db.query(
      'Stu_Reg',
      where: 'Stu_RegID = ?',
      whereArgs: [stuRegId],
      limit: 1,
    );

    if (studentRows.isEmpty) {
      throw Exception('Student not found');
    }

    final student = Student.fromMap(studentRows.first);

    // 2. Fetch academic enrollment history
    final enrollmentRows = await db.rawQuery(
      '''
    SELECT sc.*, c.CName, cs.SecName 
    FROM Student_Class sc
    JOIN Class c ON sc.ClassID = c.ClassID
    LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
    WHERE sc.Stu_RegID = ?
    ORDER BY sc.SessionYr DESC
    ''',
      [stuRegId],
    );

    final enrollments = enrollmentRows
        .map((r) => StudentEnrollment.fromMap(r))
        .toList();

    // Current enrollment metadata
    final currentEnrollment = enrollments.isNotEmpty ? enrollments.first : null;
    final classRollNo = currentEnrollment?.classRollNo ?? 0;
    final currentClassName =
        currentEnrollment?.className ??
        (student.admInClass != null
            ? 'Class ${student.admInClass}'
            : (student.admClass != null
                  ? 'Class ${student.admClass}'
                  : 'Unassigned'));
    final currentSectionName = currentEnrollment?.sectionName ?? 'A';

    // 3. Fetch vouchers with payment transactions
    final voucherRows = await db.rawQuery(
      '''
    SELECT vm.VoucherMasID, vm.VDate, vm.Student_Class_StuRegID, vm.SubTotal, 
           vm.ForMonth, vm.ClassID, vm.Remarks, vm.Discount, vm.DueDate, vm.IsPaid, 
           vm.SessionYr, ft.PaidAmount, ft.SubmissionDate
    FROM VoucharMas vm
    LEFT JOIN FeeTransaction ft ON vm.VoucherMasID = ft.VoucharNo
    WHERE vm.Student_Class_StuRegID = ?
    ORDER BY vm.VDate DESC
    ''',
      [stuRegId],
    );

    final vouchers = voucherRows.map((r) => StudentVoucher.fromMap(r)).toList();

    // 4. Financial calculations
    int totalBilled = 0;
    int totalPaid = 0;

    for (final v in vouchers) {
      totalBilled += v.subtotal;
      if (v.paidAmount != null && v.paidAmount! > 0) {
        totalPaid += v.paidAmount!;
      } else if (v.isPaid == 'Y') {
        totalPaid += (v.subtotal - v.discount);
      }
    }

    final outstandingArrears = totalBilled - totalPaid;
    final currencyFormat = NumberFormat('#,##0');

    final feeBalanceSummary = outstandingArrears <= 0
        ? 'Rs. 0.00 (All clear)'
        : 'Rs. ${currencyFormat.format(outstandingArrears)} outstanding';

    // 5. Fetch Advances
    final advanceRows = await db.query(
      'StuAdv',
      where: 'StuRegID = ?',
      whereArgs: [stuRegId],
      orderBy: 'Date DESC',
    );

    // 6. Fetch Exams
    final examRows = await db.rawQuery(
      '''
    SELECT em.ExamMasID, em.ExamInfoID, em.ExTermID, em.ClassID, em.ClassSecID,
           em.Stu_RegID, em.SessionYr, et.TermName,
           ed.ObtainedMarks, ed.TotalMarks
    FROM ExamMas em
    LEFT JOIN ExamTerm et ON em.ExTermID = et.ExTermID
    LEFT JOIN ExamDet ed ON em.ExamMasID = ed.ExamMasID
    WHERE em.Stu_RegID = ?
    ORDER BY em.SessionYr DESC
    ''',
      [stuRegId],
    );

    // 7. Fetch Attendance
    final attendanceRows = await db.rawQuery(
      '''
    SELECT ad.AttDetID, ad.AttMasID, ad.Stu_RegID, ad.AttStatus,
           ad.AttRemarks, am.AttDate, am.StudySessionYr
    FROM AttDet ad
    JOIN AttMas am ON ad.AttMasID = am.AttMasID
    WHERE ad.Stu_RegID = ?
    ORDER BY am.AttDate DESC
    ''',
      [stuRegId],
    );

    return StudentProfileBundle(
      student: student,
      enrollments: enrollments,
      vouchers: vouchers,
      totalBilled: totalBilled,
      totalPaid: totalPaid,
      outstandingArrears: outstandingArrears,
      classRollNo: classRollNo,
      currentClassName: currentClassName,
      currentSectionName: currentSectionName,
      fatherName: student.fName ?? '—',
      mobile1: student.mobile1 ?? '—',
      feeBalanceSummary: feeBalanceSummary,
      advances: advanceRows,
      exams: examRows,
      attendance: attendanceRows,
    );
  },
);

/// Function signature for saving an updated student profile to persistence.
typedef StudentProfileSaver = Future<void> Function(Student student);

/// Riverpod provider delivering the profile saving function.
final studentProfileSaverProvider = Provider<StudentProfileSaver>((ref) {
  return (student) => saveStudentProfile(student);
});

/// Helper to persist modified student record to SQLite.
Future<void> saveStudentProfile(Student updatedStudent) async {
  final db = await DatabaseService.instance.database;
  await db.update(
    'Stu_Reg',
    updatedStudent.toMap(),
    where: 'Stu_RegID = ?',
    whereArgs: [updatedStudent.stuRegId],
  );
}

/// Builds student biodata print model from profile bundle, SQLite enrollments and fee vouchers.
Future<StudentBiodataPrintData> buildBiodataPrintData(
  int stuRegId,
  WidgetRef ref,
) async {
  // Read the bundle from studentProfileProvider.family(stuRegId).future
  final bundle = await ref.read(studentProfileProvider(stuRegId).future);

  final student = bundle.student;
  final enrollments = bundle.enrollments;

  // Load fee summary
  final db = await DatabaseService.instance.database;
  final feeRows = await db.rawQuery(
    '''
    SELECT COALESCE(SUM(SubTotal), 0) as total_billed,
           COALESCE(SUM(COALESCE(PaidAmt, 0)), 0) as total_paid
    FROM VoucharMas WHERE Student_Class_StuRegID = ?
    ''',
    [stuRegId],
  );
  final feeTotalBilled = (feeRows.first['total_billed'] as int?) ?? 0;
  final feeTotalPaid = (feeRows.first['total_paid'] as int?) ?? 0;
  final feeBalance = feeTotalBilled - feeTotalPaid;

  // Resolve admClassName if admInClass is set
  String? admClassName;
  if (student.admInClass != null) {
    final clsRows = await db.rawQuery(
      'SELECT CName FROM Class WHERE ClassID = ? LIMIT 1',
      [student.admInClass],
    );
    if (clsRows.isNotEmpty) {
      admClassName = clsRows.first['CName'] as String?;
    }
  }

  // Resolve currentClassSection (active enrollment)
  String currentClassSection = 'Not Enrolled';
  final currentEnrollment = enrollments.where((e) => e.isActive).toList();
  if (currentEnrollment.isNotEmpty) {
    final e = currentEnrollment.first;
    currentClassSection = '${e.className}-${e.sectionName}';
  } else if (enrollments.isNotEmpty) {
    final e = enrollments.first;
    currentClassSection = '${e.className}-${e.sectionName}';
  }

  return StudentBiodataPrintData(
    stuRegId: stuRegId,
    studentName: student.fullName,
    nameMiddle: student.nameMiddle,
    dob: student.dob,
    sex: student.sex,
    religion: student.religion,
    nationality: student.nationality,
    bFormNo: student.bFormNo,
    photoPath: student.photoPath,
    fatherName: student.fName,
    cnicNo: student.cnicNo,
    occupation: student.occupation,
    mobile1: student.mobile1,
    mobile2: student.mobile2,
    phoneOffice: student.phoneOffice,
    phoneRes: student.phoneRes,
    emerContName: student.emerContName,
    emerContMobile: student.emerContMobile,
    pAddress: student.pAddress,
    tAddress: student.tAddress,
    pSchool: student.pSchool,
    pClass: student.pClass,
    slCertificate: student.slCertificate,
    admInClass: student.admInClass,
    admClassName: admClassName,
    doAdmission: student.doAdmission,
    discount: student.discount,
    vmDiscount: student.vmDiscount,
    fullDiscount: student.fullDiscount,
    officeFile: student.officeFile,
    remarks: student.remarls,
    enrollmentHistory: enrollments
        .map(
          (e) => StudentEnrollmentHistoryRow(
            sessionYr: e.sessionYr,
            className: e.className,
            sectionName: e.sectionName,
            classRollNo: e.classRollNo,
            isPresent: e.present == 1,
          ),
        )
        .toList(),
    feeTotalBilled: feeTotalBilled,
    feeTotalPaid: feeTotalPaid,
    feeBalance: feeBalance,
    currentClassSection: currentClassSection,
  );
}
