import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/tracking/time_totals.dart';

/// One local calendar day's locked totals — calendar / week / month views.
class DayProgress {
  const DayProgress({
    required this.day,
    required this.totals,
    required this.completedTaskIds,
  });

  final DateTime day;
  final TimeBucket totals;
  final Set<String> completedTaskIds;

  int get completedTaskCount => completedTaskIds.length;
}

class RangeProgress {
  const RangeProgress({
    required this.start,
    required this.endExclusive,
    required this.days,
    required this.totals,
    required this.completedTaskIds,
  });

  final DateTime start;
  final DateTime endExclusive;
  final List<DayProgress> days;
  final TimeBucket totals;
  final Set<String> completedTaskIds;

  int get completedTaskCount => completedTaskIds.length;
}

/// Build day-bucketed progress from sessions (offline-first; backend can swap source).
RangeProgress buildRangeProgress({
  required DateTime localStart,
  required DateTime localEndExclusive,
  required List<TrackingSession> sessions,
  required Set<String> completedTaskIds,
}) {
  final start = DateTime(localStart.year, localStart.month, localStart.day);
  final end = DateTime(
    localEndExclusive.year,
    localEndExclusive.month,
    localEndExclusive.day,
  );

  final byDay = <DateTime, TimeBucket>{};
  final completedByDay = <DateTime, Set<String>>{};
  var rangeTotals = const TimeBucket();
  final rangeCompleted = <String>{};

  for (final row in sessions) {
    final local = row.startedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (day.isBefore(start) || !day.isBefore(end)) continue;
    final amount = TimeBucket.fromSession(row);
    byDay[day] = (byDay[day] ?? const TimeBucket()) + amount;
    rangeTotals += amount;
    final tid = row.taskId;
    if (tid != null && completedTaskIds.contains(tid)) {
      completedByDay.putIfAbsent(day, () => <String>{}).add(tid);
      rangeCompleted.add(tid);
    }
  }

  final days = <DayProgress>[];
  for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
    days.add(
      DayProgress(
        day: d,
        totals: byDay[d] ?? const TimeBucket(),
        completedTaskIds: completedByDay[d] ?? const {},
      ),
    );
  }

  return RangeProgress(
    start: start,
    endExclusive: end,
    days: days,
    totals: rangeTotals,
    completedTaskIds: rangeCompleted,
  );
}

DateTime startOfWeek(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  // Monday-start week (office reporting).
  final weekday = d.weekday; // 1=Mon … 7=Sun
  return d.subtract(Duration(days: weekday - 1));
}

DateTime startOfMonth(DateTime day) => DateTime(day.year, day.month, 1);
