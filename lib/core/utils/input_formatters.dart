import 'package:flutter/services.dart';

/// Formatter for Pakistani CNIC / CRC / B-Form numbers.
///
/// Output pattern: `XXXXX-XXXXXXX-X` (13 raw digits, 15 chars).
/// Dashes are only inserted when the next block has at least 1 digit present:
/// - `""` -> `""`
/// - `"3"` -> `"3"`
/// - `"38302"` -> `"38302"`
/// - `"383024"` -> `"38302-4"`
/// - `"3830245678904"` -> `"38302-4567890-4"`
///
/// Prevents cursor trapping on backspace over dashes.
class CnicInputFormatter extends TextInputFormatter {
  const CnicInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Detect if user deleted a character immediately after a dash (backspace over dash)
    final bool isDeleting = oldValue.text.length > newValue.text.length;
    final bool deletedDash =
        isDeleting &&
        oldValue.selection.baseOffset > 0 &&
        oldValue.text[oldValue.selection.baseOffset - 1] == '-';

    // Count raw digits in newValue before cursor
    int rawDigitsBeforeCursor = 0;
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    for (int i = 0; i < cursor; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        rawDigitsBeforeCursor++;
      }
    }

    // Extract all raw digits from newValue
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (deletedDash && digits.isNotEmpty) {
      // User pressed backspace over a dash: delete the digit preceding the dash
      final deleteIndex = (rawDigitsBeforeCursor - 1).clamp(
        0,
        digits.length - 1,
      );
      digits =
          digits.substring(0, deleteIndex) +
          (deleteIndex + 1 < digits.length
              ? digits.substring(deleteIndex + 1)
              : '');
      rawDigitsBeforeCursor = deleteIndex;
    }

    // Cap at 13 digits
    if (digits.length > 13) {
      digits = digits.substring(0, 13);
    }
    rawDigitsBeforeCursor = rawDigitsBeforeCursor.clamp(0, digits.length);

    // Format digits as XXXXX-XXXXXXX-X
    final formatted = _formatCnic(digits);

    // Calculate new cursor offset in formatted text
    final newOffset = _getOffsetForRawDigitCount(
      formatted,
      rawDigitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  static String _formatCnic(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 5) return digits;
    if (digits.length <= 12) {
      return '${digits.substring(0, 5)}-${digits.substring(5)}';
    }
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
  }

  static int _getOffsetForRawDigitCount(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;
    int seen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        seen++;
        if (seen == digitCount) {
          return i + 1;
        }
      }
    }
    return formatted.length;
  }
}

/// Formatter for Pakistani mobile contact numbers.
///
/// Output pattern: `XXXX-XXXXXXX` (11 raw digits, 12 chars).
/// Dashes are only inserted when the 5th digit exists:
/// - `""` -> `""`
/// - `"0300"` -> `"0300"`
/// - `"03001"` -> `"0300-1"`
/// - `"03001234567"` -> `"0300-1234567"`
///
/// Prevents cursor trapping on backspace over dashes.
class MobileInputFormatter extends TextInputFormatter {
  const MobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Detect if user deleted a character immediately after a dash (backspace over dash)
    final bool isDeleting = oldValue.text.length > newValue.text.length;
    final bool deletedDash =
        isDeleting &&
        oldValue.selection.baseOffset > 0 &&
        oldValue.text[oldValue.selection.baseOffset - 1] == '-';

    // Count raw digits in newValue before cursor
    int rawDigitsBeforeCursor = 0;
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    for (int i = 0; i < cursor; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        rawDigitsBeforeCursor++;
      }
    }

    // Extract all raw digits from newValue
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (deletedDash && digits.isNotEmpty) {
      // User pressed backspace over a dash: delete the digit preceding the dash
      final deleteIndex = (rawDigitsBeforeCursor - 1).clamp(
        0,
        digits.length - 1,
      );
      digits =
          digits.substring(0, deleteIndex) +
          (deleteIndex + 1 < digits.length
              ? digits.substring(deleteIndex + 1)
              : '');
      rawDigitsBeforeCursor = deleteIndex;
    }

    // Cap at 11 digits
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }
    rawDigitsBeforeCursor = rawDigitsBeforeCursor.clamp(0, digits.length);

    // Format digits as XXXX-XXXXXXX
    final formatted = _formatMobile(digits);

    // Calculate new cursor offset in formatted text
    final newOffset = _getOffsetForRawDigitCount(
      formatted,
      rawDigitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  static String _formatMobile(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 4) return digits;
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }

  static int _getOffsetForRawDigitCount(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;
    int seen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        seen++;
        if (seen == digitCount) {
          return i + 1;
        }
      }
    }
    return formatted.length;
  }
}
