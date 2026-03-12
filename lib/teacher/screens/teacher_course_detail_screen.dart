import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../models/teacher_course.dart';
import '../models/teacher_course_material.dart';
import '../models/teacher_session.dart';
import '../models/teacher_student.dart';
import '../services/teacher_api_service.dart';
import 'teacher_attendance_screens.dart';
import '../../shared/widgets/app_error_widget.dart';
import '../../services/report_service.dart';

class TeacherCourseDetailScreen extends StatefulWidget {
  final TeacherSession user;
  final TeacherCourse course;

  const TeacherCourseDetailScreen({
    super.key,
    required this.user,
    required this.course,
  });

  @override
  State<TeacherCourseDetailScreen> createState() =>
      _TeacherCourseDetailScreenState();
}

class _TeacherCourseDetailScreenState extends State<TeacherCourseDetailScreen> {
  final TeacherApiService _api = const TeacherApiService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _materialsSectionKey = GlobalKey();

  List<TeacherStudent> _students = [];
  List<TeacherCourseMaterial> _materials = [];
  bool _isLoadingStudents = true;
  bool _isLoadingMaterials = true;
  String? _studentsError;
  String? _materialsError;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadMaterials();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  TeacherCourse get _activeCourse => widget.course;

  bool get _isReadOnlySemester =>
      widget.course.semester.toLowerCase().contains('first');

