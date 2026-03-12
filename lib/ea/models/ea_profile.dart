class EaProfile {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? departmentName;
  final String? role;

  const EaProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.departmentName,
    this.role,
  });

  String get fullName => '$firstName $lastName';

  factory EaProfile.fromJson(Map<String, dynamic> json) {
    return EaProfile(
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      departmentName: json['department_name'] as String?,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'department_name': departmentName,
      'role': role,
    };
  }
}
