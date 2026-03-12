import '../../services/api_service.dart';
import '../../models/admin_announcement.dart';
import '../models/admin_home_data.dart';

class AdminApiService extends ApiService {
  const AdminApiService();

  Future<AdminHomeData> fetchHome(String adminId) async {
    final data = await getWithCache('admin_home.php', query: {'admin_id': adminId});
    return AdminHomeData.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<void> postAction(String endpoint, Map<String, dynamic> body) async {
    final response = await postWithFallback(endpoint, body: body);
    parseResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchList(String endpoint, [Map<String, String>? query]) async {
    final parsed = await getWithCache(endpoint, query: query);
    final key = endpoint.contains('student') ? 'students' : (endpoint.contains('staff') ? 'staff' : 'courses');
    return List<Map<String, dynamic>>.from(parsed[key] ?? []);
  }

  Future<Map<String, dynamic>> fetchMetadata() async {
    return await getWithCache('ea_metadata.php');
  }

  Future<List<Map<String, dynamic>>> fetchAiKeys() async {
    final parsed = await getWithCache('admin_ai_keys.php', query: {'action': 'fetch_keys'});
    return List<Map<String, dynamic>>.from(parsed['keys'] ?? []);
  }

  Future<void> addAiKey(String aiType, String apiKey, {String? modelKey}) async {
    await postAction('admin_ai_keys.php', {
      'action': 'add_key',
      'ai_type': aiType,
      'api_key': apiKey,
      'model_name': modelKey,
    });
  }

  // ... (keeping other methods and updating them to use base class methods if needed)
  Future<void> deleteAiKey(int keyId) async {
    await postAction('admin_ai_keys.php', {
      'action': 'delete_key',
      'key_id': keyId,
    });
  }

  Future<Map<String, dynamic>> fetchVersionSettings() async {
    return await getWithCache('admin_settings.php', query: {'action': 'fetch_version'});
  }

  Future<void> updateRequiredVersion({
    required int versionCode,
    required String versionName,
    String? downloadUrl,
    bool mandatory = true,
  }) async {
    await postAction('admin_settings.php', {
      'action': 'update_version',
      'version_code': versionCode,
      'version_name': versionName,
      'download_url': downloadUrl,
      'mandatory': mandatory,
    });
  }

  // ── Ban management ──
  Future<Map<String, dynamic>> fetchBans({String filter = 'all'}) async {
    return await getWithCache('admin_bans.php', query: {'filter': filter}, forceRefresh: true);
  }

  Future<void> unbanUser({required int banId, required String adminId}) async {
    await postAction('admin_bans.php', {'action': 'unban', 'ban_id': banId, 'admin_id': adminId});
  }

  Future<void> banUser({required String userId, required String reason, required String adminId}) async {
    await postAction('admin_bans.php', {'action': 'ban', 'user_id': userId, 'reason': reason, 'admin_id': adminId});
  }

  Future<void> respondToAppeal({required int appealId, required String response, String status = 'reviewed'}) async {
    await postAction('admin_bans.php', {'action': 'respond_appeal', 'appeal_id': appealId, 'response': response, 'status': status});
  }

  // ── Announcement management ──
  Future<List<AdminAnnouncement>> fetchAllAnnouncements() async {
    final data = await getWithCache('admin_announcements.php', query: {'action': 'all'}, forceRefresh: true);
    final list = data['announcements'] as List? ?? [];
    return list.map((e) => AdminAnnouncement.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createAnnouncement({
    required String title,
    required String message,
    String imageUrl = '',
    String priority = 'normal',
    String targetRoles = '',
    String expiresAt = '',
  }) async {
    await postAction('admin_announcements.php', {
      'action': 'create',
      'title': title,
      'message': message,
      'image_url': imageUrl,
      'priority': priority,
      'target_roles': targetRoles,
      'expires_at': expiresAt,
    });
  }

  Future<void> updateAnnouncement({
    required int id,
    required String title,
    required String message,
    String imageUrl = '',
    String priority = 'normal',
    String targetRoles = '',
    String expiresAt = '',
  }) async {
    await postAction('admin_announcements.php', {
      'action': 'update',
      'id': id,
      'title': title,
      'message': message,
      'image_url': imageUrl,
      'priority': priority,
      'target_roles': targetRoles,
      'expires_at': expiresAt,
    });
  }

  Future<void> toggleAnnouncement(int id) async {
    await postAction('admin_announcements.php', {'action': 'toggle', 'id': id});
  }

  Future<void> deleteAnnouncement(int id) async {
    await postAction('admin_announcements.php', {'action': 'delete', 'id': id});
  }
}
