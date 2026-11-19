// Tests for parseFlexibleDate: canonical date parser for school automation data.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:school_automation/core/utils/date_parse.dart';

void main() {
  group('parseFlexibleDate — legacy MM/DD/YY format', () {
    test('03/17/17 00:00:00 → DateTime(2017, 3, 17)', () {
      expect(parseFlexibleDate('03/17/17 00:00:00'), DateTime(2017, 3, 17));
    });

    test('12/09/05 → DateTime(2005, 12, 9)', () {
      expect(parseFlexibleDate('12/09/05'), DateTime(2005, 12, 9));
    });

    test('08/25/04 00:00:00 → DateTime(2004, 8, 25)', () {
      expect(parseFlexibleDate('08/25/04 00:00:00'), DateTime(2004, 8, 25));
    });

    test('11/29/14 00:00:00 → DateTime(2014, 11, 29)', () {
      expect(parseFlexibleDate('11/29/14 00:00:00'), DateTime(2014, 11, 29));
    });

    test('06/02/16 → DateTime(2016, 6, 2) formatted as 02-Jun-2016', () {
      final dt = parseFlexibleDate('06/02/16');
      expect(dt, DateTime(2016, 6, 2));
      expect(DateFormat('dd-MMM-yyyy').format(dt!), '02-Jun-2016');
    });
  });

  group('parseFlexibleDate — 2-digit year pivot', () {
    test('03/17/99 → DateTime(1999, 3, 17) (99 > pivot, so 1900+99)', () {
      expect(parseFlexibleDate('03/17/99'), DateTime(1999, 3, 17));
    });

    test('01/01/00 → DateTime(2000, 1, 1) (00 <= pivot, so 2000+00)', () {
      expect(parseFlexibleDate('01/01/00'), DateTime(2000, 1, 1));
    });
  });

  group('parseFlexibleDate — ISO 8601', () {
    test('2002-04-12 → DateTime(2002, 4, 12) formatted as 12-Apr-2002', () {
      final dt = parseFlexibleDate('2002-04-12');
      expect(dt, DateTime(2002, 4, 12));
      expect(DateFormat('dd-MMM-yyyy').format(dt!), '12-Apr-2002');
    });

    test('2002-04-12 00:00:00 → DateTime(2002, 4, 12)', () {
      expect(parseFlexibleDate('2002-04-12 00:00:00'), DateTime(2002, 4, 12));
    });

    test('2007-07-15 → DateTime(2007, 7, 15)', () {
      expect(parseFlexibleDate('2007-07-15'), DateTime(2007, 7, 15));
    });
  });

  group('parseFlexibleDate — invalid / null / empty', () {
    test('null → null', () {
      expect(parseFlexibleDate(null), isNull);
    });

    test('empty string → null', () {
      expect(parseFlexibleDate(''), isNull);
    });

    test('whitespace string → null', () {
      expect(parseFlexibleDate('   '), isNull);
    });

    test('garbage string → null', () {
      expect(parseFlexibleDate('invalid-date'), isNull);
    });

    test('13/40/17 (month 13 out of range) → null', () {
      expect(parseFlexibleDate('13/40/17'), isNull);
    });

    test('02/31/17 (calendar rollover guard: Feb has no 31st) → null', () {
      expect(parseFlexibleDate('02/31/17'), isNull);
    });

    test('00/15/17 (month 0 out of range) → null', () {
      expect(parseFlexibleDate('00/15/17'), isNull);
    });
  });
}
