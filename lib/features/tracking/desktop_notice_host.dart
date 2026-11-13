import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/core/config/feature_toggles.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/features/tracking/desktop_notices.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

/// Screenshot notices (idle notices fire from [TrackingController]).
class DesktopNoticeHost extends ConsumerWidget {
  const DesktopNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureTogglesProvider);

    ref.listen(
      trackingControllerProvider.select((s) => s.lastScreenshotAt),
      (prev, next) async {
        if (next == null || next == prev) return;
        if (!flags.isOn(FeatureId.screenshotNotices)) return;
        final settings = await ref.read(settingsRepositoryProvider).load();
        if (!settings.notifyOnScreenshot) return;
        await DesktopNotices.showScreenshot();
      },
    );

    return child;
  }
}
