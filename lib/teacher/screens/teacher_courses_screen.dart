import 'package:flutter/material.dart';

import '../../theme/theme_service.dart';
import '../models/teacher_course.dart';
import '../models/teacher_session.dart';
import '../services/teacher_api_service.dart';
import 'teacher_course_detail_screen.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class TeacherCoursesScreen extends StatefulWidget {
  final TeacherSession user;

  const TeacherCoursesScreen({super.key, required this.user});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<TeacherCourse> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _loadCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetchedCourses = await const TeacherApiService().fetchAssignedCourses(
        widget.user.userId,
      );

      String courseKey(TeacherCourse course) {
        final sectionId = course.sectionId.trim();
        if (sectionId.isNotEmpty) {
          return 'section:${sectionId.toLowerCase()}';
        }
        final sectionCode = course.sectionCode.trim();
        if (sectionCode.isNotEmpty) {
          return 'code:${sectionCode.toLowerCase()}';
        }
        final fallback =
            '${course.courseId}|${course.courseCode}|${course.academicYear}|${course.semester}|${course.schedule}|${course.roomNumber}';
        return 'fallback:${fallback.toLowerCase()}';
      }

      final byKey = <String, TeacherCourse>{};
      for (final c in fetchedCourses) {
        final key = courseKey(c);
        final existing = byKey[key];
        if (existing == null) {
          byKey[key] = c;
          continue;
        }
        if (c.studentCount > existing.studentCount) {
          byKey[key] = c;
        }
      }

      final courses = byKey.values.toList();

      courses.sort((a, b) {
        final semesterCompare = _semesterRank(
          a.semester,
        ).compareTo(_semesterRank(b.semester));
        if (semesterCompare != 0) {
          return semesterCompare;
        }
        return a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
                  role: 'lecturer',
                  issueType: 'Teacher Courses Error',
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

  int _semesterRank(String semester) {
    final value = semester.toLowerCase();
    if (value.contains('first')) {
      return 0;
    }
    if (value.contains('second')) {
      return 1;
    }
    return 2;
  }

  List<TeacherCourse> _semesterCourses(bool secondSemester) {
    return _courses.where((course) {
      final isSecond = course.semester.toLowerCase().contains('second');
      return secondSemester ? isSecond : !isSecond;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Courses'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: _loadCourses,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'First Semester'),
            Tab(text: 'Second Semester'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? AppErrorWidget(
              error: _errorMessage,
              onRetry: _loadCourses,
              onReport: () => _showReportDialog(_errorMessage),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _SemesterTabContent(
                  courses: _semesterCourses(false),
                  user: widget.user,
                  totalCourses: _courses.length,
                  onRefresh: _loadCourses,
                ),
                _SemesterTabContent(
                  courses: _semesterCourses(true),
                  user: widget.user,
                  totalCourses: _courses.length,
                  onRefresh: _loadCourses,
                ),
              ],
            ),
    );
  }
}

class _TopSummary extends StatelessWidget {
  final int totalCourses;

  const _TopSummary({required this.totalCourses});

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;
    final primaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor,
        primaryColor.withValues(alpha: 0.8),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Courses',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withAlpha(179), // 0.7 opacity
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalCourses',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withAlpha(51), // 0.2 opacity
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary.withAlpha(38), // 0.15 opacity
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Academic Year: 2024/2025',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterTabContent extends StatelessWidget {
  final List<TeacherCourse> courses;
  final TeacherSession user;
  final int totalCourses;
  final Future<void> Function() onRefresh;

  const _SemesterTabContent({
    required this.courses,
    required this.user,
    required this.totalCourses,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _TopSummary(totalCourses: totalCourses),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Courses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(15), // 0.06 opacity
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${courses.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (courses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(13), // 0.05 opacity
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('No courses in this semester.'),
            )
          else
            for (final course in courses)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CourseCard(course: course, user: user),
              ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final TeacherCourse course;
  final TeacherSession user;

  const _CourseCard({required this.course, required this.user});

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(10), // 0.04 opacity
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(13), // 0.05 opacity
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TeacherCourseDetailScreen(user: user, course: course),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.12),
                            primaryColor.withValues(alpha: 0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Icon(Icons.school_rounded, color: primaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.courseCode,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            course.courseName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded, 
                      size: 14,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CourseMeta(
                      icon: Icons.people_outline_rounded,
                      text: '${course.studentCount} Students',
                    ),
                    _CourseMeta(
                      icon: Icons.credit_score_outlined,
                      text: '${course.credits} Credits',
                    ),
                    _CourseMeta(
                      icon: Icons.layers_outlined,
                      text: course.courseLevel > 0
                          ? 'Level ${course.courseLevel}'
                          : 'Level N/A',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.business_rounded, 
                      size: 14, 
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        course.departmentName?.isNotEmpty == true
                            ? course.departmentName!
                            : 'Department not assigned',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded, 
                      size: 14, 
                      color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(153), // 0.6 opacity
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${course.academicYear} • ${course.semester} Semester',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(153), // 0.6 opacity
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CourseMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withAlpha(13), // 0.05 opacity
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
