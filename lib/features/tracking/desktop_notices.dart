import 'package:flutter/services.dart';

/// Native separate-window toasts (Windows HWND / macOS NSPanel).
class DesktopNotices {
  DesktopNotices._();

  static const _channel = MethodChannel('com.witrack.desktop/tracking');
  static DateTime? _lastIdleAt;
  static DateTime? _lastScreenshotAt;

  static Future<void> showIdle() => _show(
        kind: 'idle',
        title: 'You’re idle',
        body: 'Idle time is counting. Move or type to go Active.',
        lastAt: _lastIdleAt,
        cooldown: const Duration(seconds: 30),
        mark: (t) => _lastIdleAt = t,
      );

  static Future<void> showScreenshot() => _show(
        kind: 'screenshot',
        title: 'Screenshot saved',
        body: 'Stored securely — open Screenshots to review.',
        lastAt: _lastScreenshotAt,
        cooldown: const Duration(seconds: 15),
        mark: (t) => _lastScreenshotAt = t,
      );

  static Future<void> _show({
    required String kind,
    required String title,
    required String body,
    required DateTime? lastAt,
    required Duration cooldown,
    required void Function(DateTime) mark,
  }) async {
    final now = DateTime.now();
    if (lastAt != null && now.difference(lastAt) < cooldown) return;
    mark(now);
    try {
      await _channel.invokeMethod<void>('showDesktopNotice', {
        'kind': kind,
        'title': title,
        'body': body,
        'durationMs': 7000,
      });
    } catch (_) {}
  }
}
