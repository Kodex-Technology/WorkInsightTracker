import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/data/auth/auth_models.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/data/screenshots/screenshot_store.dart';
import 'package:witrack/data/settings/settings_repository.dart';
import 'package:witrack/domain/tracking/session_clock.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/core/config/feature_toggles.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/tracking/desktop_notices.dart';
import 'package:witrack/platform/tracking_engine.dart';

class TrackingUiState {
  const TrackingUiState({
    this.status = TrackingStatus.stopped,
    this.sessionId,
    this.workspaceId,
    this.projectId,
    this.projectName,
    this.taskId,
    this.taskName,
    this.active = Duration.zero,
    this.idle = Duration.zero,
    this.paused = Duration.zero,
    this.currentApp,
    this.secondsSinceLastInput,
    this.isActiveSignal,
    this.activityPercent,
    this.lastScreenshotAt,
    this.nextScreenshotAt,
    this.todayTracked = Duration.zero,
    this.errorMessage,
  });

  final TrackingStatus status;
  final String? sessionId;
  final String? workspaceId;
  final String? projectId;
  final String? projectName;
  final String? taskId;
  final String? taskName;
  final Duration active;
  final Duration idle;
  final Duration paused;
  final String? currentApp;
  final int? secondsSinceLastInput;
  final bool? isActiveSignal;
  final double? activityPercent;
  final DateTime? lastScreenshotAt;
  final DateTime? nextScreenshotAt;
  final Duration todayTracked;
  final String? errorMessage;

  Duration get elapsed => active + idle + paused;

