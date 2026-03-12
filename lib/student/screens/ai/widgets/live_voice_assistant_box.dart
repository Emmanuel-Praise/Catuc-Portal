import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:catuc_portal/shared/models/ai_user.dart';
import 'package:catuc_portal/student/services/student_api_service.dart';
import 'package:catuc_portal/student/screens/ai/widgets/limit_reached_dialog.dart';
import 'package:catuc_portal/theme/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

/// Premium voice assistant bottom-sheet widget.
///
/// Uses native [speech_to_text] for listening and [flutter_tts] for speaking.
/// Works on both mobile (Android/iOS) and web (Chrome/Edge).
/// AI responses come from the backend via [StudentApiService].
class LiveVoiceAssistantBox extends StatefulWidget {
  final AiUser user;
  final VoidCallback onClose;

  const LiveVoiceAssistantBox({
    super.key,
    required this.user,
    required this.onClose,
  });

  @override
  State<LiveVoiceAssistantBox> createState() => _LiveVoiceAssistantBoxState();
}

class _LiveVoiceAssistantBoxState extends State<LiveVoiceAssistantBox>
    with TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final StudentApiService _apiService = const StudentApiService();

  // ── State ───────────────────────────────────────────────────────────────
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _hasGreeted = false;
  String _recognizedText = '';
  String _selectedLanguage = 'en-US';
  List<stt.LocaleName> _locales = const [];

  // Conversation entries: {role: 'user'|'ai', text: String}
  final List<Map<String, String>> _conversation = [];

  // ── Animations ──────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _thinkCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  // ── Voice profiles ──────────────────────────────────────────────────────
  static const _voices = [
    _VoiceProfile('Emma', 'English Female', 'en-US', 1.0, 0.65, gender: 'female'),
    _VoiceProfile('Marie', 'Français Femme', 'fr-FR', 1.0, 0.63, gender: 'female'),
    _VoiceProfile('Alex', 'English Male', 'en-US', 0.85, 0.62, gender: 'male'),
    _VoiceProfile('Pierre', 'Français Homme', 'fr-FR', 0.82, 0.60, gender: 'male'),
  ];
  _VoiceProfile _currentVoice = _voices.first; // Always start with Emma (Female)

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _thinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _initialize();
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> _initialize() async {
    // Ensure TTS is configured (and voice selection applied) before greeting.
    await _initTts();
    await _initSpeech();
  }

  Future<void> _initSpeech() async {
    // On web, speech_to_text uses the Web Speech API (works in Chrome/Edge).
    // We skip permission_handler on web since it's not supported there — the
    // browser itself prompts for microphone access.
    if (!kIsWeb) {
      // Mobile: request microphone permission via permission_handler
      try {
        final dynamic permissionHandler = await _requestMicrophonePermission();
        if (permissionHandler == false) {
          // Permission was denied
          if (mounted) {
            setState(() => _conversation.add({
                  'role': 'ai',
                  'text': 'Microphone permission is required for voice input. Please enable it in your device settings.',
                }));
          }
          return;
        }
      } catch (e) {
        // permission_handler might fail on some platforms; proceed anyway
        debugPrint('Permission check failed: $e');
      }
    }

    _speechAvailable = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) {
        debugPrint('Speech error: ${error.errorMsg}');
        if (mounted) {
          setState(() {
            _isListening = false;
            _conversation.add({
              'role': 'ai',
              'text': kIsWeb
                  ? 'Microphone/Speech error: ${error.errorMsg}. Make sure you allowed microphone access.'
                  : 'Voice input error: ${error.errorMsg}. Please check microphone permission and try again.',
            });
          });
        }
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      },
    );

    if (!_speechAvailable && mounted) {
      setState(() => _conversation.add({
            'role': 'ai',
            'text': kIsWeb
                ? 'Speech recognition requires Chrome or Edge browser with microphone access. Please allow microphone when prompted.'
                : 'Speech recognition is not available. Please check microphone permissions in Settings.',
          }));
      return;
    }

    try {
      _locales = await _speech.locales();
    } catch (_) {
      _locales = const [];
    }

    if (mounted && _speechAvailable && !_hasGreeted) {
      _playGreeting();
    }
  }

  /// Request microphone permission on mobile platforms.
  /// Returns true if granted, false if denied.
  Future<bool> _requestMicrophonePermission() async {
    if (kIsWeb) return true; // Browser handles mic permission itself
    try {
      final status = await Permission.microphone.request();
      if (status.isPermanentlyDenied && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Microphone Permission'),
            content: const Text(
              'Microphone access is permanently denied. Please enable it in Settings to use the Voice Assistant.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return status.isGranted;
    } catch (_) {
      return true; // If permission check fails, try anyway
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Some platforms may not support this; continue.
    }

    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
      _waveCtrl.repeat(reverse: true);
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      _waveCtrl.stop();
      _waveCtrl.reset();
    });
    _tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _conversation.add({
            'role': 'ai',
            'text': 'Text-to-speech is not available on this device. Please enable/ install a TTS engine in Settings.',
          });
        });
      }
      _waveCtrl.stop();
      _waveCtrl.reset();
    });

    await _applyVoiceProfile(_currentVoice);
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _waveCtrl.stop();
        _waveCtrl.reset();
      }
    });
  }

  Future<void> _setTtsLanguageBestEffort(String lang) async {
    final candidates = <String>[
      lang,
      lang.replaceAll('-', '_'),
      lang.split(RegExp('[-_]')).first,
    ].where((v) => v.trim().isNotEmpty).toSet().toList();

    for (final cand in candidates) {
      try {
        await _tts.setLanguage(cand);
        return;
      } catch (_) {
        // Try next
      }
    }
  }

  Future<void> _applyVoiceProfile(_VoiceProfile profile) async {
    try {
      await _setTtsLanguageBestEffort(profile.lang);
      await _tts.setPitch(profile.pitch);
      await _tts.setSpeechRate(profile.rate);
      await _tts.setVolume(1.0);
    } catch (_) {
      // Ignore: some engines/platforms may throw for unsupported locales/values.
    }

    if (!kIsWeb) {
      // Best-effort voice selection by locale + gender (Android/iOS).
      // Without this, many devices default to a male voice even when "female" is selected.
      try {
        final engineVoices = await _tts.getVoices;
        if (engineVoices is List) {
          final desiredLocale = profile.lang.replaceAll('_', '-').toLowerCase();
          final desiredLang = desiredLocale.split('-').first;
          final wantsFemale = profile.gender.toLowerCase() == 'female';

          Map<dynamic, dynamic>? best;
          int bestScore = -1;

          for (final v in engineVoices) {
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
            await _tts.setVoice({
              'name': best['name'].toString(),
              'locale': best['locale'].toString(),
            });
          }
        }
      } catch (_) {
        // Ignored: not all platforms support getVoices/setVoice
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      if (mounted && _isListening) {
        setState(() => _isListening = false);
        _pulseCtrl.stop();
        _pulseCtrl.reset();
        if (_recognizedText.trim().isNotEmpty) {
          _processUserInput(_recognizedText.trim());
        }
      }
    }
  }

  // ── Greeting ────────────────────────────────────────────────────────────
  void _playGreeting() {
    _hasGreeted = true;
    final name = widget.user.firstName.trim().isEmpty
        ? 'there'
        : widget.user.firstName.trim();
    final isFr = _currentVoice.lang.startsWith('fr');
    final greeting = isFr
        ? 'Bonjour $name! Je suis Catu AI, votre assistant vocal. Comment puis-je vous aider?'
        : 'Hi $name! I\'m Catu AI, your voice assistant. How can I help you today?';
    setState(() {
      _conversation.add({'role': 'ai', 'text': greeting});
    });
    _speak(greeting);
    _scrollToBottom();
  }

  // ── Listening ───────────────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      _waveCtrl.stop();
      _waveCtrl.reset();
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      return;
    }

    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    _pulseCtrl.repeat(reverse: true);

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _recognizedText = result.recognizedWords;
            });
          }
        },
        localeId: _resolveLocaleId(_selectedLanguage),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _conversation.add({
            'role': 'ai',
            'text': kIsWeb
                ? 'Could not start listening. Make sure you\'re using Chrome or Edge, and allow microphone access when prompted.'
                : 'Could not start listening. Please check microphone permissions and try again.',
          });
        });
      }
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  String? _resolveLocaleId(String preferred) {
    if (_locales.isEmpty) return null;
    final normalized = preferred.replaceAll('_', '-').toLowerCase();

    for (final loc in _locales) {
      if (loc.localeId.replaceAll('_', '-').toLowerCase() == normalized) {
        return loc.localeId;
      }
    }

    final lang = normalized.split('-').first;
    for (final loc in _locales) {
      final cand = loc.localeId.replaceAll('_', '-').toLowerCase();
      if (cand.startsWith(lang)) return loc.localeId;
    }

    return null;
  }

  // ── Process user input ──────────────────────────────────────────────────
  Future<void> _processUserInput(String text) async {
    setState(() {
      _conversation.add({'role': 'user', 'text': text});
      _recognizedText = '';
      _isThinking = true;
    });
    _thinkCtrl.repeat();
    _scrollToBottom();

    try {
      final isFr = _currentVoice.lang.startsWith('fr');
      // If French voice is selected, instruct AI to respond in French
      final enhancedMessage = isFr
          ? '$text\n\n[IMPORTANT: Réponds entièrement en français.]'
          : text;

      final response = await _apiService.generateVoiceResponseFlexible(
        studentId: widget.user.userId,
        message: enhancedMessage,
        voiceName: _currentVoice.name,
        language: _currentVoice.lang,
        pitch: _currentVoice.pitch,
        rate: _currentVoice.rate,
      );
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _conversation.add({'role': 'ai', 'text': response});
      });
      _thinkCtrl.stop();
      _thinkCtrl.reset();
      _speak(response);
    } on AiLimitReachedException catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _conversation.add({'role': 'ai', 'text': e.message});
      });
      _thinkCtrl.stop();
      _thinkCtrl.reset();
      await showLimitReachedDialog(
        context,
        studentId: widget.user.userId,
        planName: e.planName,
        usedToday: e.usedToday,
        dailyLimit: e.dailyLimit,
      );
    } catch (_) {
      final isFr = _currentVoice.lang.startsWith('fr');
      final fallback = isFr
          ? 'Désolé, je ne peux pas répondre maintenant. Veuillez réessayer.'
          : 'Sorry, I couldn\'t process that right now. Please try again.';
      if (mounted) {
        setState(() {
          _isThinking = false;
          _conversation.add({'role': 'ai', 'text': fallback});
        });
        _thinkCtrl.stop();
        _thinkCtrl.reset();
        _speak(fallback);
      }
    }
    _scrollToBottom();
  }

  // ── TTS ─────────────────────────────────────────────────────────────────
  Future<void> _speak(String text) async {
    try {
      await _applyVoiceProfile(_currentVoice);
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _conversation.add({
          'role': 'ai',
          'text': 'I can respond, but speaking is not available on this device right now.',
        });
      }
      _waveCtrl.stop();
      _waveCtrl.reset();
    }
  }

  // ── Voice change ────────────────────────────────────────────────────────
  void _changeVoice(_VoiceProfile voice) {
    setState(() {
      _currentVoice = voice;
      _selectedLanguage = voice.lang;
    });
    final isFr = voice.lang.startsWith('fr');
    final msg = isFr ? 'Voix changée à ${voice.label}.' : 'Voice changed to ${voice.label}.';
    _speak(msg);
  }

  // ── Scroll ──────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _thinkCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.85, minHeight: 400),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1219) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          _buildHeader(isDark),
          _buildVoiceSelector(isDark),
          const SizedBox(height: 6),
          Expanded(child: _buildConversationArea(isDark)),

          if (_isListening && _recognizedText.isNotEmpty)
            _buildLiveTranscript(isDark),
          if (_isThinking) _buildThinkingIndicator(isDark),
          if (_isSpeaking) _buildSpeakingIndicator(isDark),

          _buildMicButton(isDark),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.blue, AppColors.blue.withOpacity(0.65)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catu AI Voice',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _speech.stop();
              _tts.stop();
              widget.onClose();
            },
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  String get _statusLabel {
    if (_isListening) return 'Listening...';
    if (_isThinking) return 'Thinking...';
    if (_isSpeaking) return 'Speaking...';
    if (!_speechAvailable) return 'Initializing...';
    return 'Ready';
  }

  Color get _statusColor {
    if (_isListening) return AppColors.blue;
    if (_isThinking) return Colors.orange;
    if (_isSpeaking) return Colors.green;
    if (!_speechAvailable) return Colors.orange;
    return Colors.green;
  }

  // ── Voice selector ──────────────────────────────────────────────────────
  Widget _buildVoiceSelector(bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _voices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final v = _voices[i];
          final selected = v.name == _currentVoice.name;
          return GestureDetector(
            onTap: () => _changeVoice(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.blue
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.blue : Colors.transparent,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                v.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Conversation area ───────────────────────────────────────────────────
  Widget _buildConversationArea(bool isDark) {
    if (_conversation.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none_rounded,
                size: 48,
                color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 12),
            Text(
              kIsWeb
                  ? 'Tap the microphone to start talking\n(Works best in Chrome or Edge)'
                  : 'Tap the microphone to start talking',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _conversation.length,
      itemBuilder: (context, i) {
        final msg = _conversation[i];
        final isUser = msg['role'] == 'user';
        return _buildMessageBubble(msg['text'] ?? '', isUser, isDark);
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, bool isDark) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.blue
              : (isDark ? const Color(0xFF1A1F2E) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? AppColors.blue : Colors.black)
                  .withOpacity(isUser ? 0.18 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Icon(
                Icons.smart_toy_rounded,
                size: 16,
                color: isDark ? AppColors.blue : AppColors.blue.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isUser
                      ? Colors.white
                      : (isDark ? Colors.white.withOpacity(0.85) : Colors.black87),
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              Icon(Icons.person_rounded,
                  size: 16, color: Colors.white.withOpacity(0.7)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Live transcript ─────────────────────────────────────────────────────
  Widget _buildLiveTranscript(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.blue.withOpacity(0.12)
            : AppColors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          _AnimatedDots(color: AppColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _recognizedText,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Thinking indicator ──────────────────────────────────────────────────
  Widget _buildThinkingIndicator(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.withOpacity(0.1)
            : Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.orange.shade400,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _currentVoice.lang.startsWith('fr')
                ? 'Je réfléchis...'
                : 'Thinking...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Speaking indicator ──────────────────────────────────────────────────
  Widget _buildSpeakingIndicator(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.green.withOpacity(0.1)
            : Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final h = 6.0 + 10 * sin((_waveCtrl.value * 2 * pi) + i * 0.8);
                  return Container(
                    width: 3,
                    height: h.abs().clamp(4.0, 16.0),
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade500,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            _currentVoice.lang.startsWith('fr') ? 'Parle...' : 'Speaking...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Mic button ──────────────────────────────────────────────────────────
  Widget _buildMicButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: _toggleListening,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, _) {
            final scale = _isListening ? 1.0 + (_pulseCtrl.value * 0.15) : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isListening
                        ? [Colors.red.shade400, Colors.red.shade700]
                        : [AppColors.blue, AppColors.blue.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : AppColors.blue)
                          .withOpacity(0.35),
                      blurRadius: _isListening ? 24 : 16,
                      spreadRadius: _isListening ? 6 : 3,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Animated dots widget ──────────────────────────────────────────────────
class _AnimatedDots extends StatefulWidget {
  final Color color;
  const _AnimatedDots({required this.color});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
            final opacity = sin(offset * pi).clamp(0.3, 1.0);
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Voice profile model ───────────────────────────────────────────────────
class _VoiceProfile {
  final String name;
  final String label;
  final String lang;
  final double pitch;
  final double rate;
  final String gender;

  const _VoiceProfile(
    this.name,
    this.label,
    this.lang,
    this.pitch,
    this.rate, {
    this.gender = 'female',
  });
}
