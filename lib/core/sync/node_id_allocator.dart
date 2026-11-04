import 'package:school_automation/core/db/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class BlockExhaustedException implements Exception {
  final String nodeId;
  final int blockStart;
  final int blockEnd;
  final int currentAllocation;

  const BlockExhaustedException({
    required this.nodeId,
    required this.blockStart,
    required this.blockEnd,
    required this.currentAllocation,
  });

  @override
  String toString() =>
      'BlockExhaustedException: node "$nodeId" block $blockStart..$blockEnd '
      'is exhausted (next_allocated_id=$currentAllocation).';
}

class NodeIdAllocator {
  final Future<Database> Function() _open;

  NodeIdAllocator({Future<Database> Function()? openDb})
    : _open = openDb ?? (() => DatabaseService.instance.database);

  static const Map<String, int> kBlockStart = {
    'windows': 100000,
    'android_a': 200000,
    'android_b': 300000,
  };

  static const Map<String, int> kBlockEnd = {
    'windows': 199999,
    'android_a': 299999,
    'android_b': 399999,
  };

  /// Set node_block_start / node_block_end / next_allocated_id for the named
  /// node. Call once per app boot after migrations. Idempotent.
  Future<void> configureNodeBlock(String nodeId) async {
    final key = nodeId.toLowerCase();
    final start = kBlockStart[key] ?? kBlockStart['windows']!;
    final end = kBlockEnd[key] ?? kBlockEnd['windows']!;
    final db = await _open();
    await db.rawUpdate(
      'UPDATE _sync_state SET node_block_start = ?, node_block_end = ?, '
      'next_allocated_id = CASE '
      '  WHEN next_allocated_id IS NULL OR next_allocated_id < ? THEN ? '
      '  ELSE next_allocated_id END '
      "WHERE table_name = '__node__'",
      [start, end, start, start],
    );
  }

  /// Allocate the next integer ID from this node's block. Transaction-safe.
  Future<int> nextId({String? tableName, String? pkColumn}) async {
    final db = await _open();
    return db.transaction<int>(
      (txn) => allocateInTransaction(
        txn,
        tableName: tableName,
        pkColumn: pkColumn,
      ),
    );
  }

  /// Usable inside an already-open transaction (F-3b provider callers use this).
  static Future<int> allocateInTransaction(
    DatabaseExecutor txn, {
    String? tableName,
    String? pkColumn,
  }) async {
    // Acquire the write lock so two concurrent callers cannot see the same row.
    await txn.rawUpdate(
      "UPDATE _sync_state SET is_applying_remote = is_applying_remote "
      "WHERE table_name = '__node__'",
    );

    final rows = await txn.query(
      '_sync_state',
      columns: ['node_block_start', 'node_block_end', 'next_allocated_id'],
      where: "table_name = '__node__'",
    );

    if (rows.isEmpty) {
      // Minimal test fixture fallback: no _sync_state row, use MAX(pk) + 1.
      if (tableName != null && pkColumn != null) {
        final m = await txn.rawQuery(
          'SELECT COALESCE(MAX($pkColumn), 0) + 1 AS n FROM "$tableName"',
        );
        return (m.first['n'] as num).toInt();
      }
      throw StateError(
        'No __node__ row in _sync_state and no fallback table/pk',
      );
    }

    final r = rows.first;
    final start = (r['node_block_start'] as int?) ?? 100000;
    final end = (r['node_block_end'] as int?) ?? 199999;
    int next = (r['next_allocated_id'] as int?) ?? start;

    // Defensive MAX(pk) guard: never return an ID already used inside this
    // block by a legacy row (e.g. FeeTransID=18790 with block 10000..19999).
    if (tableName != null && pkColumn != null) {
      final maxInBlock = await txn.rawQuery(
        'SELECT COALESCE(MAX($pkColumn), 0) AS m FROM "$tableName" '
        'WHERE $pkColumn >= ? AND $pkColumn <= ?',
        [start, end],
      );
      final m = (maxInBlock.first['m'] as num?)?.toInt() ?? 0;
      if (m >= next) next = m + 1;
    }

    if (next > end) {
      final cfg = await txn.query(
        'app_config',
        columns: ['config_value'],
        where: "config_key = 'node_id'",
      );
      final nodeId = cfg.isEmpty
          ? 'windows'
          : (cfg.first['config_value'] as String);
      throw BlockExhaustedException(
        nodeId: nodeId,
        blockStart: start,
        blockEnd: end,
        currentAllocation: next,
      );
    }

    await txn.update(
      '_sync_state',
      {'next_allocated_id': next + 1},
      where: "table_name = '__node__'",
    );
    return next;
  }

