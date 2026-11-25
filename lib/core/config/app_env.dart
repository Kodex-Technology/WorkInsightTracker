import 'dart:io';

/// Runtime environment and API configuration for Witrack desktop.
///
/// Production builds select `.env.production` with `--dart-define=APP_ENV=production`.
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
  static Map<String, String> _fileValues = const {};

  /// Loads the selected dotenv file before the app is created.
  /// Values from the file take precedence over compile-time defaults.
  static Future<void> initialize() async {
    final environment = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    final fileName = environment == 'production' ? '.env.production' : '.env';
    final candidates = <File>[
      File(
        '${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}$fileName',
      ),
      File('${Directory.current.path}${Platform.pathSeparator}$fileName'),
    ];
    for (final file in candidates) {
      if (await file.exists()) {
        _fileValues = _parse(await file.readAsLines());
        return;
      }
    }
  }

  static Map<String, String> _parse(List<String> lines) {
    final values = <String, String>{};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separator = trimmed.indexOf('=');
      if (separator < 1) continue;
      var value = trimmed.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      values[trimmed.substring(0, separator).trim()] = value;
    }
    return values;
  }

  static String _value(String key, String fallback) =>
      _fileValues[key] ?? fallback;

  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: '',
  );

  static const String _legacyEnv = String.fromEnvironment(
    'WITRACK_ENV',
    defaultValue: 'development',
  );

  static String get appName => _value(
        'APP_NAME',
        const String.fromEnvironment(
          'APP_NAME',
          defaultValue: 'WorkInsight Tracker',
        ),
      );

  static String get apiBaseUrl => _value(
        'API_BASE_URL',
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://127.0.0.1:8000/api/',
        ),
      );

  /// Resolves an API endpoint against the configured server base, appending
  /// `/api/` exactly once when the configured URL is only an origin.
  static Uri apiUri(String endpoint) {
    final configured = Uri.parse(apiBaseUrl.trim());
    final basePath = configured.path.replaceFirst(RegExp(r'/+$'), '');
    final apiPath = basePath.endsWith('/api') ? basePath : '$basePath/api';
    return configured.replace(path: '$apiPath/').resolve(endpoint);
  }

  static String get _resolvedRaw {
    final fromFile = _fileValues['APP_ENV'];
    if (fromFile?.isNotEmpty == true) return fromFile!;
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
