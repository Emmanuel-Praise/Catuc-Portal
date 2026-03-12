import 'package:flutter/material.dart';

import '../../theme/theme_service.dart';
import '../models/teacher_announcement_item.dart';
import '../models/teacher_home_data.dart';
import '../models/teacher_session.dart';
import '../services/teacher_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class TeacherAnnouncementsScreen extends StatefulWidget {
  final TeacherSession user;
  final List<AssignedCourse> courses;
  final String currentSemester;

  const TeacherAnnouncementsScreen({
    super.key,
    required this.user,
    required this.courses,
    required this.currentSemester,
  });

  @override
  State<TeacherAnnouncementsScreen> createState() =>
      _TeacherAnnouncementsScreenState();
}

class _TeacherAnnouncementsScreenState extends State<TeacherAnnouncementsScreen> {
  final TeacherApiService _api = const TeacherApiService();

  bool _isLoading = true;
  String? _error;
  List<TeacherAnnouncementItem> _items = const [];

  List<AssignedCourse> get _uniqueCurrentSemesterCourses {
    final targetSemester = widget.currentSemester.trim().toLowerCase();
    final filtered = widget.courses.where((c) {
      return c.courseId.trim().isNotEmpty &&
          c.semester.trim().toLowerCase() == targetSemester;
    });

    final byCourseId = <String, AssignedCourse>{};
    for (final course in filtered) {
      byCourseId.putIfAbsent(course.courseId.trim(), () => course);
    }

    final unique = byCourseId.values.toList();
    unique.sort(
      (a, b) => a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase()),
    );
    return unique;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _api.fetchTeacherAnnouncements(widget.user.userId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateSheet() async {
    final primaryColor = ThemeService().primaryColor;
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String scope = 'general';
    AssignedCourse? selectedCourse;
    bool isSaving = false;
    final courses = _uniqueCurrentSemesterCourses;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'New Announcement',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: const InputDecoration(
                    labelText: 'Audience',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'general',
                      child: Text('General (everyone)'),
                    ),
                    DropdownMenuItem(
                      value: 'course',
                      child: Text('Specific course students'),
                    ),
                  ],
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setSheetState(() {
                            scope = value;
                            if (scope != 'course') {
                              selectedCourse = null;
                            }
                          });
                        },
                ),
                if (scope == 'course') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AssignedCourse>(
                    initialValue: selectedCourse,
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      border: OutlineInputBorder(),
                    ),
                    items: courses
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.courseName),
                          ),
                        )
                        .toList(),
                    onChanged: isSaving
                        ? null
                        : (value) => setSheetState(() => selectedCourse = value),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            final content = contentController.text.trim();
                            if (title.isEmpty || content.isEmpty) return;
                            if (scope == 'course' && selectedCourse == null) return;

                            final messenger =
                                ScaffoldMessenger.of(this.context);
                            setSheetState(() => isSaving = true);
                            try {
                              await _api.createTeacherAnnouncement(
                                teacherId: widget.user.userId,
                                title: title,
                                content: content,
                                scope: scope,
                                courseId: selectedCourse?.courseId,
                              );
                              if (!mounted) return;
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              await _load();
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                    child: Text(isSaving ? 'Posting...' : 'Post Announcement'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _showCreateSheet,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New announcement',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        backgroundColor: primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppErrorWidget(error: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_items.isEmpty)
                        const Center(child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Text('No announcements yet.'),
                        ))
                      else
                        for (final a in _items)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryColor.withValues(alpha: 0.1),
                                child: Icon(
                                  a.scope == 'course'
                                      ? Icons.groups_rounded
                                      : Icons.public_rounded,
                                  color: primaryColor,
                                ),
                              ),
                              title: Text(
                                a.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                a.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                a.source == 'admin'
                                    ? 'Admin'
                                    : (a.scope == 'course' ? 'Course' : 'General'),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
