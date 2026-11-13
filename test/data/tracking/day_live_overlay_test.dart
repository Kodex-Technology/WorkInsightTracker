import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/tracking/time_totals.dart';

/// Production rule: day total = closed sessions + live elapsed (never double-count).
void main() {
  test('exclude open session then add live elapsed once', () {
    final day = DateTime(2026, 11, 12);
    final project = Project(
      id: 'p1',
      workspaceId: 'w1',
      clientId: null,
      name: 'P',
      color: '#111',
      archived: false,
      createdAt: day,
    );
    final task = Task(
      id: 't1',
      projectId: 'p1',
      name: 'T',
      notes: null,
      status: 'open',
      archived: false,
      createdAt: day,
    );

    final closed = TrackingSession(
      id: 'closed',
      userId: 'u1',
      workspaceId: 'w1',
      projectId: 'p1',
      taskId: 't1',
      state: 'completed',
      startedAt: DateTime(2026, 11, 12, 8).toUtc(),
      endedAt: DateTime(2026, 11, 12, 9).toUtc(),
      activeMs: 3_600_000,
      idleMs: 0,
      pausedMs: 0,
      isManual: false,
      note: null,
    );
    final open = TrackingSession(
      id: 'open',
      userId: 'u1',
      workspaceId: 'w1',
      projectId: 'p1',
      taskId: 't1',
      state: 'tracking',
      startedAt: DateTime(2026, 11, 12, 10).toUtc(),
      endedAt: null,
      activeMs: 999_999, // stale DB value must be ignored via exclude
      idleMs: 0,
      pausedMs: 0,
      isManual: false,
      note: null,
    );

    final base = buildDayTimeTree(
      localDay: day,
      sessions: [closed, open],
      projects: [project],
      tasksByProject: {
        'p1': [task],
      },
      excludeSessionId: 'open',
    );

    const liveElapsed = Duration(minutes: 5);
    final today = base.day.total + liveElapsed;

    expect(base.day.total, const Duration(hours: 1));
    expect(today, const Duration(hours: 1, minutes: 5));
  });
}
