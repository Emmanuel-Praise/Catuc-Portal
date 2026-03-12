import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../models/teacher_home_data.dart';
import '../models/teacher_session.dart';
import '../services/teacher_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class TeacherEventsScreen extends StatefulWidget {
  final TeacherSession user;

  const TeacherEventsScreen({super.key, required this.user});

  @override
  State<TeacherEventsScreen> createState() => _TeacherEventsScreenState();
}

class _TeacherEventsScreenState extends State<TeacherEventsScreen> {
  final TeacherApiService _api = const TeacherApiService();
  late Future<List<TeacherEvent>> _future;
  String _selectedMonthKey = 'all';
  List<String> _monthOptions = const ['all'];

  @override
  void initState() {
    super.initState();
    _future = _api.fetchTeacherEvents(widget.user.userId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchTeacherEvents(widget.user.userId);
    });
  }

  DateTime? _parseEventDateTime(TeacherEvent e) {
    final d = DateTime.tryParse(e.eventDate.trim());
    if (d == null) return null;

    final t = e.startTime.trim();
    if (t.isEmpty) return DateTime(d.year, d.month, d.day);

    final parts = t.split(':');
    if (parts.isEmpty) return DateTime(d.year, d.month, d.day);

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  String _monthKey(DateTime? d) {
    if (d == null) return 'unknown';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  String _labelForMonthKey(String key) {
    if (key == 'all') return 'All months';
    if (key == 'unknown') return 'Unknown date';
    final parts = key.split('-');
    final year = int.tryParse(parts.first) ?? 0;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    return DateFormat('MMMM yyyy').format(DateTime(year, month));
  }

  List<String> _buildMonthOptions(List<TeacherEvent> events) {
    final keys = <String>{};
    for (final e in events) {
      keys.add(_monthKey(_parseEventDateTime(e)));
    }
    final months = keys.toList()
      ..remove('unknown')
      ..sort();
    final hasUnknown = keys.contains('unknown');
    return ['all', ...months, if (hasUnknown) 'unknown'];
  }

  void _syncMonthOptions(List<String> next) {
    if (_monthOptions.length == next.length) {
      bool same = true;
      for (int i = 0; i < next.length; i++) {
        if (_monthOptions[i] != next[i]) {
          same = false;
          break;
        }
      }
      if (same) return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _monthOptions = next);
    });
  }

  void _showReportDialog(dynamic error) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                hintText: 'e.g. Events are not loading...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await const ReportService().submitReport(
                  userId: widget.user.userId,
                  role: 'lecturer',
                  issueType: 'Teacher Events Error',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString()},
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully. Thank you!')),
                );
              } catch (e) {
                if (!mounted) return;
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

  Future<void> _showCreateEventSheet() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    DateTime? date;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    bool isPublic = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + viewInsets.bottom),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'New Event',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Event name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                firstDate: DateTime.now().subtract(const Duration(days: 0)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                initialDate: date ?? DateTime.now(),
                              );
                              if (picked == null) return;
                              setModalState(() => date = picked);
                            },
                            icon: const Icon(Icons.calendar_today_rounded, size: 18),
                            label: Text(
                              date == null
                                  ? 'Pick date'
                                  : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (picked == null) return;
                              setModalState(() => startTime = picked);
                            },
                            icon: const Icon(Icons.schedule_rounded, size: 18),
                            label: Text(startTime == null ? 'Start time' : startTime!.format(ctx)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: endTime ?? (startTime ?? TimeOfDay.now()),
                        );
                        if (picked == null) return;
                        setModalState(() => endTime = picked);
                      },
                      icon: const Icon(Icons.timer_rounded, size: 18),
                      label: Text(endTime == null ? 'End time (optional)' : endTime!.format(ctx)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isPublic,
                      onChanged: (v) => setModalState(() => isPublic = v),
                      title: const Text('Public event'),
                      subtitle: const Text('Visible to everyone in the app'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty || date == null || startTime == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Name, date, and start time are required')),
                            );
                            return;
                          }

                          final dateStr =
                              '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}';
                          String toTimeStr(TimeOfDay t) =>
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

                          try {
                            await _api.createTeacherEvent(
                              teacherId: widget.user.userId,
                              name: name,
                              description: descriptionController.text.trim().isEmpty
                                  ? null
                                  : descriptionController.text.trim(),
                              eventDate: dateStr,
                              startTime: toTimeStr(startTime!),
                              endTime: endTime == null ? null : toTimeStr(endTime!),
                              location: locationController.text.trim().isEmpty
                                  ? null
                                  : locationController.text.trim(),
                              isPublic: isPublic,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _reload();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Event created')),
                            );
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Failed to create event: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Event'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'New event',
            onPressed: _showCreateEventSheet,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter by month',
            initialValue: _selectedMonthKey,
            onSelected: (v) => setState(() => _selectedMonthKey = v),
            itemBuilder: (context) => [
              for (final key in _monthOptions)
                PopupMenuItem<String>(
                  value: key,
                  child: Row(
                    children: [
                      if (_selectedMonthKey == key) ...[
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                      ] else
                        const SizedBox(width: 26),
                      Expanded(child: Text(_labelForMonthKey(key))),
                    ],
                  ),
                ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.filter_list_rounded),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<TeacherEvent>>(
        future: _future,
        builder: (context, snapshot) {
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

          final rawEvents = snapshot.data ?? const [];
          if (rawEvents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy_rounded, size: 48, color: Theme.of(context).disabledColor),
                    const SizedBox(height: 12),
                    const Text(
                      'No events yet',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap + to create an event.',
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
            );
          }

          final sortedEvents = [...rawEvents]..sort((a, b) {
              final adt = _parseEventDateTime(a);
              final bdt = _parseEventDateTime(b);
              if (adt == null && bdt == null) return a.name.compareTo(b.name);
              if (adt == null) return 1;
              if (bdt == null) return -1;
              return adt.compareTo(bdt);
            });

          final nextOptions = _buildMonthOptions(sortedEvents);
          _syncMonthOptions(nextOptions);
          final selectedKey = nextOptions.contains(_selectedMonthKey) ? _selectedMonthKey : 'all';
          if (selectedKey != _selectedMonthKey) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectedMonthKey = 'all');
            });
          }

          final events = selectedKey == 'all'
              ? sortedEvents
              : sortedEvents.where((e) => _monthKey(_parseEventDateTime(e)) == selectedKey).toList();

          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_alt_off_rounded, size: 44, color: Theme.of(context).disabledColor),
                    const SizedBox(height: 12),
                    const Text(
                      'No events for this month',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Change the month filter to see more events.',
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => setState(() => _selectedMonthKey = 'all'),
                      child: const Text('Show all months'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final e = events[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.event_rounded, color: AppColors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.name,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${e.eventDate} • ${e.startTime}${e.location == null || e.location!.trim().isEmpty ? '' : ' • ${e.location}'}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (e.description != null && e.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          e.description!.trim(),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
