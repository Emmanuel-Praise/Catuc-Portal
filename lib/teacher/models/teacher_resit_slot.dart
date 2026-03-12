class TeacherResitSlot {
  final String id;
  final String type;
  final String courseId;
  final String courseName;
  final String examDate;
  final String day;
  final String startTime;
  final String endTime;
  final String venue;

  const TeacherResitSlot({
    required this.id,
    required this.type,
    required this.courseId,
    required this.courseName,
    required this.examDate,
    this.day = '',
    required this.startTime,
    required this.endTime,
    required this.venue,
  });

  factory TeacherResitSlot.fromJson(Map<String, dynamic> json) {
    return TeacherResitSlot(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      courseId: (json['course_id'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      examDate: (json['exam_date'] ?? '').toString(),
      day: (json['day'] ?? '').toString(),
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
      venue: (json['venue'] ?? '').toString(),
    );
  }
}
