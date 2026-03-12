import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../models/student_session.dart';
import '../models/student_timetable_data.dart';
import '../services/student_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';
import '../../services/connectivity_service.dart';

class StudentTimetableScreen extends StatefulWidget {
  final StudentSession user;

  const StudentTimetableScreen({super.key, required this.user});

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<_TimetableLoadResult> _future;

  static const _types = ['semester', 'exam', 'resit'];
  static const _labels = ['Semester', 'Exam', 'Resit'];
  static const _icons = [
    Icons.calendar_month_rounded,
    Icons.edit_note_rounded,
    Icons.replay_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _types.length, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetchAll();
    });
  }

  Future<_TimetableLoadResult> _fetchAll() async {
    final api = const StudentApiService();
    final errors = <String, Object>{};
    final shouldForceRefresh = ConnectivityService().isOnline;

    Future<List<TimetableSlot>> safeFetch(String type) async {
      try {
        return await api.fetchTimetable(
          studentId: widget.user.userId,
          type: type,
          forceRefresh: shouldForceRefresh,
        );
      } catch (e) {
        errors[type] = e;
        return <TimetableSlot>[];
      }
    }

    final results = await Future.wait([
      safeFetch('semester'),
      safeFetch('exam'),
      safeFetch('resit'),
    ]);

    return _TimetableLoadResult(
      data: {
        'semester': results[0],
        'exam': results[1],
        'resit': results[2],
      },
      errors: errors,
    );
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
                hintText: 'e.g. The timetable is not loading...',
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
                  role: 'student',
                  issueType: 'Student Timetable Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully. Thank you!')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.blueGradient),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: List.generate(_types.length, (i) {
            return Tab(icon: Icon(_icons[i], size: 20), text: _labels[i]);
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<_TimetableLoadResult>(
        future: _future,
        builder: (context, snapshot) {
          // Show data if we have it (from cache or previous load)
          if (snapshot.hasData) {
            final result = snapshot.data!;
            final data = result.data;

            return TabBarView(
              controller: _tabController,
              children: _types.map((type) {
                final slots = data[type] ?? [];
                return _TimetableTabContent(
                  type: type,
                  slots: slots,
                  onRefresh: _reload,
                  loadError: result.errors[type],
                  onReport: result.errors[type] == null
                      ? null
                      : () => _showReportDialog(result.errors[type]),
                );
              }).toList(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppErrorWidget(
              error: snapshot.error,
              onRetry: _reload,
              onReport: () => _showReportDialog(snapshot.error),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _TimetableLoadResult {
  final Map<String, List<TimetableSlot>> data;
  final Map<String, Object> errors;

  const _TimetableLoadResult({
    this.data = const {},
    this.errors = const {},
  });
}

// --- Tab content widget ---

class _TimetableTabContent extends StatelessWidget {
  final String type;
  final List<TimetableSlot> slots;
  final VoidCallback onRefresh;
  final Object? loadError;
  final VoidCallback? onReport;

  const _TimetableTabContent({
    required this.type,
    required this.slots,
    required this.onRefresh,
    this.loadError,
    this.onReport,
  });

  String get _emptyTitle {
    switch (type) {
      case 'semester':
        return 'No semester timetable';
      case 'exam':
        return 'No exam timetable';
      case 'resit':
        return 'No resit timetable';
      default:
        return 'No timetable';
    }
  }

  String get _emptySubtitle {
    switch (type) {
      case 'semester':
        return 'No semester class schedule has been published yet.';
      case 'exam':
        return 'No exam schedule has been published for your courses yet.';
      case 'resit':
        return 'You have no resit exams. Great job!';
      default:
        return 'Check back later.';
    }
  }

  IconData get _emptyIcon {
    switch (type) {
      case 'semester':
        return Icons.calendar_month_rounded;
      case 'exam':
        return Icons.edit_note_rounded;
      case 'resit':
        return Icons.celebration_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _typeAccentColor(BuildContext context) {
    switch (type) {
      case 'semester':
        return AppColors.blue;
      case 'exam':
        return Colors.orange.shade700;
      case 'resit':
        return Colors.red.shade600;
      default:
        return AppColors.blue;
    }
  }

  String _typeLabel() {
    switch (type) {
      case 'semester':
        return 'SEMESTER';
      case 'exam':
        return 'EXAM';
      case 'resit':
        return 'RESIT';
      default:
        return '';
    }
  }

  String _normalizeDayName(String day) {
    if (day.isEmpty) return 'Unscheduled';
    
    // Handle various day formats and normalize
    final normalizedDay = day.toLowerCase().trim();
    
    // Map common variations to standard day names
    switch (normalizedDay) {
      case 'mon':
      case 'monday':
        return 'Monday';
      case 'tue':
      case 'tues':
      case 'tuesday':
        return 'Tuesday';
      case 'wed':
      case 'wednesday':
        return 'Wednesday';
      case 'thu':
      case 'thur':
      case 'thurs':
      case 'thursday':
        return 'Thursday';
      case 'fri':
      case 'friday':
        return 'Friday';
      case 'sat':
      case 'saturday':
        return 'Saturday';
      case 'sun':
      case 'sunday':
        return 'Sunday';
      default:
        // Check if it's already a proper day name
        if (['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].contains(day)) {
          return day;
        }
        // Try to extract day from date strings
        if (day.contains('-')) {
          try {
            final dateTime = DateTime.parse(day);
            return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][dateTime.weekday - 1];
          } catch (e) {
            // If parsing fails, return as is if it looks like a date
          }
        }
        return day.contains('-') ? day : 'Other';
    }
  }

  bool _isToday(String day) {
    if (day.isEmpty) return false;
    final normalizedDay = _normalizeDayName(day);
    final today = DateTime.now();
    final todayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][today.weekday - 1];
    return normalizedDay == todayName;
  }

  @override
  Widget build(BuildContext context) {
    if (loadError != null && slots.isEmpty) {
      return AppErrorWidget(
        error: loadError,
        onRetry: onRefresh,
        onReport: onReport,
      );
    }
    if (slots.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _typeAccentColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _emptyIcon,
                      size: 64,
                      color: _typeAccentColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _emptyTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _emptySubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withAlpha(153),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final Map<String, List<TimetableSlot>> grouped = {};
    for (final s in slots) {
      // Normalize day names for consistent grouping
      final dayName = _normalizeDayName(s.day.isNotEmpty ? s.day : (s.examDate.isNotEmpty ? s.examDate : ''));
      grouped.putIfAbsent(dayName, () => []).add(s);
    }

    final List<String> sortedDates;
    if (type == 'semester') {
      const dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', 'Today', 'Other', 'Unscheduled'];
      sortedDates = grouped.keys.toList()
        ..sort((a, b) {
          // Prioritize "Today" if it exists
          if (a == 'Today') return -1;
          if (b == 'Today') return 1;
          
          int indexA = dayOrder.indexOf(a);
          int indexB = dayOrder.indexOf(b);
          if (indexA == -1) indexA = 99;
          if (indexB == -1) indexB = 99;
          int res = indexA.compareTo(indexB);
          return res != 0 ? res : a.compareTo(b);
        });
    } else {
      sortedDates = grouped.keys.toList()..sort();
    }

    final accent = _typeAccentColor(context);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: sortedDates.length,
        itemBuilder: (context, dateIndex) {
          final date = sortedDates[dateIndex];
          final dateSlots = grouped[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isToday(date) 
                            ? Colors.green.withOpacity(0.15)
                            : accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: _isToday(date) 
                            ? Border.all(color: Colors.green.withOpacity(0.3), width: 1)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isToday(date) 
                                ? Icons.today_rounded
                                : Icons.calendar_today_rounded,
                            size: 14, 
                            color: _isToday(date) ? Colors.green : accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isToday(date) ? 'Today' : date,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _isToday(date) ? Colors.green : accent,
                            ),
                          ),
                          if (_isToday(date)) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_isToday(date) 
                            ? Colors.green.withOpacity(0.08)
                            : accent.withOpacity(0.08)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${dateSlots.length} ${dateSlots.length == 1 ? 'course' : 'courses'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: (_isToday(date) 
                              ? Colors.green.withOpacity(0.7)
                              : accent.withOpacity(0.7)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Slot cards for this date
              ...dateSlots.map((s) => _SlotCard(
                    slot: s,
                    accent: accent,
                    typeLabel: _typeLabel(),
                  )),

              if (dateIndex < sortedDates.length - 1)
                const Divider(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// --- Single slot card ---

class _SlotCard extends StatelessWidget {
  final TimetableSlot slot;
  final Color accent;
  final String typeLabel;

  const _SlotCard({
    required this.slot,
    required this.accent,
    required this.typeLabel,
  });

  bool _isCurrentTime() {
    if (slot.startTime.isEmpty || slot.startTime == '--:--') return false;
    
    try {
      final now = DateTime.now();
      final startTime = _parseTime(slot.startTime);
      final endTime = slot.endTime.isNotEmpty && slot.endTime != '--:--' 
          ? _parseTime(slot.endTime) 
          : startTime.add(const Duration(hours: 1)); // Default 1 hour duration
      
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

  String _normalizeDayName(String day) {
    if (day.isEmpty) return 'Unscheduled';
    
    final normalizedDay = day.toLowerCase().trim();
    
    switch (normalizedDay) {
      case 'mon':
      case 'monday':
        return 'Monday';
      case 'tue':
      case 'tues':
      case 'tuesday':
        return 'Tuesday';
      case 'wed':
      case 'wednesday':
        return 'Wednesday';
      case 'thu':
      case 'thur':
      case 'thurs':
      case 'thursday':
        return 'Thursday';
      case 'fri':
      case 'friday':
        return 'Friday';
      case 'sat':
      case 'saturday':
        return 'Saturday';
      case 'sun':
      case 'sunday':
        return 'Sunday';
      default:
        if (['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].contains(day)) {
          return day;
        }
        return day.contains('-') ? day : 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format time display
    String timeDisplay = '';
    if (slot.startTime.isNotEmpty && slot.startTime != '--:--') {
      timeDisplay = slot.startTime;
      if (slot.endTime.isNotEmpty && slot.endTime != '--:--') {
        timeDisplay += ' - ${slot.endTime}';
      }
    }
    
    final isCurrentTime = _isCurrentTime();
    final dayName = _normalizeDayName(slot.day);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            isCurrentTime 
                ? Colors.green.withAlpha(20)
                : accent.withAlpha(13),
          ],
        ),
        border: Border.all(
          color: isCurrentTime 
              ? Colors.green.withOpacity(0.4)
              : accent.withOpacity(0.2),
          width: isCurrentTime ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentTime 
                ? Colors.green.withAlpha(26)
                : Theme.of(context).shadowColor.withAlpha(13),
            blurRadius: isCurrentTime ? 12 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentTime 
                        ? Colors.green.withOpacity(0.15)
                        : accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCurrentTime 
                        ? Icons.live_tv_rounded
                        : Icons.event_note_rounded,
                    color: isCurrentTime ? Colors.green : accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            slot.courseCode,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isCurrentTime ? Colors.green : accent,
                            ),
                          ),
                          if (isCurrentTime) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (slot.courseName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          slot.courseName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrentTime 
                        ? Colors.green.withOpacity(0.15)
                        : accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isCurrentTime ? Colors.green : accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Day row
            if (dayName.isNotEmpty && dayName != 'Unscheduled')
              _buildInfoRow(
                context,
                Icons.calendar_today_rounded,
                'Day',
                dayName,
                isHighlighted: isCurrentTime,
              ),
            if (dayName.isNotEmpty && dayName != 'Unscheduled') const SizedBox(height: 8),
            
            // Time row
            if (timeDisplay.isNotEmpty)
              _buildInfoRow(
                context,
                Icons.access_time_rounded,
                'Time',
                timeDisplay,
                isHighlighted: isCurrentTime,
              ),
            if (timeDisplay.isNotEmpty) const SizedBox(height: 8),
            
            // Venue row
            _buildInfoRow(
              context,
              Icons.location_on_rounded,
              'Venue',
              slot.venue.isNotEmpty ? slot.venue : 'TBA',
              isHighlighted: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value, {bool isHighlighted = false}) {
    // Don't show empty time ranges
    if (value.trim().isEmpty || value == '--:-- - --:--' || value == '--:--') {
      return const SizedBox.shrink();
    }
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isHighlighted 
              ? Colors.green
              : Theme.of(context).textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isHighlighted 
                ? Colors.green
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isHighlighted 
                  ? Colors.green
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }
}
