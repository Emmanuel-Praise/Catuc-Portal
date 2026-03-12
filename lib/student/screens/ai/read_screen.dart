import 'dart:io' as io;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:doc_text_extractor/doc_text_extractor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import 'package:catuc_portal/config/app_config.dart';
import 'package:catuc_portal/student/models/student_notes_data.dart';
import 'package:catuc_portal/shared/models/ai_user.dart';
import 'package:catuc_portal/student/services/student_api_service.dart';
import 'package:catuc_portal/student/models/ai_chat_models.dart';
import 'package:catuc_portal/student/screens/ai/widgets/ai_history_drawer.dart';
import 'package:catuc_portal/student/screens/ai/widgets/limit_reached_dialog.dart';
import 'package:catuc_portal/theme/app_colors.dart';

class ReadScreen extends StatefulWidget {
  final AiUser user;
  final Map<String, dynamic>? dashboardData;

  const ReadScreen({super.key, required this.user, this.dashboardData});

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class SelectedSource {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final NoteMaterial? material;
  String? extractedText;

  SelectedSource({
    required this.name,
    this.path,
    this.bytes,
    this.material,
  });

  bool get isMaterial => material != null;
}

class _ReadScreenState extends State<ReadScreen> {
  final StudentApiService _apiService = const StudentApiService();
  final TextExtractor _textExtractor = TextExtractor();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isProcessing = false;
  bool _isGeneratingPdf = false;
  bool _isGeneratingQuestions = false;
  String _activeProgressLabel = '';
  
  // Multi-source state
  final List<SelectedSource> _selectedSources = [];
  
  String _summary = '';
  String _fullAnalysis = '';
  List<String> _pageSummaries = [];
  
  // Pagination/Chunking state
  int _currentChunkIndex = 0;
  int _totalChunks = 0;
  bool _hasMoreChunks = false;
  List<String> _allChunks = [];
  String? _analysisSessionId;

  // History state (Read AI)
  bool _loadingHistory = false;
  List<AIChatSession> _historySessions = [];

  // Persistent chat session (Ask Questions tab)
  String? _chatSessionId;

  // Chat with Notes state
  final List<AIChatMessage> _chatHistory = [];
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _explainController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isSendingChat = false;
  bool _isExplaining = false;

  String _explanation = '';
  String _quizType = 'mcq'; // mcq, structural, essay
  List<Map<String, dynamic>> _quizQuestions = [];

  bool _isLimitReachedChunk(String chunk) {
    final trimmed = chunk.trim();
    return trimmed.startsWith('{') && trimmed.contains('"limit_reached":true');
  }

