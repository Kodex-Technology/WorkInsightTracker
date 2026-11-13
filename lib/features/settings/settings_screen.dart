import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/core/theme/theme_mode_provider.dart';
import 'package:witrack/core/ui/sidebar_state.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/data/settings/settings_repository.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/platform/tracking_engine.dart';

final settingsProvider = FutureProvider<TrackingSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).load();
});

final diagnosticsProvider = FutureProvider<PermissionStatusSnapshot>((ref) {
  return ref.watch(trackingEngineProvider).permissionStatus();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _section = 'General';

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(settingsProvider);
    final isAdmin = ref.watch(authControllerProvider).user?.isDevAdmin == true &&
        AppEnv.allowLocalAdminTesting;
    final sections = <String>[
      'General',
      'Tracking',
      'Appearance',
      'Privacy',
      'Diagnostics',
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 200,
                child: WitrackSurface(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (final section in sections)
                        ListTile(
                          dense: true,
                          selected: _section == section,
                          title: Text(section),
                          onTap: () => setState(() => _section = section),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: asyncSettings.when(
                  skipLoadingOnReload: true,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Failed to load settings: $e'),
                  data: (settings) => _SettingsBody(
                    section: _section,
                    settings: settings,
                    isAdmin: isAdmin,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({
    required this.section,
    required this.settings,
    required this.isAdmin,
  });

  final String section;
  final TrackingSettings settings;
  final bool isAdmin;

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late TrackingSettings _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
  }

  @override
  void didUpdateWidget(covariant _SettingsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _draft = widget.settings;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).save(_draft);
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local tracking preferences saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final diagnostics = ref.watch(diagnosticsProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final section = widget.section;
    final isAdmin = widget.isAdmin;

    return WitrackSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(section, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (section == 'General') ...[
            Text(
              'Local-first desktop tracker for this device. '
              'Tracking preferences are edited under Tracking.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _InfoRow('Idle threshold', '${_draft.idleThresholdMinutes} min'),
            _InfoRow(
              'Screenshots',
              _draft.screenshotEnabled
                  ? 'Every ${_draft.screenshotIntervalMinutes} min'
                  : 'Disabled',
            ),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: () => context.go('/app/admin'),
                  child: const Text('Open Admin Panel'),
                ),
              ),
            ],
          ],
          if (section == 'Tracking') ...[
            Text(
              'Device preferences stored locally on this machine.',
              style: theme.textTheme.bodySmall,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Screenshots enabled'),
              value: _draft.screenshotEnabled,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(screenshotEnabled: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Screenshot interval'),
              subtitle: Text('${_draft.screenshotIntervalMinutes} minutes'),
            ),
            Slider(
              // Policy: 1, 5, 10, 15 minutes (admin/testing can use 1).
              value: _nearestShotInterval(
                _draft.screenshotIntervalMinutes,
              ).toDouble(),
              min: 1,
              max: 15,
              divisions: 14,
              label: '${_nearestShotInterval(_draft.screenshotIntervalMinutes)} min',
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(
                  screenshotIntervalMinutes: _nearestShotInterval(v.round()),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Idle threshold'),
              subtitle: Text('${_draft.idleThresholdMinutes} minutes'),
            ),
            Slider(
              value: _draft.idleThresholdMinutes.toDouble().clamp(1, 30),
              min: 1,
              max: 30,
              divisions: 29,
              label: '${_draft.idleThresholdMinutes}',
              onChanged: (v) => setState(
                () => _draft =
                    _draft.copyWith(idleThresholdMinutes: v.round()),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notify on screenshot'),
              value: _draft.notifyOnScreenshot,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(notifyOnScreenshot: v),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Collect window titles'),
              subtitle: const Text('Off by default for privacy'),
              value: _draft.collectWindowTitles,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(collectWindowTitles: v),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save preferences'),
              ),
            ),
          ],
          if (section == 'Appearance') ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Theme'),
              subtitle: Text(
                'Light, dark, or follow system',
                style: theme.textTheme.bodySmall,
              ),
            ),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ],
              selected: {themeMode},
              onSelectionChanged: (value) {
                ref.read(themeModeProvider.notifier).setMode(value.first);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Collapsed sidebar'),
              subtitle: Text(
                'Remember compact navigation',
                style: theme.textTheme.bodySmall,
              ),
              value: collapsed,
              onChanged: (v) =>
                  ref.read(sidebarCollapsedProvider.notifier).setCollapsed(v),
            ),
          ],
          if (section == 'Privacy') ...[
            _InfoRow(
              'Window titles',
              _draft.collectWindowTitles ? 'Collecting' : 'Not collected',
            ),
            const SizedBox(height: 8),
            Text(
              'WorkInsight Tracker never stores typed text, passwords, or clipboard contents.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (section == 'Diagnostics') ...[
            diagnostics.when(
              skipLoadingOnReload: true,
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (p) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Screen capture: ${p.screenCapture}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'Accessibility: ${p.accessibility}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(p.notes, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    'Env: ${AppEnv.modeLabel}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Snap to policy options: 1, 5, 10, 15.
int _nearestShotInterval(int minutes) {
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

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
