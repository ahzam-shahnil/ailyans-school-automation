import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';

/// Hit for a student search result.
class StudentSearchHit {
  final int stuRegId;
  final String fullName;
  final String? fatherName;
  final String? className;
  final String? secName;
  final int? rollNo;
  final String? mobile;
  final bool isPresent;

  const StudentSearchHit({
    required this.stuRegId,
    required this.fullName,
    this.fatherName,
    this.className,
    this.secName,
    this.rollNo,
    this.mobile,
    required this.isPresent,
  });

  String get classSectionDisplay {
    final parts = <String>[];
    if (className != null && className!.isNotEmpty) parts.add(className!);
    if (secName != null && secName!.isNotEmpty) parts.add('Sec $secName');
    if (rollNo != null) parts.add('Roll #$rollNo');
    return parts.isEmpty ? 'Not Enrolled' : parts.join(' - ');
  }
}

/// Hit for a fee voucher search result.
class VoucherSearchHit {
  final String voucherId;
  final int stuRegId;
  final String studentName;
  final String? className;
  final String forMonth;
  final String? sessionYr;
  final int subTotal;
  final int discount;
  final int paidAmt;
  final int netDue;
  final String isPaid; // 'Y', 'N', 'O'
  final DateTime? dueDate;

  const VoucherSearchHit({
    required this.voucherId,
    required this.stuRegId,
    required this.studentName,
    this.className,
    required this.forMonth,
    this.sessionYr,
    required this.subTotal,
    required this.discount,
    required this.paidAmt,
    required this.netDue,
    required this.isPaid,
    this.dueDate,
  });

  bool get isPaidStatus => isPaid == 'Y';
  bool get isRolledOver => isPaid == 'O';
  bool get isUnpaid => isPaid == 'N';

  String get statusLabel {
    if (isPaidStatus) return 'Paid';
    if (isRolledOver) return 'Rolled Over';
    return 'Unpaid';
  }
}

/// Hit for a teacher / staff search result.
class StaffSearchHit {
  final int teacherId;
  final String name;
  final String? fatherName;
  final String category;
  final String? subject;
  final String? phone;
  final bool isPresent;

  const StaffSearchHit({
    required this.teacherId,
    required this.name,
    this.fatherName,
    required this.category,
    this.subject,
    this.phone,
    required this.isPresent,
  });
}

/// Hit for a library book search result.
class BookSearchHit {
  final String bookId;
  final String bookName;
  final String? author;
  final String? publisher;
  final String? categoryName;
  final double? price;

  const BookSearchHit({
    required this.bookId,
    required this.bookName,
    this.author,
    this.publisher,
    this.categoryName,
    this.price,
  });
}

/// Combined container for omni-search hits across 4 categories.
class GlobalSearchResults {
  final String query;
  final List<StudentSearchHit> students;
  final List<VoucherSearchHit> vouchers;
  final List<StaffSearchHit> staff;
  final List<BookSearchHit> books;

  const GlobalSearchResults({
    required this.query,
    this.students = const [],
    this.vouchers = const [],
    this.staff = const [],
    this.books = const [],
  });

  const GlobalSearchResults.empty([String q = ''])
    : query = q,
      students = const [],
      vouchers = const [],
      staff = const [],
      books = const [];

  int get totalCount =>
      students.length + vouchers.length + staff.length + books.length;
}

