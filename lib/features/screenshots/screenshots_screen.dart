import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/data/screenshots/screenshot_store.dart';
import 'package:witrack/data/tracking/productivity.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

final screenshotFilterProvider =
    NotifierProvider<ScreenshotFilterNotifier, ScreenshotFilter>(
  ScreenshotFilterNotifier.new,
);

class ScreenshotFilterNotifier extends Notifier<ScreenshotFilter> {
  @override
  ScreenshotFilter build() {
    // Reset filters when the signed-in user changes (avoids stale project/task ids).
    ref.listen(authControllerProvider.select((s) => s.user?.id), (prev, next) {
      if (prev != next) {
        state = ScreenshotFilter(day: ScreenshotStore.dayKey(DateTime.now()));
      }
    });
    return ScreenshotFilter(day: ScreenshotStore.dayKey(DateTime.now()));
  }

  void setDay(String? day) =>
      state = state.copyWith(day: day, clearDay: day == null);

  void setProject(String? projectId) => state = state.copyWith(
        projectId: projectId,
        clearProject: projectId == null,
        clearTask: true,
      );

  void setTask(String? taskId) => state = state.copyWith(
        taskId: taskId,
        clearTask: taskId == null,
      );

  void clearProjectIfMissing(Iterable<String> projectIds) {
    final id = state.projectId;
    if (id != null && !projectIds.contains(id)) {
      state = state.copyWith(clearProject: true, clearTask: true);
    }
  }

  void clearTaskIfMissing(Iterable<String> taskIds) {
    final id = state.taskId;
    if (id != null && !taskIds.contains(id)) {
      state = state.copyWith(clearTask: true);
    }
  }
}

final screenshotsProvider = StreamProvider<List<Screenshot>>((ref) {
  final filter = ref.watch(screenshotFilterProvider);
  return ref.watch(screenshotStoreProvider).watchFiltered(filter);
});

final screenshotDaysProvider = FutureProvider<List<String>>((ref) {
  ref.watch(screenshotsProvider);
  return ref.watch(screenshotStoreProvider).distinctTakenDays();
});

final screenshotProjectsProvider = StreamProvider<List<Project>>((ref) async* {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    yield const <Project>[];
    return;
  }
  final repo = ref.watch(projectRepositoryProvider);
  final workspaceId = await repo.ensureDefaultWorkspace(user.id);
  yield* repo.watchActiveProjects(workspaceId);
});

final screenshotTasksProvider =
    StreamProvider.family<List<Task>, String?>((ref, projectId) {
  if (projectId == null) {
    return Stream.value(const <Task>[]);
  }
  return ref.watch(projectRepositoryProvider).watchTasks(projectId);
});

final screenshotBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, screenshotId) async {
  final rows = await ref.watch(screenshotsProvider.future);
  Screenshot? row;
  for (final item in rows) {
    if (item.id == screenshotId) {
      row = item;
      break;
    }
  }
  if (row == null) return null;
  return ref.read(screenshotStoreProvider).readDecrypted(row);
});

