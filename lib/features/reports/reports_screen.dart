import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/theme/witrack_colors.dart';
import 'package:witrack/core/theme/witrack_theme.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/dashboard/activity_sparkline.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

final reportSessionsProvider = StreamProvider<List<TrackingSession>>((ref) {
  return ref.watch(sessionRepositoryProvider).watchRecentSessions(limit: 100);
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(reportSessionsProvider);
    final user = ref.watch(authControllerProvider).user;
    final live = ref.watch(trackingControllerProvider);
    final theme = Theme.of(context);
    final highlight =
        theme.extension<WitrackThemeExtras>()?.highlight ?? WitrackColors.warning;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: sessions.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Report load failed: $e'),
            data: (rows) {
              final mine = user == null
                  ? rows
                  : rows.where((r) => r.userId == user.id).toList();

              // Prefer live clock for the open session so bars tick in real time.
              var active = 0;
              var idle = 0;
              var paused = 0;
              for (final row in mine) {
                if (live.sessionId != null &&
                    row.id == live.sessionId &&
                    live.status != TrackingStatus.stopped) {
                  active += live.active.inMilliseconds;
                  idle += live.idle.inMilliseconds;
                  paused += live.paused.inMilliseconds;
                } else {
                  active += row.activeMs;
                  idle += row.idleMs;
                  paused += row.pausedMs;
                }
              }
              final total = active + idle + paused;
              final today = DateTime.now();
              final startOfToday = DateTime(today.year, today.month, today.day);
              final todayMs = _sumForRange(
                mine,
                live,
                startOfToday,
                startOfToday.add(const Duration(days: 1)),
              );
              final weekStart =
                  startOfToday.subtract(Duration(days: today.weekday - 1));
              final weekMs = _sumForRange(
                mine,
                live,
                weekStart,
                startOfToday.add(const Duration(days: 1)),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    live.status.isRunning
                        ? 'Live totals include the open session clock (updates every second).'
                        : 'Local SQLite session totals — no fabricated productivity scores.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Metric(
                        label: 'Today',
                        value: _fmt(todayMs),
                        accent: highlight,
                      ),
                      _Metric(label: 'This week', value: _fmt(weekMs)),
                      _Metric(
                        label: 'Active',
                        value: _fmt(active),
                        accent: theme.colorScheme.primary,
                      ),
                      _Metric(
                        label: 'Idle',
                        value: _fmt(idle),
                        accent: theme.colorScheme.secondary,
                      ),
                      _Metric(label: 'Paused', value: _fmt(paused)),
                      _Metric(label: 'Sessions', value: '${mine.length}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  WitrackSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Active / idle / paused mix',
                              style: theme.textTheme.titleSmall,
                            ),
                            const Spacer(),
                            if (live.status.isRunning)
                              Text(
                                'LIVE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (total == 0)
                          Text(
                            'Track a session to populate breakdown bars.',
                            style: theme.textTheme.bodySmall,
                          )
                        else ...[
                          _Bar(
                            label: 'Active',
                            fraction: active / total,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          _Bar(
                            label: 'Idle',
                            fraction: idle / total,
                            color: highlight,
                          ),
                          const SizedBox(height: 8),
                          _Bar(
                            label: 'Paused',
                            fraction: paused / total,
                            color: theme.colorScheme.outline,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const WitrackSurface(
                    child: ActivitySparkline(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: mine.isEmpty
                        ? WitrackSurface(
                            child: Center(
                              child: Text(
                                'No sessions yet.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: mine.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final row = mine[index];
                              final isLive = live.sessionId == row.id &&
                                  live.status.isRunning;
                              final a = isLive
                                  ? live.active.inMilliseconds
                                  : row.activeMs;
                              final i = isLive
                                  ? live.idle.inMilliseconds
                                  : row.idleMs;
                              final p = isLive
                                  ? live.paused.inMilliseconds
                                  : row.pausedMs;
                              return WitrackSurface(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat.yMMMd()
                                                .add_Hm()
                                                .format(row.startedAt.toLocal()),
                                            style: theme.textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Active ${_fmt(a)} · Idle ${_fmt(i)} · Paused ${_fmt(p)}'
                                            '${isLive ? ' · live' : ''}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    _StatusBadge(
                                      state: isLive
                                          ? live.status.name
                                          : row.state,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  int _sumForRange(
    List<TrackingSession> mine,
    TrackingUiState live,
    DateTime startLocal,
    DateTime endLocal,
  ) {
    var sum = 0;
    for (final r in mine) {
      final started = r.startedAt.toLocal();
      if (started.isBefore(startLocal) || !started.isBefore(endLocal)) {
        continue;
      }
      if (live.sessionId != null &&
          r.id == live.sessionId &&
          live.status != TrackingStatus.stopped) {
        sum += live.elapsed.inMilliseconds;
      } else {
        sum += r.activeMs + r.idleMs + r.pausedMs;
      }
    }
    return sum;
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 148,
      child: WitrackSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (accent != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.fraction,
    required this.color,
  });

  final String label;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.35),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            '${(fraction * 100).round()}%',
            style: theme.textTheme.labelMedium,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (state) {
      'tracking' => WitrackColors.success,
      'idle' => WitrackColors.warning,
      'paused' => theme.colorScheme.secondary,
      'stopped' => theme.colorScheme.onSurfaceVariant,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        state,
        style: theme.textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}
