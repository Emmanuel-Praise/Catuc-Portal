class EaHomeData {
  final int totalStudents;
  final int totalStaff;
  final int totalCourses;
  final int totalEnrollments;
  final String currentYear;
  final String currentSemester;
  final List<RecentStudent> recentStudents;
  final List<RecentCourse> recentCourses;

  const EaHomeData({
    required this.totalStudents,
    required this.totalStaff,
    required this.totalCourses,
    required this.totalEnrollments,
    required this.currentYear,
    required this.currentSemester,
    required this.recentStudents,
    required this.recentCourses,
  });

  factory EaHomeData.fromJson(Map<String, dynamic> json) {
    final studentsList = (json['recent_students'] as List<dynamic>? ?? [])
        .map((e) => RecentStudent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    
    final coursesList = (json['recent_courses'] as List<dynamic>? ?? [])
        .map((e) => RecentCourse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return EaHomeData(
      totalStudents: json['total_students'] as int? ?? 0,
      totalStaff: json['total_staff'] as int? ?? 0,
      totalCourses: json['total_courses'] as int? ?? 0,
      totalEnrollments: json['total_enrollments'] as int? ?? 0,
      currentYear: json['current_year'] as String? ?? '2025/2026',
      currentSemester: json['current_semester'] as String? ?? 'First',
      recentStudents: studentsList,
      recentCourses: coursesList,
    );
  }
}

class RecentStudent {
  final String studentId;
  final String studentNumber;
  final String firstName;
  final String lastName;
  final String programName;

  const RecentStudent({
    required this.studentId,
    required this.studentNumber,
    required this.firstName,
    required this.lastName,
    required this.programName,
  });

  String get fullName => '$firstName $lastName';

  factory RecentStudent.fromJson(Map<String, dynamic> json) {
    return RecentStudent(
      studentId: json['student_id'] as String? ?? '',
      studentNumber: json['student_number'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      programName: json['program_name'] as String? ?? '',
    );
  }
}

class RecentCourse {
  final String courseId;
  final String courseCode;
  final String courseName;
  final String lecturerName;

  const RecentCourse({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.lecturerName,
  });

  factory RecentCourse.fromJson(Map<String, dynamic> json) {
    return RecentCourse(
      courseId: json['course_id'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      lecturerName: json['lecturer_name'] as String? ?? '',
    );
  }
}
