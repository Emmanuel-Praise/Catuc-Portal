import 'package:flutter/material.dart';

import '../../theme/theme_service.dart';
import '../models/teacher_home_data.dart';
import '../models/teacher_session.dart';
import '../services/teacher_api_service.dart';
import '../../shared/screens/report_screen.dart';
import 'teacher_courses_screen.dart';
import 'teacher_announcements_screen.dart';
import 'teacher_events_screen.dart';
import 'teacher_timetable_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_students_screen.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';
import '../../shared/models/ai_user.dart';
import '../../student/screens/ai/widgets/ai_menu_overlay.dart';
import '../../student/screens/ai/brainstorm_screen.dart';
import '../../student/screens/ai/learn_screen.dart';
import '../../student/screens/ai/read_screen.dart';
import '../../student/screens/ai/code_assistant_screen.dart';
import '../../student/screens/ai/widgets/live_voice_assistant_box.dart';

class TeacherHomeScreen extends StatefulWidget {
  final TeacherSession user;

  const TeacherHomeScreen({super.key, required this.user});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  late Future<TeacherHomeData> _future;

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
    _future = const TeacherApiService().fetchHome(widget.user.userId);
  }

  Future<void> _reload() async {
    try {
      setState(() {
        _future = const TeacherApiService().fetchHome(widget.user.userId);
      });
      await _future;
    } catch (e) {
      debugPrint('Error reloading teacher home data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCourses() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TeacherCoursesScreen(user: widget.user)),
    );
    if (mounted) _reload();
  }

  Future<void> _openAnnouncements({
    required List<AssignedCourse> courses,
    required String currentSemester,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherAnnouncementsScreen(
          user: widget.user,
          courses: courses,
          currentSemester: currentSemester,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _openEvents() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TeacherEventsScreen(user: widget.user)),
    );
    if (mounted) _reload();
  }

  Future<void> _showCreateEventSheetOnHome() async {
    // For now, we navigate to the events screen where the user can add.
    // In a future polish, we could pass a flag to open the sheet immediately.
    await _openEvents();
  }

  Future<void> _openStudents() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TeacherStudentsScreen(user: widget.user)),
    );
    if (mounted) _reload();
  }

  void _openTimetable(List<AssignedCourse> courses) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherTimetableScreen(
          teacherId: widget.user.userId,
          courses: courses,
        ),
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

  List<AssignedCourse> _todayCourses(List<AssignedCourse> courses) {
    final weekday = DateTime.now().weekday; // 1..7 (Mon..Sun)
    final day = _days[weekday - 1];
    final list = courses.where((c) => _matchesDay(c.schedule, day.tokens)).toList();
    list.sort((a, b) => a.courseCode.toLowerCase().compareTo(b.courseCode.toLowerCase()));
    return list;
  }

  void _showReportDialog(dynamic error) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report an Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please describe what happened so we can fix it.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g. The page didn\'t load after I clicked...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await const ReportService().submitReport(
                  userId: widget.user.userId,
                  role: 'lecturer',
                  issueType: 'UI Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Issue reported successfully. Thank you!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to report: $e')),
                  );
                }
              }
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  void _showAiMenu(TeacherHomeData homeData) {
    final courseNames = homeData.assignedCourses
        .map((c) => c.courseName)
        .toSet()
        .join(', ');
    final aiUser = AiUser.fromTeacherSession(
      widget.user,
      contextLabel: courseNames.isNotEmpty ? courseNames : 'General Teaching',
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AI Menu',
      barrierColor: Colors.black54, // Keep as constant overlay
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return AiMenuOverlay(
          userData: {'user_id': widget.user.userId},
          onActionSelected: (action) {
            Widget screen;
            switch (action) {
              case 'brainstorm':
                screen = BrainstormScreen(user: aiUser, dashboardData: {});
                break;
              case 'learn':
                screen = LearnScreen(user: aiUser, dashboardData: {});
                break;
              case 'read':
                screen = ReadScreen(user: aiUser, dashboardData: {});
                break;
              case 'code':
                screen = CodeAssistantScreen(user: aiUser, dashboardData: {});
                break;
              case 'voice':
                if (!mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  showModalBottomSheet(
                    context: this.context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => LiveVoiceAssistantBox(
                      user: aiUser,
                      onClose: () => Navigator.pop(ctx),
                    ),
                  );
                });
                return;
              default:
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Feature "$action" coming soon!')),
                );
                return;
            }
            if (!mounted) return;
            Navigator.push(this.context, MaterialPageRoute(builder: (context) => screen));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final themeService = ThemeService();
    final primaryColor = themeService.primaryColor;
    
    // Create gradient from primary color
    final primaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor,
        primaryColor.withValues(alpha: 0.8),
      ],
    );

    return Scaffold(
      floatingActionButton: FutureBuilder<TeacherHomeData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          return Container(
            decoration: BoxDecoration(
              gradient: primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () => _showAiMenu(snap.data!),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onPrimary),
            ),
          );
        },
      ),
      body: FutureBuilder<TeacherHomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorWidget(
              error: snapshot.error,
              onRetry: _reload,
              onReport: () => _showReportDialog(snapshot.error),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No home data'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: primaryGradient,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _HeaderPatternPainter(primaryColor),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        MediaQuery.of(context).padding.top + 20,
                        24,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Welcome Back',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimary.withAlpha(230), // 0.9 opacity
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${widget.user.firstName}!',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.headlineMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'CATUC Lecturer Portal',
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimary.withAlpha(217), // 0.85 opacity
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _reload,
                                  icon: Icon(
                                    Icons.refresh_rounded,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 1.7,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            children: [
                              _EnhancedMetricCard(
                                label: 'Courses',
                                value: data.totalCourses,
                                icon: Icons.menu_book_rounded,
                                color: Colors.white,
                                onTap: _openCourses,
                              ),
                              _EnhancedMetricCard(
                                label: 'Students',
                                value: data.totalStudents,
                                icon: Icons.people_rounded,
                                color: Colors.white,
                                onTap: _openStudents,
                              ),
                              _EnhancedMetricCard(
                                label: 'Announcements',
                                value: data.announcementCount,
                                icon: Icons.campaign_rounded,
                                color: Colors.white,
                                onTap: () => _openAnnouncements(
                                  courses: data.assignedCourses,
                                  currentSemester: data.currentSemester,
                                ),
                              ),
                              _EnhancedMetricCard(
                                label: 'Events',
                                value: data.events.length,
                                icon: Icons.event_note_rounded,
                                color: Colors.white,
                                onTap: _openEvents,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Section Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withValues(alpha: 0.1),
                              primaryColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.dashboard_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quick Actions',
                                    style: textTheme.titleLarge?.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Manage your academic activities',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: primaryColor.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Enhanced Quick Actions Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.4,
                        children: [
                          _EnhancedQuickActionTile(
                            icon: Icons.menu_book_rounded,
                            title: 'My Courses',
                            subtitle: 'View assigned courses',
                            color: primaryColor,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TeacherCoursesScreen(user: widget.user),
                              ),
                            ),
                          ),
                          _EnhancedQuickActionTile(
                            icon: Icons.calendar_view_week_rounded,
                            title: 'Timetable',
                            subtitle: 'Plan your week',
                            color: primaryColor,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TeacherTimetableScreen(
                                  teacherId: widget.user.userId,
                                  courses: data.assignedCourses,
                                ),
                              ),
                            ),
                          ),
                          _EnhancedQuickActionTile(
                            icon: Icons.person_rounded,
                            title: 'My Profile',
                            subtitle: 'Update your details',
                            color: primaryColor,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TeacherProfileScreen(user: widget.user),
                              ),
                            ),
                          ),
                          _EnhancedQuickActionTile(
                            icon: Icons.report_problem_rounded,
                            title: 'Report Issue',
                            subtitle: 'Send feedback',
                            color: primaryColor,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReportScreen(
                                  userId: widget.user.userId,
                                  userRole: 'lecturer',
                                  onSubmit: (data) =>
                                      const TeacherApiService().submitReport(data),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Today's schedule
                      _SectionHeader(
                        title: 'Today\'s Schedule',
                        icon: Icons.calendar_today_rounded,
                        color: primaryColor,
                        subtitle: _todayCourses(data.assignedCourses).isEmpty
                            ? 'No classes scheduled for today'
                            : '${_todayCourses(data.assignedCourses).length} class(es) today',
                        action: 'Full timetable',
                        onAction: () => _openTimetable(data.assignedCourses),
                      ),
                      const SizedBox(height: 16),
                      if (_todayCourses(data.assignedCourses).isEmpty)
                        _EnhancedEmptyCard(
                          title: 'No classes today',
                          subtitle: 'Enjoy your free time or prepare for upcoming lectures.',
                          icon: Icons.free_breakfast_rounded,
                          color: primaryColor,
                        )
                      else
                        _EnhancedCard(
                          child: Column(
                            children: _todayCourses(data.assignedCourses)
                                .take(4)
                                .toList()
                                .asMap()
                                .entries
                                .map(
                              (entry) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Icon(Icons.school_rounded, color: primaryColor, size: 22),
                                ),
                                title: Text(
                                  '${entry.value.courseCode} • ${entry.value.courseName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 14, color: primaryColor.withValues(alpha: 0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        entry.value.schedule,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).textTheme.bodySmall?.color,
                                        ),
                                      ),
                                      if (entry.value.roomNumber.trim().isNotEmpty) ...[
                                        const SizedBox(width: 12),
                                        Icon(Icons.location_on_rounded, size: 14, color: primaryColor.withValues(alpha: 0.7)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Room ${entry.value.roomNumber}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                trailing: Icon(Icons.chevron_right_rounded, color: primaryColor.withValues(alpha: 0.3)),
                                onTap: () => _openTimetable(data.assignedCourses),
                              ),
                            )
                                .toList(),
                          ),
                        ),

                      const SizedBox(height: 28),

                      // Enhanced Announcements Section
                      _SectionHeader(
                        title: 'Announcements',
                        icon: Icons.campaign_rounded,
                        color: primaryColor,
                        subtitle: data.announcements.isEmpty 
                            ? 'No new announcements' 
                            : '${data.announcements.length} new announcement(s)',
                        action: '+ Add New',
                        onAction: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TeacherAnnouncementsScreen(
                                user: widget.user,
                                courses: data.assignedCourses,
                                currentSemester: data.currentSemester,
                              ),
                            ),
                          );
                          _reload();
                        },
                      ),
                      const SizedBox(height: 16),
                      if (data.announcements.isEmpty)
                        _EnhancedEmptyCard(
                          title: 'All caught up',
                          subtitle: 'No new announcements for you.',
                          icon: Icons.campaign_outlined,
                          color: primaryColor,
                        )
                      else
                        _EnhancedCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                onTap: () => _openAnnouncements(
                                  courses: data.assignedCourses,
                                  currentSemester: data.currentSemester,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.campaign_rounded,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  data.announcements.first.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    data.announcements.first.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              if (data.announcements.length > 1) const Divider(height: 1),
                              if (data.announcements.length > 1)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10, bottom: 4),
                                    child: TextButton(
                                      onPressed: () => _openAnnouncements(
                                        courses: data.assignedCourses,
                                        currentSemester: data.currentSemester,
                                      ),
                                      child: Text('View all (${data.announcements.length})'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 28),

                      // Enhanced Events Section
                      _SectionHeader(
                        title: 'Upcoming Events',
                        icon: Icons.event_rounded,
                        color: primaryColor,
                        subtitle: data.events.isEmpty 
                            ? 'No upcoming events' 
                            : '${data.events.length} upcoming event(s)',
                        action: '+ Add New',
                        onAction: _showCreateEventSheetOnHome, // Placeholder for new helper
                      ),
                      const SizedBox(height: 16),
                      if (data.events.isEmpty)
                        _EnhancedEmptyCard(
                          title: 'No upcoming events',
                          subtitle: 'Check back later for updates.',
                          icon: Icons.event_busy_rounded,
                          color: primaryColor,
                        )
                      else
                        _EnhancedCard(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.event_rounded,
                                color: primaryColor,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              data.events.first.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${data.events.first.eventDate} • ${data.events.first.startTime} • ${data.events.first.location ?? "N/A"}',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeekDay {
  final String label;
  final List<String> tokens;

  const _WeekDay({required this.label, required this.tokens});
}

// Custom painter for header pattern
class _HeaderPatternPainter extends CustomPainter {
  final Color color;
  
  _HeaderPatternPainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    
    // Draw decorative circles
    final path = Path();
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.2), radius: 60));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.1, size.height * 0.7), radius: 40));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.9, size.height * 0.8), radius: 30));
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Enhanced Metric Card
class _EnhancedMetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _EnhancedMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withAlpha(179), // 0.7 opacity
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onPrimary.withAlpha(217), // 0.85 opacity
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Quick Action Tile
class _EnhancedQuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _EnhancedQuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final border = isDark
        ? Theme.of(context).colorScheme.onSurface.withAlpha(20) // 0.08 opacity
        : Theme.of(context).colorScheme.onSurface.withAlpha(15); // 0.06 opacity

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Theme.of(context).shadowColor.withAlpha(15), // 0.06 opacity
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

// Enhanced Card Widget
class _EnhancedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _EnhancedCard({
    required this.child,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(15), // 0.06 opacity
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );
  }
}

// Enhanced Empty Card
class _EnhancedEmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _EnhancedEmptyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.1),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(10), // 0.04 opacity
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
