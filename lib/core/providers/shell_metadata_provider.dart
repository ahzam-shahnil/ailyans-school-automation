import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';

/// Aggregated system metadata consumed by the application shell.
class ShellMetadata {
  /// InstBranch.BranchName where BrnachID = 1
  final String branchName;

  /// InstBranch.BranchAddress where BrnachID = 1
  final String branchAddress;

  /// InstBranch.BrPhone where BrnachID = 1
  final String? branchPhone;

  /// InstBranch.BrPrincipal where BrnachID = 1
  final String? branchPrincipal;

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
    this.branchPhone,
    this.branchPrincipal,
    required this.sessionYear,
    required this.studentCount,
    required this.classCount,
    required this.staffCount,
    required this.pendingVouchers,
  });

  /// Fallback defaults when database is loading or unavailable.
  factory ShellMetadata.empty() {
    return const ShellMetadata(
      branchName: '',
      branchAddress: '',
      branchPhone: '',
      branchPrincipal: '',
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
    'SELECT BranchName, BranchAddress, BrPhone, BrPrincipal FROM InstBranch WHERE BrnachID = 1 LIMIT 1',
  );
  final rawBranchName = branchRows.isNotEmpty
      ? (branchRows.first['BranchName'] as String?)
      : null;
  final branchName = rawBranchName?.trim() ?? '';

  final rawBranchAddress = branchRows.isNotEmpty
      ? (branchRows.first['BranchAddress'] as String?)
      : null;
  final branchAddress = rawBranchAddress?.trim() ?? '';

  final rawBranchPhone = branchRows.isNotEmpty
      ? (branchRows.first['BrPhone'] as String?)
      : null;
  final branchPhone = rawBranchPhone?.trim() ?? '';

  final rawBranchPrincipal = branchRows.isNotEmpty
      ? (branchRows.first['BrPrincipal'] as String?)
      : null;
  final branchPrincipal = rawBranchPrincipal?.trim() ?? '';

  // 2. Active Academic Session (app_config key, set via Screen 27 System Settings)
  final sessionRows = await db.rawQuery(
    "SELECT config_value FROM app_config WHERE config_key = 'default_session_yr' LIMIT 1",
  );
  final sessionYear = sessionRows.isNotEmpty
      ? (sessionRows.first['config_value'] as String? ?? '2017-2018')
      : '2017-2018';

  // 3. Enrolled Student Count (scoped to active session with 0-fallback)
  int studentCount = 0;
  if (sessionYear.isNotEmpty) {
    final scopedRows = await db.rawQuery(
      'SELECT COUNT(DISTINCT Stu_RegID) AS cnt FROM Student_Class WHERE Present = 1 AND SessionYr = ?',
      [sessionYear],
    );
    studentCount = (scopedRows.first['cnt'] as num?)?.toInt() ?? 0;
  }
  if (studentCount == 0) {
    final fallbackRows = await db.rawQuery(
      'SELECT COUNT(DISTINCT Stu_RegID) AS cnt FROM Student_Class WHERE Present = 1',
    );
    studentCount = (fallbackRows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  // 4. Class Count
  final classRows = await db.rawQuery('SELECT COUNT(*) as cnt FROM Class');
  final classCount = (classRows.first['cnt'] as int?) ?? 0;

  // 5. Active Staff Count
  final staffRows = await db.rawQuery(
    "SELECT COUNT(*) as cnt FROM Teachers WHERE TIsPresent = 'Y'",
  );
  final staffCount = (staffRows.first['cnt'] as int?) ?? 0;

  // 6. Pending Unpaid Vouchers Count
  final voucherRows = await db.rawQuery(
    "SELECT COUNT(*) as cnt FROM VoucharMas WHERE IsPaid = 'N'",
  );
  final pendingVouchers = (voucherRows.first['cnt'] as int?) ?? 0;

  return ShellMetadata(
    branchName: branchName,
    branchAddress: branchAddress,
    branchPhone: branchPhone,
    branchPrincipal: branchPrincipal,
    sessionYear: sessionYear,
    studentCount: studentCount,
    classCount: classCount,
    staffCount: staffCount,
    pendingVouchers: pendingVouchers,
  );
});
