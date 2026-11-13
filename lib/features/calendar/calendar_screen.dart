import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/data/tracking/progress_totals.dart';
import 'package:witrack/data/tracking/time_totals.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/dashboard/project_time_tree.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

enum CalendarRangeMode { week, month }

class CalendarModeController extends Notifier<CalendarRangeMode> {
  @override
  CalendarRangeMode build() => CalendarRangeMode.week;

  void setMode(CalendarRangeMode mode) => state = mode;
}

class CalendarAnchorController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void setDay(DateTime day) =>
      state = DateTime(day.year, day.month, day.day);
}

final calendarModeProvider =
    NotifierProvider<CalendarModeController, CalendarRangeMode>(
  CalendarModeController.new,
);

final calendarAnchorProvider =
    NotifierProvider<CalendarAnchorController, DateTime>(
  CalendarAnchorController.new,
);

final calendarProgressProvider = FutureProvider<RangeProgress>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    final n = DateTime.now();
    return RangeProgress(
      start: n,
      endExclusive: n,
      days: const [],
      totals: const TimeBucket(),
      completedTaskIds: const {},
    );
  }

  final mode = ref.watch(calendarModeProvider);
  final anchor = ref.watch(calendarAnchorProvider);
  late final DateTime start;
  late final DateTime end;
  if (mode == CalendarRangeMode.week) {
    start = startOfWeek(anchor);
    end = start.add(const Duration(days: 7));
  } else {
    start = startOfMonth(anchor);
    end = DateTime(start.year, start.month + 1, 1);
  }

  final sessions = await ref.read(sessionRepositoryProvider).sessionsInLocalRange(
        userId: user.id,
        localStartDay: start,
        localEndDayExclusive: end,
      );

  final workspaceId = ref.watch(
    trackingControllerProvider.select((s) => s.workspaceId),
  );
  final completedIds = <String>{};
  if (workspaceId != null) {
    final projects =
        ref.watch(projectsProvider(workspaceId)).asData?.value ?? const [];
    for (final p in projects) {
      final tasks =
          ref.watch(completedTasksProvider(p.id)).asData?.value ?? const [];
      for (final t in tasks) {
        completedIds.add(t.id);
      }
    }
  }

  return buildRangeProgress(
    localStart: start,
    localEndExclusive: end,
    sessions: sessions,
    completedTaskIds: completedIds,
  );
});

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(calendarModeProvider);
    final anchor = ref.watch(calendarAnchorProvider);
    final progress = ref.watch(calendarProgressProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WitrackSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Progress calendar',
                          style: theme.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        SegmentedButton<CalendarRangeMode>(
                          segments: const [
                            ButtonSegment(
                              value: CalendarRangeMode.week,
                              label: Text('Week'),
                              icon: Icon(Icons.view_week_outlined, size: 16),
                            ),
                            ButtonSegment(
                              value: CalendarRangeMode.month,
                              label: Text('Month'),
                              icon: Icon(Icons.calendar_month_outlined, size: 16),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged: (s) {
                            ref
                                .read(calendarModeProvider.notifier)
                                .setMode(s.first);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous',
                          onPressed: () {
                            final next = mode == CalendarRangeMode.week
                                ? anchor.subtract(const Duration(days: 7))
                                : DateTime(anchor.year, anchor.month - 1, 1);
                            ref
                                .read(calendarAnchorProvider.notifier)
                                .setDay(next);
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            mode == CalendarRangeMode.week
                                ? 'Week of ${DateFormat.MMMd().format(startOfWeek(anchor))}'
                                : DateFormat.yMMMM().format(anchor),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next',
                          onPressed: () {
                            final next = mode == CalendarRangeMode.week
                                ? anchor.add(const Duration(days: 7))
                                : DateTime(anchor.year, anchor.month + 1, 1);
                            ref
                                .read(calendarAnchorProvider.notifier)
                                .setDay(next);
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(calendarAnchorProvider.notifier)
                                .setDay(DateTime.now());
                          },
                          child: const Text('Today'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              progress.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e'),
                data: (range) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Time worked',
                            value: formatClock(range.totals.total),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Active',
                            value: formatCompact(range.totals.active),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Completed tasks',
                            value: '${range.completedTaskCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    WitrackSurface(
                      child: mode == CalendarRangeMode.week
                          ? _WeekBars(days: range.days)
                          : _MonthGrid(days: range.days, month: range.start),
                    ),
                    const SizedBox(height: 12),
                    WitrackSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Day breakdown',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          for (final day in range.days)
                            if (day.totals.total > Duration.zero ||
                                day.completedTaskCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 96,
                                      child: Text(
                                        DateFormat.MMMd().format(day.day),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Worked ${formatClock(day.totals.total)} · '
                                        'Completed ${day.completedTaskCount}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          if (range.days
                              .every((d) => d.totals.total == Duration.zero))
                            Text(
                              'No tracked time in this range yet.',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
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
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WitrackSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<DayProgress> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = days.fold<int>(
      1,
      (m, d) => d.totals.total.inMilliseconds > m
          ? d.totals.total.inMilliseconds
          : m,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Week progress', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          formatCompact(day.totals.total),
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: (day.totals.total.inMilliseconds /
                                    maxMs)
                                .clamp(0.04, 1.0),
                            widthFactor: 1,
                            alignment: Alignment.bottomCenter,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.E().format(day.day),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.days, required this.month});

  final List<DayProgress> days;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1;
    final cells = <DayProgress?>[
      ...List<DayProgress?>.filled(leading, null),
      ...days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Month progress', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < cells.length; r += 7)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _MonthCell(day: cells[r + c])),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({required this.day});

  final DayProgress? day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (day == null) {
      return const SizedBox(height: 54);
    }
    final hasWork = day!.totals.total > Duration.zero;
    final today = DateTime.now();
    final isToday = day!.day.year == today.year &&
        day!.day.month == today.month &&
        day!.day.day == today.day;
    return Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday
              ? theme.colorScheme.primary
              : theme.dividerColor.withValues(alpha: 0.6),
        ),
        color: hasWork
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day!.day.day}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            hasWork ? formatCompact(day!.totals.total) : '—',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
