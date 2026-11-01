// ignore_for_file: public_member_api_docs
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/fee_receipt_view.dart' show VoucherPaymentInstallment;
import 'fee_head_display.dart';

// ============================================================================
// DATA MODEL
// ============================================================================

/// A single fee line item inside the payment receipt.
class FeeReceiptLineItem {
  final int feeParamId;
  final String headName;
  final int amount;
  final int discount;

  const FeeReceiptLineItem({
    required this.feeParamId,
    required this.headName,
    required this.amount,
    this.discount = 0,
  });

  int get net => amount - discount;
}

/// Complete data model for printing one payment receipt (all 3 copies).
class FeeReceiptPrintData {
  final int feeTransId;
  final String voucherMasId;
  final int stuRegId;
  final String studentName;
  final String? fatherName;
  final String? className;
  final String? sectionName;
  final String? classSecName;
  final int? rollNo;
  final String? sessionYr;
  final String forMonth;
  final DateTime submissionDate;
  final int subtotal;
  final int discount;
  final int totalAmount;
  final int paidAmount;
  final int totalPaidToDate;
  final int previousPaidAmount;
  final int remainingBalance;
  final List<VoucherPaymentInstallment> paymentHistory;
  final String paymentMode;
  final String bankName;
  final String? bankBranch;
  final String? bankAcctNo;
  final String? remarks;
  final List<FeeReceiptLineItem> lineItems;

  const FeeReceiptPrintData({
    required this.feeTransId,
    required this.voucherMasId,
    required this.stuRegId,
    required this.studentName,
    this.fatherName,
    this.className,
    this.sectionName,
    String? classSecName,
    this.rollNo,
    this.sessionYr,
    required this.forMonth,
    required this.submissionDate,
    required this.subtotal,
    required this.discount,
    required this.totalAmount,
    required this.paidAmount,
    int? totalPaidToDate,
    int? previousPaidAmount,
    int? remainingBalance,
    this.paymentHistory = const [],
    required this.paymentMode,
    required this.bankName,
    this.bankBranch,
    this.bankAcctNo,
    this.remarks,
    required this.lineItems,
  }) : classSecName = classSecName ?? sectionName,
       totalPaidToDate = totalPaidToDate ?? paidAmount,
       previousPaidAmount = previousPaidAmount ?? 0,
       remainingBalance =
           remainingBalance ??
           ((totalAmount - (totalPaidToDate ?? paidAmount)) < 0
               ? 0
               : (totalAmount - (totalPaidToDate ?? paidAmount)));
}

// ============================================================================
// PDF GENERATOR
// ============================================================================

/// Colour constants (PDF-safe - never Flutter Color objects in PDF layer).
class _Clr {
  static const navy = PdfColor.fromInt(0xFF1E3A8A);
  static const teal = PdfColor.fromInt(0xFF0F766E);
  static const slate = PdfColor.fromInt(0xFF334155);
  static const emerald700 = PdfColor.fromInt(0xFF047857);
  static const amber700 = PdfColor.fromInt(0xFFB45309);
  static const amberTint = PdfColor.fromInt(0xFFFFFBEB);
  static const amberBorder = PdfColor.fromInt(0xFFFCD34D);
  static const red700 = PdfColor.fromInt(0xFFB91C1C);
  static const surface = PdfColor.fromInt(0xFFF8FAFC);
  static const borderLight = PdfColor.fromInt(0xFFCBD5E1);
  static const greenTint = PdfColor.fromInt(0xFFF0FDF4);
  static const greenBorder = PdfColor.fromInt(0xFF86EFAC);
  static const rowAlt = PdfColor.fromInt(0xFFF8FAFC);
  static const white = PdfColors.white;
}

class ReceiptPdfGenerator {
  // --------------------------------------------------------------------------
  // Amount-to-words converter
  // --------------------------------------------------------------------------

  static const List<String> _ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  /// Converts an integer rupee amount to Pakistani accounting English words.
  /// e.g. 1920 -> 'Rupees One Thousand Nine Hundred Twenty Only'
  static String amountToWords(int amount) {
    if (amount == 0) return 'Rupees Zero Only';
    return 'Rupees ${_convertToWords(amount)} Only';
  }

