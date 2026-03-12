import 'package:flutter/material.dart';

import '../models/ea_session.dart';
import '../models/ea_course.dart';
import '../models/ea_result.dart';
import '../services/ea_api_service.dart';

class EaResultsScreen extends StatefulWidget {
  final EaSession user;

  const EaResultsScreen({super.key, required this.user});

  @override
  State<EaResultsScreen> createState() => _EaResultsScreenState();
}

class _EaResultsScreenState extends State<EaResultsScreen> {
  List<EaCourse> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterSemester = 'First';
  String _filterLevel = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final courses = await const EaApiService().fetchCourses(
        semester: _filterSemester == 'First' ? '1' : '2',
      );
      courses.sort((a, b) => a.courseCode.compareTo(b.courseCode));
      if (mounted) setState(() { _courses = courses; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  List<EaCourse> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    return _courses.where((c) {
      final lm = _filterLevel == 'All' || c.level.toString() == _filterLevel;
      final sm = q.isEmpty || c.courseCode.toLowerCase().contains(q) || c.courseName.toLowerCase().contains(q);
      return lm && sm;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Exam Marks', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Enter attendance, CA and exam scores', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color)),
                ])),
                IconButton(onPressed: _loadCourses, icon: const Icon(Icons.refresh_rounded), color: Theme.of(context).colorScheme.primary),
              ]),
            ),
            const SizedBox(height: 14),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search courses...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                   fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128), // 0.5 opacity
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Semester chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Text('Semester: ', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                for (final sem in ['First', 'Second'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                     child: _ExChip(label: '$sem Sem', selected: _filterSemester == sem, color: Theme.of(context).colorScheme.primary,
                      onTap: () { if (_filterSemester != sem) { setState(() => _filterSemester = sem); _loadCourses(); } }),
                  ),
              ]),
            ),
            const SizedBox(height: 10),

            // Level chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Text('Level: ', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                for (final lv in ['All', '1', '2', '3', '4'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                     child: _ExChip(label: lv == 'All' ? 'All' : 'Level $lv', selected: _filterLevel == lv, color: Theme.of(context).colorScheme.secondary,
                      onTap: () => setState(() => _filterLevel = lv)),
                  ),
              ]),
            ),
            const SizedBox(height: 14),

            // Course list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _ErrView(message: _errorMessage!, onRetry: _loadCourses)
                      : _filtered.isEmpty
                          ? const _EmptyV(icon: Icons.menu_book_outlined, msg: 'No courses found')
                          : RefreshIndicator(
                              onRefresh: _loadCourses,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) {
                                  final c = _filtered[i];
                                  return _ExamCourseCard(
                                    course: c,
                                    onTap: () => Navigator.push(ctx, MaterialPageRoute(
                                      builder: (_) => _ExamEntryScreen(course: c, semester: _filterSemester),
                                    )),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exam Course Card ─────────────────────────────────────────────────────────
class _ExamCourseCard extends StatelessWidget {
  final EaCourse course;
  final VoidCallback onTap;
  const _ExamCourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (course.enrolledCount ?? 0) > 0 ? 0.5 : 0.0; // placeholder progress
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border(left: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 4)),
          boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary.withAlpha(30), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(
                course.courseCode.length >= 3 ? course.courseCode.substring(0, 3) : course.courseCode,
                 style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.secondary, fontSize: 11),
              )),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.courseCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(course.courseName, maxLines: 2, overflow: TextOverflow.ellipsis,
                 style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            ])),
            Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                 child: Text('${course.enrolledCount ?? 0}', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w800)),
              ),
               Text('students', style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 8),
               Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.secondary),
            ]),
          ]),
          const SizedBox(height: 10),
          if (course.lecturerName?.isNotEmpty == true)
            Row(children: [
              const Icon(Icons.person_rounded, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(course.lecturerName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey))),
            ]),
          const SizedBox(height: 8),
          Row(children: [
             _MiniTag2(label: 'Level ${course.level}', color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: 6),
             _MiniTag2(label: 'Sem ${course.semester}', color: Theme.of(context).colorScheme.primary),
            const Spacer(),
             Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.secondary, size: 16),
            const SizedBox(width: 4),
             Text('Enter Marks', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w700, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

// ─── Exam Entry Screen (per-student marks) ────────────────────────────────────
class _ExamEntryScreen extends StatefulWidget {
  final EaCourse course;
  final String semester;
  const _ExamEntryScreen({required this.course, required this.semester});

  @override
  State<_ExamEntryScreen> createState() => _ExamEntryScreenState();
}

class _ExamEntryScreenState extends State<_ExamEntryScreen> {
  List<EaResult> _results = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;

  // Controllers per student: student_id -> {att, ca, exam}
  final Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    for (final m in _controllers.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadResults() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await const EaApiService().fetchResults(
        courseId: widget.course.courseId,
        semester: widget.semester == 'First' ? '1' : '2',
      );
      results.sort((a, b) => a.studentName.compareTo(b.studentName));
      // Init controllers
      for (final r in results) {
        _controllers[r.studentId] ??= {
          'att':  TextEditingController(text: ''),
          'ca':   TextEditingController(text: ''),
          'exam': TextEditingController(text: r.score?.toStringAsFixed(1) ?? ''),
        };
      }
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  // Compute grade from total
  String _grade(double total) {
    if (total >= 80) return 'A';
    if (total >= 70) return 'B+';
    if (total >= 60) return 'B';
    if (total >= 55) return 'C+';
    if (total >= 50) return 'C';
    if (total >= 45) return 'D';
    if (total >= 35) return 'E';
    return 'F';
  }

  Color _gradeColor(String g) {
    switch (g) {
      case 'A':  return Theme.of(context).colorScheme.tertiary;
      case 'B+': case 'B': return Theme.of(context).colorScheme.primary;
      case 'C+': case 'C': return Theme.of(context).colorScheme.secondary;
      case 'D':  return Theme.of(context).colorScheme.secondary.withAlpha(200);
      case 'E':  return Theme.of(context).colorScheme.error.withAlpha(200);
      default:   return Theme.of(context).colorScheme.error;
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    int saved = 0; int failed = 0;
    for (final result in _results) {
      final ctr = _controllers[result.studentId];
      if (ctr == null) continue;
      final attStr  = ctr['att']!.text.trim();
      final caStr   = ctr['ca']!.text.trim();
      final examStr = ctr['exam']!.text.trim();
      if (examStr.isEmpty && attStr.isEmpty && caStr.isEmpty) continue;
      final att  = double.tryParse(attStr)  ?? 0;
      final ca   = double.tryParse(caStr)   ?? 0;
      final exam = double.tryParse(examStr) ?? 0;
      final total = att + ca + exam;
      final grade = _grade(total);
      try {
        if (result.resultId.isEmpty) {
          await const EaApiService().submitResult(
            studentId: result.studentId,
            courseId: result.courseId,
            academicYear: result.academicYear,
            semester: result.semester,
            score: total,
            grade: grade,
          );
        } else {
          await const EaApiService().updateResult(
            resultId: result.resultId,
            score: total,
            grade: grade,
          );
        }
        saved++;
      } catch (_) {
        failed++;
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failed == 0
            ? '$saved marks saved successfully!'
            : '$saved saved, $failed failed'),
         backgroundColor: failed == 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error,
      ));
      if (saved > 0) _loadResults();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
       backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                     colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.secondaryContainer],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.course.courseCode,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(widget.course.courseName, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13)),
                      const SizedBox(height: 6),
                      if (widget.course.lecturerName?.isNotEmpty == true)
                        Row(children: [
                          const Icon(Icons.person_rounded, color: Colors.white70, size: 13),
                          const SizedBox(width: 4),
                          Text(widget.course.lecturerName!,
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // Score header info
          SliverToBoxAdapter(
            child: Container(
               color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_results.length} Students Enrolled',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('${widget.semester} Semester  •  ${widget.course.courseCode}',
                       style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                ]),
                Row(children: [
                   _ScoreLegend('Att', '/10', Theme.of(context).colorScheme.primary),
                   const SizedBox(width: 8),
                   _ScoreLegend('CA', '/30', Theme.of(context).colorScheme.tertiary),
                   const SizedBox(width: 8),
                   _ScoreLegend('Exam', '/60', Theme.of(context).colorScheme.secondary),
                ]),
              ]),
            ),
          ),

          // Students list
          _isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : _errorMessage != null
                  ? SliverFillRemaining(child: _ErrView(message: _errorMessage!, onRetry: _loadResults))
                  : _results.isEmpty
                      ? const SliverFillRemaining(child: _EmptyV(icon: Icons.group_off_outlined, msg: 'No students enrolled'))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final r = _results[i];
                              final ctr = _controllers[r.studentId]!;
                              return _StudentScoreRow(
                                serial: i + 1,
                                result: r,
                                attCtrl:  ctr['att']!,
                                caCtrl:   ctr['ca']!,
                                examCtrl: ctr['exam']!,
                                gradeFunc: _grade,
                                gradeColor: _gradeColor,
                              );
                            },
                            childCount: _results.length,
                          ),
                        ),

          // Bottom spacer
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),

      // Sticky save button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: _isSaving
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _saveAll,
                  style: ElevatedButton.styleFrom(
                     backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save All Marks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
        ),
      ),
    );
  }
}

