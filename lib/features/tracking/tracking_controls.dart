import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

class TrackingControls extends ConsumerWidget {
  const TrackingControls({super.key, required this.state});

  final TrackingUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(trackingControllerProvider.notifier);
    final theme = Theme.of(context);
    final canStart = state.status.canStart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (state.status.canStart)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  backgroundColor: canStart
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: canStart ? controller.start : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Start'),
              ),
            if (state.status.canPause)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: controller.pause,
                icon: const Icon(Icons.pause_rounded, size: 18),
                label: const Text('Pause'),
              ),
            if (state.status.canResume)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: controller.resume,
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Resume'),
              ),
            if (state.status.canStop)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
                onPressed: () => _confirmStop(context, controller),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Stop'),
              ),
          ],
        ),
        if (state.status == TrackingStatus.idle) ...[
          const SizedBox(height: 8),
          Text(
            'Idle — session still running. Activity resumes automatically.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _confirmStop(
    BuildContext context,
    TrackingController controller,
  ) async {
    if (!state.status.isRunning && state.status != TrackingStatus.paused) {
      await controller.stop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop tracking?'),
        content: const Text(
          'This ends the current task segment and saves durations to Today.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.stop();
  }
}
