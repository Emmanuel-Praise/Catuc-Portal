import 'package:flutter/material.dart';
import 'onboarding_service.dart';

class OnboardingResetService {
  static Future<void> showResetDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Onboarding'),
        content: const Text(
          'This will reset all onboarding and first-time user guides. '
          'You will see the onboarding screens again when you restart the app.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (result == true) {
      await OnboardingService.resetOnboarding();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Onboarding reset. Restart the app to see changes.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
