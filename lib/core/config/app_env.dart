/// Compile-time environment for Witrack desktop.
///
/// `--dart-define=WITRACK_ENV=production` (or APP_ENV=production) for release.
enum AppEnvironment { development, production }

enum AuthRole { user, admin, superAdmin }

extension AuthRoleX on AuthRole {
  String get wireName => switch (this) {
        AuthRole.user => 'user',
        AuthRole.admin => 'admin',
        AuthRole.superAdmin => 'super_admin',
      };

  bool get isAdmin => this == AuthRole.admin || this == AuthRole.superAdmin;
}

abstract final class AppEnv {
  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: '',
  );

  static const String _legacyEnv = String.fromEnvironment(
    'WITRACK_ENV',
    defaultValue: 'development',
  );

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'WorkInsight Tracker',
  );

  static String get _resolvedRaw {
    if (_rawEnv.isNotEmpty) return _rawEnv;
    return _legacyEnv;
  }

  static AppEnvironment get current => _resolvedRaw == 'production'
      ? AppEnvironment.production
      : AppEnvironment.development;

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isProduction => current == AppEnvironment.production;

  /// Local identity shortcuts — development only.
  static bool get allowLocalDevAuth => isDevelopment;

  static bool get allowLocalAdminTesting => isDevelopment;

  /// Google / Firebase auth deferred — not active for now.
  static bool get enableGoogleAuth => false;

  static String get modeLabel =>
      isDevelopment ? 'Development' : 'Production';
}
