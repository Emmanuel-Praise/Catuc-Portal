import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'widgets/ai_chat_widget.dart';
import 'package:catuc_portal/shared/models/ai_user.dart';
import 'package:catuc_portal/theme/app_colors.dart';

class CodeAssistantScreen extends StatefulWidget {
  final AiUser user;
  final Map<String, dynamic>? dashboardData;

  const CodeAssistantScreen({super.key, required this.user, this.dashboardData});

  @override
  State<CodeAssistantScreen> createState() => _CodeAssistantScreenState();
}

class _CodeAssistantScreenState extends State<CodeAssistantScreen> {
  String _selectedTheme = 'github';
  final List<String> _themes = ['github', 'vs2015', 'atom-one-dark'];
  final List<String> _supportedLanguages = [
    'dart', 'python', 'javascript', 'java', 'cpp', 'c', 'csharp', 
    'php', 'ruby', 'go', 'rust', 'swift', 'kotlin', 'typescript',
    'html', 'css', 'json', 'xml', 'sql', 'bash', 'markdown'
  ];

  Map<String, dynamic> _getThemeData() {
    switch (_selectedTheme) {
      case 'vs2015':
        return vs2015Theme;
      case 'atom-one-dark':
        return atomOneDarkTheme;
      default:
        return githubTheme;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Code Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette),
            onSelected: (theme) {
              setState(() {
                _selectedTheme = theme;
              });
            },
            itemBuilder: (context) => _themes.map((theme) {
              return PopupMenuItem<String>(
                value: theme,
                child: Row(
                  children: [
                    Icon(
                      theme == _selectedTheme ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(theme.toUpperCase()),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Language support info
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.code, color: AppColors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Syntax Highlighting Enabled',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Supports ${_supportedLanguages.length}+ languages including: ${_supportedLanguages.take(8).join(', ')}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _supportedLanguages.take(12).map((lang) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lang,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Enhanced AI Chat Widget
          Expanded(
            child: EnhancedCodeChatWidget(
              user: widget.user,
              aiType: 'code',
              title: 'Code Assistant',
              hintText: 'Ask for code, debugging help, or explanations...',
              themeData: _getThemeData(),
              supportedLanguages: _supportedLanguages,
            ),
          ),
        ],
      ),
    );
  }
}

class EnhancedCodeChatWidget extends StatefulWidget {
  final AiUser user;
  final String aiType;
  final String title;
  final String hintText;
  final Map<String, dynamic> themeData;
  final List<String> supportedLanguages;

  const EnhancedCodeChatWidget({
    super.key,
    required this.user,
    required this.aiType,
    required this.title,
    required this.hintText,
    required this.themeData,
    required this.supportedLanguages,
  });

  @override
  State<EnhancedCodeChatWidget> createState() => _EnhancedCodeChatWidgetState();
}

class _EnhancedCodeChatWidgetState extends State<EnhancedCodeChatWidget> {
  @override
  Widget build(BuildContext context) {
    return AIChatWidget(
      user: widget.user,
      aiType: widget.aiType,
      title: widget.title,
      hintText: widget.hintText,
      codeHighlightTheme: widget.themeData,
      supportedLanguages: widget.supportedLanguages,
    );
  }
}
