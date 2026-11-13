import 'dart:convert';

/// Interval productivity + event summary stored on screenshot `metadataJson`.
/// Soft-parsed — unknown fields never crash the UI.
class ScreenshotProductivity {
  const ScreenshotProductivity({
    required this.percent,
    required this.activeSamples,
    required this.totalSamples,
    required this.inputPulses,
    required this.appSwitches,
    required this.idleEnters,
    required this.windowStart,
    required this.windowEnd,
    this.events = const [],
    this.apps = const [],
  });

  final double percent;
  final int activeSamples;
  final int totalSamples;

  /// Count of 10s windows with recent input (not raw mouse clicks).
  final int inputPulses;
  final int appSwitches;
  final int idleEnters;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<ProductivityEvent> events;
  final List<AppFocusStat> apps;

  Map<String, Object?> toJson() => {
        'productivityPercent': percent,
        'activeSamples': activeSamples,
        'totalSamples': totalSamples,
        'inputPulses': inputPulses,
        'appSwitches': appSwitches,
        'idleEnters': idleEnters,
        'windowStartMs': windowStart.toUtc().millisecondsSinceEpoch,
        'windowEndMs': windowEnd.toUtc().millisecondsSinceEpoch,
        'events': events.map((e) => e.toJson()).toList(),
        'apps': apps.map((a) => a.toJson()).toList(),
      };

  static ScreenshotProductivity? tryParse(String? metadataJson) {
    if (metadataJson == null || metadataJson.isEmpty) return null;
    try {
      final raw = jsonDecode(metadataJson);
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final percent = (map['productivityPercent'] as num?)?.toDouble();
      if (percent == null) return null;
      final startMs = map['windowStartMs'] as int?;
      final endMs = map['windowEndMs'] as int?;
      final eventsRaw = map['events'];
      final appsRaw = map['apps'];
      return ScreenshotProductivity(
        percent: percent.clamp(0, 100),
        activeSamples: map['activeSamples'] as int? ?? 0,
        totalSamples: map['totalSamples'] as int? ?? 0,
        inputPulses: map['inputPulses'] as int? ?? map['activeSamples'] as int? ?? 0,
        appSwitches: map['appSwitches'] as int? ?? 0,
        idleEnters: map['idleEnters'] as int? ?? 0,
        windowStart: startMs != null
            ? DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true)
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        windowEnd: endMs != null
            ? DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true)
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        events: eventsRaw is List
            ? eventsRaw
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (e) => ProductivityEvent.tryParse(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .whereType<ProductivityEvent>()
                .toList()
            : const [],
        apps: appsRaw is List
            ? appsRaw
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (e) => AppFocusStat.tryParse(Map<String, dynamic>.from(e)),
                )
                .whereType<AppFocusStat>()
                .toList()
            : const [],
      );
    } catch (_) {
      return null;
    }
  }

  static double averagePercent(Iterable<ScreenshotProductivity?> items) {
    final vals = items.whereType<ScreenshotProductivity>().map((e) => e.percent);
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}

class ProductivityEvent {
  const ProductivityEvent({
    required this.at,
    required this.type,
    this.label,
  });

  final DateTime at;
  final String type;
  final String? label;

  Map<String, Object?> toJson() => {
        'atMs': at.toUtc().millisecondsSinceEpoch,
        'type': type,
        if (label != null) 'label': label,
      };

  static ProductivityEvent? tryParse(Map<String, dynamic> map) {
    final atMs = map['atMs'] as int?;
    final type = map['type'] as String?;
    if (atMs == null || type == null) return null;
    return ProductivityEvent(
      at: DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true),
      type: type,
      label: map['label'] as String?,
    );
  }

  String get title {
    switch (type) {
      case 'app_switch':
        return 'App switch';
      case 'idle_enter':
        return 'Became idle';
      case 'idle_exit':
        return 'Back to active';
      case 'input_pulse':
        return 'Input activity';
      case 'state:tracking':
        return 'Tracking';
      case 'state:idle':
        return 'Idle';
      case 'state:paused':
        return 'Paused';
      case 'screenshot':
      case 'screenshot_test':
        return 'Screenshot';
      default:
        if (type.startsWith('state:')) {
          return type.substring(6);
        }
        return type;
    }
  }
}

class AppFocusStat {
  const AppFocusStat({required this.name, required this.count});

  final String name;
  final int count;

  Map<String, Object?> toJson() => {'name': name, 'count': count};

  static AppFocusStat? tryParse(Map<String, dynamic> map) {
    final name = map['name'] as String?;
    final count = map['count'] as int?;
    if (name == null || count == null) return null;
    return AppFocusStat(name: name, count: count);
  }
}

double productivityPercent({
  required int activeSamples,
  required int totalSamples,
}) {
  if (totalSamples <= 0) return 0;
  return (activeSamples / totalSamples) * 100.0;
}
