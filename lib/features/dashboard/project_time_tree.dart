import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/core/config/feature_toggles.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/data/tracking/time_totals.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/projects/project_dialogs.dart';
import 'package:witrack/features/tracking/tracking_confirm.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

final todaySessionsProvider = StreamProvider<List<TrackingSession>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return Stream.value(const []);
  return ref.watch(sessionRepositoryProvider).watchSessionsForLocalDay(
        userId: user.id,
        localDay: DateTime.now(),
      );
});

final projectsProvider =
    StreamProvider.family<List<Project>, String>((ref, workspaceId) {
  return ref.watch(projectRepositoryProvider).watchActiveProjects(workspaceId);
});

final tasksProvider =
    StreamProvider.family<List<Task>, String>((ref, projectId) {
  return ref.watch(projectRepositoryProvider).watchTasks(projectId);
});

final completedTasksProvider =
    StreamProvider.family<List<Task>, String>((ref, projectId) {
  return ref.watch(projectRepositoryProvider).watchCompletedTasks(projectId);
});

class CompletedTodayRow {
  const CompletedTodayRow({
    required this.projectId,
    required this.projectName,
    required this.taskId,
    required this.taskName,
    required this.total,
  });

  final String projectId;
  final String projectName;
  final String taskId;
  final String taskName;
  final Duration total;
}

/// Finished tasks for today — locked times (separate from active open list).
final completedTodayProvider = Provider<List<CompletedTodayRow>>((ref) {
  final workspaceId = ref.watch(
    trackingControllerProvider.select((s) => s.workspaceId),
  );
  if (workspaceId == null) return const [];

  final projects =
      ref.watch(projectsProvider(workspaceId)).asData?.value ?? const [];
  final sessions = ref.watch(todaySessionsProvider).asData?.value ?? const [];
  final start = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final end = start.add(const Duration(days: 1));

  Duration taskTotal(String taskId) {
    var sum = Duration.zero;
    for (final s in sessions) {
      if (s.taskId != taskId) continue;
      final started = s.startedAt.toLocal();
      if (started.isBefore(start) || !started.isBefore(end)) continue;
      sum += Duration(
        milliseconds: s.activeMs + s.idleMs + s.pausedMs,
      );
    }
    return sum;
  }

  final rows = <CompletedTodayRow>[];
  for (final project in projects) {
    final completed =
        ref.watch(completedTasksProvider(project.id)).asData?.value ??
            const <Task>[];
    for (final task in completed) {
      rows.add(
        CompletedTodayRow(
          projectId: project.id,
          projectName: project.name,
          taskId: task.id,
          taskName: task.name,
          total: taskTotal(task.id),
        ),
      );
    }
  }
  rows.sort((a, b) => b.total.compareTo(a.total));
  return rows;
});

/// Closed/persisted day totals only — does not tick every second (no blink).
final dayTimeTreeBaseProvider = Provider<DayTimeTree>((ref) {
  final workspaceId = ref.watch(
    trackingControllerProvider.select((s) => s.workspaceId),
  );
  final liveSessionId = ref.watch(
    trackingControllerProvider.select((s) => s.sessionId),
  );
  final liveStatus = ref.watch(
    trackingControllerProvider.select((s) => s.status),
  );
  final open = liveStatus == TrackingStatus.tracking ||
      liveStatus == TrackingStatus.idle ||
      liveStatus == TrackingStatus.paused;

  final sessions = ref.watch(todaySessionsProvider).asData?.value ?? const [];
  final projects = workspaceId == null
      ? const <Project>[]
      : (ref.watch(projectsProvider(workspaceId)).asData?.value ??
          const <Project>[]);

  final tasksByProject = <String, List<Task>>{
    for (final p in projects)
      p.id: ref.watch(tasksProvider(p.id)).asData?.value ?? const <Task>[],
  };

  return buildDayTimeTree(
    localDay: DateTime.now(),
    sessions: sessions,
    projects: projects,
    tasksByProject: tasksByProject,
    excludeSessionId: open ? liveSessionId : null,
    includeUnassignedTaskRows: false,
  );
});

/// @deprecated Prefer [dayTimeTreeBaseProvider] + live clock widgets.
final dayTimeTreeProvider = dayTimeTreeBaseProvider;

class BrowseProjectController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? projectId) => state = projectId;
}

/// Project highlighted in the tasks pane (browse). Live timer follows task clicks only.
final browseProjectIdProvider =
    NotifierProvider<BrowseProjectController, String?>(
  BrowseProjectController.new,
);

