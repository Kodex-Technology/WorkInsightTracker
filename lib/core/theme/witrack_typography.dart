import 'package:flutter/material.dart';

abstract final class WitrackTypography {
  static const String fontFamily = 'PlusJakartaSans';

  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.35,
      double letterSpacing = 0,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displayLarge: style(
        size: 40,
        weight: FontWeight.w700,
        color: primary,
        letterSpacing: -1.2,
      ),
      displayMedium: style(
        size: 32,
        weight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.8,
      ),
      displaySmall: style(
        size: 28,
        weight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
      ),
      headlineMedium: style(size: 22, weight: FontWeight.w600, color: primary),
      headlineSmall: style(size: 18, weight: FontWeight.w600, color: primary),
      titleLarge: style(size: 18, weight: FontWeight.w600, color: primary),
      titleMedium: style(size: 15, weight: FontWeight.w600, color: primary),
      titleSmall: style(size: 13, weight: FontWeight.w600, color: primary),
      bodyLarge: style(size: 15, weight: FontWeight.w500, color: primary, height: 1.45),
      bodyMedium: style(size: 14, weight: FontWeight.w500, color: primary, height: 1.45),
      bodySmall: style(size: 12, weight: FontWeight.w500, color: secondary, height: 1.4),
      labelLarge: style(size: 13, weight: FontWeight.w600, color: primary),
      labelMedium: style(size: 12, weight: FontWeight.w600, color: primary),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.4,
      ),
    );
  }
}
