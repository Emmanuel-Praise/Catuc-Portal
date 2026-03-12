import 'package:flutter/material.dart';
import '../models/dean_session.dart';
import '../models/dean_course.dart';
import '../services/dean_api_service.dart';
import 'dean_batch_results_screen.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanResultsScreen extends StatefulWidget {
  final DeanSession user;

  const DeanResultsScreen({super.key, required this.user});

  @override
  State<DeanResultsScreen> createState() => _DeanResultsScreenState();
}

class _DeanResultsScreenState extends State<DeanResultsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>> _allResults = [];
  List<Map<String, dynamic>> _filteredResults = [];
  final Set<String> _selectedIds = {};
  bool _isBulkMode = false;
  final TextEditingController _searchController = TextEditingController();
  
  String? _selectedSemester;
  String? _selectedLevel;
  String? _selectedCourseId;
  List<DeanCourse> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadInitialData() async {
    _loadResults();
    try {
       final courses = await const DeanApiService().fetchCourses(widget.user.facultyId ?? '');
       setState(() => _courses = courses);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredResults = List.from(_allResults);
      } else {
        _filteredResults = _allResults.where((res) {
          final name = "${res['first_name']} ${res['last_name']}".toLowerCase();
          final matricule = res['matricule'].toString().toLowerCase();
          final courseCode = res['course_code'].toString().toLowerCase();
          final courseName = res['course_name'].toString().toLowerCase();
          return name.contains(query) || 
                 matricule.contains(query) || 
                 courseCode.contains(query) || 
                 courseName.contains(query);
        }).toList();
      }
    });
  }

  void _loadResults() {
    setState(() {
      _future = _fetchResults();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchResults() async {
    final query = <String, String>{
      'faculty_id': widget.user.facultyId ?? '',
    };
    if (_selectedSemester != null) query['semester'] = _selectedSemester!;
    if (_selectedLevel != null) query['level'] = _selectedLevel!;
    if (_selectedCourseId != null) query['course_id'] = _selectedCourseId!;

    final data = await const DeanApiService().getWithCache('dean_results.php', query: query);
    final list = List<Map<String, dynamic>>.from(data['results'] as List? ?? []);
    _allResults = list;
    _onSearchChanged(); // Apply local search on top of backend filters
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Management'),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _approveSelected,
              child: const Text('APPROVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Batch Entry',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeanBatchResultsScreen(user: widget.user))),
          ),
          IconButton(
            icon: Icon(_isBulkMode ? Icons.close : Icons.select_all),
            onPressed: () => setState(() {
              _isBulkMode = !_isBulkMode;
              if (!_isBulkMode) _selectedIds.clear();
            }),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorWidget(error: snapshot.error, onRetry: _loadResults);
          }
          if (_allResults.isEmpty) {
            return const Center(child: Text('No results pending review.'));
          }

          return Column(
            children: [
              _buildFilters(primaryColor),
              _buildSearchBox(),
              Expanded(
                child: _filteredResults.isEmpty
                    ? const Center(child: Text('No matching results found.'))
                    : _buildGroupedResults(primaryColor),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedSemester,
                  decoration: const InputDecoration(labelText: 'Semester', isDense: true),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: '1', child: Text('Sem 1')),
                    DropdownMenuItem(value: '2', child: Text('Sem 2')),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedSemester = v);
                    _loadResults();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  decoration: const InputDecoration(labelText: 'Level', isDense: true),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: '100', child: Text('100L')),
                    DropdownMenuItem(value: '200', child: Text('200L')),
                    DropdownMenuItem(value: '300', child: Text('300L')),
                    DropdownMenuItem(value: '400', child: Text('400L')),
                    DropdownMenuItem(value: '500', child: Text('500L')),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedLevel = v);
                    _loadResults();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCourseId,
            decoration: const InputDecoration(labelText: 'Select Course', isDense: true, prefixIcon: Icon(Icons.book_rounded, size: 20)),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Courses')),
              ..._courses.map((c) => DropdownMenuItem(value: c.courseId, child: Text('${c.courseCode} - ${c.courseName}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: (v) {
              setState(() => _selectedCourseId = v);
              _loadResults();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by student name or matricule...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildGroupedResults(Color primaryColor) {
    // Group results by course
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final res in _filteredResults) {
      final key = "${res['course_code']} - ${res['course_name']}";
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(res);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final courseKey = sortedKeys[index];
        final courseResults = grouped[courseKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                   Icon(Icons.menu_book_rounded, size: 18, color: primaryColor),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                        courseKey,
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
                      ),
                   ),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                     decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                     child: Text("${courseResults.length}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
                   ),
                ],
              ),
            ),
            ...courseResults.map((res) => _buildResultCard(res, primaryColor)),
          ],
        );
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> res, Color primaryColor) {
    final isSelected = _selectedIds.contains(res['result_id']);
    final status = res['status'].toString();
    final isApproved = status == 'approved';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected ? BorderSide(color: primaryColor, width: 2) : BorderSide.none,
      ),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onLongPress: () => setState(() {
          _isBulkMode = true;
          _selectedIds.add(res['result_id'].toString());
        }),
        onTap: () {
          if (_isBulkMode) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(res['result_id'].toString());
              } else {
                _selectedIds.add(res['result_id'].toString());
              }
            });
          } else {
            _showEditDialog(res);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        Text("${res['first_name']} ${res['last_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(res['matricule'].toString(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildGradeBadge(res['grade'].toString()),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${res['course_code']} - ${res['course_name']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text("CA: ${res['ca_score']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(width: 12),
                            Text("Exam: ${res['exam_score']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(width: 12),
                            Text("Total: ${res['total_score']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isApproved)
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                  else
                    Icon(Icons.pending_actions_rounded, color: Colors.orange[400], size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeBadge(String grade) {
    Color color;
    switch (grade) {
      case 'A': color = Colors.green; break;
      case 'B': color = Colors.blue; break;
      case 'C': color = Colors.teal; break;
      case 'D': color = Colors.orange; break;
      case 'E': color = Colors.deepOrange; break;
      default: color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(grade, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  void _showEditDialog(Map<String, dynamic> res) {
    // Dialog to adjust scores if needed
  }

  void _approveSelected() async {
    try {
      await const DeanApiService().postWithFallback('dean_results.php', body: {
        'action': 'approve',
        'result_ids': _selectedIds.toList(),
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedIds.length} results approved!')));
      _selectedIds.clear();
      _isBulkMode = false;
      _loadResults();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    }
  }
}