  static String _convertToWords(int n) {
    if (n == 0) return '';
    if (n < 20) return _ones[n];
    if (n < 100) {
      final t = _tens[n ~/ 10];
      final r = n % 10;
      return r == 0 ? t : '$t ${_ones[r]}';
    }
    if (n < 1000) {
      final h = _ones[n ~/ 100];
      final r = n % 100;
      return r == 0 ? '$h Hundred' : '$h Hundred ${_convertToWords(r)}';
    }
    if (n < 100000) {
      // Thousands
      final t = _convertToWords(n ~/ 1000);
      final r = n % 1000;
      return r == 0 ? '$t Thousand' : '$t Thousand ${_convertToWords(r)}';
    }
    // Lakhs
    final l = _convertToWords(n ~/ 100000);
    final r = n % 100000;
    return r == 0 ? '$l Lakh' : '$l Lakh ${_convertToWords(r)}';
  }

  // --------------------------------------------------------------------------
  // Currency formatting (comma-separated, 0 decimal places)
  // --------------------------------------------------------------------------

  static String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write(',');
      buf.write(s[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Generates a 3-copy A4 Landscape payment receipt PDF.
  /// Each page contains 3 vertical slip columns (STUDENT | SCHOOL | BANK).
  static Future<Uint8List> generateThreeCopyReceipts({
    required List<FeeReceiptPrintData> receipts,
    required String branchName,
    required String branchAddress,
  }) async {
    final doc = pw.Document();

    for (final r in receipts) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(14),
          build: (ctx) => _buildPage(r, branchName, branchAddress),
        ),
      );
    }

