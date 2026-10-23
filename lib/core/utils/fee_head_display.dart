/// Maps legacy VB6 typo spellings in FeeParameters.ParamDesciption
/// to display-corrected names for UI and PDF output.
///
/// DB values remain unchanged (verbatim legacy typos preserved per
/// project rules). Only UI/PDF presentation is corrected.
class FeeHeadDisplay {
  static const Map<String, String> _corrections = {
    'Annual Cgarges': 'Annual Charges',
    'Arears': 'Arrears', // also correct in display
    // Add more as discovered
  };

  /// Returns the display name for a given DB ParamDesciption value.
  /// Trims whitespace first (some values have trailing spaces).
  static String of(String? dbName) {
    if (dbName == null) return '';
    final trimmed = dbName.trim();
    return _corrections[trimmed] ?? trimmed;
  }
}
