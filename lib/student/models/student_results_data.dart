class AcademicOption {
  final String year;
  final String semester;
  final String semesterNormalized;

  const AcademicOption({
    required this.year,
    required this.semester,
    required this.semesterNormalized,
  });

  factory AcademicOption.fromJson(Map<String, dynamic> json) {
    return AcademicOption(
      year: (json['academic_year'] ?? '').toString(),
      semester: (json['semester'] ?? '').toString(),
      semesterNormalized: (json['semester_normalized'] ?? '').toString(),
    );
  }
}

class StudentResultItem {
  final String courseCode;
  final String courseName;
  final int credits;
  final String attendance;
  final String ca;
  final String practicals;
  final String exam;
  final String total;
  final String grade;
  final String status;

  const StudentResultItem({
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.attendance,
    required this.ca,
    required this.practicals,
    required this.exam,
    required this.total,
    required this.grade,
    required this.status,
  });

  factory StudentResultItem.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['enrollment_status'] ?? '').toString();
    return StudentResultItem(
      courseCode: (json['course_code'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      credits: int.tryParse((json['credits'] ?? '0').toString()) ?? 0,
      attendance: (json['attendance_score'] ?? '-').toString(),
      ca: (json['ca_score'] ?? '-').toString(),
      practicals: (json['practicals_score'] ?? '-').toString(),
      exam: (json['exam_score'] ?? '-').toString(),
      total: (json['total_score'] ?? '-').toString(),
      grade: (json['grade'] ?? '-').toString(),
      status: statusRaw,
    );
  }
}

class StudentResultsData {
  final String year;
  final String semester;
  final double? sgpa;
  final int creditsUsed;
  final List<AcademicOption> options;
  final List<StudentResultItem> results;

  const StudentResultsData({
    required this.year,
    required this.semester,
    required this.sgpa,
    required this.creditsUsed,
    required this.options,
    required this.results,
  });

  factory StudentResultsData.fromJson(Map<String, dynamic> json) {
    final filter = Map<String, dynamic>.from((json['filter'] ?? const <String, dynamic>{}) as Map);
    final options = (json['options'] as List<dynamic>? ?? const [])
        .map((e) => AcademicOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final results = (json['results'] as List<dynamic>? ?? const [])
        .map((e) => StudentResultItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final sgpaRaw = json['sgpa'];
    final sgpa = sgpaRaw == null ? null : double.tryParse(sgpaRaw.toString());

    return StudentResultsData(
      year: (filter['academic_year'] ?? '').toString(),
      semester: (filter['semester'] ?? '').toString(),
      sgpa: sgpa,
      creditsUsed: int.tryParse((json['credits_used'] ?? '0').toString()) ?? 0,
      options: options,
      results: results,
    );
  }
}
