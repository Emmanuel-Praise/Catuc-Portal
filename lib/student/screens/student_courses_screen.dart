import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../models/student_course.dart';
import '../models/student_enrollment_data.dart';
import '../models/student_session.dart';
import '../services/student_api_service.dart';
import 'student_course_detail_screen.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class StudentCoursesScreen extends StatefulWidget {
  final StudentSession user;

  const StudentCoursesScreen({super.key, required this.user});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final StudentApiService _api = const StudentApiService();

  Future<EnrollmentData>? _future;
  String _semester = '2';
  String? _year;
  final Set<String> _selectedEnrolled = <String>{};
  bool _resolvedInitialSemester = false;
  bool _isSelectMode = false;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<EnrollmentData> _fetch() async {
    final data = await _api.fetchEnrollment(
      studentId: widget.user.userId,
      year: _year,
      semester: _semester,
    );

    if (!_resolvedInitialSemester &&
        _semester == '2' &&
        data.enrolled.isEmpty) {
      final fallback = await _api.fetchEnrollment(
        studentId: widget.user.userId,
        year: data.year.isNotEmpty ? data.year : _year,
        semester: '1',
      );
      _resolvedInitialSemester = true;
      if (fallback.enrolled.isNotEmpty) {
        _semester = '1';
        return fallback;
      }
      return data;
    }

    _resolvedInitialSemester = true;
    return data;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetch();
      _selectedEnrolled.clear();
      _resolvedInitialSemester = true;
    });
    final future = _future;
    if (future != null) {
      await future;
    }
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
                hintText: 'e.g. My courses aren\'t appearing correctly...',
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
                  issueType: 'Course Enrollment Error',
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

  Future<void> _deleteSelected(EnrollmentData data) async {
    if (_selectedEnrolled.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Courses'),
        content: Text('Are you sure you want to remove ${_selectedEnrolled.length} selected course(s) from your enrollment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ids = _selectedEnrolled.toList();
    try {
      for (final id in ids) {
        await _api.removeEnrollment(
          studentId: widget.user.userId,
          enrollmentId: id,
          year: data.year,
          semester: data.semester,
          level: data.level,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully removed ${ids.length} course(s).')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openAddCoursesSheet(EnrollmentData data) async {
    // Collect all unique courses from available and currently enrolled
    final allCourses = <String, EnrollmentCourse>{};
    for (var c in data.available) {
      allCourses[c.courseId] = c;
    }
    for (var c in data.enrolled) {
      allCourses[c.courseId] = c;
    }

    final sortedItems = allCourses.values.toList()
      ..sort((a, b) => a.courseCode.compareTo(b.courseCode));

    // Initially select currently enrolled courses
    final enrolledIds = data.enrolled.map((e) => e.courseId).toSet();
    final selected = Set<String>.from(enrolledIds);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            int currentCredits = 0;
            for (var id in selected) {
              final c = allCourses[id];
              if (c != null) currentCredits += c.credits;
            }

            final isOverLimit = currentCredits > 36;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Courses',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${_semesterLabel(data.semester)} • Session ${data.year}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sortedItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final c = sortedItems[index];
                          final isAlreadyEnrolled = enrolledIds.contains(c.courseId);
                          final isChecked = selected.contains(c.courseId);

                          return CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            value: isChecked,
                            activeColor: AppColors.blue,
                            checkboxShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            title: Text(
                              '${c.courseCode} - ${c.courseName}',
                              style: TextStyle(
                                fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Icon(Icons.stars_rounded, size: 12, color: AppColors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  '${c.credits} credit hours',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _displayLevel(c.level),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (isAlreadyEnrolled) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ENROLLED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(c.courseId);
                                } else {
                                  selected.remove(c.courseId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isOverLimit ? Colors.red.shade50 : AppColors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOverLimit ? Colors.red.shade200 : AppColors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOverLimit ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                            color: isOverLimit ? Colors.red : AppColors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Selection: $currentCredits Credits',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOverLimit ? Colors.red : AppColors.blue,
                                  ),
                                ),
                                if (isOverLimit)
                                  const Text(
                                    'Maximum limit is 36 credits. Please remove some courses.',
                                    style: TextStyle(fontSize: 12, color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: (isOverLimit || selected.isEmpty)
                            ? null
                            : () async {
                                final navigator = Navigator.of(context);
                                try {
                                  // Determine which ones to add and which to remove
                                  final toAdd = selected.difference(enrolledIds).toList();
                                  final toRemove = enrolledIds.difference(selected);

                                  if (toAdd.isNotEmpty) {
                                    await _api.enrollCourses(
                                      studentId: widget.user.userId,
                                      courseIds: toAdd,
                                      year: data.year,
                                      semester: data.semester,
                                      level: data.level,
                                    );
                                  }

                                  for (var courseId in toRemove) {
                                    final enrollment = data.enrolled.firstWhere((e) => e.courseId == courseId);
                                    await _api.removeEnrollment(
                                      studentId: widget.user.userId,
                                      enrollmentId: enrollment.enrollmentId,
                                      year: data.year,
                                      semester: data.semester,
                                      level: data.level,
                                    );
                                  }

                                  if (!mounted) return;
                                  navigator.pop();
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(content: Text('Enrollment updated successfully')),
                                  );
                                  await _reload();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Update Enrollment',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  StudentCourse _toStudentCourse(EnrollmentCourse c, EnrollmentData data) {
    return StudentCourse(
      courseId: c.courseId,
      code: c.courseCode,
      name: c.courseName,
      credits: c.credits,
      level: _normalizeLevelForDetails(c.level),
      semester: c.semester.isEmpty ? data.semester : c.semester,
      academicYear: c.academicYear.isEmpty ? data.year : c.academicYear,
      sectionCode: '',
      room: '',
      schedule: '',
    );
  }

  String _normalizeLevelForDetails(int level) {
    if (level <= 0) return '1';
    if (level >= 100) return '${(level / 100).round()}';
    return '$level';
  }

  String _displayLevel(int level) {
    if (level <= 0) return 'Level N/A';
    if (level >= 100) return 'Level ${level ~/ 100}';
    return 'Level $level';
  }

  String _semesterLabel(String semester) {
    return semester == '2' ? 'Second Semester' : 'First Semester';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
            return const Center(child: Text('No course data found.'));
          }

          _year ??= data.year;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
              children: [
                // Header Card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: AppColors.blueGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.school_rounded, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Academic Session',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data.year,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: '1',
                              label: Text('First Semester'),
                            ),
                            ButtonSegment(
                              value: '2',
                              label: Text('Second Semester'),
                            ),
                          ],
                          selected: {_semester},
                          onSelectionChanged: (value) {
                            if (value.isEmpty) return;
                            setState(() {
                              _semester = value.first;
                              _future = _fetch();
                              _selectedEnrolled.clear();
                              _isSelectMode = false;
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            selectedForegroundColor: AppColors.blue,
                            selectedBackgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Stats Card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.assessment_rounded, color: AppColors.blue, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _semesterLabel(data.semester),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Eligible up to ${_displayLevel(data.studentLevel)} - ${data.totalCredits} credits',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${data.enrolled.length}',
                            style: TextStyle(
                              color: AppColors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enrolled Courses',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (data.enrolled.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: _isSelectMode
                              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSelectMode = !_isSelectMode;
                            if (!_isSelectMode) {
                              _selectedEnrolled.clear();
                            }
                          });
                        },
                        icon: Icon(
                          _isSelectMode ? Icons.close_rounded : Icons.checklist_rounded,
                          size: 18,
                        ),
                        label: Text(_isSelectMode ? 'Cancel' : 'Select'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (data.enrolled.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(
                      child: Text('No courses for this semester\nUse the Add Course button to enroll.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...data.enrolled.map(
                    (c) => _buildCourseBox(
                      context: context,
                      c: c,
                      data: data,
                      isSelected: _selectedEnrolled.contains(c.enrollmentId),
                    ),
                  ),
                if (_isSelectMode && _selectedEnrolled.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => _deleteSelected(data),
                        icon: const Icon(Icons.delete_outline_rounded),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        label: Text(
                          'Delete Selected (${_selectedEnrolled.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FutureBuilder<EnrollmentData>(
        future: _future,
        builder: (context, snapshot) {
          final canOpen = snapshot.hasData;
          return FloatingActionButton.extended(
            onPressed: canOpen
                ? () => _openAddCoursesSheet(snapshot.data!)
                : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Course'),
          );
        },
      ),
    );
  }

  Widget _buildCourseBox({
    required BuildContext context,
    required EnrollmentCourse c,
    required EnrollmentData data,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSelectMode
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedEnrolled.remove(c.enrollmentId);
                    } else {
                      _selectedEnrolled.add(c.enrollmentId);
                    }
                  });
                }
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentCourseDetailScreen(
                        user: widget.user,
                        course: _toStudentCourse(c, data),
                      ),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  gradient: AppColors.blueGradient,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              c.courseCode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${c.credits} Credits',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _isSelectMode
                        ? Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: Colors.white,
                            size: 26,
                          )
                        : Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 16,
                          ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.blue.withValues(alpha: 0.05)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.blue
                        : Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.courseName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.school_rounded, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
                        const SizedBox(width: 6),
                        Text(
                          _displayLevel(c.level),
                          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.event_note_rounded, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
                        const SizedBox(width: 6),
                        Text(
                          _semesterLabel(c.semester.isEmpty ? data.semester : c.semester),
                          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (_isSelectMode) ...[
                      const SizedBox(height: 12),
                      Text(
                        isSelected ? 'SELECTED FOR REMOVAL' : 'TAP TO SELECT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.blue : Theme.of(context).textTheme.bodySmall?.color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
