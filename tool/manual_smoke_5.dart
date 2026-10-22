// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/providers/voucher_generation_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('Manual Smoke Test 5 against Live Database', () async {
    print('\n======================================================');
    print('MANUAL SMOKE TEST 5 — LIVE DATABASE VERIFICATION');
    print('======================================================');

    // Open real database on disk
    final db = await DatabaseService.instance.database;

    final initialCountRows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM VoucharMas',
    );
    final initialCount = initialCountRows.first['cnt'] as int;
    print('Step 5a: Initial VoucharMas COUNT: $initialCount (Expected: 15)');
    expect(initialCount, 15);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 5b. Class 10 preview for October 2017
    print('\n--- Step 5b: Class 10 Preview (October 2017) ---');
    container.read(voucherGenFiltersProvider.notifier).setClassId(13);
    container
        .read(voucherGenFiltersProvider.notifier)
        .setBillingMonth('October 2017');

    final previewRows = await container.read(voucherGenPreviewProvider.future);
    print('Candidate rows count: ${previewRows.length} (Expected: 10)');
    expect(previewRows.length, 10);

    for (final r in previewRows) {
      print(
        '  Voucher: ${r.voucherId} | Student: ${r.studentName.padRight(20)} | SubTotal: ${r.subtotal} | Arrears: ${r.arrears} | Discount: ${r.discount} | Net: ${r.netPayable} | Status: ${r.status}',
      );
      expect(r.subtotal, 1920);
      expect(r.voucherId.startsWith('#'), isFalse);
    }

    // 5c. Confirm voucher IDs show "1710-4411" through "1710-4420"
    print('\n--- Step 5c: Voucher IDs Format (NO leading #) ---');
    for (int i = 0; i < 10; i++) {
      final expectedId = '1710-${4411 + i}';
      expect(previewRows[i].voucherId, expectedId);
      print('  Confirmed: ${previewRows[i].voucherId}');
    }

    // 5d. Click Generate -> "10 Vouchers Generated, 0 Skipped"
    print('\n--- Step 5d: Click Generate ---');
    final summary = await container
        .read(voucherGenExecutionProvider.notifier)
        .generateVouchers();

    print(
      'Batch Result: ${summary?.generatedCount} Generated, ${summary?.skippedCount} Skipped',
    );
    expect(summary, isNotNull);
    expect(summary!.generatedCount, 10);
    expect(summary.skippedCount, 0);

    // 5e. Re-run generation for same cohort -> 0 Generated, 10 Skipped
    print('\n--- Step 5e: Re-run Generation for Same Cohort ---');
    final reSummary = await container
        .read(voucherGenExecutionProvider.notifier)
        .generateVouchers();

    print(
      'Re-run Batch Result: ${reSummary?.generatedCount} Generated, ${reSummary?.skippedCount} Skipped',
    );
    expect(reSummary, isNotNull);
    expect(reSummary!.generatedCount, 0);
    expect(reSummary.skippedCount, 10);

    // 5f. Switch Class to Class 3 -> 1 row (Farhan Khan), subtotal=1280
    print('\n--- Step 5f: Switch Class to Class 3 ---');
    final cls3Rows = await db.rawQuery(
      "SELECT ClassID FROM Class WHERE CName = 'Class 3' LIMIT 1",
    );
    final class3Id = cls3Rows.first['ClassID'] as int;

    container.read(voucherGenFiltersProvider.notifier).setClassId(class3Id);
    final class3Preview = await container.read(
      voucherGenPreviewProvider.future,
    );
    print('Class 3 rows count: ${class3Preview.length}');
    expect(class3Preview.length, 1);
    expect(class3Preview.first.studentName, contains('Farhan'));
    expect(class3Preview.first.subtotal, 1280);
    print(
      '  Student: ${class3Preview.first.studentName} | SubTotal: ${class3Preview.first.subtotal} (1000+200+80)',
    );

    // 5g. Verify sqlite3:
    // SELECT COUNT(*) FROM VoucharMas; -- should be 15+10=25
    // SELECT * FROM VoucharDet WHERE VoucharMasID='1710-4411'; -- should show 3 rows, sum=1920
    print('\n--- Step 5g: SQLite3 Verification ---');
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM VoucharMas',
    );
    final totalVouchers = countRows.first['cnt'] as int;
    print('SELECT COUNT(*) FROM VoucharMas: $totalVouchers (Expected: 25)');
    expect(totalVouchers, 25);

    final det4411 = await db.rawQuery(
      "SELECT * FROM VoucharDet WHERE VoucharMasID = '1710-4411' ORDER BY feeParameterID ASC",
    );
    print('SELECT * FROM VoucharDet WHERE VoucharMasID=\'1710-4411\':');
    double sum4411 = 0;
    for (final d in det4411) {
      print(
        '  VoucharDetID: ${d['VoucharDetID']} | VoucharMasID: ${d['VoucharMasID']} | FeeParamID: ${d['feeParameterID']} | Amount: ${d['Amount']} | Discount: ${d['Discount']}',
      );
      sum4411 += (d['Amount'] as num).toDouble();
    }
    print('Sum of amounts: $sum4411 (Expected: 1920.0)');
    expect(det4411.length, 3);
    expect(sum4411, 1920.0);

    print('\n======================================================');
    print('ALL MANUAL SMOKE TEST 5 STEPS VERIFIED & PASSED!');
    print('======================================================\n');
  });
}
