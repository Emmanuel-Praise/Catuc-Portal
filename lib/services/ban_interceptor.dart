import 'dart:convert';
import 'package:flutter/material.dart';
import '../shared/screens/banned_screen.dart';
import 'local_storage_service.dart';

/// Global ban interceptor. Checks every API response for ban signals
/// and immediately redirects to BannedScreen.
class BanInterceptor {
  BanInterceptor._();

  /// Global navigator key — set this on MaterialApp
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static bool _isBanScreenShowing = false;

  /// Call this on every API response body string.
  /// Returns true if user was banned (and navigation happened).
  static bool checkResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map && decoded['banned'] == true) {
        final reason = (decoded['ban_reason'] ?? decoded['message'] ?? 'Security violation').toString();
        _showBanScreen(reason);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Force show the ban screen immediately from anywhere in the app.
  static void _showBanScreen(String reason) {
    if (_isBanScreenShowing) return; // prevent duplicate
    _isBanScreenShowing = true;

    // Get user_id from saved session
    String userId = '';
    try {
      final session = const LocalStorageService().getSession();
      userId = (session?['user_id'] ?? '').toString();
    } catch (_) {}

    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => BannedScreen(
            userId: userId,
            reason: reason,
            bannedAt: DateTime.now().toString().substring(0, 19),
          ),
        ),
        (route) => false, // remove ALL routes — no going back
      );
    }
  }

  /// Reset flag (for testing purposes, e.g., after unban)
  static void reset() {
    _isBanScreenShowing = false;
  }
}
