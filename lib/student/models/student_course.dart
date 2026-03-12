class StudentCourse {
  final String courseId;
  final String code;
  final String name;
  final int credits;
  final String level;
  final String semester;
  final String academicYear;
  final String sectionCode;
  final String room;
  final String schedule;

  const StudentCourse({
    required this.courseId,
    required this.code,
    required this.name,
    required this.credits,
    required this.level,
    required this.semester,
    required this.academicYear,
    required this.sectionCode,
    required this.room,
    required this.schedule,
  });

  String get groupKey => '$academicYear  $semester';

  factory StudentCourse.fromJson(Map<String, dynamic> json) {
    return StudentCourse(
      courseId: (json['course_id'] ?? '').toString(),
      code: (json['course_code'] ?? '').toString(),
      name: (json['course_name'] ?? '').toString(),
      credits: int.tryParse((json['credits'] ?? '0').toString()) ?? 0,
      level: (json['course_level'] ?? '').toString(),
      semester: (json['semester'] ?? '').toString(),
      academicYear: (json['academic_year'] ?? '').toString(),
      sectionCode: (json['section_code'] ?? '').toString(),
      room: (json['room_number'] ?? '').toString(),
      schedule: (json['schedule'] ?? '').toString(),
    );
  }
}
