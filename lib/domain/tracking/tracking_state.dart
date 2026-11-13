enum TrackingStatus {
  stopped,
  initializing,
  tracking,
  paused,
  idle,
  permissionRequired,
  recovering,
  error,
}

extension TrackingStatusLabel on TrackingStatus {
  String get label {
    switch (this) {
      case TrackingStatus.stopped:
        return 'Stopped';
      case TrackingStatus.initializing:
        return 'Starting';
      case TrackingStatus.tracking:
        return 'Tracking';
      case TrackingStatus.paused:
        return 'Paused';
      case TrackingStatus.idle:
        return 'Idle';
      case TrackingStatus.permissionRequired:
        return 'Permission required';
      case TrackingStatus.recovering:
        return 'Recovering';
      case TrackingStatus.error:
        return 'Error';
    }
  }

  bool get isRunning =>
      this == TrackingStatus.tracking || this == TrackingStatus.idle;

  bool get canStart =>
      this == TrackingStatus.stopped ||
      this == TrackingStatus.error ||
      this == TrackingStatus.permissionRequired;

  bool get canPause =>
      this == TrackingStatus.tracking || this == TrackingStatus.idle;

  bool get canResume => this == TrackingStatus.paused;

  bool get canStop =>
      this == TrackingStatus.tracking ||
      this == TrackingStatus.paused ||
      this == TrackingStatus.idle ||
      this == TrackingStatus.initializing;
}
