import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'data_cache_service.dart';
import 'offline_sync_service.dart';
import 'connectivity_service.dart';
import 'ban_interceptor.dart';

abstract class ApiService {
  const ApiService();

  List<String> _pathCandidates(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return const [''];

    final normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    if (normalized.isEmpty) return const [''];

    // Hostinger often strips `.php` extensions and returns 301 redirects,
    // which can break CORS preflight for POST requests.
    // Prefer the clean URL, but fall back to the `.php` URL if needed.
    if (normalized.endsWith('.php')) {
      final noPhp = normalized.substring(0, normalized.length - 4);
      return noPhp == normalized ? [normalized] : [noPhp, normalized];
    }

    // If a caller passes `ai_chat`, allow fallback to `ai_chat.php` on servers
    // that don't rewrite extension-less endpoints.
    if (!normalized.contains('.')) {
      return [normalized, '$normalized.php'];
    }

    return [normalized];
  }

  String _normalizeBase(String base) {
    final trimmed = base.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  List<Uri> _buildUriCandidates(String base, String path, {Map<String, String>? query}) {
    final normalizedBase = _normalizeBase(base);
    final candidates = _pathCandidates(path)
        .map((p) => Uri.parse('$normalizedBase/$p'))
        .toList(growable: false);

    final uris = query == null ? candidates : candidates.map((u) => u.replace(queryParameters: query)).toList(growable: false);

    // De-dupe while preserving order.
    final seen = <String>{};
    return uris.where((u) => seen.add(u.toString())).toList(growable: false);
  }

  /// Perform a GET request with caching (Stale-While-Revalidate pattern).
  Future<Map<String, dynamic>> getWithCache(
    String path, {
    Map<String, String>? query,
    Duration? maxAge,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'GET:$path:\${query?.toString() ?? ""}';
    final cacheService = const DataCacheService();

    // 1. Try to get from cache first
    if (!forceRefresh) {
      final cached = await cacheService.getCachedData(cacheKey, maxAge: maxAge);
      if (cached != null) {
        debugPrint('CACHE HIT: $path');
        // If we are offline, return cache immediately
        if (!ConnectivityService().isOnline) {
          return cached;
        }
        // If online, return cache but fetch update in background (SWRE)
        _fetchAndCacheInBackground(path, query, cacheKey);
        return cached;
      }
    }

    // 2. Not in cache or forced refresh, fetch from network
    debugPrint('CACHE MISS/REFRESH: $path');
    final response = await getWithFallback(path, query: query);
    final data = parseResponse(response);
    
    // 3. Update cache
    await cacheService.cacheData(cacheKey, data);
    return data;
  }

  void _fetchAndCacheInBackground(String path, Map<String, String>? query, String cacheKey) async {
    try {
      final response = await getWithFallback(path, query: query);
      final data = parseResponse(response);
      await const DataCacheService().cacheData(cacheKey, data);
      debugPrint('BACKGROUND CACHE UPDATE: $path');
    } catch (e) {
      debugPrint('Background cache update failed for $path: $e');
    }
  }

  Future<http.Response> postMultipartWithFallback(
    String path, {
    Map<String, String>? fields,
    List<http.MultipartFile> files = const [],
    Duration timeout = const Duration(seconds: 45),
  }) async {
    Exception? lastError;
    for (final base in AppConfig.baseUrls) {
      for (final uri in _buildUriCandidates(base, path)) {
        try {
          debugPrint('MULTIPART Connecting to: $uri');

          final request = http.MultipartRequest('POST', uri);
          if (fields != null) {
            request.fields.addAll(fields);
          }
          request.files.addAll(files);

          final streamed = await request.send().timeout(timeout);
          final response = await http.Response.fromStream(streamed);

          // Check for ban in response
          if (BanInterceptor.checkResponse(response.body)) {
            throw Exception('Account banned');
          }

          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded.containsKey('ok')) {
              return response;
            }
          } catch (_) {
            // Not JSON -> try next candidate
          }

          lastError = Exception('HTTP ${response.statusCode} from $uri');
        } catch (e) {
          if (e.toString().contains('Account banned')) rethrow;
          debugPrint('Multipart fallback $uri failed: $e');
          lastError = Exception(e.toString());
          continue;
        }
      }
    }
    throw lastError ?? Exception('Unable to reach CATPT backend on any configured URL');
  }

