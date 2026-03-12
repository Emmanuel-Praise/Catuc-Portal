import 'package:flutter/material.dart';

import '../models/admin_home_data.dart';
import '../models/admin_session.dart';
import '../services/admin_api_service.dart';
import 'widgets/admin_ui.dart';

import '../../services/report_service.dart';

class AdminPeopleScreen extends StatefulWidget {
  final AdminSession user;

  const AdminPeopleScreen({super.key, required this.user});

  @override
  State<AdminPeopleScreen> createState() => _AdminPeopleScreenState();
}

class _AdminPeopleScreenState extends State<AdminPeopleScreen> {
  late Future<AdminHomeData> _future;
  final _api = const AdminApiService();

  @override
  void initState() {
    super.initState();
    _future = _api.fetchHome(widget.user.userId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchHome(widget.user.userId);
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
                hintText: 'e.g. I cannot see the list of students...',
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
                  issueType: 'Admin People Management Error',
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

  void _showAddDialog(String type) async {
    final metadata = await _api.fetchMetadata();
    if (!mounted) return;

    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final idController = TextEditingController();
    String? selectedDept;
    String? selectedProgram;
    String? selectedRole = type == 'Staff' ? 'staff' : 'student';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add New $type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
                TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                TextField(
                  controller: idController, 
                  decoration: InputDecoration(labelText: type == 'Staff' ? 'Employee Number' : 'Student Number'),
                ),
                if (type == 'Staff') ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedDept,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: (metadata['departments'] as List).map((d) => 
                      DropdownMenuItem(value: d['department_id'].toString(), child: Text(d['department_name']))
                    ).toList(),
                    onChanged: (v) => setDialogState(() => selectedDept = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: (metadata['roles'] as List).where((r) => r != 'student').map((r) => 
                      DropdownMenuItem(value: r.toString(), child: Text(r.toString().toUpperCase()))
                    ).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedProgram,
                    decoration: const InputDecoration(labelText: 'Program'),
                    items: (metadata['programs'] as List).map((p) => 
                      DropdownMenuItem(value: p['program_id'].toString(), child: Text(p['program_name']))
                    ).toList(),
                    onChanged: (v) => setDialogState(() => selectedProgram = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  if (type == 'Staff') {
                    await _api.postAction('ea_staff.php', {
                      'action': 'add',
                      'first_name': firstNameController.text,
                      'last_name': lastNameController.text,
                      'email': emailController.text,
                      'employee_number': idController.text,
                      'department_id': selectedDept,
                      'role': selectedRole,
                    });
                  } else {
                    await _api.postAction('ea_students.php', {
                      'action': 'add',
                      'first_name': firstNameController.text,
                      'last_name': lastNameController.text,
                      'email': emailController.text,
                      'student_number': idController.text,
                      'program_id': selectedProgram,
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                  _reload();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _onDeleteItem(String id, String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deactivation'),
        content: Text('Are you sure you want to deactivate this $type?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Deactivate', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final endpoint = type == 'Staff' ? 'ea_staff.php' : 'ea_students.php';
        final key = type == 'Staff' ? 'staff_id' : 'student_id';
        await _api.postAction(endpoint, {'action': 'delete', key: id});
        _reload();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminHomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        final data = snapshot.data;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('No people data')));
        }

        final size = MediaQuery.of(context).size;
        final span = size.width > 600 ? 3 : 2;

        return AdminPageLayout(
          title: 'People Management',
          subtitle: 'Monitor students, staff and recently created accounts.',
          icon: Icons.groups_rounded,
          onRefresh: _reload,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
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
                      label: 'Active Users',
                      value: '${data.stats.activeUsers}',
                      icon: Icons.verified_user_rounded,
                       accent: Theme.of(context).colorScheme.tertiary,
                    ),
                    if (span > 2)
                    AdminMiniStatCard(
                      label: 'Account Roles',
                      value: '${data.roleBreakdown.length}',
                      icon: Icons.account_tree_rounded,
                       accent: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                );
              }
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showAddDialog('Student'),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Student'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showAddDialog('Staff'),
                    icon: const Icon(Icons.badge_rounded, size: 18),
                    label: const Text('Add Staff'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const AdminSectionTitle(
              title: 'Recently Created Accounts',
              subtitle: 'Newest platform users',
            ),
            const SizedBox(height: 12),
            if (data.recentUsers.isEmpty)
              const AdminEmptyCard(
                title: 'No users found',
                subtitle: 'User records will appear here.',
                icon: Icons.person_off_rounded,
              )
            else
              ...data.recentUsers.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AdminListItemCard(
                    icon: Icons.person_rounded,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: user.fullName.isEmpty ? user.email : user.fullName,
                    subtitle: '${user.role.toUpperCase()} • ${user.email}',
                    trailing: user.createdAt.length >= 10 ? user.createdAt.substring(0, 10) : user.createdAt,
                    onDelete: () => _onDeleteItem(user.userId, user.role == 'student' ? 'Student' : 'Staff'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
