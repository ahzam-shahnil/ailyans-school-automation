import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/student.dart';
import '../../models/student_enrollment.dart';
import '../../models/student_voucher.dart';
import '../db/database.dart';
import '../sync/node_id_allocator.dart';
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
  final bool isEnrolled;

  /// Shot 2a: true when a school-leaving record (SchLeaving) exists for this
  /// student — the profile must surface `Alumni` / `Left` status and never
  /// present a stale active enrollment as `Active`.
  final bool hasLeftRecord;

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
    this.isEnrolled = true,
    this.hasLeftRecord = false,
  });
}

/// Provider managing active tab index on the student profile (0..6).
final selectedStudentTabProvider = StateProvider<int>((ref) => 0);

/// Provider controlling whether the student profile is in View Mode (false) or Edit Mode (true).
final studentEditModeProvider = StateProvider<bool>((ref) => false);

/// Riverpod FutureProvider.family fetching all student profile data by registration ID.
///
/// G-10 Shot 10a: `.autoDispose` so the cached `StudentProfileBundle` is
/// dropped as soon as the profile screen unmounts. Re-opening a profile
/// therefore always re-queries local SQLite instead of serving the previous
/// visit's bundle (which could pre-date a pulled cloud delta, e.g. an edited
/// student name synced from another device).
final studentProfileProvider =
    FutureProvider.autoDispose.family<StudentProfileBundle, int>(
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

    // 5. School-leaving record (Shot 2a): the leaving workflow commits into
    // `SchLeaving` and deactivates the enrollment. If a leaving row exists we
    // reconcile any stale active enrollment (Present = 1 / VGen = 'Y') so an
    // SLC-issued student is never stuck as `Active` in their old class, and
    // the profile renders the `Alumni` status badge.
    final leftRows = await db.query(
      'SchLeaving',
      where: 'StuRegID = ?',
      whereArgs: [stuRegId],
      limit: 1,
    );
    final hasLeftRecord = leftRows.isNotEmpty;
    if (hasLeftRecord) {
      await db.rawUpdate(
        '''
        UPDATE Student_Class
        SET Present = 0, VGen = 'N'
        WHERE Stu_RegID = ?
          AND (COALESCE(Present, 0) = 1 OR COALESCE(VGen, 'Y') = 'Y')
        ''',
        [stuRegId],
      );
    }


    // Current enrollment metadata
    final activeEnrollments =
        enrollments.where((e) => e.present == 1).toList();
    final currentEnrollment =
        activeEnrollments.isNotEmpty ? activeEnrollments.first : null;
    // Shot 2a: a committed school-leaving record always wins — the student is
    // Alumni regardless of any stale Student_Class.Present flag.
    final isEnrolled = !hasLeftRecord && currentEnrollment != null;
    final classRollNo = currentEnrollment?.classRollNo ?? 0;
    final currentClassName =
        isEnrolled ? currentEnrollment.className : 'Not Enrolled';
    final currentSectionName = isEnrolled ? currentEnrollment.sectionName : '';

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
    // Shot 2a (Ailyans production `#4810 Ahzam Shah`): the old query billed
    // `SubTotal` while payments settled `SubTotal - Discount`, so every
    // discounted voucher reported a phantom outstanding balance equal to its
    // concession (voucher 2610-4810: SubTotal 4500, Discount 1000, 3500 paid
    // → falsely "Rs. 1,000 outstanding"). Each voucher's unpaid balance is
    // now MAX(0, SubTotal - Discount - Paid), and a voucher marked settled
    // (`IsPaid = 'Y'`) can never contribute arrears.
    // The voucher query LEFT JOINs FeeTransaction, so one voucher with several
    // installments yields several rows — aggregate per VoucherMasID first.
    final voucherAggregates = <String, List<StudentVoucher>>{};
    for (final v in vouchers) {
      voucherAggregates.putIfAbsent(v.voucherMasId, () => []).add(v);
    }

    int totalBilled = 0; // net billable = SubTotal - Discount
    int totalPaid = 0;
    int outstandingArrears = 0;

    for (final rows in voucherAggregates.values) {
      final head = rows.first;
      final net = head.subtotal - head.discount;
      int paid = 0;
      for (final r in rows) {
        if (r.paidAmount != null && r.paidAmount! > 0) paid += r.paidAmount!;
      }
      final balance = head.isPaid == 'Y' ? 0 : (net - paid > 0 ? net - paid : 0);
      totalBilled += net;
      totalPaid += paid;
      outstandingArrears += balance;
    }
    final currencyFormat = NumberFormat('#,##0');

    final feeBalanceSummary = outstandingArrears <= 0
        ? 'Rs. 0.00 (All clear)'
        : 'Rs. ${currencyFormat.format(outstandingArrears)} outstanding';

    // 5b. Fetch Advances
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
      isEnrolled: isEnrolled,
      hasLeftRecord: hasLeftRecord,
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
    SELECT COALESCE(SUM(SubTotal - COALESCE(Discount, 0)), 0) as total_billed,
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

// ─────────────────────────────────────────────────────────────────────────
// Shot 2a — Mutations: voucher delete, concession settings, student purge.
// Sync note: `_sync_outbox` AFTER DELETE triggers (Migration 009) capture
// tombstones automatically for every synced table touched below, as long as
// the writes run with `is_applying_remote = 0` (the default for local UX).
// ─────────────────────────────────────────────────────────────────────────

/// Deletes one voucher and all of its dependent rows (payment transactions,
/// voucher details, master row) inside a single transaction. Returns true if
/// the master row was removed.
Future<bool> deleteStudentVoucher(String voucherMasId) async {
  final db = await DatabaseService.instance.database;
  int deleted = 0;
  await db.transaction((txn) async {
    await txn.rawDelete(
      'DELETE FROM FeeTransaction WHERE VoucharNo = ?',
      [voucherMasId],
    );
    await txn.rawDelete(
      'DELETE FROM VoucharDet WHERE VoucharMasID = ?',
      [voucherMasId],
    );
    deleted = await txn.rawDelete(
      'DELETE FROM VoucharMas WHERE VoucherMasID = ?',
      [voucherMasId],
    );
  });
  return deleted > 0;
}

/// Persists the Fee Concessions & Advance Credit panel onto `Stu_Reg`
/// (`Discount` = monthly tuition concession, `VMDiscount` = voucher
/// adjustment credit, `FullDiscount` = 100% free-ship waiver flag).
Future<void> updateStudentConcessions({
  required int stuRegId,
  required double tuitionConcession,
  required int voucherAdjustmentCredit,
  required int fullFeeWaiver,
}) async {
  final db = await DatabaseService.instance.database;
  await db.update(
    'Stu_Reg',
    {
      'Discount': tuitionConcession,
      'VMDiscount': voucherAdjustmentCredit,
      'FullDiscount': fullFeeWaiver,
    },
    where: 'Stu_RegID = ?',
    whereArgs: [stuRegId],
  );
}

/// Records a positive advance-credit deposit into `StuAdv`.
Future<void> addStudentAdvanceCredit({
  required int stuRegId,
  required int amount,
  required DateTime date,
  String depositedBy = 'Office',
}) async {
  final db = await DatabaseService.instance.database;
  await db.transaction((txn) async {
    final nextAdvId = await NodeIdAllocator.allocateInTransaction(
      txn,
      tableName: 'StuAdv',
      pkColumn: 'StuAdvID',
    );
    await txn.insert('StuAdv', {
      'StuAdvID': nextAdvId,
      'StuRegID': stuRegId,
      'AdvAmount': amount,
      'MOP': 'Cash',
      'Date': DateFormat('yyyy-MM-dd').format(date),
      'DepositedBy': depositedBy,
      'Detail': 'Advance fee credit deposited from student profile',
    });
  });
}

/// Permanently deletes a student and every dependent record inside one
/// transaction: fee transactions, voucher details, voucher masters,
/// attendance detail rows, school-leaving record, exam marks, advance
/// credits, enrollments, and finally the `Stu_Reg` demographic row.
Future<void> permanentlyDeleteStudent(int stuRegId) async {
  final db = await DatabaseService.instance.database;
  await db.transaction((txn) async {
    final voucherRows = await txn.rawQuery(
      'SELECT VoucherMasID FROM VoucharMas WHERE Student_Class_StuRegID = ?',
      [stuRegId],
    );
    final voucherIds = voucherRows
        .map((r) => r['VoucherMasID'] as String)
        .toList(growable: false);
    if (voucherIds.isNotEmpty) {
      final placeholders = List.filled(voucherIds.length, '?').join(',');
      await txn.rawDelete(
        'DELETE FROM FeeTransaction WHERE VoucharNo IN ($placeholders)',
        voucherIds,
      );
      await txn.rawDelete(
        'DELETE FROM VoucharDet WHERE VoucharMasID IN ($placeholders)',
        voucherIds,
      );
    }
    await txn.rawDelete(
      'DELETE FROM VoucharMas WHERE Student_Class_StuRegID = ?',
      [stuRegId],
    );
    await txn.rawDelete(
      'DELETE FROM AttDet WHERE Stu_RegID = ?',
      [stuRegId],
    );
    await txn.rawDelete(
      'DELETE FROM SchLeaving WHERE StuRegID = ?',
      [stuRegId],
    );
    final examRows = await txn.rawQuery(
      'SELECT ExamMasID FROM ExamMas WHERE Stu_RegID = ?',
      [stuRegId],
    );
    final examIds = examRows
        .map((r) => r['ExamMasID'] as num)
        .toList(growable: false);
    if (examIds.isNotEmpty) {
      final placeholders = List.filled(examIds.length, '?').join(',');
      await txn.rawDelete(
        'DELETE FROM ExamDet WHERE ExamMasID IN ($placeholders)',
        examIds,
      );
    }
    await txn.rawDelete(
      'DELETE FROM ExamMas WHERE Stu_RegID = ?',
      [stuRegId],
    );
    await txn.rawDelete(
      'DELETE FROM StuAdv WHERE StuRegID = ?',
      [stuRegId],
    );
    await txn.rawDelete(
      'DELETE FROM Student_Class WHERE Stu_RegID = ?',
      [stuRegId],
    );
    await txn.rawDelete(
      'DELETE FROM Stu_Reg WHERE Stu_RegID = ?',
      [stuRegId],
    );
  });
}
