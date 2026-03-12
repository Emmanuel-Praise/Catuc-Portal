import 'package:flutter/material.dart';
import '../models/dean_session.dart';
import '../models/dean_student_course.dart';
import '../services/dean_api_service.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanStudentCourseOverviewScreen extends StatefulWidget {
  final DeanSession user;

  const DeanStudentCourseOverviewScreen({super.key, required this.user});

  @override
  State<DeanStudentCourseOverviewScreen> createState() => _DeanStudentCourseOverviewScreenState();
}

class _DeanStudentCourseOverviewScreenState extends State<DeanStudentCourseOverviewScreen> {
  late Future<List<DeanStudentCourse>> _future;
  final _searchController = TextEditingController();
  List<DeanStudentCourse> _allData = [];
  List<DeanStudentCourse> _filteredData = [];
  int? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadData() {
    setState(() {
      _future = const DeanApiService().fetchStudentCourses(widget.user.facultyId ?? '').then((list) {
        _allData = list;
        _applyFilters();
        return list;
      });
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredData = _allData.where((item) {
        final matchesSearch = item.studentName.toLowerCase().contains(query) ||
            item.matricule.toLowerCase().contains(query) ||
            item.courseCode.toLowerCase().contains(query);
        final matchesLevel = _selectedLevel == null || item.level == _selectedLevel;
        return matchesSearch && matchesLevel;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student-Course Overview'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          _buildFilterHeader(primaryColor),
          Expanded(
            child: FutureBuilder<List<DeanStudentCourse>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AppErrorWidget(error: snapshot.error, onRetry: _loadData);
                }
                if (_filteredData.isEmpty) {
                  return const Center(child: Text('No matching records found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredData.length,
                  itemBuilder: (context, index) => _buildStudentRecord(_filteredData[index], primaryColor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, matricule or course...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLevelChip(null, 'All Levels', primaryColor),
                _buildLevelChip(100, '100L', primaryColor),
                _buildLevelChip(200, '200L', primaryColor),
                _buildLevelChip(300, '300L', primaryColor),
                _buildLevelChip(400, '400L', primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip(int? level, String label, Color primaryColor) {
    final isSelected = _selectedLevel == level;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _selectedLevel = level;
            _applyFilters();
          });
        },
        selectedColor: primaryColor.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? primaryColor : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildStudentRecord(DeanStudentCourse record, Color primaryColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(record.matricule, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                _buildStatusBadge(record.enrollmentStatus),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(record.courseCode, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(record.courseName, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Lecturer: ${record.lecturerName ?? "Unassigned"}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Spacer(),
                if (record.grade != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('Grade: ${record.grade}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isCompleted = status.toLowerCase() == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: isCompleted ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
