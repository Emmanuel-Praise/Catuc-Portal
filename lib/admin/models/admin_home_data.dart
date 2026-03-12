class AdminStats {
  final int students;
  final int staff;
  final int courses;
  final int enrollments;
  final int activeUsers;
  final int activeAnnouncements;

  const AdminStats({
    required this.students,
    required this.staff,
    required this.courses,
    required this.enrollments,
    required this.activeUsers,
    required this.activeAnnouncements,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => int.tryParse((v ?? '0').toString()) ?? 0;
    return AdminStats(
      students: toInt(json['students']),
      staff: toInt(json['staff']),
      courses: toInt(json['courses']),
      enrollments: toInt(json['enrollments']),
      activeUsers: toInt(json['active_users']),
      activeAnnouncements: toInt(json['active_announcements']),
    );
  }
}

class AdminRecentUser {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String createdAt;

  const AdminRecentUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  String get fullName => '$lastName $firstName'.trim();

  factory AdminRecentUser.fromJson(Map<String, dynamic> json) {
    return AdminRecentUser(
      userId: (json['user_id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class AdminRecentCourse {
  final String courseId;
  final String courseCode;
  final String courseName;
  final String semester;
  final String academicYear;
  final String createdAt;

  const AdminRecentCourse({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.semester,
    required this.academicYear,
    required this.createdAt,
  });

  factory AdminRecentCourse.fromJson(Map<String, dynamic> json) {
    return AdminRecentCourse(
      courseId: (json['course_id'] ?? '').toString(),
      courseCode: (json['course_code'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      semester: (json['semester'] ?? '').toString(),
      academicYear: (json['academic_year'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class AdminRoleBreakdown {
  final String role;
  final int total;

  const AdminRoleBreakdown({required this.role, required this.total});

  factory AdminRoleBreakdown.fromJson(Map<String, dynamic> json) {
    return AdminRoleBreakdown(
      role: (json['role'] ?? '').toString(),
      total: int.tryParse((json['total'] ?? '0').toString()) ?? 0,
    );
  }
}

class AdminHomeData {
  final AdminStats stats;
  final List<AdminRecentUser> recentUsers;
  final List<AdminRecentCourse> recentCourses;
  final List<AdminRoleBreakdown> roleBreakdown;

  const AdminHomeData({
    required this.stats,
    required this.recentUsers,
    required this.recentCourses,
    required this.roleBreakdown,
  });

  factory AdminHomeData.fromJson(Map<String, dynamic> json) {
    final stats = AdminStats.fromJson(
      Map<String, dynamic>.from(json['stats'] as Map? ?? {}),
    );
    final recentUsers = (json['recent_users'] as List<dynamic>? ?? const [])
        .map(
          (e) => AdminRecentUser.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    final recentCourses = (json['recent_courses'] as List<dynamic>? ?? const [])
        .map(
          (e) =>
              AdminRecentCourse.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    final roleBreakdown = (json['role_breakdown'] as List<dynamic>? ?? const [])
        .map(
          (e) =>
              AdminRoleBreakdown.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return AdminHomeData(
      stats: stats,
      recentUsers: recentUsers,
      recentCourses: recentCourses,
      roleBreakdown: roleBreakdown,
    );
  }
}
