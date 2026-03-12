import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';
import '../models/teacher_course.dart';
import '../models/teacher_session.dart';
import '../services/teacher_api_service.dart';
import 'teacher_course_detail_screen.dart';

class TeacherStudentsScreen extends StatefulWidget {
  final TeacherSession user;

  const TeacherStudentsScreen({super.key, required this.user});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  final TeacherApiService _api = const TeacherApiService();
  late Future<List<TeacherCourse>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _api.fetchAssignedCourses(widget.user.userId);
  }

  void _reload() {
    setState(() {
      _future = _api.fetchAssignedCourses(widget.user.userId);
    });
  }

  void _showReportDialog(dynamic error) {
    final controller = TextEditingController();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
                hintText: 'e.g. Student list is not opening...',
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
                  issueType: 'Teacher Students Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully. Thank you!')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to report: $e')),
                );
              }
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  List<TeacherCourse> _filter(List<TeacherCourse> courses) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return courses;
    return courses.where((c) {
      final hay = '${c.courseCode} ${c.courseName} ${c.sectionCode}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: AppColors.blueGradient)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<TeacherCourse>>(
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

          final courses = _filter(snapshot.data ?? const []);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search course (e.g. MTH101)',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 16),
                if (courses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: Theme.of(context).disabledColor),
                          const SizedBox(height: 10),
                          Text(
                            _query.trim().isEmpty ? 'No courses found' : 'No matches for "${_query.trim()}"',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Students are viewed per course.',
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...courses.map((course) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                          ),
                          child: Icon(Icons.school_rounded, color: primaryColor, size: 20),
                        ),
                        title: Text(
                          '${course.courseCode} • ${course.courseName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${course.studentCount} student(s) • ${course.sectionCode}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TeacherCourseDetailScreen(user: widget.user, course: course),
                            ),
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
