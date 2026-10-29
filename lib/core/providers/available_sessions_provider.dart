import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'clock_provider.dart';

/// Distinct session years available for dropdowns.
///
/// Sources (in priority order):
///   1. DISTINCT SessionYr from Student_Class (real enrollment data)
///   2. DISTINCT SessionYr from VoucharMas (real voucher data)
///   3. app_config.default_session_yr (active session anchor)
///   4. currentYear, currentYear+1, currentYear+2 (calendar-derived, for
///      pre-registration of future sessions)
///
/// Format: YYYY-YY (2-digit end). All returned values match this format,
/// including the DB-derived ones (verified against live DB where Student_Class
/// and VoucharMas use YYYY-YY format consistently).
///
/// Do NOT include Cls_Param_Fee.FeeYr or ExamInfo.SessionYR — FeeYr has
/// '201819' (6-char, no hyphen) mixed with YYYY-YY; including would break
/// dropdown item matching.
///
/// Cached (not autoDispose). Invalidate from save paths (SystemSettings,
/// BatchPromotion, ExamTerm) after session-changing mutations.
final availableSessionsProvider = FutureProvider<List<String>>((ref) async {
  final db = await DatabaseService.instance.database;
  final rows = await db.rawQuery('''
    SELECT DISTINCT SessionYr FROM Student_Class
    WHERE SessionYr IS NOT NULL AND SessionYr != ''
    UNION
    SELECT DISTINCT SessionYr FROM VoucharMas
    WHERE SessionYr IS NOT NULL AND SessionYr != ''
  ''');

  final dbSessions = rows
      .map((r) => (r['SessionYr'] as String?)?.trim() ?? '')
      .where((s) => s.isNotEmpty)
      .toSet();

  // Anchor on app_config.default_session_yr if available, else calendar year
  String? anchor;
  try {
    final confRows = await db.rawQuery(
      "SELECT config_value FROM app_config WHERE config_key = 'default_session_yr' LIMIT 1",
    );
    if (confRows.isNotEmpty) {
      anchor = (confRows.first['config_value'] as String?)?.trim();
    }
  } catch (_) {}

  final now = ref.read(clockProvider)();
  final currentYear = now.year;
  final calSessions = <String>{
    '$currentYear-${(currentYear + 1) % 100}',
    '${currentYear + 1}-${(currentYear + 2) % 100}',
    '${currentYear + 2}-${(currentYear + 3) % 100}',
  };

  // Add anchor-year neighbors if anchor exists
  final anchorYear = anchor != null
      ? int.tryParse(anchor.split('-').first)
      : null;
  if (anchorYear != null) {
    calSessions.add('${anchorYear - 1}-${anchorYear % 100}');
    calSessions.add('$anchorYear-${(anchorYear + 1) % 100}');
    calSessions.add('${anchorYear + 1}-${(anchorYear + 2) % 100}');
    calSessions.add('${anchorYear + 2}-${(anchorYear + 3) % 100}');
  }

  final all = <String>{
    ...dbSessions,
    ...calSessions,
    if (anchor != null && anchor.isNotEmpty) anchor,
  };

  final sorted = all.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
});
