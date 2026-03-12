import 'package:flutter/material.dart';

import '../../theme/theme_service.dart';
import '../models/teacher_session.dart';
import 'teacher_courses_screen.dart';
import 'teacher_home_screen.dart';
import 'teacher_profile_screen.dart';
import '../../onboarding/user_guide_overlay.dart';

class TeacherShell extends StatefulWidget {
  final TeacherSession user;

  const TeacherShell({super.key, required this.user});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;
    final pages = [
      TeacherHomeScreen(user: widget.user),
      TeacherCoursesScreen(user: widget.user),
      TeacherProfileScreen(user: widget.user),
    ];

    return UserGuideOverlay(
      userRole: 'teacher',
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: IndexedStack(
          index: _index,
          children: [
            GuideTarget(name: 'dashboard', child: pages[0]),
            GuideTarget(name: 'courses', child: pages[1]),
            GuideTarget(name: 'profile', child: pages[2]),
          ],
        ),
        bottomNavigationBar: GuideTarget(
          name: 'navigation',
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withAlpha(20), // 0.08 opacity
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (value) => setState(() => _index = value),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: primaryColor,
              unselectedItemColor: Theme.of(context).textTheme.bodySmall?.color,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(
                  icon: GuideTarget(
                    name: 'tab_home',
                    child: const Icon(Icons.home_outlined),
                  ),
                  activeIcon: GuideTarget(
                    name: 'tab_home',
                    child: const Icon(Icons.home_rounded),
                  ),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: GuideTarget(
                    name: 'tab_courses',
                    child: const Icon(Icons.menu_book_outlined),
                  ),
                  activeIcon: GuideTarget(
                    name: 'tab_courses',
                    child: const Icon(Icons.menu_book_rounded),
                  ),
                  label: 'Courses',
                ),
                BottomNavigationBarItem(
                  icon: GuideTarget(
                    name: 'tab_profile',
                    child: const Icon(Icons.person_outline_rounded),
                  ),
                  activeIcon: GuideTarget(
                    name: 'tab_profile',
                    child: const Icon(Icons.person_rounded),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
