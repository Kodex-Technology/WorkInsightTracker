import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/core/theme/witrack_colors.dart';
import 'package:witrack/core/theme/witrack_theme.dart';
import 'package:witrack/core/theme/witrack_typography.dart';

void main() {
  test('dark theme uses Witrack brand background and teal accent', () {
    final theme = WitrackTheme.dark();
    expect(theme.scaffoldBackgroundColor, WitrackColors.darkBgPrimary);
    expect(theme.colorScheme.primary, WitrackColors.darkAccentPrimary);
    expect(theme.extension<WitrackThemeExtras>()?.highlight,
        WitrackColors.darkHighlight);
    expect(theme.textTheme.bodyLarge?.fontFamily, WitrackTypography.fontFamily);
  });

  test('light theme uses Witrack light tokens with teal selection', () {
    final theme = WitrackTheme.light();
    expect(theme.scaffoldBackgroundColor, WitrackColors.lightBgPrimary);
    expect(theme.colorScheme.primary, WitrackColors.lightAccentPrimary);
    expect(theme.extension<WitrackThemeExtras>()?.navActive,
        WitrackColors.lightNavActive);
  });
}
