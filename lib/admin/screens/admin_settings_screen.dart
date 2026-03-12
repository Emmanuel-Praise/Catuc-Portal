import 'package:flutter/material.dart';

import '../../services/local_storage_service.dart';
import '../../student/screens/student_auth_welcome_screen.dart';
import '../models/admin_session.dart';
import 'admin_version_settings_screen.dart';
import 'widgets/admin_ui.dart';

class AdminSettingsScreen extends StatelessWidget {
  final AdminSession user;

  const AdminSettingsScreen({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout from Admin panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await const LocalStorageService().clearSession();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StudentAuthWelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Admin Settings',
      subtitle: 'Session details, access notes and sign-out controls.',
      icon: Icons.settings_rounded,
      children: [
        AdminSurfaceCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName.isEmpty ? user.email : user.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${user.role.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const AdminSectionTitle(
          title: 'Access Notes',
          subtitle: 'Guidance for secure admin usage',
        ),
        const SizedBox(height: 12),
        AdminListItemCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminVersionSettingsScreen()),
            );
          },
          icon: Icons.system_update_rounded,
          iconColor: Theme.of(context).colorScheme.primary,
          title: 'App Version Management',
          subtitle: 'Set mandatory update requirements for all users.',
        ),
        const SizedBox(height: 10),
        AdminListItemCard(
          icon: Icons.campaign_rounded,
          iconColor: Theme.of(context).colorScheme.primary,
          title: 'Announcements',
          subtitle: 'Manage announcements from the backend tools when needed.',
        ),
        const SizedBox(height: 10),
        AdminListItemCard(
          icon: Icons.security_rounded,
          iconColor: Theme.of(context).colorScheme.secondary,
          title: 'Security',
          subtitle: 'Use admin-only credentials and rotate passwords regularly.',
        ),
        const SizedBox(height: 10),
        AdminListItemCard(
          icon: Icons.storage_rounded,
          iconColor: Theme.of(context).colorScheme.tertiary,
          title: 'Database',
          subtitle: 'Ensure backend APIs stay connected to the CATPT database.',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _logout(context),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ),
      ],
    );
  }
}
