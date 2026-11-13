import 'package:witrack/core/config/feature_flags.dart';

/// Catalog of product modules. Master features cannot be turned off.
enum FeatureId {
  trackingCore,
  calendar,
  completedList,
  screenshots,
  reports,
  timeline,
  projectsScreen,
  backendSync,
  attendance,
  confirmStopBeforeMutate,
  confirmTaskSwitch,
  idleNotices,
  screenshotNotices,
}

extension FeatureIdX on FeatureId {
  String get prefsKey => 'witrack.feature.$name';

  String get title => switch (this) {
        FeatureId.trackingCore => 'Tracking core (timer / events / capture)',
        FeatureId.calendar => 'Progress calendar',
        FeatureId.completedList => 'Completed today list',
        FeatureId.screenshots => 'Screenshots gallery',
        FeatureId.reports => 'Reports',
        FeatureId.timeline => 'Timeline',
        FeatureId.projectsScreen => 'Projects screen',
        FeatureId.backendSync => 'Backend sync',
        FeatureId.attendance => 'Attendance integration',
        FeatureId.confirmStopBeforeMutate => 'Confirm stop before complete/delete',
        FeatureId.confirmTaskSwitch => 'Confirm before switching tasks',
        FeatureId.idleNotices => 'Idle toast windows',
        FeatureId.screenshotNotices => 'Screenshot toast windows',
      };

  String get subtitle => switch (this) {
        FeatureId.trackingCore =>
          'Master feature — always on. Sessions, idle, screenshots while tracking.',
        FeatureId.calendar => 'Week / month progress and day breakdown.',
        FeatureId.completedList => 'Separate list for completed tasks on dashboard.',
        FeatureId.screenshots => 'Screenshot gallery navigation and filters.',
        FeatureId.reports => 'Reports / insights screen.',
        FeatureId.timeline => 'Session timeline screen.',
        FeatureId.projectsScreen => 'Standalone projects management screen.',
        FeatureId.backendSync => 'Remote sync adapters (off until API ready).',
        FeatureId.attendance => 'Portal check-in (separate from Start Tracking).',
        FeatureId.confirmStopBeforeMutate =>
          'Ask before stopping the open timer on complete/delete.',
        FeatureId.confirmTaskSwitch =>
          'Ask before ending the current task segment to switch tasks.',
        FeatureId.idleNotices =>
          'Separate native toast window when the session becomes Idle.',
        FeatureId.screenshotNotices =>
          'Separate native toast window on screenshot capture (also respects Settings).',
      };

  /// Master features stay on — admin UI shows them locked.
  bool get isMaster => this == FeatureId.trackingCore;

  bool get compileDefault => switch (this) {
        FeatureId.trackingCore => true,
        FeatureId.calendar => FeatureFlags.enableCalendar,
        FeatureId.completedList => FeatureFlags.enableCompletedList,
        FeatureId.screenshots => FeatureFlags.enableScreenshots,
        FeatureId.reports => FeatureFlags.enableReports,
        FeatureId.timeline => FeatureFlags.enableTimeline,
        FeatureId.projectsScreen => FeatureFlags.enableProjectsScreen,
        FeatureId.backendSync => FeatureFlags.enableBackendSync,
        FeatureId.attendance => FeatureFlags.enableAttendance,
        FeatureId.confirmStopBeforeMutate =>
          FeatureFlags.confirmStopBeforeMutate,
        FeatureId.confirmTaskSwitch => FeatureFlags.confirmTaskSwitch,
        FeatureId.idleNotices => FeatureFlags.enableIdleNotices,
        FeatureId.screenshotNotices => FeatureFlags.enableScreenshotNotices,
      };
}
