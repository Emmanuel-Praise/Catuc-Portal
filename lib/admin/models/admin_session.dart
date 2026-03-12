class AdminSession {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;

  const AdminSession({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  String get fullName => '$lastName $firstName'.trim();

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      userId: (json['user_id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'admin').toString(),
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
