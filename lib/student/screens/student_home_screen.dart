import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../models/student_home_data.dart';
import '../models/student_session.dart';
import '../services/student_api_service.dart';
import 'student_announcements_screen.dart';
import 'student_events_screen.dart';
import 'ai/widgets/ai_menu_overlay.dart';
import 'ai/brainstorm_screen.dart';
import 'ai/learn_screen.dart';
import 'ai/read_screen.dart';
import 'ai/code_assistant_screen.dart';
import 'ai/widgets/live_voice_assistant_box.dart';
import 'widgets/quick_actions.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';
import '../../shared/models/ai_user.dart';

class StudentHomeScreen extends StatefulWidget {
  final StudentSession user;

  const StudentHomeScreen({super.key, required this.user});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  late Future<StudentHomeData> _future;
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

  Future<StudentHomeData> _fetchData() {
    return const StudentApiService().fetchHome(widget.user.userId);
  }

  Future<void> _reload() async {
    try {
      setState(() {
        _future = _fetchData();
      });
      await _future;
    } catch (e) {
      debugPrint('Error reloading student home data: $e');
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

  DateTime? _parseEventDateTime(HomeEvent e) {
    final d = DateTime.tryParse(e.eventDate.trim());
    if (d == null) return null;

    final t = e.startTime.trim();
    if (t.isEmpty) return DateTime(d.year, d.month, d.day);

    final parts = t.split(':');
    if (parts.isEmpty) return DateTime(d.year, d.month, d.day);

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  List<HomeEvent> _sortedEvents(List<HomeEvent> events) {
    final list = [...events];
    list.sort((a, b) {
      final adt = _parseEventDateTime(a);
      final bdt = _parseEventDateTime(b);
      if (adt == null && bdt == null) return a.name.compareTo(b.name);
      if (adt == null) return 1;
      if (bdt == null) return -1;
      return adt.compareTo(bdt);
    });
    return list;
  }

  void _showAiMenu() {
    final aiUser = AiUser.fromStudentSession(widget.user);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AI Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return AiMenuOverlay(
          userData: {'matricule': widget.user.userId},
          onActionSelected: (action) {
            Widget screen;
            switch (action) {
              case 'brainstorm':
                screen =
                    BrainstormScreen(user: aiUser, dashboardData: const {});
                break;
              case 'learn':
                screen = LearnScreen(user: aiUser, dashboardData: const {});
                break;
              case 'read':
                screen = ReadScreen(user: aiUser, dashboardData: const {});
                break;
              case 'code':
                screen = CodeAssistantScreen(
                    user: aiUser, dashboardData: const {});
                break;
              case 'voice':
                _showVoiceAssistantSheet();
                return;
              default:
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Feature "$action" coming soon!')),
                  );
                }
                return;
            }
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => screen),
              );
            }
          },
        );
      },
    );
  }

  void _showVoiceAssistantSheet() {
    final aiUser = AiUser.fromStudentSession(widget.user);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LiveVoiceAssistantBox(
        user: aiUser,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showReportDialog(dynamic error) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Report an Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Please describe what happened so we can fix it.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'e.g. The page didn\'t load after I clicked...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await const ReportService().submitReport(
                  userId: widget.user.userId,
                  role: 'student',
                  issueType: 'UI Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Issue reported successfully. Thank you!')),
                );
              } catch (e) {
                if (!mounted) return;
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

  // ── Greeting based on time of day ─────────────────────────────────────
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
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppColors.blue;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        floatingActionButton: FutureBuilder<StudentHomeData>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            return _AiFab(
              onPressed: _showAiMenu,
              primaryColor: primary,
            );
          },
        ),
        body: FutureBuilder<StudentHomeData>(
          future: _future,
          builder: (context, snapshot) {
            // If we have data (from cache or previous fetch), show it immediately
            // This prevents flicker during "stale-while-revalidate" background fetches
            if (snapshot.hasData) {
              final data = snapshot.data!;
              final sortedEvents = _sortedEvents(data.events);

              // Start animation once data is available
              if (!_animController.isCompleted) {
                _animController.forward();
              }

              return RefreshIndicator(
                onRefresh: _reload,
                color: primary,
                backgroundColor: theme.colorScheme.surface,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // ── Blue Gradient Header with Stats ──────────────────
                      SliverToBoxAdapter(
                        child: _buildBlueHeader(
                            context, data, primary, isDark),
                      ),

                      // ── Content ──────────────────────────────────────────
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                            QuickActions(
                              user: widget.user,
                              dashboardData: const {},
                            ),

                            const SizedBox(height: 28),

                            // Today's Courses
                            _buildSectionTitle(
                              context,
                              "Today's Schedule",
                              Icons.calendar_today_rounded,
                              AppColors.green,
                              trailing: data.todayCourses.isNotEmpty
                                  ? _CountBadge(
                                      count: data.todayCourses.length,
                                      color: AppColors.green,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            if (data.todayCourses.isEmpty)
                              _EmptyStateCard(
                                icon: Icons.beach_access_rounded,
                                title: 'No classes today',
                                subtitle:
                                    'Enjoy your free time! 🎉',
                                accentColor: AppColors.green,
                                isDark: isDark,
                              )
                            else
                              ...data.todayCourses
                                  .asMap()
                                  .entries
                                  .map(
                                (entry) => _CourseCard(
                                  course: entry.value,
                                  index: entry.key,
                                  totalCourses:
                                      data.todayCourses.length,
                                  isDark: isDark,
                                ),
                              ),

                            const SizedBox(height: 28),

                            // Announcements
                            _buildSectionTitle(
                              context,
                              'Announcements',
                              Icons.campaign_rounded,
                              AppColors.purple,
                              trailing: data.announcements.isNotEmpty
                                  ? _ViewAllButton(
                                      onTap: () async {
                                        await Navigator.of(context)
                                            .push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                StudentAnnouncementsScreen(
                                              announcements:
                                                  data.announcements,
                                            ),
                                          ),
                                        );
                                        _reload();
                                      },
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            if (data.announcements.isEmpty)
                              _EmptyStateCard(
                                icon: Icons.mark_email_read_rounded,
                                title: 'All caught up!',
                                subtitle:
                                    'No new announcements right now.',
                                accentColor: AppColors.purple,
                                isDark: isDark,
                              )
                            else
                              ...data.announcements
                                  .take(3)
                                  .map(
                                (a) => _AnnouncementCard(
                                  announcement: a,
                                  isDark: isDark,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StudentAnnouncementsScreen(
                                          announcements:
                                              data.announcements,
                                        ),
                                      ),
                                    );
                                    _reload();
                                  },
                                ),
                              ),

                            const SizedBox(height: 28),

                            // Events
                            _buildSectionTitle(
                              context,
                              'Upcoming Events',
                              Icons.celebration_rounded,
                              AppColors.info,
                              trailing: sortedEvents.isNotEmpty
                                  ? _ViewAllButton(
                                      onTap: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              StudentEventsScreen(
                                            events: sortedEvents,
                                          ),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            if (data.events.isEmpty)
                              _EmptyStateCard(
                                icon: Icons.event_busy_rounded,
                                title: 'No upcoming events',
                                subtitle:
                                    'We\'ll notify you when something pops up.',
                                accentColor: AppColors.info,
                                isDark: isDark,
                              )
                            else
                              ...sortedEvents.take(2).map(
                                    (e) => _EventCard(
                                      event: e,
                                      isDark: isDark,
                                      onTap: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              StudentEventsScreen(
                                            events: sortedEvents,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                            const SizedBox(height: 100),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

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
                        color: primary,
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
                onReport: () => _showReportDialog(snapshot.error),
              );
            }

            return AppErrorWidget(
              message: 'No data available. Please try again.',
              onRetry: _reload,
            );
          },
        ),
      ),
    );
  }

  // ── Blue Gradient Header with Greeting + Stats Grid ───────────────────
  Widget _buildBlueHeader(
    BuildContext context,
    StudentHomeData data,
    Color primary,
    bool isDark,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final headerGap = isCompact ? 10.0 : 18.0;

    final primaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primary,
        primary.withValues(alpha: 0.8),
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
            color: primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                      data.firstName.isNotEmpty
                          ? data.firstName[0].toUpperCase()
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
                        data.firstName,
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
                // Notification bell
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentAnnouncementsScreen(
                                announcements: data.announcements,
                              ),
                            ),
                          );
                          _reload();
                        },
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    if (data.stats.unreadAnnouncements > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: primary,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            data.stats.unreadAnnouncements > 9
                                ? '9+'
                                : '${data.stats.unreadAnnouncements}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                // Refresh
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
            SizedBox(height: headerGap),
            // ── Stats 2x2 Grid ───────────────────────────────
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.0,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _HeaderStatCard(
                  label: 'Courses',
                  value: data.stats.courses,
                  icon: Icons.menu_book_rounded,
                ),
                _HeaderStatCard(
                  label: 'Announcements',
                  value: data.stats.announcements,
                  icon: Icons.campaign_rounded,
                ),
                _HeaderStatCard(
                  label: 'Assignments',
                  value: data.stats.assignments,
                  icon: Icons.assignment_rounded,
                ),
                _HeaderStatCard(
                  label: 'Events',
                  value: data.stats.events,
                  icon: Icons.celebration_rounded,
                ),
              ],
            ),
          ],
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
        if (trailing != null) trailing,
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AI FAB
// ═══════════════════════════════════════════════════════════════════════════════

