import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Phase K-6-c item 4 — delete-attempt audit log (local-only `_delete_audit`
// table, Migration 011).
//
// Purpose: the Nov 2026 field report ("client says student was deleted, the
// row is still there") could not be diagnosed because the client device kept
// no trace of whether the delete attempt ever ran. From Migration 011 on,
// every confirmed permanent-delete attempt leaves a device-local audit row:
//
//   'confirmed' — the user completed the type-DELETE dialog (recorded by the
//                 call site BEFORE the handler runs; direct handler callers
//                 self-record).
//   'success'   — the handler's DELETE transaction committed.
//   'failed'    — the handler threw (error text preserved).
//
// NEVER synced: `_delete_audit` is not a kSyncedTables member, so no
// trg_sync_* capture trigger exists on it and audit writes can never enqueue
// _sync_outbox rows. Rows survive a failed-delete ROLLBACK because outcome
// writes happen OUTSIDE the delete transaction.
//
// Every function takes the [Database] explicitly (testable) and is expected
// to be called through the guard pattern at each call site — an audit
// failure must never abort or alter the delete outcome.

/// Timestamp in the exact `_sync_outbox.created_at` trigger format
/// (strftime('%Y-%m-%dT%H:%M:%fZ','now')) — evaluated by SQLite itself so
/// the two tables' formats can never drift.
Future<String> _auditTimestamp(Database db) async {
  final rows = await db.rawQuery(
    "SELECT strftime('%Y-%m-%dT%H:%M:%fZ','now') AS t",
  );
  return rows.first['t'] as String;
}

/// Records a CONFIRMED permanent-delete attempt for [stuRegId]. Called by
/// the profile screen after the type-DELETE dialog resolves true, and by
/// [permanentlyDeleteStudent] itself for direct invocations. Returns the
/// audit row id to pass back as `auditAttemptId`.
Future<int> recordDeleteConfirmed(
  Database db, {
  required int stuRegId,
  int? attemptedBy,
}) async {
  return db.insert('_delete_audit', {
    'stu_reg_id': stuRegId,
    'attempted_by': attemptedBy,
    'status': 'confirmed',
    'error': null,
    'created_at': await _auditTimestamp(db),
    'updated_at': null,
  });
}

/// Marks an attempt [attemptId] as 'success' after the delete transaction
/// committed. `updated_at` is stamped.
Future<void> markDeleteSuccess(Database db, int attemptId) async {
  await db.update(
    '_delete_audit',
    {
      'status': 'success',
      'updated_at': await _auditTimestamp(db),
    },
    where: 'id = ?',
    whereArgs: [attemptId],
  );
}

/// Marks an attempt [attemptId] as 'failed', preserving [error] as text
/// (`e.toString()`). `updated_at` is stamped. Called OUTSIDE the delete
/// transaction's catch path, so the record survives the ROLLBACK.
Future<void> markDeleteFailed(Database db, int attemptId, Object error) async {
  await db.update(
    '_delete_audit',
    {
      'status': 'failed',
      'error': error.toString(),
      'updated_at': await _auditTimestamp(db),
    },
    where: 'id = ?',
    whereArgs: [attemptId],
  );
}
