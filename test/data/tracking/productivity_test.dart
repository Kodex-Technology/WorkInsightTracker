import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/data/tracking/productivity.dart';

void main() {
  test('productivity percent clamps empty samples to 0', () {
    expect(productivityPercent(activeSamples: 0, totalSamples: 0), 0);
    expect(productivityPercent(activeSamples: 3, totalSamples: 4), 75);
  });

  test('metadata round-trip keeps event detail', () {
    final original = ScreenshotProductivity(
      percent: 80,
      activeSamples: 8,
      totalSamples: 10,
      inputPulses: 8,
      appSwitches: 2,
      idleEnters: 1,
      windowStart: DateTime.utc(2026, 11, 13, 10),
      windowEnd: DateTime.utc(2026, 11, 13, 10, 10),
      events: [
        ProductivityEvent(
          at: DateTime.utc(2026, 11, 13, 10, 5),
          type: 'app_switch',
          label: 'Chrome',
        ),
      ],
      apps: const [AppFocusStat(name: 'Chrome', count: 2)],
    );
    final parsed = ScreenshotProductivity.tryParse(jsonEncode(original.toJson()));
    expect(parsed, isNotNull);
    expect(parsed!.percent, 80);
    expect(parsed.appSwitches, 2);
    expect(parsed.events.single.label, 'Chrome');
    expect(ScreenshotProductivity.averagePercent([parsed, null]), 80);
  });
}