  TrackingUiState copyWith({
    TrackingStatus? status,
    String? sessionId,
    String? workspaceId,
    String? projectId,
    String? projectName,
    String? taskId,
    String? taskName,
    Duration? active,
    Duration? idle,
    Duration? paused,
    String? currentApp,
    int? secondsSinceLastInput,
    bool? isActiveSignal,
    double? activityPercent,
    DateTime? lastScreenshotAt,
    DateTime? nextScreenshotAt,
    Duration? todayTracked,
    String? errorMessage,
    bool clearSession = false,
    bool clearError = false,
    bool clearTask = false,
    bool clearProject = false,
  }) {
    return TrackingUiState(
      status: status ?? this.status,
      sessionId: clearSession ? null : (sessionId ?? this.sessionId),
      workspaceId: workspaceId ?? this.workspaceId,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      projectName: clearProject ? null : (projectName ?? this.projectName),
      taskId: clearTask || clearProject ? null : (taskId ?? this.taskId),
      taskName: clearTask || clearProject ? null : (taskName ?? this.taskName),
      active: active ?? this.active,
      idle: idle ?? this.idle,
      paused: paused ?? this.paused,
      currentApp: currentApp ?? this.currentApp,
      secondsSinceLastInput:
          secondsSinceLastInput ?? this.secondsSinceLastInput,
      isActiveSignal: isActiveSignal ?? this.isActiveSignal,
      activityPercent: activityPercent ?? this.activityPercent,
      lastScreenshotAt: lastScreenshotAt ?? this.lastScreenshotAt,
      nextScreenshotAt: nextScreenshotAt ?? this.nextScreenshotAt,
      todayTracked: todayTracked ?? this.todayTracked,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TrackingController extends Notifier<TrackingUiState> {
  final SessionClock _clock = SessionClock();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _uiTicker;
  Timer? _consoleSummaryTimer;
  Timer? _policyRefreshTimer;
  bool _intervalBusy = false;
  DateTime? _pendingIntervalAt;
  String? _sessionId;
  String? _attendanceSessionId;
  DateTime? _trackingStartedAt;
  DateTime? _productivityWindowStart;
  int _activeBuckets = 0;
  int _totalBuckets = 0;
  TrackingSettings _settings = const TrackingSettings();

  TrackingEngine get _engine => ref.read(trackingEngineProvider);

  @override
  TrackingUiState build() {
    ref.onDispose(_disposeInternal);
    _subs.addAll([
      _engine.statusEvents.listen(_onStatus),
      _engine.activitySamples.listen(_onSample),
      _engine.foregroundApps.listen(_onApp),
    ]);
    Future.microtask(_bootstrap);
    return const TrackingUiState();
  }

  Future<void> _bootstrap() async {
    _settings = await _loadTrackingSettings();
    await _engine.updatePolicies(
      idleThresholdSeconds: _settings.idleThresholdMinutes * 60,
      autoPauseOnIdle: _settings.autoPauseOnIdle,
    );
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      final today =
          await ref.read(sessionRepositoryProvider).trackedToday(user.id);
      final workspaceId = await ref
          .read(projectRepositoryProvider)
          .ensureDefaultWorkspace(user.id);
      state = state.copyWith(todayTracked: today, workspaceId: workspaceId);
      unawaited(_processPendingUploads(user));
    }
  }

  Future<void> _processPendingUploads(AuthUser user) async {
    try {
      final store = ref.read(screenshotStoreProvider);
      final pending = await store.getPendingUploads();
      // ignore: avoid_print
      print('[witrack.screenshots] Startup retry queue: ${pending.length} screenshot(s)');
      for (final row in pending) {
        try {
          // ignore: avoid_print
          print('[witrack.screenshots] Retrying pending screenshot ${row.id}');
          final pngBytes = await store.readDecrypted(row);
          if (pngBytes == null || pngBytes.isEmpty) {
            developer.log('Skipping unreadable pending screenshot ${row.id}', name: 'witrack.screenshots');
            continue;
          }
          final objectKey = await ref.read(trackerApiControllerProvider).uploadScreenshotToS3(
                user: user,
                screenshotId: row.id,
                sessionId: row.sessionId,
                takenAt: row.takenAt,
                takenDay: row.takenDay ?? ScreenshotStore.dayKey(row.takenAt.toLocal()),
                pngBytes: pngBytes,
                displayIndex: row.displayIndex,
              );
          if (objectKey != null) {
            await store.updateUploadStatus(
              id: row.id,
              status: 'uploaded',
              s3ObjectKey: objectKey,
              uploadedAt: DateTime.now().toUtc(),
            );
          }
        } catch (e) {
          // ignore: avoid_print
          print('[witrack.screenshots] Pending upload failed ${row.id}: $e');
          developer.log('Pending screenshot S3 upload failed for ${row.id}: $e', name: 'witrack.screenshots');
          await store.updateUploadStatus(
            id: row.id,
            status: 'failed',
          );
        }
      }
    } catch (e) {
      developer.log('Error processing pending screenshot uploads: $e', name: 'witrack.screenshots');
    }
  }

  void setWorkspaceId(String workspaceId) {
    state = state.copyWith(workspaceId: workspaceId);
  }

  /// Select project without a task — Start stays disabled until a task is chosen.
  void selectProjectOnly({
    required String projectId,
    required String projectName,
  }) {
    state = state.copyWith(
      projectId: projectId,
      projectName: projectName,
      clearTask: true,
      clearError: true,
    );
  }

  Future<void> selectProject({
    required String projectId,
    required String projectName,
  }) async {
    final task =
        await ref.read(projectRepositoryProvider).firstOpenTask(projectId);
    if (task == null) {
      selectProjectOnly(projectId: projectId, projectName: projectName);
      return;
    }
    await focusWork(
      projectId: projectId,
      projectName: projectName,
      taskId: task.id,
      taskName: task.name,
      startIfStopped: false,
    );
  }

  Future<void> selectTask({
    required String taskId,
    required String taskName,
  }) async {
    final projectId = state.projectId;
    final projectName = state.projectName;
    if (projectId == null || projectName == null) {
      state = state.copyWith(taskId: taskId, taskName: taskName);
      return;
    }
    await focusWork(
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskName: taskName,
      startIfStopped: false,
    );
  }

  /// Tracking always requires project + task — never project-only.
  Future<void> focusWork({
    required String projectId,
    required String projectName,
    required String taskId,
    required String taskName,
    bool startIfStopped = true,
  }) async {
    final same = state.projectId == projectId && state.taskId == taskId;
    final open = state.status == TrackingStatus.tracking ||
        state.status == TrackingStatus.idle ||
        state.status == TrackingStatus.paused;

    if (open) {
      if (same) return;
      await _resegment(
        projectId: projectId,
        projectName: projectName,
        taskId: taskId,
        taskName: taskName,
        resumeStatus: state.status,
      );
      return;
    }

    state = state.copyWith(
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskName: taskName,
      clearError: true,
    );
    if (startIfStopped) {
      await start();
    }
  }

  bool get _isOpen =>
      state.status == TrackingStatus.tracking ||
      state.status == TrackingStatus.idle ||
      state.status == TrackingStatus.paused;

  /// Office rule: finalize the open segment before complete/delete.
  Future<void> stopBeforeMutate() async {
    if (_isOpen) await stop();
  }

  /// After delete/complete — keep selection on another open task, never auto-start.
  Future<void> retargetAfterTaskGone(String taskId) async {
    if (state.taskId != taskId) return;
    final projectId = state.projectId;
    final projectName = state.projectName;
    if (projectId == null || projectName == null) {
      state = state.copyWith(clearTask: true);
      return;
    }
    final open =
        await ref.read(projectRepositoryProvider).listOpenTasks(projectId);
    if (open.isEmpty) {
      state = state.copyWith(clearTask: true);
      return;
    }
    final next = open.first;
    await focusWork(
      projectId: projectId,
      projectName: projectName,
      taskId: next.id,
      taskName: next.name,
      startIfStopped: false,
    );
  }

  /// After project archive — select another project+task, never auto-start.
  Future<void> retargetAfterProjectGone(String projectId) async {
    if (state.projectId != projectId) return;
    final workspaceId = state.workspaceId;
    if (workspaceId == null) {
      state = state.copyWith(clearProject: true);
      return;
    }
    final projects = await ref
        .read(projectRepositoryProvider)
        .watchActiveProjects(workspaceId)
        .first;
    if (projects.isEmpty) {
      state = state.copyWith(clearProject: true);
      return;
    }
    final next = projects.first;
    final task =
        await ref.read(projectRepositoryProvider).firstOpenTask(next.id);
    if (task == null) {
      selectProjectOnly(projectId: next.id, projectName: next.name);
      return;
    }
    await focusWork(
      projectId: next.id,
      projectName: next.name,
      taskId: task.id,
      taskName: task.name,
      startIfStopped: false,
    );
  }

  Future<void> _resegment({
    required String projectId,
    required String projectName,
    required String taskId,
    required String taskName,
    required TrackingStatus resumeStatus,
  }) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final previous = _sessionId;
    final now = DateTime.now();
    if (previous != null) {
      _clock.tick(now);
      await ref
          .read(sessionRepositoryProvider)
          .closeOpenAppUsage(sessionId: previous, at: now);
      await ref
          .read(sessionRepositoryProvider)
          .closeOpenIdleInterval(sessionId: previous, at: now);
      final snap = _clock.snapshotMs();
      await ref.read(sessionRepositoryProvider).completeSession(
            sessionId: previous,
            activeMs: snap['activeMs']!,
            idleMs: snap['idleMs']!,
            pausedMs: snap['pausedMs']!,
          );
    }

    final workspaceId = state.workspaceId ??
        await ref.read(projectRepositoryProvider).ensureDefaultWorkspace(user.id);
    final sessionId = await ref.read(sessionRepositoryProvider).createSession(
          userId: user.id,
          workspaceId: workspaceId,
          projectId: projectId,
          taskId: taskId,
        );
    _sessionId = sessionId;
    _activeBuckets = 0;
    _totalBuckets = 0;
    _productivityWindowStart = now.toUtc();
    _clock.start(now);
    final nextStatus = resumeStatus == TrackingStatus.paused ||
            resumeStatus == TrackingStatus.idle
        ? resumeStatus
        : TrackingStatus.tracking;
    if (nextStatus != TrackingStatus.tracking) {
      _clock.transition(nextStatus, now);
    }
    final today =
        await ref.read(sessionRepositoryProvider).trackedToday(user.id);
    state = state.copyWith(
      status: nextStatus,
      sessionId: sessionId,
      workspaceId: workspaceId,
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskName: taskName,
      active: _clock.active,
      idle: _clock.idle,
      paused: _clock.paused,
      todayTracked: today,
      clearError: true,
    );
    if (nextStatus == TrackingStatus.tracking) {
      _rescheduleScreenshots();
    }
  }

  Future<void> reloadSettings() async {
    _settings = await _loadTrackingSettings();
    await _engine.updatePolicies(
      idleThresholdSeconds: _settings.idleThresholdMinutes * 60,
      autoPauseOnIdle: _settings.autoPauseOnIdle,
    );
    _rescheduleScreenshots();
  }

  Future<TrackingSettings> _loadTrackingSettings() async {
    final repository = ref.read(settingsRepositoryProvider);
    final user = ref.read(authControllerProvider).user;
    if (user?.token?.isNotEmpty == true) {
      try {
        final remote = await repository.loadRemote(token: user!.token!);
        if (remote != null) return remote;
      } catch (error) {
        developer.log('Could not load tracker preferences from API: $error', name: 'witrack.settings');
      }
    }
    return repository.load();
  }

  Future<void> start() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Sign in required.');
      return;
    }
    if (!state.status.canStart) return;

