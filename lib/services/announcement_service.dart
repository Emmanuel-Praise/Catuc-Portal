import '../models/admin_announcement.dart';
import 'api_service.dart';

class _CoreApi extends ApiService {
  const _CoreApi();
}

class AnnouncementService {
  const AnnouncementService();

  Future<List<AdminAnnouncement>> fetchActiveAnnouncements() async {
    try {
      final api = const _CoreApi();
      final response = await api.getWithFallback(
        'admin_announcements.php',
        query: {'action': 'active'},
      );
      final data = api.parseResponse(response);
      final list = data['announcements'] as List? ?? [];
      return list
          .map((e) => AdminAnnouncement.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
