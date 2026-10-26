/// ExamSessionRow model for exam schedule entries in ExamTermScreen.
/// Maps to table `ExamInfo`: ExamInfoID, ExTermID, SessionYR, StartDate, EndDate, ResultDate, ExamSupervisorID, Location, Detail.
class ExamSessionRow {
  final int examInfoId;
  final int exTermId;
  final String termName;
  final String sessionYr;
  final String startDate;
  final String endDate;
  final String resultDate;
  final int examSupervisorId;
  final String supervisorName;
  final String supervisorCat;
  final String location;
  final String detail;

  const ExamSessionRow({
    required this.examInfoId,
    required this.exTermId,
    required this.termName,
    required this.sessionYr,
    required this.startDate,
    required this.endDate,
    required this.resultDate,
    required this.examSupervisorId,
    required this.supervisorName,
    required this.supervisorCat,
    this.location = '',
    this.detail = '',
  });

  ExamSessionRow copyWith({
    int? examInfoId,
    int? exTermId,
    String? termName,
    String? sessionYr,
    String? startDate,
    String? endDate,
    String? resultDate,
    int? examSupervisorId,
    String? supervisorName,
    String? supervisorCat,
    String? location,
    String? detail,
  }) {
    return ExamSessionRow(
      examInfoId: examInfoId ?? this.examInfoId,
      exTermId: exTermId ?? this.exTermId,
      termName: termName ?? this.termName,
      sessionYr: sessionYr ?? this.sessionYr,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      resultDate: resultDate ?? this.resultDate,
      examSupervisorId: examSupervisorId ?? this.examSupervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorCat: supervisorCat ?? this.supervisorCat,
      location: location ?? this.location,
      detail: detail ?? this.detail,
    );
  }

  factory ExamSessionRow.fromMap(Map<String, dynamic> map) {
    return ExamSessionRow(
      examInfoId: (map['ExamInfoID'] as num).toInt(),
      exTermId: (map['ExTermID'] as num).toInt(),
      termName: (map['TermName'] as String?)?.trim() ?? '',
      sessionYr: (map['SessionYR'] as String?)?.trim() ?? '',
      startDate: (map['StartDate'] as String?)?.trim() ?? '',
      endDate: (map['EndDate'] as String?)?.trim() ?? '',
      resultDate: (map['ResultDate'] as String?)?.trim() ?? '',
      examSupervisorId: (map['ExamSupervisorID'] as num?)?.toInt() ?? 0,
      supervisorName: (map['TName'] as String?)?.trim() ?? 'Unknown',
      supervisorCat: (map['TCat'] as String?)?.trim() ?? 'Teacher',
      location: (map['Location'] as String?)?.trim() ?? '',
      detail: (map['Detail'] as String?)?.trim() ?? '',
    );
  }
}
