import 'package:flutter/material.dart';
import 'package:catuc_portal/theme/app_colors.dart';
import 'package:catuc_portal/student/models/student_session.dart';
import 'package:catuc_portal/student/screens/ai/brainstorm_screen.dart';
import 'package:catuc_portal/student/screens/ai/code_assistant_screen.dart';
import 'package:catuc_portal/student/screens/ai/learn_screen.dart';
import 'package:catuc_portal/student/screens/ai/read_screen.dart';
import 'package:catuc_portal/student/screens/student_report_screen.dart';
import 'package:catuc_portal/student/screens/student_timetable_screen.dart';
import 'package:catuc_portal/student/screens/student_academic_hub_screen.dart';
import 'package:catuc_portal/shared/models/ai_user.dart';

class QuickActions extends StatefulWidget {
  final StudentSession user;
  final bool hasPendingReports;
  final Map<String, dynamic>? dashboardData;

  const QuickActions({
    super.key,
    required this.user,
    this.hasPendingReports = false,
    this.dashboardData,
  });

  @override
  State<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<QuickActions> {
  final TextEditingController _aiChatController = TextEditingController();

  Widget _buildAiIdentityIcon(BuildContext context, {double size = 30}) {
    // Use AppColors.blue as the color for AI identity icon
    final color = AppColors.blue; 
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Icon(Icons.hive_outlined, size: size * 0.62, color: color),
    );
  }

  Widget _buildAIChatBar(BuildContext context, bool isDark) {
    final isCompact = MediaQuery.of(context).size.width < 380;
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 12 : 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary(context).withAlpha(77), // 0.3 opacity
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(26), // 0.1 opacity
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildAiIdentityIcon(context, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _aiChatController,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BrainstormScreen(
                        user: AiUser.fromStudentSession(widget.user),
                        dashboardData: widget.dashboardData,
                        initialMessage: value.trim(),
                      ),
                    ),
                  );
                  _aiChatController.clear();
                }
              },
              decoration: InputDecoration(
                hintText: 'Ask Catu AI anything...',
                hintStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(138), // ~0.54 opacity
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: AppColors.primary(context),
              size: 20,
            ),
            onPressed: () {
              if (_aiChatController.text.trim().isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BrainstormScreen(
                      user: AiUser.fromStudentSession(widget.user),
                      dashboardData: widget.dashboardData,
                      initialMessage: _aiChatController.text.trim(),
                    ),
                  ),
                );
                _aiChatController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget responsiveActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
    bool showBadge = false,
    bool isAI = false,
  }) {

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
            color: isAI
                ? AppColors.primary(context).withAlpha(51) // 0.2 opacity
                : Theme.of(context).dividerColor.withAlpha(13), // ~0.05 opacity
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(5), // ~0.02 opacity
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconBgColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAIToolsMenu(BuildContext context) {
    final primary = AppColors.primary(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAiIdentityIcon(context, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catu AI Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Select a specialized tool to assist you',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildAIToolItem(
              context,
              icon: Icons.menu_book_rounded,
              title: 'Catu AI Study Suite',
              subtitle: 'Summarize notes, explain, and generate quizzes',
              color: primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ReadScreen(user: AiUser.fromStudentSession(widget.user), dashboardData: widget.dashboardData),
                ),
              ),
            ),
            _buildAIToolItem(
              context,
              icon: Icons.psychology_alt_rounded,
              title: 'Learn & Quiz',
              subtitle: 'Interactive teaching & exam prep',
              color: primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LearnScreen(user: AiUser.fromStudentSession(widget.user), dashboardData: widget.dashboardData),
                ),
              ),
            ),
            _buildAIToolItem(
              context,
              icon: Icons.code_rounded,
              title: 'Code Assistant',
              subtitle: 'Expert help with programming & logic',
              color: primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CodeAssistantScreen(user: AiUser.fromStudentSession(widget.user), dashboardData: widget.dashboardData),
                ),
              ),
            ),
            _buildAIToolItem(
              context,
              icon: Icons.tips_and_updates_rounded,
              title: 'Brainstorm Partner',
              subtitle: 'Creative ideas & project planning',
              color: primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      BrainstormScreen(user: AiUser.fromStudentSession(widget.user), dashboardData: widget.dashboardData),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAIToolItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withAlpha(13), // 0.05 opacity
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(26)), // 0.1 opacity
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(26), // 0.1 opacity
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153), // ~0.6 opacity
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withAlpha(128)), // 0.5 opacity
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isCompact = screenWidth < 380;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAIChatBar(context, isDark),

        Padding(
          padding: EdgeInsets.only(left: 4, bottom: isCompact ? 8 : 12),
          child: const Text(
            'Essential Tools',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: isCompact ? 8 : 10,
          mainAxisSpacing: isCompact ? 8 : 10,
          childAspectRatio: 2.5,
          children: [
            responsiveActionButton(
              context,
              icon: Icons.school_rounded,
              label: 'Academic',
              iconBgColor: primary,
              iconColor: Colors.white,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StudentAcademicHubScreen(user: widget.user)),
              ),
            ),
            responsiveActionButton(
              context,
              icon: Icons.description_rounded,
              label: 'Report',
              iconBgColor: primary,
              iconColor: Colors.white,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StudentReportScreen(user: widget.user)),
              ),
              showBadge: widget.hasPendingReports,
            ),
            responsiveActionButton(
              context,
              icon: Icons.calendar_today_rounded,
              label: 'Timetable',
              iconBgColor: primary,
              iconColor: Colors.white,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StudentTimetableScreen(user: widget.user)),
              ),
            ),
            responsiveActionButton(
              context,
              icon: Icons.hive_outlined,
              label: 'AI Assistant',
              iconBgColor: primary,
              iconColor: Colors.white,
              isAI: true,
              onTap: () => _showAIToolsMenu(context),
            ),
          ],
        ),
      ],
    );
  }
}
