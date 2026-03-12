import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../student/models/student_course.dart';
import '../student/services/student_api_service.dart';

class CoursesScreen extends StatefulWidget {
  final UserSession user;

  const CoursesScreen({super.key, required this.user});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  late final Future<List<StudentCourse>> _future;

  @override
  void initState() {
    super.initState();
    _future = const StudentApiService().fetchCourses('${widget.user.userId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: FutureBuilder<List<StudentCourse>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(child: Text('No enrolled courses found.'));
          }

          final grouped = <String, List<StudentCourse>>{};
          for (final c in courses) {
            grouped.putIfAbsent(c.groupKey, () => []).add(c);
          }

          final keys = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              final items = grouped[key]!;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(key, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...items.map(
                        (c) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${c.code} - ${c.name}'),
                          trailing: Text('${c.credits} CU'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
