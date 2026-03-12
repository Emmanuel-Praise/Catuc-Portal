import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/connectivity_service.dart';

class AppErrorWidget extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback? onReport;
  final String? message;

  const AppErrorWidget({
    super.key,
    this.error,
    this.onRetry,
    this.onReport,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isOffline = !ConnectivityService().isOnline || 
                      (error?.toString().contains('SocketException') ?? false) ||
                      (error?.toString().contains('Network') ?? false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 64,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isOffline ? "You're Offline" : "Something Went Wrong",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message ?? (isOffline 
                ? "It looks like you're not connected to the internet. We'll show you cached data where available." 
                : "We encountered an unexpected issue while loading this page. Please try again or report it to us."),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          if (onRetry != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (!isOffline && onReport != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReport,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.blue.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.bug_report_outlined),
                label: Text(
                  'Report Issue',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }
}
