import 'package:flutter/material.dart';
import 'widgets/ai_chat_widget.dart';
import 'package:catuc_portal/shared/models/ai_user.dart';

class MakeNotesScreen extends StatelessWidget {
  final AiUser user;
  final Map<String, dynamic>? dashboardData;

  const MakeNotesScreen({super.key, required this.user, this.dashboardData});

  @override
  Widget build(BuildContext context) {
    return AIChatWidget(
      user: user,
      aiType: 'notes',
      title: 'Make Notes AI',
      hintText: 'Paste lecture text or ask to summarize...',
    );
  }
}
