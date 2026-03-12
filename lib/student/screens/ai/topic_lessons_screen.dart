import 'dart:async';

import 'package:flutter/material.dart';
import 'package:catuc_portal/shared/models/ai_user.dart';
import 'package:catuc_portal/student/models/student_profile.dart';
import 'package:catuc_portal/student/services/student_api_service.dart';
import 'package:catuc_portal/student/services/ai_learning_store.dart';
import 'package:catuc_portal/theme/app_colors.dart';

import 'lesson_detail_screen.dart';
import 'lesson_models.dart';
import 'widgets/limit_reached_dialog.dart';

class TopicLessonsScreen extends StatefulWidget {
  final AiUser user;
  final String pathId;
  final String topicId;
  final String topicTitle;
  final String topicDescription;
  final StudentProfile? studentProfile;
  final bool autoResume;

  const TopicLessonsScreen({
    super.key,
    required this.user,
    required this.pathId,
    required this.topicId,
    required this.topicTitle,
    required this.topicDescription,
    this.studentProfile,
    this.autoResume = true,
  });

  @override
  State<TopicLessonsScreen> createState() => _TopicLessonsScreenState();
}

class _TopicLessonsScreenState extends State<TopicLessonsScreen> {
  final _api = const StudentApiService();
  final _store = const AiLearningStore();

  bool _loading = true;
  bool _generatingOutline = false;
  String? _error;
  List<Lesson> _lessons = const [];
  bool _didAutoResume = false;

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

  @override
  void initState() {
    super.initState();
    _loadOrGenerateOutline();
  }

