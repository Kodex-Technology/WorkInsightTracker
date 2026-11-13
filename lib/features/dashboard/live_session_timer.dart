import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/core/theme/witrack_colors.dart';
import 'package:witrack/data/tracking/time_totals.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/dashboard/project_time_tree.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

/// Isolated ticker — only clocks rebuild every second.
class LiveSessionTimer extends ConsumerWidget {
  const LiveSessionTimer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed = ref.watch(
      trackingControllerProvider.select((s) => s.elapsed),
    );
    final active = ref.watch(
      trackingControllerProvider.select((s) => s.active),
    );
    final idle = ref.watch(
      trackingControllerProvider.select((s) => s.idle),
    );
    final paused = ref.watch(
      trackingControllerProvider.select((s) => s.paused),
    );
    final open = ref.watch(
      trackingControllerProvider.select(
        (s) =>
            s.status == TrackingStatus.tracking ||
            s.status == TrackingStatus.idle ||
            s.status == TrackingStatus.paused,
      ),
    );
    final projectName = ref.watch(
      trackingControllerProvider.select((s) => s.projectName),
    );
    final taskName = ref.watch(
      trackingControllerProvider.select((s) => s.taskName),
    );
    final baseDay = ref.watch(
      dayTimeTreeBaseProvider.select((t) => t.day.total),
    );
    final today = baseDay + (open ? elapsed : Duration.zero);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatClock(open ? elapsed : Duration.zero),
          style: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 1.0,
            fontSize: 44,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              taskName == null
                  ? Icons.radio_button_unchecked
                  : Icons.task_alt_rounded,
              size: 16,
              color: muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                taskName == null
                    ? 'Select a task to enable Start'
                    : '${projectName ?? 'Project'} · $taskName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                : const Color(0xFFF1F5F9).withValues(alpha: 0.9),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Today (all work)',
                  value: formatClock(today),
                  emphasis: true,
                ),
              ),
              _StatDivider(color: theme.dividerColor),
              Expanded(
                child: _MiniStat(
                  label: 'Active',
                  value: formatClock(active),
                ),
              ),
              _StatDivider(color: theme.dividerColor),
              Expanded(
                child: _MiniStat(
                  label: 'Idle',
                  value: formatClock(idle),
                ),
              ),
              _StatDivider(color: theme.dividerColor),
              Expanded(
                child: _MiniStat(
                  label: 'Paused',
                  value: formatClock(paused),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color.withValues(alpha: 0.55),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasis
        ? WitrackColors.success
        : theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
            color: emphasis ? WitrackColors.success : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
