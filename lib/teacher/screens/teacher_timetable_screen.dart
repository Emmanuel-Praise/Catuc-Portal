import 'package:flutter/material.dart';

import '../../theme/theme_service.dart';
import '../models/teacher_home_data.dart';
import '../models/teacher_resit_slot.dart';
import '../services/teacher_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';
import '../../services/connectivity_service.dart';

class TeacherTimetableScreen extends StatefulWidget {
  final String teacherId;
  final List<AssignedCourse> courses;

  const TeacherTimetableScreen({
    super.key,
    required this.teacherId,
    required this.courses,
  });

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen>
    with SingleTickerProviderStateMixin {
  final TeacherApiService _api = const TeacherApiService();
  late TabController _tabController;
  late Future<List<TeacherResitSlot>> _semesterFuture;
  late Future<List<TeacherResitSlot>> _examFuture;
  late Future<List<TeacherResitSlot>> _resitFuture;

  static const List<_WeekDay> _days = [
    _WeekDay(label: 'Monday', tokens: ['mon', 'monday']),
    _WeekDay(label: 'Tuesday', tokens: ['tue', 'tues', 'tuesday']),
    _WeekDay(label: 'Wednesday', tokens: ['wed', 'wednesday']),
    _WeekDay(label: 'Thursday', tokens: ['thu', 'thur', 'thurs', 'thursday']),
    _WeekDay(label: 'Friday', tokens: ['fri', 'friday']),
    _WeekDay(label: 'Saturday', tokens: ['sat', 'saturday']),
    _WeekDay(label: 'Sunday', tokens: ['sun', 'sunday']),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSlots();
  }

  void _loadSlots() {
    final shouldForceRefresh = ConnectivityService().isOnline;
    _semesterFuture = _api.fetchTeacherSemesterTimetable(
      teacherId: widget.teacherId,
      forceRefresh: shouldForceRefresh,
    );
    _examFuture = _api.fetchTeacherExamTimetable(
      teacherId: widget.teacherId,
      forceRefresh: shouldForceRefresh,
    );
    _resitFuture = _api.fetchTeacherResitTimetable(
      teacherId: widget.teacherId,
      forceRefresh: shouldForceRefresh,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showReportDialog(dynamic error) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report an Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please describe what happened.'),
            const SizedBox(height: 16),
            TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await const ReportService().submitReport(userId: widget.teacherId, role: 'lecturer', issueType: 'Teacher Timetable Error', description: controller.text.trim(), additionalData: {'error': error.toString()});
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue reported. Thank you!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  bool _matchesDay(String schedule, List<String> tokens) {
    final n = schedule.toLowerCase();
    for (final t in tokens) {
      if (RegExp('\\b${RegExp.escape(t)}\\b', caseSensitive: false).hasMatch(n)) return true;
    }
    return false;
  }

  String _normalizeDayName(String day) {
    if (day.isEmpty) return 'Unscheduled';
    
    final normalizedDay = day.toLowerCase().trim();
    
    switch (normalizedDay) {
      case 'mon':
      case 'monday':
        return 'Monday';
      case 'tue':
      case 'tues':
      case 'tuesday':
        return 'Tuesday';
      case 'wed':
      case 'wednesday':
        return 'Wednesday';
      case 'thu':
      case 'thur':
      case 'thurs':
      case 'thursday':
        return 'Thursday';
      case 'fri':
      case 'friday':
        return 'Friday';
      case 'sat':
      case 'saturday':
        return 'Saturday';
      case 'sun':
      case 'sunday':
        return 'Sunday';
      default:
        if (['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].contains(day)) {
          return day;
        }
        return day.contains('-') ? day : 'Other';
    }
  }

  bool _isToday(String day) {
    if (day.isEmpty) return false;
    final normalizedDay = _normalizeDayName(day);
    final today = DateTime.now();
    final todayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][today.weekday - 1];
    return normalizedDay == todayName;
  }

  List<AssignedCourse> _coursesForDay(_WeekDay day) {
    final list = widget.courses.where((c) => _matchesDay(c.schedule, day.tokens)).toList();
    list.sort((a, b) => a.courseCode.toLowerCase().compareTo(b.courseCode.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final primary = ThemeService().primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        backgroundColor: primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.view_week_rounded, size: 20), text: 'Weekly'),
            Tab(icon: Icon(Icons.edit_note_rounded, size: 20), text: 'Exam'),
            Tab(icon: Icon(Icons.replay_rounded, size: 20), text: 'Resit'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_loadSlots),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeeklyBody(primary),
          _buildSlotBody(_examFuture, 'exam', Colors.orange.shade700),
          _buildSlotBody(_resitFuture, 'resit', Colors.red.shade600),
        ],
      ),
    );
  }

