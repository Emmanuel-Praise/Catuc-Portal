import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/student_home_data.dart';

class StudentEventsScreen extends StatefulWidget {
  final List<HomeEvent> events;

  const StudentEventsScreen({super.key, required this.events});

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen> {
  String _selectedMonthKey = 'all';

  DateTime? _parseEventDateTime(HomeEvent e) {
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

  @override
  Widget build(BuildContext context) {
    final sortedEvents = [...widget.events]..sort((a, b) {
        final adt = _parseEventDateTime(a);
        final bdt = _parseEventDateTime(b);
        if (adt == null && bdt == null) return a.name.compareTo(b.name);
        if (adt == null) return 1;
        if (bdt == null) return -1;
        return adt.compareTo(bdt);
      });

    final monthKeys = <String>{};
    for (final e in sortedEvents) {
      monthKeys.add(_monthKey(_parseEventDateTime(e)));
    }

    final months = monthKeys.toList()
      ..remove('unknown')
      ..sort();
    final hasUnknown = monthKeys.contains('unknown');
    final options = [
      'all',
      ...months,
      if (hasUnknown) 'unknown',
    ];

    final selectedKey = options.contains(_selectedMonthKey) ? _selectedMonthKey : 'all';
    if (selectedKey != _selectedMonthKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedMonthKey = 'all');
      });
    }

    final visibleEvents = selectedKey == 'all'
        ? sortedEvents
        : sortedEvents.where((e) => _monthKey(_parseEventDateTime(e)) == selectedKey).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Events')),
      body: sortedEvents.isEmpty
          ? const Center(child: Text('No upcoming events.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedKey,
                    items: [
                      for (final key in options)
                        DropdownMenuItem(
                          value: key,
                          child: Text(_labelForMonthKey(key), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedMonthKey = v);
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Filter by month',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: visibleEvents.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_busy_rounded,
                                  size: 48,
                                  color: Theme.of(context).disabledColor,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No events for this month',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: () => setState(() => _selectedMonthKey = 'all'),
                                  child: const Text('Show all months'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: visibleEvents.length,
                          itemBuilder: (context, index) {
                            final e = visibleEvents[index];
                            final subtitleParts = [
                              e.eventDate.trim(),
                              e.startTime.trim(),
                              e.location.trim(),
                            ].where((p) => p.isNotEmpty).toList();

                            return Card(
                              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.event_rounded)),
                                title: Text(e.name),
                                subtitle: Text(subtitleParts.join(' • ')),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
