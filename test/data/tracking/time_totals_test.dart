import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/tracking/time_totals.dart';

TrackingSession _session({
  required String id,
  required DateTime startedAt,
  required int activeMs,
  String? projectId,
  String? taskId,
}) {
  return TrackingSession(
    id: id,
    userId: 'u1',
    workspaceId: 'w1',
    projectId: projectId,
    taskId: taskId,
    state: 'completed',
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(milliseconds: activeMs)),
    activeMs: activeMs,
    idleMs: 0,
    pausedMs: 0,
    isManual: false,
    note: null,
  );
}

void main() {
  final day = DateTime(2026, 11, 12);
  final project = Project(
    id: 'p1',
    workspaceId: 'w1',
    clientId: null,
    name: 'Alpha',
    color: '#000',
    archived: false,
    createdAt: day,
  );
  final task = Task(
    id: 't1',
    projectId: 'p1',
    name: 'Write',
    notes: null,
    status: 'open',
    archived: false,
    createdAt: day,
  );

  test('day tree buckets project and task; excludes live session id', () {
    final liveId = 'live';
    final sessions = [
      _session(
        id: 's1',
        startedAt: DateTime(2026, 11, 12, 9).toUtc(),
        activeMs: 60_000,
        projectId: 'p1',
        taskId: 't1',
      ),
      _session(
        id: liveId,
        startedAt: DateTime(2026, 11, 12, 10).toUtc(),
        activeMs: 999_999,
        projectId: 'p1',
        taskId: 't1',
      ),
    ];

    final tree = buildDayTimeTree(
      localDay: day,
      sessions: sessions,
      projects: [project],
      tasksByProject: {
        'p1': [task],
      },
      excludeSessionId: liveId,
      includeUnassignedTaskRows: false,
    );

    expect(tree.day.total, const Duration(minutes: 1));
    expect(tree.projects.single.totals.total, const Duration(minutes: 1));
    expect(tree.projects.single.tasks.single.totals.total,
        const Duration(minutes: 1));
  });

  test('unassigned task rows are omitted by default', () {
    final sessions = [
      _session(
        id: 's2',
        startedAt: DateTime(2026, 11, 12, 11).toUtc(),
        activeMs: 30_000,
        projectId: 'p1',
        taskId: null,
      ),
    ];
    final tree = buildDayTimeTree(
      localDay: day,
      sessions: sessions,
      projects: [project],
      tasksByProject: {
        'p1': [task],
      },
    );
    expect(tree.projects.single.tasks.every((t) => t.taskId != null), isTrue);
    expect(tree.projects.single.totals.total, const Duration(seconds: 30));
  });
}
