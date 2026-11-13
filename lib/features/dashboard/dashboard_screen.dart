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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                    const SizedBox(height: 16),
                    const LiveSessionTimer(),
                    const SizedBox(height: 16),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: WitrackSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity overview',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _MetricChip(
                                label: 'Activity',
                                value: activityPercent == null
                                    ? '—'
                                    : '${activityPercent.round()}%',
                                tone: _MetricTone.teal,
                              ),
                              _MetricChip(
                                label: 'App',
                                value: currentApp ?? '—',
                                tone: _MetricTone.sky,
                              ),
                              _MetricChip(
                                label: 'Last shot',
                                value: lastShot == null
                                    ? '—'
                                    : DateFormat.Hm().format(lastShot),
                                tone: _MetricTone.slate,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const ActivitySparkline(),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => context.go('/app/timeline'),
                                child: const Text('Timeline'),
                              ),
                              TextButton(
                                onPressed: () => context.go('/app/screenshots'),
                                child: const Text('Screenshots'),
                              ),
                              TextButton(
                                onPressed: () => context.go('/app/reports'),
                                child: const Text('Reports'),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent sessions',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
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
                                  for (final row in rows.take(6))
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TrackingStatus.tracking => const Color(0xFF16A34A),
      TrackingStatus.idle => const Color(0xFFD97706),
      TrackingStatus.paused => const Color(0xFF0284C7),
      TrackingStatus.error => const Color(0xFFE11D48),
      _ => Theme.of(context).dividerColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

enum _MetricTone { teal, sky, slate }

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.tone = _MetricTone.teal,
  });

  final String label;
  final String value;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (top, bottom, accent) = _gradient(isDark);

    return Container(
      width: 148,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.28 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _gradient(bool isDark) {
    switch (tone) {
      case _MetricTone.teal:
        return isDark
            ? (
                const Color(0xFF14302C),
                const Color(0xFF171E27),
                const Color(0xFF2DD4BF),
              )
            : (
                const Color(0xFFE7F7F4),
                const Color(0xFFFFFFFF),
                const Color(0xFF0F766E),
              );
      case _MetricTone.sky:
        return isDark
            ? (
                const Color(0xFF152636),
                const Color(0xFF171E27),
                const Color(0xFF38BDF8),
              )
            : (
                const Color(0xFFE8F3FB),
                const Color(0xFFFFFFFF),
                const Color(0xFF0369A1),
              );
      case _MetricTone.slate:
        return isDark
            ? (
                const Color(0xFF1B2330),
                const Color(0xFF171E27),
                const Color(0xFF94A3B8),
              )
            : (
                const Color(0xFFF0F3F7),
                const Color(0xFFFFFFFF),
                const Color(0xFF64748B),
              );
    }
  }
}
