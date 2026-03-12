import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../models/ea_session.dart';
import '../models/ea_course.dart';
import '../services/ea_api_service.dart';

class EaCoursesScreen extends StatefulWidget {
  final EaSession user;

  const EaCoursesScreen({super.key, required this.user});

  @override
  State<EaCoursesScreen> createState() => _EaCoursesScreenState();
}

class _EaCoursesScreenState extends State<EaCoursesScreen> {
  List<EaCourse> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterLevel = 'All';
  String _filterSemester = 'First';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final courses = await const EaApiService().fetchCourses(
        semester: _filterSemester == 'First' ? '1' : '2',
      );
      courses.sort((a, b) => a.courseCode.compareTo(b.courseCode));
      if (mounted) {
        setState(() {
          _courses = courses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<EaCourse> get _filteredCourses {
    final q = _searchController.text.toLowerCase();
    return _courses.where((c) {
      final levelMatch =
          _filterLevel == 'All' || c.level.toString() == _filterLevel;
      final searchMatch = q.isEmpty ||
          c.courseCode.toLowerCase().contains(q) ||
          c.courseName.toLowerCase().contains(q);
      return levelMatch && searchMatch;
    }).toList();
  }

  void _openCourseDetail(EaCourse course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CourseDetailScreen(course: course, semester: _filterSemester),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[600];
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Courses',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Faculty of Science – $_filterSemester Semester',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: subtitleColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    onPressed: _loadCourses,
                    icon: const Icon(Icons.refresh_rounded),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search courses...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128), // 0.5 opacity
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Semester filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Semester: ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  for (final sem in ['First', 'Second'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(
                        label: '$sem Sem',
                        selected: _filterSemester == sem,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () {
                          if (_filterSemester != sem) {
                            setState(() => _filterSemester = sem);
                            _loadCourses();
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Level filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Level: ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  for (final lv in ['All', '1', '2', '3', '4'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(
                        label: lv == 'All' ? 'All' : 'Level $lv',
                        selected: _filterLevel == lv,
                        color: Theme.of(context).colorScheme.tertiary,
                        onTap: () => setState(() => _filterLevel = lv),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Course list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _ErrorView(
                          message: _errorMessage!, onRetry: _loadCourses)
                      : _filteredCourses.isEmpty
                          ? const _EmptyView(
                              icon: Icons.menu_book_outlined,
                              message: 'No courses found')
                          : RefreshIndicator(
                              onRefresh: _loadCourses,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 100),
                                itemCount: _filteredCourses.length,
                                itemBuilder: (context, index) {
                                  final course = _filteredCourses[index];
                                  return _CourseCard(
                                    course: course,
                                    onTap: () => _openCourseDetail(course),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Course Card ────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final EaCourse course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border(
            left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(30), // 0.12 opacity
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  course.courseCode.length >= 3
                      ? course.courseCode.substring(0, 3)
                      : course.courseCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.courseCode,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    course.courseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniTag(
                          label: 'Level ${course.level}',
                          color: Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 6),
                      _MiniTag(
                          label: 'Sem ${course.semester}',
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      if (course.lecturerName != null &&
                          course.lecturerName!.isNotEmpty)
                        Expanded(
                          child: Text(
                            course.lecturerName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Theme.of(context).textTheme.bodySmall?.color
                                  : Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withAlpha(30), // 0.12 opacity
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${course.enrolledCount ?? 0}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.tertiary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('students',
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).textTheme.bodySmall?.color)),
                const SizedBox(height: 8),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Course Detail Screen: Students grouped by program ───────────────────────
class _CourseDetailScreen extends StatefulWidget {
  final EaCourse course;
  final String semester;

  const _CourseDetailScreen({required this.course, required this.semester});

  @override
  State<_CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<_CourseDetailScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final enrollments = await const EaApiService().fetchEnrollments(
        courseId: widget.course.courseId,
        semester: widget.semester == 'First' ? '1' : '2',
      );
      // Convert to maps with program grouping
      final stuList = enrollments
          .map((e) => {
                'name': e.studentName,
                'matricule': e.studentNumber,
                'program': e.programName ?? 'Unknown Program',
                'level': e.currentYear?.toString() ?? '',
                'status': e.status ?? '',
              })
          .toList();
      stuList.sort((a, b) {
        final p = (a['program'] as String).compareTo(b['program'] as String);
        if (p != 0) return p;
        return (a['name'] as String).compareTo(b['name'] as String);
      });
      if (mounted) {
        setState(() {
          _students = stuList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  // Group by program
  Map<String, List<Map<String, dynamic>>> get _byProgram {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in _students) {
      final p = s['program'] as String;
      map.putIfAbsent(p, () => []).add(s);
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App bar with course info
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.course.courseCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.course.courseName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.course.lecturerName?.isNotEmpty == true)
                          Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  color: Colors.white70, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                widget.course.lecturerName!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              // Download button
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: _isLoading || _students.isEmpty
                      ? null
                      : () => _showDownloadSnackbar(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Class List',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            ],
          ),

          // Stats bar
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? AppColors.darkSurface : Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Total Students',
                    value: '${_students.length}',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'Programs',
                    value: '${_byProgram.length}',
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'Semester',
                    value: widget.semester,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),

          // Students list
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : _errorMessage != null
                  ? SliverFillRemaining(
                      child: _ErrorView(
                          message: _errorMessage!, onRetry: _loadStudents))
                  : _students.isEmpty
                      ? const SliverFillRemaining(
                          child: _EmptyView(
                              icon: Icons.group_off_outlined,
                              message: 'No students enrolled in this course'))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final programs = _byProgram.entries.toList();
                              if (index >= programs.length) {
                                return const SizedBox.shrink();
                              }
                              final entry = programs[index];
                              return _ProgramGroup(
                                programName: entry.key,
                                students: entry.value,
                                startSerial: _students.indexOf(entry.value.first) + 1,
                              );
                            },
                            childCount: _byProgram.length,
                          ),
                        ),
        ],
      ),
    );
  }

  void _showDownloadSnackbar() async {
    try {
      await const EaApiService().downloadClassList(widget.course.courseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Class list downloaded successfully'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download initiated for ${widget.course.courseCode}'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ));
      }
    }
  }
}

// ─── Program Group ───────────────────────────────────────────────────────────
class _ProgramGroup extends StatelessWidget {
  final String programName;
  final List<Map<String, dynamic>> students;
  final int startSerial;

  const _ProgramGroup({
    required this.programName,
    required this.students,
    required this.startSerial,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Program header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    programName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${students.length} ${students.length == 1 ? "student" : "students"}',
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
          const SizedBox(height: 6),

          // Students in this program
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: isDark ? Colors.white12 : Colors.grey.shade100,
              ),
              itemBuilder: (context, i) {
                final stu = students[i];
                final serial = startSerial + i;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.primary.withAlpha(25), // 0.1 opacity
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$serial',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stu['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            Text(
                              '${stu["matricule"]}  •  Level ${stu["level"]}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Reusable helpers ─────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 14),
            Text('Failed to load data',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
        ],
      ),
    );
  }
}