  // ── Weekly tab ──
  Widget _buildWeeklyBody(Color primary) {
    if (widget.courses.isEmpty) {
      return _emptyState(Icons.calendar_month_rounded, 'No assigned courses', 'Your weekly schedule will appear here once courses are assigned.', primary);
    }

    final hasWeeklySchedule = widget.courses.any((c) => c.schedule.trim().isNotEmpty);
    if (!hasWeeklySchedule) {
      return _buildSemesterBody(primary);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          child: const Text('Weekly class timetable for your courses.', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        for (final day in _days) ...[
          _DaySection(
            day: day.label, 
            courses: _coursesForDay(day),
            isToday: _isToday(day.label),
            primary: primary,
          ),
          if (day != _days.last) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSemesterBody(Color primary) {
    return FutureBuilder<List<TeacherResitSlot>>(
      future: _semesterFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AppErrorWidget(
            error: snapshot.error,
            onRetry: () => setState(_loadSlots),
            onReport: () => _showReportDialog(snapshot.error),
          );
        }
        final slots = snapshot.data ?? [];
        if (slots.isEmpty) {
          return _emptyState(
            Icons.calendar_month_rounded,
            'No semester timetable',
            'No semester timetable was found for your assigned courses.',
            primary,
          );
        }

        final Map<String, List<TeacherResitSlot>> grouped = {};
        for (final s in slots) {
          // Use day field if available, otherwise fall back to examDate
          final key = s.day.isNotEmpty ? s.day : (s.examDate.isNotEmpty ? s.examDate : 'No Date');
          grouped.putIfAbsent(key, () => []).add(s);
        }
        final dates = grouped.keys.toList()..sort();

        return RefreshIndicator(
          onRefresh: () async => setState(_loadSlots),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: dates.length,
            itemBuilder: (context, i) {
              final date = dates[i];
              final dateSlots = grouped[date]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dateHeader(date, dateSlots.length, primary),
                  ...dateSlots.map((s) => _slotCard(s, primary, 'SEMESTER')),
                  if (i < dates.length - 1) const Divider(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── Exam / Resit tab ──
  Widget _buildSlotBody(Future<List<TeacherResitSlot>> future, String type, Color accent) {
    return FutureBuilder<List<TeacherResitSlot>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AppErrorWidget(
            error: snapshot.error,
            onRetry: () => setState(_loadSlots),
            onReport: () => _showReportDialog(snapshot.error),
          );
        }
        final slots = snapshot.data ?? [];
        if (slots.isEmpty) {
          final isExam = type == 'exam';
          return _emptyState(
            isExam ? Icons.edit_note_rounded : Icons.celebration_rounded,
            isExam ? 'No exam timetable' : 'No resit timetable',
            isExam ? 'No exam schedule published for your courses yet.' : 'No resit schedule for your courses.',
            accent,
          );
        }

        // Group by date
        final Map<String, List<TeacherResitSlot>> grouped = {};
        for (final s in slots) {
          // Use day field if available, otherwise fall back to examDate
          final key = s.day.isNotEmpty ? s.day : (s.examDate.isNotEmpty ? s.examDate : 'No Date');
          grouped.putIfAbsent(key, () => []).add(s);
        }
        final dates = grouped.keys.toList()..sort();

        return RefreshIndicator(
          onRefresh: () async => setState(_loadSlots),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: dates.length,
            itemBuilder: (context, i) {
              final date = dates[i];
              final dateSlots = grouped[date]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dateHeader(date, dateSlots.length, accent),
                  ...dateSlots.map((s) => _slotCard(s, accent, type.toUpperCase())),
                  if (i < dates.length - 1) const Divider(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _dateHeader(String date, int count, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(date, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Text('$count ${count == 1 ? 'course' : 'courses'}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent.withValues(alpha: 0.7))),
        ),
      ]),
    );
  }

  Widget _slotCard(TeacherResitSlot s, Color accent, String label) {
    // Format time display
    String timeDisplay = '';
    if (s.startTime.isNotEmpty && s.startTime != '--:--') {
      timeDisplay = s.startTime;
      if (s.endTime.isNotEmpty && s.endTime != '--:--') {
        timeDisplay += ' - ${s.endTime}';
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.event_note_rounded, color: accent, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.courseId, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent)),
              if (s.courseName.isNotEmpty) ...[const SizedBox(height: 4), Text(s.courseName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color))],
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent, letterSpacing: 0.5))),
          ]),
          const SizedBox(height: 16),
          if (timeDisplay.isNotEmpty) _infoRow(Icons.access_time_rounded, 'Time', timeDisplay),
          if (timeDisplay.isNotEmpty) const SizedBox(height: 8),
          _infoRow(Icons.location_on_rounded, 'Venue', s.venue.isNotEmpty ? s.venue : 'TBA'),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
      const SizedBox(width: 8),
      Text('$label:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodySmall?.color)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color))),
    ]);
  }

  Widget _emptyState(IconData icon, String title, String subtitle, Color color) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, size: 64, color: color)),
      const SizedBox(height: 16),
      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.titleMedium?.color)),
      const SizedBox(height: 8),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153)))),
    ]));
  }
}

