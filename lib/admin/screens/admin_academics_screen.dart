import 'package:flutter/material.dart';

import '../models/admin_home_data.dart';
import '../models/admin_session.dart';
import '../services/admin_api_service.dart';
import 'widgets/admin_ui.dart';

import '../../services/report_service.dart';

class AdminAcademicsScreen extends StatefulWidget {
  final AdminSession user;

  const AdminAcademicsScreen({super.key, required this.user});

  @override
  State<AdminAcademicsScreen> createState() => _AdminAcademicsScreenState();
}

class _AdminAcademicsScreenState extends State<AdminAcademicsScreen> {
  late Future<AdminHomeData> _future;
  final _api = const AdminApiService();

  @override
  void initState() {
    super.initState();
    _future = _api.fetchHome(widget.user.userId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchHome(widget.user.userId);
    });
    await _future;
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
                hintText: 'e.g. The academics module is not loading correctly...',
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
                  role: 'admin',
                  issueType: 'Admin Academics Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully.')),
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

  void _showAddDialog() async {
    final metadata = await _api.fetchMetadata();
    if (!mounted) return;

    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final creditsController = TextEditingController(text: '3');
    String? selectedDept;
    int semester = 1;
    int level = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Course'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Course Code (e.g. ENG101)', hintText: 'ENG101')),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Course Name')),
                TextField(controller: creditsController, decoration: const InputDecoration(labelText: 'Credits'), keyboardType: TextInputType.number),
                DropdownButtonFormField<int>(
                  initialValue: semester,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  items: [1, 2].map((s) => DropdownMenuItem(value: s, child: Text('Semester $s'))).toList(),
                  onChanged: (v) => setDialogState(() => semester = v ?? 1),
                ),
                DropdownButtonFormField<int>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'Level'),
                  items: [1, 2, 3, 4, 5, 6, 7].map((l) => DropdownMenuItem(value: l, child: Text('Level ${l}00'))).toList(),
                  onChanged: (v) => setDialogState(() => level = v ?? 1),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedDept,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: (metadata['departments'] as List).map((d) => 
                    DropdownMenuItem(value: d['department_id'].toString(), child: Text(d['department_name']))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => selectedDept = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _api.postAction('ea_courses.php', {
                    'action': 'add',
                    'course_code': codeController.text,
                    'course_name': nameController.text,
                    'credits': int.tryParse(creditsController.text) ?? 3,
                    'semester': semester,
                    'level': level,
                    'department_id': selectedDept,
                  });
                  if (context.mounted) Navigator.pop(context);
                  _reload();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Add Course'),
            ),
          ],
        ),
      ),
    );
  }

  void _onDeleteCourse(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure you want to make this course inactive?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.postAction('ea_courses.php', {'action': 'delete', 'course_id': id});
        _reload();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminHomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        final data = snapshot.data;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('No academic data')));
        }

        final size = MediaQuery.of(context).size;
        final span = size.width > 600 ? 3 : 2;

        return AdminPageLayout(
          title: 'Academic Control',
          subtitle: 'Track courses, enrollments and recent academic activity.',
          icon: Icons.school_rounded,
          onRefresh: _reload,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: span,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                AdminMiniStatCard(
                  label: 'Total Courses',
                  value: '${data.stats.courses}',
                  icon: Icons.menu_book_rounded,
                  accent: Theme.of(context).colorScheme.primary,
                ),
                AdminMiniStatCard(
                  label: 'Enrollments',
                  value: '${data.stats.enrollments}',
                  icon: Icons.assignment_rounded,
                  accent: Theme.of(context).colorScheme.secondary,
                ),
                if (span > 2)
                AdminMiniStatCard(
                  label: 'Announcements',
                  value: '${data.stats.activeAnnouncements}',
                  icon: Icons.campaign_rounded,
                  accent: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Create New Course'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const AdminSectionTitle(
              title: 'Recent Courses',
              subtitle: 'Latest course records available in the system',
            ),
            const SizedBox(height: 12),
            if (data.recentCourses.isEmpty)
              const AdminEmptyCard(
                title: 'No courses found',
                subtitle: 'Courses will appear here when they are available.',
                icon: Icons.class_outlined,
              )
            else
              ...data.recentCourses.map(
                (course) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AdminListItemCard(
                    icon: Icons.class_rounded,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: '${course.courseCode} - ${course.courseName}',
                    subtitle: 'Academic year ${course.academicYear}  •  Semester ${course.semester}',
                    trailing: course.createdAt.length >= 10 ? course.createdAt.substring(0, 10) : course.createdAt,
                    onDelete: () => _onDeleteCourse(course.courseId),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
