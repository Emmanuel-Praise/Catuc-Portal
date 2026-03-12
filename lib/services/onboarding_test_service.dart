import 'package:flutter/material.dart';
import 'onboarding_service.dart';

class OnboardingTestService {
  static Future<void> showTestDialog(BuildContext context) async {
    final onboardingCompleted = await OnboardingService.isOnboardingCompleted();
    final firstLoginCompleted = await OnboardingService.isFirstLoginCompleted();
    
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Onboarding Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('App Onboarding: ${onboardingCompleted ? "✅ Completed" : "❌ Not Completed"}'),
              const SizedBox(height: 8),
              Text('First Login Guide: ${firstLoginCompleted ? "✅ Completed" : "❌ Not Completed"}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await OnboardingService.resetOnboarding();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Onboarding reset! Restart app to see changes.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Reset All', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }
}
