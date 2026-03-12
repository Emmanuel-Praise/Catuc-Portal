import 'package:catuc_portal/student/models/student_session.dart';
import 'package:catuc_portal/teacher/models/teacher_session.dart';

/// A lightweight, role-agnostic user model consumed by all AI screens.
/// Both [StudentSession] and [TeacherSession] can convert into this.
class AiUser {
  final String userId;
  final String fullName;
  final String firstName;
  final String role; // 'student' | 'teacher'
  /// Contextual label used for AI topic suggestions.
  /// - Students: program name (e.g. "Computer Science")
  /// - Teachers: comma-separated course names they teach
  final String? contextLabel;

  const AiUser({
    required this.userId,
    required this.fullName,
    required this.firstName,
    required this.role,
    this.contextLabel,
  });

  factory AiUser.fromStudentSession(StudentSession session, {String? contextLabel}) {
    return AiUser(
      userId: session.userId,
      fullName: session.fullName,
      firstName: session.firstName,
      role: 'student',
      contextLabel: contextLabel,
    );
  }

  factory AiUser.fromTeacherSession(TeacherSession session, {String? contextLabel}) {
    return AiUser(
      userId: session.userId,
      fullName: session.fullName,
      firstName: session.firstName,
      role: 'teacher',
      contextLabel: contextLabel,
    );
  }
}
