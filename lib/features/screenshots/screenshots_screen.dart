import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/data/screenshots/screenshot_store.dart';
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
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        return _ScreenshotCard(row: rows[index]);
                      },
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

    return WitrackSurface(
      padding: const EdgeInsets.all(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openPreview(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: bytes.when(
                skipLoadingOnReload: true,
                loading: () => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => Center(
                  child: Text(
                    'Unavailable',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                data: (data) {
                  if (data == null) {
                    return Center(
                      child: Text(
                        'Unavailable',
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      data,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      gaplessPlayback: true,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d · HH:mm:ss').format(row.takenAt.toLocal()),
              style: theme.textTheme.labelLarge,
            ),
            Text(
              'Display ${row.displayIndex + 1}${row.isTestCapture ? ' · test' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPreview(BuildContext context, WidgetRef ref) async {
    final bytes = await ref.read(screenshotBytesProvider(row.id).future);
    if (!context.mounted || bytes == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.memory(bytes, gaplessPlayback: true),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
