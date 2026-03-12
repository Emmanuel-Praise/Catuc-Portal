import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../student/services/student_api_service.dart';
import '../teacher/services/teacher_api_service.dart';
import '../ea/services/ea_api_service.dart';

class OfflineSyncService {
  static Database? _db;

  const OfflineSyncService();

  static Future<void> init() async {
    if (kIsWeb) return; // sqflite is not supported on web
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_sync.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT,
            payload TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            retry_count INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> queueAction(
    String actionType,
    Map<String, dynamic> payload,
  ) async {
    await _db?.insert('sync_queue', {
      'action_type': actionType,
      'payload': jsonEncode(payload),
    });
    // Try to sync immediately if online
    checkAndSync();
  }

  Future<void> checkAndSync() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final pending = await _db?.query('sync_queue', orderBy: 'timestamp ASC');
    if (pending == null || pending.isEmpty) return;

    for (final item in pending) {
      final id = item['id'] as int;
      final type = item['action_type'] as String;
      final payload =
          jsonDecode(item['payload'] as String) as Map<String, dynamic>;

      try {
        bool success = await _performAction(type, payload);
        if (success) {
          await _db?.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
        } else {
          // Increment retry count
          await _db?.rawUpdate(
            'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
            [id],
          );
        }
      } catch (e) {
        debugPrint('Sync error for action $type: $e');
      }
    }
  }

  Future<bool> _performAction(String type, Map<String, dynamic> payload) async {
    try {
      switch (type) {
        case 'submit_result':
          await const TeacherApiService().submitResult(
            sectionId: payload['section_id'],
            studentId: payload['student_id'],
            attendanceScore: payload['attendance_score'],
            caScore: payload['ca_score'],
            examScore: payload['exam_score'],
            grade: payload['grade'],
            gradePoint: payload['grade_point'],
          );
          return true;
        case 'update_profile_student':
          await const StudentApiService().updateProfile(
            studentId: payload['student_id'],
            firstName: payload['first_name'],
            lastName: payload['last_name'],
            dateOfBirth: payload['date_of_birth'],
            phoneNumber: payload['phone_number'],
            gender: payload['gender'],
          );
          return true;
        case 'enroll_courses':
          await const StudentApiService().enrollCourses(
            studentId: payload['student_id'],
            courseIds: List<String>.from(payload['course_ids']),
            year: payload['year'],
            semester: payload['semester'],
            level: payload['level'],
          );
          return true;
        case 'ea_add_student':
          await const EaApiService().addStudent(
            firstName: payload['first_name'],
            lastName: payload['last_name'],
            email: payload['email'],
            studentNumber: payload['student_number'],
            programId: payload['program_id'],
            level: payload['level'] ?? 1,
          );
          return true;
        case 'ea_update_student':
          await const EaApiService().updateStudent(
            studentId: payload['student_id'],
            firstName: payload['first_name'],
            lastName: payload['last_name'],
            email: payload['email'],
            programId: payload['program_id'],
            currentYear: payload['current_year'],
            currentSemester: payload['current_semester'],
            academicStatus: payload['academic_status'],
          );
          return true;
        case 'ea_delete_student':
          await const EaApiService().deleteStudent(payload['student_id']);
          return true;
        case 'ea_add_course':
          await const EaApiService().addCourse(
            courseCode: payload['course_code'],
            courseTitle: payload['course_title'],
            level: payload['level'],
            semester: payload['semester'],
            programId: payload['program_id'],
            departmentId: payload['department_id'],
            credits: payload['credits'] ?? 3,
          );
          return true;
        case 'ea_delete_course':
          await const EaApiService().deleteCourse(payload['course_id']);
          return true;
        case 'ea_enroll_student':
          await const EaApiService().enrollStudent(
            studentId: payload['student_id'],
            courseId: payload['course_id'],
            academicYear: payload['academic_year'],
            semester: payload['semester'],
          );
          return true;
        case 'ea_update_enrollment_status':
          await const EaApiService().updateEnrollmentStatus(
            enrollmentId: payload['enrollment_id'],
            status: payload['status'],
          );
          return true;
        case 'ea_submit_result':
          await const EaApiService().submitResult(
            studentId: payload['student_id'],
            courseId: payload['course_id'],
            academicYear: payload['academic_year'],
            semester: payload['semester'],
            score: payload['score'],
            grade: payload['grade'],
            gradePoint: payload['grade_point'],
          );
          return true;
        case 'ea_update_result':
          await const EaApiService().updateResult(
            resultId: payload['result_id'],
            score: payload['score'],
            grade: payload['grade'],
            gradePoint: payload['grade_point'],
          );
          return true;
        case 'remove_enrollment':
          await const StudentApiService().removeEnrollment(
            studentId: payload['student_id'],
            enrollmentId: payload['enrollment_id'],
            year: payload['year'],
            semester: payload['semester'],
            level: payload['level'],
          );
          return true;
        case 'student_change_password':
          await const StudentApiService().changePassword(
            studentId: payload['student_id'],
            currentPassword: payload['current_password'],
            newPassword: payload['new_password'],
            confirmPassword: payload['confirm_password'],
          );
          return true;
        case 'submit_report':
          await const StudentApiService().submitReport(payload);
          return true;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }
}
