import 'package:flutter/material.dart';
import '../../models/admin_announcement.dart';
import '../services/admin_api_service.dart';
import 'widgets/admin_ui.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  List<AdminAnnouncement> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _announcements = await const AdminApiService().fetchAllAnnouncements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showForm({AdminAnnouncement? existing}) {
    final titleC = TextEditingController(text: existing?.title ?? '');
    final msgC = TextEditingController(text: existing?.message ?? '');
    final imgC = TextEditingController(text: existing?.imageUrl ?? '');
    final expiresC = TextEditingController(text: existing?.expiresAt ?? '');
    String priority = existing?.priority ?? 'normal';
    final rolesC = TextEditingController(text: existing?.targetRoles ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            margin: const EdgeInsets.only(top: 60),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      existing == null ? 'New Announcement' : 'Edit Announcement',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleC,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: msgC,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message *',
                        prefixIcon: Icon(Icons.message_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: imgC,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                        hintText: 'https://example.com/image.png',
                        prefixIcon: Icon(Icons.image_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'high', child: Text('High (Important)')),
                        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                      ],
                      onChanged: (v) => setSheetState(() => priority = v ?? 'normal'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: rolesC,
                      decoration: const InputDecoration(
                        labelText: 'Target Roles (optional)',
                        hintText: 'student,teacher,ea  (empty = all)',
                        prefixIcon: Icon(Icons.people_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: expiresC,
                      decoration: const InputDecoration(
                        labelText: 'Expires At (optional)',
                        hintText: '2026-12-31 23:59:59',
                        prefixIcon: Icon(Icons.timer_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (titleC.text.trim().isEmpty || msgC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Title and Message are required')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          try {
                            if (existing == null) {
                              await const AdminApiService().createAnnouncement(
                                title: titleC.text.trim(),
                                message: msgC.text.trim(),
                                imageUrl: imgC.text.trim(),
                                priority: priority,
                                targetRoles: rolesC.text.trim(),
                                expiresAt: expiresC.text.trim(),
                              );
                            } else {
                              await const AdminApiService().updateAnnouncement(
                                id: existing.id,
                                title: titleC.text.trim(),
                                message: msgC.text.trim(),
                                imageUrl: imgC.text.trim(),
                                priority: priority,
                                targetRoles: rolesC.text.trim(),
                                expiresAt: expiresC.text.trim(),
                              );
                            }
                            _load();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          existing == null ? 'Create Announcement' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'urgent': return const Color(0xFFEF4444);
      case 'high': return const Color(0xFFF59E0B);
      case 'low': return const Color(0xFF6B7280);
      default: return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No announcements yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _announcements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final a = _announcements[i];
                      final color = _priorityColor(a.priority);
                      return AdminSurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      a.priority.toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: a.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      a.isActive ? 'ACTIVE' : 'INACTIVE',
                                      style: TextStyle(
                                        color: a.isActive ? Colors.green : Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  // Toggle
                                  IconButton(
                                    icon: Icon(
                                      a.isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await const AdminApiService().toggleAnnouncement(a.id);
                                      _load();
                                    },
                                    tooltip: a.isActive ? 'Deactivate' : 'Activate',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 20),
                                    onPressed: () => _showForm(existing: a),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.redAccent),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Announcement?'),
                                          content: Text('Delete "${a.title}"? This cannot be undone.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(c, true),
                                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await const AdminApiService().deleteAnnouncement(a.id);
                                        _load();
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            // Image
                            if (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                              Image.network(
                                a.imageUrl!,
                                width: double.infinity,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  Text(
                                    a.message,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (a.targetRoles != null && a.targetRoles!.isNotEmpty)
                                        _chip(Icons.people_outline, 'Roles: ${a.targetRoles}'),
                                      if (a.expiresAt != null && a.expiresAt!.isNotEmpty)
                                        _chip(Icons.timer_outlined, 'Exp: ${a.expiresAt!.length >= 10 ? a.expiresAt!.substring(0, 10) : a.expiresAt!}'),
                                      _chip(Icons.calendar_today_rounded, a.createdAt.length >= 10 ? a.createdAt.substring(0, 10) : a.createdAt),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
