class HomeStat {
  final int courses;
  final int announcements;
  final int unreadAnnouncements;
  final int assignments;
  final int events;

  const HomeStat({
    required this.courses,
    required this.announcements,
    required this.unreadAnnouncements,
    required this.assignments,
    required this.events,
  });

  factory HomeStat.fromJson(Map<String, dynamic> json) {
    int value(String key) => int.tryParse((json[key] ?? '0').toString()) ?? 0;
    return HomeStat(
      courses: value('courses_count'),
      announcements: value('announcements_count'),
      unreadAnnouncements: value('unread_announcements_count'),
      assignments: value('assignments_count'),
      events: value('events_count'),
    );
  }
}

class HomeAnnouncement {
  final String title;
  final String content;
  final String postedAt;

  const HomeAnnouncement({
    required this.title,
    required this.content,
    required this.postedAt,
  });

  factory HomeAnnouncement.fromJson(Map<String, dynamic> json) {
    return HomeAnnouncement(
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      postedAt: (json['posted_at'] ?? '').toString(),
    );
  }
}

class HomeEvent {
  final String name;
  final String eventDate;
  final String startTime;
  final String location;

  const HomeEvent({
    required this.name,
    required this.eventDate,
    required this.startTime,
    required this.location,
  });

  factory HomeEvent.fromJson(Map<String, dynamic> json) {
    return HomeEvent(
      name: (json['event_name'] ?? '').toString(),
      eventDate: (json['event_date'] ?? '').toString(),
      startTime: (json['start_time'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
    );
  }
}

class TodayCourse {
  final String code;
  final String name;
  final String sectionCode;
  final String room;
  final String schedule;
  final String startTime;
  final String endTime;
  final String day;

  const TodayCourse({
    required this.code,
    required this.name,
    required this.sectionCode,
    required this.room,
    required this.schedule,
    required this.startTime,
    required this.endTime,
    required this.day,
  });

  factory TodayCourse.fromJson(Map<String, dynamic> json) {
    return TodayCourse(
      code: (json['course_code'] ?? '').toString(),
      name: (json['course_name'] ?? '').toString(),
      sectionCode: (json['section_code'] ?? '').toString(),
      room: (json['room_number'] ?? '').toString(),
      schedule: (json['schedule'] ?? '').toString(),
      startTime: (json['start_time'] ?? '--:--').toString(),
      endTime: (json['end_time'] ?? '--:--').toString(),
      day: (json['day'] ?? '').toString(),
    );
  }
}

class StudentHomeData {
  final String firstName;
  final HomeStat stats;
  final List<TodayCourse> todayCourses;
  final List<HomeAnnouncement> announcements;
  final List<HomeEvent> events;

  const StudentHomeData({
    required this.firstName,
    required this.stats,
    required this.todayCourses,
    required this.announcements,
    required this.events,
  });

  factory StudentHomeData.fromJson(Map<String, dynamic> json) {
    final student = Map<String, dynamic>.from((json['student'] ?? const <String, dynamic>{}) as Map);
    final stats = Map<String, dynamic>.from((json['stats'] ?? const <String, dynamic>{}) as Map);

    final todayCourses = (json['today_courses'] as List<dynamic>? ?? const [])
        .map((e) => TodayCourse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final announcements = (json['announcements'] as List<dynamic>? ?? const [])
        .map((e) => HomeAnnouncement.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final events = (json['events'] as List<dynamic>? ?? const [])
        .map((e) => HomeEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return StudentHomeData(
      firstName: (student['first_name'] ?? 'Student').toString(),
      stats: HomeStat.fromJson(stats),
      todayCourses: todayCourses,
      announcements: announcements,
      events: events,
    );
  }
}