  Future<({int blockStart, int blockEnd, int nextAllocated})> state() async {
    final db = await _open();
    final rows = await db.query(
      '_sync_state',
      columns: ['node_block_start', 'node_block_end', 'next_allocated_id'],
      where: "table_name = '__node__'",
    );
    final r = rows.first;
    return (
      blockStart: (r['node_block_start'] as int?) ?? 100000,
      blockEnd: (r['node_block_end'] as int?) ?? 199999,
      nextAllocated: (r['next_allocated_id'] as int?) ?? 100000,
    );
  }
}

/// Append-only fee ledger reconciliation. Deterministically recomputes
/// VoucharMas.PaidAmt and IsPaid from cash received (FeeTransaction) plus
/// advance deductions (negative StuAdv rows linked by VoucherMasID), so two
/// devices that each collected an offline partial payment never overwrite each
/// other on sync (LWW is never applied to money).
class LedgerReconciler {
  static Future<({int totalPaid, String isPaid})> reconcileVoucher(
    DatabaseExecutor db,
    String voucherMasId,
  ) async {
    // Cash received via FeeTransaction.
    final cashRows = await db.rawQuery(
      'SELECT COALESCE(SUM(PaidAmount), 0) AS totalPaid '
      'FROM FeeTransaction WHERE VoucharNo = ?',
      [voucherMasId],
    );
    final cashPaid = (cashRows.first['totalPaid'] as num?)?.toInt() ?? 0;

    // Advance deduction: negative AdvAmount rows linked by VoucherMasID.
    // SUM(-AdvAmount) turns -500 into +500 as contribution to PaidAmt.
    final advRows = await db.rawQuery(
      'SELECT COALESCE(SUM(-AdvAmount), 0) AS advancePaid '
      'FROM StuAdv WHERE VoucherMasID = ? AND AdvAmount < 0',
      [voucherMasId],
    );
    final advancePaid = (advRows.first['advancePaid'] as num?)?.toInt() ?? 0;

    final totalPaid = cashPaid + advancePaid;

    final vmRows = await db.rawQuery(
      'SELECT SubTotal, COALESCE(Discount, 0) AS disc, IsPaid '
      'FROM VoucharMas WHERE VoucherMasID = ?',
      [voucherMasId],
    );
    if (vmRows.isEmpty) {
      return (totalPaid: totalPaid, isPaid: 'N');
    }

    final subTotal = (vmRows.first['SubTotal'] as num?)?.toInt() ?? 0;
    final discount = (vmRows.first['disc'] as num?)?.toInt() ?? 0;
    final currentStatus = vmRows.first['IsPaid'] as String? ?? 'N';

    final rawNet = subTotal - discount;
    final clampedNet = rawNet < 0 ? 0 : rawNet;

    final String newIsPaid;
    if (currentStatus == 'O' && totalPaid == 0) {
      newIsPaid = 'O';
    } else {
      newIsPaid = totalPaid >= clampedNet ? 'Y' : 'N';
    }

    await db.rawUpdate(
      'UPDATE VoucharMas SET PaidAmt = ?, IsPaid = ? WHERE VoucherMasID = ?',
      [totalPaid, newIsPaid, voucherMasId],
    );
    return (totalPaid: totalPaid, isPaid: newIsPaid);
  }
}