    state = state.copyWith(
      status: TrackingStatus.initializing,
      clearError: true,
    );
    try {
      final workspaceId = state.workspaceId ??
          await ref
              .read(projectRepositoryProvider)
              .ensureDefaultWorkspace(user.id);
      final sessionId = await ref.read(sessionRepositoryProvider).createSession(
            userId: user.id,
            workspaceId: workspaceId,
            projectId: state.projectId,
            taskId: state.taskId,
          );
      _sessionId = sessionId;
      _attendanceSessionId = sessionId;
      _trackingStartedAt = DateTime.now();
      _activeBuckets = 0;
      _totalBuckets = 0;
      _productivityWindowStart = DateTime.now().toUtc();
      _clock.start(DateTime.now());
      _startTicker();
      await _engine.start();
      try {
        await ref.read(trackerApiControllerProvider).syncAttendance(
              user: user,
              sessionId: sessionId,
              startedAt: _trackingStartedAt!,
              endedAt: _trackingStartedAt!,
              idleMs: 0,
              pausedMs: 0,
              projectId: state.projectId,
              note: state.taskName ?? state.projectName,
            );
      } catch (apiError) {
        developer.log('Attendance API check-in failed: $apiError', name: 'witrack.attendance');
      }
      state = state.copyWith(
        status: TrackingStatus.tracking,
        sessionId: sessionId,
        workspaceId: workspaceId,
        active: _clock.active,
        idle: _clock.idle,
        paused: _clock.paused,
      );
      _rescheduleScreenshots();
    } catch (e) {
      state = state.copyWith(
        status: TrackingStatus.error,
        errorMessage: e.toString(),
        clearSession: true,
      );
      _sessionId = null;
      _attendanceSessionId = null;
      _trackingStartedAt = null;
      _stopTicker();
      _consoleSummaryTimer?.cancel();
    }
  }

  Future<void> pause() async {
    if (!state.status.canPause) return;
    await _engine.pause();
    _consoleSummaryTimer?.cancel();
    state = state.copyWith(nextScreenshotAt: null);
  }

  Future<void> resume() async {
    if (!state.status.canResume) return;
    await _engine.resume();
    _rescheduleScreenshots();
  }

  /// Force-stop for logout / app close — no UI confirm.
  Future<void> stopForExit() async {
    if (state.status == TrackingStatus.stopped && _sessionId == null) return;
    await stop(force: true);
  }

  Future<void> stop({bool force = false}) async {
    if (!force &&
        !state.status.canStop &&
        state.status != TrackingStatus.error) {
      return;
    }
    final sessionId = _sessionId;
    final attendanceSessionId = _attendanceSessionId;
    final attendanceStartedAt = _trackingStartedAt;
    final trackingUser = ref.read(authControllerProvider).user;
    final stoppedAt = DateTime.now();
    _clock.tick(stoppedAt);
    final stoppedTime = _clock.snapshotMs();
    if (attendanceSessionId != null && attendanceStartedAt != null && trackingUser != null) {
      try {
        await ref.read(trackerApiControllerProvider).syncAttendance(
              user: trackingUser,
              sessionId: attendanceSessionId,
              startedAt: attendanceStartedAt,
              endedAt: stoppedAt,
              idleMs: stoppedTime['idleMs']!,
              pausedMs: stoppedTime['pausedMs']!,
              projectId: state.projectId,
              note: state.taskName ?? state.projectName,
            );
      } catch (apiError) {
        developer.log('Attendance API check-out failed: $apiError', name: 'witrack.attendance');
      }
    }
    _consoleSummaryTimer?.cancel();
    try {
      await _engine.stop();
    } catch (_) {}
    final now = DateTime.now();
    _clock.transition(TrackingStatus.stopped, now);
    _stopTicker();
    if (sessionId != null) {
      await ref
          .read(sessionRepositoryProvider)
          .closeOpenAppUsage(sessionId: sessionId, at: now);
      await ref
          .read(sessionRepositoryProvider)
          .closeOpenIdleInterval(sessionId: sessionId, at: now);
      final snap = _clock.snapshotMs();
      await ref.read(sessionRepositoryProvider).completeSession(
            sessionId: sessionId,
            activeMs: snap['activeMs']!,
            idleMs: snap['idleMs']!,
            pausedMs: snap['pausedMs']!,
          );
      final user = ref.read(authControllerProvider).user;
      if (user != null) {
        final today =
            await ref.read(sessionRepositoryProvider).trackedToday(user.id);
        state = state.copyWith(todayTracked: today);
      }
    }
    _sessionId = null;
    _attendanceSessionId = null;
    _trackingStartedAt = null;
    _productivityWindowStart = null;
    // Stopped UI shows a clean 00:00:00 segment; day totals hold finished time.
    state = TrackingUiState(
      status: TrackingStatus.stopped,
      workspaceId: state.workspaceId,
      projectId: state.projectId,
      projectName: state.projectName,
      taskId: state.taskId,
      taskName: state.taskName,
      active: Duration.zero,
      idle: Duration.zero,
      paused: Duration.zero,
      currentApp: state.currentApp,
      activityPercent: state.activityPercent,
      todayTracked: state.todayTracked,
      lastScreenshotAt: state.lastScreenshotAt,
    );
  }

  Future<void> captureTestScreenshot() async {
    final sessionId = _sessionId;
    if (sessionId == null || !state.status.isRunning) {
      state = state.copyWith(
        errorMessage: 'Start tracking to capture a test screenshot.',
      );
      return;
    }
    await _captureNow(isTest: true);
  }

  void _rescheduleScreenshots() {
    _consoleSummaryTimer?.cancel();
    _policyRefreshTimer?.cancel();
    if (_sessionId != null && state.status.isRunning) {
      final interval = Duration(
        minutes: _settings.screenshotIntervalMinutes.clamp(1, 15),
      );
      state = state.copyWith(nextScreenshotAt: DateTime.now().add(interval));
      _consoleSummaryTimer = Timer.periodic(interval, (_) => _onTrackingInterval());
      _policyRefreshTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _refreshOrganizationPolicy(),
      );
    }
    if (!_settings.screenshotEnabled) {
      state = state.copyWith(nextScreenshotAt: null);
    }
  }

  Future<void> _refreshOrganizationPolicy() async {
    final user = ref.read(authControllerProvider).user;
    if (user?.token?.isNotEmpty != true) return;
    try {
      final next = await ref.read(settingsRepositoryProvider).loadRemote(token: user!.token!);
      if (next == null) return;
      final changed = next.screenshotEnabled != _settings.screenshotEnabled ||
          next.screenshotIntervalMinutes != _settings.screenshotIntervalMinutes ||
          next.idleThresholdMinutes != _settings.idleThresholdMinutes ||
          next.autoPauseOnIdle != _settings.autoPauseOnIdle ||
          next.excludeIdleFromActive != _settings.excludeIdleFromActive ||
          next.collectWindowTitles != _settings.collectWindowTitles ||
          next.notifyOnScreenshot != _settings.notifyOnScreenshot;
      if (!changed) return;
      _settings = next;
      await _engine.updatePolicies(
        idleThresholdSeconds: next.idleThresholdMinutes * 60,
        autoPauseOnIdle: next.autoPauseOnIdle,
      );
      _rescheduleScreenshots();
    } catch (error) {
      developer.log('Organization tracker policy refresh failed: $error', name: 'witrack.settings');
    }
  }

  Future<void> _onTrackingInterval() async {
    if (_intervalBusy || _sessionId == null || !state.status.isRunning) return;
    _intervalBusy = true;
    try {
      _logTrackingSummary();
      final user = ref.read(authControllerProvider).user;
      final attendanceId = _attendanceSessionId;
      final startedAt = _trackingStartedAt;
      final intervalAt = DateTime.now();
      _clock.tick(intervalAt);
      final elapsed = _clock.snapshotMs();
      if (user != null && attendanceId != null && startedAt != null) {
        try {
          await ref.read(trackerApiControllerProvider).syncAttendance(
                user: user,
                sessionId: attendanceId,
                startedAt: startedAt,
                endedAt: intervalAt,
                idleMs: elapsed['idleMs']!,
                pausedMs: elapsed['pausedMs']!,
                projectId: state.projectId,
                note: state.taskName ?? state.projectName,
              );
        } catch (error) {
          developer.log('Attendance interval API update failed: $error', name: 'witrack.attendance');
        }
      }
      if (_settings.screenshotEnabled) {
        _pendingIntervalAt = intervalAt;
        try {
          await _captureNow(isTest: false);
        } finally {
          _pendingIntervalAt = null;
        }
      }
      if (_sessionId != null && state.status.isRunning) {
        await _startIntervalSegment(intervalAt);
      }
    } finally {
      _intervalBusy = false;
      // Timer.periodic callbacks are not awaited. Schedule the next occurrence
      // after this one finishes so transient API/capture failures don't stop
      // future attendance updates.
      if (_sessionId != null && state.status.isRunning) {
        final interval = Duration(
          minutes: _settings.screenshotIntervalMinutes.clamp(1, 15),
        );
        state = state.copyWith(
          nextScreenshotAt: _settings.screenshotEnabled
              ? DateTime.now().add(interval)
              : null,
        );
        _consoleSummaryTimer?.cancel();
        _consoleSummaryTimer = Timer(interval, _onTrackingInterval);
      }
    }
  }

  Future<void> _startIntervalSegment(DateTime at) async {
    final user = ref.read(authControllerProvider).user;
    final previous = _sessionId;
    if (user == null || previous == null) return;
    _clock.tick(at);
    await ref.read(sessionRepositoryProvider).closeOpenAppUsage(
          sessionId: previous,
          at: at,
        );
    await ref.read(sessionRepositoryProvider).closeOpenIdleInterval(
          sessionId: previous,
          at: at,
        );
    final snapshot = _clock.snapshotMs();
    await ref.read(sessionRepositoryProvider).completeSession(
          sessionId: previous,
          activeMs: snapshot['activeMs']!,
          idleMs: snapshot['idleMs']!,
          pausedMs: snapshot['pausedMs']!,
          endedAt: at,
        );
    await ref.read(sessionRepositoryProvider).addEvent(
          sessionId: previous,
          type: 'interval_completed',
          at: at,
        );
    final nextId = await ref.read(sessionRepositoryProvider).createSession(
          userId: user.id,
          workspaceId: state.workspaceId,
          projectId: state.projectId,
          taskId: state.taskId,
          startedAt: at,
        );
    _sessionId = nextId;
    _activeBuckets = 0;
    _totalBuckets = 0;
    _productivityWindowStart = at.toUtc();
    await ref.read(sessionRepositoryProvider).openAppUsage(
          sessionId: nextId,
          appName: state.currentApp ?? 'Unknown',
          at: at,
        );
    if (state.status == TrackingStatus.idle) {
      await ref.read(sessionRepositoryProvider).openIdleInterval(
            sessionId: nextId,
            at: at,
          );
    }
    state = state.copyWith(sessionId: nextId);
  }

  void _logTrackingSummary() {
    if (_sessionId == null || !state.status.isRunning) return;
    final summary = <String, Object?>{
      'sessionId': _sessionId,
      'at': DateTime.now().toUtc().toIso8601String(),
      'status': state.status.name,
      'intervalMinutes': _settings.screenshotIntervalMinutes,
      'screenshotEnabled': _settings.screenshotEnabled,
      'activeMs': _clock.active.inMilliseconds,
      'idleMs': _clock.idle.inMilliseconds,
      'pausedMs': _clock.paused.inMilliseconds,
      'activityPercent': state.activityPercent,
      'secondsSinceLastInput': state.secondsSinceLastInput,
      'foregroundApp': state.currentApp,
    };
    final line = jsonEncode(summary);
    developer.log('Tracking interval summary: $line', name: 'witrack.tracking');
    // ignore: avoid_print
    print('[witrack.tracking] $line');
  }

  Future<void> _captureNow({required bool isTest}) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    if (!state.status.isRunning) return;
    try {
      final images = await _engine.captureDisplays();
      // ignore: avoid_print
      print(
        '[witrack.screenshots] Capture triggered: session=$sessionId '
        'test=$isTest displays=${images.length}',
      );
      final store = ref.read(screenshotStoreProvider);
      final windowEnd =
          (isTest ? DateTime.now() : (_pendingIntervalAt ?? DateTime.now()))
              .toUtc();
      final windowStart = _productivityWindowStart ?? windowEnd;
      final productivity = await ref
          .read(sessionRepositoryProvider)
          .productivityForWindow(
            sessionId: sessionId,
            windowStart: windowStart,
            windowEnd: windowEnd,
          );
      final productivityMeta = productivity.toJson();
      DateTime? last;
      for (final image in images) {
        final row = await store.persistCapture(
          sessionId: sessionId,
          projectId: state.projectId,
          taskId: state.taskId,
          displayIndex: image.displayIndex,
          width: image.width,
          height: image.height,
          pngBytes: image.pngBytes,
          isTestCapture: isTest,
          persistImage: false,
          metadata: {
            'source': isTest ? 'test_capture' : 'interval',
            if (state.projectName != null) 'projectName': state.projectName,
            if (state.taskName != null) 'taskName': state.taskName,
            ...productivityMeta,
          },
        );
        final authUser = ref.read(authControllerProvider).user;
        if (authUser != null) {
          try {
            final objectKey = await ref.read(trackerApiControllerProvider).uploadScreenshotToS3(
                  user: authUser,
                  screenshotId: row.id,
                  sessionId: sessionId,
                  takenAt: row.takenAt,
                  takenDay: row.takenDay ?? ScreenshotStore.dayKey(row.takenAt.toLocal()),
                  pngBytes: image.pngBytes,
                  displayIndex: row.displayIndex,
                );
            if (objectKey != null) {
              await store.updateUploadStatus(
                id: row.id,
                status: 'uploaded',
                s3ObjectKey: objectKey,
                uploadedAt: DateTime.now().toUtc(),
              );
            }
          } catch (apiError) {
            // ignore: avoid_print
            print('[witrack.screenshots] Upload failed ${row.id}: $apiError');
            developer.log('Screenshot S3 upload failed: $apiError', name: 'witrack.screenshots');
            await store.updateUploadStatus(id: row.id, status: 'failed');
          }
        }
        last = row.takenAt;
      }
      // Next interval starts after this capture (shared across multi-display).
      _productivityWindowStart = windowEnd;
      if (last != null) {
        state = state.copyWith(
          lastScreenshotAt: last.toLocal(),
          activityPercent: productivity.percent,
        );
        await ref.read(sessionRepositoryProvider).addEvent(
              sessionId: sessionId,
              type: isTest ? 'screenshot_test' : 'screenshot',
              payload:
                  '${images.length} display(s) · ${productivity.percent.toStringAsFixed(0)}% productive',
            );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Screenshot failed: $e');
    }
  }

  void _onStatus(TrackingStatusEvent event) {
    if (_sessionId == null) return;
    if (event.status == TrackingStatus.stopped) return;

    final previous = _clock.status;
    _clock.transition(event.status, event.at);
    state = state.copyWith(
      status: event.status,
      active: _clock.active,
      idle: _clock.idle,
      paused: _clock.paused,
      errorMessage: event.message,
    );

    if (event.status == TrackingStatus.idle &&
        previous != TrackingStatus.idle) {
      unawaited(
        ref.read(sessionRepositoryProvider).openIdleInterval(
              sessionId: _sessionId!,
              at: event.at,
            ),
      );
      // Fire from the status source of truth (not UI listen) so idle toasts
      // always show when the session actually becomes Idle.
      if (ref.read(featureTogglesProvider).isOn(FeatureId.idleNotices)) {
        unawaited(DesktopNotices.showIdle());
      }
      if (_settings.autoPauseOnIdle) {
        unawaited(pause());
      }
    }
    if (previous == TrackingStatus.idle &&
        event.status == TrackingStatus.tracking) {
      unawaited(
        ref.read(sessionRepositoryProvider).closeOpenIdleInterval(
              sessionId: _sessionId!,
              at: event.at,
            ),
      );
    }

    unawaited(
      ref.read(sessionRepositoryProvider).updateState(
            sessionId: _sessionId!,
            state: event.status.name,
          ),
    );
    unawaited(_persistDurations());

    if (event.status.isRunning) {
      _rescheduleScreenshots();
    } else {
      _consoleSummaryTimer?.cancel();
    }
  }

  void _onSample(ActivitySampleEvent event) {
    if (_sessionId == null) return;
    _totalBuckets += 1;
    if (event.isActiveSignal) _activeBuckets += 1;
    final percent =
        _totalBuckets == 0 ? 0.0 : (_activeBuckets / _totalBuckets) * 100.0;
    state = state.copyWith(
      secondsSinceLastInput: event.secondsSinceLastInput,
      isActiveSignal: event.isActiveSignal,
      currentApp: event.foregroundApp ?? state.currentApp,
      activityPercent: percent,
    );
    unawaited(
      ref.read(sessionRepositoryProvider).addActivitySample(
            sessionId: _sessionId!,
            sampledAt: event.sampledAt,
            secondsSinceLastInput: event.secondsSinceLastInput,
            isActiveSignal: event.isActiveSignal,
            foregroundApp: event.foregroundApp ?? state.currentApp,
          ),
    );
  }

  void _onApp(ForegroundAppEvent event) {
    if (_sessionId == null) return;
    state = state.copyWith(currentApp: event.appName);
    unawaited(
      ref.read(sessionRepositoryProvider).openAppUsage(
            sessionId: _sessionId!,
            appName: event.appName,
            exeName: event.exeName,
            at: event.at,
          ),
    );
    unawaited(
      ref.read(sessionRepositoryProvider).addEvent(
            sessionId: _sessionId!,
            type: 'foreground',
            payload: event.appName,
          ),
    );
  }

  int _persistTick = 0;

  void _startTicker() {
    _uiTicker?.cancel();
    _persistTick = 0;
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final before = _clock.snapshotMs();
      _clock.tick(DateTime.now());
      final after = _clock.snapshotMs();
      // Skip Riverpod notify when wall-clock produced no accrual (rare / skew).
      if (before['activeMs'] == after['activeMs'] &&
          before['idleMs'] == after['idleMs'] &&
          before['pausedMs'] == after['pausedMs']) {
        return;
      }
      state = state.copyWith(
        active: _clock.active,
        idle: _clock.idle,
        paused: _clock.paused,
      );
      // Persist every 5s — every-second DB writes thrash Drift watches and blink the UI.
      _persistTick++;
      if (_persistTick % 5 == 0 &&
          (_clock.status == TrackingStatus.tracking ||
              _clock.status == TrackingStatus.idle ||
              _clock.status == TrackingStatus.paused)) {
        unawaited(_persistDurations());
      }
    });
  }

  void _stopTicker() {
    _uiTicker?.cancel();
    _consoleSummaryTimer?.cancel();
    _policyRefreshTimer?.cancel();
    _uiTicker = null;
  }

  Future<void> _persistDurations() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final snap = _clock.snapshotMs();
    await ref.read(sessionRepositoryProvider).updateDurations(
          sessionId: sessionId,
          activeMs: snap['activeMs']!,
          idleMs: snap['idleMs']!,
          pausedMs: snap['pausedMs']!,
        );
  }

  Future<void> _disposeInternal() async {
    // Best-effort finalize if provider tears down mid-session (logout/crash path).
    if (_sessionId != null) {
      try {
        await stop(force: true);
      } catch (_) {}
    }
    _stopTicker();
    _consoleSummaryTimer?.cancel();
    _policyRefreshTimer?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }
}

final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingUiState>(
  TrackingController.new,
);