// ─── Student Score Row ────────────────────────────────────────────────────────
class _StudentScoreRow extends StatefulWidget {
  final int serial;
  final EaResult result;
  final TextEditingController attCtrl;
  final TextEditingController caCtrl;
  final TextEditingController examCtrl;
  final String Function(double) gradeFunc;
  final Color Function(String) gradeColor;

  const _StudentScoreRow({
    required this.serial, required this.result,
    required this.attCtrl, required this.caCtrl, required this.examCtrl,
    required this.gradeFunc, required this.gradeColor,
  });

  @override
  State<_StudentScoreRow> createState() => _StudentScoreRowState();
}

class _StudentScoreRowState extends State<_StudentScoreRow> {
  late String _liveGrade;
  late double _liveTotal;

  @override
  void initState() {
    super.initState();
    _computeLive();
    widget.attCtrl.addListener(_onChanged);
    widget.caCtrl.addListener(_onChanged);
    widget.examCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.attCtrl.removeListener(_onChanged);
    widget.caCtrl.removeListener(_onChanged);
    widget.examCtrl.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(_computeLive);

  void _computeLive() {
    final a = double.tryParse(widget.attCtrl.text) ?? 0;
    final c = double.tryParse(widget.caCtrl.text) ?? 0;
    final e = double.tryParse(widget.examCtrl.text) ?? 0;
    _liveTotal = a + c + e;
    _liveGrade = (widget.examCtrl.text.trim().isEmpty && widget.attCtrl.text.trim().isEmpty)
        ? (widget.result.grade ?? '')
        : widget.gradeFunc(_liveTotal);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gc = _liveGrade.isNotEmpty ? widget.gradeColor(_liveGrade) : Colors.grey;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.surface,
         borderRadius: BorderRadius.circular(16),
         boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withAlpha(10), blurRadius: 6, offset: const Offset(0,3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Student name row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Container(
              width: 30, height: 30,
               decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary.withAlpha(30), borderRadius: BorderRadius.circular(8)),
               child: Center(child: Text('${widget.serial}', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.secondary, fontSize: 12))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.result.studentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
               Text(widget.result.studentNumber, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
            ])),
            if (_liveGrade.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: gc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(_liveGrade, style: TextStyle(color: gc, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        // Score inputs
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
             _ScoreField(label: 'Att /10', ctrl: widget.attCtrl, max: 10, color: Theme.of(context).colorScheme.primary),
             const SizedBox(width: 8),
             _ScoreField(label: 'CA /30', ctrl: widget.caCtrl, max: 30, color: Theme.of(context).colorScheme.tertiary),
             const SizedBox(width: 8),
             _ScoreField(label: 'Exam /60', ctrl: widget.examCtrl, max: 60, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 12),
            Column(children: [
               Text('Total', style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 4),
              Text(
                _liveTotal > 0 ? _liveTotal.toStringAsFixed(1) : '—',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: gc),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ScoreField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final double max;
  final Color color;

  const _ScoreField({required this.label, required this.ctrl, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: color.withValues(alpha: 0.3)),
            filled: true,
            fillColor: color.withValues(alpha: 0.08),
            border:OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 2)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ]),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _ExChip extends StatelessWidget {
  final String label; final bool selected; final Color color; final VoidCallback onTap;
  const _ExChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: selected ? color : color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class _MiniTag2 extends StatelessWidget {
  final String label; final Color color;
  const _MiniTag2({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
  );
}

class _ScoreLegend extends StatelessWidget {
  final String label; final String sub; final Color color;
  const _ScoreLegend(this.label, this.sub, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
      TextSpan(text: sub, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10)),
    ])),
  );
}

class _ErrView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.error_outline_rounded, size: 56, color: Colors.red.shade300), const SizedBox(height: 14),
    Text('Failed to load', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
    Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
    const SizedBox(height: 20),
    FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try Again')),
  ])));
}

class _EmptyV extends StatelessWidget {
  final IconData icon; final String msg;
  const _EmptyV({required this.icon, required this.msg});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 64, color: Colors.grey.shade400), const SizedBox(height: 14),
    Text(msg, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
  ]));
}