class ScreenshotsScreen extends ConsumerWidget {
  const ScreenshotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shots = ref.watch(screenshotsProvider);
    final filter = ref.watch(screenshotFilterProvider);
    final days = ref.watch(screenshotDaysProvider);
    final projects = ref.watch(screenshotProjectsProvider);
    final tasks = ref.watch(screenshotTasksProvider(filter.projectId));
    final isRunning = ref.watch(
      trackingControllerProvider.select((s) => s.status.isRunning),
    );
    final theme = Theme.of(context);
    final dayLabel = DateFormat('EEE, MMM d');

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Encrypted local captures. Filter by day, project, or task.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: isRunning
                        ? () => ref
                            .read(trackingControllerProvider.notifier)
                            .captureTestScreenshot()
                        : null,
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Test capture'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              WitrackSurface(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      child: days.when(
                        skipLoadingOnReload: true,
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (list) {
                          final options = <String?>[
                            null,
                            if (filter.day != null && !list.contains(filter.day))
                              filter.day,
                            ...list,
                          ];
                          return DropdownButtonFormField<String?>(
                            key: ValueKey('day-${filter.day}'),
                            initialValue: filter.day,
                            decoration: const InputDecoration(
                              labelText: 'Day',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final day in options)
                                DropdownMenuItem(
                                  value: day,
                                  child: Text(
                                    day == null
                                        ? 'All days'
                                        : dayLabel.format(DateTime.parse(day)),
                                  ),
                                ),
                            ],
                            onChanged: (v) => ref
                                .read(screenshotFilterProvider.notifier)
                                .setDay(v),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: projects.when(
                        skipLoadingOnReload: true,
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (list) {
                          final ids = list.map((p) => p.id).toSet();
                          final safeProjectId =
                              ids.contains(filter.projectId)
                                  ? filter.projectId
                                  : null;
                          if (filter.projectId != null &&
                              safeProjectId == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref
                                  .read(screenshotFilterProvider.notifier)
                                  .clearProjectIfMissing(ids);
                            });
                          }
                          return DropdownButtonFormField<String?>(
                            key: ValueKey('project-$safeProjectId'),
                            initialValue: safeProjectId,
                            decoration: const InputDecoration(
                              labelText: 'Project',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All projects'),
                              ),
                              for (final project in list)
                                DropdownMenuItem(
                                  value: project.id,
                                  child: Text(project.name),
                                ),
                            ],
                            onChanged: (v) => ref
                                .read(screenshotFilterProvider.notifier)
                                .setProject(v),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: tasks.when(
                        skipLoadingOnReload: true,
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (list) {
                          final ids = list.map((t) => t.id).toSet();
                          final safeTaskId =
                              ids.contains(filter.taskId) ? filter.taskId : null;
                          if (filter.taskId != null && safeTaskId == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref
                                  .read(screenshotFilterProvider.notifier)
                                  .clearTaskIfMissing(ids);
                            });
                          }
                          return DropdownButtonFormField<String?>(
                            key: ValueKey(
                              'task-${filter.projectId}-$safeTaskId',
                            ),
                            initialValue: safeTaskId,
                            decoration: const InputDecoration(
                              labelText: 'Task',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All tasks'),
                              ),
                              for (final task in list)
                                DropdownMenuItem(
                                  value: task.id,
                                  child: Text(task.name),
                                ),
                            ],
                            onChanged: filter.projectId == null
                                ? null
                                : (v) => ref
                                    .read(screenshotFilterProvider.notifier)
                                    .setTask(v),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: shots.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  data: (rows) {
                    if (rows.isEmpty) {
                      return WitrackSurface(
                        child: Center(
                          child: Text(
                            'No screenshots for this filter. '
                            'Start tracking or use Test capture.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }
                    final scores = rows
                        .map(
                          (r) =>
                              ScreenshotProductivity.tryParse(r.metadataJson),
                        )
                        .toList();
                    final avg = ScreenshotProductivity.averagePercent(scores);
                    final scored = scores.whereType<ScreenshotProductivity>();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (scored.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProductivitySummaryCard(
                              percent: avg,
                              shotCount: scored.length,
                              label: filter.taskId != null
                                  ? 'Task productivity'
                                  : 'Filter productivity',
                            ),
                          ),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.92,
                            ),
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              return _ScreenshotCard(row: rows[index]);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Failed to load screenshots: $e'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenshotCard extends ConsumerWidget {
  const _ScreenshotCard({required this.row});

  final Screenshot row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bytes = ref.watch(screenshotBytesProvider(row.id));
    final prod = ScreenshotProductivity.tryParse(row.metadataJson);
    final percent = prod?.percent ?? 0;

    return WitrackSurface(
      padding: const EdgeInsets.all(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetail(context, ref, prod),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: bytes.when(
                  skipLoadingOnReload: true,
                  loading: () => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Text(
                        'Unavailable',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  data: (data) {
                    if (data == null) {
                      return ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Text(
                            'Unavailable',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      );
                    }
                    return Image.memory(
                      data,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMM d · HH:mm:ss').format(row.takenAt.toLocal()),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (prod != null)
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (prod != null) ...[
              _ProductivityBar(percent: percent, height: 7),
              const SizedBox(height: 6),
            ],
            Text(
              'Display ${row.displayIndex + 1}'
              '${row.isTestCapture ? ' · test' : ''}'
              '${prod != null ? ' · ${prod.appSwitches} switches' : ''}',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    ScreenshotProductivity? prod,
  ) async {
    final bytes = await ref.read(screenshotBytesProvider(row.id).future);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final timeFmt = DateFormat('HH:mm:ss');
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 740),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Screenshot detail',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: bytes == null
                              ? Center(
                                  child: Text(
                                    'Image unavailable',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: InteractiveViewer(
                                    child: Image.memory(
                                      bytes,
                                      gaplessPlayback: true,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: WitrackSurface(
                            padding: const EdgeInsets.all(12),
                            child: prod == null
                                ? Text(
                                    'No productivity data on this capture yet. '
                                    'New screenshots include interval scores and events.',
                                    style: theme.textTheme.bodyMedium,
                                  )
                                : ListView(
                                    children: [
                                      Text(
                                        '${prod.percent.toStringAsFixed(0)}% productive',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _ProductivityBar(
                                        percent: prod.percent,
                                        height: 10,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Since previous shot (or session start). '
                                        'Based on 10s activity samples — not key content.',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 12),
                                      _StatLine(
                                        label: 'Input activity pulses',
                                        value: '${prod.inputPulses}',
                                      ),
                                      _StatLine(
                                        label: 'Activity samples',
                                        value:
                                            '${prod.activeSamples}/${prod.totalSamples} active',
                                      ),
                                      _StatLine(
                                        label: 'App / focus switches',
                                        value: '${prod.appSwitches}',
                                      ),
                                      _StatLine(
                                        label: 'Idle enters',
                                        value: '${prod.idleEnters}',
                                      ),
                                      if (prod.apps.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          'Apps in interval',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 6),
                                        for (final app in prod.apps.take(8))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              '${app.name} · ${app.count}×',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ),
                                      ],
                                      const SizedBox(height: 12),
                                      Text(
                                        'Events',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 6),
                                      if (prod.events.isEmpty)
                                        Text(
                                          'No discrete events in this window.',
                                          style: theme.textTheme.bodySmall,
                                        )
                                      else
                                        for (final event in prod.events.reversed)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  width: 54,
                                                  child: Text(
                                                    timeFmt.format(
                                                      event.at.toLocal(),
                                                    ),
                                                    style: theme
                                                        .textTheme.labelSmall,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    event.label == null ||
                                                            event.label!
                                                                .isEmpty
                                                        ? event.title
                                                        : '${event.title}: ${event.label}',
                                                    style: theme
                                                        .textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductivitySummaryCard extends StatelessWidget {
  const _ProductivitySummaryCard({
    required this.percent,
    required this.shotCount,
    required this.label,
  });

  final double percent;
  final int shotCount;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WitrackSurface(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Average across $shotCount screenshot${shotCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _ProductivityBar(percent: percent, height: 10),
        ],
      ),
    );
  }
}

class _ProductivityBar extends StatelessWidget {
  const _ProductivityBar({
    required this.percent,
    this.height = 8,
  });

  final double percent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (percent.clamp(0, 100) / 100).toDouble();
    final fill = theme.colorScheme.primary;
    final track = theme.colorScheme.surfaceContainerHighest;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track.withValues(alpha: 0.9)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      fill,
                      Color.lerp(fill, theme.colorScheme.secondary, 0.35)!,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
