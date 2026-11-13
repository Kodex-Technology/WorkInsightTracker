import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final accent = theme.colorScheme.primary;
    final panelBg = isDark
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.06),
            const Color(0xFF0A1C2A),
          )
        : const Color(0xFFF1F5F9).withValues(alpha: 0.95);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatClock(open ? elapsed : Duration.zero),
          style: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            height: 1.0,
            fontSize: 44,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              taskName == null
                  ? Icons.radio_button_unchecked
                  : Icons.task_alt_rounded,
              size: 16,
              color: taskName == null ? muted : accent,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                taskName == null
                    ? 'Select a task below to start'
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
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: panelBg,
            border: Border.all(
              color: isDark
                  ? theme.dividerColor.withValues(alpha: 0.9)
                  : theme.dividerColor.withValues(alpha: 0.75),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Today',
                  value: formatClock(today),
                  emphasize: true,
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
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: color.withValues(alpha: 0.4),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: muted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: emphasize
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.92),
          ),
        ),
      ],
    );
  }
}