    return doc.save();
  }

  // --------------------------------------------------------------------------
  // Page layout: 3 slips side by side
  // --------------------------------------------------------------------------

  static pw.Widget _buildPage(
    FeeReceiptPrintData r,
    String branchName,
    String branchAddress,
  ) {
    const dividerWidth = 10.0;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(
          child: _buildCopy(
            r,
            branchName,
            branchAddress,
            'STUDENT COPY',
            _Clr.navy,
          ),
        ),
        pw.SizedBox(width: dividerWidth / 2),
        _buildDivider(),
        pw.SizedBox(width: dividerWidth / 2),
        pw.Expanded(
          child: _buildCopy(
            r,
            branchName,
            branchAddress,
            'SCHOOL COPY',
            _Clr.teal,
          ),
        ),
        pw.SizedBox(width: dividerWidth / 2),
        _buildDivider(),
        pw.SizedBox(width: dividerWidth / 2),
        pw.Expanded(
          child: _buildCopy(
            r,
            branchName,
            branchAddress,
            'BANK COPY',
            _Clr.slate,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDivider() {
    return pw.Container(
      width: 1,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(
            color: PdfColors.grey400,
            width: 0.6,
            style: pw.BorderStyle.dashed,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Individual copy slip
  // --------------------------------------------------------------------------

  static pw.Widget _buildCopy(
    FeeReceiptPrintData r,
    String branchName,
    String branchAddress,
    String copyLabel,
    PdfColor bannerColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Top navy accent bar
        pw.Container(height: 3, color: _Clr.navy),
        pw.SizedBox(height: 5),

        // Institutional header
        _buildHeader(branchName, branchAddress),
        pw.SizedBox(height: 4),

        // Copy banner strip
        pw.Container(
          color: bannerColor,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text(
            'OFFICIAL PAYMENT RECEIPT - $copyLabel',
            style: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _Clr.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 4),

        // Receipt metadata strip
        _buildMetaStrip(r),
        pw.SizedBox(height: 4),

        // Student identity box
        _buildStudentBox(r),
        pw.SizedBox(height: 4),

        // Fee table - Expanded to fill remaining space
        pw.Expanded(child: _buildFeeTable(r)),
        pw.SizedBox(height: 4),

        // Financial settlement summary
        _buildSettlementBox(r),
        pw.SizedBox(height: 4),

        // Deposit & signature footer
        _buildFooter(r),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Section builders
  // --------------------------------------------------------------------------

  static pw.Widget _buildHeader(String branchName, String branchAddress) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // School crest
        pw.Container(
          width: 22,
          height: 22,
          decoration: const pw.BoxDecoration(
            color: _Clr.navy,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'AH',
            style: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _Clr.white,
            ),
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              branchName,
              style: const pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _Clr.navy,
              ),
            ),
            pw.Text(
              branchAddress,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMetaStrip(FeeReceiptPrintData r) {
    final receiptNo = 'Receipt No: #${r.feeTransId.toString().padLeft(5, '0')}';
    final dateStr = _formatDate(r.submissionDate);
    final voucherRef = 'Voucher Ref: ${r.voucherMasId}';
    final monthStr = 'Billing Month: ${r.forMonth}';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _Clr.surface,
        border: pw.Border.all(color: _Clr.borderLight, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                receiptNo,
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Date: $dateStr',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(voucherRef, style: const pw.TextStyle(fontSize: 7.5)),
              pw.Text(monthStr, style: const pw.TextStyle(fontSize: 7.5)),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatInstallmentDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return '-';
    try {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return DateFormat('dd-MMM-yyyy').format(parsed);
      }
      final datePart = trimmed.split(' ').first;
      final parsedDatePart = DateTime.tryParse(datePart);
      if (parsedDatePart != null) {
        return DateFormat('dd-MMM-yyyy').format(parsedDatePart);
      }
    } catch (_) {}
    return trimmed;
  }

  static pw.Widget _buildStudentBox(FeeReceiptPrintData r) {
    final sec = (r.classSecName ?? r.sectionName)?.trim();
    final cls = r.className?.trim();
    final classSection = (cls != null && cls.isNotEmpty)
        ? ((sec != null && sec.isNotEmpty && sec != 'N/A') ? '$cls-$sec' : cls)
        : 'Unknown';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _Clr.borderLight, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'Student Name: ${r.studentName}',
            style: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Father Name: ${r.fatherName ?? 'N/A'}',
            style: const pw.TextStyle(fontSize: 7.5),
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            children: [
              pw.Text(
                'Reg ID: ${r.stuRegId}',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Class: $classSection',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Roll No: ${r.rollNo ?? '-'}',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFeeTable(FeeReceiptPrintData r) {
    const colNum = 18.0;
    const colDisc = 34.0;
    const colAmt = 48.0;

    final headers = ['#', 'Fee Particulars', 'Disc', 'Amount (Rs)'];
    final colWidths = {
      0: const pw.FixedColumnWidth(colNum),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FixedColumnWidth(colDisc),
      3: const pw.FixedColumnWidth(colAmt),
    };

    // Header row
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _Clr.navy),
      children: headers.map((h) {
        final isRight = h == 'Disc' || h == 'Amount (Rs)';
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(
            h,
            style: const pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _Clr.white,
            ),
            textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        );
      }).toList(),
    );

    // Data rows
    final dataRows = r.lineItems.asMap().entries.map((entry) {
      final i = entry.key;
      final li = entry.value;
      final bg = i.isEven ? PdfColors.white : _Clr.rowAlt;
      final displayName = FeeHeadDisplay.of(li.headName);
      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Text(
              '${i + 1}',
              style: const pw.TextStyle(fontSize: 7.5),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Text(
              displayName,
              style: const pw.TextStyle(fontSize: 7.5),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Text(
              li.discount > 0 ? _fmt(li.discount) : '-',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 7.5),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Text(
              _fmt(li.amount),
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }).toList();

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.symmetric(
        outside: const pw.BorderSide(color: _Clr.borderLight, width: 0.5),
        inside: const pw.BorderSide(color: PdfColors.grey200, width: 0.3),
      ),
      children: [headerRow, ...dataRows],
    );
  }

  static pw.Widget _buildSettlementBox(FeeReceiptPrintData r) {
    final isPartial = r.remainingBalance > 0;
    final highlightBg = isPartial ? _Clr.amberTint : _Clr.greenTint;
    final highlightBorder = isPartial ? _Clr.amberBorder : _Clr.greenBorder;
    final badgeColor = isPartial ? _Clr.amber700 : _Clr.emerald700;
    final badgeText = isPartial ? '[ PARTIAL PAID ]' : '[ PAID IN FULL ]';
    final receiptNoStr = '#${r.feeTransId.toString().padLeft(5, '0')}';

    final accountingRows = <pw.Widget>[
      _summaryRow('Gross SubTotal:', 'Rs. ${_fmt(r.subtotal)}'),
      if (r.discount > 0)
        _summaryRow('Less Concession / Discount:', '- Rs. ${_fmt(r.discount)}'),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Net Billable Fee:',
              style: const pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Rs. ${_fmt(r.totalAmount)}',
              style: const pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      if (r.previousPaidAmount > 0) ...[
        _summaryRow(
          'Previous Installment(s) Paid:',
          'Rs. ${_fmt(r.previousPaidAmount)}',
        ),
        if (r.paymentHistory.isNotEmpty)
          ...r.paymentHistory
              .where((inst) => inst.feeTransId != r.feeTransId)
              .map((inst) {
                final formattedDate = _formatInstallmentDate(
                  inst.submissionDate,
                );
                final bank =
                    (inst.bankName != null && inst.bankName!.isNotEmpty)
                    ? ' (${inst.bankName})'
                    : '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 4, bottom: 0.5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '  * Rcpt #${inst.feeTransId} ($formattedDate)$bank:',
                        style: const pw.TextStyle(
                          fontSize: 6.5,
                          color: _Clr.slate,
                        ),
                      ),
                      pw.Text(
                        'Rs. ${_fmt(inst.paidAmount)}',
                        style: const pw.TextStyle(
                          fontSize: 6.5,
                          color: _Clr.slate,
                        ),
                      ),
                    ],
                  ),
                );
              }),
        _summaryRow(
          'Paid This Receipt ($receiptNoStr):',
          'Rs. ${_fmt(r.paidAmount)}',
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Paid to Date:',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Rs. ${_fmt(r.totalPaidToDate)}',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: highlightBg,
        border: pw.Border.all(color: highlightBorder, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          ...accountingRows,
          pw.Container(
            height: 0.5,
            margin: const pw.EdgeInsets.symmetric(vertical: 2.5),
            color: highlightBorder,
          ),
          // Highlight Box: Amount Received + Status Badge
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'AMOUNT RECEIVED: Rs. ${_fmt(r.paidAmount)}',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: badgeColor,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: badgeColor, width: 1.2),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(2),
                  ),
                ),
                child: pw.Text(
                  badgeText,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          // Remaining balance line
          pw.Text(
            isPartial
                ? 'REMAINING BALANCE DUE: Rs. ${_fmt(r.remainingBalance)} (UNSETTLED)'
                : 'REMAINING BALANCE DUE: Rs. 0 (FULLY SETTLED)',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: isPartial ? _Clr.red700 : _Clr.emerald700,
            ),
          ),
          pw.SizedBox(height: 1.5),
          // Amount in words
          pw.Text(
            'In Words: ${amountToWords(r.paidAmount)}',
            style: const pw.TextStyle(
              fontSize: 6.5,
              fontStyle: pw.FontStyle.italic,
              color: _Clr.slate,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 7.5)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(FeeReceiptPrintData r) {
    final bankLine = r.bankBranch != null
        ? '${r.paymentMode} - ${r.bankName} (${r.bankBranch})'
        : '${r.paymentMode} - ${r.bankName}';
    final acctLine = r.bankAcctNo != null ? ' (A/C: ${r.bankAcctNo})' : '';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'Mode / Bank: $bankLine$acctLine',
          style: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 8),
        // Signature columns
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 80, height: 0.8, color: PdfColors.grey600),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Cashier Signature',
                  style: const pw.TextStyle(
                    fontSize: 6.5,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(width: 80, height: 0.8, color: PdfColors.grey600),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Authorized Stamp',
                  style: const pw.TextStyle(
                    fontSize: 6.5,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Received with thanks. Computer-generated official receipt.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  static String _formatDate(DateTime d) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
  }
}
