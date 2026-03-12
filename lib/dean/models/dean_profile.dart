class DeanProfile {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? officeLocation;
  final String? gender;
  final String? dateOfBirth;
  final String? facultyName;
  final String? staffNumber;

  const DeanProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.officeLocation,
    this.gender,
    this.dateOfBirth,
    this.facultyName,
    this.staffNumber,
  });

  factory DeanProfile.fromJson(Map<String, dynamic> json) {
    return DeanProfile(
      userId: (json['user_id'] ?? json['staff_id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phoneNumber: json['phone_number']?.toString(),
      officeLocation: json['office_location']?.toString(),
      gender: json['gender']?.toString(),
      dateOfBirth: json['date_of_birth']?.toString(),
      facultyName: json['faculty_name']?.toString(),
      staffNumber: (json['staff_number'] ?? json['employee_id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone_number': phoneNumber,
    'office_location': officeLocation,
    'gender': gender,
    'date_of_birth': dateOfBirth,
    'faculty_name': facultyName,
    'staff_number': staffNumber,
  };
}
