class EaResult {
  final String resultId;
  final String studentId;
  final String studentNumber;
  final String studentName;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String academicYear;
  final String semester;
  final double? score;
  final String? grade;
  final double? gradePoint;
  final String? status;
  final DateTime? submittedDate;

  const EaResult({
    required this.resultId,
    required this.studentId,
    required this.studentNumber,
    required this.studentName,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.academicYear,
    required this.semester,
    this.score,
    this.grade,
    this.gradePoint,
    this.status,
    this.submittedDate,
  });

  factory EaResult.fromJson(Map<String, dynamic> json) {
    String asString(dynamic value) => (value ?? '').toString();
    double? asDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return EaResult(
      resultId: asString(json['result_id']),
      studentId: asString(json['student_id']),
      studentNumber: asString(json['student_number']),
      studentName: asString(json['student_name']),
      courseId: asString(json['course_id']),
      courseCode: asString(json['course_code']),
      courseName: asString(json['course_name']),
      academicYear: asString(json['academic_year']),
      semester: asString(json['semester']),
      score: asDouble(json['score']),
      grade: json['grade'] == null ? null : asString(json['grade']),
      gradePoint: asDouble(json['grade_point']),
      status: json['status'] == null ? null : asString(json['status']),
      submittedDate: json['submitted_date'] != null
          ? DateTime.tryParse(asString(json['submitted_date']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result_id': resultId,
      'student_id': studentId,
      'student_number': studentNumber,
      'student_name': studentName,
      'course_id': courseId,
      'course_code': courseCode,
      'course_name': courseName,
      'academic_year': academicYear,
      'semester': semester,
      'score': score,
      'grade': grade,
      'grade_point': gradePoint,
      'status': status,
      'submitted_date': submittedDate?.toIso8601String(),
    };
  }
}
