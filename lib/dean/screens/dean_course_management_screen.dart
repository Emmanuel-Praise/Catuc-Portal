import 'package:flutter/material.dart';
import '../models/dean_course.dart';
import '../models/dean_session.dart';
import '../services/dean_api_service.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanCourseManagementScreen extends StatefulWidget {
  final DeanSession user;

  const DeanCourseManagementScreen({super.key, required this.user});

  @override
  State<DeanCourseManagementScreen> createState() => _DeanCourseManagementScreenState();
}

class _DeanCourseManagementScreenState extends State<DeanCourseManagementScreen> {
  late Future<List<DeanCourse>> _future;
  final _searchController = TextEditingController();
  List<DeanCourse> _allCourses = [];
  List<DeanCourse> _filteredCourses = [];
  int? _selectedLevel;
  String? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadCourses() {
    setState(() {
      _future = const DeanApiService().fetchCourses(
        widget.user.facultyId ?? '',
        semester: _selectedSemester,
        level: _selectedLevel?.toString(),
      ).then((list) {
        _allCourses = list;
        _filteredCourses = list;
        return list;
      });
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCourses = List.from(_allCourses);
      } else {
        _filteredCourses = _allCourses.where((c) {
          return c.courseName.toLowerCase().contains(query) || 
                 c.courseCode.toLowerCase().contains(query) ||
                 c.departmentName.toLowerCase().contains(query);
        }).toList();
      }
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
        title: const Text('Course Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(primaryColor),
          Expanded(
            child: FutureBuilder<List<DeanCourse>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AppErrorWidget(error: snapshot.error, onRetry: _loadCourses);
                }
                if (_allCourses.isEmpty) {
                  return const Center(child: Text('No courses found in your faculty.'));
                }
                if (_filteredCourses.isEmpty) {
                  return const Center(child: Text('No courses match your search.'));
                }

                return _buildGroupedListView(primaryColor);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCourseEditor(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupedListView(Color primaryColor) {
    // Group first by Department, then by Level
    final Map<String, Map<int, List<DeanCourse>>> grouped = {};

    for (final course in _filteredCourses) {
      final dept = course.departmentName;
      final level = course.courseLevel;

      grouped.putIfAbsent(dept, () => {});
      grouped[dept]!.putIfAbsent(level, () => []);
      grouped[dept]![level]!.add(course);
    }

    // Sort Departments alphabetically
    final sortedDepts = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDepts.length,
      itemBuilder: (context, deptIndex) {
        final deptName = sortedDepts[deptIndex];
        final levelsMap = grouped[deptName]!;

        // Sort levels ascending (100, 200, 300, etc.)
        final sortedLevels = levelsMap.keys.toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Department Header
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.business_rounded, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    deptName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Level Sections within Department
            ...sortedLevels.map((level) {
              final coursesInLevel = levelsMap[level]!;
              // Sort courses within level by code
              coursesInLevel.sort((a, b) => a.courseCode.compareTo(b.courseCode));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      'Level $level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  ...coursesInLevel.map((course) => _buildCourseCard(course, primaryColor)),
                  const SizedBox(height: 8),
                ],
              );
            }),
            const Divider(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildSearchHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Semester Selection Dropdown
          DropdownButtonFormField<String>(
            value: _selectedSemester,
            decoration: const InputDecoration(
              labelText: 'Select Semester',
              isDense: true,
              prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All Semesters')),
              DropdownMenuItem(value: '1', child: Text('Semester 1')),
              DropdownMenuItem(value: '2', child: Text('Semester 2')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedSemester = value;
                _loadCourses();
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, code or department...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Levels', null, _selectedLevel, (val) => setState(() {
                  _selectedLevel = val;
                  _loadCourses();
                })),
                _buildFilterChip('100L', 100, _selectedLevel, (val) => setState(() {
                  _selectedLevel = val;
                  _loadCourses();
                })),
                _buildFilterChip('200L', 200, _selectedLevel, (val) => setState(() {
                  _selectedLevel = val;
                  _loadCourses();
                })),
                _buildFilterChip('300L', 300, _selectedLevel, (val) => setState(() {
                  _selectedLevel = val;
                  _loadCourses();
                })),
                _buildFilterChip('400L', 400, _selectedLevel, (val) => setState(() {
                  _selectedLevel = val;
                  _loadCourses();
                })),
                _buildFilterChip('500L', 500, _selectedLevel, (val) => setState(() {
                  _selectedLevel = val;
                  _loadCourses();
                })),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip<T>(String label, T value, T groupValue, Function(T) onSelected) {
    final isSelected = value == groupValue;
    final primaryColor = ThemeService().primaryColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        selectedColor: primaryColor.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? primaryColor : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildCourseCard(DeanCourse course, Color primaryColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => _showCourseEditor(course: course),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.courseCode,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${course.credits} Credits',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course.courseName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.business_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    course.departmentName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Sem ${course.semester ?? "N/A"}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'L${course.courseLevel}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              if (course.lecturerName != null && course.lecturerName!.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Lecturer: ${course.lecturerName}',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseEditor({DeanCourse? course}) {
    // This would be a more complex dialog with form validation
    // For now, I'll just show a placeholder as I need to fetch departments too.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CourseEditorSheet(
        course: course,
        user: widget.user,
        onSaved: () {
          Navigator.pop(context);
          _loadCourses();
        },
      ),
    );
  }
}

class _CourseEditorSheet extends StatefulWidget {
  final DeanCourse? course;
  final DeanSession user;
  final VoidCallback onSaved;

  const _CourseEditorSheet({this.course, required this.user, required this.onSaved});

  @override
  State<_CourseEditorSheet> createState() => _CourseEditorSheetState();
}

class _CourseEditorSheetState extends State<_CourseEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _code, _name;
  late int _credits, _level;
  String? _deptId;
  bool _loading = false;
  List<Map<String, dynamic>> _departments = [];

  @override
  void initState() {
    super.initState();
    _code = widget.course?.courseCode ?? '';
    _name = widget.course?.courseName ?? '';
    _credits = widget.course?.credits ?? 3;
    _level = widget.course?.courseLevel ?? 100;
    _deptId = widget.course?.departmentId;
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final depts = await const DeanApiService().fetchDepartments(widget.user.facultyId ?? '');
      if (mounted) {
        setState(() {
          _departments = depts;
          if (_deptId == null && depts.isNotEmpty) {
            _deptId = depts.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching departments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.course == null ? 'Add New Course' : 'Edit Course',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: _code,
                decoration: const InputDecoration(labelText: 'Course Code (e.g. CSC101)'),
                onSaved: (v) => _code = v ?? '',
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Course Name'),
                onSaved: (v) => _name = v ?? '',
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _credits,
                      items: [1, 2, 3, 4, 5, 6].map((it) => DropdownMenuItem(value: it, child: Text('$it Credits'))).toList(),
                      onChanged: (v) => setState(() => _credits = v ?? 3),
                      decoration: const InputDecoration(labelText: 'Credits'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _deptId,
                      items: _departments.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['name'].toString()))).toList(),
                      onChanged: (v) => setState(() => _deptId = v),
                      decoration: const InputDecoration(labelText: 'Department'),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _loading 
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton(
                      onPressed: _save,
                      child: const Text('Save Course'),
                    ),
              ),
              if (widget.course != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete Course'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _loading = true);
    try {
      await const DeanApiService().saveCourse({
        'course_id': widget.course?.courseId,
        'course_code': _code,
        'course_name': _name,
        'credits': _credits,
        'course_level': _level,
        'department_id': _deptId,
      });
      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await const DeanApiService().deleteCourse(widget.course!.courseId);
      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    } finally {
      setState(() => _loading = false);
    }
  }
}
