class TeacherSession {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;

  const TeacherSession({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  String get fullName => '$lastName $firstName';

  factory TeacherSession.fromJson(Map<String, dynamic> json) {
    return TeacherSession(
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'staff',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'role': role,
    };
  }
}
