class AppConstants {
  /// Display brand (UI + window title). Technical package id stays `witrack`.
  static const String appName = 'WorkInsight Tracker';
  static const String brandPrimary = 'WorkInsight';
  static const String brandSecondary = 'Tracker';
  static const String tagline = 'Work smarter. Track clearly.';
  static const String packageName = 'witrack';
  static const String bundleId = 'com.witrack.desktop';
  static const Duration splashDuration = Duration(milliseconds: 1600);

  /// Fixed desktop window size (resize disabled on Windows + macOS).
  static const double windowWidth = 1180;
  static const double windowHeight = 760;

  /// Kept as aliases for older call sites / docs.
  static const double minWindowWidth = windowWidth;
  static const double minWindowHeight = windowHeight;
}
