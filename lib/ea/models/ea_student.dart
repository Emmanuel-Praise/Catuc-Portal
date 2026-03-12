class EaStudent {
  final String studentId;
  final String studentNumber;
  final String firstName;
  final String lastName;
  final String email;
  final String? programId;
  final String? programName;
  final int currentYear;
  final int currentSemester;
  final double? gpa;
  final String? academicStatus;
  final String? enrollmentDate;

  const EaStudent({
    required this.studentId,
    required this.studentNumber,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.programId,
    this.programName,
    required this.currentYear,
    required this.currentSemester,
    this.gpa,
    this.academicStatus,
    this.enrollmentDate,
  });

  String get fullName => '$lastName $firstName';

  factory EaStudent.fromJson(Map<String, dynamic> json) {
    // Handle GPA as either num or string
    double? parsedGpa;
    if (json['gpa'] != null) {
      if (json['gpa'] is num) {
        parsedGpa = (json['gpa'] as num).toDouble();
      } else if (json['gpa'] is String && json['gpa'].toString().isNotEmpty) {
        parsedGpa = double.tryParse(json['gpa'].toString());
      }
    }

    return EaStudent(
      studentId: json['student_id'] as String? ?? '',
      studentNumber: json['student_number'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      programId: json['program_id'] as String?,
      programName: json['program_name'] as String?,
      currentYear: json['current_year'] is int 
          ? json['current_year'] as int 
          : int.tryParse(json['current_year']?.toString() ?? '') ?? 1,
      currentSemester: json['current_semester'] is int 
          ? json['current_semester'] as int 
          : int.tryParse(json['current_semester']?.toString() ?? '') ?? 1,
      gpa: parsedGpa,
      academicStatus: json['academic_status'] as String?,
      enrollmentDate: json['enrollment_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'student_number': studentNumber,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'program_id': programId,
      'program_name': programName,
      'current_year': currentYear,
      'current_semester': currentSemester,
      'gpa': gpa,
      'academic_status': academicStatus,
      'enrollment_date': enrollmentDate,
    };
  }
}