/// Auto-disposing future provider executing omni-search across all 4 categories.
final globalSearchProvider = FutureProvider.autoDispose
    .family<GlobalSearchResults, String>((ref, rawQuery) async {
      final q = rawQuery.trim();
      if (q.isEmpty) {
        return const GlobalSearchResults(
          query: '',
          students: [],
          vouchers: [],
          staff: [],
          books: [],
        );
      }

      final db = await DatabaseService.instance.database;
      final pattern = '%${q.toLowerCase()}%';

      // 1. Students
      // Shot 6k: a student can have multiple Student_Class rows (promotion
      // history / re-enrollment across sessions). Joining Student_Class
      // directly produced one result row per enrollment — `#4777 Aimal Khan`
      // appeared twice in Global Omni-Search. Join only the single canonical
      // enrollment row per student (Present=1 in the newest session first),
      // and GROUP BY sr.Stu_RegID as a hard guarantee. Exact Reg-ID matches
      // are ordered first.
      final studentRows = await db.rawQuery(
        '''
    SELECT sr.Stu_RegID, sr.NameFirst, sr.NameMiddle, sr.NameLast, sr.F_Name, sr.Mobile1,
           sc.ClassRollNo, sc.Present, c.CName, cs.SecName
    FROM Stu_Reg sr
    LEFT JOIN Student_Class sc ON sc.rowid = (
      SELECT sc2.rowid
      FROM Student_Class sc2
      WHERE sc2.Stu_RegID = sr.Stu_RegID
      ORDER BY COALESCE(sc2.Present, 0) DESC, sc2.SessionYr DESC, sc2.rowid DESC
      LIMIT 1
    )
    LEFT JOIN Class c ON c.ClassID = sc.ClassID
    LEFT JOIN ClassSec cs ON cs.ClassSecID = sc.ClassSecID
    WHERE LOWER(TRIM(COALESCE(sr.NameFirst,'') || ' ' || COALESCE(sr.NameMiddle,'') || ' ' || COALESCE(sr.NameLast,''))) LIKE ?
       OR LOWER(COALESCE(sr.F_Name,'')) LIKE ?
       OR CAST(sr.Stu_RegID AS TEXT) LIKE ?
       OR LOWER(COALESCE(sr.Mobile1,'')) LIKE ?
    GROUP BY sr.Stu_RegID
    ORDER BY CASE
        WHEN CAST(sr.Stu_RegID AS TEXT) = ? THEN 0
        WHEN CAST(sr.Stu_RegID AS TEXT) LIKE ? THEN 1
        ELSE 2
      END,
      sr.Stu_RegID DESC
    LIMIT 25
    ''',
        [pattern, pattern, pattern, pattern, q, pattern],
      );

      final students = studentRows.map((r) {
        final f = (r['NameFirst'] as String?)?.trim() ?? '';
        final m = (r['NameMiddle'] as String?)?.trim() ?? '';
        final l = (r['NameLast'] as String?)?.trim() ?? '';
        final full = [f, m, l].where((s) => s.isNotEmpty).join(' ');

        return StudentSearchHit(
          stuRegId: (r['Stu_RegID'] as num).toInt(),
          fullName: full.isNotEmpty ? full : 'Student #${r['Stu_RegID']}',
          fatherName: (r['F_Name'] as String?)?.trim(),
          className: (r['CName'] as String?)?.trim(),
          secName: (r['SecName'] as String?)?.trim(),
          rollNo: (r['ClassRollNo'] as num?)?.toInt(),
          mobile: (r['Mobile1'] as String?)?.trim(),
          isPresent: (r['Present'] as num?)?.toInt() == 1,
        );
      }).toList();

      // 2. Vouchers
      // Shot 6k: GROUP BY vm.VoucherMasID guarantees one row per voucher even
      // if the join graph ever fans out through multi-enrollment students.
      final voucherRows = await db.rawQuery(
        '''
    SELECT vm.VoucherMasID, vm.Student_Class_StuRegID AS StuRegID, vm.ForMonth, vm.SessionYr,
           vm.SubTotal, COALESCE(vm.Discount, 0) AS Discount, COALESCE(vm.PaidAmt, 0) AS PaidAmt,
           vm.IsPaid, vm.DueDate, sr.NameFirst, sr.NameMiddle, sr.NameLast, c.CName
    FROM VoucharMas vm
    LEFT JOIN Stu_Reg sr ON sr.Stu_RegID = vm.Student_Class_StuRegID
    LEFT JOIN Class c ON c.ClassID = vm.ClassID
    WHERE LOWER(vm.VoucherMasID) LIKE ?
       OR CAST(vm.Student_Class_StuRegID AS TEXT) LIKE ?
       OR LOWER(COALESCE(vm.ForMonth,'')) LIKE ?
       OR LOWER(TRIM(COALESCE(sr.NameFirst,'') || ' ' || COALESCE(sr.NameMiddle,'') || ' ' || COALESCE(sr.NameLast,''))) LIKE ?
    GROUP BY vm.VoucherMasID
    ORDER BY SUBSTR(vm.VoucherMasID, 1, 4) DESC, vm.VoucherMasID DESC
    LIMIT 25
    ''',
        [pattern, pattern, pattern, pattern],
      );

      final vouchers = voucherRows.map((r) {
        final f = (r['NameFirst'] as String?)?.trim() ?? '';
        final m = (r['NameMiddle'] as String?)?.trim() ?? '';
        final l = (r['NameLast'] as String?)?.trim() ?? '';
        final full = [f, m, l].where((s) => s.isNotEmpty).join(' ');

        final subTotal = (r['SubTotal'] as num?)?.toInt() ?? 0;
        final discount = (r['Discount'] as num?)?.toInt() ?? 0;
        final paidAmt = (r['PaidAmt'] as num?)?.toInt() ?? 0;
        final isPaid = (r['IsPaid'] as String?)?.trim() ?? 'N';

        final netDue = isPaid == 'Y'
            ? 0
            : math.max(0, subTotal - discount - paidAmt);

        DateTime? dueDate;
        final dueRaw = r['DueDate'];
        if (dueRaw != null) {
          dueDate = DateTime.tryParse(dueRaw.toString());
        }

        return VoucherSearchHit(
          voucherId: (r['VoucherMasID'] as String?) ?? '',
          stuRegId: (r['StuRegID'] as num?)?.toInt() ?? 0,
          studentName: full.isNotEmpty ? full : 'Student #${r['StuRegID']}',
          className: (r['CName'] as String?)?.trim(),
          forMonth: (r['ForMonth'] as String?)?.trim() ?? '',
          sessionYr: (r['SessionYr'] as String?)?.trim(),
          subTotal: subTotal,
          discount: discount,
          paidAmt: paidAmt,
          netDue: netDue,
          isPaid: isPaid,
          dueDate: dueDate,
        );
      }).toList();

      // 3. Staff
      final staffRows = await db.rawQuery(
        '''
    SELECT TeacherID, TName, TFName, TCat, TSubject, TContactNo1, TIsPresent
    FROM Teachers
    WHERE LOWER(COALESCE(TName,'')) LIKE ?
       OR LOWER(COALESCE(TFName,'')) LIKE ?
       OR LOWER(COALESCE(TCat,'')) LIKE ?
       OR LOWER(COALESCE(TContactNo1,'')) LIKE ?
       OR CAST(TeacherID AS TEXT) LIKE ?
    ORDER BY TeacherID ASC
    LIMIT 20
    ''',
        [pattern, pattern, pattern, pattern, pattern],
      );

      final staff = staffRows.map((r) {
        return StaffSearchHit(
          teacherId: (r['TeacherID'] as num).toInt(),
          name: (r['TName'] as String?)?.trim() ?? 'Teacher #${r['TeacherID']}',
          fatherName: (r['TFName'] as String?)?.trim(),
          category: (r['TCat'] as String?)?.trim() ?? 'Teacher',
          subject: (r['TSubject'] as String?)?.trim(),
          phone: (r['TContactNo1'] as String?)?.trim(),
          isPresent: (r['TIsPresent'] as String?)?.trim().toUpperCase() == 'Y',
        );
      }).toList();

      // 4. Books
      final bookRows = await db.rawQuery(
        '''
    SELECT b.BookID, b.BookName, b.BAuthor, b.PulishedBy, b.BookPrice, s.SubjName AS CategoryName
    FROM Books b
    LEFT JOIN Subject s ON s.SubjID = b.BookCatSubj
    WHERE LOWER(COALESCE(b.BookName,'')) LIKE ?
       OR LOWER(COALESCE(b.BAuthor,'')) LIKE ?
       OR LOWER(COALESCE(b.PulishedBy,'')) LIKE ?
       OR CAST(b.BookID AS TEXT) LIKE ?
    ORDER BY b.BookID ASC
    LIMIT 20
    ''',
        [pattern, pattern, pattern, pattern],
      );

      final books = bookRows.map((r) {
        return BookSearchHit(
          bookId: r['BookID']?.toString() ?? '',
          bookName: (r['BookName'] as String?)?.trim() ?? 'Untitled Book',
          author: (r['BAuthor'] as String?)?.trim(),
          publisher: (r['PulishedBy'] as String?)?.trim(),
          categoryName: (r['CategoryName'] as String?)?.trim(),
          price: (r['BookPrice'] as num?)?.toDouble(),
        );
      }).toList();

      return GlobalSearchResults(
        query: q,
        students: students,
        vouchers: vouchers,
        staff: staff,
        books: books,
      );
    });
