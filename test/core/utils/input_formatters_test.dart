import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/input_formatters.dart';

void main() {
  group('CnicInputFormatter', () {
    const formatter = CnicInputFormatter();

    test('typing single digit "3" -> "3"', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '3',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(result.text, '3');
      expect(result.selection.baseOffset, 1);
    });

    test('typing 5 digits "38302" -> "38302" (no dash)', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '3830',
          selection: TextSelection.collapsed(offset: 4),
        ),
        const TextEditingValue(
          text: '38302',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(result.text, '38302');
      expect(result.selection.baseOffset, 5);
    });

    test('typing 6th digit "383024" -> "38302-4"', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '38302',
          selection: TextSelection.collapsed(offset: 5),
        ),
        const TextEditingValue(
          text: '383024',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(result.text, '38302-4');
      expect(result.selection.baseOffset, 7);
    });

    test('full 13 digits -> "38302-4567890-4"', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '3830245678904',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );
      expect(result.text, '38302-4567890-4');
      expect(result.selection.baseOffset, 15);
    });

    test('paste pre-formatted "38302-4567890-4" -> unchanged', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '38302-4567890-4',
          selection: TextSelection.collapsed(offset: 15),
        ),
      );
      expect(result.text, '38302-4567890-4');
      expect(result.selection.baseOffset, 15);
    });

    test('clearing -> ""', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '38302',
          selection: TextSelection.collapsed(offset: 5),
        ),
        TextEditingValue.empty,
      );
      expect(result.text, '');
      expect(result.selection.baseOffset, 0);
    });

    test('14th digit ignored (capped at 13)', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '38302-4567890-4',
          selection: TextSelection.collapsed(offset: 15),
        ),
        const TextEditingValue(
          text: '38302-4567890-49',
          selection: TextSelection.collapsed(offset: 16),
        ),
      );
      expect(result.text, '38302-4567890-4');
      expect(result.selection.baseOffset, 15);
    });

    test('backspace over dash deletes preceding digit without cursor trap', () {
      // User is at "38302-4" with cursor after the dash (offset 6) and presses backspace
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '38302-4',
          selection: TextSelection.collapsed(offset: 6),
        ),
        const TextEditingValue(
          text: '383024',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      // The digit '2' is deleted, leaving '38304' (5 digits, so no dash)
      expect(result.text, '38304');
      expect(result.selection.baseOffset, 4);
    });
  });

  group('MobileInputFormatter', () {
    const formatter = MobileInputFormatter();

    test('typing 4 digits "0300" -> "0300" (no dash)', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '0300',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(result.text, '0300');
      expect(result.selection.baseOffset, 4);
    });

    test('typing 5th digit "03001" -> "0300-1"', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '0300',
          selection: TextSelection.collapsed(offset: 4),
        ),
        const TextEditingValue(
          text: '03001',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(result.text, '0300-1');
      expect(result.selection.baseOffset, 6);
    });

    test('11 digits -> "0300-1234567"', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '03001234567',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      expect(result.text, '0300-1234567');
      expect(result.selection.baseOffset, 12);
    });

    test('12th digit ignored (capped at 11)', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '0300-1234567',
          selection: TextSelection.collapsed(offset: 12),
        ),
        const TextEditingValue(
          text: '0300-12345678',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );
      expect(result.text, '0300-1234567');
      expect(result.selection.baseOffset, 12);
    });

    test('empty -> ""', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '0300-123',
          selection: TextSelection.collapsed(offset: 8),
        ),
        TextEditingValue.empty,
      );
      expect(result.text, '');
      expect(result.selection.baseOffset, 0);
    });

    test('backspace over dash deletes preceding digit', () {
      // User is at "0300-1" with cursor after dash (offset 5) and presses backspace
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '0300-1',
          selection: TextSelection.collapsed(offset: 5),
        ),
        const TextEditingValue(
          text: '03001',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      // The last '0' before the dash is deleted -> '0301' (4 digits, no dash)
      expect(result.text, '0301');
      expect(result.selection.baseOffset, 3);
    });
  });
}
