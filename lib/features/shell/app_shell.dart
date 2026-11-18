import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/core/config/feature_toggles.dart';
import 'package:witrack/core/constants/app_constants.dart';
import 'package:witrack/core/theme/theme_mode_provider.dart';
import 'package:witrack/core/theme/witrack_theme.dart';
import 'package:witrack/core/ui/sidebar_state.dart';
import 'package:witrack/core/widgets/brand_lockup.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static List<_NavItem> _mainNavFor(
    FeatureToggleState flags, {
    required bool isAdmin,
  }) {
    if (isAdmin) {
      // Admin: no personal tracking surfaces.
      return [
        const _NavItem(
          'Admin',
          Icons.admin_panel_settings_outlined,
          '/app/admin',
        ),
        if (flags.isOn(FeatureId.screenshots))
          const _NavItem(
            'Screenshots',
            Icons.photo_library_outlined,
            '/app/screenshots',
          ),
      ];
    }
    return [
      const _NavItem('Dashboard', Icons.grid_view_rounded, '/app/dashboard'),
      // Timeline route/screen kept; tab intentionally omitted from nav.
      if (flags.isOn(FeatureId.screenshots))
        const _NavItem(
          'Screenshots',
          Icons.photo_library_outlined,
          '/app/screenshots',
        ),
      if (flags.isOn(FeatureId.calendar))
        const _NavItem(
          'Calendar',
          Icons.calendar_month_outlined,
          '/app/calendar',
        ),
      // Projects management screen kept; sidebar entry hidden for cleaner IA.
    ];
  }

  static const _manageNav = <_NavItem>[
    _NavItem('Settings', Icons.tune_rounded, '/app/settings'),
    _NavItem('Admin', Icons.admin_panel_settings_outlined, '/app/admin'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extras = theme.extension<WitrackThemeExtras>();
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final location = GoRouterState.of(context).uri.toString();
    final status = ref.watch(
      trackingControllerProvider.select((s) => s.status),
    );
    final auth = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final width = collapsed ? 72.0 : 224.0;
    final flags = ref.watch(featureTogglesProvider);
    final isAdmin = auth.user?.isAdmin == true;
    final mainNav = _mainNavFor(flags, isAdmin: isAdmin);
    final title = _titleFor(location, mainNav);
    final showAdmin = isAdmin;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: width,
            color: extras?.sidebarBg ?? theme.colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    collapsed ? 14 : 16,
                    16,
                    collapsed ? 14 : 12,
                    12,
                  ),
                  child: collapsed
                      ? const Center(
                          child: BrandLockup(markSize: 30, compact: true),
                        )
                      : const SizedBox(
                          width: double.infinity,
                          child: BrandLockup(markSize: 34),
                        ),
                ),
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('MAIN', style: theme.textTheme.labelSmall),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final item in mainNav)
                        _NavTile(
                          item: item,
                          selected: location.startsWith(item.path),
                          collapsed: collapsed,
                          onTap: () => context.go(item.path),
                        ),
                      const SizedBox(height: 12),
                      if (!collapsed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: Text(
                            'MANAGE',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      for (final item in _manageNav)
                        if ((item.path == '/app/settings' && !isAdmin) ||
                            (item.path == '/app/admin' && isAdmin))
                          _NavTile(
                            item: item,
                            selected: location.startsWith(item.path),
                            collapsed: collapsed,
                            onTap: () => context.go(item.path),
                          ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: collapsed
                      ? Tooltip(
                          message: status.label,
                          child: Icon(
                            Icons.circle,
                            size: 10,
                            color: _statusColor(status),
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: _statusColor(status),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                status.label,
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      if (auth.user?.profileImage != null &&
                          auth.user!.profileImage!.isNotEmpty)
                        CircleAvatar(
                          radius: collapsed ? 14 : 16,
                          backgroundImage: NetworkImage(auth.user!.profileImage!),
                        )
                      else
                        CircleAvatar(
                          radius: collapsed ? 14 : 16,
                          backgroundColor: theme.colorScheme.primary
                              .withValues(alpha: 0.15),
                          child: Text(
                            (auth.user?.displayName ?? 'A').isNotEmpty
                                ? auth.user!.displayName[0].toUpperCase()
                                : 'A',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                auth.user?.displayName ?? 'Account',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (auth.user?.organization != null ||
                                  auth.user?.designation != null)
                                Text(
                                  [
                                    if (auth.user?.organization != null)
                                      auth.user!.organization!,
                                    if (auth.user?.designation != null)
                                      auth.user!.designation!,
                                  ].join(' • '),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: collapsed
                            ? 'Expand sidebar'
                            : 'Collapse sidebar',
                        onPressed: () => ref
                            .read(sidebarCollapsedProvider.notifier)
                            .toggle(),
                        icon: Icon(
                          collapsed
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: theme.dividerColor),
          Expanded(
            child: Column(
              children: [
                _DesktopTopBar(
                  title: title,
                  status: status,
                  themeMode: themeMode,
                  isDevAdmin: auth.user?.isDevAdmin == true,
                  email: auth.user?.email ?? '',
                  onToggleTheme: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  onSignOut: () async {
                    await ref
                        .read(trackingControllerProvider.notifier)
                        .stopForExit();
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
                Divider(height: 1, color: theme.dividerColor),
                Expanded(
                  child: ClipRect(
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(String location, List<_NavItem> mainNav) {
    for (final item in [...mainNav, ..._manageNav]) {
      if (location.startsWith(item.path)) return item.label;
    }
    return AppConstants.appName;
  }

  Color _statusColor(TrackingStatus status) {
    return switch (status) {
      TrackingStatus.tracking => const Color(0xFF16A34A),
      TrackingStatus.idle => const Color(0xFFD97706),
      TrackingStatus.paused => const Color(0xFF0284C7),
      TrackingStatus.error => const Color(0xFFE11D48),
      _ => const Color(0xFF94A3B8),
    };
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.status,
    required this.themeMode,
    required this.isDevAdmin,
    required this.email,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  final String title;
  final TrackingStatus status;
  final ThemeMode themeMode;
  final bool isDevAdmin;
  final String email;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = theme.extension<WitrackThemeExtras>();
    final accent = theme.colorScheme.primary;

    return Material(
      color: extras?.topBarBg ?? theme.colorScheme.surface,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: theme.textTheme.titleLarge!,
                child: Text(title),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat.yMMMEd().format(DateTime.now()),
                style: theme.textTheme.bodySmall,
              ),
              if (AppEnv.isDevelopment) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    isDevAdmin ? 'Development Admin' : 'Development',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.55),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: _statusColor(status)),
                    const SizedBox(width: 6),
                    Text(status.label, style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: themeMode == ThemeMode.dark
                    ? 'Light theme'
                    : 'Dark theme',
                onPressed: onToggleTheme,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 18,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Account',
                onSelected: (value) async {
                  if (value == 'logout') await onSignOut();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(enabled: false, child: Text(email)),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('Sign out'),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.account_circle_outlined, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(TrackingStatus status) {
    return switch (status) {
      TrackingStatus.tracking => const Color(0xFF16A34A),
      TrackingStatus.idle => const Color(0xFFD97706),
      TrackingStatus.paused => const Color(0xFF0284C7),
      TrackingStatus.error => const Color(0xFFE11D48),
      _ => const Color(0xFF94A3B8),
    };
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = theme.extension<WitrackThemeExtras>();
    final accent = theme.colorScheme.primary;
    final bg = selected
        ? (extras?.navActive ?? accent.withValues(alpha: 0.12))
        : Colors.transparent;
    final fg = selected ? accent : theme.colorScheme.onSurfaceVariant;

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.28)
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: accent.withValues(alpha: 0.06),
            child: SizedBox(
              height: 38,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: Icon(item.icon, size: 18, color: fg),
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: fg,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (collapsed) {
      return Tooltip(message: item.label, child: tile);
    }
    return tile;
  }
}
