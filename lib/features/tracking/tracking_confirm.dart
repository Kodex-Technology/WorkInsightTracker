import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/core/config/feature_toggles.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

bool timerIsOpen(TrackingUiState s) =>
    s.status == TrackingStatus.tracking ||
    s.status == TrackingStatus.idle ||
    s.status == TrackingStatus.paused;

/// Office rule: if a timer is running, ask before stopping it for complete/delete.
/// Returns `false` when the user cancels. When confirmed (or no open timer), stops then returns `true`.
Future<bool> confirmAndStopOpenTimer({
  required BuildContext context,
  required WidgetRef ref,
  required String actionLabel,
}) async {
  final state = ref.read(trackingControllerProvider);
  if (!timerIsOpen(state)) return true;

  final ask = ref
      .read(featureTogglesProvider)
      .isOn(FeatureId.confirmStopBeforeMutate);
  if (!ask) {
    await ref.read(trackingControllerProvider.notifier).stopBeforeMutate();
    return true;
  }

  final project = state.projectName ?? 'project';
  final task = state.taskName ?? 'task';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Stop current timer?'),
      content: Text(
        'A timer is running on “$project · $task”.\n\n'
        'Stop it and save progress to Today (all work) before you $actionLabel?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep tracking'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Stop & continue'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(trackingControllerProvider.notifier).stopBeforeMutate();
  return true;
}

/// Ask before starting or switching a task. Day total continues on switch.
Future<bool> confirmTaskFocusIfNeeded({
  required BuildContext context,
  required WidgetRef ref,
  required String nextProjectName,
  required String nextTaskName,
}) async {
  final state = ref.read(trackingControllerProvider);
  final ask =
      ref.read(featureTogglesProvider).isOn(FeatureId.confirmTaskSwitch);

  if (!timerIsOpen(state)) {
    if (!ask) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start this task?'),
        content: Text(
          'Are you sure you want to start “$nextProjectName · $nextTaskName”?\n\n'
          'Tracking will begin on this task until you pause, stop, or switch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start task'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  if (!ask) return true;

  final currentProject = state.projectName ?? 'project';
  final currentTask = state.taskName ?? 'task';
  if (state.projectName == nextProjectName && state.taskName == nextTaskName) {
    return true;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Switch task timer?'),
      content: Text(
        'Current task “$currentProject · $currentTask” will end for this segment.\n\n'
        'Today (all work) total will keep counting — only this task’s open timer closes.\n\n'
        'Switch to “$nextProjectName · $nextTaskName”?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep current'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Switch task'),
        ),
      ],
    ),
  );
  return ok == true;
}
