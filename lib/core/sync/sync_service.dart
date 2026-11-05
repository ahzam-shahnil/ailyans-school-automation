import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/database.dart';
import 'supabase_client.dart';

// ============================================================================
// Remote adapter — injectable for tests (Supabase.instance crashes in tests)
// ============================================================================

abstract class SyncRemoteAdapter {
  Future<void> upsertRow(String tableName, Map<String, dynamic> payload);
  Future<void> deleteRow(String tableName, Map<String, dynamic> pkMatch);
}

class SupabaseSyncRemoteAdapter implements SyncRemoteAdapter {
  const SupabaseSyncRemoteAdapter();

  @override
  Future<void> upsertRow(String tableName, Map<String, dynamic> payload) async {
    await Supabase.instance.client.rpc(
      'upsert_$tableName',
      params: {'p_payload': payload},
    );
  }

  @override
  Future<void> deleteRow(String tableName, Map<String, dynamic> pkMatch) async {
    await Supabase.instance.client
        .from(tableName)
        .delete()
        .match(pkMatch.cast<String, Object>());
  }
}

/// Test-only fake. Injected from test/sync_push_test.dart.
@visibleForTesting
class FakeSyncRemoteAdapter implements SyncRemoteAdapter {
  final List<({String table, Map<String, dynamic> payload})> upserts = [];
  final List<({String table, Map<String, dynamic> pk})> deletes = [];
  final Set<String> failTables = {};

  @override
  Future<void> upsertRow(String tableName, Map<String, dynamic> payload) async {
    if (failTables.contains(tableName)) {
      throw Exception('Simulated failure for $tableName');
    }
    upserts.add((table: tableName, payload: payload));
  }

  @override
  Future<void> deleteRow(String tableName, Map<String, dynamic> pkMatch) async {
    if (failTables.contains(tableName)) {
      throw Exception('Simulated failure for $tableName');
    }
    deletes.add((table: tableName, pk: pkMatch));
  }
}

// ============================================================================
// PK metadata for all 19 synced tables
// ============================================================================

const Map<String, List<String>> kPkColumns = {
  'Stu_Reg': ['Stu_RegID'],
  'Student_Class': ['Stu_RegID', 'ClassID', 'SessionYr'],
  'Sibling_Links': ['LinkID'],
  'VoucharMas': ['VoucherMasID'],
  'VoucharDet': ['VoucharDetID', 'VoucharMasID', 'feeParameterID'],
  'FeeTransaction': ['FeeTransID'],
  'StuAdv': ['StuAdvID'],
  'AttMas': ['ClassID', 'ClassSecID', 'AttDate'],
  'AttDet': ['AttMasID', 'Stu_RegID'],
  'TAtt': ['TeacherID', 'AttDate'],
  'Teachers': ['TeacherID'],
  'TSalMas': ['TeacherID', 'SalMonth'],
  'TSalDet': ['TSalMasID', 'Detail'],
  'ExamInfo': ['ExTermID', 'SessionYR'],
  'ExamMas': ['ExamInfoID', 'Stu_RegID'],
  'ExamDet': ['ExamMasID', 'SubjID'],
  'SchLeaving': ['StuRegID'],
  'Books': ['BookID'],
  'app_config': ['config_key'],
};

/// Single-column INTEGER/BIGINT PK tables (7 tables, including SchLeaving).
const Set<String> kIntegerPkTables = {
  'Stu_Reg',
  'Sibling_Links',
  'FeeTransaction',
  'StuAdv',
  'Teachers',
  'SchLeaving',
  'Books',
};

// ============================================================================
// Result type
// ============================================================================

class SyncPushResult {
  final int pushedCount;
  final int failedCount;
  final List<String> errors;
  final bool skipped;

  const SyncPushResult({
    required this.pushedCount,
    required this.failedCount,
    required this.errors,
    this.skipped = false,
  });

  static const skippedResult = SyncPushResult(
    pushedCount: 0,
    failedCount: 0,
    errors: [],
    skipped: true,
  );
}

// ============================================================================
// SyncService
// ============================================================================

class SyncService {
  final SyncRemoteAdapter _adapter;
  final Future<Database> Function() _openDb;
  static const int _batchSize = 100;

  SyncService({
    SyncRemoteAdapter? adapter,
    Future<Database> Function()? openDb,
  })  : _adapter = adapter ?? const SupabaseSyncRemoteAdapter(),
        _openDb = openDb ?? (() => DatabaseService.instance.database);

  /// Startup entry point: awaits idempotent init, then pushes. Skipped if
  /// not ready (offline / no creds). Never throws.
  static Future<SyncPushResult> runStartupPush() async {
    final ready = await SupabaseClientWrapper.init();
    if (!ready) {
      debugPrint('[F-4a-2] Skipping startup push (not ready/offline)');
      return SyncPushResult.skippedResult;
    }
    try {
      final svc = SyncService();
      return await svc.pushOutbox();
    } catch (e) {
      debugPrint('[F-4a-2] Startup push error: $e');
      return SyncPushResult(
        pushedCount: 0,
        failedCount: 0,
        errors: [e.toString()],
      );
    }
  }

