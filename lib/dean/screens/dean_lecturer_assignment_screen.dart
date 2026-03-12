import 'package:flutter/material.dart';
import '../models/dean_course.dart';
import '../models/dean_session.dart';
import '../services/dean_api_service.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanLecturerAssignmentScreen extends StatefulWidget {
  final DeanSession user;

  const DeanLecturerAssignmentScreen({super.key, required this.user});

  @override
  State<DeanLecturerAssignmentScreen> createState() => _DeanLecturerAssignmentScreenState();
}

class _DeanLecturerAssignmentScreenState extends State<DeanLecturerAssignmentScreen> {
  late Future<Map<String, dynamic>> _futureData;
  List<DeanCourse> _courses = [];
  List<Map<String, dynamic>> _lecturers = [];
  
  String? _selectedCourseId;
  String? _selectedLecturerId;
  String _academicYear = '2025/2026';
  String _semester = '1';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _futureData = Future.wait([
        const DeanApiService().fetchCourses(widget.user.facultyId ?? ''),
        const DeanApiService().fetchLecturers(widget.user.facultyId ?? ''),
      ]).then((results) {
        _courses = results[0] as List<DeanCourse>;
        _lecturers = results[1] as List<Map<String, dynamic>>;
        return {'courses': _courses, 'lecturers': _lecturers};
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Lecturer Assignment')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorWidget(error: snapshot.error, onRetry: _loadData);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(primaryColor),
                const SizedBox(height: 24),
                _buildAssignmentForm(primaryColor),
                const SizedBox(height: 32),
                Text(
                  'Current Assignments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildAssignmentsList(primaryColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Assign lecturers to specific courses for the selected academic year and semester.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentForm(Color primaryColor) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedCourseId,
          decoration: const InputDecoration(labelText: 'Select Course', prefixIcon: Icon(Icons.book_rounded)),
          items: _courses.map((c) => DropdownMenuItem(
            value: c.courseId,
            child: Text('\${c.courseCode} - \${c.courseName}', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) => setState(() => _selectedCourseId = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedLecturerId,
          decoration: const InputDecoration(labelText: 'Select Lecturer', prefixIcon: Icon(Icons.person_rounded)),
          items: _lecturers.map((l) => DropdownMenuItem(
            value: l['user_id'].toString(),
            child: Text('\${l["first_name"]} \${l["last_name"]}'),
          )).toList(),
          onChanged: (v) => setState(() => _selectedLecturerId = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _semester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('First Semester')),
                  DropdownMenuItem(value: '2', child: Text('Second Semester')),
                ],
                onChanged: (v) => setState(() => _semester = v ?? '1'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: _academicYear,
                decoration: const InputDecoration(labelText: 'Academic Year'),
                onChanged: (v) => _academicYear = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: _submitting 
            ? const Center(child: CircularProgressIndicator())
            : FilledButton.icon(
                onPressed: _assign,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Assign Lecturer'),
              ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsList(Color primaryColor) {
    final assigned = _courses.where((c) => c.lecturerName != null).toList();
    if (assigned.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No lecturers assigned to courses yet.')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assigned.length,
      itemBuilder: (context, index) {
        final course = assigned[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            title: Text('${course.courseCode} - ${course.courseName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Lecturer: ${course.lecturerName}', style: TextStyle(color: primaryColor, fontSize: 12)),
          ),
        );
      },
    );
  }

  void _assign() async {
    if (_selectedCourseId == null || _selectedLecturerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both course and lecturer')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await const DeanApiService().assignLecturer(
        courseId: _selectedCourseId!,
        lecturerId: _selectedLecturerId!,
        academicYear: _academicYear,
        semester: _semester,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment successful!')));
      _loadData();
      setState(() {
        _selectedCourseId = null;
        _selectedLecturerId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _submitting = false);
    }
  }
}

