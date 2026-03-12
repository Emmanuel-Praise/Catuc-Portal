import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static String get baseUrl => baseUrls.first;

  static List<String> get baseUrls {
    if (kIsWeb) {
      return const [
        // 'http://127.0.0.1/api',
        // 'http://localhost/api',
        'https://catuc.cloud/api',
        // Fallbacks for hosts that deploy the PHP API under a different base path.
        'https://catuc.cloud/website/backend/api',
        'https://catuc.cloud/backend/api',
      ];
    }

    return const [
      // 'http://127.0.0.1/api',
      // 'http://localhost/api',
      // 'http://10.0.2.2/api',
      // 'http://192.168.1.196/api',
      'https://catuc.cloud/api',
      // Fallbacks for hosts that deploy the PHP API under a different base path.
      'https://catuc.cloud/website/backend/api',
      'https://catuc.cloud/backend/api',
    ];
  }
}
