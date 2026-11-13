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

  /// Projects column kept in code but hidden in dashboard UI for a cleaner layout.
  static const bool showProjectsColumn = false;

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

    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;

    return WitrackSurface(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      open
                          ? 'Click a task to switch — you’ll confirm first'
                          : 'Click a task to start · same as Start',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              _LiveDayClock(base: tree.day.total),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!showProjectsColumn && tree.projects.isNotEmpty) ...[
                _ProjectPickerChip(
                  projects: tree.projects,
                  selected: selectedNode,
                  liveProjectId: liveProject,
                  open: open,
                  onSelected: (project) =>
                      _onProjectTap(ref, project, open: open),
                  onDelete: (project) => _deleteProject(
                    context,
                    ref,
                    project.projectId,
                    project.name,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              _TinyAction(
                icon: Icons.create_new_folder_outlined,
                label: 'Project',
                onPressed: workspaceId == null
                    ? null
                    : () => showCreateProjectDialog(
                          context,
                          ref,
                          workspaceId: workspaceId,
                        ),
              ),
              const SizedBox(width: 8),
              _TinyAction(
                icon: Icons.add_task_outlined,
                label: 'Task',
                filled: true,
                onPressed: browseProject == null
                    ? null
                    : () => showCreateTaskDialog(
                          context,
                          ref,
                          projectId: browseProject,
                        ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tree.projects.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark
                    ? const Color(0xFF0A1C2A)
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No projects yet',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a project, add a task, then click the task to start.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 248,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showProjectsColumn) ...[
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
                              onTap: () =>
                                  _onProjectTap(ref, project, open: open),
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
                  ],
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
                          title: 'Tasks',
                          trailing: Text(
                            node.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: node.tasks.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(
                                    'No tasks yet. Add a task, then click it to start.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
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
            const SizedBox(height: 16),
            Text(
              'Completed today',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Locked after mark completed — day total still includes them',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 10),
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

class _ProjectPickerChip extends StatelessWidget {
  const _ProjectPickerChip({
    required this.projects,
    required this.selected,
    required this.liveProjectId,
    required this.open,
    required this.onSelected,
    required this.onDelete,
  });

  final List<ProjectTimeNode> projects;
  final ProjectTimeNode? selected;
  final String? liveProjectId;
  final bool open;
  final ValueChanged<ProjectTimeNode> onSelected;
  final ValueChanged<ProjectTimeNode> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final name = selected?.name ?? 'Select project';
    final trackingHere =
        open && selected != null && liveProjectId == selected!.projectId;

    return PopupMenuButton<String>(
      tooltip: 'Switch project',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF102536) : theme.colorScheme.surface,
      onSelected: (id) {
        if (id.startsWith('del:')) {
          final projectId = id.substring(4);
          for (final p in projects) {
            if (p.projectId == projectId) {
              onDelete(p);
              return;
            }
          }
          return;
        }
        for (final p in projects) {
          if (p.projectId == id) {
            onSelected(p);
            return;
          }
        }
      },
      itemBuilder: (context) => [
        for (final project in projects)
          PopupMenuItem<String>(
            value: project.projectId,
            child: SizedBox(
              width: 260,
              child: Row(
                children: [
                  Icon(
                    open && liveProjectId == project.projectId
                        ? Icons.play_arrow_rounded
                        : Icons.folder_outlined,
                    size: 18,
                    color: selected?.projectId == project.projectId
                        ? accent
                        : muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      project.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected?.projectId == project.projectId
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatClock(project.totals.total),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (selected != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'del:${selected!.projectId}',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Text(
                  'Delete “${selected!.name}”',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 40,
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: isDark ? const Color(0xFF0E2433) : theme.colorScheme.surface,
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.95),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              trackingHere ? Icons.play_arrow_rounded : Icons.folder_outlined,
              size: 16,
              color: accent,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}

class _TinyAction extends StatelessWidget {
  const _TinyAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final enabled = onPressed != null;

    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor: enabled
              ? accent
              : theme.disabledColor.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        foregroundColor: enabled ? theme.colorScheme.onSurface : theme.disabledColor,
        side: BorderSide(
          color: enabled
              ? theme.dividerColor.withValues(alpha: 0.95)
              : theme.dividerColor.withValues(alpha: 0.45),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.row, required this.onReopen});

  final CompletedTodayRow row;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.75)),
        color: isDark
            ? const Color(0xFF0A1C2A).withValues(alpha: 0.7)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 17,
            color: theme.colorScheme.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${row.projectName} · ${row.taskName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            formatClock(row.total),
            style: theme.textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: muted,
            ),
          ),
          TextButton(
            onPressed: onReopen,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? const Color(0xFF0A1C2A)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
            child: Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.25,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing!,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.65),
          ),
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
    final muted = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: accent.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
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
                trackingHere
                    ? Icons.play_arrow_rounded
                    : Icons.play_circle_outline_rounded,
                size: 18,
                color: trackingHere ? accent : muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
