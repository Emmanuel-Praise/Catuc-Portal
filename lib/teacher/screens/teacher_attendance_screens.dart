import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../models/teacher_attendance_record.dart';
import '../models/teacher_course.dart';
import '../models/teacher_session.dart';
import '../services/teacher_api_service.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class TeacherAttendanceSelectionScreen extends StatefulWidget {
  final TeacherSession user;
  final TeacherCourse course;
  final bool readOnly;

  const TeacherAttendanceSelectionScreen({
    super.key,
    required this.user,
    required this.course,
    this.readOnly = false,
  });

  @override
  State<TeacherAttendanceSelectionScreen> createState() =>
      _TeacherAttendanceSelectionScreenState();
}

class _TeacherAttendanceSelectionScreenState
    extends State<TeacherAttendanceSelectionScreen> {
  final TeacherApiService _api = const TeacherApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<TeacherAttendanceSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
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
                hintText: 'e.g. Attendance sessions are not loading...',
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
                  role: 'lecturer',
                  issueType: 'Teacher Attendance Error',
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

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await _api.fetchAttendanceSessions(
        teacherId: widget.user.userId,
        sectionId: widget.course.sectionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAllSessionsSheet() {
    if (_sessions.isEmpty) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Text(
              'Attendance Sessions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            for (final session in _sessions)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(session.classDate),
                  subtitle: Text(
                    'Present ${session.presentCount} - Absent ${session.absentCount}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => TeacherAttendanceSessionDetailScreen(
                          user: widget.user,
                          course: widget.course,
                          classDate: session.classDate,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.course.courseCode}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.lightTextPrimary,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: false,
      backgroundColor: AppColors.lightBackground,
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _AttendanceOptionCard(
                    icon: Icons.add_task_outlined,
                    title: widget.readOnly
                        ? 'Locked Semester'
                        : 'Take New Attendance',
                    subtitle: widget.readOnly
                        ? 'First semester records are read-only'
                        : 'Mark a new class session',
                    color: Colors.purple,
                    onTap: widget.readOnly
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TeacherMarkAttendanceScreen(
                                  user: widget.user,
                                  course: widget.course,
                                  initialDate: _todayString(),
                                  readOnly: widget.readOnly,
                                ),
                              ),
                            );
                            _loadSessions();
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AttendanceOptionCard(
                    icon: Icons.history_outlined,
                    title: 'Previous Records',
                    subtitle: 'View all sessions',
                    color: Colors.blue,
                    onTap: _sessions.isEmpty ? null : _showAllSessionsSheet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Attendance Sessions',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              AppErrorWidget(
                error: _errorMessage,
                onRetry: _loadSessions,
                onReport: () => _showReportDialog(_errorMessage),
              )
            else if (_sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text('No attendance has been recorded yet.'),
                ),
              )
            else
              for (final session in _sessions)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.green,
                      ),
                    ),
                    title: Text(session.classDate),
                    subtitle: Text(
                      'Present ${session.presentCount} - Absent ${session.absentCount}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TeacherAttendanceSessionDetailScreen(
                            user: widget.user,
                            course: widget.course,
                            classDate: session.classDate,
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class TeacherMarkAttendanceScreen extends StatefulWidget {
  final TeacherSession user;
  final TeacherCourse course;
  final String initialDate;
  final bool readOnly;

  const TeacherMarkAttendanceScreen({
    super.key,
    required this.user,
    required this.course,
    required this.initialDate,
    this.readOnly = false,
  });

  @override
  State<TeacherMarkAttendanceScreen> createState() =>
      _TeacherMarkAttendanceScreenState();
}

class _TeacherMarkAttendanceScreenState
    extends State<TeacherMarkAttendanceScreen> {
  final TeacherApiService _api = const TeacherApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  late String _selectedDate;
  List<TeacherAttendanceRecord> _records = [];
  final Map<String, String> _selectedStatuses = {};

  String _normalizeStatus(String value) {
    return value.toLowerCase() == 'absent' ? 'absent' : 'present';
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
                hintText: 'e.g. Students are not showing for this date...',
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
                  role: 'lecturer',
                  issueType: 'Teacher Attendance Record Error',
                  description: controller.text.trim(),
                  additionalData: {
                    'courseId': widget.course.courseId,
                    'date': _selectedDate,
                    'error': error.toString(),
                  },
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
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _loadRecords();
  }

  Future<void> _pickDate() async {
    final parts = _selectedDate.split('-');
    final initialDate = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _api.fetchAttendanceRecords(
        teacherId: widget.user.userId,
        sectionId: widget.course.sectionId,
        classDate: _selectedDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _selectedStatuses
          ..clear()
          ..addEntries(
            records.map(
              (record) => MapEntry(
                record.enrollmentId,
                _normalizeStatus(record.status),
              ),
            ),
          );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, List<TeacherAttendanceRecord>> _groupedRecords() {
    final grouped = <String, List<TeacherAttendanceRecord>>{};
    for (final record in _records) {
      final key = record.programName.trim().isNotEmpty
          ? record.programName.trim()
          : 'Other Programs';
      grouped.putIfAbsent(key, () => []).add(record);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sorted = <String, List<TeacherAttendanceRecord>>{};
    for (final key in sortedKeys) {
      final records = [...grouped[key]!]
        ..sort((a, b) {
          final lastNameCompare = a.lastName.toLowerCase().compareTo(
            b.lastName.toLowerCase(),
          );
          if (lastNameCompare != 0) {
            return lastNameCompare;
          }
          return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
        });
      sorted[key] = records;
    }
    return sorted;
  }

  Future<void> _saveAttendance() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _api.saveAttendance(
        teacherId: widget.user.userId,
        sectionId: widget.course.sectionId,
        classDate: _selectedDate,
        entries: _records
            .map(
              (record) => {
                'enrollment_id': record.enrollmentId,
                'status': _selectedStatuses[record.enrollmentId] ?? 'present',
                'notes': record.notes,
              },
            )
            .toList(),
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully')),
      );
      _loadRecords();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedRecords();

    return Scaffold(
      appBar: AppBar(
        title: Text('Take Attendance - ${widget.course.courseCode}'),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: widget.readOnly ? null : _pickDate,
            icon: const Icon(Icons.edit_calendar_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? AppErrorWidget(
              error: _errorMessage,
              onRetry: _loadRecords,
              onReport: () => _showReportDialog(_errorMessage),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.lightBackground,
                  child: Text(
                    'Class Date: $_selectedDate',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in grouped.entries) ...[
                        _AttendanceDepartmentSection(
                          title: entry.key,
                          records: entry.value,
                          readOnly: widget.readOnly,
                          selectedStatuses: _selectedStatuses,
                          onStatusChanged: (enrollmentId, status) {
                            setState(() {
                              _selectedStatuses[enrollmentId] = status;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.readOnly || _isSaving
                            ? null
                            : _saveAttendance,
                        child: Text(
                          widget.readOnly
                              ? 'Read Only'
                              : (_isSaving ? 'Saving...' : 'Save Attendance'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class TeacherAttendanceSessionDetailScreen extends StatefulWidget {
  final TeacherSession user;
  final TeacherCourse course;
  final String classDate;

  const TeacherAttendanceSessionDetailScreen({
    super.key,
    required this.user,
    required this.course,
    required this.classDate,
  });

  @override
  State<TeacherAttendanceSessionDetailScreen> createState() =>
      _TeacherAttendanceSessionDetailScreenState();
}

class _TeacherAttendanceSessionDetailScreenState
    extends State<TeacherAttendanceSessionDetailScreen> {
  final TeacherApiService _api = const TeacherApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<TeacherAttendanceRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _api.fetchAttendanceRecords(
        teacherId: widget.user.userId,
        sectionId: widget.course.sectionId,
        classDate: widget.classDate,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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
                hintText: 'e.g. Session details are incorrect...',
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
                  role: 'lecturer',
                  issueType: 'Teacher Attendance Session Detail Error',
                  description: controller.text.trim(),
                  additionalData: {
                    'courseId': widget.course.courseId,
                    'classDate': widget.classDate,
                    'error': error.toString(),
                  },
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

  Map<String, List<TeacherAttendanceRecord>> _groupedRecords() {
    final grouped = <String, List<TeacherAttendanceRecord>>{};
    for (final record in _records) {
      final key = record.programName.trim().isNotEmpty
          ? record.programName.trim()
          : 'Other Programs';
      grouped.putIfAbsent(key, () => []).add(record);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sorted = <String, List<TeacherAttendanceRecord>>{};
    for (final key in sortedKeys) {
      final records = [...grouped[key]!]
        ..sort((a, b) {
          final lastNameCompare = a.lastName.toLowerCase().compareTo(
            b.lastName.toLowerCase(),
          );
          if (lastNameCompare != 0) {
            return lastNameCompare;
          }
          return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
        });
      sorted[key] = records;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedRecords();

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance ${widget.classDate}'),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? AppErrorWidget(
              error: _errorMessage,
              onRetry: _loadRecords,
              onReport: () => _showReportDialog(_errorMessage),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in grouped.entries) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final record in entry.value) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(record.fullName),
                            subtitle: Text(record.studentNumber),
                            trailing: _StatusPill(status: record.status),
                          ),
                          if (record != entry.value.last)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

class _AttendanceOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _AttendanceOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  title, 
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceDepartmentSection extends StatelessWidget {
  final String title;
  final List<TeacherAttendanceRecord> records;
  final bool readOnly;
  final Map<String, String> selectedStatuses;
  final void Function(String enrollmentId, String status) onStatusChanged;

  const _AttendanceDepartmentSection({
    required this.title,
    required this.records,
    required this.readOnly,
    required this.selectedStatuses,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          for (final record in records) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        record.studentNumber,
                        style: const TextStyle(
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AttendanceStatusButton(
                      label: 'Present',
                      selected:
                          (selectedStatuses[record.enrollmentId] ??
                              'present') ==
                          'present',
                      selectedColor: Colors.green,
                      enabled: !readOnly,
                      onTap: () =>
                          onStatusChanged(record.enrollmentId, 'present'),
                    ),
                    const SizedBox(width: 8),
                    _AttendanceStatusButton(
                      label: 'Absent',
                      selected:
                          (selectedStatuses[record.enrollmentId] ??
                              'present') ==
                          'absent',
                      selectedColor: Colors.red,
                      enabled: !readOnly,
                      onTap: () =>
                          onStatusChanged(record.enrollmentId, 'absent'),
                    ),
                  ],
                ),
              ],
            ),
            if (record != records.last) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase() == 'absent' ? 'absent' : 'present';
    final color = normalized == 'present' ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized[0].toUpperCase() + normalized.substring(1),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AttendanceStatusButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final bool enabled;
  final VoidCallback onTap;

  const _AttendanceStatusButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

