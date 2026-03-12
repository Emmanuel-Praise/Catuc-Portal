import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../student/models/student_home_data.dart';
import '../student/services/student_api_service.dart';

class HomeScreen extends StatefulWidget {
  final UserSession user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<StudentHomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchHome();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetchHome();
    });
    await _future;
  }

  Future<StudentHomeData> _fetchHome() async {
    return const StudentApiService().fetchHome('${widget.user.userId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: FutureBuilder<StudentHomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No data found'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Academics', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Welcome: ${data.firstName}'),
                        Text('Courses: ${data.stats.courses}'),
                        Text('Assignments: ${data.stats.assignments}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Today\'s Courses', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...data.todayCourses.map(
                  (row) => Card(
                    child: ListTile(
                      title: Text('${row.code} - ${row.name}'),
                      subtitle: Text(row.schedule.isEmpty ? 'Schedule not set' : row.schedule),
                      trailing: Text(row.room.isEmpty ? '-' : row.room),
                    ),
                  ),
                ),
                if (data.todayCourses.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('No classes for today'),
                      subtitle: Text('Your timetable will appear here.'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
