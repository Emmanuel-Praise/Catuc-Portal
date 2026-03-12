import 'package:flutter/material.dart';
import '../models/dean_session.dart';
import '../services/dean_api_service.dart';
import '../../theme/theme_service.dart';

class DeanBatchResultsScreen extends StatefulWidget {
  final DeanSession user;
  final String? initialCourseId;

  const DeanBatchResultsScreen({super.key, required this.user, this.initialCourseId});

  @override
  State<DeanBatchResultsScreen> createState() => _DeanBatchResultsScreenState();
}

class _DeanBatchResultsScreenState extends State<DeanBatchResultsScreen> {
  String? _selectedCourseId;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = false;
  final Map<String, TextEditingController> _caControllers = {};
  final Map<String, TextEditingController> _examControllers = {};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final list = await const DeanApiService().fetchCourses(widget.user.facultyId ?? '');
      setState(() {
        _courses = list.map((e) => {'id': e.courseId, 'name': '${e.courseCode} - ${e.courseName}'}).toList();
        if (widget.initialCourseId != null) {
          _selectedCourseId = widget.initialCourseId;
          _loadStudents();
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadStudents() async {
    if (_selectedCourseId == null) return;
    setState(() => _isLoading = true);
    try {
      final list = await const DeanApiService().fetchCourseStudents(_selectedCourseId!);
      
      // Initialize controllers
      _caControllers.clear();
      _caControllers.clear();
      _examControllers.clear();
      for (var s in list) {
        final sid = s['student_id'].toString();
        _caControllers[sid] = TextEditingController(text: s['ca_score']?.toString() ?? '');
        _examControllers[sid] = TextEditingController(text: s['exam_score']?.toString() ?? '');
      }

      setState(() => _students = list);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _saveAll() async {
    setState(() => _isLoading = true);
    try {
      final gradesList = _students.map((s) {
        final sid = s['student_id'].toString();
        return {
          'enrollment_id': s['enrollment_id'],
          'ca': _caControllers[sid]?.text ?? '0',
          'exam': _examControllers[sid]?.text ?? '0',
        };
      }).toList();

      await const DeanApiService().batchSaveGrades(_selectedCourseId!, gradesList);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All grades saved successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Grading'),
        actions: [
          if (_students.isNotEmpty)
            IconButton(icon: const Icon(Icons.save), onPressed: _saveAll),
        ],
      ),
      body: Column(
        children: [
          _buildCoursePicker(primaryColor),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _selectedCourseId == null 
                ? const Center(child: Text('Select a course to start grading'))
                : _students.isEmpty
                  ? const Center(child: Text('No students enrolled in this course.'))
                  : _buildGradesList(primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursePicker(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCourseId,
        items: _courses.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: (val) {
          setState(() {
            _selectedCourseId = val;
            _students.clear();
          });
          _loadStudents();
        },
        decoration: InputDecoration(
          labelText: 'Course Section',
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildGradesList(Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final s = _students[index];
        final sid = s['student_id'].toString();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: Text(s['student_name'][0], style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['student_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(s['matricule'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildScoreField('CA', _caControllers[sid]!, primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildScoreField('EXAM', _examControllers[sid]!, primaryColor),
                    ),
                    const SizedBox(width: 16),
                    _buildTotalPlaceholder(sid, primaryColor),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreField(String label, TextEditingController controller, Color primaryColor) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildTotalPlaceholder(String sid, Color primaryColor) {
    final ca = double.tryParse(_caControllers[sid]?.text ?? '0') ?? 0;
    final ex = double.tryParse(_examControllers[sid]?.text ?? '0') ?? 0;
    final total = ca + ex;
    return Column(
      children: [
        const Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(total.toStringAsFixed(1), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
      ],
    );
  }
}
