import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../models/ea_course.dart';
import '../models/ea_enrollment.dart';
import '../models/ea_home_data.dart';
import '../models/ea_profile.dart';
import '../models/ea_result.dart';
import '../models/ea_session.dart';
import '../models/ea_student.dart';

class EaApiService extends ApiService {
  const EaApiService();

  Future<EaSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await postWithFallback(
      'ea_login.php',
      body: {'identifier': identifier, 'password': password},
    );

    final data = parseResponse(response);
    return EaSession.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<EaHomeData> fetchHome(String eaId) async {
    final data = await getWithCache('ea_home.php', query: {
      'ea_id': eaId,
    });
    return EaHomeData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<EaProfile> fetchProfile(String eaId) async {
    final data = await getWithCache('ea_profile.php', query: {
      'ea_id': eaId,
    });
    return EaProfile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
  }

  Future<List<EaStudent>> fetchStudents({
    String? search,
    String? programId,
    String? year,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (programId != null && programId.isNotEmpty) {
      queryParams['program_id'] = programId;
    }
    if (year != null && year.isNotEmpty) {
      queryParams['year'] = year;
    }

    final data = await getWithCache(
      'ea_students.php',
      query: queryParams.isNotEmpty ? queryParams : null,
    );
    final rows = (data['students'] as List<dynamic>? ?? []);
    return rows
        .map((e) => EaStudent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<EaCourse>> fetchCourses({
    String? search,
    String? programId,
    String? departmentId,
    String? academicYear,
    String? semester,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (programId != null && programId.isNotEmpty) {
      queryParams['program_id'] = programId;
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParams['department_id'] = departmentId;
    }
    if (academicYear != null && academicYear.isNotEmpty) {
      queryParams['academic_year'] = academicYear;
    }
    if (semester != null && semester.isNotEmpty) {
      queryParams['semester'] = semester;
    }

    final data = await getWithCache(
      'ea_courses.php',
      query: queryParams.isNotEmpty ? queryParams : null,
    );
    final rows = (data['courses'] as List<dynamic>? ?? []);
    return rows
        .map((e) => EaCourse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<EaEnrollment>> fetchEnrollments({
    String? studentId,
    String? courseId,
    String? academicYear,
    String? semester,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (studentId != null && studentId.isNotEmpty) {
      queryParams['student_id'] = studentId;
    }
    if (courseId != null && courseId.isNotEmpty) {
      queryParams['course_id'] = courseId;
    }
    if (academicYear != null && academicYear.isNotEmpty) {
      queryParams['academic_year'] = academicYear;
    }
    if (semester != null && semester.isNotEmpty) {
      queryParams['semester'] = semester;
    }
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final data = await getWithCache(
      'ea_enrollments.php',
      query: queryParams.isNotEmpty ? queryParams : null,
    );
    final rows = (data['enrollments'] as List<dynamic>? ?? []);
    return rows
        .map((e) => EaEnrollment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<EaResult>> fetchResults({
    String? studentId,
    String? courseId,
    String? academicYear,
    String? semester,
  }) async {
    final queryParams = <String, String>{};
    if (studentId != null && studentId.isNotEmpty) {
      queryParams['student_id'] = studentId;
    }
    if (courseId != null && courseId.isNotEmpty) {
      queryParams['course_id'] = courseId;
    }
    if (academicYear != null && academicYear.isNotEmpty) {
      queryParams['academic_year'] = academicYear;
    }
    if (semester != null && semester.isNotEmpty) {
      queryParams['semester'] = semester;
    }

    final data = await getWithCache(
      'ea_results.php',
      query: queryParams.isNotEmpty ? queryParams : null,
    );
    final rows = (data['results'] as List<dynamic>? ?? []);
    return rows
        .map((e) => EaResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addStudent({
    required String firstName,
    required String lastName,
    required String email,
    required String studentNumber,
    String? programId,
    int level = 1,
  }) async {
    final response = await postWithFallback(
      'ea_students.php',
      body: {
        'action': 'add',
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'student_number': studentNumber,
        'program_id': programId,
        'level': level,
      },
      offlineActionType: 'ea_add_student',
    );
    parseResponse(response);
  }

  Future<void> updateStudent({
    required String studentId,
    String? firstName,
    String? lastName,
    String? email,
    String? programId,
    int? currentYear,
    int? currentSemester,
    String? academicStatus,
  }) async {
    final response = await postWithFallback(
      'ea_students.php',
      body: {
        'action': 'update',
        'student_id': studentId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'program_id': programId,
        'current_year': currentYear,
        'current_semester': currentSemester,
        'academic_status': academicStatus,
      },
    );
    parseResponse(response);
  }

  Future<void> deleteStudent(String studentId) async {
    final response = await postWithFallback(
      'ea_students.php',
      body: {'action': 'delete', 'student_id': studentId},
    );
    parseResponse(response);
  }

  Future<void> addCourse({
    required String courseCode,
    required String courseTitle,
    required int level,
    required int semester,
    String? programId,
    String? departmentId,
    int credits = 3,
  }) async {
    final response = await postWithFallback(
      'ea_courses.php',
      body: {
        'action': 'add',
        'course_code': courseCode,
        'course_name': courseTitle,
        'level': level,
        'semester': semester,
        'program_id': programId,
        'department_id': departmentId,
        'credits': credits,
      },
    );
    parseResponse(response);
  }

  Future<void> deleteCourse(String courseId) async {
    final response = await postWithFallback(
      'ea_courses.php',
      body: {'action': 'delete', 'course_id': courseId},
    );
    parseResponse(response);
  }

  Future<void> downloadClassList(String courseId) async {
    await getWithCache(
      'ea_class_list.php',
      query: {'course_id': courseId},
    );
    debugPrint('Class list downloaded/cached for course: $courseId');
  }

  Future<void> enrollStudent({
    required String studentId,
    required String courseId,
    required String academicYear,
    required String semester,
  }) async {
    final response = await postWithFallback(
      'ea_enrollments.php',
      body: {
        'action': 'enroll',
        'student_id': studentId,
        'course_id': courseId,
        'academic_year': academicYear,
        'semester': semester,
      },
    );
    parseResponse(response);
  }

  Future<void> updateEnrollmentStatus({
    required String enrollmentId,
    required String status,
  }) async {
    final response = await postWithFallback(
      'ea_enrollments.php',
      body: {
        'action': 'update_status',
        'enrollment_id': enrollmentId,
        'status': status,
      },
    );
    parseResponse(response);
  }

  Future<void> submitResult({
    required String studentId,
    required String courseId,
    required String academicYear,
    required String semester,
    required double score,
    String? grade,
    double? gradePoint,
  }) async {
    final response = await postWithFallback(
      'ea_results.php',
      body: {
        'action': 'submit',
        'student_id': studentId,
        'course_id': courseId,
        'academic_year': academicYear,
        'semester': semester,
        'score': score,
        'grade': grade,
        'grade_point': gradePoint,
      },
    );
    parseResponse(response);
  }

  Future<void> updateResult({
    required String resultId,
    double? score,
    String? grade,
    double? gradePoint,
  }) async {
    final response = await postWithFallback(
      'ea_results.php',
      body: {
        'action': 'update',
        'result_id': resultId,
        'score': score,
        'grade': grade,
        'grade_point': gradePoint,
      },
    );
    parseResponse(response);
  }
}
