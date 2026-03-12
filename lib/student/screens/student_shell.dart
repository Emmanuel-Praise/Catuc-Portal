import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../models/student_session.dart';
import 'student_home_screen.dart';
import 'student_courses_screen.dart';
import 'student_profile_screen.dart';
import '../../onboarding/user_guide_overlay.dart';

class StudentShell extends StatefulWidget {
  final StudentSession user;

  const StudentShell({super.key, required this.user});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      StudentHomeScreen(user: widget.user),
      StudentCoursesScreen(user: widget.user),
      StudentProfileScreen(user: widget.user),
    ];

    return UserGuideOverlay(
      userRole: 'student',
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
              selectedItemColor: AppColors.blue,
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
