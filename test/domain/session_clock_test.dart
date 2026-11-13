import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/domain/tracking/session_clock.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';

void main() {
  group('SessionClock production accrual', () {
    test('pause stops active accrual and resume continues separately', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);
      clock.start(t0);

      clock.tick(t0.add(const Duration(seconds: 10)));
      expect(clock.active, const Duration(seconds: 10));

      clock.transition(
        TrackingStatus.paused,
        t0.add(const Duration(seconds: 10)),
      );
      clock.tick(t0.add(const Duration(seconds: 25)));
      expect(clock.active, const Duration(seconds: 10));
      expect(clock.paused, const Duration(seconds: 15));

      clock.transition(
        TrackingStatus.tracking,
        t0.add(const Duration(seconds: 25)),
      );
      clock.tick(t0.add(const Duration(seconds: 40)));
      expect(clock.active, const Duration(seconds: 25));
      expect(clock.paused, const Duration(seconds: 15));
    });

    test('idle accrues idle time without auto-stop', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);
      clock.start(t0);
      clock.transition(TrackingStatus.idle, t0.add(const Duration(minutes: 5)));
      clock.tick(t0.add(const Duration(minutes: 6)));
      expect(clock.idle, const Duration(minutes: 1));
      expect(clock.status, TrackingStatus.idle);
    });

    test('idle then tracking continues active without losing idle', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 3, 1, 9, 0, 0);
      clock.start(t0);
      clock.tick(t0.add(const Duration(seconds: 30)));
      clock.transition(TrackingStatus.idle, t0.add(const Duration(seconds: 30)));
      clock.tick(t0.add(const Duration(seconds: 90)));
      clock.transition(
        TrackingStatus.tracking,
        t0.add(const Duration(seconds: 90)),
      );
      clock.tick(t0.add(const Duration(seconds: 120)));

      expect(clock.active, const Duration(seconds: 60)); // 30 + 30
      expect(clock.idle, const Duration(seconds: 60));
      expect(clock.elapsed, const Duration(seconds: 120));
    });

    test('stop flushes final segment then ignores further ticks', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 3, 1, 10, 0, 0);
      clock.start(t0);
      clock.tick(t0.add(const Duration(seconds: 20)));
      clock.transition(
        TrackingStatus.stopped,
        t0.add(const Duration(seconds: 45)),
      );

      expect(clock.active, const Duration(seconds: 45));
      clock.tick(t0.add(const Duration(seconds: 200)));
      expect(clock.active, const Duration(seconds: 45));
      expect(clock.status, TrackingStatus.stopped);
    });

    test('start resets counters for a new segment (resegment pattern)', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 3, 1, 11, 0, 0);
      clock.start(t0);
      clock.tick(t0.add(const Duration(minutes: 2)));
      expect(clock.active, const Duration(minutes: 2));

      // Close old segment then open a new one — production resegment path.
      clock.transition(
        TrackingStatus.stopped,
        t0.add(const Duration(minutes: 2)),
      );
      final closed = clock.snapshotMs();
      expect(closed['activeMs'], 120_000);

      clock.start(t0.add(const Duration(minutes: 2)));
      clock.tick(t0.add(const Duration(minutes: 2, seconds: 15)));
      expect(clock.active, const Duration(seconds: 15));
      expect(clock.idle, Duration.zero);
      expect(clock.paused, Duration.zero);
    });

    test('same-instant tick does not double-count', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 3, 1, 12, 0, 0);
      clock.start(t0);
      clock.tick(t0);
      clock.tick(t0);
      expect(clock.active, Duration.zero);
      clock.tick(t0.add(const Duration(seconds: 1)));
      expect(clock.active, const Duration(seconds: 1));
    });

    test('clock skew (negative delta) is ignored', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 3, 1, 13, 0, 0);
      clock.start(t0);
      clock.tick(t0.add(const Duration(seconds: 10)));
      clock.tick(t0.add(const Duration(seconds: 5))); // backwards
      expect(clock.active, const Duration(seconds: 10));
    });

    test('snapshotMs matches durations', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 3, 1, 14, 0, 0);
      clock.start(t0);
      clock.tick(t0.add(const Duration(seconds: 5)));
      clock.transition(TrackingStatus.idle, t0.add(const Duration(seconds: 5)));
      clock.tick(t0.add(const Duration(seconds: 8)));
      clock.transition(
        TrackingStatus.paused,
        t0.add(const Duration(seconds: 8)),
      );
      clock.tick(t0.add(const Duration(seconds: 11)));

      final snap = clock.snapshotMs();
      expect(snap['activeMs'], 5_000);
      expect(snap['idleMs'], 3_000);
      expect(snap['pausedMs'], 3_000);
      expect(
        clock.elapsed.inMilliseconds,
        snap['activeMs']! + snap['idleMs']! + snap['pausedMs']!,
      );
    });

    test('many one-second ticks match wall time (Windows/macOS UI ticker)', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 3, 1, 15, 0, 0);
      clock.start(t0);
      for (var i = 1; i <= 120; i++) {
        clock.tick(t0.add(Duration(seconds: i)));
      }
      expect(clock.active, const Duration(seconds: 120));
      expect(clock.elapsed, const Duration(seconds: 120));
    });

    test('paused then stop keeps paused total', () {
      final clock = SessionClock();
      final t0 = DateTime.utc(2026, 3, 1, 16, 0, 0);
      clock.start(t0);
      clock.transition(TrackingStatus.paused, t0.add(const Duration(seconds: 10)));
      clock.transition(
        TrackingStatus.stopped,
        t0.add(const Duration(seconds: 40)),
      );
      expect(clock.active, const Duration(seconds: 10));
      expect(clock.paused, const Duration(seconds: 30));
    });
  });
}
