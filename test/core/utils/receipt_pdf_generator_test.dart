import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/receipt_pdf_generator.dart';

FeeReceiptPrintData _fakeReceipt({bool paid = true}) {
  return FeeReceiptPrintData(
    feeTransId: 1,
    voucherMasId: '1710-4411',
    stuRegId: 4411,
    studentName: 'Muhammad Ali Khan',
    fatherName: 'Khan Muhammad',
    className: 'Class 10',
    sectionName: 'A',
    rollNo: 1,
    sessionYr: '2017-2018',
    forMonth: 'October 2017',
    submissionDate: DateTime(2017, 10, 5),
    subtotal: 1920,
    discount: 0,
    totalAmount: 1920,
    paidAmount: paid ? 1920 : 0,
    paymentMode: 'Cash',
    bankName: 'Askari Bank Limited',
    bankBranch: 'Ballo Khel Road',
    bankAcctNo: '4528',
    remarks: null,
    lineItems: [
      const FeeReceiptLineItem(
        feeParamId: 2,
        headName: 'Tuition Fee',
        amount: 1500,
        discount: 0,
      ),
      const FeeReceiptLineItem(
        feeParamId: 3,
        headName: 'Exam Fee',
        amount: 300,
        discount: 0,
      ),
      const FeeReceiptLineItem(
        feeParamId: 7,
        headName: 'Annual Cgarges',
        amount: 120,
        discount: 0,
      ),
    ],
  );
}

void main() {
  test('Three-copy receipt PDF generates valid bytes', () async {
    final bytes = await ReceiptPdfGenerator.generateThreeCopyReceipts(
      receipts: [_fakeReceipt()],
      branchName: 'Test School',
      branchAddress: 'Test Address',
    );
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('Multiple receipts generate longer PDF', () async {
    final bytes = await ReceiptPdfGenerator.generateThreeCopyReceipts(
      receipts: [_fakeReceipt(), _fakeReceipt()],
      branchName: 'Test School',
      branchAddress: 'Test Address',
    );
    expect(bytes.length, greaterThan(8000));
  });

  test('amountToWords converts rupee amounts to English words', () {
    expect(ReceiptPdfGenerator.amountToWords(0), contains('Zero'));
    expect(ReceiptPdfGenerator.amountToWords(100), contains('Hundred'));
    expect(
      ReceiptPdfGenerator.amountToWords(1920),
      contains('Twenty'),
    ); // 1920 = One Thousand Nine Hundred Twenty
    expect(ReceiptPdfGenerator.amountToWords(1920), contains('Thousand'));
    expect(ReceiptPdfGenerator.amountToWords(100000), contains('Lakh'));
  });

  test('Receipt with discount renders without error', () async {
    final receipt = FeeReceiptPrintData(
      feeTransId: 2,
      voucherMasId: '1710-4414',
      stuRegId: 4414,
      studentName: 'Fatima Zahra',
      fatherName: 'Tariq Mehmood',
      className: 'Class 10',
      sectionName: 'A',
      rollNo: 4,
      sessionYr: '2017-2018',
      forMonth: 'October 2017',
      submissionDate: DateTime(2017, 10, 5),
      subtotal: 1920,
      discount: 500,
      totalAmount: 1420,
      paidAmount: 1420,
      paymentMode: 'Cash',
      bankName: 'Askari Bank Limited',
      bankBranch: 'Ballo Khel Road',
      bankAcctNo: '4528',
      remarks: null,
      lineItems: [
        const FeeReceiptLineItem(
          feeParamId: 2,
          headName: 'Tuition Fee',
          amount: 1500,
          discount: 500,
        ),
      ],
    );
    final bytes = await ReceiptPdfGenerator.generateThreeCopyReceipts(
      receipts: [receipt],
      branchName: 'Test School',
      branchAddress: 'Test Address',
    );
    expect(bytes.length, greaterThan(5000));
  });
}
