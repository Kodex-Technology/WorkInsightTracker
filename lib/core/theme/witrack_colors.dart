import 'package:flutter/material.dart';

/// Brand color tokens — Work Insights reference palette.
/// Change values here; [WitrackTheme] maps them into ThemeData.
abstract final class WitrackColors {
  // Dark (default) — deep navy canvas, teal actions, purple secondary
  static const Color darkBgPrimary = Color(0xFF071521);
  static const Color darkBgSecondary = Color(0xFF0C1E2E);
  static const Color darkSurface = Color(0xFF122A3D);
  static const Color darkAccentPrimary = Color(0xFF14B8A6);
  static const Color darkAccentSecondary = Color(0xFFA78BFA);
  static const Color darkHighlight = Color(0xFF14B8A6);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF1E3A4F);
  static const Color darkNavActive = Color(0xFF134E4A);

  // Light — soft gray canvas, deep teal brand
  static const Color lightBgPrimary = Color(0xFFF3F6F8);
  static const Color lightBgSecondary = Color(0xFFE8EEF2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightAccentPrimary = Color(0xFF0F766E);
  static const Color lightAccentSecondary = Color(0xFF7C3AED);
  static const Color lightHighlight = Color(0xFF0F766E);
  static const Color lightTextPrimary = Color(0xFF0B1A24);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightBorder = Color(0xFFD0DAE3);
  static const Color lightNavActive = Color(0xFFDCF5F2);

  /// Logo glyph: white on dark UI, teal-green on light (day) UI.
  static const Color darkLogo = Color(0xFFFFFFFF);
  static const Color lightLogo = Color(0xFF0F766E);

  // Shared semantic
  static const Color danger = Color(0xFFE11D48);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF16A34A);
}
