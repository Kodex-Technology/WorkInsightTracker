import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/app/router.dart';
import 'package:witrack/features/auth/auth_controller.dart';

class PortalLoginCallback {
  const PortalLoginCallback({required this.token, this.roleType});

  final String? token;
  final String? roleType;
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
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  return PortalLoginCallback(
    token: firstValue(const ['token', 'access_token', 'accessToken']),
    roleType: firstValue(const ['role_type', 'roleType', 'role']),
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
    debugPrint(
      'Deep-link callback received: scheme=${uri.scheme}, '
      'host=${uri.host}, path=${uri.path}',
    );

    final PortalLoginCallback? callback;
    try {
      callback = parsePortalLoginCallback(uri);
    } on FormatException catch (error) {
      debugPrint('Ignoring malformed deep-link parameters: ${error.message}');
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

    debugPrint('Token received: ${callback.token?.isNotEmpty == true}');
    debugPrint('Role type received: ${callback.roleType ?? '(missing)'}');
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
              .handlePortalLoginCallback(
                token: callback.token,
                roleType: callback.roleType,
                context: context,
              );
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
