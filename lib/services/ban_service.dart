import '../services/api_service.dart';

class BanService extends ApiService {
  const BanService();

  /// Check if user is banned. Returns null if not banned, or a map with reason/banned_at.
  Future<Map<String, dynamic>?> checkBan(String userId) async {
    try {
      final data = await getWithCache(
        'ban_check.php',
        query: {'user_id': userId},
        forceRefresh: true,
      );
      if (data['banned'] == true) {
        return {
          'reason': (data['reason'] ?? '').toString(),
          'banned_at': (data['banned_at'] ?? '').toString(),
        };
      }
      return null;
    } catch (_) {
      return null; // If check fails, don't block the user
    }
  }

  /// Submit a ban appeal message
  Future<String> submitAppeal({
    required String userId,
    required String message,
  }) async {
    final response = await postWithFallback(
      'ban_appeal.php',
      body: {'user_id': userId, 'message': message},
    );
    final parsed = parseResponse(response);
    return (parsed['message'] ?? 'Appeal submitted.').toString();
  }
}
