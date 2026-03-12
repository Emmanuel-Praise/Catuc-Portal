class DeanCourse {
  final String courseId;
  final String courseCode;
  final String courseName;
  final int credits;
  final int courseLevel;
  final String departmentName;
  final String? departmentId;
  final String? lecturerName;
  final String? lecturerId;
  final String? semester;

  const DeanCourse({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.courseLevel,
    required this.departmentName,
    this.departmentId,
    this.lecturerName,
    this.lecturerId,
    this.semester,
  });

  factory DeanCourse.fromJson(Map<String, dynamic> json) {
    return DeanCourse(
      courseId: (json['course_id'] ?? '').toString(),
      courseCode: (json['course_code'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      credits: int.tryParse(json['credits']?.toString() ?? '0') ?? 0,
      courseLevel: int.tryParse(json['course_level']?.toString() ?? '0') ?? 0,
      departmentName: (json['department_name'] ?? '').toString(),
      departmentId: json['department_id']?.toString(),
      lecturerName: json['lecturer_name']?.toString() ?? json['lecturer']?.toString(),
      lecturerId: json['lecturer_id']?.toString() ?? json['faculty_id']?.toString(),
      semester: json['semester']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'course_code': courseCode,
      'course_name': courseName,
      'credits': credits,
      'course_level': courseLevel,
      'department_name': departmentName,
      'department_id': departmentId,
      'lecturer_name': lecturerName,
      'lecturer_id': lecturerId,
      'semester': semester,
    };
  }
}
