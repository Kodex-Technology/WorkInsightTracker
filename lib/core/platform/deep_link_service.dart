import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/app/router.dart';
import 'package:witrack/features/auth/auth_controller.dart';

class PortalLoginCallback {
  const PortalLoginCallback({
    required this.token,
    this.roleType,
    this.userData,
    this.status,
    this.message,
  });

  final String? token;
  final String? roleType;
  final Map<String, dynamic>? userData;
  final String? status;
  final String? message;

  bool get isCancelled {
    final s = status?.trim().toLowerCase();
    if (s == 'cancelled' || s == 'cancel') return true;
    if (message != null && message!.toLowerCase().contains('cancel')) return true;
    return false;
  }

  bool get hasToken =>
      token != null &&
      token!.trim().isNotEmpty &&
      token != 'null' &&
      token != 'undefined';
}

PortalLoginCallback? parsePortalLoginCallback(Uri uri) {
  const schemes = {'witrack', 'workinsighttracker'};
  if (!schemes.contains(uri.scheme.toLowerCase())) return null;

  final isLoginCallback =
      uri.host.toLowerCase() == 'login' ||
      (uri.host.isEmpty && uri.path.toLowerCase() == '/login');
  if (!isLoginCallback) return null;

  final parameters = uri.queryParameters;
  String? firstValue(Iterable<String> names) {
    for (final name in names) {
      final value = parameters[name]?.trim();
      if (value != null &&
          value.isNotEmpty &&
          value != 'null' &&
          value != 'undefined') {
        return value;
      }
    }
    return null;
  }

  final status = firstValue(
    const ['status', 'state', 'result', 'code', 'error'],
  );

  final message = firstValue(
    const ['message', 'msg', 'error_description', 'error_message', 'reason', 'details'],
  );

  Map<String, dynamic>? tryParseJsonMap(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || trimmed == '[object Object]') return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (trimmed.contains('%')) {
      try {
        final decodedUrl = Uri.decodeComponent(trimmed);
        final decoded = jsonDecode(decodedUrl);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        // The normal Uri parser already decodes query parameters.
      } catch (_) {}
    }

    return null;
  }

  Map<String, dynamic>? userData;
  final rawUserData = firstValue(
    const ['user_data', 'userData', 'user', 'data', 'payload', 'profile'],
  );
  if (rawUserData != null) {
    userData = tryParseJsonMap(rawUserData);
    if (userData == null && rawUserData != '[object Object]') {
      throw const FormatException('Invalid userData JSON.');
    }
  }

  final email = userData?['email']?.toString() ??
      userData?['user_email']?.toString() ??
      userData?['email_address']?.toString() ??
      firstValue(const ['email', 'user_email', 'email_address']);

  final firstName = userData?['first_name']?.toString() ??
      userData?['firstName']?.toString() ??
      firstValue(const ['first_name', 'firstName']);

  final lastName = userData?['last_name']?.toString() ??
      userData?['lastName']?.toString() ??
      firstValue(const ['last_name', 'lastName']);

  final name = userData?['name']?.toString() ??
      userData?['display_name']?.toString() ??
      userData?['displayName']?.toString() ??
      userData?['full_name']?.toString() ??
      userData?['fullName']?.toString() ??
      firstValue(
        const ['name', 'display_name', 'displayName', 'full_name', 'fullName'],
      );

  final roleType = firstValue(
        const ['role_type', 'roleType', 'role', 'user_role'],
      ) ??
      userData?['role_type']?.toString() ??
      userData?['roleType']?.toString() ??
      userData?['role']?.toString() ??
      userData?['user_role']?.toString();

  final department = userData?['department']?.toString() ??
      userData?['sub_department']?.toString() ??
      firstValue(const ['department', 'sub_department']);

  final designation = userData?['designation']?.toString() ??
      userData?['designation_name']?.toString() ??
      firstValue(const ['designation', 'designation_name']);

  final organization = userData?['organization']?.toString() ??
      userData?['org_name']?.toString() ??
      firstValue(const ['organization', 'org_name']);

  return PortalLoginCallback(
    token: firstValue(const ['token', 'access_token', 'accessToken']),
    status: status,
    message: message,
    roleType: userData?['user_role'] is Map
        ? (userData?['user_role'] as Map)['role_type']?.toString()
        : firstValue(const ['role_type', 'roleType', 'role']),
    userData: userData ?? (
      parameters.keys.isNotEmpty &&
      (parameters['email'] != null ||
       parameters['first_name'] != null ||
       parameters['name'] != null)
        ? <String, dynamic>{
            if (email != null) 'email': email,
            if (firstName != null) 'first_name': firstName,
            if (lastName != null) 'last_name': lastName,
            if (name != null) 'name': name,
            if (department != null) 'department': department,
            if (designation != null) 'designation': designation,
            if (organization != null) 'organization': organization,
          }
        : null),
  );
}

