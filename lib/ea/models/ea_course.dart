class EaCourse {
  final String courseId;
  final String courseCode;
  final String courseName;
  final String? description;
  final int credits;
  final int level;
  final int semester;
  final String? programId;
  final String? programName;
  final String? departmentId;
  final String? departmentName;
  final String? lecturerId;
  final String? lecturerName;
  final String? academicYear;
  final String? sectionName;
  final int? enrolledCount;
  final String? status;

  const EaCourse({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    this.description,
    required this.credits,
    this.level = 1,
    this.semester = 1,
    this.programId,
    this.programName,
    this.departmentId,
    this.departmentName,
    this.lecturerId,
    this.lecturerName,
    this.academicYear,
    this.sectionName,
    this.enrolledCount,
    this.status,
  });

  factory EaCourse.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? fallback;
    }

    int normalizeLevel(int raw) {
      if (raw >= 100) return raw ~/ 100;
      if (raw <= 0) return 1;
      return raw;
    }

    return EaCourse(
      courseId: json['course_id'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      description: json['description'] as String?,
      credits: parseInt(json['credits']),
      level: normalizeLevel(parseInt(json['level'], fallback: 1)),
      semester: parseInt(json['semester'], fallback: 1),
      programId: json['program_id'] as String?,
      programName: json['program_name'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName: json['department_name'] as String?,
      lecturerId: json['lecturer_id'] as String?,
      lecturerName: json['lecturer_name'] as String?,
      academicYear: json['academic_year'] as String?,
      sectionName: json['section_name'] as String?,
      enrolledCount: json['enrolled_count'] == null
          ? null
          : parseInt(json['enrolled_count']),
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'course_code': courseCode,
      'course_name': courseName,
      'description': description,
      'credits': credits,
      'level': level,
      'semester': semester,
      'program_id': programId,
      'program_name': programName,
      'department_id': departmentId,
      'department_name': departmentName,
      'lecturer_id': lecturerId,
      'lecturer_name': lecturerName,
      'academic_year': academicYear,
      'section_name': sectionName,
      'enrolled_count': enrolledCount,
      'status': status,
    };
  }
}
