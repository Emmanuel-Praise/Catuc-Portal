import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../models/ea_home_data.dart';
import '../models/ea_session.dart';
import '../services/ea_api_service.dart';

class EaHomeScreen extends StatefulWidget {
  final EaSession user;

  const EaHomeScreen({super.key, required this.user});

  @override
  State<EaHomeScreen> createState() => _EaHomeScreenState();
}

class _EaHomeScreenState extends State<EaHomeScreen> {
  EaHomeData? _homeData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await const EaApiService().fetchHome(widget.user.userId);
      if (!mounted) return;
      setState(() {
        _homeData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _homeData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _HeroCard(
                  fullName: widget.user.fullName,
                  academicYear: _homeData?.currentYear ?? 'Academic Year',
                  semester: _homeData?.currentSemester ?? 'Semester',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      _InfoBanner(message: _errorMessage!),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      'Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.18,
                      children: [
                        _StatCard(
                          label: 'Students',
                          value: '${_homeData?.totalStudents ?? 0}',
                          icon: Icons.people_rounded,
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        _StatCard(
                          label: 'Staff',
                          value: '${_homeData?.totalStaff ?? 0}',
                          icon: Icons.badge_rounded,
                          accent: Theme.of(context).colorScheme.secondary,
                        ),
                        _StatCard(
                          label: 'Courses',
                          value: '${_homeData?.totalCourses ?? 0}',
                          icon: Icons.menu_book_rounded,
                          accent: Theme.of(context).colorScheme.tertiary,
                        ),
                        _StatCard(
                          label: 'Enrollments',
                          value: '${_homeData?.totalEnrollments ?? 0}',
                          icon: Icons.assignment_rounded,
                          accent: Theme.of(context).colorScheme.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if ((_homeData?.recentStudents.isNotEmpty ?? false)) ...[
                      _SectionHeader(
                        title: 'Recent Students',
                        subtitle: 'Latest student records',
                      ),
                      const SizedBox(height: 12),
                      ..._homeData!.recentStudents.map(
                        (student) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ListCard(
                            icon: Icons.person_rounded,
                            iconColor: Theme.of(context).colorScheme.primary,
                            title: student.fullName.trim().isEmpty
                                ? 'Unnamed Student'
                                : student.fullName,
                            subtitle:
                                '${student.studentNumber}  •  ${student.programName}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if ((_homeData?.recentCourses.isNotEmpty ?? false)) ...[
                      _SectionHeader(
                        title: 'Recent Courses',
                        subtitle: 'Latest course records',
                      ),
                      const SizedBox(height: 12),
                      ..._homeData!.recentCourses.map(
                        (course) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ListCard(
                            icon: Icons.menu_book_rounded,
                            iconColor: Theme.of(context).colorScheme.secondary,
                            title: '${course.courseCode} - ${course.courseName}',
                            subtitle: course.lecturerName.isEmpty
                                ? 'Lecturer not assigned'
                                : course.lecturerName,
                          ),
                        ),
                      ),
                    ],
                    if ((_homeData?.recentStudents.isEmpty ?? true) &&
                        (_homeData?.recentCourses.isEmpty ?? true))
                      const _EmptyCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String fullName;
  final String academicYear;
  final String semester;

  const _HeroCard({
    required this.fullName,
    required this.academicYear,
    required this.semester,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exams & Records',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary.withAlpha(51), // 0.2 opacity
                    borderRadius: BorderRadius.circular(16),
                  ),
                    child: Text(
                      '$academicYear • $semester',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.analytics_rounded,
              color: Theme.of(context).colorScheme.onSecondary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(15), // 0.06 opacity
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Theme.of(context).textTheme.bodySmall?.color
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _ListCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(15), // 0.06 opacity
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Theme.of(context).textTheme.bodySmall?.color
                        : Theme.of(context).textTheme.bodySmall?.color,
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

class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.onError),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(15), // 0.06 opacity
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.inbox_rounded, color: Theme.of(context).colorScheme.onPrimary),
          ),
          const SizedBox(height: 14),
          Text(
            'No recent activity',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Students and course updates will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
