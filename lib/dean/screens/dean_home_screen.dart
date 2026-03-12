import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_service.dart';
import '../models/dean_home_data.dart';
import '../models/dean_enrollment_breakdown.dart';
import '../models/dean_session.dart';
import '../services/dean_api_service.dart';
import 'dean_announcements_screen.dart';
import 'dean_lecturer_assignment_screen.dart';
import 'dean_enrollment_screen.dart';
import 'dean_student_course_overview_screen.dart';
import 'dean_staff_screen.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanHomeScreen extends StatefulWidget {
  final DeanSession user;

  const DeanHomeScreen({super.key, required this.user});

  @override
  State<DeanHomeScreen> createState() => _DeanHomeScreenState();
}

class _DeanHomeScreenState extends State<DeanHomeScreen>
    with SingleTickerProviderStateMixin {
  late Future<DeanHomeData> _future;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _future = _fetchData();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<DeanHomeData> _fetchData() {
    return const DeanApiService().fetchHomeData(widget.user.facultyId ?? '');
  }

  Future<void> _reload() async {
    try {
      setState(() {
        _future = _fetchData();
      });
      await _future;
    } catch (e) {
      debugPrint('Error reloading dean home data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData get _greetingIcon {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_cloudy_rounded;
    return Icons.nightlight_round;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = ThemeService().primaryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: FutureBuilder<DeanHomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your dashboard…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return AppErrorWidget(
                error: snapshot.error,
                onRetry: _reload,
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return AppErrorWidget(
                message: 'No data available. Please try again.',
                onRetry: _reload,
              );
            }

            // Start animation once data loads
            if (!_animController.isCompleted) {
              _animController.forward();
            }

            return RefreshIndicator(
              onRefresh: _reload,
              color: primaryColor,
              backgroundColor: theme.colorScheme.surface,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // ── Gradient Header ──────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildGradientHeader(context, data, primaryColor),
                    ),

                    // ── Content ──────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Quick Actions
                          _buildSectionTitle(
                            context,
                            'Quick Actions',
                            Icons.bolt_rounded,
                            AppColors.orange,
                          ),
                          const SizedBox(height: 12),
                          _buildQuickActions(primaryColor),

                          const SizedBox(height: 28),

                          // Announcements Button
                          _buildAnnouncementsBanner(primaryColor),

                          const SizedBox(height: 28),

                          // Enrollment Breakdown
                          _buildSectionTitle(
                            context,
                            'Enrollment Breakdown',
                            Icons.donut_large_rounded,
                            AppColors.purple,
                            trailing: data.enrollmentBreakdown.isNotEmpty
                                ? _ViewAllButton(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DeanStudentCourseOverviewScreen(
                                                user: widget.user),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          if (data.enrollmentBreakdown.isEmpty)
                            _EmptyStateCard(
                              icon: Icons.donut_large_rounded,
                              title: 'No enrollment data',
                              subtitle:
                                  'Enrollment breakdown will appear here.',
                              accentColor: AppColors.purple,
                            )
                          else
                            _buildBreakdownCard(
                                data.enrollmentBreakdown, primaryColor),

                          const SizedBox(height: 28),

                          // Recent Activities
                          _buildSectionTitle(
                            context,
                            'Recent Activities',
                            Icons.history_rounded,
                            AppColors.info,
                          ),
                          const SizedBox(height: 12),
                          if (data.recentActivities.isEmpty)
                            _EmptyStateCard(
                              icon: Icons.history_rounded,
                              title: 'No recent activities',
                              subtitle:
                                  'Activity feed will update as things happen.',
                              accentColor: AppColors.info,
                            )
                          else
                            ...data.recentActivities
                                .take(10)
                                .map((a) => _buildActivityCard(a, primaryColor)),

                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Gradient Header with Greeting + Stats Grid ───────────────────────
  Widget _buildGradientHeader(
    BuildContext context,
    DeanHomeData data,
    Color primaryColor,
  ) {
    final primaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor,
        primaryColor.withValues(alpha: 0.8),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _HeaderPatternPainter(primaryColor),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 16,
            20,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting Row ─────────────────────────────────
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.user.firstName.isNotEmpty
                            ? widget.user.firstName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Greeting text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _greetingIcon,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _greeting,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.user.firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: IconButton(
                      onPressed: _reload,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Subtitle
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Dean • Faculty Dashboard',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // ── Stats 2×2 Grid ───────────────────────────────
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.0,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _HeaderStatCard(
                    label: 'Students',
                    value: data.totalStudents,
                    icon: Icons.people_rounded,
                  ),
                  _HeaderStatCard(
                    label: 'Staff',
                    value: data.totalStaff,
                    icon: Icons.work_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeanStaffScreen(user: widget.user),
                      ),
                    ),
                  ),
                  _HeaderStatCard(
                    label: 'Courses',
                    value: data.totalCourses,
                    icon: Icons.menu_book_rounded,
                  ),
                  _HeaderStatCard(
                    label: 'Enrollments',
                    value: data.totalEnrollments,
                    icon: Icons.assignment_ind_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────
  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    Color color, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  // ── Quick Actions Grid ────────────────────────────────────────────────
  Widget _buildQuickActions(Color primaryColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _QuickActionCard(
          icon: Icons.people_rounded,
          title: 'Staff Assignment',
          subtitle: 'Assign lecturers',
          color: primaryColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DeanLecturerAssignmentScreen(user: widget.user),
            ),
          ),
        ),
        _QuickActionCard(
          icon: Icons.how_to_reg_rounded,
          title: 'Enrollments',
          subtitle: 'Manage enrollment',
          color: primaryColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeanEnrollmentScreen(user: widget.user),
            ),
          ),
        ),
        _QuickActionCard(
          icon: Icons.list_alt_rounded,
          title: 'Student Overview',
          subtitle: 'Course overview',
          color: primaryColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DeanStudentCourseOverviewScreen(user: widget.user),
            ),
          ),
        ),
        _QuickActionCard(
          icon: Icons.campaign_rounded,
          title: 'Announcements',
          subtitle: 'Faculty news',
          color: primaryColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DeanAnnouncementsScreen(user: widget.user),
            ),
          ),
        ),
        _QuickActionCard(
          icon: Icons.groups_rounded,
          title: 'Staff List',
          subtitle: 'View all staff',
          color: primaryColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeanStaffScreen(user: widget.user),
            ),
          ),
        ),
      ],
    );
  }

  // ── Announcements Banner ──────────────────────────────────────────────
  Widget _buildAnnouncementsBanner(Color primaryColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.1),
            primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeanAnnouncementsScreen(user: widget.user),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.campaign_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Faculty Announcements',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        'Post news and updates to your faculty',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Enrollment Breakdown Card ────────────────────────────────────────
  Widget _buildBreakdownCard(
    List<DeanEnrollmentBreakdown> breakdown,
    Color primaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: breakdown.take(5).map((b) {
          final isLast = breakdown.indexOf(b) ==
              (breakdown.length > 5 ? 4 : breakdown.length - 1);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.school_rounded,
                      color: primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.courseCode,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(b.courseName,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${b.studentCount}',
                    style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Activity Card ────────────────────────────────────────────────────
  Widget _buildActivityCard(DeanActivity activity, Color primaryColor) {
    IconData icon;
    Color color;
    switch (activity.type) {
      case 'enrollment':
        icon = Icons.person_add_rounded;
        color = Colors.blue;
        break;
      case 'course':
        icon = Icons.add_box_rounded;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications_rounded;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          activity.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            activity.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 13,
            ),
          ),
        ),
        trailing: Text(
          _formatDate(activity.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) return '${diff.inMinutes}m ago';
        return '${diff.inHours}h ago';
      }
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Header Stat Card (inside gradient header) — matches student/teacher pattern
// ═══════════════════════════════════════════════════════════════════════════════

class _HeaderStatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Quick Action Card
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? color.withValues(alpha: 0.08)
          : color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// View All Button
// ═══════════════════════════════════════════════════════════════════════════════

class _ViewAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View All',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Empty State Card
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark
            ? accentColor.withValues(alpha: 0.06)
            : accentColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Header Pattern Painter — decorative circles on header background
// ═══════════════════════════════════════════════════════════════════════════════

class _HeaderPatternPainter extends CustomPainter {
  final Color color;
  _HeaderPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.15),
      size.width * 0.35,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.85),
      size.width * 0.2,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.75),
      size.width * 0.15,
      paint..color = Colors.white.withValues(alpha: 0.03),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
