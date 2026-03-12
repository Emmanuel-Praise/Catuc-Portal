class EaEnrollment {
  final String enrollmentId;
  final String studentId;
  final String studentNumber;
  final String studentName;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String? sectionId;
  final String? sectionName;
  final String academicYear;
  final String semester;
  final String status;
  final DateTime? enrollmentDate;
  final String? programName;
  final int? currentYear;

  const EaEnrollment({
    required this.enrollmentId,
    required this.studentId,
    required this.studentNumber,
    required this.studentName,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    this.sectionId,
    this.sectionName,
    required this.academicYear,
    required this.semester,
    required this.status,
    this.enrollmentDate,
    this.programName,
    this.currentYear,
  });

  factory EaEnrollment.fromJson(Map<String, dynamic> json) {
    String asString(dynamic value) => (value ?? '').toString();

    return EaEnrollment(
      enrollmentId: asString(json['enrollment_id']),
      studentId: asString(json['student_id']),
      studentNumber: asString(json['student_number']),
      studentName: asString(json['student_name']),
      courseId: asString(json['course_id']),
      courseCode: asString(json['course_code']),
      courseName: asString(json['course_name']),
      sectionId: json['section_id'] == null
          ? null
          : asString(json['section_id']),
      sectionName: json['section_name'] == null
          ? null
          : asString(json['section_name']),
      academicYear: asString(json['academic_year']),
      semester: asString(json['semester']),
      status: asString(json['status']).isEmpty
          ? 'enrolled'
          : asString(json['status']),
      enrollmentDate: json['enrollment_date'] != null
          ? DateTime.tryParse(asString(json['enrollment_date']))
          : null,
      programName: json['program_name'] == null
          ? null
          : asString(json['program_name']),
      currentYear: json['current_year'] == null
          ? null
          : (json['current_year'] is int
              ? json['current_year'] as int
              : int.tryParse(asString(json['current_year']))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'student_id': studentId,
      'student_number': studentNumber,
      'student_name': studentName,
      'course_id': courseId,
      'course_code': courseCode,
      'course_name': courseName,
      'section_id': sectionId,
      'section_name': sectionName,
      'academic_year': academicYear,
      'semester': semester,
      'status': status,
      'enrollment_date': enrollmentDate?.toIso8601String(),
      'program_name': programName,
      'current_year': currentYear,
    };
  }
}
