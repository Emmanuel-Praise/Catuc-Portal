import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/student_notes_data.dart';
import '../models/student_session.dart';
import '../services/student_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class StudentNotesScreen extends StatefulWidget {
  final StudentSession user;

  const StudentNotesScreen({super.key, required this.user});

  @override
  State<StudentNotesScreen> createState() => _StudentNotesScreenState();
}

class _StudentNotesScreenState extends State<StudentNotesScreen> {
  late Future<List<NoteCourse>> _future;

  @override
  void initState() {
    super.initState();
    _future = const StudentApiService().fetchNoteCourses(widget.user.userId);
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
                hintText: 'e.g. Courses are missing from notes list...',
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
                  role: 'student',
                  issueType: 'Student Notes Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully. Thank you!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
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

  void _reload() {
    setState(() {
      _future = const StudentApiService().fetchNoteCourses(widget.user.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course Notes')),
      body: FutureBuilder<List<NoteCourse>>(
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
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(
              child: Text('No notes available for your courses.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final c = courses[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.menu_book_rounded),
                  ),
                  title: Text('${c.courseCode} - ${c.courseName}'),
                  subtitle: Text('${c.materialCount} materials'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentNoteMaterialsScreen(
                          user: widget.user,
                          course: c,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StudentNoteMaterialsScreen extends StatefulWidget {
  final StudentSession user;
  final NoteCourse course;

  const StudentNoteMaterialsScreen({
    super.key,
    required this.user,
    required this.course,
  });

  @override
  State<StudentNoteMaterialsScreen> createState() =>
      _StudentNoteMaterialsScreenState();
}

class _StudentNoteMaterialsScreenState
    extends State<StudentNoteMaterialsScreen> {
  late Future<List<NoteMaterial>> _future;

  @override
  void initState() {
    super.initState();
    _future = const StudentApiService().fetchCourseMaterials(
      studentId: widget.user.userId,
      courseId: widget.course.courseId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.course.courseCode)),
      body: FutureBuilder<List<NoteMaterial>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorWidget(
              error: snapshot.error,
              onRetry: () {
                setState(() {
                  _future = const StudentApiService().fetchCourseMaterials(
                    studentId: widget.user.userId,
                    courseId: widget.course.courseId,
                  );
                });
              },
              onReport: () {
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
                            hintText: 'e.g. Materials are not loading for this course...',
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
                              role: 'student',
                              issueType: 'Student Note Materials Error',
                              description: controller.text.trim(),
                              additionalData: {
                                'courseId': widget.course.courseId,
                                'error': snapshot.error.toString(),
                              },
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Issue reported successfully. Thank you!')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to report: $e')),
                            );
                          }
                        },
                        child: const Text('Submit Report'),
                      ),
                    ],
                  ),
                );
              },
            );
          }
          final materials = snapshot.data ?? [];
          if (materials.isEmpty) {
            return const Center(child: Text('No materials uploaded yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final m = materials[index];
              final icon = switch (m.materialType.toLowerCase()) {
                'video' => Icons.play_circle_outline_rounded,
                'link' => Icons.link_rounded,
                _ => Icons.description_rounded,
              };
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(icon)),
                  title: Text(m.title.isEmpty ? m.fileName : m.title),
                  subtitle: Text(
                    m.description.isEmpty ? m.uploadDate : m.description,
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openMaterial(m.downloadUrl),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openMaterial(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid material link')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open material')));
    }
  }
}
