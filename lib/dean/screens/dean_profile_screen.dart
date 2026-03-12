import 'package:flutter/material.dart';
import '../models/dean_profile.dart';
import '../models/dean_session.dart';
import '../services/dean_api_service.dart';
import '../../services/local_storage_service.dart';
import '../../student/screens/student_auth_welcome_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanProfileScreen extends StatefulWidget {
  final DeanSession user;

  const DeanProfileScreen({super.key, required this.user});

  @override
  State<DeanProfileScreen> createState() => _DeanProfileScreenState();
}

class _DeanProfileScreenState extends State<DeanProfileScreen> {
  late Future<DeanProfile> _future;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    setState(() {
      _future = const DeanApiService().fetchDeanProfile(widget.user.userId)
          .then((data) => DeanProfile.fromJson(data));
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<DeanProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorWidget(error: snapshot.error, onRetry: _loadProfile);
          }
          final profile = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(profile, primaryColor),
              const SizedBox(height: 24),
              _buildInfoSection(profile),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _showChangePasswordDialog(),
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Change Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: Colors.orange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _showLogoutConfirm(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(DeanProfile profile, Color primaryColor) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Text(
            (profile.firstName.isNotEmpty ? profile.firstName[0] : '?') + 
            (profile.lastName.isNotEmpty ? profile.lastName[0] : '?'),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${profile.firstName} ${profile.lastName}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          'Dean of ${profile.facultyName ?? "Faculty"}',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildInfoSection(DeanProfile profile) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildInfoTile(Icons.email_outlined, 'Email', profile.email),
          _buildInfoTile(Icons.phone_outlined, 'Phone', profile.phoneNumber ?? 'Not set'),
          _buildInfoTile(Icons.business_rounded, 'Office', profile.officeLocation ?? 'Not set'),
          _buildInfoTile(Icons.badge_outlined, 'Staff ID', profile.staffNumber ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: ThemeService().primaryColor),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obfuscate = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: obfuscate,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(obfuscate ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setModalState(() => obfuscate = !obfuscate),
                  ),
                ),
              ),
              TextField(
                controller: newController,
                obscureText: obfuscate,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              TextField(
                controller: confirmController,
                obscureText: obfuscate,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
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
                final current = currentController.text;
                final newPass = newController.text;
                final confirm = confirmController.text;

                if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All fields are required')),
                  );
                  return;
                }
                if (newPass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match')),
                  );
                  return;
                }

                try {
                  final msg = await const DeanApiService().changePassword(
                    userId: widget.user.userId,
                    currentPassword: current,
                    newPassword: newPass,
                    confirmPassword: confirm,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await const LocalStorageService().clearSession();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const StudentAuthWelcomeScreen()),
                  (route) => false,
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
