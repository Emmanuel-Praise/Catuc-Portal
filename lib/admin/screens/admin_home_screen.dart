import 'package:flutter/material.dart';

import '../models/admin_home_data.dart';
import '../models/admin_session.dart';
import '../services/admin_api_service.dart';
import 'admin_version_settings_screen.dart';
import 'admin_bans_screen.dart';
import 'admin_announcements_screen.dart';
import 'widgets/admin_ui.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class AdminHomeScreen extends StatefulWidget {
  final AdminSession user;

  const AdminHomeScreen({super.key, required this.user});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<AdminHomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = const AdminApiService().fetchHome(widget.user.userId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = const AdminApiService().fetchHome(widget.user.userId);
    });
    await _future;
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
                hintText: 'e.g. The dashboard counts are wrong...',
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
                  role: 'admin',
                  issueType: 'Admin UI Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully.')),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminHomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: AppErrorWidget(
              error: snapshot.error,
              onRetry: _reload,
              onReport: () => _showReportDialog(snapshot.error),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Scaffold(
            body: Center(child: Text('No dashboard data')),
          );
        }

        return AdminPageLayout(
          title: 'Admin Overview',
          subtitle: 'Manage CATUC from one clear dashboard.',
          icon: Icons.admin_panel_settings_rounded,
          onRefresh: _reload,
          children: [
            AdminSurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Signed in as',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.user.fullName.isEmpty
                              ? widget.user.email
                              : widget.user.fullName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.user.role.toUpperCase(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const AdminSectionTitle(
              title: 'Quick Actions',
              subtitle: 'Common administrative tasks',
            ),
            const SizedBox(height: 12),
            AdminSurfaceCard(
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminVersionSettingsScreen()),
                  );
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(25), // 0.1 opacity
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.system_update_rounded, color: Theme.of(context).colorScheme.primary),
                ),
                title: const Text(
                  'Manage App Version',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Push mandatory updates to users'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ),
            ),
            const SizedBox(height: 10),
            AdminSurfaceCard(
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AdminBansScreen(user: widget.user)),
                  );
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.gpp_bad_rounded, color: Colors.red),
                ),
                title: const Text(
                  'Ban Management',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('View bans, appeals & manage banned users'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ),
            ),
            const SizedBox(height: 10),
            AdminSurfaceCard(
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminAnnouncementsScreen()),
                  );
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Colors.orange),
                ),
                title: const Text(
                  'Announcements',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Create popup notices with images for all users'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ),
            ),
            const SizedBox(height: 22),
            const AdminSectionTitle(
              title: 'System Metrics',
              subtitle: 'Live counts from the current database',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final span = constraints.maxWidth > 600 ? 4 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: span,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    AdminMiniStatCard(
                      label: 'Students',
                      value: '${data.stats.students}',
                      icon: Icons.school_rounded,
                      accent: Theme.of(context).colorScheme.primary,
                    ),
                    AdminMiniStatCard(
                      label: 'Staff',
                      value: '${data.stats.staff}',
                      icon: Icons.badge_rounded,
                      accent: Theme.of(context).colorScheme.secondary,
                    ),
                    AdminMiniStatCard(
                      label: 'Courses',
                      value: '${data.stats.courses}',
                      icon: Icons.menu_book_rounded,
                      accent: Theme.of(context).colorScheme.tertiary,
                    ),
                    AdminMiniStatCard(
                      label: 'Enrollments',
                      value: '${data.stats.enrollments}',
                      icon: Icons.assignment_rounded,
                      accent: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                );
              }
            ),
            const SizedBox(height: 18),
            AdminSurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: _InlineMetric(
                      label: 'Active Users',
                      value: '${data.stats.activeUsers}',
                    ),
                  ),
                  Expanded(
                    child: _InlineMetric(
                      label: 'Announcements',
                      value: '${data.stats.activeAnnouncements}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const AdminSectionTitle(
              title: 'Role Breakdown',
              subtitle: 'User distribution by account type',
            ),
            const SizedBox(height: 12),
            if (data.roleBreakdown.isEmpty)
              const AdminEmptyCard(
                title: 'No role data',
                subtitle: 'Role totals will appear here when available.',
                icon: Icons.pie_chart_outline_rounded,
              )
            else
              ...data.roleBreakdown.map(
                (role) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AdminListItemCard(
                    icon: Icons.group_work_rounded,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: role.role.toUpperCase(),
                    subtitle: 'Registered accounts in this role',
                    trailing: '${role.total}',
                  ),
                ),
              ),
            const SizedBox(height: 22),
            const AdminSectionTitle(
              title: 'Recent Users',
              subtitle: 'Newest accounts created in the system',
            ),
            const SizedBox(height: 12),
            if (data.recentUsers.isEmpty)
              const AdminEmptyCard(
                title: 'No users found',
                subtitle: 'Recent users will appear here.',
                icon: Icons.person_search_rounded,
              )
            else
              ...data.recentUsers.take(6).map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AdminListItemCard(
                    icon: Icons.person_rounded,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title:
                        user.fullName.isEmpty ? user.email : user.fullName,
                    subtitle: '${user.role}  •  ${user.email}',
                    trailing: user.createdAt.length >= 10
                        ? user.createdAt.substring(0, 10)
                        : user.createdAt,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
