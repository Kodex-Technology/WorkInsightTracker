import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/core/constants/app_constants.dart';
import 'package:witrack/core/widgets/witrack_mark.dart';
import 'package:witrack/features/auth/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (!next.isAuthenticated) return;
      // Let GoRouter redirect pick admin vs dashboard/onboarding.
      if (next.user?.isDevAdmin == true) {
        context.go('/app/admin');
      } else {
        context.go('/app/dashboard');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: WitrackMark(size: 48, showGlow: true)),
                      const SizedBox(height: 10),
                      Text(
                        AppConstants.brandPrimary,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        AppConstants.brandSecondary,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Sign in to ${AppConstants.appName}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppEnv.isDevelopment
                            ? 'Development mode — local identities only.'
                            : 'Production authentication is not configured yet.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (AppEnv.allowLocalDevAuth) ...[
                        FilledButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => ref
                                  .read(authControllerProvider.notifier)
                                  .signInLocalDev(),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Continue as developer'),
                        ),
                        if (AppEnv.allowLocalAdminTesting) ...[
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInLocalAdmin(),
                            child: const Text('Development Admin'),
                          ),
                        ],
                      ] else ...[
                        Text(
                          'Fail closed: configure a production identity provider later.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                      if (auth.error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          auth.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
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
      ),
    );
  }
}
