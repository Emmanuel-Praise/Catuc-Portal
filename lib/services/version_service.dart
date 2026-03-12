import '../models/app_version.dart';
import 'api_service.dart';

class _CoreApiService extends ApiService {
  const _CoreApiService();
}

class VersionService {
  static const String _endpoint = 'version.php';

  const VersionService();

  Future<AppVersion> fetchRequiredVersion() async {
    try {
      final api = const _CoreApiService();
      final response = await api.getWithFallback(_endpoint);
      final data = api.parseResponse(response);
      return AppVersion.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      // In case of error, assume local version is fine to avoid locking users out due to network issues
      // though ideally we'd handle this more gracefully.
      return AppVersion(versionCode: 0, versionName: '0.0.0');
    }
  }

  bool isUpdateRequired(int currentCode, AppVersion required) {
    return currentCode < required.versionCode;
  }
}