  Future<SyncPushResult> pushOutbox() async {
    final db = await _openDb();

    // 1. Fetch up to _batchSize oldest rows.
    final rawRows = await db.query(
      '_sync_outbox',
      orderBy: 'id ASC',
      limit: _batchSize,
    );
    if (rawRows.isEmpty) {
      return const SyncPushResult(pushedCount: 0, failedCount: 0, errors: []);
    }

    // 2. Coalesce by (table_name, record_pk) -> keep MAX(id) row.
    final Map<String, Map<String, dynamic>> latest = {};
    final Map<String, List<int>> groupIds = {};
    for (final row in rawRows) {
      final key = '${row['table_name']}|${row['record_pk']}';
      latest[key] = row;
      (groupIds[key] ??= []).add(row['id'] as int);
    }

    int pushed = 0;
    int failed = 0;
    final List<String> errors = [];
    final Set<String> touchedTables = {};

    // 3. Execute each coalesced group.
    for (final entry in latest.entries) {
      final row = entry.value;
      final ids = groupIds[entry.key]!;
      final tableName = row['table_name'] as String;
      final recordPk = row['record_pk'] as String;
      final operation = row['operation'] as String;
      final rowId = row['id'] as int;

      try {
        if (operation == 'DELETE') {
          final pkMap = parseRecordPk(tableName, recordPk);
          await _adapter.deleteRow(tableName, pkMap);
        } else {
          final payload = await reconstructPayload(db, tableName, recordPk);
          if (payload == null) {
            // Vanished row: deleted locally before push. Clean up outbox only.
            await db.delete(
              '_sync_outbox',
              where: 'id IN (${ids.join(",")})',
            );
            continue;
          }
          await _adapter.upsertRow(tableName, payload);
        }
        // Success: delete ALL group IDs covered by this coalesced operation.
        await db.delete(
          '_sync_outbox',
          where: 'id IN (${ids.join(",")})',
        );
        pushed++;
        touchedTables.add(tableName);
      } catch (e) {
        failed++;
        errors.add('$tableName|$recordPk:$e');
        await db.rawUpdate(
          'UPDATE _sync_outbox SET retry_count = retry_count + 1, '
          'last_error = ? WHERE id = ?',
          [e.toString(), rowId],
        );
      }
    }

    // 4. Update watermarks (INSERT ON CONFLICT per table + __global__) when
    //    at least 1 table succeeded.
    if (touchedTables.isNotEmpty) {
      final nowIso =
          DateTime.now().toUtc().toIso8601String().replaceAll('+00:00', 'Z');
      for (final tableName in touchedTables) {
        await db.rawInsert(
          'INSERT INTO _sync_state (table_name, last_pushed_at, is_applying_remote) '
          'VALUES (?, ?, 0) '
          'ON CONFLICT(table_name) DO UPDATE SET last_pushed_at = excluded.last_pushed_at',
          [tableName, nowIso],
        );
      }
      await db.rawUpdate(
        "UPDATE _sync_state SET last_pushed_at = ? WHERE table_name = '__global__'",
        [nowIso],
      );
    }

    debugPrint('[F-4a-2] Push summary: pushed=$pushed, failed=$failed');
    return SyncPushResult(
      pushedCount: pushed,
      failedCount: failed,
      errors: errors,
    );
  }

  /// Reconstruct the current row from SQLite by PK. Null if row is gone.
  Future<Map<String, dynamic>?> reconstructPayload(
    Database db,
    String tableName,
    String recordPk,
  ) async {
    final pkMap = parseRecordPk(tableName, recordPk);
    final cols = kPkColumns[tableName];
    if (cols == null) return null;
    final where = cols.map((c) => '"$c" = ?').join(' AND ');
    final args = cols.map((c) => pkMap[c]).toList();
    final rows = await db.rawQuery(
      'SELECT * FROM "$tableName" WHERE $where LIMIT 1',
      args,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// Parse record_pk. Two shapes:
  /// - JSON object (composite PK from SQLite json_object trigger expression).
  /// - Plain string (single-col PK from CAST(pk AS TEXT)).
  Map<String, dynamic> parseRecordPk(String tableName, String recordPk) {
    final trimmed = recordPk.trimLeft();
    if (trimmed.startsWith('{')) {
      return Map<String, dynamic>.from(
        jsonDecode(recordPk) as Map<String, dynamic>,
      );
    }
    final cols = kPkColumns[tableName];
    if (cols == null || cols.isEmpty) {
      return {'pk': recordPk};
    }
    final col = cols.first;
    if (kIntegerPkTables.contains(tableName)) {
      return {col: int.tryParse(recordPk) ?? recordPk};
    }
    return {col: recordPk};
  }
}
