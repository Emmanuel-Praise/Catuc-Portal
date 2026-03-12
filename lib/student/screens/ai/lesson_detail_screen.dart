import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:catuc_portal/shared/models/ai_user.dart';
import 'package:catuc_portal/student/models/student_profile.dart';
import 'package:catuc_portal/student/screens/ai/lesson_models.dart';
import 'package:catuc_portal/student/services/ai_learning_store.dart';
import 'package:catuc_portal/student/services/student_api_service.dart';
import 'package:catuc_portal/theme/app_colors.dart';
import 'widgets/limit_reached_dialog.dart';

class LessonDetailScreen extends StatefulWidget {
  final AiUser user;
  final String topicId;
  final String topicTitle;
  final int lessonIndex;
  final List<Lesson> allLessons;
  final StudentProfile? studentProfile;

  const LessonDetailScreen({
    super.key,
    required this.user,
    required this.topicId,
    required this.topicTitle,
    required this.lessonIndex,
    required this.allLessons,
    this.studentProfile,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final _api = const StudentApiService();
  final _store = const AiLearningStore();

  bool _loading = true;
  String? _error;
  Lesson? _lesson;
  int _tabIndex = 0; // 0: explanation, 1: example, 2: exercises

  final Map<int, String> _answers = {};
  bool _showExerciseResults = false;

  String _prettyError(Object e) {
    final msg = e.toString();
    if (msg.contains('No active API keys available')) {
      return 'AI is not configured yet. Please ask the admin to add an active OpenRouter API key for the Learn module.';
    }
    if (msg.contains('Unable to reach CATPT backend')) {
      return 'Cannot connect to the server. Check your internet connection or the backend URL.';
    }
    return msg;
  }

  bool get _hasNextLesson =>
      widget.allLessons.isNotEmpty && widget.lessonIndex < widget.allLessons.length - 1;
  bool get _hasPreviousLesson => widget.allLessons.isNotEmpty && widget.lessonIndex > 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _store.setLastOpenedLessonIndex(
        topicId: widget.topicId,
        lessonIndex: widget.lessonIndex,
      );

      final cached = await _store.getLesson(widget.topicId, widget.lessonIndex);
      final base = cached ?? widget.allLessons[widget.lessonIndex];

      if (base.isContentGenerated && (base.explanation ?? '').trim().isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _lesson = base;
          _loading = false;
        });
        unawaited(_prefetchNextLesson());
        return;
      }

      final generated = await _api.generateSpecificLesson(
        studentId: widget.user.userId,
        topic: widget.topicTitle,
        lessonTitle: base.title,
        lessonDescription: base.description,
        studentProfile: widget.studentProfile,
        role: widget.user.role,
        contextLabel: widget.user.contextLabel,
      );

      await _store.saveLessonContent(
        topicId: widget.topicId,
        lessonIndex: widget.lessonIndex,
        explanation: (generated.explanation ?? '').trim().isEmpty
            ? '# ${base.title}\n\nThis lesson covers key concepts in ${widget.topicTitle}.'
            : generated.explanation!.trim(),
        example: generated.example ?? '',
        exercises: generated.exercises,
      );

      final refreshed = await _store.getLesson(widget.topicId, widget.lessonIndex);
      if (!mounted) return;
      setState(() {
        _lesson = refreshed ?? generated;
        _loading = false;
      });