  Future<void> _loadOrGenerateOutline() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cached = await _store.getLessons(widget.topicId);
    if (cached.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _lessons = cached;
        _loading = false;
      });
      _maybeAutoResume();
      return;
    }

    setState(() => _generatingOutline = true);
    try {
      final outline = await _api.generateLearningLessons(
        studentId: widget.user.userId,
        topic: widget.topicTitle,
        studentProfile: widget.studentProfile,
        role: widget.user.role,
        contextLabel: widget.user.contextLabel,
        generateOutlineOnly: true,
      );
      final safeOutline = outline.isEmpty ? _localOutline(widget.topicTitle) : outline;
      await _store.upsertLessonsOutline(topicId: widget.topicId, lessons: safeOutline);
      final refreshed = await _store.getLessons(widget.topicId);
      if (!mounted) return;
      setState(() {
        _lessons = refreshed;
        _loading = false;
        _generatingOutline = false;
      });
      _maybeAutoResume();
    } on AiLimitReachedException catch (e) {
      if (mounted) {
        unawaited(showLimitReachedDialog(
          context,
          studentId: widget.user.userId,
          planName: e.planName,
          usedToday: e.usedToday,
          dailyLimit: e.dailyLimit,
        ));
      }
      if (!mounted) return;
      final safeOutline = _localOutline(widget.topicTitle);
      await _store.upsertLessonsOutline(topicId: widget.topicId, lessons: safeOutline);
      final refreshed = await _store.getLessons(widget.topicId);
      if (!mounted) return;
      setState(() {
        _lessons = refreshed;
        _loading = false;
        _generatingOutline = false;
      });
      _maybeAutoResume();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _generatingOutline = false;
        _error = _prettyError(e);
      });
    }
  }

  List<Lesson> _localOutline(String topic) {
    return [
      Lesson(
        title: 'Introduction to $topic',
        description: 'What $topic is, why it matters, and what you will learn.',
        duration: '20 minutes',
        difficulty: 'Beginner',
        objectives: const ['Define the topic', 'Understand the learning roadmap'],
        exercises: const [],
        isContentGenerated: false,
      ),
      Lesson(
        title: 'Core Concepts',
        description: 'Learn the key ideas and terms you must know to progress.',
        duration: '35 minutes',
        difficulty: 'Beginner',
        objectives: const ['Learn key terms', 'Understand the fundamentals'],
        exercises: const [],
        isContentGenerated: false,
      ),
      Lesson(
        title: 'Essential Techniques',
        description: 'The main techniques and patterns used in real work.',
        duration: '40 minutes',
        difficulty: 'Intermediate',
        objectives: const ['Apply techniques', 'Recognize common patterns'],
        exercises: const [],
        isContentGenerated: false,
      ),
      Lesson(
        title: 'Worked Examples',
        description: 'Step-by-step examples to connect theory to practice.',
        duration: '30 minutes',
        difficulty: 'Intermediate',
        objectives: const ['Follow examples', 'Explain each step'],
        exercises: const [],
        isContentGenerated: false,
      ),
      Lesson(
        title: 'Practice & Drills',
        description: 'Short exercises to build confidence and accuracy.',
        duration: '30 minutes',
        difficulty: 'Intermediate',
        objectives: const ['Practice actively', 'Self-check understanding'],
        exercises: const [],
        isContentGenerated: false,
      ),
      Lesson(
        title: 'Mini Project',
        description: 'Build something small using the skills you learned.',
        duration: '60 minutes',
        difficulty: 'Advanced',
        objectives: const ['Build a mini project', 'Reflect on improvements'],
        exercises: const [],
        isContentGenerated: false,
      ),
    ];
  }

  Future<void> _maybeAutoResume() async {
    if (!widget.autoResume) return;
    if (_didAutoResume) return;
    if (_lessons.isEmpty) return;

    _didAutoResume = true;
    final resumeIndex = await _store.getResumeLessonIndex(widget.topicId);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonDetailScreen(
          user: widget.user,
          topicId: widget.topicId,
          topicTitle: widget.topicTitle,
          lessonIndex: resumeIndex.clamp(0, _lessons.length - 1),
          allLessons: _lessons,
          studentProfile: widget.studentProfile,
        ),
      ),
    );

    final refreshed = await _store.getLessons(widget.topicId);
    if (!mounted) return;
    setState(() => _lessons = refreshed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = _lessons.where((l) => l.isCompleted).length;
    final total = _lessons.length;
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.topicTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    _generatingOutline ? 'Generating lesson outline...' : 'Loading lessons...',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOrGenerateOutline,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTopicHeader(isDark, progress, completed, total),
                  const SizedBox(height: 16),
                  if (_error != null) _buildError(isDark),
                  if (_lessons.isEmpty && _error == null) _buildEmpty(isDark),
                  if (_lessons.isNotEmpty) ..._buildLessonTiles(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildTopicHeader(bool isDark, double progress, int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.topicDescription,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.grey.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0 ? Colors.green : AppColors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                total == 0 ? '0%' : '${(progress * 100).round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$completed / $total lessons completed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(isDark ? 0.20 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.30)),
      ),
      child: Text(
        _error ?? 'Something went wrong.',
        style: TextStyle(color: isDark ? Colors.white70 : Colors.red.shade800),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'No lessons yet for this topic.',
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  List<Widget> _buildLessonTiles(bool isDark) {
    return List.generate(_lessons.length, (index) {
      final lesson = _lessons[index];
      final isResumeCandidate = _lessons.indexWhere((l) => !l.isCompleted) == index;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isResumeCandidate
              ? Border.all(color: AppColors.blue.withOpacity(0.8), width: 1.2)
              : Border.all(color: AppColors.blue.withOpacity(0.10)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: lesson.isCompleted
                  ? Colors.green.withOpacity(0.12)
                  : AppColors.blue.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              lesson.isCompleted ? Icons.check_rounded : Icons.play_arrow_rounded,
              color: lesson.isCompleted ? Colors.green : AppColors.blue,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  lesson.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (isResumeCandidate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'RESUME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      lesson.duration,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.bar_chart_rounded, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      lesson.difficulty,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LessonDetailScreen(
                  user: widget.user,
                  topicId: widget.topicId,
                  topicTitle: widget.topicTitle,
                  lessonIndex: index,
                  allLessons: _lessons,
                  studentProfile: widget.studentProfile,
                ),
              ),
            );
            final refreshed = await _store.getLessons(widget.topicId);
            if (!mounted) return;
            setState(() => _lessons = refreshed);
          },
        ),
      );
    });
  }
}
