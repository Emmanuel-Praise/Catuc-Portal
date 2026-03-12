import 'package:flutter/material.dart';
import 'package:catuc_portal/student/screens/ai/ai_plans_screen.dart';
import 'package:catuc_portal/theme/app_colors.dart';

/// Shows a dialog when the user's daily AI message limit is reached.
/// Returns true if the user wants to view plans.
Future<void> showLimitReachedDialog(
  BuildContext context, {
  required String studentId,
  required String planName,
  required int usedToday,
  required int dailyLimit,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 10),
          const Expanded(child: Text('Daily Limit Reached', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You've used all $dailyLimit AI messages for today on the $planName plan.",
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.blue, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Upgrade your plan for more messages!',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AiPlansScreen(
                  studentId: studentId,
                  currentPlanName: planName,
                ),
              ),
            );
          },
          icon: const Icon(Icons.upgrade_rounded, size: 18),
          label: const Text('View Plans'),
        ),
      ],
    ),
  );
}
