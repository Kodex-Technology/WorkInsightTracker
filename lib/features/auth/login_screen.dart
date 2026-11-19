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
    final isDark = theme.brightness == Brightness.dark;
    final auth = ref.watch(authControllerProvider);
    final primaryAccent = theme.colorScheme.primary;

    ref.listen(authControllerProvider, (previous, next) {
      if (!next.isAuthenticated) return;
      // Let GoRouter redirect pick admin vs dashboard/onboarding.
      if (next.user?.isAdmin == true) {
        context.go('/app/admin');
      } else {
        context.go('/app/dashboard');
      }
    });

    return Scaffold(
     body: Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/images/login_background.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.45),
            BlendMode.darken,
          ),
        ),
      ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.45)
                            : primaryAccent.withValues(alpha: 0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 720;
                      if (isWide) {
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Side: Brand Showcase Pane
                            Expanded(
                              flex: 11,
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF0C1E2E).withValues(alpha: 1),
                                      const Color(0xFF071521).withValues(alpha: 0.8),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const WitrackMark(size: 64),
                                    const SizedBox(height: 24),
                                    Text(
                                      AppConstants.brandPrimary,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      AppConstants.brandSecondary.toUpperCase(),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        color: primaryAccent,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.8,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Work smarter. Track clearly.',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 36),
                                    _buildInfoRow(
                                      context,
                                      Icons.verified_user_rounded,
                                      'Privacy-First Tracking',
                                      'No keystrokes, passwords, or hidden surveillance.',
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInfoRow(
                                      context,
                                      Icons.offline_bolt_rounded,
                                      'Offline-First Drift',
                                      'Local SQLite persistence with outbox reliability.',
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInfoRow(
                                      context,
                                      Icons.desktop_windows_rounded,
                                      'Windows Native Engine',
                                      'High-performance C++ lifecycle & capture.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Right Side: Action Form Pane
                            Expanded(
                              flex: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF071521).withValues(alpha: 0.25),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: _buildLoginForm(
                                    context,
                                    ref,
                                    auth,
                                    primaryAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      } else {
                        // Stacked layout for narrow screens
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: WitrackMark(size: 56)),
                              const SizedBox(height: 16),
                              Text(
                                AppConstants.brandPrimary,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppConstants.brandSecondary.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: primaryAccent,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildLoginForm(context, ref, auth, primaryAccent),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    final primaryAccent = theme.colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: primaryAccent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(
      BuildContext context, WidgetRef ref, AuthState auth, Color primaryAccent) {
    final theme = Theme.of(context);

   
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Sign in to Session',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppEnv.isDevelopment
              ? 'Development mode is active with local developer identities.'
              : 'Production authorization gateway required.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        if (AppEnv.allowLocalDevAuth) ...[
          SizedBox(
            height: 50,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: FilledButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () => ref
                        .read(authControllerProvider.notifier)
                        .signInWithPortal(),
                icon: auth.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'Login With Portal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // if (AppEnv.allowLocalAdminTesting) ...[
          //   const SizedBox(height: 14),
          //   SizedBox(
          //     height: 48,
          //     child: MouseRegion(
          //       cursor: SystemMouseCursors.click,
          //       child: OutlinedButton.icon(
          //         onPressed: auth.isLoading
          //             ? null
          //             : () => ref
          //                 .read(authControllerProvider.notifier)
          //                 .signInLocalAdmin(),
          //         icon: const Icon(
          //           Icons.admin_panel_settings_outlined,
          //           size: 18,
          //         ),
          //         label: const Text(
          //           'Development Admin Portal',
          //           style: TextStyle(
          //             fontSize: 14,
          //             fontWeight: FontWeight.w600,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ],
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Fail closed: configure a production identity provider.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        if (auth.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    auth.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Encrypted Local Session · v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );

  }
}


