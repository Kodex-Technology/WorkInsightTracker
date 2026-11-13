import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';

class TimelineDayController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void previous() => state = state.subtract(const Duration(days: 1));
  void next() => state = state.add(const Duration(days: 1));
  void goToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final timelineDayProvider =
    NotifierProvider<TimelineDayController, DateTime>(TimelineDayController.new);

final timelineEventsProvider = StreamProvider<List<SessionEvent>>((ref) {
  final day = ref.watch(timelineDayProvider);
  // Pass local calendar day — repository converts bounds to UTC.
  return ref.watch(sessionRepositoryProvider).watchEventsForDay(day);
});

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(timelineDayProvider);
    final events = ref.watch(timelineEventsProvider);
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sessions, app changes, and screenshot markers for the selected day.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: () =>
                        ref.read(timelineDayProvider.notifier).previous(),
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  Text(
                    DateFormat.yMMMd().format(day),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed: () =>
                        ref.read(timelineDayProvider.notifier).next(),
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () =>
                        ref.read(timelineDayProvider.notifier).goToday(),
                    child: const Text('Today'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: events.when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: true,
                    data: (rows) {
                      if (rows.isEmpty) {
                        return WitrackSurface(
                          key: ValueKey('empty-${day.toIso8601String()}'),
                          child: Center(
                            child: Text(
                              'No tracked events for this day.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        key: ValueKey('events-${day.toIso8601String()}'),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final event = rows[index];
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(
                              milliseconds: 140 + (index.clamp(0, 8) * 20),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 6),
                                child: child,
                              ),
                            ),
                            child: WitrackSurface(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _iconFor(event.type),
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _labelFor(event.type),
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        if ((event.payload ?? '').isNotEmpty)
                                          Text(
                                            event.payload!,
                                            style: theme.textTheme.bodySmall,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat.Hms()
                                        .format(event.at.toLocal()),
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      key: ValueKey('loading'),
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Text(
                      'Failed to load timeline: $e',
                      key: const ValueKey('error'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    if (type.startsWith('state:')) return Icons.flag_outlined;
    if (type == 'foreground') return Icons.apps_outlined;
    if (type.startsWith('screenshot')) return Icons.photo_outlined;
    if (type == 'started' || type == 'stopped') return Icons.timelapse;
    if (type.contains('idle')) return Icons.hourglass_empty;
    if (type.contains('pause')) return Icons.pause_circle_outline;
    return Icons.circle_outlined;
  }

  String _labelFor(String type) {
    if (type.startsWith('state:')) {
      return type.substring(6).replaceAll('_', ' ');
    }
    switch (type) {
      case 'foreground':
        return 'Application focus';
      case 'started':
        return 'Session started';
      case 'stopped':
        return 'Session stopped';
      default:
        if (type.startsWith('screenshot')) return 'Screenshot captured';
        return type;
    }
  }
}