  /// Perform a POST request with fallback across all base URLs.
  Future<http.Response> postWithFallback(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 10),
    String? offlineActionType, // If provided, will queue if offline
  }) async {
    // Check if offline and action is queueable
    if (!ConnectivityService().isOnline && offlineActionType != null) {
      debugPrint('OFFLINE: Queueing action $offlineActionType');
      await const OfflineSyncService().queueAction(offlineActionType, body ?? {});
      // Return a fake "success" response that the service layer can interpret
      return http.Response(jsonEncode({
        'ok': true, 
        'data': {'message': 'You are offline. Your changes have been queued and will sync when you reconnect.', 'queued': true}
      }), 200);
    }

    Exception? lastError;
    for (final base in AppConfig.baseUrls) {
      for (final uri in _buildUriCandidates(base, path, query: query)) {
        try {
          debugPrint('POST Connecting to: $uri');

          final response = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout);

          // Check for ban in response
          if (BanInterceptor.checkResponse(response.body)) {
            throw Exception('Account banned');
          }

          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded.containsKey('ok')) {
              return response;
            }
          } catch (_) {
            // Not JSON -> try next candidate
          }

          lastError = Exception('HTTP ${response.statusCode} from $uri');
        } catch (e) {
          if (e.toString().contains('Account banned')) rethrow;
          debugPrint('POST fallback $uri failed: $e');
          lastError = Exception(e.toString());
          continue;
        }
      }
    }

    // If all failed and we have a queueable action, queue it as a last resort
    if (offlineActionType != null) {
      debugPrint('ALL URLS FAILED: Queueing action $offlineActionType');
      await const OfflineSyncService().queueAction(offlineActionType, body ?? {});
      return http.Response(jsonEncode({
        'ok': true, 
        'data': {'message': 'Connection error. Changes queued for later sync.', 'queued': true}
      }), 200);
    }

    throw lastError ?? Exception('Unable to reach CATPT backend on any configured URL');
  }

  /// Perform a GET request with fallback across all base URLs.
  Future<http.Response> getWithFallback(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Exception? lastError;
    for (final base in AppConfig.baseUrls) {
      for (final uri in _buildUriCandidates(base, path, query: query)) {
        try {
          debugPrint('GET Connecting to: $uri');

          final response = await http.get(uri).timeout(timeout);

          // Check for ban in response
          if (BanInterceptor.checkResponse(response.body)) {
            throw Exception('Account banned');
          }

          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded.containsKey('ok')) {
              return response;
            }
          } catch (_) {
            // Not JSON -> try next candidate
          }

          lastError = Exception('HTTP ${response.statusCode} from $uri');
        } catch (e) {
          if (e.toString().contains('Account banned')) rethrow;
          debugPrint('GET fallback $uri failed: $e');
          lastError = Exception(e.toString());
          continue;
        }
      }
    }
    throw lastError ?? Exception('Unable to reach CATPT backend on any configured URL');
  }

  /// Utility to handle common response parsing
  Map<String, dynamic> parseResponse(http.Response response) {
    dynamic parsed;
    try {
      parsed = jsonDecode(response.body);
    } catch (e) {
      throw Exception('Server returned invalid data format');
    }

    if (parsed is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    if (response.statusCode != 200 || parsed['ok'] != true) {
      final rawMessage = (parsed['message'] ?? 'Request failed').toString();
      throw Exception(_sanitizeError(rawMessage));
    }

    return Map<String, dynamic>.from(parsed['data'] as Map);
  }

  String _sanitizeError(String error) {
    final lower = error.toLowerCase();
    
    if (lower.contains('sqlstate') || lower.contains('database error')) {
      return 'The system is experiencing a temporary database issue. Please try again in 5 minutes.';
    }
    if (lower.contains('ai provider error') || lower.contains('openrouter') || lower.contains('ai error')) {
      return 'The AI service is temporarily unavailable. Our team has been notified and is working on it.';
    }
    if (lower.contains('dioerror') || lower.contains('socketexception') || lower.contains('connection failed')) {
      return 'Connection error. Please check your internet and try again.';
    }
    if (lower.contains('method not allowed') || lower.contains('405')) {
      return 'An unexpected communication error occurred. Please ensure your app is up to date.';
    }
    if (lower.contains('invalid credentials') || lower.contains('incorrect password')) {
      return 'Incorrect ID or password. Please double-check and try again.';
    }
    if (lower.contains('user not found')) {
      return 'This account was not found. Please contact the administration if you believe this is an error.';
    }
    if (lower.contains('timeout')) {
      return 'The connection timed out. The server might be busy, please try again.';
    }
    
    // Fallback: If it's a long technical string, replace it, otherwise keep it if it looks like a manual error msg
    if (error.length > 60 && (error.contains(':') || error.contains('{'))) {
      return 'An unexpected error occurred. Please report this to the support team.';
    }

    return error;
  }
}
