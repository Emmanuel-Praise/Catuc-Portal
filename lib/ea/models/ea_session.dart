class EaSession {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;

  const EaSession({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  String get fullName => '$lastName $firstName';

  factory EaSession.fromJson(Map<String, dynamic> json) {
    return EaSession(
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'ea',
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
