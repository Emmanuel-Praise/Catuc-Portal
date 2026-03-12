import 'package:flutter/material.dart';
import '../models/teacher_home_data.dart';

class TeacherTodayCourseCard extends StatelessWidget {
  final AssignedCourse course;
  final Color primaryColor;
  final int index;
  final int totalCourses;

  const TeacherTodayCourseCard({
    super.key,
    required this.course,
    required this.primaryColor,
    required this.index,
    required this.totalCourses,
  });

  String _extractDayFromSchedule(String schedule) {
    if (schedule.isEmpty) return '';
    
    final dayMap = {
      'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
      'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday'
    };
    
    final normalizedSchedule = schedule.toLowerCase();
    
    for (final entry in dayMap.entries) {
      if (normalizedSchedule.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return '';
  }

  String _extractTimeFromSchedule(String schedule) {
    if (schedule.isEmpty) return '';
    
    // Look for time patterns like "08:00-10:00" or "8:00 AM - 10:00 AM"
    final timeRegex = RegExp(r'(\d{1,2}:\d{2})\s*(?:AM|PM)?\s*[-–—]\s*(\d{1,2}:\d{2})\s*(?:AM|PM)?');
    final match = timeRegex.firstMatch(schedule);
    
    if (match != null) {
      return '${match.group(1)} - ${match.group(2)}';
    }
    
    // Look for single time
    final singleTimeRegex = RegExp(r'(\d{1,2}:\d{2})');
    final singleMatch = singleTimeRegex.firstMatch(schedule);
    
    if (singleMatch != null) {
      return singleMatch.group(1)!;
    }
    
    return schedule;
  }

  bool _isCurrentTime() {
    final timeStr = _extractTimeFromSchedule(course.schedule);
    if (timeStr.isEmpty || !timeStr.contains('-')) return false;
    
    try {
      final parts = timeStr.split('-');
      final startTime = _parseTime(parts[0].trim());
      final endTime = _parseTime(parts[1].trim());
      final now = DateTime.now();
      
      return now.isAfter(startTime) && now.isBefore(endTime);
    } catch (e) {
      return false;
    }
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final dayName = _extractDayFromSchedule(course.schedule);
    final timeStr = _extractTimeFromSchedule(course.schedule);
    final isCurrentTime = _isCurrentTime();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTime 
              ? Colors.green.withValues(alpha: 0.3)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.1)),
          width: isCurrentTime ? 2 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: isCurrentTime 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isCurrentTime ? 12 : 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Accent strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: isCurrentTime ? Colors.green : primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Course icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isCurrentTime 
                            ? Colors.green.withValues(alpha: 0.15)
                            : primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCurrentTime ? Icons.live_tv_rounded : Icons.school_rounded,
                        color: isCurrentTime ? Colors.green : primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                course.courseCode,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrentTime ? Colors.green : primaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (isCurrentTime) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'NOW',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            course.courseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (dayName.isNotEmpty)
                                _InfoTag(
                                  icon: Icons.calendar_today_rounded,
                                  text: dayName,
                                  isDark: isDark,
                                  isHighlighted: isCurrentTime,
                                ),
                              if (dayName.isNotEmpty) const SizedBox(width: 8),
                              if (course.roomNumber.trim().isNotEmpty)
                                _InfoTag(
                                  icon: Icons.room_outlined,
                                  text: course.roomNumber,
                                  isDark: isDark,
                                  isHighlighted: isCurrentTime,
                                ),
                              if (course.roomNumber.trim().isNotEmpty && timeStr.isNotEmpty) const SizedBox(width: 8),
                              if (timeStr.isNotEmpty)
                                Flexible(
                                  child: _InfoTag(
                                    icon: Icons.access_time_rounded,
                                    text: timeStr,
                                    isDark: isDark,
                                    isHighlighted: isCurrentTime,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Trailing arrow
            Icon(
              Icons.chevron_right_rounded, 
              color: (isCurrentTime ? Colors.green : primaryColor).withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final bool isHighlighted;

  const _InfoTag({
    required this.icon,
    required this.text,
    required this.isDark,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.green.withValues(alpha: 0.1)
            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 11, 
            color: isHighlighted ? Colors.green : muted,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isHighlighted ? Colors.green : muted,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
