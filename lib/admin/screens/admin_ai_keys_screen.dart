import 'package:flutter/material.dart';

import '../models/admin_session.dart';
import '../services/admin_api_service.dart';
import 'widgets/admin_ui.dart';

import '../../services/report_service.dart';

class AdminAiKeysScreen extends StatefulWidget {
  final AdminSession user;

  const AdminAiKeysScreen({super.key, required this.user});

  @override
  State<AdminAiKeysScreen> createState() => _AdminAiKeysScreenState();
}

class _AdminAiKeysScreenState extends State<AdminAiKeysScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = const AdminApiService().fetchAiKeys();
    });
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
                hintText: 'e.g. AI keys are not loading correctly...',
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
                  issueType: 'Admin AI Management Error',
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

  Future<void> _addKeyDialog() async {
    final types = ['brainstorm', 'learn', 'read', 'notes', 'code', 'voice'];
    String? selectedType = types.first;
    final controller = TextEditingController();
    final modelController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add API Key'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Model Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setDialogState(() => selectedType = v),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Text('API Key (OpenRouter, OpenAI, etc.):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'sk-or-v1-...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  const Text('Model Name (OpenRouter Identifier):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'e.g., google/gemini-2.5-pro',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save Key'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && selectedType != null && controller.text.trim().isNotEmpty) {
      if (!mounted) return;
      try {
        await const AdminApiService().addAiKey(
          selectedType!, 
          controller.text.trim(),
          modelKey: modelController.text.trim().isEmpty ? null : modelController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key added successfully!')),
        );
        _reload();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _deleteKey(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Key'),
        content: const Text('Are you sure you want to permanently delete this API key? AI relying on it might stop working if there are no other active keys for that model.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    try {
      await const AdminApiService().deleteAiKey(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key revoked successfully!')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'AI Management',
      subtitle: 'Dynamically add or revoke API keys for AI Models.',
      icon: Icons.auto_awesome_rounded,
      onRefresh: () async => _reload(),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _addKeyDialog,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Register New API Key'),
          ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final keys = snapshot.data ?? [];
            if (keys.isEmpty) {
              return const AdminEmptyCard(
                title: 'No API Keys Configured',
                subtitle: 'Add load-balanced API keys above to power the Catu AI services.',
                icon: Icons.vpn_key_off_rounded,
              );
            }

            // Group keys by AI Type
            final Map<String, List<Map<String, dynamic>>> grouped = {};
            for (var key in keys) {
              final type = key['ai_type'] as String? ?? 'unknown';
              grouped.putIfAbsent(type, () => []).add(key);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminSectionTitle(
                      title: 'Model: ${entry.key.toUpperCase()}',
                      subtitle: '${entry.value.length} active keys in rotation',
                    ),
                    const SizedBox(height: 12),
                    ...entry.value.map((keyData) {
                      final id = keyData['id'] as int;
                      final rawKey = keyData['api_key'] as String;
                      final maskedKey = rawKey.length > 10
                          ? '${rawKey.substring(0, 6)}...${rawKey.substring(rawKey.length - 4)}'
                          : rawKey;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AdminListItemCard(
                          icon: Icons.key_rounded,
                          iconColor: Theme.of(context).colorScheme.tertiary,
                          title: maskedKey,
                          subtitle: 'Model: ${keyData['model_name'] ?? 'N/A'}\nAdded: ${keyData['created_at']}',
                          trailingWidget: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                            onPressed: () => _deleteKey(id),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
