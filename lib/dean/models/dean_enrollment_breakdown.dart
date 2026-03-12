class DeanEnrollmentBreakdown {
  final String courseCode;
  final String courseName;
  final String sectionCode;
  final int studentCount;

  DeanEnrollmentBreakdown({
    required this.courseCode,
    required this.courseName,
    required this.sectionCode,
    required this.studentCount,
  });

  factory DeanEnrollmentBreakdown.fromJson(Map<String, dynamic> json) {
    return DeanEnrollmentBreakdown(
      courseCode: json['course_code'] ?? '',
      courseName: json['course_name'] ?? '',
      sectionCode: json['section_code'] ?? '',
      studentCount: (json['student_count'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_code': courseCode,
      'course_name': courseName,
      'section_code': sectionCode,
      'student_count': studentCount,
    };
  }
}
