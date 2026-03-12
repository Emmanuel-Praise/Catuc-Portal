import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../models/student_course.dart';
import '../models/student_course_detail_data.dart';
import '../models/student_notes_data.dart';
import '../models/student_session.dart';
import '../services/student_api_service.dart';
import 'student_notes_screen.dart';

class StudentCourseDetailScreen extends StatefulWidget {
  final StudentSession user;
  final StudentCourse course;

  const StudentCourseDetailScreen({
    super.key,
    required this.user,
    required this.course,
  });

  @override
  State<StudentCourseDetailScreen> createState() =>
      _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState extends State<StudentCourseDetailScreen> {
  late Future<StudentCourseDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = const StudentApiService().fetchCourseDetail(
      studentId: widget.user.userId,
      courseId: widget.course.courseId,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = const StudentApiService().fetchCourseDetail(
        studentId: widget.user.userId,
        courseId: widget.course.courseId,
      );
    });
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature feature coming soon!')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: FutureBuilder<StudentCourseDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No course detail available'));
          }

          final c = data.course;
          return RefreshIndicator(
            onRefresh: _reload,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 96,
                  pinned: true,
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.courseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.courseCode,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionCard(
                          title: 'Course Information',
                          child: Column(
                            children: [
                              _InfoRow(
                                icon: Icons.person_outline_rounded,
                                label: 'Instructor',
                                value: c.instructor.isEmpty
                                    ? 'TBD'
                                    : c.instructor,
                              ),
                              _InfoRow(
                                icon: Icons.schedule_outlined,
                                label: 'Hours',
                                value: c.schedule.isEmpty ? 'TBD' : c.schedule,
                              ),
                              _InfoRow(
                                icon: Icons.school_outlined,
                                label: 'Level',
                                value: c.level.isEmpty ? 'N/A' : c.level,
                              ),
                              _InfoRow(
                                icon: Icons.credit_card_rounded,
                                label: 'Credits',
                                value: '${c.credits} Credits',
                              ),
                              _InfoRow(
                                icon: Icons.calendar_month_rounded,
                                label: 'Semester',
                                value: c.semester,
                              ),
                              _InfoRow(
                                icon: Icons.date_range_rounded,
                                label: 'Session',
                                value: c.year,
                              ),
                              _InfoRow(
                                icon: Icons.meeting_room_rounded,
                                label: 'Room',
                                value: c.room.isEmpty ? 'TBD' : c.room,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount:
                              MediaQuery.of(context).size.width < 520 ? 2 : 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                          children: [
                            _ActionCard(
                              icon: Icons.calendar_today_rounded,
                              title: 'Attendance',
                              subtitle: 'Check attendance',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      _StudentAttendanceScreen(data: c),
                                ),
                              ),
                            ),
                            _ActionCard(
                              icon: Icons.assignment_outlined,
                              title: 'Assignments',
                              subtitle: 'View tasks',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _StudentAssignmentsScreen(
                                    assignments: data.assignments,
                                  ),
                                ),
                              ),
                            ),
                            _ActionCard(
                              icon: Icons.bar_chart_rounded,
                              title: 'CA Marks',
                              subtitle: 'Scores',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      _StudentCaMarksScreen(data: c),
                                ),
                              ),
                            ),
                            _ActionCard(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'Chat',
                              subtitle: 'Course chat',
                              onTap: () => _comingSoon('Chat'),
                            ),
                            _ActionCard(
                              icon: Icons.description_outlined,
                              title: 'Materials',
                              subtitle: '${c.materialsCount} available',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StudentNoteMaterialsScreen(
                                    user: widget.user,
                                    course: NoteCourse(
                                      courseId: c.courseId,
                                      courseCode: c.courseCode,
                                      courseName: c.courseName,
                                      materialCount: c.materialsCount,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _ActionCard(
                              icon: Icons.video_library_outlined,
                              title: 'Lectures',
                              subtitle: 'Recorded lectures',
                              onTap: () => _comingSoon('Lectures'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Additional Information',
                          child: Column(
                            children: [
                              _InfoRow(
                                icon: Icons.business_outlined,
                                label: 'Department',
                                value: c.department.isEmpty
                                    ? '-'
                                    : c.department,
                              ),
                              _InfoRow(
                                icon: Icons.account_balance_outlined,
                                label: 'Faculty',
                                value: c.faculty.isEmpty ? '-' : c.faculty,
                              ),
                              _InfoRow(
                                icon: Icons.email_outlined,
                                label: 'Teacher Email',
                                value: c.instructorEmail.isEmpty
                                    ? 'Not available'
                                    : c.instructorEmail,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'About This Course',
                          child: Text(
                            c.description.isEmpty
                                ? 'This course covers fundamental concepts and practical applications.'
                                : c.description,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardTheme.color,
          border: Border.all(color: AppColors.blue),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.blue,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceScreen extends StatelessWidget {
  final StudentCourseDetail data;

  const _StudentAttendanceScreen({required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Attendance Percentage'),
              trailing: Text('${data.attendancePercent}%'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Attendance Score'),
              trailing: Text(data.attendanceScore),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentAssignmentsScreen extends StatelessWidget {
  final List<StudentAssignment> assignments;

  const _StudentAssignmentsScreen({required this.assignments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      body: assignments.isEmpty
          ? const Center(child: Text('No assignments available.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final a = assignments[index];
                return Card(
                  child: ListTile(
                    title: Text(a.name),
                    subtitle: Text(
                      '${a.description.isEmpty ? 'No description' : a.description}\nDue: ${a.dueDate.isEmpty ? 'TBD' : a.dueDate}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      a.maxPoints.isEmpty ? '-' : '${a.maxPoints} pts',
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StudentCaMarksScreen extends StatelessWidget {
  final StudentCourseDetail data;

  const _StudentCaMarksScreen({required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CA Marks')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('CA Score'),
              trailing: Text(data.caScore),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Practicals Score'),
              trailing: Text(data.practicalsScore),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Exam Score'),
              trailing: Text(data.examScore),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Total Score'),
              trailing: Text(data.totalScore),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Grade'),
              trailing: Text(data.grade),
            ),
          ),
        ],
      ),
    );
  }
}
