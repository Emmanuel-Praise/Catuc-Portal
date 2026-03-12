import 'package:flutter/material.dart';

import '../models/student_course.dart';
import '../models/student_enrollment_data.dart';
import '../models/student_session.dart';
import '../services/student_api_service.dart';
import 'student_course_detail_screen.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class StudentEnrollmentScreen extends StatefulWidget {
  final StudentSession user;

  const StudentEnrollmentScreen({super.key, required this.user});

  @override
  State<StudentEnrollmentScreen> createState() => _StudentEnrollmentScreenState();
}

class _StudentEnrollmentScreenState extends State<StudentEnrollmentScreen> {
  late Future<EnrollmentData> _future;
  final Set<String> _selectedCourseIds = {};

  bool _isSelectMode = false;

  @override
  void initState() {
    super.initState();
    _future = const StudentApiService().fetchEnrollment(studentId: widget.user.userId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = const StudentApiService().fetchEnrollment(studentId: widget.user.userId);
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
                hintText: 'e.g. Courses for my level are not showing...',
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
                  issueType: 'Student Enrollment Error',
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

  Future<void> _enroll(EnrollmentData data) async {
    if (_selectedCourseIds.isEmpty) return;
    try {
      final msg = await const StudentApiService().enrollCourses(
        studentId: widget.user.userId,
        courseIds: _selectedCourseIds.toList(),
        year: data.year,
        semester: data.semester,
        level: data.level,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _selectedCourseIds.clear();
      setState(() => _isSelectMode = false);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _remove(EnrollmentData data, String enrollmentId) async {
    try {
      final msg = await const StudentApiService().removeEnrollment(
        studentId: widget.user.userId,
        enrollmentId: enrollmentId,
        year: data.year,
        semester: data.semester,
        level: data.level,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Enrollment', style: TextStyle(fontSize: 20)),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isSelectMode = !_isSelectMode;
                if (!_isSelectMode) _selectedCourseIds.clear();
              });
            },
            icon: Icon(
              _isSelectMode ? Icons.close_rounded : Icons.checklist_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              _isSelectMode ? 'Cancel' : 'Select',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<EnrollmentData>(
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
            return const Center(child: Text('No enrollment data'));
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DetailChip(icon: Icons.calendar_today, label: data.year),
                        _DetailChip(icon: Icons.auto_stories_rounded, label: 'Sem ${data.semester}'),
                        _DetailChip(icon: Icons.trending_up_rounded, label: 'Lvl ${data.level}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (data.available.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Available Courses', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    if (_isSelectMode && _selectedCourseIds.isNotEmpty)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _enroll(data),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text('Enroll (${_selectedCourseIds.length})'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...data.available.map((c) => _buildCourseBox(
                  context: context,
                  courseCode: c.courseCode,
                  courseName: c.courseName,
                  credits: c.credits,
                  isSelected: _selectedCourseIds.contains(c.courseId),
                  isSelectMode: _isSelectMode,
                  onTap: _isSelectMode
                      ? () {
                          setState(() {
                            if (_selectedCourseIds.contains(c.courseId)) {
                              _selectedCourseIds.remove(c.courseId);
                            } else {
                              _selectedCourseIds.add(c.courseId);
                            }
                          });
                        }
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentCourseDetailScreen(
                                user: widget.user,
                                course: StudentCourse(
                                  courseId: c.courseId,
                                  code: c.courseCode,
                                  name: c.courseName,
                                  credits: c.credits,
                                  level: c.level.toString(),
                                  semester: c.semester.isEmpty ? data.semester : c.semester,
                                  academicYear: c.academicYear.isEmpty ? data.year : c.academicYear,
                                  sectionCode: '',
                                  room: '',
                                  schedule: '',
                                ),
                              ),
                            ),
                          );
                        },
                )),
              ],

              const SizedBox(height: 24),

              if (data.enrolled.isNotEmpty) ...[
                Text('Enrolled Courses', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...data.enrolled.map((c) => _buildCourseBox(
                  context: context,
                  courseCode: c.courseCode,
                  courseName: c.courseName,
                  credits: c.credits,
                  isSelectMode: _isSelectMode,
                  onRemove: _isSelectMode ? () => _remove(data, c.enrollmentId) : null,
                  onTap: _isSelectMode ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentCourseDetailScreen(
                          user: widget.user,
                          course: StudentCourse(
                            courseId: c.courseId,
                            code: c.courseCode,
                            name: c.courseName,
                            credits: c.credits,
                            level: c.level.toString(),
                            semester: c.semester.isEmpty ? data.semester : c.semester,
                            academicYear: c.academicYear.isEmpty ? data.year : c.academicYear,
                            sectionCode: '',
                            room: '',
                            schedule: '',
                          ),
                        ),
                      ),
                    );
                  },
                  isEnrolledBox: true,
                )),
              ],

              if (data.available.isEmpty && data.enrolled.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No courses found for this session.', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCourseBox({
    required BuildContext context,
    required String courseCode,
    required String courseName,
    required int credits,
    bool isSelected = false,
    bool isSelectMode = false,
    VoidCallback? onTap,
    VoidCallback? onRemove,
    bool isEnrolledBox = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isSelectMode && !isEnrolledBox) ...[
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
                  size: 24,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            courseCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$credits Credits',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      courseName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ],
                ),
              ),
              if (isSelectMode && isEnrolledBox) ...[
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: onRemove,
                  tooltip: 'Remove Course',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
