import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/app/router.dart';
import 'package:witrack/features/auth/auth_controller.dart';

class DeepLinkService {
  DeepLinkService(this._ref);

  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  static const MethodChannel _deeplinkChannel =
      MethodChannel('com.witrack.desktop/deeplink');

  Future<void> init() async {
    if (Platform.isWindows) {
      await _registerWindowsProtocolHandlers();

      _deeplinkChannel.setMethodCallHandler((call) async {
        if (call.method == 'handleDeepLink') {
          final uriStr = call.arguments as String?;
          if (uriStr != null && uriStr.isNotEmpty) {
            final uri = Uri.tryParse(uriStr);
            if (uri != null) {
              _handleUri(uri);
            }
          }
        }
      });
    }

    try {
      for (final arg in Platform.executableArguments) {
        if (arg.contains('://')) {
          final uri = Uri.tryParse(arg);
          if (uri != null) {
            _handleUri(uri);
            break;
          }
        }
      }
    } catch (_) {}

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri),
      onError: (_) {},
    );
  }

  void dispose() {
    _sub?.cancel();
    if (Platform.isWindows) {
      _deeplinkChannel.setMethodCallHandler(null);
    }
  }

  void _handleUri(Uri uri) {
    final token = uri.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      _ref.read(authControllerProvider.notifier).handlePortalToken(token);
    } else if (uri.host == 'login' || uri.path == '/login' || uri.toString().contains('login')) {
      try {
        _ref.read(routerProvider).go('/login');
      } catch (_) {}
    }
  }

  Future<void> _registerWindowsProtocolHandlers() async {
    try {
      final exePath = Platform.resolvedExecutable;
      for (final scheme in ['witrack', 'workinsighttracker']) {
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Classes\' + scheme,
          '/ve',
          '/d',
          'URL:WorkInsight Tracker Protocol',
          '/f',
        ]);
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Classes\' + scheme,
          '/v',
          'URL Protocol',
          '/d',
          '',
          '/f',
        ]);
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Classes\' + scheme + r'\shell\open\command',
          '/ve',
          '/d',
          '"$exePath" "%1"',
          '/f',
        ]);
      }
    } catch (_) {}
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});
