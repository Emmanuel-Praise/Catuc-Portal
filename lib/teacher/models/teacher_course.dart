class TeacherCourse {
  final String sectionId;
  final String sectionCode;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String description;
  final String? programName;
  final String? departmentName;
  final int credits;
  final int courseLevel;
  final String academicYear;
  final String semester;
  final String roomNumber;
  final String schedule;
  final int studentCount;
  final String? status;

  const TeacherCourse({
    required this.sectionId,
    required this.sectionCode,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.description,
    this.programName,
    this.departmentName,
    required this.credits,
    required this.courseLevel,
    required this.academicYear,
    required this.semester,
    required this.roomNumber,
    required this.schedule,
    required this.studentCount,
    this.status,
  });

  factory TeacherCourse.fromJson(Map<String, dynamic> json) {
    return TeacherCourse(
      sectionId: json['section_id'] as String? ?? '',
      sectionCode: json['section_code'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      programName: json['program_name'] as String?,
      departmentName: json['department_name'] as String?,
      credits: int.tryParse((json['credits'] ?? '0').toString()) ?? 0,
      courseLevel: int.tryParse((json['course_level'] ?? '0').toString()) ?? 0,
      academicYear: json['academic_year'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      roomNumber: json['room_number'] as String? ?? '',
      schedule: json['schedule'] as String? ?? '',
      studentCount: int.tryParse((json['student_count'] ?? '0').toString()) ?? 0,
      status: json['status'] as String?,
    );
  }
}
