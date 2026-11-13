import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/core/config/feature_toggles.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/data/settings/settings_repository.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

final registeredUsersProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(authRepositoryProvider).watchRegisteredUsers();
});

/// Admin console — users, screenshot policy, feature flags.
/// No personal tracking dashboard (timer / projects / reports).
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  TrackingSettings? _draft;
  bool _savingShot = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSettings);
  }

  Future<void> _loadSettings() async {
    final s = await ref.read(settingsRepositoryProvider).load();
    if (mounted) setState(() => _draft = s);
  }

  Future<void> _saveScreenshotPolicy() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _savingShot = true);
    await ref.read(settingsRepositoryProvider).save(draft);
    await ref.read(trackingControllerProvider.notifier).reloadSettings();
    if (mounted) {
      setState(() => _savingShot = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Screenshot interval set to ${draft.screenshotIntervalMinutes} min',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final toggles = ref.watch(featureTogglesProvider);
    final users = ref.watch(registeredUsersProvider);
    final draft = _draft;

    if (!AppEnv.allowLocalAdminTesting || auth.user?.isDevAdmin != true) {
      return Center(
        child: WitrackSurface(
          margin: const EdgeInsets.all(24),
          child: Text(
            AppEnv.isProduction
                ? 'Production admin requires a trusted identity provider (deferred).'
                : 'Local admin testing requires the Development Admin account.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            WitrackSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin console', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Manage registered users, screenshot capture timing, and feature flags. '
                    'Personal tracking (timer / projects / reports) is for user accounts — not shown here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            WitrackSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Registered users', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Local DB accounts for testing. Future API can replace this list.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  users.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e'),
                    data: (rows) {
                      if (rows.isEmpty) {
                        return Text(
                          'No users registered yet.',
                          style: theme.textTheme.bodyMedium,
                        );
                      }
                      return Column(
                        children: [
                          for (final u in rows)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                child: Text(
                                  u.displayName.isNotEmpty
                                      ? u.displayName[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(u.displayName),
                              subtitle: Text(
                                '${u.email} · ${u.authProvider ?? 'local'} · '
                                '${DateFormat.yMMMd().add_Hm().format(u.createdAt.toLocal())}',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            WitrackSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Screenshot capture',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Interval while users are tracking (1–15 min). Applies on this device.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (draft == null)
                    const LinearProgressIndicator()
                  else ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Screenshots enabled'),
                      value: draft.screenshotEnabled,
                      onChanged: (v) => setState(
                        () => _draft = draft.copyWith(screenshotEnabled: v),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notify on screenshot capture'),
                      subtitle: const Text(
                        'Show a side toast when a shot is saved (also needs Feature flag).',
                      ),
                      value: draft.notifyOnScreenshot,
                      onChanged: (v) => setState(
                        () => _draft = draft.copyWith(notifyOnScreenshot: v),
                      ),
                    ),
                    Text(
                      'Every ${_snapShot(draft.screenshotIntervalMinutes)} min',
                      style: theme.textTheme.titleSmall,
                    ),
                    Slider(
                      value: _snapShot(draft.screenshotIntervalMinutes)
                          .toDouble(),
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: '${_snapShot(draft.screenshotIntervalMinutes)} min',
                      onChanged: (v) => setState(
                        () => _draft = draft.copyWith(
                          screenshotIntervalMinutes: _snapShot(v.round()),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _savingShot ? null : _saveScreenshotPolicy,
                        child: Text(_savingShot ? 'Saving…' : 'Save capture policy'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/app/screenshots'),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Open screenshots gallery'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            WitrackSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Feature flags', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Toggle optional modules. Tracking core stays on.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (final id in FeatureId.values) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(id.title),
                      subtitle: Text(id.subtitle),
                      value: toggles.isOn(id),
                      onChanged: id.isMaster
                          ? null
                          : (v) => ref
                              .read(featureTogglesProvider.notifier)
                              .setEnabled(id, v),
                    ),
                    if (id != FeatureId.values.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _snapShot(int minutes) {
    const options = [1, 5, 10, 15];
    var best = options.first;
    var bestDist = (minutes - best).abs();
    for (final o in options.skip(1)) {
      final d = (minutes - o).abs();
      if (d < bestDist) {
        best = o;
        bestDist = d;
      }
    }
    return best;
  }
}
