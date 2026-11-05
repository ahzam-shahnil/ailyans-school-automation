import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/database.dart';
import 'node_id_allocator.dart';
import 'supabase_client.dart';

// ============================================================================
// Remote adapter — injectable for tests (Supabase.instance crashes in tests)
// ============================================================================

abstract class SyncRemoteAdapter {
  Future<void> upsertRow(String tableName, Map<String, dynamic> payload);
  Future<void> deleteRow(String tableName, Map<String, dynamic> pkMatch);
  Future<List<Map<String, dynamic>>> fetchDelta(
    String tableName, {
    String? sinceIso,
    int offset = 0,
    int limit = 500,
  });
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

  @override
  Future<List<Map<String, dynamic>>> fetchDelta(
    String tableName, {
    String? sinceIso,
    int offset = 0,
    int limit = 500,
  }) async {
    var query = Supabase.instance.client.from(tableName).select();
    if (sinceIso != null) {
      query = query.gt('updated_at', sinceIso);
    }
    final rows = await query
        .order('updated_at', ascending: true)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }
}

/// Test-only fake. Injected from test/sync_push_test.dart.
@visibleForTesting
class FakeSyncRemoteAdapter implements SyncRemoteAdapter {
  final List<({String table, Map<String, dynamic> payload})> upserts = [];
  final List<({String table, Map<String, dynamic> pk})> deletes = [];
  final Set<String> failTables = {};

  /// Optional fake for fetchDelta. Returns [] if null (push tests unaffected).
  List<Map<String, dynamic>> Function(
          String table, String? sinceIso, int offset, int limit)?
      fakeFetchDelta;

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

