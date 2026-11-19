// Canonical date parser for school automation data.
// Handles ISO 8601 strings and legacy Access-migration dates (MM/DD/YY[YY]).

/// Parses a date value into [DateTime], supporting both ISO 8601 strings
/// and legacy Access-migrated date representations ('MM/DD/YY[YY]' with optional
/// time suffix).
///
/// Returns `null` if the value is null, empty, non-parseable, or fails
/// calendar boundary validation (e.g., month rollover like Feb 31).
DateTime? parseFlexibleDate(dynamic val) {
  if (val == null) return null;
  final str = val.toString().trim();
  if (str.isEmpty) return null;

  // ISO 8601 (newer registrations and standard timestamps).
  final iso = DateTime.tryParse(str);
  if (iso != null) return iso;

  // Legacy Access-migration format: MM/DD/YY[YY] [HH:MM:SS].
  final datePart = str.split(' ').first;
  final parts = datePart.split('/');
  if (parts.length == 3) {
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    var y = int.tryParse(parts[2]);
    if (m != null && d != null && y != null) {
      if (y < 100) {
        final pivot = DateTime.now().year % 100;
        y = y <= pivot ? 2000 + y : 1900 + y;
      }
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        final dt = DateTime(y, m, d);
        // Guard against Dart DateTime month rollover (e.g. 02/31/17 -> Mar 3).
        if (dt.year == y && dt.month == m && dt.day == d) {
          return dt;
        }
      }
    }
  }
  return null;
}
