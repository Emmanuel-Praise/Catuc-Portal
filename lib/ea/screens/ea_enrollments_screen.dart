import 'package:flutter/material.dart';

import '../../services/offline_sync_service.dart';
import '../models/ea_enrollment.dart';
import '../models/ea_session.dart';
import '../services/ea_api_service.dart';

class EaEnrollmentsScreen extends StatefulWidget {
  final EaSession user;

  const EaEnrollmentsScreen({super.key, required this.user});

  @override
  State<EaEnrollmentsScreen> createState() => _EaEnrollmentsScreenState();
}

class _EaEnrollmentsScreenState extends State<EaEnrollmentsScreen> {
  List<EaEnrollment> _enrollments = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedYear = '2025/2026';
  String _selectedSemester = 'First';
  String _selectedStatus = 'all';

  final List<String> _years = ['2025/2026', '2024/2025', '2023/2024'];
  final List<String> _semesters = ['First', 'Second'];
  final List<String> _statuses = [
    'all',
    'enrolled',
    'pending',
    'dropped',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
  }

  Future<void> _loadEnrollments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final enrollments = await const EaApiService().fetchEnrollments(
        academicYear: _selectedYear,
        semester: _selectedSemester,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );

      // Sort enrollments by student name (ascending order)
      enrollments.sort(
        (a, b) =>
            a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()),
      );

      if (mounted) {
        setState(() {
          _enrollments = enrollments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showEnrollmentDetails(EaEnrollment enrollment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Enrollment Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _DetailRow(label: 'Student', value: enrollment.studentName),
              _DetailRow(
                label: 'Matric Number',
                value: enrollment.studentNumber,
              ),
              _DetailRow(label: 'Course', value: enrollment.courseName),
              _DetailRow(label: 'Course Code', value: enrollment.courseCode),
              _DetailRow(
                label: 'Academic Year',
                value: enrollment.academicYear,
              ),
              _DetailRow(label: 'Semester', value: enrollment.semester),
              _DetailRow(
                label: 'Section',
                value: enrollment.sectionName ?? 'N/A',
              ),
              _DetailRow(label: 'Status', value: enrollment.status),
              if (enrollment.enrollmentDate != null)
                _DetailRow(
                  label: 'Enrolled On',
                  value:
                      '${enrollment.enrollmentDate!.day}/${enrollment.enrollmentDate!.month}/${enrollment.enrollmentDate!.year}',
                ),
              const SizedBox(height: 24),
              if (enrollment.status != 'completed')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showUpdateStatusDialog(enrollment);
                    },
                    child: const Text('Update Status'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateStatusDialog(EaEnrollment enrollment) {
    String newStatus = enrollment.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Enrollment Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current status: ${enrollment.status}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: newStatus,
                decoration: const InputDecoration(labelText: 'New Status'),
                items: _statuses
                    .where((s) => s != 'all')
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.capitalize()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    newStatus = value!;
                  });
                },
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
                try {
                  await const EaApiService().updateEnrollmentStatus(
                    enrollmentId: enrollment.enrollmentId,
                    status: newStatus,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadEnrollments();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  await const OfflineSyncService().queueAction('ea_update_enrollment_status', {
                    'enrollment_id': enrollment.enrollmentId,
                    'status': newStatus,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Offline: Update queued')),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enrollments')),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withAlpha(12), // 0.05 opacity
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _years
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text(year),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedYear = value!;
                          });
                          _loadEnrollments();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSemester,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _semesters
                            .map(
                              (sem) => DropdownMenuItem(
                                value: sem,
                                child: Text(sem),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSemester = value!;
                          });
                          _loadEnrollments();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(
                            status == 'all'
                                ? 'All Statuses'
                                : status.capitalize(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                    _loadEnrollments();
                  },
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error.withAlpha(153), // 0.6 opacity
                        ),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadEnrollments,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _enrollments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No enrollments found',
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadEnrollments,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _enrollments.length,
                      itemBuilder: (context, index) {
                        final enrollment = _enrollments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => _showEnrollmentDetails(enrollment),
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(
                                enrollment.status,
                              ).withValues(alpha: 0.1),
                              child: Icon(
                                Icons.assignment,
                                color: _getStatusColor(enrollment.status),
                              ),
                            ),
                            title: Text(enrollment.studentName),
                            subtitle: Text(
                              '${enrollment.courseCode} - ${enrollment.studentNumber}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  enrollment.status,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                enrollment.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(enrollment.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEnrollStudentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Enroll Student'),
      ),
    );
  }

  void _showEnrollStudentDialog() {
    final studentIdController = TextEditingController();
    final courseIdController = TextEditingController();
    final yearController = TextEditingController(text: _selectedYear);
    final semesterController = TextEditingController(text: _selectedSemester);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enroll Student'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: studentIdController,
                  decoration: const InputDecoration(labelText: 'Student ID'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: courseIdController,
                  decoration: const InputDecoration(labelText: 'Course ID'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: semesterController,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final payload = {
                'student_id': studentIdController.text.trim(),
                'course_id': courseIdController.text.trim(),
                'academic_year': yearController.text.trim(),
                'semester': semesterController.text.trim(),
              };

              try {
                await const EaApiService().enrollStudent(
                  studentId: payload['student_id'] as String,
                  courseId: payload['course_id'] as String,
                  academicYear: payload['academic_year'] as String,
                  semester: payload['semester'] as String,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadEnrollments();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student enrolled successfully')),
                  );
                }
              } catch (e) {
                await const OfflineSyncService().queueAction('ea_enroll_student', payload);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Offline: Enrollment queued')),
                  );
                }
              }
            },
            child: const Text('Enroll'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'enrolled':
        return Theme.of(context).colorScheme.primary;
      case 'pending':
        return Theme.of(context).colorScheme.secondary;
      case 'completed':
        return Theme.of(context).colorScheme.tertiary;
      case 'dropped':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).disabledColor;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
