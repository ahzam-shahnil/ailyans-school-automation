import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/fee_head_display.dart';

void main() {
  test('Corrects Annual Cgarges to Annual Charges', () {
    expect(FeeHeadDisplay.of('Annual Cgarges'), 'Annual Charges');
  });
  test('Corrects Arears to Arrears', () {
    expect(FeeHeadDisplay.of('Arears'), 'Arrears');
  });
  test('Trims trailing whitespace', () {
    expect(FeeHeadDisplay.of('Tuition Fee '), 'Tuition Fee');
  });
  test('Passes through unknown names', () {
    expect(FeeHeadDisplay.of('Exam Fee'), 'Exam Fee');
  });
  test('Handles null gracefully', () {
    expect(FeeHeadDisplay.of(null), '');
  });
}
