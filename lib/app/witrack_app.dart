import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/app/router.dart';
import 'package:witrack/core/constants/app_constants.dart';
import 'package:witrack/core/theme/theme_mode_provider.dart';
import 'package:witrack/core/theme/witrack_theme.dart';
import 'package:witrack/features/tracking/desktop_notice_host.dart';
import 'package:witrack/features/tracking/tracking_lifecycle.dart';

class WitrackApp extends ConsumerWidget {
  const WitrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return TrackingLifecycleScope(
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: WitrackTheme.light(),
        darkTheme: WitrackTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) {
          return DesktopNoticeHost(
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
