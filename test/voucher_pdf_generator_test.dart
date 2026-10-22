import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/voucher_pdf_generator.dart';
import 'package:school_automation/models/fee_receipt_view.dart';

FeeReceiptView _fakeReceipt({bool paid = false}) {
  return FeeReceiptView(
    voucherMasId: '1710-4411',
    stuRegId: 4411,
    studentName: 'Muhammad Ali Khan',
    fatherName: 'Khan Muhammad',
    className: 'Class 10',
    sectionName: 'A',
    rollNo: 1,
    sessionYr: '2017-2018',
    photoPath: null,
    forMonth: 'October 2017',
    issueDate: DateTime(2017, 10, 1),
    dueDate: DateTime(2017, 10, 10),
    subtotal: 1920,
    discount: 0,
    paidAmount: paid ? 1920 : 0,
    paidDate: paid ? DateTime(2017, 10, 5) : null,
    bankId: 1,
    isPaid: paid ? 'Y' : 'N',
    lineItems: const [
      FeeReceiptLineItem(
        feeParamId: 2,
        headName: 'Tuition Fee',
        amount: 1500,
        discount: 0,
      ),
      FeeReceiptLineItem(
        feeParamId: 3,
        headName: 'Exam Fee',
        amount: 300,
        discount: 0,
      ),
      FeeReceiptLineItem(
        feeParamId: 7,
        headName: 'Annual Cgarges',
        amount: 120,
        discount: 0,
      ),
    ],
    advanceBalance: 0,
  );
}

void main() {
  test('ThreeCopyVouchersPdf.generate returns valid PDF bytes', () async {
    final bytes = await ThreeCopyVouchersPdf.generate(
      vouchers: [_fakeReceipt()],
      branchName: 'Ailyans Higher Secondary School',
      branchAddress: 'Muslim Bazar Mianwali',
      bankName: 'Askari Bank Limited',
      bankBranch: 'Ballo Khel Road',
      bankAcctNo: '4528',
    );
    expect(bytes, isA<Uint8List>());
    expect(
      bytes.length,
      greaterThan(5000),
      reason: 'Real PDF should exceed 5KB, empty shell is smaller',
    );
    // PDF magic header
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('ThreeCopyVouchersPdf handles multiple vouchers', () async {
    final bytes = await ThreeCopyVouchersPdf.generate(
      vouchers: [_fakeReceipt(), _fakeReceipt(paid: true)],
      branchName: 'Test School',
      branchAddress: 'Test Address',
      bankName: 'Test Bank',
      bankBranch: 'Test Branch',
      bankAcctNo: '1234',
    );
    expect(
      bytes.length,
      greaterThan(6500),
      reason: 'Two vouchers should produce more bytes than one',
    );
  });

  test('FeeLedgerVoucherGenerator produces ledger PDF', () async {
    final receipts = [_fakeReceipt(), _fakeReceipt(paid: true)];
    final gen = FeeLedgerVoucherGenerator(
      institutionName: 'Test School',
      ledgerPeriodTitle: 'Cohort Ledger',
      transactions: receipts
          .map(
            (r) => FeeVoucherTransactionRecord.fromFeeReceipt(
              r,
              className: r.className ?? '',
            ),
          )
          .toList(),
    );
    final bytes = await gen.generatePdf();
    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
