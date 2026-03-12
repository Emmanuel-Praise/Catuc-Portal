import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  Color _primaryColor = const Color.fromARGB(255, 0, 26, 255);
  final LocalStorageService _storage = const LocalStorageService();

  Color get primaryColor => _primaryColor;

  Future<void> init() async {
    final savedColor = _storage.getSetting('primary_color');
    if (savedColor != null) {
      try {
        _primaryColor = Color(int.parse(savedColor, radix: 16));
      } catch (e) {
        // Fallback to default
      }
    }
  }

  Future<void> updatePrimaryColor(Color color) async {
    _primaryColor = color;
    await _storage.saveSetting('primary_color', color.toARGB32().toRadixString(16));
    notifyListeners();
  }
}
