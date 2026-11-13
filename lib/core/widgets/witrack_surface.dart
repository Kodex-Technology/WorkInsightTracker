import 'package:flutter/material.dart';

class WitrackSurface extends StatelessWidget {
  const WitrackSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.07),
                    theme.colorScheme.surface,
                  ),
                  theme.colorScheme.surface,
                  Color.alphaBlend(
                    theme.colorScheme.secondary.withValues(alpha: 0.04),
                    theme.colorScheme.surface,
                  ),
                ]
              : [
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.05),
                    theme.colorScheme.surface,
                  ),
                  theme.colorScheme.surface,
                  Color.alphaBlend(
                    theme.colorScheme.secondary.withValues(alpha: 0.035),
                    const Color(0xFFF8FAFC),
                  ),
                ],
        ),
        border: Border.all(
          color: isDark
              ? theme.dividerColor.withValues(alpha: 0.95)
              : theme.dividerColor.withValues(alpha: 0.9),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.28)
                      : accent.withValues(alpha: 0.06),
                  blurRadius: isDark ? 14 : 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
    );
  }
}
