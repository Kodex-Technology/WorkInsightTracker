import 'package:flutter/material.dart';
import 'package:witrack/core/constants/app_constants.dart';
import 'package:witrack/core/widgets/witrack_mark.dart';

/// In-app brand: mark + WorkInsight / Tracker (reference-style lockup).
/// OS title bar / taskbar use the mark-only icon — not this widget.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.markSize = 32,
    this.compact = false,
  });

  final double markSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tooNarrow = !constraints.hasBoundedWidth ||
            constraints.maxWidth < markSize + 72;
        if (compact || tooNarrow) {
          return WitrackMark(size: markSize);
        }

        final theme = Theme.of(context);
        final accent = theme.colorScheme.primary;

        return Row(
          children: [
            WitrackMark(size: markSize),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.brandPrimary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      height: 1.1,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 28,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppConstants.brandSecondary.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 9.5,
                      letterSpacing: 1.35,
                      height: 1.1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
