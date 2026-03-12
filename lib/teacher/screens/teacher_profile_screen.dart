import 'package:flutter/material.dart';

import '../../services/local_storage_service.dart';
import '../../student/screens/student_auth_welcome_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_service.dart';
import '../models/teacher_profile.dart';
import '../models/teacher_session.dart';
import '../services/teacher_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class TeacherProfileScreen extends StatefulWidget {
  final TeacherSession user;

  const TeacherProfileScreen({super.key, required this.user});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  late Future<TeacherProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = const TeacherApiService().fetchProfile(widget.user.userId);
  }

  Future<void> _reload() async {
    try {
      setState(() {
        _future = const TeacherApiService().fetchProfile(widget.user.userId);
      });
      await _future;
    } catch (e) {
      debugPrint('Error reloading teacher profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                hintText: 'e.g. The page didn\'t load after I clicked...',
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
                  issueType: 'Profile Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Issue reported successfully. Thank you!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to report: $e')),
                  );
                }
              }
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(TeacherProfile profile) {
    final firstNameController = TextEditingController(text: profile.firstName);
    final lastNameController = TextEditingController(text: profile.lastName);
    final emailController = TextEditingController(text: profile.email);
    final phoneController = TextEditingController(text: profile.phoneNumber ?? '');
    final officeController = TextEditingController(text: profile.officeLocation ?? '');
    String? gender = profile.gender;
    DateTime? dob = (() {
      final raw = (profile.dateOfBirth ?? '').trim();
      if (raw.isEmpty) return null;
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    })();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: officeController,
                    decoration: const InputDecoration(
                      labelText: 'Office Location (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: (gender == null || gender!.trim().isEmpty) ? null : gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: (v) => setModalState(() => gender = v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1950, 1, 1),
                        lastDate: DateTime.now(),
                        initialDate: dob ?? DateTime(1995, 1, 1),
                      );
                      if (picked == null) return;
                      setModalState(() => dob = picked);
                    },
                    icon: const Icon(Icons.cake_rounded, size: 18),
                    label: Text(
                      dob == null
                          ? 'Date of birth (optional)'
                          : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final firstName = firstNameController.text.trim();
                        final lastName = lastNameController.text.trim();
                        final email = emailController.text.trim();
                        if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('First name, last name and email are required')),
                          );
                          return;
                        }

                        String? dobStr;
                        if (dob != null) {
                          dobStr =
                              '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}';
                        }

                        try {
                          final msg = await const TeacherApiService().updateProfile(
                            teacherId: widget.user.userId,
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            phoneNumber: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                            officeLocation: officeController.text.trim().isNotEmpty ? officeController.text.trim() : null,
                            gender: (gender == null || gender!.trim().isEmpty) ? null : gender,
                            dateOfBirth: dobStr,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          _reload();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update profile: $e')),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await const LocalStorageService().clearSession();
                if (!mounted) return;
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const StudentAuthWelcomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
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
                  final msg = await const TeacherApiService().changePassword(
                    teacherId: widget.user.userId,
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final themeService = ThemeService();
    final primaryColor = themeService.primaryColor;
     
    // Create gradient from primary color
    final primaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor,
        primaryColor.withValues(alpha: 0.8),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<TeacherProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppErrorWidget(
              error: snapshot.error,
              onRetry: _reload,
              onReport: () => _showReportDialog(snapshot.error),
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('No profile data'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Enhanced Header with dynamic gradient
                Stack(
                  children: [
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        gradient: primaryGradient,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      // Add decorative pattern
                      child: CustomPaint(
                        painter: _HeaderPatternPainter(primaryColor),
                        child: Container(),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      child: Container(
                        height: 280,
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.onPrimary.withAlpha(38), // 0.15 opacity
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.onPrimary.withAlpha(77), // 0.3 opacity
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'Teacher Profile',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onPrimary.withAlpha(230), // 0.9 opacity
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${widget.user.firstName} ${widget.user.lastName}',
                                        style: textTheme.headlineMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        profile.departmentName ?? 'CATUC Lecturer',
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimary.withAlpha(217), // 0.85 opacity
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.onPrimary.withAlpha(38), // 0.15 opacity
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.onPrimary.withAlpha(77), // 0.3 opacity
                                      width: 1,
                                    ),
                                  ),
                                  child: IconButton(
                                    onPressed: _reload,
                                    icon: Icon(
                                      Icons.refresh_rounded,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Profile Stats
                            Row(
                              children: [
                                _EnhancedStatCard(
                                  label: 'Courses',
                                  value: '5', // Placeholder value
                                  icon: Icons.menu_book_rounded,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 16),
                                _EnhancedStatCard(
                                  label: 'Experience',
                                  value: '3 yrs', // Placeholder value
                                  icon: Icons.work_rounded,
                                  color: primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _InfoCard(
                        children: [
                          _InfoTile(
                            icon: Icons.badge_outlined,
                            label: 'Staff Number',
                            value: profile.staffNumber ?? 'Not provided',
                          ),
                          _InfoTile(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: profile.email,
                          ),
                          _InfoTile(
                            icon: Icons.phone_android_rounded,
                            label: 'Phone Number',
                            value: profile.phoneNumber ?? 'Not provided',
                          ),
                          _InfoTile(
                            icon: Icons.business_rounded,
                            label: 'Department',
                            value: profile.departmentName ?? 'Not assigned',
                          ),
                          _InfoTile(
                            icon: Icons.location_on_outlined,
                            label: 'Office Location',
                            value: profile.officeLocation ?? 'Not specified',
                          ),
                          _InfoTile(
                            icon: Icons.cake_outlined,
                            label: 'Date of Birth',
                            value: profile.dateOfBirth ?? 'Not set',
                          ),
                          _InfoTile(
                            icon: Icons.wc_rounded,
                            label: 'Gender',
                            value: profile.gender?.toUpperCase() ?? 'Not set',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _showEditProfileSheet(profile),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Profile'),
                      ),
                      const SizedBox(height: 12),
                      // Change Password Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          color: Colors.orange.withValues(alpha: 0.05),
                        ),
                        child: OutlinedButton.icon(
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.lock_reset_rounded, size: 20, color: Colors.orange),
                          label: const Text('Change Password', style: TextStyle(color: Colors.orange)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.transparent,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Theme Customization Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                          color: AppColors.blue.withValues(alpha: 0.05),
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const _ColorPickerSheet(),
                            );
                          },
                          icon: Icon(Icons.palette_rounded, size: 20, color: AppColors.blue),
                          label: Text('Customize Theme Color', style: TextStyle(color: AppColors.blue)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.transparent,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _showLogoutConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Logout'),
                      ),
                    ],
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

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(15), // 0.06 opacity
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.blue,
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
      ),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

// Custom painter for header pattern
class _HeaderPatternPainter extends CustomPainter {
  final Color color;
  
  _HeaderPatternPainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    
    // Draw decorative circles
    final path = Path();
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.2), radius: 60));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.1, size.height * 0.7), radius: 40));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.9, size.height * 0.8), radius: 30));
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Enhanced Stat Card
class _EnhancedStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _EnhancedStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimary.withAlpha(38), // 0.15 opacity
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withAlpha(64)), // 0.25 opacity
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(20), // 0.08 opacity
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withAlpha(64), // 0.25 opacity
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withAlpha(179), // 0.7 opacity
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerSheet extends StatelessWidget {
  const _ColorPickerSheet();

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final colors = [
      const Color(0xFF001AFF), // Default Blue
      const Color(0xFF7C4DFF), // Purple
      const Color(0xFFE91E63), // Pink
      const Color(0xFFF44336), // Red
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFFC107), // Amber
      const Color(0xFF4CAF50), // Green
      const Color(0xFF009688), // Teal
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF212121), // Charcoal
    ];

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final selected = themeService.primaryColor.toARGB32();

        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.15),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Customize Theme Color',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a color that fits your style. This will update the entire app experience.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: colors.map((color) {
                    final isSelected = selected == color.toARGB32();
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => themeService.updatePrimaryColor(color),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? scheme.onSurface : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: color.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: isSelected
                              ? Icon(Icons.check, color: scheme.onPrimary, size: 24)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
