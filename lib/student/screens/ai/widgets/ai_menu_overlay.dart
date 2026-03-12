import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:catuc_portal/theme/app_colors.dart';

class AiMenuOverlay extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Function(String action) onActionSelected;

  const AiMenuOverlay({
    super.key,
    required this.userData,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: (isDark ? Colors.black : Colors.white).withOpacity(0.4),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.menu_book_rounded,
                    title: 'Catu AI Study Suite',
                    subtitle: 'Summarize, Explain, Quiz & Ask',
                    color: Colors.blueAccent,
                    onTap: () => onActionSelected('read'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.school_rounded,
                    title: 'Learn',
                    subtitle: 'Get explanations on any topic',
                    color: Colors.greenAccent,
                    onTap: () => onActionSelected('learn'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.code_rounded,
                    title: 'Code',
                    subtitle: 'Debug or generate programming code',
                    color: Colors.orangeAccent,
                    onTap: () => onActionSelected('code'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.psychology_rounded,
                    title: 'Brainstorm',
                    subtitle: 'Idea generation and project planning',
                    color: Colors.purpleAccent,
                    onTap: () => onActionSelected('brainstorm'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.mic_rounded,
                    title: 'Voice Assistant',
                    subtitle: 'Talk with AI using your voice',
                    color: Colors.tealAccent,
                    onTap: () => onActionSelected('voice'),
                  ),
                  const SizedBox(height: 40),
                  FloatingActionButton(
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                    child: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurface : Colors.white).withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
