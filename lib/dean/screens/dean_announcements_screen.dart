import 'package:flutter/material.dart';
import '../models/dean_session.dart';
import '../services/dean_api_service.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanAnnouncementsScreen extends StatefulWidget {
  final DeanSession user;

  const DeanAnnouncementsScreen({super.key, required this.user});

  @override
  State<DeanAnnouncementsScreen> createState() => _DeanAnnouncementsScreenState();
}

class _DeanAnnouncementsScreenState extends State<DeanAnnouncementsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  void _loadAnnouncements() {
    setState(() {
      _future = const DeanApiService().fetchAnnouncements(widget.user.facultyId ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Announcements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnnouncements,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorWidget(error: snapshot.error, onRetry: _loadAnnouncements);
          }
          _announcements = snapshot.data ?? [];
          if (_announcements.isEmpty) {
            return const Center(child: Text('No announcements posted yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _announcements.length,
            itemBuilder: (context, index) {
              final ann = _announcements[index];
              return _buildAnnouncementCard(ann, primaryColor);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> ann, Color primaryColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (ann['title'] ?? 'No Title').toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteAnnouncement(ann['id'].toString()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (ann['content'] ?? 'No content').toString(),
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "By ${ann['author_name'] ?? 'Unknown'}",
                  style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatDate(ann['created_at']),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown Date';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _showCreateDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    List<String> selectedCourseIds = [];
    bool isGlobal = true;

    // Fetch courses for selection
    final courses = await const DeanApiService().fetchCourses(widget.user.facultyId ?? '');
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20, right: 20, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New Announcement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: contentController, maxLines: 4, decoration: const InputDecoration(labelText: 'Content')),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setModalState) => Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Global (All Faculty)'),
                    value: isGlobal,
                    onChanged: (val) => setModalState(() => isGlobal = val ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (!isGlobal) ...[
                     const Divider(),
                     const Text('Target Specific Courses:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                     const SizedBox(height: 8),
                     Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: courses.length,
                        itemBuilder: (context, index) {
                          final c = courses[index];
                          final isSelected = selectedCourseIds.contains(c.courseId);
                          return CheckboxListTile(
                            title: Text('${c.courseCode} - ${c.courseName}', style: const TextStyle(fontSize: 13)),
                            value: isSelected,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedCourseIds.add(c.courseId);
                                } else {
                                  selectedCourseIds.remove(c.courseId);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  if (titleController.text.isEmpty || contentController.text.isEmpty) return;
                  if (!isGlobal && selectedCourseIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one course or make it global.')));
                    return;
                  }
                  try {
                    await const DeanApiService().createAnnouncement({
                      'title': titleController.text,
                      'content': contentController.text,
                      'course_ids': isGlobal ? [] : selectedCourseIds,
                      'author_id': widget.user.userId,
                      'faculty_id': widget.user.facultyId,
                    });
                    Navigator.pop(context);
                    _loadAnnouncements();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Post Announcement'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteAnnouncement(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement?'),
        content: const Text('Are you sure you want to remove this announcement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await const DeanApiService().deleteAnnouncement(id);
      _loadAnnouncements();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
