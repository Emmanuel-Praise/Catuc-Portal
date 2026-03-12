import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../models/dean_home_data.dart';
import '../models/dean_course.dart';
import '../models/dean_student_course.dart';

class DeanApiService extends ApiService {
  const DeanApiService();

  Future<DeanHomeData> fetchHomeData(String facultyId) async {
    final data = await getWithCache('dean_home.php', query: {
      'faculty_id': facultyId,
    });
    return DeanHomeData.fromJson(data);
  }

  Future<List<DeanCourse>> fetchCourses(String facultyId, {String? semester, String? level}) async {
    try {
      final query = <String, String>{'faculty_id': facultyId};
      if (semester != null && semester.isNotEmpty) query['semester'] = semester;
      if (level != null && level.isNotEmpty) query['level'] = level;
      
      final data = await getWithCache('dean_courses.php', query: query);
      final rows = (data['courses'] as List? ?? []);
      return rows.map((e) => DeanCourse.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      debugPrint('Error fetching courses: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    final response = await postWithFallback('dean_profile_update.php', body: profileData);
    parseResponse(response);
  }

  Future<void> saveCourse(Map<String, dynamic> courseData) async {
    await postWithFallback('dean_courses.php', body: {
      'action': 'save',
      ...courseData,
    });
  }

  Future<List<Map<String, dynamic>>> fetchDepartments(String facultyId) async {
    final data = await getWithCache('dean_home.php', query: {'faculty_id': facultyId, 'action': 'departments'});
    return List<Map<String, dynamic>>.from(data['departments'] as List? ?? []);
  }

  Future<List<Map<String, dynamic>>> fetchEnrollments({
    required String facultyId,
    String? level,
    String? semester,
    String? courseId,
  }) async {
    final query = <String, String>{'faculty_id': facultyId};
    if (level != null && level.isNotEmpty) query['level'] = level;
    if (semester != null && semester.isNotEmpty) query['semester'] = semester;
    if (courseId != null && courseId.isNotEmpty) query['course_id'] = courseId;

    final data = await getWithCache('dean_enrollments.php', query: query);
    return List<Map<String, dynamic>>.from(data['enrollments'] as List? ?? []);
  }

  Future<void> deleteCourse(String courseId) async {
    await postWithFallback('dean_courses.php', body: {
      'action': 'delete',
      'course_id': courseId,
    });
  }

  Future<List<Map<String, dynamic>>> fetchLecturers(String facultyId) async {
    final data = await getWithCache('dean_lecturers.php', query: {
      'faculty_id': facultyId,
    });
    return List<Map<String, dynamic>>.from(data['lecturers'] as List? ?? []);
  }

  Future<List<DeanStudentCourse>> fetchStudentCourses(String facultyId) async {
    final data = await getWithCache('dean_enrollments.php', query: {
      'faculty_id': facultyId,
      'action': 'overview',
    });
    final rows = (data['overview'] as List? ?? []);
    return rows.map((e) => DeanStudentCourse.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCourseStudents(String courseId) async {
    final response = await postWithFallback('dean_enrollments.php', body: {
      'action': 'get_students',
      'course_id': courseId,
    });
    final data = parseResponse(response);
    return List<Map<String, dynamic>>.from(data['students'] as List? ?? []);
  }

  Future<void> batchSaveGrades(String courseId, List<Map<String, dynamic>> grades) async {
    await postWithFallback('dean_results.php', body: {
      'action': 'batch_save',
      'course_id': courseId,
      'grades': grades,
    });
  }

  Future<void> assignLecturer({
    required String courseId,
    required String lecturerId,
    required String academicYear,
    required String semester,
  }) async {
    await postWithFallback('dean_lecturers.php', body: {
      'action': 'assign',
      'course_id': courseId,
      'lecturer_id': lecturerId,
      'academic_year': academicYear,
      'semester': semester,
    });
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements(String facultyId) async {
    try {
      final data = await getWithCache('dean_announcements.php', query: {
        'faculty_id': facultyId,
      });
      return List<Map<String, dynamic>>.from(data['announcements'] as List? ?? []);
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      rethrow;
    }
  }

  Future<void> createAnnouncement(Map<String, dynamic> announcementData) async {
    await postWithFallback('dean_announcements.php', body: {
      'action': 'create',
      ...announcementData,
    });
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await postWithFallback('dean_announcements.php', body: {
      'action': 'delete',
      'announcement_id': announcementId,
    });
  }

  Future<Map<String, dynamic>> fetchDeanProfile(String userId) async {
    try {
      final data = await getWithCache('dean_profile.php', query: {
        'user_id': userId,
      });
      return data;
    } catch (e) {
      debugPrint('Error fetching dean profile: $e');
      rethrow;
    }
  }

  Future<String> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await postWithFallback(
      'dean_change_password.php',
      body: {
        'user_id': userId,
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    final parsed = parseResponse(response);
    return (parsed['message'] ?? 'Password updated successfully').toString();
  }
}
