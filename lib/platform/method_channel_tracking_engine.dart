import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/platform/tracking_engine.dart';

/// Shared MethodChannel bridge used by Windows and macOS native plugins.
class MethodChannelTrackingEngine implements TrackingEngine {
  MethodChannelTrackingEngine();

  static const _methods = MethodChannel('com.witrack.desktop/tracking');

  final _statusController = StreamController<TrackingStatusEvent>.broadcast();
  final _sampleController = StreamController<ActivitySampleEvent>.broadcast();
  final _appController = StreamController<ForegroundAppEvent>.broadcast();

  Timer? _pollTimer;
  TrackingStatus _lastStatus = TrackingStatus.stopped;
  String? _lastApp;
  int _sampleTicks = 0;
  bool _sessionActive = false;

  @override
  Stream<TrackingStatusEvent> get statusEvents => _statusController.stream;

  @override
  Stream<ActivitySampleEvent> get activitySamples => _sampleController.stream;

  @override
  Stream<ForegroundAppEvent> get foregroundApps => _appController.stream;

  @override
  Future<void> start() async {
    _ensureDesktop();
    _sessionActive = true;
    _sampleTicks = 0;
    await _methods.invokeMethod<void>('start');
    _lastStatus = TrackingStatus.tracking;
    _statusController.add(
      TrackingStatusEvent(status: TrackingStatus.tracking, at: DateTime.now()),
    );
    _startPolling();
  }

  @override
  Future<void> pause() async {
    _ensureDesktop();
    await _methods.invokeMethod<void>('pause');
  }

  @override
  Future<void> resume() async {
    _ensureDesktop();
    await _methods.invokeMethod<void>('resume');
  }

  @override
  Future<void> stop() async {
    _ensureDesktop();
    _sessionActive = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _methods.invokeMethod<void>('stop');
    _lastStatus = TrackingStatus.stopped;
  }

  @override
  Future<TrackingStatus> getStatus() async {
    _ensureDesktop();
    final raw = await _methods.invokeMethod<String>('getStatus');
    return _parseStatus(raw ?? 'stopped');
  }

  @override
  Future<void> updatePolicies({
    required int idleThresholdSeconds,
    required bool autoPauseOnIdle,
  }) async {
    _ensureDesktop();
    await _methods.invokeMethod<void>('updatePolicies', {
      'idleThresholdSeconds': idleThresholdSeconds,
      'autoPauseOnIdle': autoPauseOnIdle,
    });
  }

  @override
  Future<List<CapturedDisplayImage>> captureDisplays() async {
    _ensureDesktop();
    final raw = await _methods.invokeMethod<dynamic>('captureDisplays');
    if (raw is! List) return const [];
    final out = <CapturedDisplayImage>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final bytes = map['pngBytes'];
      if (bytes is! Uint8List && bytes is! List) continue;
      out.add(
        CapturedDisplayImage(
          displayIndex: map['displayIndex'] as int? ?? 0,
          width: map['width'] as int? ?? 0,
          height: map['height'] as int? ?? 0,
          pngBytes: bytes is Uint8List
              ? bytes
              : Uint8List.fromList(List<int>.from(bytes as List)),
        ),
      );
    }
    return out;
  }

  @override
  Future<PermissionStatusSnapshot> permissionStatus() async {
    _ensureDesktop();
    final raw = await _methods.invokeMethod<dynamic>('permissionStatus');
    return _toPermissionSnapshot(raw);
  }

  @override
  Future<PermissionStatusSnapshot> requestPermissions({
    bool prompt = false,
  }) async {
    _ensureDesktop();
    final raw = await _methods.invokeMethod<dynamic>('requestPermissions', {
      'prompt': prompt,
    });
    return _toPermissionSnapshot(raw);
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _statusController.close();
    await _sampleController.close();
    await _appController.close();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_poll());
    });
  }

  Future<void> _poll() async {
    if (!_sessionActive) return;
    try {
      final raw = await _methods.invokeMethod<dynamic>('poll');
      if (raw is! Map) return;
      final map = Map<String, dynamic>.from(raw);
      final at = DateTime.fromMillisecondsSinceEpoch(
        map['atMs'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
      final status = _parseStatus(map['status'] as String? ?? 'stopped');
      final app = map['foregroundApp'] as String? ?? 'Unknown';
      final idleSec = map['secondsSinceLastInput'] as int? ?? 0;
      final activeSignal = map['isActiveSignal'] as bool? ?? false;

      if (status != _lastStatus) {
        _lastStatus = status;
        _statusController.add(TrackingStatusEvent(status: status, at: at));
      }
      if (app != _lastApp) {
        _lastApp = app;
        _appController.add(
          ForegroundAppEvent(
            appName: app,
            exeName: map['exeName'] as String?,
            at: at,
          ),
        );
      }
      if (status == TrackingStatus.tracking || status == TrackingStatus.idle) {
        _sampleTicks += 1;
        if (_sampleTicks >= 10) {
          _sampleTicks = 0;
          _sampleController.add(
            ActivitySampleEvent(
              sampledAt: at,
              secondsSinceLastInput: idleSec,
              isActiveSignal: activeSignal,
              foregroundApp: app,
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _ensureDesktop() {
    if (!Platform.isWindows && !Platform.isMacOS) {
      throw UnsupportedError('Native tracking requires Windows or macOS.');
    }
  }

  TrackingStatus _parseStatus(String value) {
    switch (value) {
      case 'tracking':
        return TrackingStatus.tracking;
      case 'paused':
        return TrackingStatus.paused;
      case 'idle':
        return TrackingStatus.idle;
      case 'initializing':
        return TrackingStatus.initializing;
      case 'error':
        return TrackingStatus.error;
      case 'permissionRequired':
        return TrackingStatus.permissionRequired;
      default:
        return TrackingStatus.stopped;
    }
  }

  PermissionStatusSnapshot _toPermissionSnapshot(dynamic raw) {
    if (raw is! Map) {
      return const PermissionStatusSnapshot(
        screenCapture: 'unknown',
        accessibility: 'unknown',
        notes: 'Native permission probe unavailable',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    return PermissionStatusSnapshot(
      screenCapture: map['screenCapture'] as String? ?? 'unknown',
      accessibility: map['accessibility'] as String? ?? 'unknown',
      notes: map['notes'] as String? ?? '',
    );
  }
}
