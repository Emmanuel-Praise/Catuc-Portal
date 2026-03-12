import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:catuc_portal/shared/models/ai_user.dart';
import 'package:catuc_portal/student/models/student_profile.dart';
import 'package:catuc_portal/student/services/ai_learning_store.dart';
import 'package:catuc_portal/student/services/student_api_service.dart';
import 'package:catuc_portal/theme/app_colors.dart';

import 'learning_path_screen.dart';
import 'widgets/limit_reached_dialog.dart';

class LearnScreen extends StatefulWidget {
  final AiUser user;
  final Map<String, dynamic>? dashboardData;

  const LearnScreen({super.key, required this.user, this.dashboardData});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _api = const StudentApiService();
  final _store = const AiLearningStore();
  final _controller = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  String? _error;

  StudentProfile? _studentProfile;
  List<Map<String, dynamic>> _history = const [];
  static const _quickRequests = <String>[
    'Learn Python',
    'Learn UI Design',
    'Learn Calculus',
    'Learn Data Structures',
    'Learn Public Speaking',
  ];

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
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.user.role != 'teacher') {
        _studentProfile = await _api.getStudentProfile(widget.user.userId);
      }
      _history = await _store.listPaths(widget.user.userId);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _prettyError(e);
      });
    }
  }

  Future<void> _generateLearningPath() async {
    final request = _controller.text.trim();
    if (request.isEmpty) return;

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      List<Map<String, String>> topics;
      try {
        topics = await _api.generateLearningTopics(
          studentId: widget.user.userId,
          broadSubject: request,
          studentProfile: _studentProfile,
          role: widget.user.role,
        );
      } on AiLimitReachedException catch (e) {
        if (mounted) {
          await showLimitReachedDialog(
            context,
            studentId: widget.user.userId,
            planName: e.planName,
            usedToday: e.usedToday,
            dailyLimit: e.dailyLimit,
          );
        }
        topics = const [];
      } catch (e) {
        topics = const [];
        _error = 'AI is unavailable right now — using an offline learning path.';
      }

      if (topics.isEmpty) {
        topics = _localTopicsFor(request);
      }

      final pathId = const Uuid().v4();
      await _store.createPath(
        pathId: pathId,
        studentId: widget.user.userId,
        requestText: request,
        topics: topics,
      );

      if (!mounted) return;
      setState(() => _generating = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LearningPathScreen(
            user: widget.user,
            pathId: pathId,
            studentProfile: _studentProfile,
          ),
        ),
      );

      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = _prettyError(e);
      });
    }
  }

  List<Map<String, String>> _localTopicsFor(String request) {
    final subject = request.trim().isEmpty ? 'this topic' : request.trim();
    return [
      {'topic': 'Foundations of $subject', 'description': 'Core concepts and key terms you must know first.'},
      {'topic': 'Tools & Setup', 'description': 'Install, configure, and learn the essential tools.'},
      {'topic': 'Core Skills', 'description': 'Learn the main techniques and patterns used in practice.'},
      {'topic': 'Common Mistakes', 'description': 'Avoid the pitfalls that slow beginners down.'},
      {'topic': 'Practice Drills', 'description': 'Short exercises to build confidence quickly.'},
      {'topic': 'Mini Projects', 'description': 'Apply what you learned to realistic tasks.'},
      {'topic': 'Next Steps', 'description': 'How to keep improving after the basics.'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI Learning', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHero(isDark),
                  const SizedBox(height: 14),
                  _buildComposer(isDark),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _buildError(isDark),
                  ],
                  const SizedBox(height: 18),
                  _buildHistoryHeader(isDark),
                  const SizedBox(height: 10),
                  if (_history.isEmpty) _buildEmptyHistory(isDark),
                  ..._history.map((row) => _buildHistoryCard(isDark, row)),
                ],
              ),
            ),
    );
  }

  Widget _buildComposer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create a learning path',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Describe what you want to learn. AI will generate topics, then lessons, examples, and practice questions. Progress is saved automatically.',
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _quickRequests.map((text) {
              return ActionChip(
                label: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFFF1F5F9),
                side: BorderSide(color: AppColors.blue.withOpacity(0.22)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                onPressed: _generating
                    ? null
                    : () {
                        setState(() => _controller.text = text);
                        _generateLearningPath();
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _generating ? null : _generateLearningPath(),
            decoration: InputDecoration(
              hintText: 'e.g. Learn Python',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.blue, width: 2),
              ),
              suffixIcon: IconButton(
                tooltip: 'Generate learning path',
                onPressed: _generating ? null : _generateLearningPath,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generateLearningPath,
              icon: const Icon(Icons.route_rounded),
              label: Text(_generating ? 'Generating...' : 'Generate Learning Path'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue,
            AppColors.blue.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withOpacity(0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Learning Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Personalized course modules, generated on-demand.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
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
        _error ?? '',
        style: TextStyle(color: isDark ? Colors.white70 : Colors.red.shade800),
      ),
    );
  }

  Widget _buildHistoryHeader(bool isDark) {
    return Row(
      children: [
        Text(
          'Saved Paths',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const Spacer(),
        Icon(Icons.history_rounded, color: AppColors.blue),
      ],
    );
  }

  Widget _buildEmptyHistory(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'No saved learning paths yet. Generate your first one above.',
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  Widget _buildHistoryCard(bool isDark, Map<String, dynamic> row) {
    final pathId = (row['id'] ?? '').toString();
    final request = (row['request_text'] ?? '').toString();
    final updatedAt = DateTime.fromMillisecondsSinceEpoch((row['updated_at'] as int?) ?? 0);
    final total = (row['total_lessons'] as int?) ?? 0;
    final completed = (row['completed_lessons'] as int?) ?? 0;
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LearningPathScreen(
              user: widget.user,
              pathId: pathId,
              studentProfile: _studentProfile,
            ),
          ),
        );
        _load();
      },
      child: Container(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    request,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await _store.deletePath(pathId);
                      _load();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? Colors.green : AppColors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  total == 0 ? 'No lessons yet' : '$completed / $total lessons',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(updatedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
