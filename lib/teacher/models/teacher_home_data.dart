import 'package:flutter/foundation.dart';

import 'teacher_resit_slot.dart';

class TeacherHomeData {
  final int totalCourses;
  final int totalStudents;
  final int announcementCount;
  final String currentYear;
  final String currentSemester;
  final List<AssignedCourse> assignedCourses;
  final List<AssignedCourse> todayCourses;
  final List<TeacherAnnouncement> announcements;
  final List<TeacherEvent> events;
  final List<TeacherResitSlot> resitSlots;

  const TeacherHomeData({
    required this.totalCourses,
    required this.totalStudents,
    required this.announcementCount,
    required this.currentYear,
    required this.currentSemester,
    required this.assignedCourses,
    required this.todayCourses,
    required this.announcements,
    required this.events,
    required this.resitSlots,
  });

  factory TeacherHomeData.fromJson(Map<String, dynamic> json) {
    List<AssignedCourse> parseCourses(String key) {
      try {
        return (json[key] as List<dynamic>? ?? [])
            .map((e) => AssignedCourse.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Error parsing $key: $e');
        return [];
      }
    }

    List<AssignedCourse> parseAssignedCourses() => parseCourses('assigned_courses');
    List<AssignedCourse> parseTodayCourses() => parseCourses('today_courses');

    List<TeacherAnnouncement> parseAnnouncements() {
      try {
        return (json['announcements'] as List<dynamic>? ?? [])
            .map((e) => TeacherAnnouncement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Error parsing announcements: $e');
        return [];
      }
    }

    List<TeacherEvent> parseEvents() {
      try {
        return (json['events'] as List<dynamic>? ?? [])
            .map((e) => TeacherEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Error parsing events: $e');
        return [];
      }
    }

    List<TeacherResitSlot> parseResitSlots() {
      try {
        return (json['resit_slots'] as List<dynamic>? ?? [])
            .map((e) => TeacherResitSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Error parsing resit_slots: $e');
        return [];
      }
    }

    return TeacherHomeData(
      totalCourses: int.tryParse((json['total_courses'] ?? '0').toString()) ?? 0,
      totalStudents: int.tryParse((json['total_students'] ?? '0').toString()) ?? 0,
      announcementCount: int.tryParse((json['announcement_count'] ?? '0').toString()) ?? 0,
      currentYear: json['current_year'] as String? ?? '2025/2026',
      currentSemester: json['current_semester'] as String? ?? 'First',
      assignedCourses: parseAssignedCourses(),
      todayCourses: parseTodayCourses(),
      announcements: parseAnnouncements(),
      events: parseEvents(),
      resitSlots: parseResitSlots(),
    );
  }
}

class TeacherAnnouncement {
  final String announcementId;
  final String title;
  final String content;
  final String createdAt;

  const TeacherAnnouncement({
    required this.announcementId,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory TeacherAnnouncement.fromJson(Map<String, dynamic> json) {
    return TeacherAnnouncement(
      announcementId: json['announcement_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class TeacherEvent {
  final String eventId;
  final String name;
  final String? description;
  final String eventDate;
  final String startTime;
  final String? location;

  const TeacherEvent({
    required this.eventId,
    required this.name,
    this.description,
    required this.eventDate,
    required this.startTime,
    this.location,
  });

  factory TeacherEvent.fromJson(Map<String, dynamic> json) {
    String pickString(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        final s = v.toString();
        if (s.trim().isNotEmpty) return s;
      }
      return '';
    }

    return TeacherEvent(
      eventId: pickString(['event_id', 'id', 'eventId']),
      name: pickString(['event_name', 'name', 'title']),
      description: json['description'] as String?,
      eventDate: pickString(['event_date', 'date']),
      startTime: pickString(['start_time', 'time', 'start']),
      location: json['location'] as String?,
    );
  }
}

class AssignedCourse {
  final String sectionId;
  final String sectionCode;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String? programName;
  final int studentCount;
  final String academicYear;
  final String semester;
  final String roomNumber;
  final String schedule;

  const AssignedCourse({
    required this.sectionId,
    required this.sectionCode,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    this.programName,
    required this.studentCount,
    required this.academicYear,
    required this.semester,
    required this.roomNumber,
    required this.schedule,
  });

  factory AssignedCourse.fromJson(Map<String, dynamic> json) {
    return AssignedCourse(
      sectionId: json['section_id'] as String? ?? '',
      sectionCode: json['section_code'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      programName: json['program_name'] as String?,
      studentCount:
          int.tryParse((json['student_count'] ?? '0').toString()) ?? 0,
      academicYear: json['academic_year'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      roomNumber: json['room_number'] as String? ?? '',
      schedule: json['schedule'] as String? ?? '',
    );
  }
}
