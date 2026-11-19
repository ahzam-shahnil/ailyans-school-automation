// test/student_parse_date_test.dart
//
// Tests for Student.fromMap parseDate — the local closure that hydrates
// Student.dob and Student.doAdmission from raw SQLite values.
//
// parseDate is a LOCAL closure; we exercise it exclusively via Student.fromMap
// (never by calling parseDate directly).

import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/models/student.dart';

// ---------------------------------------------------------------------------
// Minimal helper — only the fields required by Student.fromMap.
// ---------------------------------------------------------------------------
Student _studentWithDob(dynamic dobRaw) => Student.fromMap({
      'Stu_RegID': 1,
      'NameFirst': 'Test',
      'DOB': dobRaw,
    });

Student _studentWithAdmission(dynamic admRaw) => Student.fromMap({
      'Stu_RegID': 1,
      'NameFirst': 'Test',
      'DOAdmission': admRaw,
    });

void main() {
  group('Student.fromMap parseDate — legacy MM/DD/YY format', () {
    test('03/17/17 00:00:00  → DateTime(2017, 3, 17)', () {
      expect(
        _studentWithDob('03/17/17 00:00:00').dob,
        DateTime(2017, 3, 17),
      );
    });

    test('12/09/05          → DateTime(2005, 12, 9)', () {
      expect(
        _studentWithDob('12/09/05').dob,
        DateTime(2005, 12, 9),
      );
    });

    test('08/25/04 00:00:00 → DateTime(2004, 8, 25)', () {
      expect(
        _studentWithDob('08/25/04 00:00:00').dob,
        DateTime(2004, 8, 25),
      );
    });

    test('11/29/14 00:00:00 → DateTime(2014, 11, 29)', () {
      // Sample from live DB (second part >12 confirms MM/DD order).
      expect(
        _studentWithDob('11/29/14 00:00:00').dob,
        DateTime(2014, 11, 29),
      );
    });
  });

  group('Student.fromMap parseDate — 2-digit year pivot', () {
    // pivot = DateTime.now().year % 100 (e.g. 26 in 2026).
    // y <= pivot → 2000+y; y > pivot → 1900+y.
    test('03/17/99 → DateTime(1999, 3, 17)  (99 > pivot, so 1900+99)', () {
      expect(
        _studentWithDob('03/17/99').dob,
        DateTime(1999, 3, 17),
      );
    });

    test('01/01/00 → DateTime(2000, 1, 1)  (00 <= pivot, so 2000+00)', () {
      expect(
        _studentWithDob('01/01/00').dob,
        DateTime(2000, 1, 1),
      );
    });
  });

  group('Student.fromMap parseDate — ISO 8601 (unchanged behavior)', () {
    test('2002-04-12         → DateTime(2002, 4, 12)', () {
      expect(
        _studentWithDob('2002-04-12').dob,
        DateTime(2002, 4, 12),
      );
    });

    test('2002-04-12 00:00:00 → DateTime(2002, 4, 12)', () {
      // ISO with time component — DateTime.tryParse handles this.
      expect(
        _studentWithDob('2002-04-12 00:00:00').dob,
        DateTime(2002, 4, 12),
      );
    });

    test('2007-07-15         → DateTime(2007, 7, 15)', () {
      expect(
        _studentWithDob('2007-07-15').dob,
        DateTime(2007, 7, 15),
      );
    });
  });

  group('Student.fromMap parseDate — invalid / null / empty → null', () {
    test('null              → null', () {
      expect(_studentWithDob(null).dob, isNull);
    });

    test('empty string      → null', () {
      expect(_studentWithDob('').dob, isNull);
    });

    test('garbage string    → null', () {
      expect(_studentWithDob('garbage').dob, isNull);
    });

    test('13/40/17 (month 13 out of range) → null', () {
      expect(_studentWithDob('13/40/17').dob, isNull);
    });

    test('02/31/17 (calendar rollover guard: Feb has no 31st) → null', () {
      // Dart DateTime(2017, 2, 31) rolls to Mar 3; rollover guard rejects it.
      expect(_studentWithDob('02/31/17').dob, isNull);
    });

    test('00/15/17 (month 0 out of range) → null', () {
      expect(_studentWithDob('00/15/17').dob, isNull);
    });
  });

  group('Student.fromMap doAdmission — same parser via DOAdmission key', () {
    test('03/17/17 00:00:00 → DateTime(2017, 3, 17)', () {
      expect(
        _studentWithAdmission('03/17/17 00:00:00').doAdmission,
        DateTime(2017, 3, 17),
      );
    });

    test('04/02/24 00:00:00 → DateTime(2024, 4, 2)', () {
      // Sample from live DoAdmission column.
      expect(
        _studentWithAdmission('04/02/24 00:00:00').doAdmission,
        DateTime(2024, 4, 2),
      );
    });

    test('ISO 2024-08-15    → DateTime(2024, 8, 15)', () {
      expect(
        _studentWithAdmission('2024-08-15').doAdmission,
        DateTime(2024, 8, 15),
      );
    });

    test('null              → null', () {
      expect(_studentWithAdmission(null).doAdmission, isNull);
    });
  });
}
