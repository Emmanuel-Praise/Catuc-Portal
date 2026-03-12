class TeacherProfile {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? departmentName;
  final String? role;
  final String? staffNumber;
  final String? officeLocation;
  final String? gender;
  final String? dateOfBirth;

  const TeacherProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.departmentName,
    this.role,
    this.staffNumber,
    this.officeLocation,
    this.gender,
    this.dateOfBirth,
  });

  String get fullName => '$lastName $firstName';

  factory TeacherProfile.fromJson(Map<String, dynamic> json) {
    return TeacherProfile(
      userId: json['user_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      departmentName: json['department_name'] as String?,
      role: json['role'] as String?,
      staffNumber: json['staff_number'] as String?,
      officeLocation: json['office_location'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
    );
  }
}
