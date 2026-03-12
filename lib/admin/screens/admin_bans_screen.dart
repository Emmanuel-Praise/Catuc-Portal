import 'package:flutter/material.dart';
import '../models/admin_session.dart';
import '../services/admin_api_service.dart';
import 'widgets/admin_ui.dart';

class AdminBansScreen extends StatefulWidget {
  final AdminSession user;
  const AdminBansScreen({super.key, required this.user});
  @override
  State<AdminBansScreen> createState() => _AdminBansScreenState();
}

class _AdminBansScreenState extends State<AdminBansScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _api = const AdminApiService();
  List<Map<String, dynamic>> _bans = [];
  List<Map<String, dynamic>> _appeals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.fetchBans();
      setState(() {
        _bans = List<Map<String, dynamic>>.from(data['bans'] ?? []);
        _appeals = List<Map<String, dynamic>>.from(data['appeals'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _unban(int banId) async {
    try {
      await _api.unbanUser(banId: banId, adminId: widget.user.userId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unbanned.')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _manualBan() async {
    final idCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ban a User'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'User ID (e.g. FE/23/48329058)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: reasonCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ban')),
        ],
      ),
    );
    if (result == true && idCtrl.text.trim().isNotEmpty) {
      try {
        await _api.banUser(userId: idCtrl.text.trim(), reason: reasonCtrl.text.trim().isEmpty ? 'Manually banned by admin' : reasonCtrl.text.trim(), adminId: widget.user.userId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User banned.')));
        _load();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _respondAppeal(Map<String, dynamic> appeal) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Appeal from ${appeal['full_name']?.toString().isNotEmpty == true ? appeal['full_name'] : appeal['user_id']}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Message:', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text(appeal['message']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Your response', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          OutlinedButton(onPressed: () => Navigator.pop(ctx, 'reviewed'), child: const Text('Mark Reviewed')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'resolved'), child: const Text('Resolve & Unban')),
        ],
      ),
    );
    if (result != null) {
      try {
        await _api.respondToAppeal(appealId: appeal['id'] as int, response: ctrl.text.trim(), status: result);
        if (result == 'resolved') {
          // Also unban the user - find active ban
          final activeBan = _bans.where((b) => b['user_id'] == appeal['user_id'] && b['is_active'] == true).toList();
          for (final b in activeBan) {
            await _api.unbanUser(banId: b['id'] as int, adminId: widget.user.userId);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appeal updated.')));
        _load();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Ban Management',
      subtitle: 'View banned accounts, appeals, and manage bans.',
      icon: Icons.gpp_bad_rounded,
      onRefresh: _load,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _manualBan,
            icon: const Icon(Icons.person_add_disabled_rounded, size: 18),
            label: const Text('Ban a User'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_error != null) Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('Error: $_error')))
        else ...[
          // Stats row
          Row(children: [
            Expanded(child: _StatChip(label: 'Active Bans', value: '${_bans.where((b) => b['is_active'] == true).length}', color: Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _StatChip(label: 'Pending Appeals', value: '${_appeals.where((a) => a['status'] == 'pending').length}', color: Colors.orange)),
          ]),
          const SizedBox(height: 16),
          // Tabs
          Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14)),
            child: TabBar(controller: _tab, labelColor: Theme.of(context).colorScheme.primary, unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color, indicatorSize: TabBarIndicatorSize.tab, tabs: [
              Tab(text: 'Banned Users (${_bans.length})'),
              Tab(text: 'Appeals (${_appeals.length})'),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 500,
            child: TabBarView(controller: _tab, children: [
              _buildBansList(),
              _buildAppealsList(),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildBansList() {
    if (_bans.isEmpty) return const AdminEmptyCard(title: 'No bans', subtitle: 'No users have been banned yet.', icon: Icons.check_circle_rounded);
    return ListView.builder(
      itemCount: _bans.length,
      itemBuilder: (ctx, i) {
        final b = _bans[i];
        final active = b['is_active'] == true;
        final name = (b['full_name']?.toString().isNotEmpty == true) ? b['full_name'] : b['user_id'];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: active ? Colors.red.shade100 : Colors.green.shade100, child: Icon(active ? Icons.block_rounded : Icons.check_rounded, color: active ? Colors.red : Colors.green)),
            title: Text('$name', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${b['reason']?.toString().substring(0, (b['reason']?.toString().length ?? 0) > 80 ? 80 : (b['reason']?.toString().length ?? 0)) ?? 'N/A'}...\nBanned: ${b['banned_at']} by ${b['banned_by']}', style: const TextStyle(fontSize: 12)),
            isThreeLine: true,
            trailing: active ? IconButton(icon: const Icon(Icons.lock_open_rounded, color: Colors.green), tooltip: 'Unban', onPressed: () => _unban(b['id'] as int)) : const Chip(label: Text('Unbanned', style: TextStyle(fontSize: 10)), backgroundColor: Colors.transparent),
          ),
        );
      },
    );
  }

  Widget _buildAppealsList() {
    if (_appeals.isEmpty) return const AdminEmptyCard(title: 'No appeals', subtitle: 'No ban appeals have been submitted.', icon: Icons.mail_outline_rounded);
    return ListView.builder(
      itemCount: _appeals.length,
      itemBuilder: (ctx, i) {
        final a = _appeals[i];
        final pending = a['status'] == 'pending';
        final name = (a['full_name']?.toString().isNotEmpty == true) ? a['full_name'] : a['user_id'];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: pending ? Colors.orange.shade100 : Colors.grey.shade200, child: Icon(pending ? Icons.mail_rounded : Icons.done_all_rounded, color: pending ? Colors.orange : Colors.grey)),
            title: Text('$name', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${a['message']?.toString().substring(0, (a['message']?.toString().length ?? 0) > 100 ? 100 : (a['message']?.toString().length ?? 0)) ?? ''}\nStatus: ${a['status']} • ${a['created_at']}', style: const TextStyle(fontSize: 12)),
            isThreeLine: true,
            trailing: pending ? IconButton(icon: Icon(Icons.reply_rounded, color: Theme.of(context).colorScheme.primary), tooltip: 'Respond', onPressed: () => _respondAppeal(a)) : null,
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final MaterialColor color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color.shade700)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.shade600)),
      ]),
    );
  }
}
