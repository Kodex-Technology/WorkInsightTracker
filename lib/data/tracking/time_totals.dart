import 'package:witrack/data/database/app_database.dart';

/// Aggregated active/idle/paused — future sync can map the same shape from API.
class TimeBucket {
  const TimeBucket({
    this.active = Duration.zero,
    this.idle = Duration.zero,
    this.paused = Duration.zero,
  });

  final Duration active;
  final Duration idle;
  final Duration paused;

  Duration get total => active + idle + paused;

  TimeBucket operator +(TimeBucket other) => TimeBucket(
        active: active + other.active,
        idle: idle + other.idle,
        paused: paused + other.paused,
      );

  static TimeBucket fromSession(TrackingSession row) => TimeBucket(
        active: Duration(milliseconds: row.activeMs),
        idle: Duration(milliseconds: row.idleMs),
        paused: Duration(milliseconds: row.pausedMs),
      );
}

class TaskTimeNode {
  const TaskTimeNode({
    required this.taskId,
    required this.name,
    required this.totals,
  });

  /// Null means sessions with no task on this project.
  final String? taskId;
  final String name;
  final TimeBucket totals;
}

class ProjectTimeNode {
  const ProjectTimeNode({
    required this.projectId,
    required this.name,
    required this.totals,
    required this.tasks,
  });

  final String projectId;
  final String name;
  final TimeBucket totals;
  final List<TaskTimeNode> tasks;
}

class DayTimeTree {
  const DayTimeTree({
    required this.day,
    required this.projects,
    required this.localDay,
  });

  final DateTime localDay;
  final TimeBucket day;
  final List<ProjectTimeNode> projects;
}

/// Build day → project → task tree from persisted sessions.
///
/// Pass [excludeSessionId] for the open live segment so UI clocks can add
/// live elapsed without double-counting (and without rebuilding every second).
DayTimeTree buildDayTimeTree({
  required DateTime localDay,
  required List<TrackingSession> sessions,
  required List<Project> projects,
  required Map<String, List<Task>> tasksByProject,
  String? excludeSessionId,
  bool includeUnassignedTaskRows = false,
}) {
  final start = DateTime(localDay.year, localDay.month, localDay.day);
  final end = start.add(const Duration(days: 1));

  final buckets = <String, TimeBucket>{}; // key: projectId or projectId|taskId
  var day = const TimeBucket();

  TimeBucket add(TimeBucket a, TimeBucket b) => a + b;

  void accumulate(TrackingSession row, TimeBucket amount) {
    day = add(day, amount);
    final pid = row.projectId;
    if (pid == null || pid.isEmpty) return;
    buckets[pid] = add(buckets[pid] ?? const TimeBucket(), amount);
    final tid = row.taskId;
    final taskKey = '$pid|${tid ?? ''}';
    buckets[taskKey] = add(buckets[taskKey] ?? const TimeBucket(), amount);
  }

  for (final row in sessions) {
    if (excludeSessionId != null && row.id == excludeSessionId) continue;
    final started = row.startedAt.toLocal();
    if (started.isBefore(start) || !started.isBefore(end)) continue;
    accumulate(row, TimeBucket.fromSession(row));
  }

  final projectNodes = <ProjectTimeNode>[];
  for (final project in projects) {
    final pTotals = buckets[project.id] ?? const TimeBucket();
    final tasks = tasksByProject[project.id] ?? const <Task>[];
    final taskNodes = <TaskTimeNode>[
      for (final task in tasks)
        TaskTimeNode(
          taskId: task.id,
          name: task.name,
          totals: buckets['${project.id}|${task.id}'] ?? const TimeBucket(),
        ),
    ];
    if (includeUnassignedTaskRows) {
      final unassigned = buckets['${project.id}|'];
      if (unassigned != null && unassigned.total > Duration.zero) {
        taskNodes.add(
          TaskTimeNode(
            taskId: null,
            name: 'No task',
            totals: unassigned,
          ),
        );
      }
    }
    projectNodes.add(
      ProjectTimeNode(
        projectId: project.id,
        name: project.name,
        totals: pTotals,
        tasks: taskNodes,
      ),
    );
  }

  return DayTimeTree(day: day, projects: projectNodes, localDay: start);
}

String formatCompact(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) {
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
  if (m > 0) {
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
  return '${s}s';
}

String formatClock(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