class _AiFab extends StatefulWidget {
  final VoidCallback onPressed;
  final Color primaryColor;
  const _AiFab({required this.onPressed, required this.primaryColor});

  @override
  State<_AiFab> createState() => _AiFabState();
}

class _AiFabState extends State<_AiFab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withValues(alpha: 0.35),
                blurRadius: 16 + 4 * math.sin(_ctrl.value * 2 * math.pi),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: widget.primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER STAT CARD (white glass card inside blue header)
// ═══════════════════════════════════════════════════════════════════════════════

class _HeaderStatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _HeaderStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Icon(icon, size: 18, color: Colors.white),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
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

// ═══════════════════════════════════════════════════════════════════════════════
// COUNT BADGE
// ═══════════════════════════════════════════════════════════════════════════════

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VIEW ALL BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _ViewAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View All',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.blue,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COURSE CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _CourseCard extends StatelessWidget {
  final TodayCourse course;
  final int index;
  final int totalCourses;
  final bool isDark;

  const _CourseCard({
    required this.course,
    required this.index,
    required this.totalCourses,
    required this.isDark,
  });

  String get _status {
    if (course.startTime == '--:--' || course.endTime == '--:--') return '';
    try {
      final now = DateTime.now();
      final start = _parseTime(course.startTime);
      final end = _parseTime(course.endTime);

      if (now.isBefore(start)) return 'Upcoming';
      if (now.isAfter(start) && now.isBefore(end)) return 'Ongoing';
      return 'Past';
    } catch (e) {
      return '';
    }
  }

  bool get _isCurrentTime => _status == 'Ongoing';

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) throw Exception('Invalid time format');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _formatTimeDisplay(String start, String end) {
    if (start == '--:--') return course.schedule;
    if (end == '--:--') return start;
    return '$start - $end';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Upcoming':
        return AppColors.blue;
      case 'Ongoing':
        return Colors.green;
      case 'Past':
        return Colors.grey;
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColors = [
      AppColors.blue,
      AppColors.green,
      AppColors.purple,
      AppColors.orange,
      AppColors.info,
    ];
    final status = _status;
    final isCurrentTime = _isCurrentTime;
    final accent = isCurrentTime 
        ? Colors.green 
        : (status == 'Past' ? Colors.grey : accentColors[index % accentColors.length]);
    
    final timeDisplay = _formatTimeDisplay(course.startTime, course.endTime);
    final dayName = course.day;
    final timeStr = timeDisplay;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTime 
              ? Colors.green.withValues(alpha: 0.3)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.1)),
          width: isCurrentTime ? 2 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: isCurrentTime 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isCurrentTime ? 12 : 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCurrentTime ? Icons.live_tv_rounded : Icons.menu_book_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                course.code,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (status.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(status == 'Past' ? 0.1 : 1.0),
                                    borderRadius: BorderRadius.circular(8),
                                    border: status == 'Past' ? Border.all(color: Colors.grey.withOpacity(0.3)) : null,
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: status == 'Past' ? Colors.grey : Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            course.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: status == 'Past' ? theme.textTheme.bodyLarge?.color?.withOpacity(0.6) : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (dayName.isNotEmpty)
                                _InfoTag(
                                  icon: Icons.calendar_today_rounded,
                                  text: dayName,
                                  isDark: isDark,
                                  isHighlighted: isCurrentTime,
                                ),
                              if (dayName.isNotEmpty) const SizedBox(width: 8),
                              if (course.room.isNotEmpty)
                                _InfoTag(
                                  icon: Icons.room_outlined,
                                  text: course.room,
                                  isDark: isDark,
                                  isHighlighted: isCurrentTime,
                                ),
                              if (course.room.isNotEmpty && timeStr.isNotEmpty) const SizedBox(width: 8),
                              if (timeStr.isNotEmpty)
                                Flexible(
                                  child: _InfoTag(
                                    icon: Icons.access_time_rounded,
                                    text: timeStr,
                                    isDark: isDark,
                                    isHighlighted: isCurrentTime,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// INFO TAG (small chip with icon + text)
// ═══════════════════════════════════════════════════════════════════════════════

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final bool isHighlighted;

  const _InfoTag({
    required this.icon,
    required this.text,
    required this.isDark,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.green.withOpacity(0.1)
            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 11, 
            color: isHighlighted ? Colors.green : muted,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isHighlighted ? Colors.green : muted,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANNOUNCEMENT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _AnnouncementCard extends StatelessWidget {
  final HomeAnnouncement announcement;
  final bool isDark;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.announcement,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.1),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.purple.withValues(alpha: 0.15),
                    AppColors.purple.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.campaign_rounded,
                color: AppColors.purple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    announcement.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodySmall?.color,
                      height: 1.4,
                    ),
                  ),
                  if (announcement.postedAt.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          announcement.postedAt,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.textTheme.bodySmall?.color
                  ?.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _EventCard extends StatelessWidget {
  final HomeEvent event;
  final bool isDark;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.1),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Date badge
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: AppColors.info,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shortDate(event.eventDate),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (event.startTime.isNotEmpty) ...[
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.startTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (event.location.isNotEmpty) ...[
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  theme.textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.textTheme.bodySmall?.color
                  ?.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(String date) {
    // Try to parse and show a compact date
    try {
      final parts = date.split(RegExp(r'[-/]'));
      if (parts.length >= 3) {
        final months = [
          '',
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final m = int.tryParse(parts[1]) ?? 0;
        final d = parts[2].padLeft(2, '0');
        if (m >= 1 && m <= 12) return '$d\n${months[m]}';
      }
    } catch (_) {}
    return date.length > 6 ? date.substring(0, 6) : date;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isDark;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark 
            ? accentColor.withValues(alpha: 0.05)
            : accentColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodySmall?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
