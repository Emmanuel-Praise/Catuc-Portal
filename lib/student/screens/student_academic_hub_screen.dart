import 'package:flutter/material.dart';

import '../models/student_session.dart';
import 'student_results_screen.dart';

class StudentAcademicHubScreen extends StatelessWidget {
  final StudentSession user;

  const StudentAcademicHubScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Academic')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentResultsScreen(user: user),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(child: Icon(Icons.assessment_rounded)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Results',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Select session and semester inside Results to view your grades.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