class _DaySection extends StatelessWidget {
  final String day;
  final List<AssignedCourse> courses;
  final bool isToday;
  final Color primary;

  const _DaySection({
    required this.day, 
    required this.courses,
    required this.isToday,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, 
        borderRadius: BorderRadius.circular(20),
        border: isToday 
            ? Border.all(color: primary.withValues(alpha: 0.3), width: 2)
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Text(
              isToday ? 'Today' : day, 
              style: TextStyle(
                fontSize: 17, 
                fontWeight: FontWeight.w700,
                color: isToday ? primary : null,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (courses.isEmpty)
          Text(
            'No classes scheduled.', 
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontStyle: isToday ? FontStyle.italic : null,
            ),
          )
        else
          for (final course in courses) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isToday 
                    ? primary.withValues(alpha: 0.2)
                    : ThemeService().primaryColor.withValues(alpha: 0.1), 
                child: Icon(
                  Icons.menu_book_rounded, 
                  color: isToday ? primary : ThemeService().primaryColor,
                ),
              ),
              title: Text(
                '${course.courseCode} - ${course.courseName}', 
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isToday ? primary : null,
                ),
              ),
              subtitle: Text(
                '${course.sectionCode.isEmpty ? "Section N/A" : course.sectionCode}  •  ${course.schedule.isEmpty ? "Schedule N/A" : course.schedule}\n${course.roomNumber.isEmpty ? "Room N/A" : course.roomNumber}  •  ${course.studentCount} students',
                style: TextStyle(
                  color: isToday 
                      ? primary.withValues(alpha: 0.8)
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
            if (course != courses.last) const Divider(height: 1),
          ],
      ]),
    );
  }
}

class _WeekDay {
  final String label;
  final List<String> tokens;
  const _WeekDay({required this.label, required this.tokens});
}
