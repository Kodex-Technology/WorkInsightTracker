import 'package:flutter/material.dart';
import 'package:witrack/core/theme/witrack_colors.dart';
import 'package:witrack/core/theme/witrack_typography.dart';

abstract final class WitrackTheme {
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bgPrimary: WitrackColors.darkBgPrimary,
        bgSecondary: WitrackColors.darkBgSecondary,
        surface: WitrackColors.darkSurface,
        accent: WitrackColors.darkAccentPrimary,
        accentSecondary: WitrackColors.darkAccentSecondary,
        highlight: WitrackColors.darkHighlight,
        textPrimary: WitrackColors.darkTextPrimary,
        textSecondary: WitrackColors.darkTextSecondary,
        border: WitrackColors.darkBorder,
        navActive: WitrackColors.darkNavActive,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        bgPrimary: WitrackColors.lightBgPrimary,
        bgSecondary: WitrackColors.lightBgSecondary,
        surface: WitrackColors.lightSurface,
        accent: WitrackColors.lightAccentPrimary,
        accentSecondary: WitrackColors.lightAccentSecondary,
        highlight: WitrackColors.lightHighlight,
        textPrimary: WitrackColors.lightTextPrimary,
        textSecondary: WitrackColors.lightTextSecondary,
        border: WitrackColors.lightBorder,
        navActive: WitrackColors.lightNavActive,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bgPrimary,
    required Color bgSecondary,
    required Color surface,
    required Color accent,
    required Color accentSecondary,
    required Color highlight,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    required Color navActive,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accentSecondary,
      onSecondary: Colors.white,
      error: WitrackColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      surfaceContainerHighest: bgSecondary,
    );

    final textTheme = WitrackTypography.textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: WitrackTypography.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgPrimary,
      canvasColor: bgPrimary,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: textSecondary, size: 20),
      dividerColor: border,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bgSecondary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
        selectedColor: accent,
        selectedTileColor: navActive,
        dense: true,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accent.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: WitrackTypography.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: WitrackTypography.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontFamily: WitrackTypography.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return surface;
          }),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.7);
          }
          return border;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary),
        floatingLabelStyle: TextStyle(color: accent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgSecondary,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: bgSecondary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: textPrimary),
      ),
      extensions: <ThemeExtension<dynamic>>[
        WitrackThemeExtras(
          navActive: navActive,
          sidebarBg: bgSecondary,
          highlight: highlight,
          topBarBg: surface,
        ),
      ],
    );
  }
}

@immutable
class WitrackThemeExtras extends ThemeExtension<WitrackThemeExtras> {
  const WitrackThemeExtras({
    required this.navActive,
    required this.sidebarBg,
    required this.highlight,
    required this.topBarBg,
  });

  final Color navActive;
  final Color sidebarBg;
  final Color highlight;
  final Color topBarBg;

  @override
  WitrackThemeExtras copyWith({
    Color? navActive,
    Color? sidebarBg,
    Color? highlight,
    Color? topBarBg,
  }) {
    return WitrackThemeExtras(
      navActive: navActive ?? this.navActive,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      highlight: highlight ?? this.highlight,
      topBarBg: topBarBg ?? this.topBarBg,
    );
  }

  @override
  WitrackThemeExtras lerp(ThemeExtension<WitrackThemeExtras>? other, double t) {
    if (other is! WitrackThemeExtras) return this;
    return WitrackThemeExtras(
      navActive: Color.lerp(navActive, other.navActive, t) ?? navActive,
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t) ?? sidebarBg,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      topBarBg: Color.lerp(topBarBg, other.topBarBg, t) ?? topBarBg,
    );
  }
}
