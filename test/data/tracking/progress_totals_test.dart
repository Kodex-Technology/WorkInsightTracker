import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/tracking/progress_totals.dart';

TrackingSession _s(DateTime localStart, int ms, {String? taskId}) {
  return TrackingSession(
    id: localStart.toIso8601String(),
    userId: 'u1',
    workspaceId: 'w1',
    projectId: 'p1',
    taskId: taskId,
    state: 'completed',
    startedAt: localStart.toUtc(),
    endedAt: localStart.add(Duration(milliseconds: ms)).toUtc(),
    activeMs: ms,
    idleMs: 0,
    pausedMs: 0,
    isManual: false,
    note: null,
  );
}

void main() {
  test('week range buckets days and completed task ids', () {
    final start = DateTime(2026, 11, 10); // Monday
    final end = start.add(const Duration(days: 7));
    final sessions = [
      _s(DateTime(2026, 11, 10, 9), 60_000, taskId: 'done1'),
      _s(DateTime(2026, 11, 12, 9), 120_000, taskId: 'open1'),
      _s(DateTime(2026, 11, 12, 14), 30_000, taskId: 'done1'),
    ];

    final range = buildRangeProgress(
      localStart: start,
      localEndExclusive: end,
      sessions: sessions,
      completedTaskIds: {'done1'},
    );

    expect(range.days.length, 7);
    expect(range.totals.total, const Duration(milliseconds: 210_000));
    expect(range.completedTaskIds, {'done1'});
    final wed = range.days.firstWhere((d) => d.day.day == 12);
    expect(wed.totals.total, const Duration(milliseconds: 150_000));
    expect(wed.completedTaskIds, {'done1'});
  });

  test('startOfWeek is Monday', () {
    final sun = DateTime(2026, 11, 15); // Sunday
    expect(startOfWeek(sun), DateTime(2026, 11, 9));
  });
}
