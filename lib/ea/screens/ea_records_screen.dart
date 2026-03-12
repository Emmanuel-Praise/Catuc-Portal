import 'package:flutter/material.dart';

import '../models/ea_session.dart';
import 'ea_courses_screen.dart';
import 'ea_enrollments_screen.dart';
import 'ea_results_screen.dart';

class EaRecordsScreen extends StatefulWidget {
  final EaSession user;

  const EaRecordsScreen({super.key, required this.user});

  @override
  State<EaRecordsScreen> createState() => _EaRecordsScreenState();
}

class _EaRecordsScreenState extends State<EaRecordsScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      EaCoursesScreen(user: widget.user),
      EaEnrollmentsScreen(user: widget.user),
      EaResultsScreen(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: 'Courses',
                      isSelected: _tabIndex == 0,
                      onTap: () => setState(() => _tabIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SegmentButton(
                      label: 'Enrollments',
                      isSelected: _tabIndex == 1,
                      onTap: () => setState(() => _tabIndex = 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SegmentButton(
                      label: 'Results',
                      isSelected: _tabIndex == 2,
                      onTap: () => setState(() => _tabIndex = 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(index: _tabIndex, children: pages),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
