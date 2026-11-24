import 'package:flutter/material.dart';
import 'package:witrack/core/theme/witrack_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// WorkInsight diamond mark. Tints for light/dark automatically (no glow).
class WitrackMark extends StatelessWidget {
  const WitrackMark({
    super.key,
    this.size = 64,
    @Deprecated('Glow removed — kept for call-site compatibility')
    this.showGlow = false,
    this.forceColor,
  });

  static const assetPath = 'assets/branding/workinsight_mark.svg';

  final double size;
  final bool showGlow;
  final Color? forceColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glyph = forceColor ??
        (isDark ? WitrackColors.darkLogo : WitrackColors.lightLogo);

    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(glyph, BlendMode.srcIn),
      ),
    );
  }
}
