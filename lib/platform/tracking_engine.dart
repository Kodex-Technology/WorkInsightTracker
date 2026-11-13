import 'dart:async';
import 'dart:typed_data';

import 'package:witrack/domain/tracking/tracking_state.dart';

/// Activity signal — not fabricated key/mouse counts.
class ActivitySampleEvent {
  const ActivitySampleEvent({
    required this.sampledAt,
    required this.secondsSinceLastInput,
    required this.isActiveSignal,
    this.foregroundApp,
  });

  final DateTime sampledAt;
  final int secondsSinceLastInput;
  final bool isActiveSignal;
  final String? foregroundApp;
}

class ForegroundAppEvent {
  const ForegroundAppEvent({
    required this.appName,
    required this.at,
    this.exeName,
  });

  final String appName;
  final String? exeName;
  final DateTime at;
}

class TrackingStatusEvent {
  const TrackingStatusEvent({
    required this.status,
    required this.at,
    this.message,
  });

  final TrackingStatus status;
  final DateTime at;
  final String? message;
}

class CapturedDisplayImage {
  const CapturedDisplayImage({
    required this.displayIndex,
    required this.width,
    required this.height,
    required this.pngBytes,
  });

  final int displayIndex;
  final int width;
  final int height;
  final Uint8List pngBytes;
}

class PermissionStatusSnapshot {
  const PermissionStatusSnapshot({
    required this.screenCapture,
    required this.accessibility,
    required this.notes,
  });

  final String screenCapture;
  final String accessibility;
  final String notes;
}

/// Platform boundary for the native tracking engine.
abstract class TrackingEngine {
  Stream<TrackingStatusEvent> get statusEvents;
  Stream<ActivitySampleEvent> get activitySamples;
  Stream<ForegroundAppEvent> get foregroundApps;

  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<TrackingStatus> getStatus();
  Future<void> updatePolicies({
    required int idleThresholdSeconds,
    required bool autoPauseOnIdle,
  });
  Future<List<CapturedDisplayImage>> captureDisplays();
  Future<PermissionStatusSnapshot> permissionStatus();
  Future<void> dispose();
}
