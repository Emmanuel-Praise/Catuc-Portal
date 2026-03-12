import 'package:flutter/material.dart';

import '../models/admin_session.dart';
import 'admin_academics_screen.dart';
import 'admin_ai_keys_screen.dart';
import 'admin_home_screen.dart';
import 'admin_people_screen.dart';
import 'admin_settings_screen.dart';
import '../../onboarding/user_guide_overlay.dart';

class AdminShell extends StatefulWidget {
  final AdminSession user;

  const AdminShell({super.key, required this.user});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminHomeScreen(user: widget.user),
      AdminAcademicsScreen(user: widget.user),
      AdminPeopleScreen(user: widget.user),
      AdminAiKeysScreen(user: widget.user),
      AdminSettingsScreen(user: widget.user),
    ];

    return UserGuideOverlay(
      userRole: 'admin',
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: IndexedStack(
          index: _index,
          children: [
            GuideTarget(name: 'dashboard', child: pages[0]),
            GuideTarget(name: 'academics', child: pages[1]),
            GuideTarget(name: 'people', child: pages[2]),
            GuideTarget(name: 'ai', child: pages[3]),
            GuideTarget(name: 'settings', child: pages[4]),
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
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(context).textTheme.bodySmall?.color,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(
                  icon: GuideTarget(
                    name: 'tab_home',
                    child: const Icon(Icons.dashboard_outlined),
                  ),
                  activeIcon: GuideTarget(
                    name: 'tab_home',
                    child: const Icon(Icons.dashboard_rounded),
                  ),
                  label: 'Overview',
                ),
                BottomNavigationBarItem(
                  icon: GuideTarget(
                    name: 'tab_academics',
                    child: const Icon(Icons.school_outlined),
                  ),
                  activeIcon: GuideTarget(
                    name: 'tab_academics',
                    child: const Icon(Icons.school_rounded),
                  ),
                  label: 'Academics',
                ),
                BottomNavigationBarItem(
                  icon: GuideTarget(
                    name: 'tab_people',
                    child: const Icon(Icons.groups_outlined),
                  ),
                  activeIcon: GuideTarget(
                    name: 'tab_people',
                    child: const Icon(Icons.groups_rounded),
                  ),
                  label: 'People',
                ),
                BottomNavigationBarItem(
                  icon: GuideTarget(
                    name: 'tab_ai',
                    child: const Icon(Icons.auto_awesome_outlined),
                  ),
                  activeIcon: GuideTarget(
                    name: 'tab_ai',
                    child: const Icon(Icons.auto_awesome_rounded),
                  ),
                  label: 'AI',
                ),
                BottomNavigationBarItem(
                  icon: GuideTarget(
                    name: 'tab_settings',
                    child: const Icon(Icons.settings_outlined),
                  ),
                  activeIcon: GuideTarget(
                    name: 'tab_settings',
                    child: const Icon(Icons.settings_rounded),
                  ),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
