class StudentAssignment {
  final String id;
  final String name;
  final String description;
  final String dueDate;
  final String maxPoints;
  final String weight;

  const StudentAssignment({
    required this.id,
    required this.name,
    required this.description,
    required this.dueDate,
    required this.maxPoints,
    required this.weight,
  });

  factory StudentAssignment.fromJson(Map<String, dynamic> json) {
    return StudentAssignment(
      id: (json['assignment_id'] ?? '').toString(),
      name: (json['assignment_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      dueDate: (json['due_date'] ?? '').toString(),
      maxPoints: (json['max_points'] ?? '').toString(),
      weight: (json['weight'] ?? '').toString(),
    );
  }
}

class StudentCourseDetail {
  final String courseId;
  final String courseCode;
  final String courseName;
  final String description;
  final String instructor;
  final String instructorEmail;
  final int credits;
  final String level;
  final String semester;
  final String year;
  final String sectionCode;
  final String room;
  final String schedule;
  final String attendancePercent;
  final String attendanceScore;
  final String caScore;
  final String practicalsScore;
  final String examScore;
  final String totalScore;
  final String grade;
  final String department;
  final String faculty;
  final int materialsCount;
  final int assignmentsCount;

  const StudentCourseDetail({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.description,
    required this.instructor,
    required this.instructorEmail,
    required this.credits,
    required this.level,
    required this.semester,
    required this.year,
    required this.sectionCode,
    required this.room,
    required this.schedule,
    required this.attendancePercent,
    required this.attendanceScore,
    required this.caScore,
    required this.practicalsScore,
    required this.examScore,
    required this.totalScore,
    required this.grade,
    required this.department,
    required this.faculty,
    required this.materialsCount,
    required this.assignmentsCount,
  });

  factory StudentCourseDetail.fromJson(Map<String, dynamic> json) {
    return StudentCourseDetail(
      courseId: (json['course_id'] ?? '').toString(),
      courseCode: (json['course_code'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      instructor: (json['instructor_name'] ?? '').toString(),
      instructorEmail: (json['instructor_email'] ?? '').toString(),
      credits: int.tryParse((json['credits'] ?? '0').toString()) ?? 0,
      level: (json['course_level'] ?? '').toString(),
      semester: (json['semester'] ?? '').toString(),
      year: (json['academic_year'] ?? '').toString(),
      sectionCode: (json['section_code'] ?? '').toString(),
      room: (json['room_number'] ?? '').toString(),
      schedule: (json['schedule'] ?? '').toString(),
      attendancePercent: (json['attendance_percentage'] ?? '-').toString(),
      attendanceScore: (json['attendance_score'] ?? '-').toString(),
      caScore: (json['ca_score'] ?? '-').toString(),
      practicalsScore: (json['practicals_score'] ?? '-').toString(),
      examScore: (json['exam_score'] ?? '-').toString(),
      totalScore: (json['total_score'] ?? '-').toString(),
      grade: (json['grade'] ?? '-').toString(),
      department: (json['department_name'] ?? '').toString(),
      faculty: (json['faculty_name'] ?? '').toString(),
      materialsCount: int.tryParse((json['materials_count'] ?? '0').toString()) ?? 0,
      assignmentsCount: int.tryParse((json['assignments_count'] ?? '0').toString()) ?? 0,
    );
  }
}

class StudentCourseDetailData {
  final StudentCourseDetail course;
  final List<StudentAssignment> assignments;

  const StudentCourseDetailData({required this.course, required this.assignments});

  factory StudentCourseDetailData.fromJson(Map<String, dynamic> json) {
    final course = StudentCourseDetail.fromJson(Map<String, dynamic>.from(json['course'] as Map));
    final assignments = (json['assignments'] as List<dynamic>? ?? const [])
        .map((e) => StudentAssignment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return StudentCourseDetailData(course: course, assignments: assignments);
  }
}
