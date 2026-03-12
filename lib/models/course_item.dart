class CourseItem {
  final String code;
  final String name;
  final String semester;
  final String academicYear;
  final int credits;

  const CourseItem({
    required this.code,
    required this.name,
    required this.semester,
    required this.academicYear,
    required this.credits,
  });

  String get groupKey => '$academicYear - $semester';

  factory CourseItem.fromJson(Map<String, dynamic> json) {
    return CourseItem(
      code: (json['course_code'] ?? '').toString(),
      name: (json['course_name'] ?? '').toString(),
      semester: (json['semester'] ?? '').toString(),
      academicYear: (json['academic_year'] ?? '').toString(),
      credits: (json['credit_hours'] as num?)?.toInt() ?? 0,
    );
  }
}
