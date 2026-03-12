class UserSession {
  final int userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? studentNumber;

  const UserSession({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.studentNumber,
  });

  String get fullName => '$lastName $firstName'.trim();

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      studentNumber: json['student_number']?.toString(),
    );
  }
}
