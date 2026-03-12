import 'package:flutter/material.dart';
import '../../models/admin_announcement.dart';

/// Shows a beautiful closable announcement dialog.
/// Call this from any screen after fetching active announcements.
Future<void> showAnnouncementPopup(
  BuildContext context,
  List<AdminAnnouncement> announcements,
) async {
  if (announcements.isEmpty) return;

  for (final announcement in announcements) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AnnouncementDialog(announcement: announcement),
    );
  }
}

class _AnnouncementDialog extends StatelessWidget {
  final AdminAnnouncement announcement;

  const _AnnouncementDialog({required this.announcement});

  Color _priorityColor() {
    switch (announcement.priority) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _priorityIcon() {
    switch (announcement.priority) {
      case 'urgent':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.priority_high_rounded;
      case 'low':
        return Icons.info_outline_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String _priorityLabel() {
    switch (announcement.priority) {
      case 'urgent':
        return 'URGENT';
      case 'high':
        return 'IMPORTANT';
      case 'low':
        return 'INFO';
      default:
        return 'ANNOUNCEMENT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Priority banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_priorityIcon(), color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _priorityLabel(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // Image if present
              if (hasImage)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Image.network(
                    announcement.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        announcement.message,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
