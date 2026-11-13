import 'package:witrack/domain/tracking/tracking_state.dart';

/// Accrues active / idle / paused time from status transitions.
/// Suspended OS time is handled when native emits future sleep signals.
class SessionClock {
  Duration active = Duration.zero;
  Duration idle = Duration.zero;
  Duration paused = Duration.zero;

  TrackingStatus _status = TrackingStatus.stopped;
  DateTime? _segmentStarted;

  TrackingStatus get status => _status;

  Duration get elapsed => active + idle + paused;

  void start(DateTime now) {
    active = Duration.zero;
    idle = Duration.zero;
    paused = Duration.zero;
    _status = TrackingStatus.tracking;
    _segmentStarted = now;
  }

  void transition(TrackingStatus next, DateTime now) {
    _flush(now);
    _status = next;
    if (next == TrackingStatus.stopped) {
      _segmentStarted = null;
    } else {
      _segmentStarted = now;
    }
  }

  /// Tick while a session is open so the UI timer advances.
  void tick(DateTime now) {
    if (_segmentStarted == null) return;
    if (_status == TrackingStatus.stopped ||
        _status == TrackingStatus.initializing ||
        _status == TrackingStatus.error) {
      return;
    }
    _flush(now);
    _segmentStarted = now;
  }

  Map<String, int> snapshotMs() => {
        'activeMs': active.inMilliseconds,
        'idleMs': idle.inMilliseconds,
        'pausedMs': paused.inMilliseconds,
      };

  void _flush(DateTime now) {
    final started = _segmentStarted;
    if (started == null) return;
    final delta = now.difference(started);
    if (delta.isNegative) return;
    switch (_status) {
      case TrackingStatus.tracking:
      case TrackingStatus.initializing:
        active += delta;
      case TrackingStatus.idle:
        idle += delta;
      case TrackingStatus.paused:
        paused += delta;
      case TrackingStatus.stopped:
      case TrackingStatus.error:
      case TrackingStatus.permissionRequired:
      case TrackingStatus.recovering:
        break;
    }
  }
}
