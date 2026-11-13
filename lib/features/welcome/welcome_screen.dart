import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:witrack/core/constants/app_constants.dart';
import 'package:witrack/core/widgets/witrack_mark.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final content = _WelcomeContent(theme: theme, wide: wide);
            if (wide) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: content,
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: content,
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.theme, required this.wide});

  final ThemeData theme;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WitrackMark(size: 56, showGlow: true),
        SizedBox(height: wide ? 64 : 32),
        Text(
          AppConstants.brandPrimary,
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        Text(
          AppConstants.brandSecondary,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppConstants.tagline,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Premium desktop time tracking with clear activity '
            'insight, local-first storage, and privacy-respecting '
            'controls.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 36),
        FilledButton(
          onPressed: () => context.go('/app/dashboard'),
          child: const Text('Continue to app shell'),
        ),
        const SizedBox(height: 12),
        Text(
          'Local authentication arrives in Milestone M1.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.18),
            theme.colorScheme.secondary.withValues(alpha: 0.12),
            theme.scaffoldBackgroundColor,
          ],
        ),
        border: Border.all(color: theme.dividerColor),
      ),
      child: SizedBox(
        height: wide ? double.infinity : 220,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Track clearly.\nStay in control.',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
          ),
        ),
      ),
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copy,
          const SizedBox(height: 28),
          panel,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: copy),
        const SizedBox(width: 32),
        Expanded(child: panel),
      ],
    );
  }
}
