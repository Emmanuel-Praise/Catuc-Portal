class TeacherAttendanceSession {
  final String classDate;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final String recordedAt;

  const TeacherAttendanceSession({
    required this.classDate,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    required this.recordedAt,
  });

  factory TeacherAttendanceSession.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) => int.tryParse((value ?? '0').toString()) ?? 0;

    return TeacherAttendanceSession(
      classDate: (json['class_date'] ?? '').toString(),
      totalStudents: parseInt(json['total_students']),
      presentCount: parseInt(json['present_count']),
      absentCount: parseInt(json['absent_count']),
      lateCount: parseInt(json['late_count']),
      excusedCount: parseInt(json['excused_count']),
      recordedAt: (json['recorded_at'] ?? '').toString(),
    );
  }
}

class TeacherAttendanceRecord {
  final String attendanceId;
  final String enrollmentId;
  final String studentId;
  final String studentNumber;
  final String firstName;
  final String lastName;
  final String programName;
  final String departmentName;
  final String classDate;
  final String status;
  final String notes;
  final String recordedAt;

  const TeacherAttendanceRecord({
    required this.attendanceId,
    required this.enrollmentId,
    required this.studentId,
    required this.studentNumber,
    required this.firstName,
    required this.lastName,
    required this.programName,
    required this.departmentName,
    required this.classDate,
    required this.status,
    required this.notes,
    required this.recordedAt,
  });

  String get fullName => '$lastName $firstName';

  factory TeacherAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceRecord(
      attendanceId: (json['attendance_id'] ?? '').toString(),
      enrollmentId: (json['enrollment_id'] ?? '').toString(),
      studentId: (json['student_id'] ?? '').toString(),
      studentNumber: (json['student_number'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      programName: (json['program_name'] ?? '').toString(),
      departmentName: (json['department_name'] ?? '').toString(),
      classDate: (json['class_date'] ?? '').toString(),
      status: (json['status'] ?? 'absent').toString(),
      notes: (json['notes'] ?? '').toString(),
      recordedAt: (json['recorded_at'] ?? '').toString(),
    );
  }
}
