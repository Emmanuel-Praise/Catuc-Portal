import 'package:flutter/material.dart';
import 'package:catuc_portal/shared/models/ai_user.dart';
import 'package:catuc_portal/theme/app_colors.dart';

import '../../models/student_profile.dart';
import '../../services/ai_learning_store.dart';
import 'topic_lessons_screen.dart';

class LearningPathScreen extends StatefulWidget {
  final AiUser user;
  final String pathId;
  final StudentProfile? studentProfile;

  const LearningPathScreen({
    super.key,
    required this.user,
    required this.pathId,
    this.studentProfile,
  });

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  final _store = const AiLearningStore();
  bool _loading = true;
  String _requestText = '';
  List<Map<String, dynamic>> _topics = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pathRow = await _store.getPath(widget.pathId);
    final topics = await _store.listTopics(widget.pathId);
    if (!mounted) return;
    setState(() {
      _requestText = (pathRow?['request_text'] ?? '').toString();
      _topics = topics;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Learning Path',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHero(isDark),
                  const SizedBox(height: 16),
                  Text(
                    'Topics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_topics.isEmpty)
                    _buildEmptyTopics(isDark)
                  else
                    ..._topics.map((t) => _buildTopicCard(isDark, t)),
                ],
              ),
            ),
    );
  }

  Widget _buildHero(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue.withOpacity(0.95),
            AppColors.blue.withOpacity(0.70),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your learning path',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _requestText.isEmpty ? 'Your request' : _requestText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap a topic to generate lessons. Lessons are cached and you can resume anytime.',
            style: TextStyle(
              fontSize: 13,
              height: 1.25,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTopics(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'No topics found for this path.',
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  Widget _buildTopicCard(bool isDark, Map<String, dynamic> topic) {
    final title = (topic['title'] ?? '').toString();
    final desc = (topic['description'] ?? '').toString();
    final topicId = (topic['id'] ?? '').toString();
    final completed = (topic['completed_lessons'] as int?) ?? 0;
    final total = (topic['total_lessons'] as int?) ?? 0;
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopicLessonsScreen(
              user: widget.user,
              pathId: widget.pathId,
              topicId: topicId,
              topicTitle: title,
              topicDescription: desc,
              studentProfile: widget.studentProfile,
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
          border: Border.all(color: AppColors.blue.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    total == 0 ? 'New' : '$completed / $total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
            if (total > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1.0 ? Colors.green : AppColors.blue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
