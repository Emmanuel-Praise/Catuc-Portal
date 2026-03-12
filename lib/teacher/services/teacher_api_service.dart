import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../models/teacher_attendance_record.dart';
import '../models/teacher_course.dart';
import '../models/teacher_course_material.dart';
import '../models/teacher_home_data.dart';
import '../models/teacher_profile.dart';
import '../models/teacher_resit_slot.dart';
import '../models/teacher_student.dart';
import '../models/teacher_announcement_item.dart';

class TeacherApiService extends ApiService {
  const TeacherApiService();

  // Fetch home/dashboard data for teacher
  Future<TeacherHomeData> fetchHome(String teacherId) async {
    try {
      final data = await getWithCache(
        'teacher_home.php',
        query: {'teacher_id': teacherId},
        forceRefresh: true,
      );
      return TeacherHomeData.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('Error fetching teacher home data: $e');
      rethrow;
    }
  }

  // Fetch profile
  Future<TeacherProfile> fetchProfile(String teacherId) async {
    final data = await getWithCache(
      'teacher_profile.php',
      query: {'teacher_id': teacherId},
    );
    return TeacherProfile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
  }

  // Fetch assigned courses
  Future<List<TeacherCourse>> fetchAssignedCourses(String teacherId) async {
    final data = await getWithCache(
      'teacher_courses.php',
      query: {'teacher_id': teacherId},
    );
    final rows = (data['courses'] as List<dynamic>? ?? []);
    return rows
        .map((e) => TeacherCourse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // Fetch students in a course section
  Future<List<TeacherStudent>> fetchCourseStudents(String sectionId) async {
    final data = await getWithCache(
      'teacher_course_students.php',
      query: {'section_id': sectionId},
    );
    final rows = (data['students'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => TeacherStudent.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  // Submit or update student result
  Future<void> submitResult({
    required String sectionId,
    required String studentId,
    double? attendanceScore,
    double? caScore,
    double? examScore,
    String? grade,
    double? gradePoint,
  }) async {
    final response = await postWithFallback(
      'teacher_results.php',
      body: {
        'action': 'submit',
        'section_id': sectionId,
        'student_id': studentId,
        'attendance_score': attendanceScore,
        'ca_score': caScore,
        'exam_score': examScore,
        'grade': grade,
        'grade_point': gradePoint,
      },
      offlineActionType: 'submit_result',
    );
    parseResponse(response);
  }

  // Update existing result
  Future<void> updateResult({
    required String resultId,
    double? attendanceScore,
    double? caScore,
    double? examScore,
    String? grade,
    double? gradePoint,
  }) async {
    final response = await postWithFallback(
      'teacher_results.php',
      body: {
        'action': 'update',
        'result_id': resultId,
        'attendance_score': attendanceScore,
        'ca_score': caScore,
        'exam_score': examScore,
        'grade': grade,
        'grade_point': gradePoint,
      },
    );
    parseResponse(response);
  }

  // Fetch results for a course section
  Future<List<TeacherStudent>> fetchCourseResults(String sectionId) async {
    final data = await getWithCache(
      'teacher_results.php',
      query: {'section_id': sectionId},
    );
    final rows = (data['results'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => TeacherStudent.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  // Update profile
  Future<String> updateProfile({
    required String teacherId,
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
    String? gender,
    String? dateOfBirth,
    String? officeLocation,
  }) async {
    final response = await postWithFallback(
      'teacher_profile_update.php',
      body: {
        'teacher_id': teacherId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone_number': phoneNumber,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'office_location': officeLocation,
      },
    );
    final parsed = parseResponse(response);
    return (parsed['message'] ?? 'Profile updated successfully').toString();
  }

  // Change password
  Future<String> changePassword({
    required String teacherId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await postWithFallback(
      'teacher_change_password.php',
      body: {
        'teacher_id': teacherId,
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    final parsed = parseResponse(response);
    return (parsed['message'] ?? 'Password updated successfully').toString();
  }

  Future<List<TeacherCourseMaterial>> fetchCourseMaterials({
    required String teacherId,
    required String sectionId,
  }) async {
    final data = await getWithCache(
      'teacher_course_materials.php',
      query: {'teacher_id': teacherId, 'section_id': sectionId},
    );
    final rows = (data['materials'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => TeacherCourseMaterial.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> addCourseMaterial({
    required String teacherId,
    required String sectionId,
    required String title,
    required String materialType,
    String? description,
    String? externalUrl,
    String? fileName,
    String? filePath,
  }) async {
    final response = await postWithFallback(
      'teacher_course_materials.php',
      body: {
        'action': 'add',
        'teacher_id': teacherId,
        'section_id': sectionId,
        'title': title,
        'material_type': materialType,
        'description': description,
        'external_url': externalUrl,
        'file_name': fileName,
        'file_path': filePath,
      },
    );
    parseResponse(response);
  }

  Future<void> uploadCourseMaterial({
    required String teacherId,
    required String sectionId,
    required String title,
    required String materialType,
    String? description,
    String? externalUrl,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final response = await postMultipartWithFallback(
      'teacher_course_materials.php',
      fields: {
        'action': 'add',
        'teacher_id': teacherId,
        'section_id': sectionId,
        'title': title,
        'material_type': materialType,
        'description': description ?? '',
        'external_url': externalUrl ?? '',
      },
      files: [
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      ],
    );
    parseResponse(response);
  }

  Future<void> deleteCourseMaterial({
    required String teacherId,
    required String materialId,
  }) async {
    final response = await postWithFallback(
      'teacher_course_materials.php',
      body: {
        'action': 'delete',
        'teacher_id': teacherId,
        'material_id': materialId,
      },
    );
    parseResponse(response);
  }

  Future<List<TeacherAttendanceSession>> fetchAttendanceSessions({
    required String teacherId,
    required String sectionId,
  }) async {
    final data = await getWithCache(
      'teacher_attendance.php',
      query: {'teacher_id': teacherId, 'section_id': sectionId},
    );
    final rows = (data['sessions'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => TeacherAttendanceSession.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<TeacherAttendanceRecord>> fetchAttendanceRecords({
    required String teacherId,
    required String sectionId,
    required String classDate,
  }) async {
    final data = await getWithCache(
      'teacher_attendance.php',
      query: {
        'teacher_id': teacherId,
        'section_id': sectionId,
        'class_date': classDate,
      },
    );
    final rows = (data['records'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => TeacherAttendanceRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> saveAttendance({
    required String teacherId,
    required String sectionId,
    required String classDate,
    required List<Map<String, dynamic>> entries,
  }) async {
    final response = await postWithFallback(
      'teacher_attendance.php',
      body: {
        'teacher_id': teacherId,
        'section_id': sectionId,
        'class_date': classDate,
        'entries': entries,
      },
    );
    parseResponse(response);
  }

  Future<List<TeacherResitSlot>> fetchTeacherResitTimetable({
    required String teacherId,
    bool forceRefresh = false,
    Duration maxAge = const Duration(minutes: 2),
  }) async {
    final data = await getWithCache(
      'teacher_timetable.php',
      query: {'teacher_id': teacherId, 'type': 'resit'},
      maxAge: maxAge,
      forceRefresh: forceRefresh,
    );
    final rows = (data['slots'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => TeacherResitSlot.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<TeacherResitSlot>> fetchTeacherExamTimetable({
    required String teacherId,
    bool forceRefresh = false,
    Duration maxAge = const Duration(minutes: 2),
  }) async {
    final data = await getWithCache(
      'teacher_timetable.php',
      query: {'teacher_id': teacherId, 'type': 'exam'},
      maxAge: maxAge,
      forceRefresh: forceRefresh,
    );
    final rows = (data['slots'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => TeacherResitSlot.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<TeacherResitSlot>> fetchTeacherSemesterTimetable({
    required String teacherId,
    bool forceRefresh = false,
    Duration maxAge = const Duration(minutes: 2),
  }) async {
    final data = await getWithCache(
      'teacher_timetable.php',
      query: {'teacher_id': teacherId, 'type': 'semester'},
      maxAge: maxAge,
      forceRefresh: forceRefresh,
    );
    final rows = (data['slots'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => TeacherResitSlot.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> submitReport(Map<String, dynamic> reportData) async {
    final response = await postWithFallback(
      'submit_report.php',
      body: reportData,
      offlineActionType: 'submit_report',
    );
    parseResponse(response);
  }

  Future<List<TeacherAnnouncementItem>> fetchTeacherAnnouncements(String teacherId) async {
    final data = await getWithCache(
      'teacher_announcements.php',
      query: {'teacher_id': teacherId},
      forceRefresh: true,
    );
    final rows = (data['announcements'] as List<dynamic>? ?? []);
    return rows
        .map((e) => TeacherAnnouncementItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createTeacherAnnouncement({
    required String teacherId,
    required String title,
    required String content,
    required String scope, // general | course
    String? courseId,
    bool isPublished = true,
  }) async {
    final response = await postWithFallback(
      'teacher_announcements.php',
      body: {
        'teacher_id': teacherId,
        'title': title,
        'content': content,
        'scope': scope,
        'course_id': courseId,
        'is_published': isPublished ? 1 : 0,
      },
    );
    parseResponse(response);
  }

  Future<List<TeacherEvent>> fetchTeacherEvents(String teacherId) async {
    final data = await getWithCache(
      'teacher_events.php',
      query: {'teacher_id': teacherId},
      forceRefresh: true,
    );
    final rows = (data['events'] as List<dynamic>? ?? []);
    return rows
        .map((e) => TeacherEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createTeacherEvent({
    required String teacherId,
    required String name,
    String? description,
    required String eventDate, // YYYY-MM-DD
    required String startTime, // HH:mm:ss
    String? endTime, // HH:mm:ss
    String? location,
    bool isPublic = true,
    String? eventType,
  }) async {
    final response = await postWithFallback(
      'teacher_events.php',
      body: {
        'teacher_id': teacherId,
        'event_name': name,
        'description': description,
        'event_date': eventDate,
        'start_time': startTime,
        'end_time': endTime,
        'location': location,
        'is_public': isPublic ? 1 : 0,
        'event_type': eventType,
      },
    );
    parseResponse(response);
  }
}
