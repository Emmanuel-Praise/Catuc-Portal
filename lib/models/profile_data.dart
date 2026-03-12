class ProfileData {
  final String fullName;
  final String email;
  final String studentNumber;
  final String program;
  final String department;
  final String faculty;
  final String level;
  final String gender;
  final String phone;

  const ProfileData({
    required this.fullName,
    required this.email,
    required this.studentNumber,
    required this.program,
    required this.department,
    required this.faculty,
    required this.level,
    required this.gender,
    required this.phone,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      fullName: '${(json['first_name'] ?? '').toString()} ${(json['last_name'] ?? '').toString()}'.trim(),
      email: (json['email'] ?? '').toString(),
      studentNumber: (json['student_number'] ?? '').toString(),
      program: (json['program_name'] ?? '').toString(),
      department: (json['department_name'] ?? '').toString(),
      faculty: (json['faculty_name'] ?? '').toString(),
      level: (json['current_year'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      phone: (json['phone_number'] ?? '').toString(),
    );
  }
}
