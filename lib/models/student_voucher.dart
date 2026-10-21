import 'package:intl/intl.dart';

/// Domain model representing a billing voucher for the student fee ledger (`VoucharMas`).
class StudentVoucher {
  final String voucherMasId;
  final DateTime vDate;
  final String forMonth;
  final int subtotal;
  final int discount;
  final int? paidAmount;
  final DateTime? paidDate;
  final String isPaid; // 'Y' / 'N' / 'O' (overdue)
  final DateTime? dueDate;

  const StudentVoucher({
    required this.voucherMasId,
    required this.vDate,
    required this.forMonth,
    required this.subtotal,
    required this.discount,
    this.paidAmount,
    this.paidDate,
    required this.isPaid,
    this.dueDate,
  });

  /// Formatted Issue Date (e.g., "01-Oct-2017").
  String get formattedVDate => DateFormat('dd-MMM-yyyy').format(vDate);

  /// Formatted Due Date (e.g., "10-Oct-2017").
  String get formattedDueDate {
    if (dueDate == null) return '—';
    return DateFormat('dd-MMM-yyyy').format(dueDate!);
  }

  /// Formatted Paid Date (e.g., "09-Oct-2017").
  String get formattedPaidDate {
    if (paidDate == null) return '—';
    return DateFormat('dd-MMM-yyyy').format(paidDate!);
  }

  /// Effective net payable amount after discount.
  int get netPayable => subtotal - discount;

  /// Effective status string: 'Paid', 'Overdue', or 'Unpaid'.
  String get statusText {
    if (isPaid == 'Y') return 'Paid';
    if (dueDate != null && DateTime.now().isAfter(dueDate!)) return 'Overdue';
    if (isPaid == 'O') return 'Overdue';
    return 'Unpaid';
  }

  factory StudentVoucher.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      final str = val.toString().trim();
      if (str.isEmpty) return fallback ?? DateTime.now();
      try {
        return DateTime.parse(str);
      } catch (_) {
        return fallback ?? DateTime.now();
      }
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      final str = val.toString().trim();
      if (str.isEmpty) return null;
      try {
        return DateTime.parse(str);
      } catch (_) {
        return null;
      }
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    return StudentVoucher(
      voucherMasId: map['VoucherMasID'] as String? ?? '',
      vDate: parseDate(map['VDate']),
      forMonth: (map['ForMonth'] as String?)?.trim() ?? '',
      subtotal: (map['SubTotal'] as int?) ?? 0,
      discount: (map['Discount'] as int?) ?? 0,
      paidAmount: parseInt(map['PaidAmount']),
      paidDate: parseNullableDate(map['SubmissionDate']),
      isPaid: (map['IsPaid'] as String?)?.trim() ?? 'N',
      dueDate: parseNullableDate(map['DueDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'VoucherMasID': voucherMasId,
      'VDate': vDate.toIso8601String(),
      'ForMonth': forMonth,
      'SubTotal': subtotal,
      'Discount': discount,
      'PaidAmount': paidAmount,
      'SubmissionDate': paidDate?.toIso8601String(),
      'IsPaid': isPaid,
      'DueDate': dueDate?.toIso8601String(),
    };
  }

  StudentVoucher copyWith({
    String? voucherMasId,
    DateTime? vDate,
    String? forMonth,
    int? subtotal,
    int? discount,
    int? paidAmount,
    DateTime? paidDate,
    String? isPaid,
    DateTime? dueDate,
  }) {
    return StudentVoucher(
      voucherMasId: voucherMasId ?? this.voucherMasId,
      vDate: vDate ?? this.vDate,
      forMonth: forMonth ?? this.forMonth,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      paidAmount: paidAmount ?? this.paidAmount,
      paidDate: paidDate ?? this.paidDate,
      isPaid: isPaid ?? this.isPaid,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}
