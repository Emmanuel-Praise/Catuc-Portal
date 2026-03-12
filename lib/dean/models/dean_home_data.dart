import 'dean_enrollment_breakdown.dart';

class DeanHomeData {
  final int totalStudents;
  final int totalStaff;
  final int totalCourses;
  final int totalEnrollments;
  final String currentYear;
  final String currentSemester;
  final List<DeanActivity> recentActivities;
  final List<DeanEnrollmentBreakdown> enrollmentBreakdown;

  DeanHomeData({
    required this.totalStudents,
    required this.totalStaff,
    required this.totalCourses,
    required this.totalEnrollments,
    this.currentYear = '',
    this.currentSemester = '',
    required this.recentActivities,
    required this.enrollmentBreakdown,
  });

  factory DeanHomeData.fromJson(Map<String, dynamic> json) {
    // The backend returns flat keys at root level, not nested under 'stats'.
    // Support both formats for safety.
    final stats = json['stats'] as Map?;
    final int students = (stats?['total_students'] ?? json['total_students'] as num? ?? 0).toInt();
    final int staff = (stats?['total_staff'] ?? json['total_staff'] as num? ?? 0).toInt();
    final int courses = (stats?['total_courses'] ?? json['total_courses'] as num? ?? 0).toInt();
    final int enrollments = (stats?['total_enrollments'] ?? json['total_enrollments'] as num? ?? 0).toInt();

    return DeanHomeData(
      totalStudents: students,
      totalStaff: staff,
      totalCourses: courses,
      totalEnrollments: enrollments,
      currentYear: (json['current_year'] ?? '').toString(),
      currentSemester: (json['current_semester'] ?? '').toString(),
      recentActivities: ((json['recent_activities'] ?? json['activities']) as List? ?? [])
          .map((e) => DeanActivity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      enrollmentBreakdown: ((json['enrollment_breakdown'] ?? json['breakdown']) as List? ?? [])
          .map((e) => DeanEnrollmentBreakdown.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_students': totalStudents,
      'total_staff': totalStaff,
      'total_courses': totalCourses,
      'total_enrollments': totalEnrollments,
      'current_year': currentYear,
      'current_semester': currentSemester,
      'recent_activities': recentActivities.map((e) => e.toJson()).toList(),
      'enrollment_breakdown': enrollmentBreakdown.map((e) => e.toJson()).toList(),
    };
  }
}

class DeanActivity {
  final String id;
  final String title;
  final String description;
  final String createdAt;
  final String type;

  const DeanActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.type,
  });

  factory DeanActivity.fromJson(Map<String, dynamic> json) {
    return DeanActivity(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt,
      'type': type,
    };
  }
}
