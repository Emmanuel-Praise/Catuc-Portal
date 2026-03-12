import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../student/models/student_profile.dart';
import '../student/services/student_api_service.dart';

class ProfileScreen extends StatefulWidget {
  final UserSession user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<StudentProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = const StudentApiService().fetchProfile('${widget.user.userId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<StudentProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('Profile unavailable.'));
          }

          Widget item(String label, String value) {
            return ListTile(
              title: Text(label),
              subtitle: Text(value.isEmpty ? '-' : value),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    CircleAvatar(
                      radius: 34,
                      child: Text(profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'S'),
                    ),
                    const SizedBox(height: 10),
                    Text(profile.fullName, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(profile.email),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    item('Student Number', profile.studentNumber),
                    item('Program', profile.program),
                    item('Department', profile.department),
                    item('Faculty', profile.faculty),
                    item('Current Year', profile.level),
                    item('Gender', profile.gender),
                    item('Phone', profile.phone),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