  Future<bool> _handleLimitReachedIfNeeded(String chunk) async {
    if (!_isLimitReachedChunk(chunk)) return false;
    try {
      final decoded = jsonDecode(chunk);
      if (decoded is Map && decoded['limit_reached'] == true) {
        if (!mounted) return true;
        await showLimitReachedDialog(
          context,
          studentId: widget.user.userId,
          planName: decoded['current_plan']?['name'] ?? 'Free',
          usedToday: decoded['used_today'] ?? 10,
          dailyLimit: decoded['current_plan']?['daily_limit'] ?? 10,
        );
        return true;
      }
    } catch (_) {
      return true; // Don't show raw JSON in the UI.
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      endDrawer: _buildHistoryDrawer(isDark),
      appBar: AppBar(
        title: const Text(
          'Catu AI Study Suite',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: _openHistoryDrawer,
            icon: const Icon(Icons.history_rounded),
          ),
          if (_summary.isNotEmpty || _fullAnalysis.isNotEmpty)
            IconButton(
              tooltip: 'Download PDF',
              onPressed: _isGeneratingPdf ? null : _generatePdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSourcePanel(isDark),
            const SizedBox(height: 16),
            if (_isProcessing) _buildProcessingCard(isDark),
            if (_selectedSources.isNotEmpty || _summary.isNotEmpty || _fullAnalysis.isNotEmpty)
              Expanded(child: _buildResults(isDark)),
            if (_selectedSources.isEmpty && _summary.isEmpty && _fullAnalysis.isEmpty)
              Expanded(child: _buildEmptyState(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcePanel(bool isDark) {
    final hasSources = _selectedSources.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_stories_rounded, color: AppColors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catu AI Study Suite',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Upload multiple sources to analyze and generate questions.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _sourceButton(
                  label: 'Add Files',
                  icon: Icons.add_circle_outline_rounded,
                  onTap: _isProcessing ? null : _pickDeviceFile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _sourceButton(
                  label: 'Add Materials',
                  icon: Icons.library_add_rounded,
                  onTap: _isProcessing ? null : _pickInAppMaterial,
                ),
              ),
            ],
          ),
          if (hasSources) ...[
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _selectedSources.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final src = _selectedSources[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          src.isMaterial ? Icons.folder_special_rounded : Icons.description_rounded,
                          color: AppColors.blue,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            src.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() {
                            _selectedSources.removeAt(index);
                            _resetGeneratedState();
                          }),
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          if (hasSources) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isProcessing ? null : _clearSelection,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Clear All Sources'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sourceButton({
    required String label,
    required IconData icon,
    required void Function()? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.blue,
        elevation: 0,
        side: BorderSide(color: AppColors.blue.withOpacity(0.35)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildProcessingCard(bool isDark) {
    final hasChunks = _totalChunks > 0;
    final progressValue = hasChunks
        ? (_currentChunkIndex.clamp(0, _totalChunks) / _totalChunks)
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          if (hasChunks) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressValue == 0 ? null : progressValue,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
            ),
            const SizedBox(height: 6),
            Text(
              'Progress: ${(_currentChunkIndex + 1).clamp(1, _totalChunks)}/$_totalChunks',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            _activeProgressLabel.isEmpty
                ? 'Catu AI is reading your notes section by section and preparing a final summary.'
                : _activeProgressLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              labelColor: AppColors.blue,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              indicatorColor: AppColors.blue,
              tabs: const [
                Tab(text: 'Summary'),
                Tab(text: 'Explain'),
                Tab(text: 'Quizzes'),
                Tab(text: 'Ask Questions'),
              ],
            ),
          ),
          if (_hasMoreChunks) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _continueAnalysis,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text('Continue Analysis (Chunk ${_currentChunkIndex + 2} of $_totalChunks)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: BorderSide(color: AppColors.blue.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _resultPane(
                  isDark,
                  child: _buildSummaryTab(isDark),
                ),
                _resultPane(
                  isDark,
                  child: _buildExplainTab(isDark),
                ),
                _resultPane(
                  isDark,
                  child: _buildQuizTab(isDark),
                ),
                _resultPane(
                  isDark,
                  child: _buildChatTab(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(bool isDark) {
    if (_summary.isEmpty && !_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: AppColors.blue.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No Summary Generated',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _startNewAnalysis,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate Very Detailed Summary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: _summary.isEmpty ? _fullAnalysis : _summary,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: 15, height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          if (_summary.isNotEmpty) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPdf ? null : _generatePdf,
                icon: const Icon(Icons.download_rounded),
                label: Text(_isGeneratingPdf ? 'Preparing PDF...' : 'Download Detailed Summary (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExplainTab(bool isDark) {
    if (_explanation.isEmpty && !_isExplaining) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 48, color: AppColors.blue.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Need a simpler explanation?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _explainController,
              decoration: InputDecoration(
                hintText: 'Enter a specific part to explain (optional)',
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generateExplanation,
              icon: const Icon(Icons.psychology_rounded),
              label: const Text('Explain in Simple Terms'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    if (_isExplaining) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: MarkdownBody(
        data: _explanation,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(fontSize: 15, height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildQuizTab(bool isDark) {
    if (_quizQuestions.isEmpty && !_isGeneratingQuestions) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Question Type:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                _quizTypeChip('MCQ', 'mcq', isDark),
                _quizTypeChip('Structural', 'structural', isDark),
                _quizTypeChip('Essay', 'essay', isDark),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startQuizGeneration,
              icon: const Icon(Icons.quiz_rounded),
              label: const Text('Generate Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    if (_isGeneratingQuestions) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      itemCount: _quizQuestions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildQuizQuestionCard(isDark, index, _quizQuestions[index]);
      },
    );
  }

  Widget _quizTypeChip(String label, String value, bool isDark) {
    final isSelected = _quizType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _quizType = value);
      },
      selectedColor: AppColors.blue.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.blue : (isDark ? Colors.white60 : Colors.black54),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildQuizQuestionCard(bool isDark, int index, Map<String, dynamic> data) {
    final question = data['question'] as String;
    final answer = data['answer'] as String;
    bool showAnswer = data['showAnswer'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.blue,
                child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _quizType.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: question,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(height: 16),
          if (showAnswer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Answer:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 4),
                  Text(answer, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _quizQuestions[index]['showAnswer'] = !showAnswer;
              });
            },
            icon: Icon(showAnswer ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
            label: Text(showAnswer ? 'Hide Answer' : 'View Answer'),
            style: TextButton.styleFrom(foregroundColor: AppColors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab(bool isDark) {
    if (_chatHistory.isEmpty && !_isSendingChat) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.blue.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Ask anything about your sources',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 24),
            _buildChatInput(isDark),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _chatScrollController,
            itemCount: _chatHistory.length + (_isSendingChat ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == _chatHistory.length) {
                return _buildTypingIndicator(isDark);
              }
              final msg = _chatHistory[index];
              return _buildChatBubble(isDark, msg);
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildChatInput(isDark),
      ],
    );
  }

  Widget _buildChatInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              onSubmitted: (_) => _sendChatMessage(),
              decoration: const InputDecoration(
                hintText: 'Type a question...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
            ),
          ),
          IconButton(
            onPressed: _isSendingChat ? null : _sendChatMessage,
            icon: Icon(Icons.send_rounded, color: AppColors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(bool isDark, AIChatMessage msg) {
    final isAI = msg.role == 'assistant';
    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isAI 
              ? (isDark ? Colors.white.withOpacity(0.1) : Colors.white)
              : AppColors.blue,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isAI ? 0 : 16),
            bottomRight: Radius.circular(isAI ? 16 : 0),
          ),
          boxShadow: isAI ? [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ] : null,
        ),
        child: MarkdownBody(
          data: msg.content,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: 14,
              color: isAI 
                  ? (isDark ? Colors.white.withOpacity(0.9) : Colors.black87)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSendingChat) return;

    _chatController.clear();
    setState(() {
      _chatHistory.add(AIChatMessage(role: 'user', content: text));
      _isSendingChat = true;
    });
    _scrollToBottom();

    try {
      await _ensureTextExtracted();
      final context = _getSourceContext();
      if (context.isEmpty) {
         _showError('No source content available to chat with.');
         setState(() => _isSendingChat = false);
         return;
       }

      _chatSessionId ??= 'read_chat_${Uuid().v4()}';
      final trimmedContext = _trimContextForPrompt(context, maxChars: 14000);

      final prompt = '''
Answer the student's question STRICTLY using the notes below.
If the answer is not in the notes, say: "Not found in the provided notes." and then mention the closest related part.

Required format:
## Answer
## Evidence From Notes

STUDENT QUESTION:
$text

NOTES:
$trimmedContext
''';

      // Live-updating assistant bubble
      setState(() {
        _chatHistory.add(AIChatMessage(role: 'assistant', content: ''));
      });
      _scrollToBottom();

      final buffer = StringBuffer();
      var lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in _apiService.streamAiMessage(
        studentId: widget.user.userId,
        sessionId: _chatSessionId!,
        message: prompt,
        aiType: 'read',
        includeHistory: true,
      )) {
        if (await _handleLimitReachedIfNeeded(chunk)) {
          if (mounted) setState(() => _isSendingChat = false);
          return;
        }
        if (chunk.startsWith('Error:')) {
          throw Exception(chunk);
        }
        buffer.write(chunk);
        if (mounted) {
          final now = DateTime.now();
          if (now.difference(lastUiUpdate).inMilliseconds >= 80) {
            lastUiUpdate = now;
            setState(() {
              _chatHistory[_chatHistory.length - 1] = AIChatMessage(
                role: 'assistant',
                content: buffer.toString(),
              );
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _chatHistory[_chatHistory.length - 1] = AIChatMessage(
            role: 'assistant',
            content: buffer.toString(),
          );
        });
      }
      if (mounted) setState(() => _isSendingChat = false);
      _scrollToBottom();

    } catch (e) {
      _showError('Chat failed: $e');
      if (mounted) setState(() => _isSendingChat = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _resultPane(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 74,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 20),
          const Text(
            'No note source selected yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pick a file from your device or choose one of your in-app course materials.\nCatu AI will summarize it and generate a PDF for you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _ensureTextExtracted() async {
    bool changed = false;
    for (final src in _selectedSources) {
      if (src.extractedText == null) {
        src.extractedText = await _extractTextFromSource(src);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  void _clearSelection() {
    setState(() {
      _selectedSources.clear();
      _resetGeneratedState();
    });
  }

  Future<void> _startNewAnalysis() async {
    setState(() {
      _isProcessing = true;
      _summary = '';
      _fullAnalysis = '';
      _pageSummaries = [];
      _explanation = '';
      _quizQuestions = [];
      _allChunks = [];
      _currentChunkIndex = 0;
      _analysisSessionId = 'read_summary_${Uuid().v4()}';
      _activeProgressLabel = 'Catu AI is preparing your notes for live summary...';
    });

    try {
      await _ensureTextExtracted();
      final allText = _getSourceContext();
      if (allText.isEmpty) throw Exception('No readable text found in sources.');

      // 2. Chunk the combined text
      _allChunks = _chunkText(allText, chunkSize: 2000);
      _totalChunks = _allChunks.length;
      
      if (_totalChunks == 0) throw Exception('No readable text found in sources.');

      // 3. Process first batch (max 10 chunks to start)
      await _processChunks(startIndex: 0, count: 10);
      
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _activeProgressLabel = '';
        });
      }
    }
  }

  Future<void> _continueAnalysis() async {
    setState(() {
      _isProcessing = true;
      _activeProgressLabel = 'Catu AI is continuing the live summary...';
    });
    try {
      await _processChunks(startIndex: _currentChunkIndex + 1, count: 10);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _activeProgressLabel = '';
        });
      }
    }
  }

  Future<void> _processChunks({required int startIndex, required int count}) async {
    final endIndex = (startIndex + count).clamp(0, _totalChunks);
    for (var pageIndex = startIndex; pageIndex < endIndex; pageIndex++) {
      final pageNumber = pageIndex + 1;
      final prompt = '''
Study materials to analyze:

Page $pageNumber:
${_allChunks[pageIndex]}

Summarize this page only.
Use markdown and include:
## Final Summary
## Section $pageNumber
''';

      String summaryPrefix = '';
      if (mounted) {
        setState(() {
          _activeProgressLabel = 'Catu AI is summarizing page $pageNumber of $_totalChunks...';
          summaryPrefix = _summary.trim();
          _summary = summaryPrefix.isEmpty
              ? '## Page $pageNumber\n'
              : '$summaryPrefix\n\n## Page $pageNumber\n';
        });
      } else {
        summaryPrefix = _summary.trim();
      }

      final pageHeader = summaryPrefix.isEmpty
          ? '## Page $pageNumber\n'
          : '$summaryPrefix\n\n## Page $pageNumber\n';

      final result = await _streamReadResponse(
        prompt: prompt,
        sessionId: _analysisSessionId ?? 'read_summary_${Uuid().v4()}',
        includeHistory: false,
        onProgress: (current) {
          _summary = '$pageHeader$current';
        },
      );

      if (result.trim().isEmpty) {
        // Limit reached (dialog already shown) or empty response; stop processing further pages.
        return;
      }

      final parsed = _parseAnalysis(result);

      if (mounted) {
        setState(() {
          _fullAnalysis += (_fullAnalysis.isEmpty ? '' : '\n\n') + result;
          _pageSummaries.addAll(parsed.pages.isEmpty ? [result.trim()] : parsed.pages);
          _currentChunkIndex = pageIndex;
          _hasMoreChunks = _currentChunkIndex < _totalChunks - 1;
        });
      }
    }
  }

  Future<String> _streamReadResponse({
    required String prompt,
    required String sessionId,
    required void Function(String current) onProgress,
    bool includeHistory = true,
  }) async {
    final buffer = StringBuffer();
    var lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

    await for (final chunk in _apiService.streamAiMessage(
      studentId: widget.user.userId,
      sessionId: sessionId,
      message: prompt,
      aiType: 'read',
      includeHistory: includeHistory,
    )) {
      if (await _handleLimitReachedIfNeeded(chunk)) {
        return '';
      }
      if (chunk.startsWith('Error:')) {
        throw Exception(chunk);
      }

      buffer.write(chunk);
      if (mounted) {
        final now = DateTime.now();
        if (now.difference(lastUiUpdate).inMilliseconds >= 80) {
          lastUiUpdate = now;
          setState(() => onProgress(buffer.toString()));
        }
      }
    }

    if (mounted) {
      setState(() => onProgress(buffer.toString()));
    }
    return buffer.toString().trim();
  }

  Future<String> _extractTextFromSource(SelectedSource src) async {
    if (src.isMaterial) {
      final url = _resolveMaterialUrl(src.material!.downloadUrl);
      final result = await _textExtractor.extractText(url, isUrl: true);
      return result.text;
    } else {
      final String source;
      if (kIsWeb) {
        final base64File = base64Encode(src.bytes!);
        final mimeType = _getMimeType(src.name);
        source = 'data:$mimeType;base64,$base64File';
      } else {
        source = src.path ?? await _ensureLocalFileFromBytes(src.bytes!, src.name);
      }
      final result = await _textExtractor.extractText(source, isUrl: kIsWeb);
      return result.text;
    }
  }

  Future<String> _ensureLocalFileFromBytes(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = io.File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  String _getSourceContext() {
    final aggregated = _selectedSources.map((s) => s.extractedText ?? '').join('\n\n');
    return aggregated.trim();
  }

  Future<void> _generateExplanation() async {
    setState(() => _isExplaining = true);
    try {
      await _ensureTextExtracted();
      final context = _getSourceContext();
      if (context.isEmpty) {
        _showError('No readable text found in sources.');
        return;
      }

      final specificPart = _explainController.text.trim();
      final msg = specificPart.isEmpty 
        ? context 
        : "Based on these notes: \n\n$context\n\nPlease explain this specific part in simple terms: $specificPart";

      setState(() => _explanation = '');
      await _streamReadResponse(
        prompt: '''
Please explain these notes in simple terms.
Use real-world examples and break the ideas down step by step.

$msg
''',
        sessionId: 'read_explain_${Uuid().v4()}',
        includeHistory: false,
        onProgress: (current) {
          _explanation = current;
        },
      );
    } catch (e) {
      _showError('Explanation failed: $e');
    } finally {
      if (mounted) setState(() => _isExplaining = false);
    }
  }

  Future<void> _startQuizGeneration() async {
    setState(() => _isGeneratingQuestions = true);
    try {
      await _ensureTextExtracted();
      final context = _getSourceContext();
      if (context.isEmpty) {
        _showError('No readable text found in sources.');
        return;
      }

      String rawQuiz = '';
      await _streamReadResponse(
        prompt: '''
Generate 5 to 10 ${_quizType == 'essay' ? 'essay questions' : _quizType == 'structural' ? 'structural or short-answer questions' : 'multiple-choice questions with four options each'}
from the notes below.
For every question, include the answer under the exact label [Answer]:

$context
''',
        sessionId: 'read_quiz_${Uuid().v4()}',
        includeHistory: false,
        onProgress: (current) {
          rawQuiz = current;
        },
      );
      setState(() {
        _quizQuestions = _parseQuizzes(rawQuiz);
      });
    } catch (e) {
      _showError('Quiz generation failed: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingQuestions = false);
    }
  }

  List<Map<String, dynamic>> _parseQuizzes(String raw) {
    final cleaned = raw.replaceAll('\r\n', '\n').trim();
    final List<Map<String, dynamic>> questions = [];
    if (cleaned.isEmpty) {
      return questions;
    }

    // Split by common question numbering styles: "1.", "1)", "Q1:", etc.
    final startRegex = RegExp(r'(?m)^(?:\s*)(?:Q\s*)?\d+\s*[\.\)\:\-]\s+');
    final matches = startRegex.allMatches(cleaned).toList();

    final List<String> blocks;
    if (matches.length >= 2) {
      blocks = [];
      for (var i = 0; i < matches.length; i++) {
        final start = matches[i].start;
        final end = (i + 1 < matches.length) ? matches[i + 1].start : cleaned.length;
        final piece = cleaned.substring(start, end).trim();
        if (piece.isNotEmpty) blocks.add(piece);
      }
    } else {
      blocks = cleaned
          .split(RegExp(r'\n(?=\d+[\.\)]\s+)'))
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .toList();
    }

    for (final block in blocks) {
      final answerMatch = RegExp(r'(?i)\[?answer\]?\s*:\s*').firstMatch(block);
      final answerIndex = answerMatch?.start ?? -1;
      final labelLen = answerMatch?.group(0)?.length ?? 0;

      final questionPart = answerIndex >= 0 ? block.substring(0, answerIndex).trim() : block.trim();
      final answerPart = answerIndex >= 0
          ? block.substring(answerIndex + labelLen).trim()
          : 'Consult your notes for the answer.';

      if (questionPart.isEmpty) {
        continue;
      }

      questions.add({
        'question': questionPart,
        'answer': answerPart.isEmpty ? 'Consult your notes for the answer.' : answerPart,
        'showAnswer': false,
      });
    }

    if (questions.isEmpty) {
      questions.add({
        'question': cleaned,
        'answer': 'Consult your notes for the answer.',
        'showAnswer': false,
      });
    }

    return questions;
  }

  Future<void> _pickDeviceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (result != null) {
      setState(() {
        _resetGeneratedState();
        for (var file in result.files) {
          _selectedSources.add(SelectedSource(
            name: file.name,
            path: file.path,
            bytes: file.bytes,
          ));
        }
      });
    }
  }

  Future<void> _pickInAppMaterial() async {
    final courses = (widget.dashboardData?['courses'] as List?)
            ?.map((c) => NoteCourse.fromJson(c))
            .toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MaterialPickerSheet(
        user: widget.user,
        courses: courses,
        apiService: _apiService,
        onPicked: (mat) {
          setState(() {
            _resetGeneratedState();
            _selectedSources.add(SelectedSource(
              name: mat.title.isEmpty ? mat.fileName : mat.title,
              material: mat,
            ));
          });
        },
      ),
    );
  }

  String _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.md')) return 'text/markdown';
    return 'application/octet-stream';
  }

  List<String> _chunkText(String text, {required int chunkSize}) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final chunks = <String>[];
    var start = 0;
    while (start < compact.length) {
      final end = (start + chunkSize < compact.length)
          ? compact.lastIndexOf(' ', start + chunkSize)
          : compact.length;
      final safeEnd = end <= start ? (start + chunkSize).clamp(0, compact.length) : end;
      final piece = compact.substring(start, safeEnd).trim();
      if (piece.isNotEmpty) {
        chunks.add(piece);
      }
      start = safeEnd;
    }
    return chunks;
  }

  void _resetGeneratedState() {
    _summary = '';
    _fullAnalysis = '';
    _pageSummaries = [];
    _explanation = '';
    _quizQuestions = [];
    _chatHistory.clear();
    _chatController.clear();
    _explainController.clear();
    _hasMoreChunks = false;
    _currentChunkIndex = 0;
    _totalChunks = 0;
    _allChunks = [];
    _activeProgressLabel = '';
    _analysisSessionId = null;
    _chatSessionId = null;
  }

  _ParsedReadAnalysis _parseAnalysis(String analysis) {
    final normalized = analysis.replaceAll('\r\n', '\n');
    
    // Extract Final Summary
    final finalSummaryMatch = RegExp(
      r'##\s*Final Summary\s*\n?([\s\S]*?)(?=\n##\s*Page|\nPage\s+\d+|\Z)',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(normalized);

    // Extract all Page/Section sections
    final pageMatches = RegExp(
      r'##\s*(?:Page|Section)\s+(\d+)\s*\n?([\s\S]*?)(?=\n##\s*(?:Page|Section)|\n(?:Page|Section)\s+\d+|\Z)',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(normalized);

    final pages = pageMatches
        .map((match) => (match.group(2) ?? '').trim())
        .where((text) => text.isNotEmpty)
        .toList();

    return _ParsedReadAnalysis(
      summary: (finalSummaryMatch?.group(1) ?? '').trim(),
      pages: pages,
    );
  }

  Widget _buildHistoryDrawer(bool isDark) {
    if (_loadingHistory) {
      return Drawer(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return AIHistoryDrawer(
      aiType: 'read',
      sessions: _historySessions,
      onSelectSession: _loadHistorySession,
      onNewChat: _startNewHistoryView,
      onDeleteSession: _deleteHistorySession,
    );
  }

  Future<void> _openHistoryDrawer() async {
    if (_loadingHistory) return;
    setState(() => _loadingHistory = true);
    try {
      final sessions = await _apiService.fetchAiSessions(
        studentId: widget.user.userId,
        aiType: 'read',
      );
      if (mounted) {
        setState(() {
          _historySessions = sessions;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
      _showError('Could not load history: $e');
    }

    if (mounted) {
      _scaffoldKey.currentState?.openEndDrawer();
    }
  }

  Future<void> _loadHistorySession(AIChatSession session) async {
    setState(() => _isProcessing = true);
    try {
      final messages = await _apiService.fetchAiHistory(session.id);
      final assistant = messages
          .where((m) => m.role == 'assistant')
          .map((m) => m.content.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final combined = assistant.join('\n\n');
      if (mounted) {
        setState(() {
          _summary = combined;
          _fullAnalysis = combined;
          _pageSummaries = const [];
          _hasMoreChunks = false;
          _totalChunks = 0;
          _currentChunkIndex = 0;
        });
      }
    } catch (e) {
      _showError('Could not load history session: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _startNewHistoryView() {
    setState(() {
      _summary = '';
      _fullAnalysis = '';
      _pageSummaries = [];
      _hasMoreChunks = false;
      _totalChunks = 0;
      _currentChunkIndex = 0;
    });
  }

  Future<void> _deleteHistorySession(String sessionId) async {
    try {
      await _apiService.deleteAiSession(sessionId);
      final sessions = await _apiService.fetchAiSessions(
        studentId: widget.user.userId,
        aiType: 'read',
      );
      if (mounted) setState(() => _historySessions = sessions);
    } catch (e) {
      _showError('Could not delete history: $e');
    }
  }


  String _resolveMaterialUrl(String rawUrl) {
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }

    final apiBase = AppConfig.baseUrl;
    final origin = apiBase.endsWith('/api')
        ? apiBase.substring(0, apiBase.length - 4)
        : apiBase;
    if (rawUrl.startsWith('/')) {
      return '$origin$rawUrl';
    }
    return '$origin/$rawUrl';
  }

  Future<void> _generatePdf({bool includePages = true}) async {
    final hasAnyContent = _summary.trim().isNotEmpty || _fullAnalysis.trim().isNotEmpty || _pageSummaries.isNotEmpty;
    if (!hasAnyContent) return;

    setState(() => _isGeneratingPdf = true);
    try {
      var includePagesResolved = includePages;
      // Large exports can fail on low-memory devices; prefer "what you have" (summary-only).
      if (includePagesResolved && _pageSummaries.length > 25) {
        includePagesResolved = false;
      }

      final pdf = pw.Document();
      final summaryText = _summary.trim().isNotEmpty ? _summary : _fullAnalysis;
      final sourceLabel = _selectedSources.isEmpty
          ? 'History / Previous session'
          : _selectedSources.map((s) => s.name).join(', ');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            pw.Text(
              'Catu AI Read Summary',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Source: $sourceLabel'),
            pw.SizedBox(height: 6),
            pw.Text('Generated on ${DateTime.now()}'),
            pw.SizedBox(height: 20),
            pw.Text(
              'Final Summary',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            ..._pdfParagraphs(summaryText),
            if (includePagesResolved && _pageSummaries.isNotEmpty) pw.SizedBox(height: 18),
            if (includePagesResolved)
              for (var i = 0; i < _pageSummaries.length; i++) ...[
                pw.Text(
                  'Page ${i + 1}',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                ..._pdfParagraphs(_pageSummaries[i]),
                pw.SizedBox(height: 12),
              ],
          ],
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'catu_read_summary_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (!includePagesResolved && includePages && mounted && _pageSummaries.length > 25) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exported summary-only PDF (the full export is very large).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Could not generate the PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  List<pw.Widget> _pdfParagraphs(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];

    final paragraphs = normalized
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    return [
      for (final p in paragraphs) ...[
        pw.Text(p),
        pw.SizedBox(height: 8),
      ],
    ];
  }

  String _trimContextForPrompt(String text, {required int maxChars}) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.length <= maxChars) return normalized;
    final head = normalized.substring(0, (maxChars * 0.8).round());
    final tailLen = maxChars - head.length;
    final tail = normalized.substring(normalized.length - tailLen);
    return '$head\n\n[...snipped...]\n\n$tail';
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message\n(API: ${AppConfig.baseUrl})'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MaterialPickerSheet extends StatefulWidget {
  final AiUser user;
  final List<NoteCourse> courses;
  final StudentApiService apiService;
  final ValueChanged<NoteMaterial> onPicked;

  const _MaterialPickerSheet({
    required this.user,
    required this.courses,
    required this.apiService,
    required this.onPicked,
  });

  @override
  State<_MaterialPickerSheet> createState() => _MaterialPickerSheetState();
}

class _MaterialPickerSheetState extends State<_MaterialPickerSheet> {
  NoteCourse? _selectedCourse;
  bool _loadingMaterials = false;
  List<NoteMaterial> _materials = const [];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCourse == null ? 'Choose a Course' : 'Choose Material',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _selectedCourse == null
                  ? ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.courses.length,
                      itemBuilder: (context, index) {
                        final course = widget.courses[index];
                        return ListTile(
                          onTap: () => _loadMaterials(course),
                          leading: const Icon(Icons.menu_book_rounded),
                          title: Text('${course.courseCode} - ${course.courseName}'),
                          subtitle: Text('${course.materialCount} materials'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        );
                      },
                      separatorBuilder: (_, _) => const Divider(height: 1),
                    )
                  : _loadingMaterials
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => setState(() {
                                  _selectedCourse = null;
                                  _materials = const [];
                                }),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back to courses'),
                              ),
                            ),
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _materials.length,
                                itemBuilder: (context, index) {
                                  final material = _materials[index];
                                  return ListTile(
                                    onTap: () {
                                      widget.onPicked(material);
                                      Navigator.of(context).pop();
                                    },
                                    leading: const Icon(Icons.description_rounded),
                                    title: Text(
                                      material.title.isEmpty
                                          ? material.fileName
                                          : material.title,
                                    ),
                                    subtitle: Text(
                                      material.description.isEmpty
                                          ? material.uploadDate
                                          : material.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                                separatorBuilder: (_, _) => const Divider(height: 1),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMaterials(NoteCourse course) async {
    setState(() {
      _selectedCourse = course;
      _loadingMaterials = true;
    });
    try {
      final materials = await widget.apiService.fetchCourseMaterials(
        studentId: widget.user.userId,
        courseId: course.courseId,
      );
      if (mounted) {
        setState(() {
          _materials = materials.where((item) => item.downloadUrl.trim().isNotEmpty).toList();
          _loadingMaterials = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _materials = const [];
          _loadingMaterials = false;
        });
      }
    }
  }
}

class _ParsedReadAnalysis {
  final String summary;
  final List<String> pages;

  const _ParsedReadAnalysis({
    required this.summary,
    required this.pages,
  });
}