class ProjectTimeTreePanel extends ConsumerWidget {
  const ProjectTimeTreePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workspaceId = ref.watch(
      trackingControllerProvider.select((s) => s.workspaceId),
    );
    final liveProject = ref.watch(
      trackingControllerProvider.select((s) => s.projectId),
    );
    final selectedTask = ref.watch(
      trackingControllerProvider.select((s) => s.taskId),
    );
    final status = ref.watch(
      trackingControllerProvider.select((s) => s.status),
    );
    final open = status == TrackingStatus.tracking ||
        status == TrackingStatus.idle ||
        status == TrackingStatus.paused;
    final browseProject =
        ref.watch(browseProjectIdProvider) ?? liveProject;

    final tree = ref.watch(dayTimeTreeBaseProvider);
    final completed = ref.watch(completedTodayProvider);
    ProjectTimeNode? selectedNode;
    for (final p in tree.projects) {
      if (p.projectId == browseProject) {
        selectedNode = p;
        break;
      }
    }
    selectedNode ??= tree.projects.isEmpty ? null : tree.projects.first;

    return WitrackSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today · day tracker',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              _LiveDayClock(base: tree.day.total),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            open
                ? 'Click a task to switch (you’ll be asked) · project only browses'
                : 'Create a project and task, then click the task to start',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: workspaceId == null
                    ? null
                    : () => showCreateProjectDialog(
                          context,
                          ref,
                          workspaceId: workspaceId,
                        ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Project'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: browseProject == null
                    ? null
                    : () => showCreateTaskDialog(
                          context,
                          ref,
                          projectId: browseProject,
                        ),
                icon: const Icon(Icons.add_task_outlined, size: 16),
                label: const Text('Task'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tree.projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No projects yet',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a project, then add a task. Start Tracking enables only after a task is selected.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Pane(
                      title: 'Projects',
                      child: ListView.builder(
                        itemCount: tree.projects.length,
                        itemBuilder: (context, i) {
                          final project = tree.projects[i];
                          final selected =
                              browseProject == project.projectId;
                          final trackingHere =
                              open && liveProject == project.projectId;
                          return _QuietRow(
                            label: project.name,
                            selected: selected,
                            trackingHere: trackingHere,
                            base: project.totals.total,
                            liveHere: trackingHere,
                            onTap: () => _onProjectTap(ref, project, open: open),
                            menuItems: const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete project'),
                              ),
                            ],
                            onMenuSelected: (value) {
                              if (value == 'delete') {
                                _deleteProject(
                                  context,
                                  ref,
                                  project.projectId,
                                  project.name,
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final node = selectedNode;
                        if (node == null) {
                          return _Pane(
                            title: 'Tasks',
                            child: Center(
                              child: Text(
                                'Select a project',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          );
                        }
                        return _Pane(
                          title: 'Tasks · ${node.name}',
                          child: node.tasks.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'No tasks in this project. Create a task, then click it to start.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                )
                              : ListView.builder(
                            itemCount: node.tasks.length,
                            itemBuilder: (context, i) {
                              final task = node.tasks[i];
                              final selected =
                                  liveProject == node.projectId &&
                                      selectedTask == task.taskId;
                              final taskId = task.taskId;
                              if (taskId == null) {
                                return const SizedBox.shrink();
                              }
                              return _QuietRow(
                                label: task.name,
                                selected: selected,
                                trackingHere: open && selected,
                                base: task.totals.total,
                                liveHere: open && selected,
                                onTap: () => _onTaskTap(
                                  context,
                                  ref,
                                  projectId: node.projectId,
                                  projectName: node.name,
                                  taskId: taskId,
                                  taskName: task.name,
                                ),
                                menuItems: const [
                                  PopupMenuItem(
                                    value: 'complete',
                                    child: Text('Mark completed'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete task'),
                                  ),
                                ],
                                onMenuSelected: (value) {
                                  if (value == 'complete') {
                                    _completeTask(
                                      context,
                                      ref,
                                      taskId,
                                      task.name,
                                    );
                                  } else if (value == 'delete') {
                                    _deleteTask(
                                      context,
                                      ref,
                                      taskId,
                                      task.name,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (ref.watch(featureTogglesProvider).isOn(FeatureId.completedList) &&
              completed.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Completed today',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Previous timers locked after mark completed — day total still includes them',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final row in completed)
              _CompletedRow(
                row: row,
                onReopen: () => _reopenTask(context, ref, row),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _onProjectTap(
    WidgetRef ref,
    ProjectTimeNode project, {
    required bool open,
  }) async {
    ref.read(browseProjectIdProvider.notifier).select(project.projectId);
    // Never start or resegment from project click.
    if (open) return;
    ref.read(trackingControllerProvider.notifier).selectProjectOnly(
          projectId: project.projectId,
          projectName: project.name,
        );
  }

  Future<void> _onTaskTap(
    BuildContext context,
    WidgetRef ref, {
    required String projectId,
    required String projectName,
    required String taskId,
    required String taskName,
  }) async {
    ref.read(browseProjectIdProvider.notifier).select(projectId);
    final live = ref.read(trackingControllerProvider);
    final same = live.projectId == projectId && live.taskId == taskId;
    if (same && timerIsOpen(live)) return;

    final ok = await confirmTaskFocusIfNeeded(
      context: context,
      ref: ref,
      nextProjectName: projectName,
      nextTaskName: taskName,
    );
    if (!ok || !context.mounted) return;

    await ref.read(trackingControllerProvider.notifier).focusWork(
          projectId: projectId,
          projectName: projectName,
          taskId: taskId,
          taskName: taskName,
          startIfStopped: true,
        );
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    String projectId,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          '“$name” and its tasks leave the active list. '
          'Past day time stays in Today (all work). '
          'If a timer is running, you will be asked to stop it first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final stopped = await confirmAndStopOpenTimer(
      context: context,
      ref: ref,
      actionLabel: 'delete this project',
    );
    if (!stopped || !context.mounted) return;
    final tracking = ref.read(trackingControllerProvider.notifier);
    await ref.read(projectRepositoryProvider).archiveProject(projectId);
    await tracking.retargetAfterProjectGone(projectId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $name')),
      );
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          '“$name” leaves the active list. Past time stays on Today (all work). '
          'If a timer is running, you will be asked to stop it first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final stopped = await confirmAndStopOpenTimer(
      context: context,
      ref: ref,
      actionLabel: 'delete this task',
    );
    if (!stopped || !context.mounted) return;
    final tracking = ref.read(trackingControllerProvider.notifier);
    await ref.read(projectRepositoryProvider).archiveTask(taskId);
    await tracking.retargetAfterTaskGone(taskId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $name')),
      );
    }
  }

  Future<void> _completeTask(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    String name,
  ) async {
    final stopped = await confirmAndStopOpenTimer(
      context: context,
      ref: ref,
      actionLabel: 'mark this task completed',
    );
    if (!stopped) return;
    final tracking = ref.read(trackingControllerProvider.notifier);
    await ref.read(projectRepositoryProvider).markTaskCompleted(taskId);
    await tracking.retargetAfterTaskGone(taskId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Completed $name — moved to Completed today')),
      );
    }
  }

  Future<void> _reopenTask(
    BuildContext context,
    WidgetRef ref,
    CompletedTodayRow row,
  ) async {
    await ref.read(projectRepositoryProvider).reopenTask(row.taskId);
    await ref.read(trackingControllerProvider.notifier).focusWork(
          projectId: row.projectId,
          projectName: row.projectName,
          taskId: row.taskId,
          taskName: row.taskName,
          startIfStopped: false,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reopened ${row.taskName}')),
      );
    }
  }
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.row, required this.onReopen});

  final CompletedTodayRow row;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${row.projectName} · ${row.taskName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            formatClock(row.total),
            style: theme.textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onReopen,
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Stable row chrome — selection is a left bar, not a glowing border rebuild.
class _QuietRow extends StatelessWidget {
  const _QuietRow({
    required this.label,
    required this.selected,
    required this.trackingHere,
    required this.base,
    required this.liveHere,
    required this.onTap,
    this.menuItems = const [],
    this.onMenuSelected,
  });

  final String label;
  final bool selected;
  final bool trackingHere;
  final Duration base;
  final bool liveHere;
  final VoidCallback onTap;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String>? onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
              : null,
          border: Border(
            left: BorderSide(
              width: 3,
              color: selected ? accent : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              trackingHere ? Icons.play_arrow_rounded : Icons.circle_outlined,
              size: 16,
              color: trackingHere
                  ? accent
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            _LiveSegmentClock(base: base, liveHere: liveHere),
            if (menuItems.isNotEmpty)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                tooltip: 'Actions',
                onSelected: onMenuSelected,
                itemBuilder: (context) => menuItems,
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveDayClock extends ConsumerWidget {
  const _LiveDayClock({required this.base});

  final Duration base;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(
      trackingControllerProvider.select(
        (s) =>
            s.status == TrackingStatus.tracking ||
            s.status == TrackingStatus.idle ||
            s.status == TrackingStatus.paused,
      ),
    );
    final live = open
        ? ref.watch(trackingControllerProvider.select((s) => s.elapsed))
        : Duration.zero;
    final theme = Theme.of(context);
    return Text(
      formatClock(base + live),
      style: theme.textTheme.titleMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _LiveSegmentClock extends ConsumerWidget {
  const _LiveSegmentClock({required this.base, required this.liveHere});

  final Duration base;
  final bool liveHere;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = liveHere
        ? ref.watch(trackingControllerProvider.select((s) => s.elapsed))
        : Duration.zero;
    return Text(
      formatClock(base + live),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}
