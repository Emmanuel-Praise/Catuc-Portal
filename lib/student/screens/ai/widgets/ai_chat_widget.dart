import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/themes/github.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../../theme/app_colors.dart';
import '../../../../shared/models/ai_user.dart';
import '../../../models/ai_chat_models.dart';
import '../../../services/student_api_service.dart';
import 'ai_history_drawer.dart';
import 'limit_reached_dialog.dart';
import 'thinking_indicator.dart';

class AIChatWidget extends StatefulWidget {
  final AiUser user;
  final String aiType;
  final String title;
  final String hintText;
  final String? initialMessage;
  final Map<String, dynamic>? codeHighlightTheme;
  final List<String>? supportedLanguages;

  const AIChatWidget({
    super.key,
    required this.user,
    required this.aiType,
    required this.title,
    required this.hintText,
    this.initialMessage,
    this.codeHighlightTheme,
    this.supportedLanguages,
  });

  @override
  State<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends State<AIChatWidget> {
  static const List<Map<String, dynamic>> _voiceProfiles = [
    {
      'id': 'en-us-female',
      'label': 'English Female',
      'ttsLanguage': 'en-US',
      'sttLocale': 'en_US',
      'pitch': 1.08,
      'rate': 0.50,
      'female': true,
    },
    {
      'id': 'en-us-male',
      'label': 'English Male',
      'ttsLanguage': 'en-US',
      'sttLocale': 'en_US',
      'pitch': 0.92,
      'rate': 0.48,
      'female': false,
    },
    {
      'id': 'fr-fr-female',
      'label': 'Francais Female',
      'ttsLanguage': 'fr-FR',
      'sttLocale': 'fr_FR',
      'pitch': 1.06,
      'rate': 0.47,
      'female': true,
    },
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AIChatMessage> _messages = [];
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isLoading = false;
  bool _isStreaming = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isSpeechReady = false;
  bool _isTtsReady = false;
  bool _hasStartedVoiceGreeting = false;
  bool _resumeListeningAfterSpeech = false;
  String _voiceDraft = '';
  String _selectedVoiceId = 'en-us-female';

  Timer? _silenceTimer;

  String _currentSessionId = const Uuid().v4();
  List<AIChatSession> _sessions = [];
  final StudentApiService _apiService = const StudentApiService();

  Map<String, dynamic>? _usageData;

  bool get _voiceEnabled => widget.aiType == 'voice';

  @override
  void initState() {
    super.initState();
    _checkUsageAndLoadSessions();
    if (_voiceEnabled) {
      _initializeVoiceFeatures();
    }
    if (widget.initialMessage != null && widget.initialMessage!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.text = widget.initialMessage!.trim();
        _sendMessage();
      });
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speechToText.cancel();
    _flutterTts.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeVoiceFeatures() async {
    await _initSpeech();
    await _initTts();

    if (!_hasStartedVoiceGreeting &&
        (widget.initialMessage == null || widget.initialMessage!.trim().isEmpty)) {
      _hasStartedVoiceGreeting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final greeting = _buildGreeting();
        setState(() {
          _messages.add(AIChatMessage(role: 'assistant', content: greeting));
        });
        _scrollToBottom();
        await _speakText(greeting, resumeListeningAfter: true);
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      _isSpeechReady = await _speechToText.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if ((status == 'done' || status == 'notListening') && _isListening) {
            _finalizeListening();
          }
        },
        onError: (_) {
          if (!mounted) return;
          if (_isListening) {
            _finalizeListening();
          }
        },
        debugLogging: false,
      );
    } catch (_) {
      _isSpeechReady = false;
    }
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setVolume(1.0);
      await _applyVoiceProfile(_selectedVoiceId, announceChange: false);
      _flutterTts.setStartHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = true);
      });
      _flutterTts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
        if (_resumeListeningAfterSpeech) {
          _resumeListeningAfterSpeech = false;
          _startListening();
        }
      });
      _flutterTts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
        if (_resumeListeningAfterSpeech) {
          _resumeListeningAfterSpeech = false;
          _startListening();
        }
      });
      _isTtsReady = true;
    } catch (_) {
      _isTtsReady = false;
    }
  }

  Map<String, dynamic> get _selectedVoiceProfile {
    return _voiceProfiles.firstWhere(
      (profile) => profile['id'] == _selectedVoiceId,
      orElse: () => _voiceProfiles.first,
    );
  }

  bool get _isFrenchVoice {
    return (_selectedVoiceProfile['ttsLanguage'] as String).toLowerCase().startsWith('fr');
  }

  String get _currentSttLocale => _selectedVoiceProfile['sttLocale'] as String;

  String _buildGreeting() {
    if (_isFrenchVoice) {
      return 'Bonjour, je suis votre assistant IA. Comment puis-je vous aider aujourd\'hui ?';
    }
    return 'Hello, I am your AI assistant. How can I help you today?';
  }

  Future<void> _applyVoiceProfile(
    String voiceId, {
    bool announceChange = true,
  }) async {
    final profile = _voiceProfiles.firstWhere(
      (item) => item['id'] == voiceId,
      orElse: () => _voiceProfiles.first,
    );

    _selectedVoiceId = profile['id'] as String;

    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(profile['ttsLanguage'] as String);
      await _flutterTts.setPitch((profile['pitch'] as num).toDouble());
      await _flutterTts.setSpeechRate((profile['rate'] as num).toDouble());

      // Try to force a female/male voice when the platform supports it.
      try {
        final desiredLocale = (profile['ttsLanguage'] as String).replaceAll('_', '-').toLowerCase();
        final desiredLang = desiredLocale.split('-').first;
        final wantsFemale = profile['female'] == true;

        final voices = await _flutterTts.getVoices;
        if (voices is List) {
          Map<dynamic, dynamic>? best;
          int bestScore = -1;

          for (final v in voices) {
            if (v is! Map) continue;
            final name = (v['name'] ?? '').toString();
            final locale = (v['locale'] ?? '').toString().replaceAll('_', '-');
            if (name.isEmpty || locale.isEmpty) continue;

            final localeLower = locale.toLowerCase();
            if (!(localeLower == desiredLocale || localeLower.startsWith('$desiredLang-'))) continue;

            final nameLower = name.toLowerCase();
            final gender = (v['gender'] ?? '').toString().toLowerCase();
            final isFemale = gender == 'female' || nameLower.contains('female') || nameLower.contains('#female') || nameLower.contains('woman') || nameLower.contains('fem');
            final isMale = gender == 'male' || nameLower.contains('male') || nameLower.contains('#male') || nameLower.contains('man');

            int score = 0;
            if (localeLower == desiredLocale) score += 4;
            if (wantsFemale && isFemale) score += 3;
            if (!wantsFemale && isMale) score += 3;
            if (nameLower.contains('network')) score -= 1;

            if (score > bestScore) {
              bestScore = score;
              best = Map<dynamic, dynamic>.from(v);
            }
          }

          if (best != null) {
            await _flutterTts.setVoice({
              'name': best['name'].toString(),
              'locale': best['locale'].toString(),
            });
          }
        }
      } catch (_) {
        // Ignore: not all platforms support getVoices/setVoice.
      }
    } catch (_) {
      _showError('The selected voice is not available on this device.');
    }

    if (!mounted) {
      return;
    }

    setState(() {});

    if (announceChange) {
      final confirmation = _isFrenchVoice
          ? 'Voix changee. Nous pouvons parler en francais.'
          : 'Voice changed. We can continue talking now.';
      await _speakText(confirmation);
    }
  }

  Future<void> _speakText(
    String text, {
    bool resumeListeningAfter = false,
  }) async {
    final cleaned = _prepareSpeechText(text);
    if (cleaned.isEmpty || !_isTtsReady || !mounted) return;

    _resumeListeningAfterSpeech = resumeListeningAfter;
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(cleaned);
    } catch (_) {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
      if (_resumeListeningAfterSpeech) {
        _resumeListeningAfterSpeech = false;
        await _startListening();
      }
    }
  }

  String _prepareSpeechText(String text) {
    var cleaned = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
        .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1')
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .replaceAll(RegExp(r'[#>*_~-]'), ' ')
        .replaceAll(':', ', ')
        .replaceAll(';', ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) {
      return '';
    }

    if (_isFrenchVoice) {
      return cleaned;
    }

    if (!RegExp(r'[.!?]$').hasMatch(cleaned)) {
      cleaned = '$cleaned.';
    }

    final lower = cleaned.toLowerCase();
    if (lower.startsWith('sorry') || lower.startsWith('i can')) {
      return cleaned;
    }

    return 'Alright, $cleaned';
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;
    setState(() => _voiceDraft = words);
    _resetSilenceTimer();

    if (result.finalResult) {
      _finalizeListening();
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 6), () {
      if (_isListening) {
        _finalizeListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (_isListening || _isStreaming || _isSpeaking) return;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showError('Microphone permission is required for voice chat.');
      return;
    }

    if (!_isSpeechReady) {
      await _initSpeech();
    }
    if (!_isSpeechReady) {
      _showError('Speech recognition is not available on this device.');
      return;
    }

    try {
      setState(() {
        _isListening = true;
        _voiceDraft = '';
      });
      _resetSilenceTimer();
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 6),
        localeId: _currentSttLocale,
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _stopListeningOnly() async {
    _silenceTimer?.cancel();
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _finalizeListening() async {
    final spoken = _voiceDraft.trim();
    await _stopListeningOnly();
    if (mounted) {
      setState(() => _voiceDraft = '');
    }
    if (spoken.isNotEmpty) {
      await _sendMessage(voiceText: spoken, fromVoice: true);
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isStreaming) return;
    if (_isListening) {
      await _finalizeListening();
      return;
    }
    if (_isSpeaking) {
      try {
        _resumeListeningAfterSpeech = false;
        await _flutterTts.stop();
      } catch (_) {}
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
    await _startListening();
  }

  Future<void> _checkUsageAndLoadSessions() async {
    setState(() => _isLoading = true);
    try {
      final studentId = widget.user.userId;

      // Proactive usage check
      final usage = await _apiService.checkAiUsage(studentId);

      // Load sessions
      final sessions = await _apiService.fetchAiSessions(studentId: studentId, aiType: widget.aiType);

      setState(() {
        _usageData = usage;
        _sessions = sessions;
        _isLoading = false;
      });

      // Notify user of their plan/usage
      if (usage['ok'] == true) {
        final plan = usage['plan'] ?? {};
        final remaining = usage['remaining'] ?? 0;
        final isUnlimited = usage['is_unlimited'] == true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUnlimited 
              ? 'You have Unlimited AI messages on the ${plan['name']} plan!' 
              : 'You have $remaining messages left for today (${plan['name']} plan).'),
            backgroundColor: AppColors.primary(context),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Connection error. Please try again.');
    }
  }

  Future<void> _loadSession(AIChatSession session) async {
    setState(() {
      _currentSessionId = session.id;
      _isLoading = true;
    });
    try {
      final history = await _apiService.fetchAiHistory(session.id);
      setState(() {
        _messages.clear();
        _messages.addAll(history);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load history');
    }
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = const Uuid().v4();
      _messages.clear();
      _controller.clear();
    });
    if (_voiceEnabled && _isTtsReady) {
      _hasStartedVoiceGreeting = false;
      _initializeVoiceFeatures();
    }
  }

  Future<void> _deleteSession(String id) async {
    try {
      await _apiService.deleteAiSession(id);
      if (id == _currentSessionId) _startNewChat();
      _refreshSessions();
    } catch (_) {}
  }

  Future<void> _refreshSessions() async {
    try {
      final sessions = await _apiService.fetchAiSessions(studentId: widget.user.userId, aiType: widget.aiType);
      setState(() => _sessions = sessions);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary(context);

    return Scaffold(
      drawer: AIHistoryDrawer(
        aiType: widget.aiType,
        sessions: _sessions,
        onSelectSession: _loadSession,
        onNewChat: _startNewChat,
        onDeleteSession: _deleteSession,
      ),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (_voiceEnabled)
            IconButton(
              tooltip: 'Voice options',
              onPressed: _showVoicePicker,
              icon: const Icon(Icons.record_voice_over),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg, isDark);
                  },
                ),
          ),
          _buildInputArea(isDark, primary),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AIChatMessage msg, bool isDark) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary(context)
              : (isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: !isUser ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isThinking)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: ThinkingIndicator(),
              )
            else
              MarkdownBody(
                data: msg.content,
                selectable: true,
                builders: {
                  'code': CodeBlockBuilder(
                    theme: widget.codeHighlightTheme,
                    supportedLanguages: widget.supportedLanguages,
                  ),
                },
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    fontSize: 15,
                  ),
                  code: TextStyle(
                    backgroundColor: isDark ? Colors.black26 : Colors.black12,
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: isDark ? Colors.black45 : Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_voiceEnabled && (_isListening || _isSpeaking || _voiceDraft.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    _isListening
                        ? Icons.hearing
                        : _isSpeaking
                            ? Icons.volume_up
                            : Icons.mic_none,
                    size: 18,
                    color: _isListening ? Colors.red : primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isListening
                          ? (_voiceDraft.isEmpty ? 'Listening...' : _voiceDraft)
                          : _isSpeaking
                              ? 'AI is speaking...'
                              : '${_selectedVoiceProfile['label']} selected',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showVoicePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_selectedVoiceProfile['label']}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _isStreaming ? null : _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              if (_voiceEnabled) ...[
                CircleAvatar(
                  backgroundColor: _isListening ? Colors.red : (isDark ? Colors.white24 : Colors.black26),
                  radius: 24,
                  child: IconButton(
                    icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic, color: Colors.white),
                    onPressed: _isStreaming ? null : _toggleVoiceInput,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              CircleAvatar(
                backgroundColor: _isStreaming ? Colors.grey : primary,
                radius: 24,
                child: IconButton(
                  icon: Icon(_isStreaming ? Icons.hourglass_bottom : Icons.send, color: Colors.white),
                  onPressed: _isStreaming ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage({String? voiceText, bool fromVoice = false}) async {
    final text = (voiceText ?? _controller.text).trim();
    if (text.isEmpty || _isStreaming) return;

    final studentId = widget.user.userId;
    if (studentId.isEmpty) {
      _showError('Student ID not found. Please log in again.');
      return;
    }

    // Add user message immediately
    setState(() {
      _messages.add(AIChatMessage(role: 'user', content: text));
      _isStreaming = true;
    });

    // Add thinking indicator after a short delay to make it visible
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _isStreaming) {
        setState(() {
          // Only add thinking if there's no assistant message yet
          if (_messages.isEmpty || _messages.last.role != 'assistant') {
            _messages.add(AIChatMessage(role: 'assistant', content: '', isThinking: true));
          }
        });
        _scrollToBottom();
      }
    });

    if (voiceText == null) {
      _controller.clear();
    }
    _scrollToBottom();

    String assistantReplyForVoice = '';
    final backendMessage = _buildBackendMessage(text, fromVoice: fromVoice);

    try {
      final stream = _apiService.streamAiMessage(
        studentId: studentId,
        sessionId: _currentSessionId,
        message: backendMessage,
        aiType: widget.aiType,
      );

      bool started = false;
      String accumulatedContent = '';

      await for (final chunk in stream) {
        if (!mounted) break;

        // Check for limit reached or error responses
        if (chunk.trim().startsWith('{') && chunk.trim().contains('"limit_reached":true')) {
          try {
            final decoded = jsonDecode(chunk);
            if (decoded['limit_reached'] == true) {
              // Remove thinking indicator if present
              if (_messages.isNotEmpty && _messages.last.isThinking) {
                setState(() => _messages.removeLast());
              }
              if (mounted) {
                showLimitReachedDialog(
                  context,
                  studentId: studentId,
                  planName: decoded['current_plan']?['name'] ?? 'Free',
                  usedToday: decoded['used_today'] ?? 10,
                  dailyLimit: decoded['current_plan']?['daily_limit'] ?? 10,
                );
              }
              break;
            }
          } catch (_) {}
        }

        // Check for error messages
        if (chunk.startsWith('Error:')) {
          if (_messages.isNotEmpty && _messages.last.isThinking) {
            setState(() => _messages.removeLast());
          }
          setState(() {
            _messages.add(AIChatMessage(role: 'assistant', content: chunk));
          });
          assistantReplyForVoice = chunk;
          _scrollToBottom();
          break;
        }

        // Handle normal content streaming
        if (!started) {
          setState(() {
            // Remove thinking indicator if present
            if (_messages.isNotEmpty && _messages.last.isThinking) {
              _messages.removeLast();
            }
            // Add first chunk as new message
            _messages.add(AIChatMessage(role: 'assistant', content: chunk));
            started = true;
            accumulatedContent = chunk;
            assistantReplyForVoice = accumulatedContent;
          });
        } else {
          setState(() {
            // Update the last message with new content
            accumulatedContent += chunk;
            _messages[_messages.length - 1] = AIChatMessage(
              role: 'assistant',
              content: accumulatedContent,
            );
            assistantReplyForVoice = accumulatedContent;
          });
        }
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        // Remove thinking indicator if present
        if (_messages.isNotEmpty && _messages.last.isThinking) {
          setState(() => _messages.removeLast());
        }
        _showError('Connection error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isStreaming = false);
        _refreshSessions();
        _scrollToBottom();

        if (fromVoice) {
          if (assistantReplyForVoice.trim().isNotEmpty &&
              !assistantReplyForVoice.startsWith('Error:')) {
            await _speakText(
              assistantReplyForVoice,
              resumeListeningAfter: true,
            );
          } else {
            await _startListening();
          }
        }
      }
    }
  }

  String _buildBackendMessage(String originalText, {required bool fromVoice}) {
    // Always append French instruction when a French voice is selected,
    // whether the message comes from voice or typed text.
    if (_isFrenchVoice) {
      return '$originalText\n\n[IMPORTANT: You MUST reply fully in French. Réponds entièrement en français.]';
    }
    return originalText;
  }

  void _showVoicePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Voice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (final profile in _voiceProfiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    profile['female'] == true ? Icons.person : Icons.person_outline,
                  ),
                  title: Text(profile['label'] as String),
                  subtitle: Text(profile['ttsLanguage'] as String),
                  trailing: _selectedVoiceId == profile['id']
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _applyVoiceProfile(profile['id'] as String);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final Map<String, dynamic>? theme;
  final List<String>? supportedLanguages;

  CodeBlockBuilder({
    this.theme,
    this.supportedLanguages,
  });

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';
    var code = element.textContent;

    if (element.attributes['class'] != null) {
      String className = element.attributes['class']!;
      const prefix = 'language-';
      if (className.startsWith(prefix)) {
        language = className.substring(prefix.length);
      }
    }

    // Default to 'plaintext' if no language is specified
    if (language.isEmpty) {
      language = 'plaintext';
    }

    // Check if language is supported
    if (supportedLanguages != null && !supportedLanguages!.contains(language)) {
      // Try to find a similar language
      if (language.contains('python')) {
        language = 'python';
      } else if (language.contains('java') && !language.contains('javascript')) {
        language = 'java';
      } else if (language.contains('js') || language.contains('javascript')) {
        language = 'javascript';
      } else if (language.contains('c++') || language.contains('cpp')) {
        language = 'cpp';
      } else if (language.contains('c#') || language.contains('csharp')) {
        language = 'csharp';
      } else if (language.contains('ts') || language.contains('typescript')) {
        language = 'typescript';
      } else if (language.contains('html')) {
        language = 'html';
      } else if (language.contains('css')) {
        language = 'css';
      } else if (language.contains('json')) {
        language = 'json';
      } else if (language.contains('sql')) {
        language = 'sql';
      } else if (language.contains('bash') || language.contains('shell')) {
        language = 'bash';
      } else if (language.contains('md') || language.contains('markdown')) {
        language = 'markdown';
      } else {
        language = 'plaintext';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme?['rootBackground'] ?? Colors.grey[900],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Text(
                    language.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme?['keyword']?.color ?? Colors.blue[300],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      // Copy code to clipboard
                      // You can implement clipboard functionality here
                    },
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              code,
              language: language,
              theme: theme?.cast<String, TextStyle>() ?? githubTheme,
              padding: const EdgeInsets.all(0),
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
