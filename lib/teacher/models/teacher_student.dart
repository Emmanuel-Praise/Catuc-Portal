class TeacherStudent {
  final String enrollmentId;
  final String studentId;
  final String studentNumber;
  final String firstName;
  final String lastName;
  final String email;
  final String? programName;
  final String? departmentName;
  final String? facultyName;
  final int currentYear;
  final double? attendancePercentage;
  final double? score;
  final double? attendanceScore;
  final double? caScore;
  final double? examScore;
  final String? grade;
  final double? gradePoint;
  final String? resultStatus;

  const TeacherStudent({
    required this.enrollmentId,
    required this.studentId,
    required this.studentNumber,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.programName,
    this.departmentName,
    this.facultyName,
    required this.currentYear,
    this.attendancePercentage,
    this.score,
    this.attendanceScore,
    this.caScore,
    this.examScore,
    this.grade,
    this.gradePoint,
    this.resultStatus,
  });

  String get fullName => '$lastName $firstName';

  factory TeacherStudent.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) =>
        value == null ? null : double.tryParse(value.toString());

    return TeacherStudent(
      enrollmentId: (json['enrollment_id'] ?? '').toString(),
      studentId: (json['student_id'] ?? '').toString(),
      studentNumber: (json['student_number'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      programName: json['program_name']?.toString(),
      departmentName: json['department_name']?.toString(),
      facultyName: json['faculty_name']?.toString(),
      currentYear: int.tryParse((json['current_year'] ?? '1').toString()) ?? 1,
      attendancePercentage: toDouble(json['attendance_percentage']),
      score: toDouble(json['score']),
      attendanceScore: toDouble(json['attendance_score']),
      caScore: toDouble(json['ca_score']),
      examScore: toDouble(json['exam_score']),
      grade: json['grade']?.toString(),
      gradePoint: toDouble(json['grade_point']),
      resultStatus: json['result_status']?.toString(),
    );
  }
}