      unawaited(_prefetchNextLesson());
    } on AiLimitReachedException catch (e) {
      if (!mounted) return;
      unawaited(showLimitReachedDialog(
        context,
        studentId: widget.user.userId,
        planName: e.planName,
        usedToday: e.usedToday,
        dailyLimit: e.dailyLimit,
      ));
      setState(() {
        _lesson = widget.allLessons[widget.lessonIndex].copyWith(
          explanation: '# ${widget.allLessons[widget.lessonIndex].title}\n\nAI limit reached. You can still read this outline and resume generation later.',
          example: '',
          exercises: const [],
          isContentGenerated: true,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _prettyError(e);
      });
    }
  }

  Future<void> _prefetchNextLesson() async {
    if (!_hasNextLesson) return;

    final nextIndex = widget.lessonIndex + 1;
    final nextCached = await _store.getLesson(widget.topicId, nextIndex);
    final nextBase = nextCached ?? widget.allLessons[nextIndex];
    final hasContent = (nextBase.explanation ?? '').trim().isNotEmpty;
    if (hasContent && nextBase.isContentGenerated) return;

    try {
      final generated = await _api.generateSpecificLesson(
        studentId: widget.user.userId,
        topic: widget.topicTitle,
        lessonTitle: nextBase.title,
        lessonDescription: nextBase.description,
        studentProfile: widget.studentProfile,
        role: widget.user.role,
        contextLabel: widget.user.contextLabel,
      );

      await _store.saveLessonContent(
        topicId: widget.topicId,
        lessonIndex: nextIndex,
        explanation: generated.explanation ?? '',
        example: generated.example ?? '',
        exercises: generated.exercises,
      );
    } catch (_) {
      // Prefetch is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _lesson?.title ?? 'Lesson',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(isDark)
              : _buildContent(isDark),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to load this lesson.',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final lesson = _lesson!;
    final totalLessons = widget.allLessons.isEmpty ? 0 : widget.allLessons.length;
    final lessonPos = totalLessons == 0 ? '' : 'Lesson ${widget.lessonIndex + 1} of $totalLessons';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.topicTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (lessonPos.isNotEmpty)
                    Expanded(
                      child: Text(
                        lessonPos,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  if (lesson.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.green.withOpacity(0.25)),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTabs(isDark),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _buildMarkdownPane(isDark, lesson.explanation ?? ''),
              _buildMarkdownPane(isDark, lesson.example ?? ''),
              _buildExercisesPane(isDark, lesson.exercises),
            ],
          ),
        ),
        _buildLessonNav(isDark, lesson),
      ],
    );
  }

  Widget _buildTabs(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _tabButton(isDark, 0, 'Lesson'),
          _tabButton(isDark, 1, 'Examples'),
          _tabButton(isDark, 2, 'Practice'),
        ],
      ),
    );
  }

  Widget _tabButton(bool isDark, int index, String label) {
    final selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownPane(bool isDark, String markdown) {
    final content = markdown.trim().isEmpty ? '_No content yet._' : markdown;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: MarkdownBody(
            data: content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: isDark ? Colors.white70 : Colors.black87, height: 1.35),
              h1: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900),
              h2: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900),
              h3: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900),
              code: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExercisesPane(bool isDark, List<Exercise> exercises) {
    if (exercises.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'No practice questions generated for this lesson.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < exercises.length; i++) _buildExerciseCard(isDark, i, exercises[i]),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _showExerciseResults
              ? null
              : () {
                  setState(() => _showExerciseResults = true);
                },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: AppColors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Check answers'),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(bool isDark, int index, Exercise ex) {
    final answer = _answers[index] ?? '';
    final correct = (ex.answer ?? '').toString();
    final explanation = (ex.explanation ?? '').toString();
    final show = _showExerciseResults;

    bool isCorrect() {
      if (correct.trim().isEmpty) return false;
      return answer.trim().toLowerCase() == correct.trim().toLowerCase();
    }

    Widget input;
    if (ex.type.toLowerCase() == 'multiple_choice' && (ex.options?.isNotEmpty ?? false)) {
      input = Column(
        children: [
          for (final opt in ex.options!)
            RadioListTile<String>(
              dense: true,
              value: opt,
              groupValue: answer,
              onChanged: show ? null : (v) => setState(() => _answers[index] = v ?? ''),
              title: Text(opt, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            ),
        ],
      );
    } else {
      input = TextField(
        enabled: !show,
        minLines: 2,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: ex.type.toLowerCase() == 'code' ? 'Write your code here...' : 'Write your answer...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (v) => _answers[index] = v,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.blue.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercise ${index + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ex.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          input,
          if (show) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  isCorrect() ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: isCorrect() ? Colors.green : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    correct.trim().isEmpty ? 'Suggested answer:' : (isCorrect() ? 'Correct' : 'Suggested answer: $correct'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isCorrect() ? Colors.green : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
            if (explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                explanation,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLessonNav(bool isDark, Lesson lesson) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: isDark ? AppColors.darkSurface : Colors.white,
        child: Row(
          children: [
            if (_hasPreviousLesson)
              Expanded(
                child: OutlinedButton(
                  onPressed: _goToPreviousLesson,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Previous'),
                ),
              )
            else
              const Expanded(child: SizedBox()),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final hasNext = _hasNextLesson;

                  if (!lesson.isCompleted) {
                    await _store.markLessonCompleted(
                      topicId: widget.topicId,
                      lessonIndex: widget.lessonIndex,
                      completed: true,
                    );
                    if (!mounted) return;
                    setState(() => _lesson = lesson.copyWith(isCompleted: true));
                  }

                  if (hasNext) {
                    nav.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => LessonDetailScreen(
                          user: widget.user,
                          topicId: widget.topicId,
                          topicTitle: widget.topicTitle,
                          lessonIndex: widget.lessonIndex + 1,
                          allLessons: widget.allLessons,
                          studentProfile: widget.studentProfile,
                        ),
                      ),
                    );
                  } else {
                    nav.pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _hasNextLesson ? Colors.green : AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_hasNextLesson ? 'Next lesson' : 'Finish topic'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToPreviousLesson() {
    if (!_hasPreviousLesson) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LessonDetailScreen(
          user: widget.user,
          topicId: widget.topicId,
          topicTitle: widget.topicTitle,
          lessonIndex: widget.lessonIndex - 1,
          allLessons: widget.allLessons,
          studentProfile: widget.studentProfile,
        ),
      ),
    );
  }
}
