import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

/// Stops tracking when the desktop process is really leaving (not minimize).
class TrackingLifecycleScope extends ConsumerStatefulWidget {
  const TrackingLifecycleScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TrackingLifecycleScope> createState() =>
      _TrackingLifecycleScopeState();
}

class _TrackingLifecycleScopeState
    extends ConsumerState<TrackingLifecycleScope> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // detached = process exiting / window destroyed. Do not stop on hidden/paused
    // (minimize / unfocus) — user asked only for crash/close/logout.
    if (state == AppLifecycleState.detached) {
      ref.read(trackingControllerProvider.notifier).stopForExit();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
