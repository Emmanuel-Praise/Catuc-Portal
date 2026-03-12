class StudentSession {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? studentNumber;
  final String? facultyId;

  const StudentSession({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.studentNumber,
    this.facultyId,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory StudentSession.fromJson(Map<String, dynamic> json) {
    return StudentSession(
      userId: (json['user_id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      studentNumber: json['student_number']?.toString(),
      facultyId: (json['faculty_id'] ?? json['facultyId'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'role': role,
      'student_number': studentNumber,
      'faculty_id': facultyId,
    };
  }
}
