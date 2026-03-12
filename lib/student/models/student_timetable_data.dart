class TimetableSlot {
  final String courseCode;
  final String courseName;
  final String examDate;
  final String day;
  final String startTime;
  final String endTime;
  final String venue;
  final String type;
  final String academicYear;

  const TimetableSlot({
    required this.courseCode,
    required this.courseName,
    required this.examDate,
    this.day = '',
    required this.startTime,
    required this.endTime,
    required this.venue,
    this.type = '',
    this.academicYear = '',
  });

  factory TimetableSlot.fromJson(Map<String, dynamic> json) {
    return TimetableSlot(
      courseCode: (json['course_id'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      examDate: (json['exam_date'] ?? '').toString(),
      day: (json['day'] ?? '').toString(),
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
      venue: (json['venue'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      academicYear: (json['academic_year'] ?? '').toString(),
    );
  }
}