class DeepLinkService {
  DeepLinkService(this._ref);

  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  final List<PortalLoginCallback> _pendingCallbacks = [];
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;
  bool _disposed = false;
  bool _deliveringCallbacks = false;
  int? _lastCallbackFingerprint;
  DateTime? _lastCallbackAt;

  static const MethodChannel _deeplinkChannel = MethodChannel(
    'com.witrack.desktop/deeplink',
  );

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('Deep link service initialized');

    if (Platform.isWindows) {
      _deeplinkChannel.setMethodCallHandler(_handleNativeCall);
      try {
        final pendingLinks = await _deeplinkChannel.invokeListMethod<String>(
          'startListening',
        );
        for (final link in pendingLinks ?? const <String>[]) {
          _handleLinkString(link);
        }
      } on PlatformException catch (error) {
        debugPrint('Could not start Windows deep-link listener: $error');
      } on MissingPluginException catch (error) {
        debugPrint('Windows deep-link channel is unavailable: $error');
      } catch (error, stackTrace) {
        debugPrint('Could not start the Windows deep-link listener: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      unawaited(_registerWindowsProtocolHandlers());
    }

    try {
      _sub = _appLinks.uriLinkStream.listen(
        _handleUri,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Deep-link stream error: ${error.runtimeType}');
          debugPrintStack(stackTrace: stackTrace);
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Could not subscribe to deep-link updates: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      for (final arg in Platform.executableArguments) {
        if (arg.contains('://')) {
          _handleLinkString(arg);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Could not inspect startup deep-link arguments: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (error, stackTrace) {
      debugPrint('Could not read the initial deep link: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel() ?? Future<void>.value());
    if (Platform.isWindows) {
      _deeplinkChannel.setMethodCallHandler(null);
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'handleDeepLink') return;

    final link = call.arguments;
    if (link is! String || link.isEmpty) {
      debugPrint('Windows sent an empty or invalid deep-link callback');
      return;
    }
    debugPrint('Windows deep-link callback received');
    _handleLinkString(link);
  }

  void _handleLinkString(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      debugPrint('Ignoring malformed deep-link callback');
      return;
    }
    _handleUri(uri);
  }

  void _handleUri(Uri uri) {
    final token = uri.queryParameters['token'];
    final userDataStr = uri.queryParameters['userData'];
    final statusStr = uri.queryParameters['status'];
    final messageStr = uri.queryParameters['message'];
    debugPrint('========== TRACKER CALLBACK ==========');
    debugPrint('Scheme: ${uri.scheme}');
    debugPrint('Host: ${uri.host}');
    debugPrint('Path: ${uri.path}');
    debugPrint('Status parameter: $statusStr');
    debugPrint('Message parameter: $messageStr');
    debugPrint('Token parameter exists: ${token != null && token.trim().isNotEmpty}');
    debugPrint('Token length: ${token?.trim().length ?? 0}');
    debugPrint('UserData parameter exists: ${userDataStr != null}');
    debugPrint(
      userDataStr?.trim() == '[object Object]'
          ? 'UserData was not JSON-serialized by the portal.'
          : 'UserData contents omitted from logs.',
    );

    debugPrint('======================================');

    final PortalLoginCallback? callback;
    try {
      callback = parsePortalLoginCallback(uri);
    } on FormatException catch (error, stackTrace) {
      debugPrint('Malformed deep-link parameters: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }
    if (callback == null) {
      debugPrint('Ignoring unrelated deep link');
      return;
    }

    final now = DateTime.now();
    final fingerprint = uri.toString().hashCode;
    if (_lastCallbackFingerprint == fingerprint &&
        _lastCallbackAt != null &&
        now.difference(_lastCallbackAt!) < const Duration(seconds: 2)) {
      debugPrint('Ignoring duplicate portal callback');
      return;
    }
    _lastCallbackFingerprint = fingerprint;
    _lastCallbackAt = now;

    if (callback.isCancelled) {
      debugPrint('Portal authentication was cancelled: ${callback.message}');
    } else if (!callback.hasToken) {
      debugPrint('Authentication token is missing from callback.');
    } else if (callback.userData != null) {
      final userDataMap = callback.userData!;
      debugPrint('========== USER DATA RECEIVED ==========');
      debugPrint('User ID: ${userDataMap['id']}');
      debugPrint('Email: ${userDataMap['email']}');
      debugPrint('First Name: ${userDataMap['first_name']}');
      debugPrint('Last Name: ${userDataMap['last_name']}');
      final userRole = userDataMap['user_role'];
      debugPrint('Role Name: ${userRole is Map ? userRole['role_name'] : null}');
      debugPrint('Role Type: ${userRole is Map ? userRole['role_type'] : null}');
      final organization = userDataMap['organization'];
      final designation = userDataMap['designation'];
      debugPrint('Organization: ${organization is Map ? organization['name'] : organization}');
      debugPrint('Designation: ${designation is Map ? designation['designation_name'] : designation}');
      debugPrint('========================================');
      debugPrint('Token length: ${callback.token!.trim().length}');
      debugPrint('Role type received: ${callback.roleType ?? '(missing)'}');
    }

    _pendingCallbacks.add(callback);
    unawaited(_deliverCallbacks());
  }

  Future<void> _deliverCallbacks() async {
    if (_deliveringCallbacks || _disposed) return;
    _deliveringCallbacks = true;
    try {
      while (_pendingCallbacks.isNotEmpty && !_disposed) {
        final router = _ref.read(routerProvider);
        BuildContext? context;
        for (var attempt = 0; attempt < 30; attempt++) {
          context = router.routerDelegate.navigatorKey.currentContext;
          if (context != null && context.mounted) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        if (context == null || !context.mounted) {
          debugPrint('Flutter UI was not ready to display the portal callback');
          return;
        }

        final callback = _pendingCallbacks.removeAt(0);
        try {
          await _ref
              .read(authControllerProvider.notifier)
              .handlePortalCallback(callback);
        } catch (error, stackTrace) {
          debugPrint('Could not display the portal callback result: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Portal callback delivery failed: ${error.runtimeType}');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _deliveringCallbacks = false;
    }
  }

  Future<void> _registerWindowsProtocolHandlers() async {
    final exePath = Platform.resolvedExecutable;
    try {
      for (final scheme in ['witrack', 'workinsighttracker']) {
        final commandKey =
            'HKCU\\Software\\Classes\\$scheme\\shell\\open\\command';
        final existing = await Process.run('reg', ['query', commandKey, '/ve']);
        if (existing.exitCode == 0) {
          final registeredCommand = existing.stdout.toString().toLowerCase();
          if (registeredCommand.contains(exePath.toLowerCase())) continue;
          debugPrint(
            'The $scheme protocol is already registered to another app; '
            'leaving it unchanged.',
          );
          continue;
        }

        final key = 'HKCU\\Software\\Classes\\$scheme';
        final registrations = [
          ['add', key, '/ve', '/d', 'URL:WorkInsight Tracker Protocol', '/f'],
          ['add', key, '/v', 'URL Protocol', '/d', '', '/f'],
          ['add', commandKey, '/ve', '/d', '"$exePath" "%1"', '/f'],
        ];
        for (final arguments in registrations) {
          final result = await Process.run('reg', arguments);
          if (result.exitCode != 0) {
            debugPrint(
              'Could not register the $scheme protocol: '
              '${result.stderr.toString().trim()}',
            );
            break;
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Windows protocol registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  unawaited(service.init());
  ref.onDispose(service.dispose);
  return service;
});
