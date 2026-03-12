class DeanStudentCourse {
  final String matricule;
  final String studentName;
  final String programName;
  final int level;
  final String courseCode;
  final String courseName;
  final String? lecturerName;
  final String enrollmentStatus;
  final String? grade;

  DeanStudentCourse({
    required this.matricule,
    required this.studentName,
    required this.programName,
    required this.level,
    required this.courseCode,
    required this.courseName,
    this.lecturerName,
    required this.enrollmentStatus,
    this.grade,
  });

  factory DeanStudentCourse.fromJson(Map<String, dynamic> json) {
    return DeanStudentCourse(
      matricule: json['matricule'] ?? '',
      studentName: json['student_name'] ?? '',
      programName: json['program_name'] ?? 'N/A',
      level: (json['current_year'] as num? ?? 1).toInt() * 100,
      courseCode: json['course_code'] ?? '',
      courseName: json['course_name'] ?? '',
      lecturerName: json['lecturer'],
      enrollmentStatus: json['enrollment_status'] ?? 'pending',
      grade: json['grade'],
    );
  }
}
