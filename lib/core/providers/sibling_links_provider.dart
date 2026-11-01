import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db/database.dart';

/// Data model for a canonical student sibling relationship row.
class SiblingLink {
  final int linkId;
  final int stu1RegId;
  final int stu2RegId;
  final String? relation;
  final String? linkedBy;
  final String? linkedOn;

  const SiblingLink({
    required this.linkId,
    required this.stu1RegId,
    required this.stu2RegId,
    this.relation,
    this.linkedBy,
    this.linkedOn,
  });

  factory SiblingLink.fromMap(Map<String, dynamic> m) {
    return SiblingLink(
      linkId: (m['LinkID'] as num).toInt(),
      stu1RegId: (m['Stu1_RegID'] as num).toInt(),
      stu2RegId: (m['Stu2_RegID'] as num).toInt(),
      relation: m['Relation'] as String?,
      linkedBy: m['LinkedBy'] as String?,
      linkedOn: m['LinkedOn'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'LinkID': linkId,
    'Stu1_RegID': stu1RegId,
    'Stu2_RegID': stu2RegId,
    'Relation': relation,
    'LinkedBy': linkedBy,
    'LinkedOn': linkedOn,
  };
}

/// StateNotifier managing Sibling Links operations (loading, linking, unlinking).
class SiblingLinksNotifier extends StateNotifier<List<SiblingLink>> {
  SiblingLinksNotifier() : super(const []);

  /// Returns the OTHER student ID for a given student from a link row.
  static int otherSide(SiblingLink link, int myId) =>
      link.stu1RegId == myId ? link.stu2RegId : link.stu1RegId;

  /// Load all links for a student (either side).
  Future<List<SiblingLink>> loadForStudent(int stuRegId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      'SELECT * FROM Sibling_Links WHERE Stu1_RegID = ? OR Stu2_RegID = ?',
      [stuRegId, stuRegId],
    );
    final links = rows.map(SiblingLink.fromMap).toList();
    state = links;
    return links;
  }

  /// Insert canonical pair. If a and b already linked, no-op (UNIQUE guard).
  /// Returns true if inserted, false if already existed or a == b.
  Future<bool> linkPair(
    int a,
    int b, {
    String? relation,
    String? linkedBy,
  }) async {
    if (a == b) return false;
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    final db = await DatabaseService.instance.database;
    final nextRow = await db.rawQuery(
      'SELECT COALESCE(MAX(LinkID), 0) + 1 AS nextId FROM Sibling_Links',
    );
    final nextId = (nextRow.first['nextId'] as num?)?.toInt() ?? 1;
    final now = DateTime.now().toIso8601String();
    try {
      await db.rawInsert(
        'INSERT INTO Sibling_Links '
        '(LinkID, Stu1_RegID, Stu2_RegID, Relation, LinkedBy, LinkedOn) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [nextId, lo, hi, relation, linkedBy, now],
      );
      return true;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) return false;
      rethrow;
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint')) return false;
      rethrow;
    }
  }

  /// Remove a link by its ID.
  Future<void> unlink(int linkId) async {
    final db = await DatabaseService.instance.database;
    await db.rawDelete('DELETE FROM Sibling_Links WHERE LinkID = ?', [linkId]);
    state = state.where((link) => link.linkId != linkId).toList();
  }
}

/// Global provider for SiblingLinksNotifier.
final siblingLinksProvider =
    StateNotifierProvider<SiblingLinksNotifier, List<SiblingLink>>(
      (ref) => SiblingLinksNotifier(),
    );

/// Queries SQLite for linked siblings with class and section information.
final siblingLinksForStudentProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, id) async {
      final db = await DatabaseService.instance.database;
      return db.rawQuery(
        '''
    SELECT sr.Stu_RegID, sr.NameFirst, sr.NameLast,
           sc.ClassID, sc.ClassSecID, c.CName, cs.SecName, sl.LinkID
    FROM Stu_Reg sr
    JOIN Sibling_Links sl ON
      sr.Stu_RegID = (CASE WHEN sl.Stu1_RegID = ?
                            THEN sl.Stu2_RegID
                            ELSE sl.Stu1_RegID END)
    LEFT JOIN Student_Class sc ON sr.Stu_RegID = sc.Stu_RegID AND sc.Present = 1
    LEFT JOIN Class c ON sc.ClassID = c.ClassID
    LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
    WHERE sl.Stu1_RegID = ? OR sl.Stu2_RegID = ?
    ORDER BY sr.NameFirst ASC
  ''',
        [id, id, id],
      );
    });
