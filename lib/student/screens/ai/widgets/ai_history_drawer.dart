import 'package:flutter/material.dart';
import 'package:catuc_portal/theme/app_colors.dart';
import 'package:catuc_portal/student/models/ai_chat_models.dart';
import 'package:intl/intl.dart';

class AIHistoryDrawer extends StatefulWidget {
  final String aiType;
  final List<AIChatSession> sessions;
  final Function(AIChatSession) onSelectSession;
  final VoidCallback onNewChat;
  final Function(String) onDeleteSession;

  const AIHistoryDrawer({
    super.key,
    required this.aiType,
    required this.sessions,
    required this.onSelectSession,
    required this.onNewChat,
    required this.onDeleteSession,
  });

  @override
  State<AIHistoryDrawer> createState() => _AIHistoryDrawerState();
}

class _AIHistoryDrawerState extends State<AIHistoryDrawer> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 12),
                  const Text(
                    'Chat History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onNewChat();
                  Navigator.pop(context); // Close drawer
                },
                icon: const Icon(Icons.add),
                label: const Text('Start New Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: widget.sessions.isEmpty
                  ? const Center(child: Text("No previous chats found", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: widget.sessions.length,
                      itemBuilder: (context, index) {
                        final session = widget.sessions[index];
                        final dateStr = DateFormat('MMM d, h:mm a').format(session.updatedAt);
                        
                        return ListTile(
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                          leading: const Icon(Icons.chat_bubble_outline),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () {
                              widget.onDeleteSession(session.id);
                            },
                          ),
                          onTap: () {
                            widget.onSelectSession(session);
                            Navigator.pop(context); // close drawer
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