  @override
  Future<List<Map<String, dynamic>>> fetchDelta(
    String tableName, {
    String? sinceIso,
    int offset = 0,
    int limit = 500,
  }) async {
    if (fakeFetchDelta == null) return const [];
    if (failTables.contains(tableName)) {
      throw Exception('Simulated fetchDelta failure for $tableName');
    }
    return fakeFetchDelta!(tableName, sinceIso, offset, limit);
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

/// Pull order respects FK dependencies (parents before children).
const List<String> kPullTableOrder = [
  'Stu_Reg', 'Teachers', 'Books', 'ExamInfo', 'app_config',
  'Student_Class', 'Sibling_Links', 'VoucharMas', 'TSalMas', 'ExamMas',
  'SchLeaving', 'StuAdv',
  'VoucharDet', 'TSalDet', 'AttMas', 'ExamDet',
  'FeeTransaction', 'AttDet', 'TAtt',
];

/// Device-local app_config keys. These must never cross the sync boundary:
/// each device owns its node block and its own Supabase credentials.
const Set<String> kDeviceLocalConfigKeys = {
  'node_id',
  'supabase_url',
  'supabase_anon_key',
  'supabase_sync_email',
  'supabase_sync_password',
};

// ============================================================================
// Result types
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

class SyncPullResult {
  final int pulledCount;
  final int failedCount;
  final List<String> errors;
  final bool skipped;

  const SyncPullResult({
    required this.pulledCount,
    required this.failedCount,
    required this.errors,
    this.skipped = false,
  });

  static const skippedResult = SyncPullResult(
    pulledCount: 0,
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

  /// Startup push: awaits idempotent init, resets any stale re-entrancy guard,
  /// then drains the outbox. Skipped if offline/unconfigured. Never throws.
  static Future<SyncPushResult> runStartupPush() async {
    final ready = await SupabaseClientWrapper.init();
    if (!ready) {
      debugPrint('[F-4a-2] Skipping startup push (not ready/offline)');
      return SyncPushResult.skippedResult;
    }
    try {
      // F-4b: defensive reset in case a prior pull crashed before clearing
      // is_applying_remote, which would permanently suppress outbox triggers.
      final db = await DatabaseService.instance.database;
      await db.rawUpdate(
        "UPDATE _sync_state SET is_applying_remote = 0 "
        "WHERE table_name = '__global__'",
      );
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

  /// Startup pull: awaits idempotent init, then pulls deltas for all 19 tables.
  /// Skipped if offline/unconfigured. Never throws.
  static Future<SyncPullResult> runStartupPull() async {
    final ready = await SupabaseClientWrapper.init();
    if (!ready) {
      debugPrint('[F-4b] Skipping startup pull (not ready/offline)');
      return SyncPullResult.skippedResult;
    }
    try {
      final svc = SyncService();
      return await svc.pullDelta();
    } catch (e) {
      debugPrint('[F-4b] Startup pull error: $e');
      return SyncPullResult(
        pulledCount: 0,
        failedCount: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Force push: reset retry state on every failed outbox row, then drain the
  /// outbox until it is empty. Does NOT push arbitrary local rows — only the
  /// pending outbox. Skipped when unconfigured unless a [serviceFactory] is
  /// injected (unit tests).
  static Future<SyncPushResult> runForcePushAll({
    SyncService Function()? serviceFactory,
  }) async {
    if (serviceFactory == null) {
      final ready = await SupabaseClientWrapper.init();
      if (!ready) {
        debugPrint('[F-6] Skipping force push (not ready/offline)');
        return SyncPushResult.skippedResult;
      }
    }

    final db = await DatabaseService.instance.database;
    await db.rawUpdate(
      'UPDATE _sync_outbox SET retry_count = 0, last_error = NULL '
      'WHERE retry_count > 0',
    );

    final svc = (serviceFactory ?? () => SyncService())();

    int totalPushed = 0;
    int totalFailed = 0;
    final errors = <String>[];
    int stalls = 0;
    int lastCount = -1;

    while (true) {
      final countRow =
          await db.rawQuery('SELECT COUNT(*) AS n FROM _sync_outbox');
      final count = (countRow.first['n'] as num?)?.toInt() ?? 0;
      if (count == 0) break;

      if (count == lastCount) {
        stalls++;
      } else {
        stalls = 0;
      }
      lastCount = count;

      if (stalls >= 3) {
        errors.add('forcePushAll stalled at $count rows');
        break;
      }

      final r = await svc.pushOutbox();
      totalPushed += r.pushedCount;
      totalFailed += r.failedCount;
      errors.addAll(r.errors);

      // Nothing progressed and nothing is left to retry in this pass.
      if (r.failedCount > 0 && r.pushedCount == 0) break;
    }

    debugPrint(
      '[F-6] Force push summary: pushed=$totalPushed, failed=$totalFailed',
    );
    return SyncPushResult(
      pushedCount: totalPushed,
      failedCount: totalFailed,
      errors: errors,
    );
  }

  /// Force pull: clear every table watermark, then run a full delta pull.
  /// Reuses pullDelta's per-page transaction and dirty-row guard.
  static Future<SyncPullResult> runForcePullAll({
    SyncService Function()? serviceFactory,
  }) async {
    if (serviceFactory == null) {
      final ready = await SupabaseClientWrapper.init();
      if (!ready) {
        debugPrint('[F-6] Skipping force pull (not ready/offline)');
        return SyncPullResult.skippedResult;
      }
    }

    final db = await DatabaseService.instance.database;
    final tables = [...kPullTableOrder, '__global__'];
    final placeholders = List.filled(tables.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE _sync_state SET last_pulled_at = NULL '
      'WHERE table_name IN ($placeholders)',
      tables,
    );

    final svc = (serviceFactory ?? () => SyncService())();
    return await svc.pullDelta();
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

      // Device-local app_config keys never leave this device. Drop the
      // coalesced outbox rows without contacting the remote.
      if (tableName == 'app_config' &&
          kDeviceLocalConfigKeys.contains(recordPk)) {
        await db.delete(
          '_sync_outbox',
          where: 'id IN (${ids.join(",")})',
        );
        continue;
      }

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

  /// Pull remote deltas for all synced tables in FK-safe order.
  /// Uses per-page transactions with re-entrancy guard and LedgerReconciler.
  Future<SyncPullResult> pullDelta() async {
    final db = await _openDb();
    int totalPulled = 0;
    int totalFailed = 0;
    final errors = <String>[];

    // Preload dirty keys ONCE — rows with pending local edits that must not
    // be overwritten by remote data (except append-only tables).
    final dirtyRows = await db.query(
      '_sync_outbox',
      columns: ['table_name', 'record_pk'],
    );
    final dirtyKeys = dirtyRows
        .map((r) => '${r['table_name']}|${r['record_pk']}')
        .toSet();

    for (final tableName in kPullTableOrder) {
      // Rule 5 CORRECTION: read watermark ONCE per table (fixed for all pages).
      final stateRows = await db.query(
        '_sync_state',
        columns: ['last_pulled_at'],
        where: 'table_name = ?',
        whereArgs: [tableName],
      );
      final initialSinceIso = stateRows.isEmpty
          ? null
          : stateRows.first['last_pulled_at'] as String?;

      int offset = 0;
      while (true) {
        List<Map<String, dynamic>> remoteRows;
        try {
          remoteRows = await _adapter.fetchDelta(
            tableName,
            sinceIso: initialSinceIso,
            offset: offset,
            limit: 500,
          );
        } catch (e) {
          totalFailed++;
          errors.add('$tableName|fetch@$offset: $e');
          break;
        }
        if (remoteRows.isEmpty) break;

        try {
          await db.transaction((txn) async {
            // Rule 2: re-entrancy guard suppresses outbox triggers during pull.
            await txn.rawUpdate(
              "UPDATE _sync_state SET is_applying_remote = 1 "
              "WHERE table_name = '__global__'",
            );

            final touchedVouchers = <String>{};

            for (final remoteRow in remoteRows) {
              final row = Map<String, dynamic>.from(remoteRow);

              // Rule 1: strip updated_at before inserting into local SQLite
              // (local schema has no updated_at column).
              row.remove('updated_at');

              // Rule 3: skip dirty rows (pending local edits win), except for
              // append-only tables where both local and remote rows are valid.
              if (tableName != 'FeeTransaction' && tableName != 'StuAdv') {
                final recordPk = buildRecordPkFromRow(tableName, row);
                if (dirtyKeys.contains('$tableName|$recordPk')) {
                  continue;
                }
              }

              // Device-local app_config keys are never overwritten by remote
              // values; each device keeps its own node block/credentials.
              if (tableName == 'app_config' &&
                  kDeviceLocalConfigKeys.contains(row['config_key'])) {
                continue;
              }

              await txn.insert(
                tableName,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              // Rule 4 CORRECTION: collect voucher IDs from all three sources.
              if (tableName == 'VoucharMas') {
                final vId = row['VoucherMasID'];
                if (vId is String && vId.isNotEmpty) touchedVouchers.add(vId);
              } else if (tableName == 'FeeTransaction') {
                final vNo = row['VoucharNo'];
                if (vNo is String && vNo.isNotEmpty) touchedVouchers.add(vNo);
              } else if (tableName == 'StuAdv') {
                final vId = row['VoucherMasID'];
                if (vId is String && vId.isNotEmpty) touchedVouchers.add(vId);
              }
            }

            // Rule 2 addendum: reconcile every touched voucher per page.
            for (final vId in touchedVouchers) {
              await LedgerReconciler.reconcileVoucher(txn, vId);
            }

            // Rule 5 CORRECTION: advance watermark to MAX(remote.updated_at)
            // using the original remoteRows (before stripping).
            final updatedAts = remoteRows
                .map((r) => r['updated_at'] as String?)
                .whereType<String>();
            if (updatedAts.isNotEmpty) {
              final pageMax =
                  updatedAts.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
              await txn.rawInsert(
                'INSERT INTO _sync_state '
                '(table_name, last_pulled_at, is_applying_remote) '
                'VALUES (?, ?, 0) '
                'ON CONFLICT(table_name) DO UPDATE '
                'SET last_pulled_at = excluded.last_pulled_at',
                [tableName, pageMax],
              );
              await txn.rawUpdate(
                "UPDATE _sync_state SET last_pulled_at = ? "
                "WHERE table_name = '__global__'",
                [pageMax],
              );
            }

            // Clear re-entrancy guard.
            await txn.rawUpdate(
              "UPDATE _sync_state SET is_applying_remote = 0 "
              "WHERE table_name = '__global__'",
            );
          });

          totalPulled += remoteRows.length;
        } catch (e) {
          totalFailed += remoteRows.length;
          errors.add('$tableName|apply@$offset: $e');
          break;
        }

        if (remoteRows.length < 500) break;
        offset += remoteRows.length;
      }
    }

    debugPrint('[F-4b] Pull summary: pulled=$totalPulled, failed=$totalFailed');
    return SyncPullResult(
      pulledCount: totalPulled,
      failedCount: totalFailed,
      errors: errors,
    );
  }

  /// Build the record_pk string for a row (mirrors the trigger expression).
  /// Single-col PK: CAST(value AS TEXT). Composite PK: JSON object.
  String buildRecordPkFromRow(String tableName, Map<String, dynamic> row) {
    final cols = kPkColumns[tableName];
    if (cols == null || cols.isEmpty) return '';
    if (cols.length == 1) {
      return '${row[cols.first]}';
    }
    return jsonEncode({for (final c in cols) c: row[c]});
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
