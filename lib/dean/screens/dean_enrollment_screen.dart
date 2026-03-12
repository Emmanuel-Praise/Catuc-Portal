import 'package:flutter/material.dart';
import '../models/dean_session.dart';
import '../services/dean_api_service.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanEnrollmentScreen extends StatefulWidget {
  final DeanSession user;

  const DeanEnrollmentScreen({super.key, required this.user});

  @override
  State<DeanEnrollmentScreen> createState() => _DeanEnrollmentScreenState();
}

class _DeanEnrollmentScreenState extends State<DeanEnrollmentScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allEnrollments = [];
  List<Map<String, dynamic>> _filteredEnrollments = [];
  
  String? _selectedLevel;
  String? _selectedSemester;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadEnrollments() {
    setState(() {
      _future = _fetchEnrollments();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchEnrollments() async {
    final list = await const DeanApiService().fetchEnrollments(
      facultyId: widget.user.facultyId ?? '',
      level: _selectedLevel,
      semester: _selectedSemester,
      courseId: _selectedCourseId,
    );
    
    _allEnrollments = list;
    _filteredEnrollments = list;
    return list;
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEnrollments = _allEnrollments.where((e) {
        final name = '${e['first_name']} ${e['last_name']}'.toLowerCase();
        final matricule = (e['matricule'] ?? '').toString().toLowerCase();
        return name.contains(query) || matricule.contains(query);
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
      appBar: AppBar(title: const Text('Enrollment Manager')),
      body: Column(
        children: [
          _buildFilters(primaryColor),
          _buildSearch(primaryColor),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AppErrorWidget(error: snapshot.error, onRetry: _loadEnrollments);
                }
                if (_filteredEnrollments.isEmpty) {
                  return const Center(child: Text('No enrollments found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredEnrollments.length,
                  itemBuilder: (context, index) {
                    final enrollment = _filteredEnrollments[index];
                    return _buildEnrollmentCard(enrollment, primaryColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLevel,
                hint: const Text('Level'),
                isExpanded: true,
                items: ['1', '2', '3', '4'].map((l) => DropdownMenuItem(value: l, child: Text('L\${int.parse(l)*100}'))).toList()
                  ..insert(0, const DropdownMenuItem(value: null, child: Text('All Levels'))),
                onChanged: (v) {
                  setState(() => _selectedLevel = v);
                  _loadEnrollments();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSemester,
                hint: const Text('Semester'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Sem')),
                  const DropdownMenuItem(value: '1', child: Text('1st Sem')),
                  const DropdownMenuItem(value: '2', child: Text('2nd Sem')),
                ],
                onChanged: (v) {
                  setState(() => _selectedSemester = v);
                  _loadEnrollments();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search student or matricule...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildEnrollmentCard(Map<String, dynamic> e, Color primaryColor) {
    final status = e['status'].toString();
    final isCompleted = status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Text(e['last_name'][0], style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${e['first_name']} ${e['last_name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(e['matricule'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'Enrolled',
                    style: TextStyle(color: isCompleted ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.book_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  "${e['course_code']} - ${e['course_name']}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.school_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  "Level ${int.parse(e['level'].toString()) * 100} • ${e['program_name']}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showReassignDialog(e),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Reassign Course'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReassignDialog(Map<String, dynamic> enrollment) {
    // This would fetch alternatives and show a list
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reassign Student'),
        content: Text("Reassign ${enrollment['first_name']} to a different course section?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Proceed')),
        ],
      ),
    );
  }
}
