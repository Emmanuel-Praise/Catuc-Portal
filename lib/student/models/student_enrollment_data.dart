class EnrollmentCourse {
  final String enrollmentId;
  final String courseId;
  final String courseCode;
  final String courseName;
  final int credits;
  final int level;
  final String academicYear;
  final String semester;

  const EnrollmentCourse({
    required this.enrollmentId,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.level,
    required this.academicYear,
    required this.semester,
  });

  factory EnrollmentCourse.fromJson(Map<String, dynamic> json) {
    return EnrollmentCourse(
      enrollmentId: (json['enrollment_id'] ?? '').toString(),
      courseId: (json['course_id'] ?? '').toString(),
      courseCode: (json['course_code'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      credits: int.tryParse((json['credits'] ?? '0').toString()) ?? 0,
      level: int.tryParse((json['course_level'] ?? '0').toString()) ?? 0,
      academicYear: (json['academic_year'] ?? '').toString(),
      semester: (json['semester'] ?? '').toString(),
    );
  }
}

class EnrollmentData {
  final String year;
  final String semester;
  final int level;
  final int studentLevel;
  final int totalCredits;
  final List<EnrollmentCourse> available;
  final List<EnrollmentCourse> enrolled;

  const EnrollmentData({
    required this.year,
    required this.semester,
    required this.level,
    required this.studentLevel,
    required this.totalCredits,
    required this.available,
    required this.enrolled,
  });

  factory EnrollmentData.fromJson(Map<String, dynamic> json) {
    final filter = Map<String, dynamic>.from(
      (json['filter'] ?? const <String, dynamic>{}) as Map,
    );
    final available = (json['available_courses'] as List<dynamic>? ?? const [])
        .map(
          (e) => EnrollmentCourse.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    final enrolled = (json['enrolled_courses'] as List<dynamic>? ?? const [])
        .map(
          (e) => EnrollmentCourse.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return EnrollmentData(
      year: (filter['year'] ?? '').toString(),
      semester: (filter['semester'] ?? '').toString(),
      level: int.tryParse((filter['level'] ?? '0').toString()) ?? 0,
      studentLevel:
          int.tryParse((filter['student_level'] ?? '0').toString()) ?? 0,
      totalCredits:
          int.tryParse((json['total_credits'] ?? '0').toString()) ?? 0,
      available: available,
      enrolled: enrolled,
    );
  }
}
