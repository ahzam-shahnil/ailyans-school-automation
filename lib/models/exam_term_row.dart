/// ExamTermRow model for ExamTerm catalog in ExamTermScreen.
/// Maps to table `ExamTerm`: ExTermID, TermName, TermRemarks.
class ExamTermRow {
  final int exTermId;
  final String termName;
  final String termRemarks;
  final int sessionCount;

  const ExamTermRow({
    required this.exTermId,
    required this.termName,
    this.termRemarks = '',
    this.sessionCount = 0,
  });

  ExamTermRow copyWith({
    int? exTermId,
    String? termName,
    String? termRemarks,
    int? sessionCount,
  }) {
    return ExamTermRow(
      exTermId: exTermId ?? this.exTermId,
      termName: termName ?? this.termName,
      termRemarks: termRemarks ?? this.termRemarks,
      sessionCount: sessionCount ?? this.sessionCount,
    );
  }

  factory ExamTermRow.fromMap(
    Map<String, dynamic> map, {
    int sessionCount = 0,
  }) {
    return ExamTermRow(
      exTermId: (map['ExTermID'] as num).toInt(),
      termName: (map['TermName'] as String?)?.trim() ?? '',
      termRemarks: (map['TermRemarks'] as String?)?.trim() ?? '',
      sessionCount: sessionCount,
    );
  }
}
