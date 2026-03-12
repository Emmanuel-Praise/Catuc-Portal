import 'package:flutter/material.dart';

import '../models/student_home_data.dart';
import '../models/student_session.dart';
import '../services/student_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class StudentAnnouncementsLoaderScreen extends StatefulWidget {
  final StudentSession user;

  const StudentAnnouncementsLoaderScreen({super.key, required this.user});

  @override
  State<StudentAnnouncementsLoaderScreen> createState() => _StudentAnnouncementsLoaderScreenState();
}

class _StudentAnnouncementsLoaderScreenState extends State<StudentAnnouncementsLoaderScreen> {
  late Future<List<HomeAnnouncement>> _future;

  @override
  void initState() {
    super.initState();
    _future = const StudentApiService().fetchAllAnnouncements(widget.user.userId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = const StudentApiService().fetchAllAnnouncements(widget.user.userId);
    });
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
                hintText: 'e.g. Announcements are not appearing...',
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
                  issueType: 'Student Announcements Error',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: FutureBuilder<List<HomeAnnouncement>>(
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
                  _future = const StudentApiService().fetchAllAnnouncements(widget.user.userId);
                });
              },
              onReport: () => _showReportDialog(snapshot.error),
            );
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('No announcements found.'));
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final a = rows[index];
              return Card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ListTile(
                  title: Text(a.title),
                  subtitle: Text(a.content),
                  trailing: Text(a.postedAt.isEmpty ? '' : a.postedAt.split(' ').first),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