  String _studentGroupLabel(TeacherStudent student) {
    final department = student.departmentName?.trim() ?? '';
    if (department.isNotEmpty) {
      return department;
    }
    return 'Other Departments';
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoadingStudents = true;
      _studentsError = null;
    });

    try {
      final students = await _api.fetchCourseStudents(_activeCourse.sectionId);
      students.sort((a, b) {
        final groupCompare = _studentGroupLabel(
          a,
        ).toLowerCase().compareTo(_studentGroupLabel(b).toLowerCase());
        if (groupCompare != 0) {
          return groupCompare;
        }
        final lastNameCompare = a.lastName.toLowerCase().compareTo(
          b.lastName.toLowerCase(),
        );
        if (lastNameCompare != 0) {
          return lastNameCompare;
        }
        return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _students = students;
        _isLoadingStudents = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _studentsError = e.toString();
        _isLoadingStudents = false;
      });
    }
  }

  void _showReportDialog(dynamic error, String type) {
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
              decoration: InputDecoration(
                hintText: 'e.g. $type are not loading...',
                border: const OutlineInputBorder(),
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
                  issueType: 'Teacher Course Detail - $type',
                  description: controller.text.trim(),
                  additionalData: {'error': error.toString(), 'sectionId': widget.course.sectionId},
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

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoadingMaterials = true;
      _materialsError = null;
    });

    try {
      final materials = await _api.fetchCourseMaterials(
        teacherId: widget.user.userId,
        sectionId: _activeCourse.sectionId,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _materials = materials;
        _isLoadingMaterials = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _materialsError = e.toString();
        _isLoadingMaterials = false;
      });
    }
  }

  Map<String, List<TeacherStudent>> _groupStudents() {
    final grouped = <String, List<TeacherStudent>>{};
    for (final student in _students) {
      final key = _studentGroupLabel(student);
      grouped.putIfAbsent(key, () => []).add(student);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sortedMap = <String, List<TeacherStudent>>{};
    for (final key in sortedKeys) {
      final sortedStudents = [...grouped[key]!]
        ..sort((a, b) {
          final lastNameCompare = a.lastName.toLowerCase().compareTo(
            b.lastName.toLowerCase(),
          );
          if (lastNameCompare != 0) {
            return lastNameCompare;
          }
          return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
        });
      sortedMap[key] = sortedStudents;
    }
    return sortedMap;
  }

  Map<String, List<TeacherStudent>> _groupStudentsByProgram() {
    final grouped = <String, List<TeacherStudent>>{};
    for (final student in _students) {
      final key = (student.programName?.trim().isNotEmpty ?? false)
          ? student.programName!.trim()
          : 'Other Programs';
      grouped.putIfAbsent(key, () => []).add(student);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sortedMap = <String, List<TeacherStudent>>{};
    for (final key in sortedKeys) {
      final sortedStudents = [...grouped[key]!]
        ..sort((a, b) {
          final lastNameCompare = a.lastName.toLowerCase().compareTo(
            b.lastName.toLowerCase(),
          );
          if (lastNameCompare != 0) {
            return lastNameCompare;
          }
          return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
        });
      sortedMap[key] = sortedStudents;
    }
    return sortedMap;
  }

  Future<void> _scrollToSection(GlobalKey sectionKey) async {
    final sectionContext = sectionKey.currentContext;
    if (sectionContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  Future<void> _openMaterialLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid material link')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open material')));
    }
  }

  void _showAddMaterialSheet() {
    if (_isReadOnlySemester) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First semester is locked. Upload is disabled.'),
        ),
      );
      return;
    }

    final activeCourse = _activeCourse;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final urlController = TextEditingController();
    String selectedType = 'document';
    PlatformFile? selectedFile;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Upload Material',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Week 3 notes',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Material Type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'document',
                        child: Text('Document / File'),
                      ),
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                      DropdownMenuItem(
                        value: 'link',
                        child: Text('External Link'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setSheetState(() {
                        selectedType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'External URL',
                      hintText: 'Optional if you upload a file',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        withData: true,
                        type: FileType.any,
                      );
                      if (result == null || result.files.isEmpty) {
                        return;
                      }
                      setSheetState(() {
                        selectedFile = result.files.single;
                      });
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                      selectedFile == null
                          ? 'Choose File'
                          : 'Selected: ${selectedFile!.name}',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Title is required')),
                          );
                          return;
                        }

                        final hasUrl = urlController.text.trim().isNotEmpty;
                        final hasFile = selectedFile?.bytes != null;
                        if (!hasUrl && !hasFile) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Choose a file or provide an external URL.',
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          if (hasFile) {
                            await _api.uploadCourseMaterial(
                              teacherId: widget.user.userId,
                              sectionId: activeCourse.sectionId,
                              title: titleController.text.trim(),
                              materialType: selectedType,
                              description: descriptionController.text.trim(),
                              externalUrl: urlController.text.trim(),
                              fileName: selectedFile!.name,
                              fileBytes: selectedFile!.bytes!,
                            );
                          } else {
                            await _api.addCourseMaterial(
                              teacherId: widget.user.userId,
                              sectionId: activeCourse.sectionId,
                              title: titleController.text.trim(),
                              materialType: selectedType,
                              description: descriptionController.text.trim(),
                              externalUrl: urlController.text.trim(),
                            );
                          }

                          if (!mounted || !sheetContext.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Material uploaded successfully'),
                            ),
                          );
                          _loadMaterials();
                        } catch (e) {
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(
                            this.context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      child: const Text('Save Material'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteMaterial(TeacherCourseMaterial material) async {
    if (_isReadOnlySemester) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First semester is locked. Delete is disabled.'),
        ),
      );
      return;
    }

    try {
      await _api.deleteCourseMaterial(
        teacherId: widget.user.userId,
        materialId: material.materialId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Material deleted')));
      _loadMaterials();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openMarksEntryScreen() async {
    if (_isLoadingStudents) {
      await _loadStudents();
    }
    if (!mounted) {
      return;
    }

    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeacherMarksEntryScreen(
          user: widget.user,
          course: _activeCourse,
          groupedStudents: _groupStudentsByProgram(),
          sectionId: _activeCourse.sectionId,
          readOnly: _isReadOnlySemester,
        ),
      ),
    );

    if (didSave == true && mounted) {
      _loadStudents();
    }
  }

  Future<void> _openStudentsScreen() async {
    if (_isLoadingStudents) {
      await _loadStudents();
    }
    if (!mounted) {
      return;
    }
    if (_studentsError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_studentsError!)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherStudentsListScreen(students: _students),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCourse = _activeCourse;

    final grouped = _groupStudents();
    final gradedCount = _students
        .where((student) => student.score != null)
        .length;

    return Scaffold(
      floatingActionButton: !_isReadOnlySemester
          ? FloatingActionButton.extended(
              onPressed: _showAddMaterialSheet,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add Material'),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeCourse.courseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              activeCourse.courseCode,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimary.withAlpha(230), // 0.9 opacity
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStudents();
          await _loadMaterials();
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            if (_isReadOnlySemester)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withAlpha(31), // 0.12 opacity
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'First semester is locked. You can only view past data.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            _SectionCard(
              title: 'Course Information',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Semester',
                    value: activeCourse.semester,
                  ),
                  _InfoRow(
                    icon: Icons.date_range_rounded,
                    label: 'Session',
                    value: activeCourse.academicYear,
                  ),
                  _InfoRow(
                    icon: Icons.meeting_room_outlined,
                    label: 'Room',
                    value: activeCourse.roomNumber.isEmpty
                        ? 'TBD'
                        : activeCourse.roomNumber,
                  ),
                  _InfoRow(
                    icon: Icons.schedule_outlined,
                    label: 'Schedule',
                    value: activeCourse.schedule.isEmpty
                        ? 'TBD'
                        : activeCourse.schedule,
                  ),
                  _InfoRow(
                    icon: Icons.school_outlined,
                    label: 'Department',
                    value: activeCourse.departmentName?.isNotEmpty == true
                        ? activeCourse.departmentName!
                        : 'Not assigned',
                  ),
                  _InfoRow(
                    icon: Icons.credit_score_outlined,
                    label: 'Credits',
                    value: '${activeCourse.credits}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_studentsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppErrorWidget(
                  error: _studentsError,
                  onRetry: _loadStudents,
                  onReport: () => _showReportDialog(_studentsError, 'Students'),
                ),
              ),
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width < 520 ? 2 : 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
              children: [
                _OverviewActionTile(
                  icon: Icons.fact_check_outlined,
                  title: 'Attendance',
                  subtitle: _isReadOnlySemester
                      ? 'View only'
                      : 'Take or review',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeacherAttendanceSelectionScreen(
                          user: widget.user,
                          course: _activeCourse,
                          readOnly: _isReadOnlySemester,
                        ),
                      ),
                    );
                  },
                ),
                _OverviewActionTile(
                  icon: Icons.groups_outlined,
                  title: 'Students',
                  subtitle: 'By department',
                  onTap: _openStudentsScreen,
                ),
                _OverviewActionTile(
                  icon: Icons.edit_note_outlined,
                  title: 'CA Marks',
                  subtitle: _isReadOnlySemester ? 'Locked' : 'Edit scores',
                  onTap: _openMarksEntryScreen,
                ),
                _OverviewActionTile(
                  icon: Icons.description_outlined,
                  title: 'Materials',
                  subtitle: _isReadOnlySemester
                      ? 'Read only'
                      : 'Upload resources',
                  onTap: () {
                    if (_isReadOnlySemester) {
                      _scrollToSection(_materialsSectionKey);
                      return;
                    }
                    _showAddMaterialSheet();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Teaching Summary',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 140,
                    child: _SummaryTile(
                      title: 'Students',
                      value: '${_students.length}',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: _SummaryTile(
                      title: 'Departments',
                      value: '${grouped.length}',
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: _SummaryTile(
                      title: 'Graded',
                      value: '$gradedCount',
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'About This Course',
              child: Text(
                activeCourse.description.isEmpty
                    ? 'No course description has been added yet.'
                    : activeCourse.description,
                style: const TextStyle(
                  color: AppColors.lightTextSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              key: _materialsSectionKey,
              child: _buildMaterialsSection(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsSection() {
    final title = 'Materials';

    if (_isLoadingMaterials) {
      return const _SectionCard(
        title: 'Materials',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_materialsError != null) {
      return _SectionCard(
        title: title,
        child: AppErrorWidget(
          error: _materialsError,
          onRetry: _loadMaterials,
          onReport: () => _showReportDialog(_materialsError, 'Materials'),
        ),
      );
    }

    return _SectionCard(
      title: title,
      child: _materials.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(128), // 0.5 opacity
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isReadOnlySemester
                        ? 'No materials found for this first semester section.'
                        : 'No materials uploaded yet. Use quick actions or the add button to upload.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final material in _materials)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MaterialListTile(
                      material: material,
                      readOnly: _isReadOnlySemester,
                      icon: _materialIcon(material.materialType),
                      onOpen: () {
                        final url = material.externalUrl.isNotEmpty
                            ? material.externalUrl
                            : material.downloadUrl;
                        if (url.isNotEmpty) {
                          _openMaterialLink(url);
                        }
                      },
                      onDelete: () => _deleteMaterial(material),
                    ),
                  ),
              ],
            ),
    );
  }

  IconData _materialIcon(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.description_outlined;
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(10), // 0.04 opacity
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OverviewActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.lightTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDepartmentSection extends StatelessWidget {
  final String title;
  final List<TeacherStudent> students;
  final ValueChanged<TeacherStudent> onTapStudent;

  const _StudentDepartmentSection({
    required this.title,
    required this.students,
    required this.onTapStudent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final student in students) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(25), // 0.1 opacity
                child: Text(
                  student.firstName.isEmpty ? '?' : student.firstName[0],
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(student.fullName),
              subtitle: Text(
                '${student.studentNumber} - ${student.programName ?? 'Program not set'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: SizedBox(
                width: 88,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (student.score != null)
                      Text(
                        student.score!.toStringAsFixed(1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    else
                      const Text(
                        'No score',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.lightTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Att ${student.attendancePercentage?.toStringAsFixed(0) ?? '-'}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () => onTapStudent(student),
            ),
            if (student != students.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class TeacherStudentsListScreen extends StatefulWidget {
  final List<TeacherStudent> students;

  const TeacherStudentsListScreen({super.key, required this.students});

  @override
  State<TeacherStudentsListScreen> createState() =>
      _TeacherStudentsListScreenState();
}

class _TeacherStudentsListScreenState extends State<TeacherStudentsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<TeacherStudent>> _groupedStudents() {
    final filtered = widget.students.where((student) {
      if (_query.isEmpty) {
        return true;
      }
      final q = _query.toLowerCase();
      return student.fullName.toLowerCase().contains(q) ||
          student.studentNumber.toLowerCase().contains(q) ||
          (student.departmentName ?? '').toLowerCase().contains(q) ||
          (student.programName ?? '').toLowerCase().contains(q);
    }).toList();

    final grouped = <String, List<TeacherStudent>>{};
    for (final student in filtered) {
      final key = (student.departmentName?.trim().isNotEmpty ?? false)
          ? student.departmentName!.trim()
          : 'Other Departments';
      grouped.putIfAbsent(key, () => []).add(student);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sorted = <String, List<TeacherStudent>>{};
    for (final key in keys) {
      final students = [...grouped[key]!]
        ..sort((a, b) {
          final last = a.lastName.toLowerCase().compareTo(
            b.lastName.toLowerCase(),
          );
          if (last != 0) {
            return last;
          }
          return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
        });
      sorted[key] = students;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedStudents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query = value.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, number, program or department',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? const Center(child: Text('No students match your search.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (final entry in grouped.entries) ...[
                        _StudentDepartmentSection(
                          title: entry.key,
                          students: entry.value,
                          onTapStudent: (_) {},
                        ),
                        if (entry.key != grouped.keys.last)
                          const SizedBox(height: 16),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class TeacherMarksEntryScreen extends StatefulWidget {
  final TeacherSession user;
  final TeacherCourse course;
  final Map<String, List<TeacherStudent>> groupedStudents;
  final String sectionId;
  final bool readOnly;

  const TeacherMarksEntryScreen({
    super.key,
    required this.user,
    required this.course,
    required this.groupedStudents,
    required this.sectionId,
    required this.readOnly,
  });

  @override
  State<TeacherMarksEntryScreen> createState() =>
      _TeacherMarksEntryScreenState();
}

class _TeacherMarksEntryScreenState extends State<TeacherMarksEntryScreen> {
  final TeacherApiService _api = const TeacherApiService();
  final Map<String, String> _caInputs = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final students in widget.groupedStudents.values) {
      for (final student in students) {
        _caInputs[student.studentId] = student.caScore != null
            ? student.caScore!.toStringAsFixed(1)
            : '';
      }
    }
  }

  String _calculateGrade(double score) {
    if (score >= 70) return 'A';
    if (score >= 60) return 'B';
    if (score >= 50) return 'C';
    if (score >= 45) return 'D';
    if (score >= 40) return 'E';
    return 'F';
  }

  double _calculateGradePoint(String grade) {
    switch (grade) {
      case 'A':
        return 5.0;
      case 'B':
        return 4.0;
      case 'C':
        return 3.0;
      case 'D':
        return 2.0;
      case 'E':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Future<void> _saveAll() async {
    if (widget.readOnly || _isSaving) {
      return;
    }

    final allStudents = widget.groupedStudents.values
        .expand((students) => students)
        .toList();

    for (final student in allStudents) {
      final ca = double.tryParse(_caInputs[student.studentId]?.trim() ?? '');

      if (ca == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter valid CA for ${student.fullName}.',
            ),
          ),
        );
        return;
      }
      if (ca < 0 || ca > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CA score out of range for ${student.fullName}. CA: 0-30.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      for (final student in allStudents) {
        final attendance = student.attendanceScore ?? 0.0;
        final ca = double.parse(_caInputs[student.studentId]!);
        final exam = student.examScore ?? 0.0;
        final total = attendance + ca + exam;
        final grade = _calculateGrade(total);
        final gradePoint = _calculateGradePoint(grade);

        await _api.submitResult(
          sectionId: widget.sectionId,
          studentId: student.studentId,
          attendanceScore: attendance,
          caScore: ca,
          examScore: exam,
          grade: grade,
          gradePoint: gradePoint,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CA scores saved successfully.'),
        ),
      );
      Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter CA Marks'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Edit attendance',
            icon: const Icon(Icons.how_to_reg_rounded),
            onPressed: () async {
              if (widget.readOnly) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'First semester is locked. Attendance editing is disabled.',
                    ),
                  ),
                );
                return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TeacherAttendanceSelectionScreen(
                    user: widget.user,
                    course: widget.course,
                    readOnly: widget.readOnly,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: widget.groupedStudents.isEmpty
          ? const Center(child: Text('No students enrolled in this course.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.readOnly)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withAlpha(31), // 0.12 opacity
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'First semester is locked. You can only view scores.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                for (final entry in widget.groupedStudents.entries) ...[
                  _SectionCard(
                    title: entry.key,
                    child: Column(
                      children: [
                        for (final student in entry.value) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      student.studentNumber,
                                      style: const TextStyle(
                                        color: AppColors.lightTextSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 96,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Att ${((student.attendanceScore ?? 0.0)).toStringAsFixed(1)}/10',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${student.attendancePercentage?.toStringAsFixed(0) ?? '0'}%',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.lightTextSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 86,
                                child: TextFormField(
                                  initialValue:
                                      _caInputs[student.studentId] ?? '',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  enabled: !widget.readOnly && !_isSaving,
                                  decoration: const InputDecoration(
                                    labelText: 'CA',
                                    hintText: '0-30',
                                  ),
                                  onChanged: (value) {
                                    _caInputs[student.studentId] = value;
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (student != entry.value.last) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (entry.key != widget.groupedStudents.keys.last)
                    const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.readOnly ? null : _saveAll,
                    child: Text(
                      widget.readOnly
                          ? 'Read Only'
                          : (_isSaving ? 'Saving...' : 'Save All Marks'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _MaterialListTile extends StatelessWidget {
  final TeacherCourseMaterial material;
  final bool readOnly;
  final IconData icon;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _MaterialListTile({
    required this.material,
    required this.readOnly,
    required this.icon,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final url = material.externalUrl.isNotEmpty
        ? material.externalUrl
        : material.downloadUrl;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(25), // 0.1 opacity
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(material.title),
        subtitle: Text(
          material.description.isNotEmpty
              ? material.description
              : (material.fileName.isNotEmpty
                    ? material.fileName
                    : material.uploadDate),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: url.isEmpty ? null : onOpen,
        trailing: readOnly
            ? (url.isNotEmpty
                  ? IconButton(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new_rounded),
                    )
                  : null)
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'open' && url.isNotEmpty) {
                    onOpen();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'open', child: Text('Open')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
      ),
    );
  }
}
