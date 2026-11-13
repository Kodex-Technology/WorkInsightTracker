import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/platform/tracking_engine.dart';

final permissionSnapshotProvider = FutureProvider<PermissionStatusSnapshot>((
  ref,
) {
  return ref.watch(trackingEngineProvider).permissionStatus();
});

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_requestPermissions);
  }

  Future<void> _requestPermissions() async {
    await ref.read(trackingEngineProvider).requestPermissions(prompt: true);
    if (!mounted) return;
    ref.invalidate(permissionSnapshotProvider);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(permissionSnapshotProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: snapshot.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Permission check failed: $e'),
                  data: (status) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Permissions',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'WorkInsight Tracker requests only the capabilities needed for '
                        'authorized tracking. No typed text or clipboard data is collected.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      _PermissionRow(
                        title: 'Screen capture',
                        status: status.screenCapture,
                        why: 'Used for screenshots during authorized tracking sessions.',
                      ),
                      const SizedBox(height: 12),
                      _PermissionRow(
                        title: 'Accessibility / input monitoring',
                        status: status.accessibility,
                        why: 'Only if required by the OS for idle/activity signals.',
                      ),
                      const SizedBox(height: 16),
                      Text(status.notes, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _requestPermissions,
                            child: const Text('Request now'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () =>
                                ref.invalidate(permissionSnapshotProvider),
                            child: const Text('Recheck'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () async {
                              final current = await ref
                                  .read(settingsRepositoryProvider)
                                  .load();
                              await ref
                                  .read(settingsRepositoryProvider)
                                  .save(
                                    current.copyWith(onboardingCompleted: true),
                                  );
                              if (context.mounted) {
                                context.go('/app/dashboard');
                              }
                            },
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.status,
    required this.why,
  });

  final String title;
  final String status;
  final String why;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(why),
      trailing: Text(status),
    );
  }
}
