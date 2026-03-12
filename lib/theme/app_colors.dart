import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // ── Single brand blue ─────────────────────────────────────────────────────
  static Color blue = const Color.fromARGB(255, 0, 26, 255);  // primaryBlue from your system
  static Color primary(BuildContext context) => blue;

  // ── Other accent colours ──────────────────────────────────────────────────
  static const Color yellow  = Color.fromARGB(255, 181, 184, 0); // primaryYellow
  static const Color green   = Color.fromARGB(255, 34, 197, 94);  // customSuccess
  static const Color red     = Color.fromARGB(255, 239, 68, 68);  // customError / customLike
  static const Color orange  = Color.fromARGB(255, 255, 165, 0);  // customWarning
  static const Color info    = Color.fromARGB(255, 59, 130, 246); // customInfo
  static const Color purple  = Color(0xFF7B1FA2);

  // ── Gradient (darker → same blue) ────────────────────────────────────────
  static LinearGradient get blueGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HSLColor.fromColor(blue).withLightness((HSLColor.fromColor(blue).lightness - 0.1).clamp(0.0, 1.0)).toColor(), 
      blue
    ],
  );

  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      HSLColor.fromColor(blue).withLightness((HSLColor.fromColor(blue).lightness - 0.1).clamp(0.0, 1.0)).toColor(), 
      blue
    ],
  );

  // ── Light theme ───────────────────────────────────────────────────────────
  static const Color lightBackground    = Color(0xFFF8FAFC);
  static const Color lightSurface       = Color(0xFFFFFFFF);
  static const Color lightTextPrimary   = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color mutedCard          = Color(0xFFF8FAFC);
  
  // ── Dark theme compatibility (mapped to light values) ─────────────────────
  static const Color darkBackground    = Color(0xFF0F1219); // Deep, premium blue-grey
  static const Color darkSurface       = Color(0xFF1A1F2E); // Slightly elevated dark tone
  static const Color darkTextPrimary   = Color(0xFFF1F5F9); // Crisp off-white
  static const Color darkTextSecondary = Color(0xFFA1AABB); // Soft neutral text
}