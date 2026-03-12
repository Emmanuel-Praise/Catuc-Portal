import 'package:flutter/material.dart';
import '../models/dean_session.dart';
import '../services/dean_api_service.dart';
import '../../theme/theme_service.dart';
import '../../shared/widgets/app_error_widget.dart';

class DeanStaffScreen extends StatefulWidget {
  final DeanSession user;

  const DeanStaffScreen({super.key, required this.user});

  @override
  State<DeanStaffScreen> createState() => _DeanStaffScreenState();
}

class _DeanStaffScreenState extends State<DeanStaffScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>> _allStaff = [];
  List<Map<String, dynamic>> _filteredStaff = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaff();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadStaff() {
    setState(() {
      _future = const DeanApiService().fetchLecturers(widget.user.facultyId ?? '');
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredStaff = List.from(_allStaff);
      } else {
        _filteredStaff = _allStaff.where((staff) {
          final name = "${staff['first_name']} ${staff['last_name']}".toLowerCase();
          final email = (staff['email'] ?? '').toString().toLowerCase();
          final dept = (staff['department_name'] ?? '').toString().toLowerCase();
          final pos = (staff['position'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query) || dept.contains(query) || pos.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService().primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Staff List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaff,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(primaryColor),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AppErrorWidget(error: snapshot.error, onRetry: _loadStaff);
                }
                
                _allStaff = snapshot.data ?? [];
                if (_filteredStaff.isEmpty && _searchController.text.isEmpty) {
                   _filteredStaff = List.from(_allStaff);
                }

                if (_allStaff.isEmpty) {
                  return const Center(child: Text('No staff members found in this faculty.'));
                }
                if (_filteredStaff.isEmpty) {
                  return const Center(child: Text('No staff match your search.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredStaff.length,
                  itemBuilder: (context, index) {
                    final staff = _filteredStaff[index];
                    return _buildStaffCard(staff, primaryColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, department, or position...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff, Color primaryColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              child: Text(
                staff['first_name'] != null ? staff['first_name'][0].toUpperCase() : '?',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${staff['first_name']} ${staff['last_name']}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business_rounded, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        staff['department_name'] ?? 'N/A',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.work_outline_rounded, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        staff['position'] ?? 'Lecturer',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.email_outlined, color: primaryColor, size: 20),
              onPressed: () {
                // Email action
              },
            ),
          ],
        ),
      ),
    );
  }
}
