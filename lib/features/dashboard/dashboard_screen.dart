import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/dashboard/activity_sparkline.dart';
import 'package:witrack/features/dashboard/circular_progress_ring.dart';
import 'package:witrack/features/dashboard/live_session_timer.dart';
import 'package:witrack/features/dashboard/project_time_tree.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';
import 'package:witrack/features/tracking/tracking_controls.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_ensureProjectSeed);
  }

  Future<void> _ensureProjectSeed() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    // Workspace only — no default project/task. User creates work before Start.
    final workspaceId = await ref
        .read(projectRepositoryProvider)
        .ensureDefaultWorkspace(user.id);
    final live = ref.read(trackingControllerProvider);
    if (live.workspaceId == null) {
      ref.read(trackingControllerProvider.notifier).setWorkspaceId(workspaceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(
      trackingControllerProvider.select((s) => s.status),
    );
    final workspaceId = ref.watch(
      trackingControllerProvider.select((s) => s.workspaceId),
    );
    final projectId = ref.watch(
      trackingControllerProvider.select((s) => s.projectId),
    );
    final taskId = ref.watch(
      trackingControllerProvider.select((s) => s.taskId),
    );
    final activityPercent = ref.watch(
      trackingControllerProvider.select((s) => s.activityPercent),
    );
    final currentApp = ref.watch(
      trackingControllerProvider.select((s) => s.currentApp),
    );
    final lastShot = ref.watch(
      trackingControllerProvider.select((s) => s.lastScreenshotAt),
    );
    final errorMessage = ref.watch(
      trackingControllerProvider.select((s) => s.errorMessage),
    );
    final trackingSnapshot = TrackingUiState(
      status: status,
      workspaceId: workspaceId,
      projectId: projectId,
      taskId: taskId,
      activityPercent: activityPercent,
      currentApp: currentApp,
      lastScreenshotAt: lastShot,
      errorMessage: errorMessage,
    );
    final sessions = ref.watch(recentSessionsProvider);
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WitrackSurface(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Session',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        _StatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const LiveSessionTimer(),
                    const SizedBox(height: 14),
                    TrackingControls(state: trackingSnapshot),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const ProjectTimeTreePanel(),
              const SizedBox(height: 12),
              const _DashboardInsights(),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: WitrackSurface(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Activity',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                currentApp == null || currentApp.isEmpty
                                    ? '—'
                                    : currentApp,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (lastShot != null) ...[
                                Text(
                                  ' · ${DateFormat.Hm().format(lastShot)}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          const ActivitySparkline(),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            children: [
                              TextButton(
                                onPressed: () => context.go('/app/screenshots'),
                                child: const Text('Screenshots'),
                              ),
                              TextButton(
                                onPressed: status.isRunning
                                    ? () => ref
                                        .read(
                                          trackingControllerProvider.notifier,
                                        )
                                        .captureTestScreenshot()
                                    : null,
                                child: const Text('Test screenshot'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: WitrackSurface(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent sessions',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          sessions.when(
                            skipLoadingOnReload: true,
                            skipLoadingOnRefresh: true,
                            loading: () => const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (e, _) => Text('$e'),
                            data: (rows) {
                              if (rows.isEmpty) {
                                return Text(
                                  'No sessions yet.',
                                  style: theme.textTheme.bodySmall,
                                );
                              }
                              return Column(
                                children: [
                                  for (final row in rows.take(5))
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        DateFormat('MMM d · HH:mm')
                                            .format(row.startedAt.toLocal()),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      subtitle: Text(
                                        '${row.state} · ${_compact(row.activeMs + row.idleMs + row.pausedMs)}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _compact(int ms) {
    final d = Duration(milliseconds: ms);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

final recentSessionsProvider = StreamProvider<List<TrackingSession>>((ref) {
  return ref.watch(sessionRepositoryProvider).watchRecentSessions();
});

class _DashboardInsights extends ConsumerWidget {
  const _DashboardInsights();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final activityPercent = ref.watch(
      trackingControllerProvider.select((s) => s.activityPercent),
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
    final day = ref.watch(dayTimeTreeBaseProvider.select((t) => t.day));
    final activeMs = day.active.inMilliseconds +
        (open ? active.inMilliseconds : 0);
    final idleMs = day.idle.inMilliseconds + (open ? idle.inMilliseconds : 0);
    final pausedMs =
        day.paused.inMilliseconds + (open ? paused.inMilliseconds : 0);
    final totalMs = activeMs + idleMs + pausedMs;
    final activeFrac = totalMs == 0 ? 0.0 : activeMs / totalMs;
    final idleFrac = totalMs == 0 ? 0.0 : idleMs / totalMs;
    final pausedFrac = totalMs == 0 ? 0.0 : pausedMs / totalMs;
    final activityFrac =
        ((activityPercent ?? 0).clamp(0.0, 100.0)) / 100.0;

    return WitrackSurface(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Progress',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (open)
                Text(
                  'LIVE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Today mix · circular readouts update with the open session',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              CircularProgressRing(
                value: activityFrac,
                label: 'Focus',
                caption: 'Live activity',
                color: accent,
                size: 102,
              ),
              CircularProgressRing(
                value: activeFrac,
                label: 'Active',
                caption: _compactMs(activeMs),
                color: accent,
                size: 96,
              ),
              CircularProgressRing(
                value: idleFrac,
                label: 'Idle',
                caption: _compactMs(idleMs),
                color: secondary,
                size: 96,
              ),
              CircularProgressRing(
                value: pausedFrac,
                label: 'Paused',
                caption: _compactMs(pausedMs),
                color: const Color(0xFF64748B),
                size: 96,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _compactMs(int ms) {
    final d = Duration(milliseconds: ms);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      TrackingStatus.tracking => theme.colorScheme.primary,
      TrackingStatus.idle => const Color(0xFFD97706),
      TrackingStatus.paused => const Color(0xFF38BDF8),
      TrackingStatus.error => theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
