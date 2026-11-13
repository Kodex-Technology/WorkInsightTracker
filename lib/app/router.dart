import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/core/config/feature_toggles.dart';
import 'package:witrack/core/widgets/fade_slide_page.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/features/admin/admin_screen.dart';
import 'package:witrack/features/auth/auth_controller.dart';
import 'package:witrack/features/auth/login_screen.dart';
import 'package:witrack/features/calendar/calendar_screen.dart';
import 'package:witrack/features/dashboard/dashboard_screen.dart';
import 'package:witrack/features/onboarding/permissions_screen.dart';
import 'package:witrack/features/projects/projects_screen.dart';
import 'package:witrack/features/reports/reports_screen.dart';
import 'package:witrack/features/screenshots/screenshots_screen.dart';
import 'package:witrack/features/settings/settings_screen.dart';
import 'package:witrack/features/shell/app_shell.dart';
import 'package:witrack/features/splash/splash_screen.dart';
import 'package:witrack/features/timeline/timeline_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) async {
      final auth = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login';
      final splashing = state.matchedLocation == '/splash';
      final onboarding = state.matchedLocation == '/onboarding/permissions';
      final adminRoute = state.matchedLocation.startsWith('/app/admin');

      if (auth.isLoading || splashing) return null;
      if (!auth.isAuthenticated && !loggingIn) return '/login';
      if (auth.isAuthenticated && loggingIn) {
        if (auth.user?.isDevAdmin == true) {
          return '/app/admin';
        }
        final settings = await ref.read(settingsRepositoryProvider).load();
        return settings.onboardingCompleted
            ? '/app/dashboard'
            : '/onboarding/permissions';
      }
      if (auth.isAuthenticated &&
          !onboarding &&
          auth.user?.isDevAdmin != true &&
          state.matchedLocation.startsWith('/app')) {
        final settings = await ref.read(settingsRepositoryProvider).load();
        if (!settings.onboardingCompleted) {
          return '/onboarding/permissions';
        }
      }
      if (adminRoute) {
        if (!AppEnv.allowLocalAdminTesting || auth.user?.isDevAdmin != true) {
          return '/app/dashboard';
        }
      }
      final loc = state.matchedLocation;
      // Admin accounts stay out of personal tracking surfaces.
      if (auth.user?.isDevAdmin == true) {
        const tracking = [
          '/app/dashboard',
          '/app/timeline',
          '/app/reports',
          '/app/calendar',
          '/app/projects',
        ];
        if (tracking.any(loc.startsWith)) {
          return '/app/admin';
        }
      }
      final flags = ref.read(featureTogglesProvider);
      if (loc.startsWith('/app/timeline') && !flags.isOn(FeatureId.timeline)) {
        return auth.user?.isDevAdmin == true ? '/app/admin' : '/app/dashboard';
      }
      if (loc.startsWith('/app/screenshots') &&
          !flags.isOn(FeatureId.screenshots)) {
        return auth.user?.isDevAdmin == true ? '/app/admin' : '/app/dashboard';
      }
      if (loc.startsWith('/app/reports') && !flags.isOn(FeatureId.reports)) {
        return auth.user?.isDevAdmin == true ? '/app/admin' : '/app/dashboard';
      }
      if (loc.startsWith('/app/calendar') && !flags.isOn(FeatureId.calendar)) {
        return auth.user?.isDevAdmin == true ? '/app/admin' : '/app/dashboard';
      }
      if (loc.startsWith('/app/projects') &&
          !flags.isOn(FeatureId.projectsScreen)) {
        return auth.user?.isDevAdmin == true ? '/app/admin' : '/app/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => FadeSlidePage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/permissions',
        pageBuilder: (context, state) => FadeSlidePage(
          key: state.pageKey,
          child: const PermissionsScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app/dashboard',
            pageBuilder: (context, state) => FadeSlidePage(
              key: state.pageKey,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/app/timeline',
            pageBuilder: (context, state) => FadeSlidePage(
              key: state.pageKey,
              child: const TimelineScreen(),
            ),
          ),
          GoRoute(
            path: '/app/screenshots',
            pageBuilder: (context, state) => FadeSlidePage(
              key: state.pageKey,
              child: const ScreenshotsScreen(),
            ),
          ),
          GoRoute(
            path: '/app/reports',
            pageBuilder: (context, state) => FadeSlidePage(
              key: state.pageKey,
              child: const ReportsScreen(),
            ),
          ),
          GoRoute(
            path: '/app/calendar',
            pageBuilder: (context, state) => FadeSlidePage(
              key: state.pageKey,
              child: const CalendarScreen(),
            ),
          ),
          GoRoute(
            path: '/app/projects',
            pageBuilder: (context, state) => FadeSlidePage(
              key: state.pageKey,
              child: const ProjectsScreen(),
            ),
          ),
          GoRoute(
            path: '/app/settings',
            pageBuilder: (context, state) => FadeSlidePage(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/app/admin',
            pageBuilder: (context, state) => FadeSlidePage(
              key: state.pageKey,
              child: const AdminScreen(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _authSub = _ref.listen<AuthState>(authControllerProvider, (_, _) {
      notifyListeners();
    });
    _flagsSub = _ref.listen<FeatureToggleState>(featureTogglesProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _authSub;
  late final ProviderSubscription<FeatureToggleState> _flagsSub;

  @override
  void dispose() {
    _authSub.close();
    _flagsSub.close();
    super.dispose();
  }
}
