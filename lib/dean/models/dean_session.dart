class DeanSession {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? facultyId;
  final String? facultyName;
  final String? token;

  const DeanSession({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.facultyId,
    this.facultyName,
    this.token,
  });

  factory DeanSession.fromJson(Map<String, dynamic> json) {
    return DeanSession(
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      role: (json['role'] ?? 'dean').toString(),
      facultyId: json['faculty_id']?.toString() ?? json['facultyId']?.toString(),
      facultyName: json['faculty_name']?.toString() ?? json['facultyName']?.toString(),
      token: json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'faculty_id': facultyId,
      'faculty_name': facultyName,
      'token': token,
    };
  }

  String get fullName => '$firstName $lastName';
}
