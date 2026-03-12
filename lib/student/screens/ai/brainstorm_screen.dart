import 'package:flutter/material.dart';
import 'widgets/ai_chat_widget.dart';
import 'package:catuc_portal/shared/models/ai_user.dart';

class BrainstormScreen extends StatelessWidget {
  final AiUser user;
  final Map<String, dynamic>? dashboardData;
  final String? initialMessage;

  const BrainstormScreen({super.key, required this.user, this.dashboardData, this.initialMessage});

  @override
  Widget build(BuildContext context) {
    return AIChatWidget(
      user: user,
      aiType: 'brainstorm',
      title: 'Brainstorm Tool',
      hintText: 'Describe your goal or problem...',
      initialMessage: initialMessage,
    );
  }
}
