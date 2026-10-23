import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';

/// Aggregated system metadata consumed by the application shell.
class ShellMetadata {
  /// InstBranch.BranchName where BrnachID = 1
  final String branchName;

  /// InstBranch.BranchAddress where BrnachID = 1
  final String branchAddress;

  /// Active academic session year (defaults to "2017-2018")
  final String sessionYear;

  /// COUNT(*) FROM Student_Class WHERE Present = 1
  final int studentCount;

  /// COUNT(*) FROM Class
  final int classCount;

  /// COUNT(*) FROM Teachers WHERE TIsPresent = 'Y'
  final int staffCount;

  /// COUNT(*) FROM VoucharMas WHERE IsPaid = 'N'
  final int pendingVouchers;

  const ShellMetadata({
    required this.branchName,
    required this.branchAddress,
    required this.sessionYear,
    required this.studentCount,
    required this.classCount,
    required this.staffCount,
    required this.pendingVouchers,
  });

  /// Fallback defaults when database is loading or unavailable.
  factory ShellMetadata.empty() {
    return const ShellMetadata(
      branchName: "Ailyans's Higher Secondary School Mianwali",
      branchAddress: 'Muslim Bazar Mianwali',
      sessionYear: '2017-2018',
      studentCount: 0,
      classCount: 0,
      staffCount: 0,
      pendingVouchers: 0,
    );
  }
}

/// Riverpod provider fetching current shell metadata from the database.
final shellMetadataProvider = FutureProvider<ShellMetadata>((ref) async {
  final db = await DatabaseService.instance.database;

  // 1. Branch Name
  final branchRows = await db.rawQuery(
    'SELECT BranchName, BranchAddress FROM InstBranch WHERE BrnachID = 1 LIMIT 1',
  );
  final branchName = branchRows.isNotEmpty
      ? (branchRows.first['BranchName'] as String? ??
            "Ailyans's Higher Secondary School Mianwali")
      : "Ailyans's Higher Secondary School Mianwali";
  final branchAddress = branchRows.isNotEmpty
      ? (branchRows.first['BranchAddress'] as String? ??
            'Muslim Bazar Mianwali')
      : 'Muslim Bazar Mianwali';

  // 2. Enrolled Student Count
  final studentRows = await db.rawQuery(
    'SELECT COUNT(*) as cnt FROM Student_Class WHERE Present = 1',
  );
  final studentCount = (studentRows.first['cnt'] as int?) ?? 0;

  // 3. Class Count
  final classRows = await db.rawQuery('SELECT COUNT(*) as cnt FROM Class');
  final classCount = (classRows.first['cnt'] as int?) ?? 0;

  // 4. Active Staff Count
  final staffRows = await db.rawQuery(
    "SELECT COUNT(*) as cnt FROM Teachers WHERE TIsPresent = 'Y'",
  );
  final staffCount = (staffRows.first['cnt'] as int?) ?? 0;

  // 5. Pending Unpaid Vouchers Count
  final voucherRows = await db.rawQuery(
    "SELECT COUNT(*) as cnt FROM VoucharMas WHERE IsPaid = 'N'",
  );
  final pendingVouchers = (voucherRows.first['cnt'] as int?) ?? 0;

  return ShellMetadata(
    branchName: branchName,
    branchAddress: branchAddress,
    sessionYear: '2017-2018',
    studentCount: studentCount,
    classCount: classCount,
    staffCount: staffCount,
    pendingVouchers: pendingVouchers,
  );
});
